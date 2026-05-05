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
]
