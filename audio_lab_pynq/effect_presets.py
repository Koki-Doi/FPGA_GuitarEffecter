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


__all__ = [
    "DISTORTION_PRESETS",
    "NOISE_SUPPRESSOR_PRESETS",
    "COMPRESSOR_PRESETS",
    "SAFE_BYPASS_PRESET",
]
