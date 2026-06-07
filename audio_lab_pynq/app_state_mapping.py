"""Shared compact-v2 AppState effect-order helpers.

The HDMI GUI, encoder live-apply, and footswitch runtime all interpret
``AppState.effect_on`` as a list indexed by the compact-v2 ``EFFECTS``
order. Keep the index contract here so inserting an effect cannot leave
one control path on an older layout.
"""

EFFECT_NOISE_SUP = "Noise Sup"
EFFECT_COMPRESSOR = "Compressor"
EFFECT_WAH = "Wah"
EFFECT_OVERDRIVE = "Overdrive"
EFFECT_DISTORTION = "Distortion"
EFFECT_AMP = "Amp Sim"
EFFECT_CAB = "Cab IR"
EFFECT_EQ = "EQ"
EFFECT_REVERB = "Reverb"

EFFECTS = (
    EFFECT_NOISE_SUP,
    EFFECT_COMPRESSOR,
    EFFECT_WAH,
    EFFECT_OVERDRIVE,
    EFFECT_DISTORTION,
    EFFECT_AMP,
    EFFECT_CAB,
    EFFECT_EQ,
    EFFECT_REVERB,
)

EFFECT_ON_INDEX = {name: idx for idx, name in enumerate(EFFECTS)}

IDX_NOISE_SUP = EFFECT_ON_INDEX[EFFECT_NOISE_SUP]
IDX_COMPRESSOR = EFFECT_ON_INDEX[EFFECT_COMPRESSOR]
IDX_WAH = EFFECT_ON_INDEX[EFFECT_WAH]
IDX_OVERDRIVE = EFFECT_ON_INDEX[EFFECT_OVERDRIVE]
IDX_DISTORTION = EFFECT_ON_INDEX[EFFECT_DISTORTION]
IDX_AMP = EFFECT_ON_INDEX[EFFECT_AMP]
IDX_CAB = EFFECT_ON_INDEX[EFFECT_CAB]
IDX_EQ = EFFECT_ON_INDEX[EFFECT_EQ]
IDX_REVERB = EFFECT_ON_INDEX[EFFECT_REVERB]
NUM_EFFECTS = len(EFFECTS)


def effect_index(effect_name, default=-1):
    """Return the AppState.effect_on index for ``effect_name``."""
    return EFFECT_ON_INDEX.get(effect_name, default)


def effect_name(index, default=None):
    """Return the compact-v2 effect name at ``index``."""
    try:
        idx = int(index)
    except Exception:
        return default
    if 0 <= idx < NUM_EFFECTS:
        return EFFECTS[idx]
    return default


def ensure_effect_on_length(values, fill=False):
    """Return an effect_on list exactly ``NUM_EFFECTS`` long."""
    out = list(values or [])
    if len(out) < NUM_EFFECTS:
        out = out + [bool(fill)] * (NUM_EFFECTS - len(out))
    return out[:NUM_EFFECTS]


def effect_enabled(state, effect_name, default=False):
    """Read ``state.effect_on`` by effect name."""
    idx = effect_index(effect_name)
    values = list(getattr(state, "effect_on", []) or [])
    if 0 <= idx < len(values):
        return bool(values[idx])
    return bool(default)


def knob_list(state, effect_name, fallback):
    """Read ``state.all_knob_values[effect_name]`` with a length guard."""
    values_by_effect = getattr(state, "all_knob_values", {}) or {}
    values = values_by_effect.get(effect_name)
    if values is None or len(values) < len(fallback):
        return list(fallback)
    return list(values)
