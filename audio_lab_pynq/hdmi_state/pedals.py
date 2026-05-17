"""Pedal model names, display labels, and notebook-side normalisation
helpers used by ``HdmiEffectStateMirror`` to drive the SELECTED FX /
PEDAL dropdown chip on the HDMI GUI.
"""

from audio_lab_pynq.hdmi_state.common import _normalize_index_or_name

PEDAL_MODELS = (
    "clean_boost",
    "tube_screamer",
    "rat",
    "ds1",
    "big_muff",
    "fuzz_face",
    "metal",
)

PEDAL_MODEL_LABELS = {
    "clean_boost": "CLEAN BOOST",
    "tube_screamer": "TUBE SCREAMER",
    "rat": "RAT",
    "ds1": "DS-1",
    "big_muff": "BIG MUFF",
    "fuzz_face": "FUZZ FACE",
    "metal": "METAL",
}

PEDAL_MODEL_TO_INDEX = dict((name, index)
                            for index, name in enumerate(PEDAL_MODELS))

PEDAL_MODEL_ALIASES = {
    "clean_boost": "clean_boost",
    "cleanboost": "clean_boost",
    "boost": "clean_boost",
    "tube_screamer": "tube_screamer",
    "tubescreamer": "tube_screamer",
    "ts": "tube_screamer",
    "rat": "rat",
    "ds1": "ds1",
    "ds_1": "ds1",
    "big_muff": "big_muff",
    "bigmuff": "big_muff",
    "muff": "big_muff",
    "fuzz_face": "fuzz_face",
    "fuzzface": "fuzz_face",
    "fuzz": "fuzz_face",
    "metal": "metal",
}


def normalize_pedal_model(value):
    return _normalize_index_or_name(
        value, PEDAL_MODELS, PEDAL_MODEL_ALIASES, "pedal")


def pedal_model_label(value):
    return PEDAL_MODEL_LABELS[normalize_pedal_model(value)]
