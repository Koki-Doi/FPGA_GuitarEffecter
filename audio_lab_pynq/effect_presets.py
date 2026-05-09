"""Shared presets for the Notebook UI and Python API.

The Notebook (``GuitarPedalboardOneCell.ipynb``) imports these so the
preset buttons match what someone driving the API directly would get.
The notebook also keeps a fallback inline copy in case the import
fails on an older deployed package — the values must stay byte-for-byte
identical between the two sources of truth.

If you change a number here, mirror it into the notebook's fallback
block in the same commit.
"""


# Distortion section presets. ``distortion_on`` toggles the section
# master flag (``gate_control`` bit 2). ``pedal`` is the
# pedal-mask name; the notebook applies it with ``exclusive=True``.
DISTORTION_PRESETS = {
    "Clean Boost": dict(
        distortion_on=True,
        pedal="clean_boost",
        drive=35,
        tone=50,
        level=45,
        bias=50,
        tight=50,
        mix=100,
    ),
    "Tube Screamer Crunch": dict(
        distortion_on=True,
        pedal="tube_screamer",
        drive=45,
        tone=55,
        level=35,
        bias=50,
        tight=60,
        mix=100,
    ),
    "RAT Distortion": dict(
        distortion_on=True,
        pedal="rat",
        drive=55,
        tone=45,
        level=35,
        bias=50,
        tight=50,
        mix=100,
    ),
    "Metal Tight": dict(
        distortion_on=True,
        pedal="metal",
        drive=55,
        tone=55,
        level=30,
        bias=50,
        tight=75,
        mix=100,
    ),
    # DS-1 style: bright, edgy crunch. DRIVE 45 / TONE 60 keeps the
    # voicing usable for rhythm; the Lead variant pushes DRIVE harder.
    "DS-1 Crunch": dict(
        distortion_on=True,
        pedal="ds1",
        drive=45,
        tone=60,
        level=30,
        bias=50,
        tight=50,
        mix=100,
    ),
    "DS-1 Lead": dict(
        distortion_on=True,
        pedal="ds1",
        drive=60,
        tone=65,
        level=28,
        bias=50,
        tight=55,
        mix=100,
    ),
    # Big Muff style: thick fuzz with cascaded soft clip. Sustain
    # variant sits in the mix; Wall variant pushes DRIVE for a
    # wall-of-sound feel.
    "Big Muff Sustain": dict(
        distortion_on=True,
        pedal="big_muff",
        drive=60,
        tone=45,
        level=28,
        bias=50,
        tight=35,
        mix=100,
    ),
    "Big Muff Wall": dict(
        distortion_on=True,
        pedal="big_muff",
        drive=75,
        tone=55,
        level=25,
        bias=50,
        tight=30,
        mix=100,
    ),
    # Fuzz Face style: raw asymmetric breakup. Vintage variant runs
    # darker / lower BIAS for a rounder germanium-flavoured feel.
    "Fuzz Face": dict(
        distortion_on=True,
        pedal="fuzz_face",
        drive=55,
        tone=55,
        level=28,
        bias=45,
        tight=25,
        mix=100,
    ),
    "Fuzz Face Vintage": dict(
        distortion_on=True,
        pedal="fuzz_face",
        drive=70,
        tone=45,
        level=25,
        bias=40,
        tight=20,
        mix=100,
    ),
}

# Noise Suppressor presets. THRESHOLD is the new 0..100 scale
# (byte = round(threshold * 255 / 1000), so the new 100 == legacy 10).
# DECAY drives close-ramp slowness; DAMP sets the maximum
# attenuation depth. BOSS NS-2 / NS-1X is referenced by name only —
# no source code or circuit is copied.
NOISE_SUPPRESSOR_PRESETS = {
    "NS-2 Style":       dict(threshold=35, decay=45, damp=80),
    "NS-1X Natural":    dict(threshold=30, decay=55, damp=60),
    "High Gain Tight":  dict(threshold=55, decay=20, damp=90),
    "Sustain Friendly": dict(threshold=25, decay=75, damp=45),
}

