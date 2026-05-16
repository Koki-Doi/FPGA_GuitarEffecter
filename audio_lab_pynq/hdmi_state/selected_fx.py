"""SELECTED FX classification + dropdown chip helpers used by
``HdmiEffectStateMirror`` to drive the [model ▼] chip on the
compact-v2 800x480 HDMI panel, the ``AppState.active_model_category``
field, and the Notebook ipywidgets category dropdown.
"""

from audio_lab_pynq.hdmi_state.pedals import PEDAL_MODEL_LABELS  # noqa: F401
from audio_lab_pynq.hdmi_state.amps import AMP_MODEL_LABELS      # noqa: F401
from audio_lab_pynq.hdmi_state.cabs import CAB_MODEL_LABELS      # noqa: F401


# Phase 6C: SELECTED FX -> model category. Drives the [model ▼] chip
# rendered next to SELECTED FX on the HDMI GUI, the AppState
# ``active_model_category`` field, and the Notebook ipywidgets
# category dropdown.
SELECTED_FX_CATEGORY = {
    "CLEAN BOOST": "PEDAL",
    "TUBE SCREAMER": "PEDAL",
    "RAT": "PEDAL",
    "DS-1": "PEDAL",
    "BIG MUFF": "PEDAL",
    "FUZZ FACE": "PEDAL",
    "METAL": "PEDAL",
    "DISTORTION": "PEDAL",
    "OVERDRIVE": "OVERDRIVE",
    "AMP SIM": "AMP",
    "CAB": "CAB",
    "REVERB": "REVERB",
    "EQ": "EQ",
    "COMPRESSOR": "COMPRESSOR",
    "NOISE SUPPRESSOR": "NOISE SUPPRESSOR",
    "SAFE BYPASS": "SAFE",
    "PRESET": "PRESET",
}

# Phase 6C: short labels for the [model ▼] chip drawn inside SELECTED FX.
# The chip space on the 800x480 LCD is tight; long model names overflow
# the fx panel without truncation.
DROPDOWN_SHORT_LABELS = {
    "CLEAN BOOST": "CLN BOOST",
    "TUBE SCREAMER": "TUBE SCRMR",
    "RAT": "RAT",
    "DS-1": "DS-1",
    "BIG MUFF": "BIG MUFF",
    "FUZZ FACE": "FUZZ",
    "METAL": "METAL",
    "JC CLEAN": "JC CLEAN",
    "CLEAN COMBO": "CLN COMBO",
    "BRITISH CRUNCH": "BRIT CRUNCH",
    "HIGH GAIN STACK": "HI-GAIN",
    "1X12 OPEN": "1x12 OPN",
    "2X12 COMBO": "2x12 CMB",
    "4X12 CLOSED": "4x12 CLS",
    "SAFE BYPASS": "SAFE",
    "PRESET": "PRESET",
    "REVERB": "REVERB",
    "EQ": "EQ",
    "COMPRESSOR": "COMP",
    "NOISE SUPPRESSOR": "NOISE SUP",
    "OVERDRIVE": "OD",
}


CANONICAL_SELECTED_FX = {
    "PRESET": "PRESET",
    "SAFE BYPASS": "SAFE BYPASS",
    "NOISE SUPPRESSOR": "NOISE SUPPRESSOR",
    "COMPRESSOR": "COMPRESSOR",
    "OVERDRIVE": "OVERDRIVE",
    "DISTORTION": "DISTORTION",
    "CLEAN BOOST": "CLEAN BOOST",
    "TUBE SCREAMER": "TUBE SCREAMER",
    "RAT": "RAT",
    "DS 1": "DS-1",
    "DS-1": "DS-1",
    "BIG MUFF": "BIG MUFF",
    "FUZZ FACE": "FUZZ FACE",
    "METAL": "METAL",
    "AMP SIM": "AMP SIM",
    "CAB": "CAB",
    "EQ": "EQ",
    "REVERB": "REVERB",
}

SELECTED_FX_ALIASES = {
    "NS": "NOISE SUPPRESSOR",
    "NOISE SUP": "NOISE SUPPRESSOR",
    "NOISE GATE": "NOISE SUPPRESSOR",
    "NOISE SUPPRESSOR": "NOISE SUPPRESSOR",
    "COMP": "COMPRESSOR",
    "CMP": "COMPRESSOR",
    "COMPRESSOR": "COMPRESSOR",
    "OD": "OVERDRIVE",
    "OVER DRIVE": "OVERDRIVE",
    "OVERDRIVE": "OVERDRIVE",
    "DIST": "DISTORTION",
    "DISTORTION": "DISTORTION",
    "CLEAN BOOST": "CLEAN BOOST",
    "CLEANBOOST": "CLEAN BOOST",
    "BOOST": "CLEAN BOOST",
    "TUBE SCREAMER": "TUBE SCREAMER",
    "TUBESCREAMER": "TUBE SCREAMER",
    "TS": "TUBE SCREAMER",
    "RAT": "RAT",
    "DS 1": "DS-1",
    "DS1": "DS-1",
    "DS-1": "DS-1",
    "BIG MUFF": "BIG MUFF",
    "BIGMUFF": "BIG MUFF",
    "MUFF": "BIG MUFF",
    "FUZZ FACE": "FUZZ FACE",
    "FUZZFACE": "FUZZ FACE",
    "FUZZ": "FUZZ FACE",
    "METAL": "METAL",
    "AMP": "AMP SIM",
    "AMP SIM": "AMP SIM",
    "AMP SIMULATOR": "AMP SIM",
    "CAB": "CAB",
    "CAB IR": "CAB",
    "CABINET": "CAB",
    "EQ": "EQ",
    "EQUALIZER": "EQ",
    "REVERB": "REVERB",
    "RVB": "REVERB",
    "PRESET": "PRESET",
    "CHAIN PRESET": "PRESET",
    "SAFE BYPASS": "SAFE BYPASS",
    "BYPASS": "SAFE BYPASS",
}

