"""Per-effect constants and helpers for `hdmi_effect_state_mirror`.

The HDMI GUI state mirror layer used to live in a single 1727-line
``audio_lab_pynq/hdmi_effect_state_mirror.py``. The constant tables
(pedal / amp / cab model names + labels + aliases, SELECTED FX
categories, dropdown short labels), the normalisation helpers, the
GUI knob layout, and the ``ResourceSampler`` were extracted into the
per-effect submodules under this package so an AI agent reading just
the pedal mapping does not have to load the entire mirror file.

The ``HdmiEffectStateMirror`` class itself still lives in
``audio_lab_pynq/hdmi_effect_state_mirror.py`` and that module re-
exports every public symbol from here, so external callers keep using
``from audio_lab_pynq.hdmi_effect_state_mirror import X`` exactly as
before.
"""

from audio_lab_pynq.hdmi_state.knobs import (
    GUI_EFFECTS,
    GUI_EFFECT_KNOBS,
    _knob_defaults_for_effect_index,
)
from audio_lab_pynq.hdmi_state.pedals import (
    PEDAL_MODELS,
    PEDAL_MODEL_LABELS,
    PEDAL_MODEL_TO_INDEX,
    PEDAL_MODEL_ALIASES,
    normalize_pedal_model,
    pedal_model_label,
)
from audio_lab_pynq.hdmi_state.amps import (
    AMP_MODELS,
    AMP_MODEL_LABELS,
    AMP_MODEL_CHARACTER,
    AMP_MODEL_TO_INDEX,
    AMP_MODEL_ALIASES,
    normalize_amp_model,
    amp_model_label,
)
from audio_lab_pynq.hdmi_state.cabs import (
    CAB_MODELS,
    CAB_MODEL_LABELS,
    CAB_MODEL_TO_INDEX,
    CAB_MODEL_ALIASES,
    normalize_cab_model,
    cab_model_label,
)
from audio_lab_pynq.hdmi_state.selected_fx import (
    SELECTED_FX_CATEGORY,
    DROPDOWN_SHORT_LABELS,
    CANONICAL_SELECTED_FX,
    SELECTED_FX_ALIASES,
    METHOD_SELECTED_FX,
    GUITAR_KWARG_PREFIX_TO_SELECTED_FX,
    GUITAR_CATEGORY_PRIORITY,
    EFFECT_INDEX_BY_SELECTED_FX,
    normalize_selected_fx,
    canonical_selected_fx,
    selected_fx_category,
    dropdown_short_label,
    dropdown_label_for,
    dropdown_visible_for,
    _normalize_text,
)
from audio_lab_pynq.hdmi_state.resource_sampler import (
    ResourceSampler,
    STATIC_PL_UTILIZATION,
    _parse_proc_meminfo_text,
    _parse_proc_status_text,
    _parse_proc_stat_cpu_line,
    _parse_proc_self_stat_times,
)
from audio_lab_pynq.hdmi_state.common import (
    _clamp_percent,
    _eq_display_value,
    _cab_model_display_value,
    _has_asserted_vdma_error,
    _model_key,
    _normalize_index_or_name,
)
