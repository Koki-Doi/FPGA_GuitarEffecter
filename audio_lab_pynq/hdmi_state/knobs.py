"""GUI knob layout for the 800x480 compact-v2 HDMI panel.

``GUI_EFFECT_KNOBS`` is the 8-slot per-effect layout consumed by
``GUI/pynq_multi_fx_gui.py`` and mirrored into ``AppState`` by
``HdmiEffectStateMirror``. AMP SIM uses all 8 indices; other effects
fill 3-6 slots and leave the rest as the empty marker so the
renderer can ignore them.
"""

GUI_EFFECTS = [
    "Noise Sup", "Compressor", "Overdrive", "Distortion",
    "Amp Sim", "Cab IR", "EQ", "Reverb",
]

# Phase 6E: 8-slot knob layout. AMP SIM uses all 8 indices
# (GAIN / BASS / MIDDLE / TREBLE / PRESENCE / RESONANCE / MASTER /
# CHARACTER); the other effects fill 3-6 slots and leave the rest as
# the empty marker so the renderer can ignore them.
GUI_EFFECT_KNOBS = {
    "Noise Sup":  [("THRESHOLD", 35), ("DECAY", 45), ("DAMP", 80),
                   ("", 0), ("", 0), ("", 0), ("", 0), ("", 0)],
    "Compressor": [("THRESHOLD", 50), ("RATIO", 45), ("RESPONSE", 40),
                   ("MAKEUP", 55), ("", 0), ("", 0), ("", 0), ("", 0)],
    "Overdrive":  [("DRIVE", 35), ("TONE", 60), ("LEVEL", 60),
                   ("", 0), ("", 0), ("", 0), ("", 0), ("", 0)],
    "Distortion": [("DRIVE", 50), ("TONE", 55), ("LEVEL", 35),
                   ("BIAS", 50), ("TIGHT", 60), ("MIX", 100),
                   ("", 0), ("", 0)],
    "Amp Sim":    [("GAIN", 45), ("BASS", 55), ("MIDDLE", 60),
                   ("TREBLE", 50), ("PRESENCE", 45), ("RESONANCE", 35),
                   ("MASTER", 70), ("CHARACTER", 60)],
    "Cab IR":     [("MIX", 100), ("LEVEL", 70), ("MODEL", 33),
                   ("AIR", 35), ("", 0), ("", 0), ("", 0), ("", 0)],
    "EQ":         [("LOW", 50), ("MID", 55), ("HIGH", 55),
                   ("", 0), ("", 0), ("", 0), ("", 0), ("", 0)],
    "Reverb":     [("DECAY", 30), ("TONE", 65), ("MIX", 25),
                   ("", 0), ("", 0), ("", 0), ("", 0), ("", 0)],
}


def _knob_defaults_for_effect_index(index):
    effect_name = GUI_EFFECTS[int(index)]
    return [default for _label, default in GUI_EFFECT_KNOBS[effect_name]]
