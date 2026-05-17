"""HDMI mirror knob layout aliases.

The canonical catalog lives in ``audio_lab_pynq.effect_catalog``. This file
keeps the historical ``GUI_EFFECTS`` / ``GUI_EFFECT_KNOBS`` names used by
``HdmiEffectStateMirror`` and older tests.
"""

from audio_lab_pynq.effect_catalog import (
    EFFECTS as GUI_EFFECTS,
    MIRROR_EFFECT_KNOBS as GUI_EFFECT_KNOBS,
)


def _knob_defaults_for_effect_index(index):
    effect_name = GUI_EFFECTS[int(index)]
    return [default for _label, default in GUI_EFFECT_KNOBS[effect_name]]
