"""Control word pack / unpack / clamp helpers for AXI GPIO writes.

Every effect parameter reaches the Clash block through one of the
``axi_gpio_*`` IPs documented in
``docs/ai_context/GPIO_CONTROL_MAP.md``. Each GPIO is a single-channel
32-bit output; the Clash side decomposes the word into four bytes
(``ctrlA`` = `[7:0]`, ``ctrlB`` = `[15:8]`, ``ctrlC`` = `[23:16]`,
``ctrlD`` = `[31:24]`).

This module owns the *shape* of those bytes and words. Anything that
builds an AXI GPIO word should use these helpers so the Python /
Clash / notebook / tests layers all agree on the same encoding.

Compatibility note: the byte values produced here are byte-for-byte
identical to the legacy ``AudioLabOverlay._clamp_percent`` /
``_percent_to_u8`` / ``_level_to_q7`` / ``_noise_threshold_to_u8`` /
``_pack4`` helpers. ``AudioLabOverlay`` keeps those classmethods as
thin delegates so existing tests and external callers keep working.
"""


def clamp_int(value, low, high):
    """Round to int and clamp to ``[low, high]``."""
    value = int(round(value))
    if value < low:
        return low
    if value > high:
        return high
    return value


def clamp_percent(value):
    """Clamp a 0..100 percentage to an integer in ``[0, 100]``."""
    return clamp_int(value, 0, 100)


def clamp_u8(value):
    """Clamp any input to an integer in ``[0, 255]``."""
    return clamp_int(value, 0, 255)


def percent_to_u8(value, maximum=255):
    """Map a 0..100 percentage to a byte in ``[0, maximum]`` then clamp to u8.

    Matches the legacy ``AudioLabOverlay._percent_to_u8`` exactly:
    the percent input is rounded and clamped first, then scaled by
    ``maximum / 100``, then re-rounded and clamped to ``[0, 255]``.
    """
    value = clamp_percent(value)
    return clamp_int(value * maximum / 100, 0, 255)


def level_to_q7(value):
    """Map a 0..200 ``level`` percentage to a Q7-style byte.

    Used by ``overdrive_level`` / ``distortion_level`` /
    ``rat_level`` / ``amp_master`` / ``cab_level`` / EQ-band knobs.
    Matches the legacy ``AudioLabOverlay._level_to_q7``: input is
    clamped to ``[0, 200]``, then scaled by ``128 / 100``, then
    clamped to ``[0, 255]``.
    """
    value = clamp_int(value, 0, 200)
    return clamp_int(value * 128 / 100, 0, 255)


def noise_threshold_to_u8(value):
    """Map a 0..100 noise-suppressor threshold to a byte.

    New scale (one tenth of the legacy ``noise_gate_threshold`` span):
    ``byte = round(threshold * 255 / 1000)``, so the new 100 maps to
    byte 26 (== legacy ``noise_gate_threshold=10`` byte). Anchor
    table:

    +-----------+------+
    | threshold | byte |
    +===========+======+
    | 0         | 0    |
    +-----------+------+
    | 10        | 3    |
    +-----------+------+
    | 50        | 13   |
    +-----------+------+
    | 100       | 26   |
    +-----------+------+
    """
    value = clamp_percent(value)
    return clamp_int(value * 255 / 1000, 0, 255)


def bool_to_bit(value):
    """Map a truthy / falsy value to ``1`` / ``0``."""
    return 1 if value else 0


def pack_u8x4(ctrlA=0, ctrlB=0, ctrlC=0, ctrlD=0):
    """Pack four bytes into one 32-bit AXI GPIO word.

    Layout: ``ctrlA | ctrlB << 8 | ctrlC << 16 | ctrlD << 24``.
    Each input is masked to 8 bits so out-of-range values cannot
    leak into adjacent bytes.
    """
    return (
        (int(ctrlA) & 0xFF)
        | ((int(ctrlB) & 0xFF) << 8)
        | ((int(ctrlC) & 0xFF) << 16)
        | ((int(ctrlD) & 0xFF) << 24)
    )


def pack_u8x3(ctrlA=0, ctrlB=0, ctrlC=0):
    """Pack three bytes into one 32-bit AXI GPIO word; ``ctrlD`` stays 0."""
    return pack_u8x4(ctrlA, ctrlB, ctrlC, 0)


