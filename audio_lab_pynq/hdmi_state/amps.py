"""Amp Simulator model names, character bytes, display labels, and
notebook-side normalisation helpers used by ``HdmiEffectStateMirror``.

The Clash side quantises ``amp_character`` into a 2-bit
``ampModelSel`` index that darkens the post-clip pre-LPF for the
higher-gain models. ``AMP_MODEL_CHARACTER`` is the convenience
mapping the notebook UI writes through ``set_guitar_effects(
amp_character=...)``.
"""

from audio_lab_pynq.hdmi_state.common import _normalize_index_or_name

AMP_MODELS = (
    "jc_clean",
    "clean_combo",
    "british_crunch",
    "high_gain_stack",
)

AMP_MODEL_LABELS = {
    "jc_clean": "JC CLEAN",
    "clean_combo": "CLEAN COMBO",
    "british_crunch": "BRITISH CRUNCH",
    "high_gain_stack": "HIGH GAIN STACK",
}

AMP_MODEL_CHARACTER = {
    "jc_clean": 10,
    "clean_combo": 35,
    "british_crunch": 60,
    "high_gain_stack": 85,
}

AMP_MODEL_TO_INDEX = dict((name, index)
                          for index, name in enumerate(AMP_MODELS))

AMP_MODEL_ALIASES = {
    "jc_clean": "jc_clean",
    "jcclean": "jc_clean",
    "jc": "jc_clean",
    "clean_combo": "clean_combo",
    "cleancombo": "clean_combo",
    "combo": "clean_combo",
    "british_crunch": "british_crunch",
    "britishcrunch": "british_crunch",
    "brit_crunch": "british_crunch",
    "brit": "british_crunch",
    "crunch": "british_crunch",
    "high_gain_stack": "high_gain_stack",
    "highgainstack": "high_gain_stack",
    "hi_gain_stack": "high_gain_stack",
    "higainstack": "high_gain_stack",
    "high_gain": "high_gain_stack",
    "higain": "high_gain_stack",
    "high": "high_gain_stack",
}


def normalize_amp_model(value):
    return _normalize_index_or_name(
        value, AMP_MODELS, AMP_MODEL_ALIASES, "amp")


def amp_model_label(value):
    return AMP_MODEL_LABELS[normalize_amp_model(value)]