EFFECT_INDEX_BY_SELECTED_FX = {
    "NOISE SUPPRESSOR": 0,
    "COMPRESSOR": 1,
    "OVERDRIVE": 2,
    "DISTORTION": 3,
    "CLEAN BOOST": 3,
    "TUBE SCREAMER": 3,
    "RAT": 3,
    "DS-1": 3,
    "BIG MUFF": 3,
    "FUZZ FACE": 3,
    "METAL": 3,
    "AMP SIM": 4,
    "CAB": 5,
    "EQ": 6,
    "REVERB": 7,
}

METHOD_SELECTED_FX = {
    "safe_bypass": "SAFE BYPASS",
    "apply_chain_preset": "PRESET",
    "set_noise_suppressor_settings": "NOISE SUPPRESSOR",
    "set_compressor_settings": "COMPRESSOR",
    "set_distortion_settings": "DISTORTION",
    "clear_distortion_pedals": "DISTORTION",
}

GUITAR_KWARG_PREFIX_TO_SELECTED_FX = (
    ("noise_gate_", "NOISE SUPPRESSOR"),
    ("noise_gate", "NOISE SUPPRESSOR"),
    ("overdrive_", "OVERDRIVE"),
    ("overdrive", "OVERDRIVE"),
    ("distortion_", "DISTORTION"),
    ("distortion", "DISTORTION"),
    ("rat_", "RAT"),
    ("rat", "RAT"),
    ("amp_", "AMP SIM"),
    ("amp", "AMP SIM"),
    ("cab_", "CAB"),
    ("cab", "CAB"),
    ("eq_", "EQ"),
    ("eq", "EQ"),
    ("reverb_", "REVERB"),
    ("reverb", "REVERB"),
)

GUITAR_CATEGORY_PRIORITY = (
    "REVERB", "CAB", "AMP SIM", "EQ", "RAT", "OVERDRIVE",
    "DISTORTION", "COMPRESSOR", "NOISE SUPPRESSOR",
)


def _normalize_text(value):
    text = str(value or "").replace("_", " ").replace("-", " ")
    return " ".join(text.strip().upper().split())


def normalize_selected_fx(value):
    """Normalize display strings for SELECTED FX comparisons."""
    normalized = _normalize_text(value)
    return SELECTED_FX_ALIASES.get(normalized, normalized)


def canonical_selected_fx(value):
    normalized = normalize_selected_fx(value)
    return CANONICAL_SELECTED_FX.get(normalized, normalized or "")


def selected_fx_category(value):
    """Phase 6C: classify a SELECTED FX label by model category.

    Returns one of ``"PEDAL"``, ``"AMP"``, ``"CAB"``, ``"REVERB"``,
    ``"EQ"``, ``"COMPRESSOR"``, ``"NOISE SUPPRESSOR"``, ``"OVERDRIVE"``,
    ``"PRESET"``, or ``"SAFE"``. Unknown labels fall back to the
    canonical string.
    """
    canonical = canonical_selected_fx(value)
    return SELECTED_FX_CATEGORY.get(canonical, canonical)


def dropdown_short_label(value):
    """Phase 6C: shorten a model/effect label so it fits the dropdown chip.

    Falls back to the upper-cased input. The chip width is ~150 px on
    the compact-v2 800x480 fx panel, so anything past ~12 characters
    gets clipped.
    """
    text = str(value or "").strip().upper()
    return DROPDOWN_SHORT_LABELS.get(text, text)


def dropdown_label_for(selected_fx, pedal_label, amp_label, cab_label):
    """Phase 6D: pick the [model ▼] marker text for the SELECTED FX panel.

    The dropdown marker is only shown for model-driven effects
    (PEDAL / AMP / CAB) and stays hidden for REVERB / EQ / COMPRESSOR /
    NOISE SUPPRESSOR / SAFE / PRESET / OVERDRIVE. This helper returns
    the matching model label for PEDAL / AMP / CAB and an empty string
    otherwise so the renderer and AppState mirror can use the
    truthiness as a visibility flag.
    """
    canonical = canonical_selected_fx(selected_fx)
    category = SELECTED_FX_CATEGORY.get(canonical, canonical)
    if category == "PEDAL":
        return str(pedal_label or "").upper()
    if category == "AMP":
        return str(amp_label or "").upper()
    if category == "CAB":
        return str(cab_label or "").upper()
    return ""


def dropdown_visible_for(selected_fx):
    """Phase 6D: True when the SELECTED FX has a PEDAL/AMP/CAB dropdown."""
    canonical = canonical_selected_fx(selected_fx)
    category = SELECTED_FX_CATEGORY.get(canonical, canonical)
    return category in ("PEDAL", "AMP", "CAB")