def unpack_u8x4(word):
    """Inverse of :func:`pack_u8x4`. Returns ``(ctrlA, ctrlB, ctrlC, ctrlD)``."""
    word = int(word) & 0xFFFFFFFF
    return (
        word & 0xFF,
        (word >> 8) & 0xFF,
        (word >> 16) & 0xFF,
        (word >> 24) & 0xFF,
    )


def set_byte(word, index, value):
    """Replace one byte (``index`` 0..3) inside ``word`` with ``value``.

    Useful for read-modify-write on a cached AXI GPIO word: mask out
    the byte we own, OR the new byte in.
    """
    if index < 0 or index > 3:
        raise ValueError("byte index must be 0..3, got {}".format(index))
    shift = index * 8
    mask = 0xFF << shift
    return ((int(word) & 0xFFFFFFFF) & ~mask) | ((int(value) & 0xFF) << shift)


def get_byte(word, index):
    """Extract one byte (``index`` 0..3) from ``word``."""
    if index < 0 or index > 3:
        raise ValueError("byte index must be 0..3, got {}".format(index))
    return (int(word) >> (index * 8)) & 0xFF


def noise_suppressor_word(threshold, decay, damp, mode=0):
    """Build the 32-bit word for ``axi_gpio_noise_suppressor``.

    Bytes:

    - ``ctrlA`` = THRESHOLD via :func:`noise_threshold_to_u8`
    - ``ctrlB`` = DECAY via :func:`percent_to_u8`
    - ``ctrlC`` = DAMP via :func:`percent_to_u8`
    - ``ctrlD`` = ``mode`` (clamped to ``[0, 255]``)
    """
    return pack_u8x4(
        noise_threshold_to_u8(threshold),
        percent_to_u8(decay, 255),
        percent_to_u8(damp, 255),
        clamp_u8(mode),
    )


def makeup_to_u7(value):
    """Map a 0..100 makeup percentage to a 7-bit Q7 byte in ``[0, 127]``.

    Anchors:

    +---------+-----+
    | percent | u7  |
    +=========+=====+
    | 0       | 0   |
    +---------+-----+
    | 50      | 64  |
    +---------+-----+
    | 100     | 127 |
    +---------+-----+

    The result lives in the low 7 bits of
    ``compressor_control.ctrlD``; the top bit of that byte carries the
    compressor enable flag.
    """
    return clamp_int(percent_to_u8(value, 127), 0, 127)


def compressor_enable_makeup_byte(enabled, makeup):
    """Pack the compressor enable bit and makeup percent into one byte.

    Bit 7 carries the enable flag; bits[6:0] carry
    :func:`makeup_to_u7` of ``makeup``. The Clash side reads this as
    ``compEnable`` / ``compMakeupU7``.
    """
    byte = makeup_to_u7(makeup)
    if enabled:
        byte |= 0x80
    return byte & 0xFF


def compressor_word(threshold, ratio, response, makeup, enabled=False):
    """Build the 32-bit word for ``axi_gpio_compressor``.

    Bytes:

    - ``ctrlA`` = THRESHOLD via :func:`percent_to_u8`
    - ``ctrlB`` = RATIO via :func:`percent_to_u8`
    - ``ctrlC`` = RESPONSE via :func:`percent_to_u8`
    - ``ctrlD`` bit 7 = ``enabled``;
      ``ctrlD`` bits[6:0] = :func:`makeup_to_u7` of ``makeup``
    """
    return pack_u8x4(
        percent_to_u8(threshold, 255),
        percent_to_u8(ratio, 255),
        percent_to_u8(response, 255),
        compressor_enable_makeup_byte(enabled, makeup),
    )


def reverb_word(decay, tone, mix):
    """Build the 32-bit word for ``axi_gpio_reverb``.

    Hardware layout, fixed by the Clash reverb stage
    (``AudioLab.Effects.Reverb``):

    - ``ctrlA`` = DECAY / feedback gain, ``percent_to_u8(decay, 220)``
      (the feedback multiply ``mulU8(monoWet, ctrlA)``)
    - ``ctrlB`` = TONE, ``percent_to_u8(tone, 255)``
    - ``ctrlC`` = MIX, ``percent_to_u8(mix, 192)``
    - ``ctrlD`` is unused (kept 0)

    The reverb ENABLE is **not** carried in this word -- the Clash stage
    gates on ``flag5`` of ``gate_control`` (the ``reverb_on`` flag bit),
    so this builder takes no ``enabled`` argument. The DECAY / TONE / MIX
    maxima (220 / 255 / 192) match the legacy inline packing in
    ``AudioLabOverlay.guitar_effect_control_words`` byte-for-byte.
    """
    return pack_u8x3(
        percent_to_u8(decay, 220),
        percent_to_u8(tone, 255),
        percent_to_u8(mix, 192),
    )