# Compressor presets. Stereo-linked feed-forward peak compressor on
# axi_gpio_compressor. The numbers ride the Python 0..100 scale that
# AudioLabOverlay.set_compressor_settings accepts; bytes are derived
# via control_maps.compressor_word. Reference designs for shape only:
#   - harveyf2801/AudioFX-Compressor (parameter set, knee philosophy)
#   - bdejong/musicdsp simple-compressor (feed-forward, peak detect,
#     stereo link)
#   - DanielRudrich/SimpleCompressor (gain-reduction computer concept)
#   - chipaudette/OpenAudio_ArduinoLibrary AudioEffectCompressor2_F32
#     (compression curve / knee idea)
#   - p-hlp/SMPLComp, Ashymad/bancom (parameter naming + UI grouping)
# No source code from these projects has been copied; only the
# parameter naming and design philosophy is referenced.
COMPRESSOR_PRESETS = {
    "Comp Off": dict(
        enabled=False,
        threshold=45,
        ratio=35,
        response=45,
        makeup=50,
    ),
    "Light Sustain": dict(
        enabled=True,
        threshold=45,
        ratio=25,
        response=55,
        makeup=55,
    ),
    "Funk Tight": dict(
        enabled=True,
        threshold=55,
        ratio=45,
        response=20,
        makeup=50,
    ),
    "Lead Sustain": dict(
        enabled=True,
        threshold=40,
        ratio=60,
        response=70,
        makeup=60,
    ),
    "Limiter-ish": dict(
        enabled=True,
        threshold=70,
        ratio=85,
        response=25,
        makeup=45,
    ),
}

# Safe Bypass: panic preset, every effect off and parameters at the
# neutral end of their range. The notebook's Safe Bypass button
# applies this. Mirrors ``effect_defaults.SAFE_BYPASS_DEFAULTS``;
# kept as a simple alias for symmetry with the other presets.
SAFE_BYPASS_PRESET = "_safe_bypass"


