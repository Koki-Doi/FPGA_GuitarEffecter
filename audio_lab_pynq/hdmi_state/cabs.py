"""Cabinet IR model names, display labels, and helpers."""

from audio_lab_pynq.effect_catalog import (
    CAB_MODELS,
    CAB_MODEL_LABELS,
    CAB_MODEL_TO_INDEX,
)
from audio_lab_pynq.hdmi_state.common import _normalize_index_or_name

CAB_MODEL_ALIASES = {
    "0": "1x12",
    "model_0": "1x12",
    "model0": "1x12",
    "1x12": "1x12",
    "1x12_open": "1x12",
    "open_1x12": "1x12",
    "1x12_combo": "1x12",
    "1": "2x12",
    "model_1": "2x12",
    "model1": "2x12",
    "2x12": "2x12",
    "2x12_combo": "2x12",
    "2x12_black": "2x12",
    "black_2x12": "2x12",
    "2": "4x12",
    "model_2": "4x12",
    "model2": "4x12",
    "4x12": "4x12",
    "4x12_closed": "4x12",
    "closed_4x12": "4x12",
    "4x12_british": "4x12",
    "british_4x12": "4x12",
}


def normalize_cab_model(value):
    return _normalize_index_or_name(
        value, CAB_MODELS, CAB_MODEL_ALIASES, "cab")


def cab_model_label(value):
    return CAB_MODEL_LABELS[normalize_cab_model(value)]