def eq_word(low, mid, high):
    """Build the ``axi_gpio_eq`` word: ctrlA/B/C = LOW/MID/HIGH bands as
    Q7-style level bytes; ctrlD unused. Matches the legacy inline packing
    in ``guitar_effect_control_words`` byte-for-byte."""
    return pack_u8x3(level_to_q7(low), level_to_q7(mid), level_to_q7(high))


def rat_word(filter_, level, drive, mix):
    """Build the ``axi_gpio_delay`` (RAT) word: ctrlA=FILTER, ctrlB=LEVEL
    (Q7, clamped to <=150 first), ctrlC=DRIVE, ctrlD=MIX. Matches the
    legacy inline packing byte-for-byte."""
    return pack_u8x4(
        percent_to_u8(filter_, 255),
        level_to_q7(clamp_int(level, 0, 150)),
        percent_to_u8(drive, 255),
        percent_to_u8(mix, 255),
    )


def cab_word(mix, level, model, air):
    """Build the ``axi_gpio_cab`` word: ctrlA=MIX, ctrlB=LEVEL (Q7,
    clamped to <=150 first), ctrlC=MODEL (0/85/170 = the three preset
    IRs, from ``model`` 0..2), ctrlD=AIR. Matches the legacy inline
    packing byte-for-byte."""
    return pack_u8x4(
        percent_to_u8(mix, 255),
        level_to_q7(clamp_int(level, 0, 150)),
        clamp_int(model, 0, 2) * 85,
        percent_to_u8(air, 255),
    )


def gate_flags(noise_gate_on=False, overdrive_on=False, distortion_on=False,
               eq_on=False, rat_on=False, reverb_on=False, amp_on=False,
               cab_on=False):
    """Pack the eight effect-master flags into ``gate_control.ctrlA``."""
    flags = 0
    flags |= 0x01 if noise_gate_on else 0
    flags |= 0x02 if overdrive_on else 0
    flags |= 0x04 if distortion_on else 0
    flags |= 0x08 if eq_on else 0
    flags |= 0x10 if rat_on else 0
    flags |= 0x20 if reverb_on else 0
    flags |= 0x40 if amp_on else 0
    flags |= 0x80 if cab_on else 0
    return flags & 0xFF


def gate_word(noise_gate_on=False, noise_gate_threshold=8,
              overdrive_on=False, distortion_on=False, eq_on=False,
              rat_on=False, reverb_on=False, amp_on=False, cab_on=False,
              distortion_bias=50, distortion_mix=100):
    """Build ``axi_gpio_gate``.

    Bytes:

    - ``ctrlA`` = effect-master flags
    - ``ctrlB`` = legacy noise gate threshold via
      :func:`noise_threshold_to_u8`
    - ``ctrlC`` = distortion bias byte
    - ``ctrlD`` = distortion mix byte
    """
    return pack_u8x4(
        gate_flags(
            noise_gate_on=noise_gate_on,
            overdrive_on=overdrive_on,
            distortion_on=distortion_on,
            eq_on=eq_on,
            rat_on=rat_on,
            reverb_on=reverb_on,
            amp_on=amp_on,
            cab_on=cab_on,
        ),
        noise_threshold_to_u8(noise_gate_threshold),
        percent_to_u8(distortion_bias, 255),
        percent_to_u8(distortion_mix, 255),
    )


def overdrive_ctrlD(distortion_tight=50, overdrive_model=0,
                    overdrive_model_count=6):
    """Pack ``overdrive_control.ctrlD``.

    Upper five bits carry distortion TIGHT. Lower three bits carry the
    overdrive model select; values outside the implemented model count
    fall back to 0 (TS9), matching the legacy inline packer.
    """
    tight_byte = percent_to_u8(distortion_tight, 255)
    model = clamp_int(overdrive_model, 0, 7) & 0x07
    if model >= int(overdrive_model_count):
        model = 0
    return ((tight_byte & 0xF8) | (model & 0x07)) & 0xFF


def overdrive_word(tone, level, drive, distortion_tight=50,
                   overdrive_model=0, overdrive_model_count=6):
    """Build ``axi_gpio_overdrive``.

    Bytes: ctrlA=TONE, ctrlB=LEVEL Q7, ctrlC=DRIVE, ctrlD=TIGHT/model.
    """
    return pack_u8x4(
        percent_to_u8(tone, 255),
        level_to_q7(level),
        percent_to_u8(drive, 255),
        overdrive_ctrlD(distortion_tight, overdrive_model,
                        overdrive_model_count),
    )