# Practical chain presets that combine every section of the live
# pedalboard (Compressor + Noise Suppressor + Overdrive + Distortion
# Pedalboard + Amp + Cab IR + EQ + Reverb) into one named voicing.
# These are designed to be playable in practice: makeup gain is held
# at 45..60 (no surprise volume jumps), distortion ``level`` stays
# below 35, NS / Comp settings are tuned not to fight each other,
# and Reverb ``mix`` is conservative.
#
# Schema: each preset is a nested dict with one entry per section.
# Sections that are absent or have ``enabled=False`` are bypassed.
# The keys mirror the ``set_*_settings`` argument names so
# ``AudioLabOverlay.apply_chain_preset`` can call them directly.
#
# Distortion section: ``pedal`` is a name from
# ``effect_defaults.DISTORTION_PEDALS`` or ``None``. ``None`` plus
# ``enabled=False`` means "section master off, no pedal selected".
CHAIN_PRESETS = {
    "Safe Bypass": dict(
        compressor=dict(enabled=False, threshold=45, ratio=35, response=45, makeup=50),
        noise_suppressor=dict(enabled=False, threshold=35, decay=40, damp=70),
        overdrive=dict(enabled=False, drive=0, tone=50, level=100),
        distortion=dict(enabled=False, pedal=None, drive=20, tone=50, level=35,
                        bias=50, tight=50, mix=100),
        amp=dict(enabled=False, input_gain=35, bass=50, middle=50, treble=50,
                 presence=45, resonance=35, master=80, character=35),
        cab=dict(enabled=False, mix=100, level=100, model=1, air=50),
        eq=dict(enabled=False, low=100, mid=100, high=100),
        reverb=dict(enabled=False, decay=0, tone=65, mix=0),
    ),
    "Basic Clean": dict(
        compressor=dict(enabled=True, threshold=50, ratio=20, response=50, makeup=50),
        noise_suppressor=dict(enabled=False, threshold=35, decay=40, damp=70),
        overdrive=dict(enabled=False, drive=0, tone=50, level=100),
        distortion=dict(enabled=False, pedal=None, drive=20, tone=50, level=35,
                        bias=50, tight=50, mix=100),
        amp=dict(enabled=True, input_gain=25, bass=50, middle=55, treble=60,
                 presence=42, resonance=30, master=75, character=22),
        cab=dict(enabled=True, mix=85, level=100, model=0, air=65),
        eq=dict(enabled=False, low=100, mid=100, high=100),
        reverb=dict(enabled=True, decay=25, tone=65, mix=15),
    ),
    "Clean Sustain": dict(
        compressor=dict(enabled=True, threshold=45, ratio=25, response=55, makeup=55),
        noise_suppressor=dict(enabled=False, threshold=30, decay=55, damp=60),
        overdrive=dict(enabled=False, drive=0, tone=50, level=100),
        distortion=dict(enabled=False, pedal=None, drive=20, tone=50, level=35,
                        bias=50, tight=50, mix=100),
        amp=dict(enabled=True, input_gain=25, bass=50, middle=55, treble=58,
                 presence=42, resonance=30, master=75, character=25),
        cab=dict(enabled=True, mix=85, level=100, model=0, air=60),
        eq=dict(enabled=False, low=100, mid=100, high=100),
        reverb=dict(enabled=True, decay=35, tone=65, mix=20),
    ),
    "Light Crunch": dict(
        compressor=dict(enabled=True, threshold=50, ratio=25, response=45, makeup=50),
        noise_suppressor=dict(enabled=False, threshold=35, decay=40, damp=70),
        overdrive=dict(enabled=True, drive=30, tone=60, level=80),
        distortion=dict(enabled=False, pedal=None, drive=20, tone=50, level=35,
                        bias=50, tight=50, mix=100),
        amp=dict(enabled=True, input_gain=35, bass=55, middle=55, treble=55,
                 presence=45, resonance=35, master=70, character=35),
        cab=dict(enabled=True, mix=100, level=100, model=0, air=60),
        eq=dict(enabled=False, low=100, mid=100, high=100),
        reverb=dict(enabled=True, decay=25, tone=65, mix=15),
    ),
    "Tube Screamer Lead": dict(
        compressor=dict(enabled=True, threshold=40, ratio=60, response=70, makeup=60),
        noise_suppressor=dict(enabled=True, threshold=30, decay=55, damp=60),
        overdrive=dict(enabled=False, drive=0, tone=60, level=100),
        distortion=dict(enabled=True, pedal="tube_screamer",
                        drive=50, tone=65, level=30, bias=50, tight=60, mix=100),
        amp=dict(enabled=True, input_gain=40, bass=55, middle=60, treble=60,
                 presence=50, resonance=40, master=70, character=40),
        cab=dict(enabled=True, mix=100, level=100, model=1, air=55),
        eq=dict(enabled=False, low=100, mid=100, high=100),
        reverb=dict(enabled=True, decay=35, tone=65, mix=20),
    ),
    "RAT Rhythm": dict(
        compressor=dict(enabled=True, threshold=50, ratio=35, response=40, makeup=50),
        noise_suppressor=dict(enabled=True, threshold=40, decay=40, damp=70),
        overdrive=dict(enabled=False, drive=0, tone=50, level=100),
        distortion=dict(enabled=True, pedal="rat",
                        drive=50, tone=50, level=30, bias=50, tight=55, mix=80),
        amp=dict(enabled=True, input_gain=35, bass=55, middle=55, treble=55,
                 presence=45, resonance=40, master=70, character=40),
        cab=dict(enabled=True, mix=100, level=100, model=1, air=50),
        eq=dict(enabled=False, low=100, mid=100, high=100),
        reverb=dict(enabled=True, decay=25, tone=65, mix=10),
    ),
    "Metal Tight": dict(
        compressor=dict(enabled=True, threshold=55, ratio=45, response=20, makeup=50),
        noise_suppressor=dict(enabled=True, threshold=55, decay=20, damp=90),
        overdrive=dict(enabled=False, drive=0, tone=50, level=100),
        distortion=dict(enabled=True, pedal="metal",
                        drive=55, tone=55, level=28, bias=50, tight=80, mix=100),
        amp=dict(enabled=True, input_gain=42, bass=55, middle=50, treble=52,
                 presence=45, resonance=45, master=70, character=50),
        cab=dict(enabled=True, mix=100, level=100, model=2, air=35),
        eq=dict(enabled=False, low=100, mid=100, high=100),
        reverb=dict(enabled=True, decay=20, tone=65, mix=8),
    ),
    "Ambient Clean": dict(
        compressor=dict(enabled=True, threshold=45, ratio=25, response=55, makeup=55),
        noise_suppressor=dict(enabled=False, threshold=30, decay=55, damp=60),
        overdrive=dict(enabled=False, drive=0, tone=50, level=100),
        distortion=dict(enabled=False, pedal=None, drive=20, tone=50, level=35,
                        bias=50, tight=50, mix=100),
        amp=dict(enabled=False, input_gain=35, bass=50, middle=50, treble=50,
                 presence=45, resonance=35, master=80, character=35),
        cab=dict(enabled=True, mix=75, level=100, model=0, air=70),
        eq=dict(enabled=True, low=80, mid=100, high=110),
        reverb=dict(enabled=True, decay=70, tone=70, mix=55),
    ),
    "Solo Boost": dict(
        compressor=dict(enabled=True, threshold=40, ratio=60, response=70, makeup=60),
        noise_suppressor=dict(enabled=True, threshold=30, decay=55, damp=55),
        overdrive=dict(enabled=False, drive=0, tone=60, level=100),
        distortion=dict(enabled=True, pedal="tube_screamer",
                        drive=45, tone=65, level=30, bias=50, tight=55, mix=100),
        amp=dict(enabled=True, input_gain=40, bass=55, middle=60, treble=60,
                 presence=55, resonance=40, master=70, character=45),
        cab=dict(enabled=True, mix=100, level=100, model=1, air=55),
        eq=dict(enabled=False, low=100, mid=100, high=100),
        reverb=dict(enabled=True, decay=35, tone=65, mix=20),
    ),
    "Noise Controlled High Gain": dict(
        compressor=dict(enabled=True, threshold=50, ratio=30, response=40, makeup=50),
        noise_suppressor=dict(enabled=True, threshold=60, decay=30, damp=85),
        overdrive=dict(enabled=False, drive=0, tone=50, level=100),
        distortion=dict(enabled=True, pedal="metal",
                        drive=55, tone=50, level=28, bias=50, tight=75, mix=100),
        amp=dict(enabled=True, input_gain=42, bass=55, middle=50, treble=52,
                 presence=45, resonance=45, master=70, character=50),
        cab=dict(enabled=True, mix=100, level=100, model=2, air=35),
        eq=dict(enabled=False, low=100, mid=100, high=100),
        reverb=dict(enabled=True, decay=20, tone=65, mix=10),
    ),
    # New chain voicings for the freshly-implemented reserved pedals.
    # Same safety contract (compressor makeup 45..60, distortion level
    # <= 35) as the existing presets.
    "DS-1 Crunch": dict(
        compressor=dict(enabled=True, threshold=50, ratio=30, response=40, makeup=50),
        noise_suppressor=dict(enabled=True, threshold=35, decay=40, damp=70),
        overdrive=dict(enabled=False, drive=0, tone=50, level=100),
        distortion=dict(enabled=True, pedal="ds1",
                        drive=45, tone=60, level=30, bias=50, tight=50, mix=100),
        amp=dict(enabled=True, input_gain=40, bass=55, middle=55, treble=60,
                 presence=50, resonance=40, master=70, character=40),
        cab=dict(enabled=True, mix=100, level=100, model=2, air=40),
        eq=dict(enabled=False, low=100, mid=100, high=100),
        reverb=dict(enabled=True, decay=25, tone=65, mix=12),
    ),
    "Big Muff Sustain": dict(
        compressor=dict(enabled=True, threshold=45, ratio=35, response=60, makeup=55),
        noise_suppressor=dict(enabled=True, threshold=40, decay=50, damp=70),
        overdrive=dict(enabled=False, drive=0, tone=50, level=100),
        distortion=dict(enabled=True, pedal="big_muff",
                        drive=60, tone=45, level=28, bias=50, tight=35, mix=100),
        amp=dict(enabled=True, input_gain=38, bass=58, middle=45, treble=52,
                 presence=42, resonance=48, master=70, character=45),
        cab=dict(enabled=True, mix=100, level=100, model=2, air=35),
        eq=dict(enabled=False, low=100, mid=100, high=100),
        reverb=dict(enabled=True, decay=40, tone=65, mix=18),
    ),
    "Vintage Fuzz": dict(
        compressor=dict(enabled=True, threshold=50, ratio=30, response=50, makeup=50),
        noise_suppressor=dict(enabled=True, threshold=35, decay=45, damp=70),
        overdrive=dict(enabled=False, drive=0, tone=50, level=100),
        distortion=dict(enabled=True, pedal="fuzz_face",
                        drive=55, tone=55, level=28, bias=45, tight=25, mix=100),
        amp=dict(enabled=True, input_gain=35, bass=58, middle=50, treble=52,
                 presence=40, resonance=42, master=70, character=35),
        cab=dict(enabled=True, mix=90, level=100, model=2, air=35),
        eq=dict(enabled=False, low=100, mid=100, high=100),
        reverb=dict(enabled=True, decay=30, tone=65, mix=15),
    ),
}

# Sections every chain preset must define, in the canonical apply
# order. ``apply_chain_preset`` iterates this list to push a preset
# into the overlay; tests use it to validate preset shape.
CHAIN_PRESET_SECTIONS = (
    "compressor",
    "noise_suppressor",
    "overdrive",
    "distortion",
    "amp",
    "cab",
    "eq",
    "reverb",
)


__all__ = [
    "DISTORTION_PRESETS",
    "NOISE_SUPPRESSOR_PRESETS",
    "COMPRESSOR_PRESETS",
    "CHAIN_PRESETS",
    "CHAIN_PRESET_SECTIONS",
    "SAFE_BYPASS_PRESET",
]