def distortion_word(tone, level, drive, pedal_mask=0):
    """Build ``axi_gpio_distortion``.

    Bytes: ctrlA=TONE, ctrlB=LEVEL Q7, ctrlC=DRIVE, ctrlD=pedal mask
    bits[6:0]. Bit 7 is reserved and always cleared.
    """
    return pack_u8x4(
        percent_to_u8(tone, 255),
        level_to_q7(level),
        percent_to_u8(drive, 255),
        int(pedal_mask) & 0x7F,
    )


def amp_word(input_gain, master, presence, resonance):
    """Build ``axi_gpio_amp``.

    Bytes: ctrlA=INPUT_GAIN, ctrlB=MASTER Q7 (clamped to <=150 before
    scaling), ctrlC=PRESENCE, ctrlD=RESONANCE.
    """
    return pack_u8x4(
        percent_to_u8(input_gain, 255),
        level_to_q7(clamp_int(master, 0, 150)),
        percent_to_u8(presence, 255),
        percent_to_u8(resonance, 255),
    )


def amp_model_drive_byte(amp_model_idx=0, amp_drive_mode=0,
                         max_idx=5, idx_mask=0x07, drive_mode_bit=7):
    """Pack the D55 amp model index and binary drive mode into one byte."""
    try:
        idx = int(amp_model_idx)
    except Exception:
        idx = 0
    idx = max(0, min(int(max_idx), idx))
    try:
        mode = 1 if int(amp_drive_mode) >= 1 else 0
    except Exception:
        mode = 0
    return ((mode & 1) << int(drive_mode_bit)) | (idx & int(idx_mask))


def amp_tone_word(bass, middle, treble, character=35, amp_model_idx=None,
                  amp_drive_mode=0, max_idx=5, idx_mask=0x07,
                  drive_mode_bit=7):
    """Build ``axi_gpio_amp_tone``.

    Legacy callers without ``amp_model_idx`` use ``character`` as a
    percent byte. D55 callers pass ``amp_model_idx`` and get the bit-packed
    model/drive byte in ctrlD.
    """
    if amp_model_idx is not None:
        character_byte = amp_model_drive_byte(
            amp_model_idx=amp_model_idx,
            amp_drive_mode=amp_drive_mode,
            max_idx=max_idx,
            idx_mask=idx_mask,
            drive_mode_bit=drive_mode_bit,
        )
    else:
        character_byte = percent_to_u8(character, 255)
    return pack_u8x4(
        percent_to_u8(bass, 255),
        percent_to_u8(middle, 255),
        percent_to_u8(treble, 255),
        character_byte,
    )


# ---- Wah --------------------------------------------------------------
#
# Drives the dedicated ``axi_gpio_wah`` at ``0x43D30000``. Bytes:
# ``ctrlA`` = POSITION (0..255 u8; the 0..100 UI scale is mapped onto
# 0..255), ``ctrlB`` = Q (0..100 UI -> 0..255 u8), ``ctrlC`` = VOLUME
# (0..100 UI -> 0..255 u8 with 128 ~= unity), ``ctrlD`` bit 7 = enable,
# ``ctrlD`` bits[6:0] = BIAS (0..100 UI -> 0..127 u7 with 64 = centred).
# The Wah enable lives inside this GPIO (same convention as
# ``axi_gpio_compressor`` ctrlD bit 7); it is NOT carried in
# ``gate_control.ctrlA``.

def wah_position_byte(value):
    """Map a Wah POSITION UI percent (0..100) to a byte in [0, 255].

    D73 split: this is now the GUI / encoder path **only** and treats
    its argument as a 0..100 percent value. For the FP02M / Arduino A0
    future-input path (raw 0..255 byte), use
    :func:`wah_position_raw_byte` instead -- the previous
    magnitude-based scale auto-detection caused raw 0..100 values to
    be mis-interpreted as percentages.
    """
    return percent_to_u8(value, 255)


def wah_position_raw_byte(value):
    """Clamp a raw Wah POSITION byte (0..255) for the FP02M / Arduino A0
    future-input path.

    No percent scaling. Out-of-range inputs are clamped to ``[0, 255]``;
    non-numeric inputs return 0.
    """
    try:
        v = int(round(float(value)))
    except (TypeError, ValueError):
        return 0
    return clamp_u8(v)


# D76: the Wah resonance self-oscillates near full POSITION (toe) once the
# Q byte gets sharp enough. Bench (FP02M pedal at the toe extreme): Q byte
# 89 (old UI 35 %) was clean, byte 128 (this cap's first try) still howled,
# byte 166 (UI 65 %) howled hard. Cap the UI Q range so even UI Q = 100 %
# lands at byte 80 -- just below the proven-clean byte-89 point, with margin
# for pedal/position variance -- giving a mild-medium resonance (q_coef
# ~0.34) that does not self-oscillate anywhere on the POSITION sweep. The UI
# keeps its 0..100 scale; only the top of the dial is tamed.
WAH_Q_BYTE_MAX = 80


def wah_q_byte(value):
    """Map a Wah Q UI value (0..100) to a byte in [0, WAH_Q_BYTE_MAX].

    D76: the upper end is capped at ``WAH_Q_BYTE_MAX`` (was 255) to keep the
    resonant band-pass below its self-oscillation onset at high POSITION.
    """
    return percent_to_u8(value, WAH_Q_BYTE_MAX)


def wah_volume_byte(value):
    """Map a Wah VOLUME UI value (0..100) to a byte in [0, 255].

    50 -> ~128 -> unity on the Clash side (``wahVolumeFactor`` yields a
    Q8 factor of 256 at byte 255 with linear interpolation from 64 at
    byte 0; byte 128 sits at the unity-ish mid-point).
    """
    return percent_to_u8(value, 255)


def wah_bias_to_u7(value):
    """Map a Wah BIAS UI value (0..100) to a u7 byte in [0, 127].

    50 -> ~64 -> Clash interprets as "centred / no bias shift".
    The result lives in the low 7 bits of ``axi_gpio_wah.ctrlD``; the
    top bit of that byte carries the Wah enable flag.
    """
    return clamp_int(percent_to_u8(value, 127), 0, 127)


def wah_enable_bias_byte(enabled, bias):
    """Pack the Wah enable bit and BIAS percent into one byte.

    Bit 7 carries the enable flag; bits[6:0] carry :func:`wah_bias_to_u7`
    of ``bias``. The Clash side reads this as ``wahEnabled`` /
    ``wahBiasByte``.
    """
    byte = wah_bias_to_u7(bias)
    if enabled:
        byte |= 0x80
    return byte & 0xFF


def wah_word(position=None, q=0, volume=0, bias=0, enabled=False,
             position_raw=None):
    """Build the 32-bit word for ``axi_gpio_wah``.

    Bytes:

    - ``ctrlA`` = POSITION:
        ``wah_position_byte(position)`` when ``position`` is a 0..100
        percent (GUI / encoder path), OR ``wah_position_raw_byte(position_raw)``
        when ``position_raw`` is the FP02M / Arduino A0 raw byte. The
        two arguments are mutually exclusive; supplying both raises
        ``ValueError``. Supplying neither yields 0 (heel).
    - ``ctrlB`` = Q via :func:`wah_q_byte`
    - ``ctrlC`` = VOLUME via :func:`wah_volume_byte`
    - ``ctrlD`` bit 7 = ``enabled``;
      ``ctrlD`` bits[6:0] = :func:`wah_bias_to_u7` of ``bias``
    """
    if position is not None and position_raw is not None:
        raise ValueError(
            "wah_word: pass position (percent) OR position_raw (byte), "
            "not both")
    if position_raw is not None:
        position_byte = wah_position_raw_byte(position_raw)
    elif position is not None:
        position_byte = wah_position_byte(position)
    else:
        position_byte = 0
    return pack_u8x4(
        position_byte,
        wah_q_byte(q),
        wah_volume_byte(volume),
        wah_enable_bias_byte(enabled, bias),
    )


__all__ = [
    "clamp_int",
    "clamp_percent",
    "clamp_u8",
    "percent_to_u8",
    "level_to_q7",
    "noise_threshold_to_u8",
    "bool_to_bit",
    "pack_u8x4",
    "pack_u8x3",
    "unpack_u8x4",
    "set_byte",
    "get_byte",
    "noise_suppressor_word",
    "makeup_to_u7",
    "compressor_enable_makeup_byte",
    "compressor_word",
    "wah_position_byte",
    "wah_position_raw_byte",
    "wah_q_byte",
    "WAH_Q_BYTE_MAX",
    "wah_volume_byte",
    "wah_bias_to_u7",
    "wah_enable_bias_byte",
    "wah_word",
]
