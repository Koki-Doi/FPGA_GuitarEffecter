"""Notebook-driven AudioLab effect state mirror for the HDMI GUI.

``HdmiEffectStateMirror`` is deliberately one-way:

Notebook helper -> AudioLabOverlay existing API -> AppState display update
-> 800x480 HDMI redraw.

It does not make the GUI interactive, does not poll GPIOs every frame, and
does not monkey-patch ``AudioLabOverlay``. The wrapper exists because direct
``ovl.set_*`` calls do not carry enough context to infer which effect the
user last edited.

The constant tables (pedal / amp / cab model names + labels + aliases,
SELECTED FX categories, dropdown short labels), the normalisation helpers,
the GUI knob layout, and the ``ResourceSampler`` were extracted into
``audio_lab_pynq/hdmi_state/`` so an AI agent reading just the pedal
mapping does not need the full mirror class. The historical
``audio_lab_pynq.hdmi_effect_state_mirror`` module re-exports this module
so existing callers keep working.
"""
from __future__ import print_function

import inspect
import json
import os
import time

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


class HdmiEffectStateMirror(object):
    """Mirror Notebook-driven effect edits onto the HDMI GUI AppState."""

    METHOD_SELECTED_FX = METHOD_SELECTED_FX
    SET_GUITAR_EFFECTS_PRIORITY = GUITAR_CATEGORY_PRIORITY

    def __init__(self, overlay, hdmi_backend, app_state, renderer,
                 theme=None, variant="compact-v2", placement="manual",
                 offset_x=0, offset_y=0, selected_fx_check_enabled=True,
                 render_cache=None):
        self.overlay = overlay
        self.hdmi_backend = hdmi_backend
        self.app_state = app_state
        self.renderer = renderer
        self.theme = theme
        self.variant = variant
        self.placement = placement
        self.offset_x = int(offset_x)
        self.offset_y = int(offset_y)
        self.selected_fx_check_enabled = bool(selected_fx_check_enabled)
        self.render_cache = render_cache

        self.last_edited_effect = None
        self.selected_fx_history = []
        self.render_history = []
        self.last_render_info = {}
        self.last_selected_fx_expected = None
        self.last_selected_fx_actual = None

        dist_idx = int(getattr(self.app_state, "dist_model_idx", 1) or 0)
        amp_idx = int(getattr(self.app_state, "amp_model_idx", 2) or 0)
        cab_idx = int(getattr(self.app_state, "cab_model_idx", 2) or 0)
        self.current_pedal_model = PEDAL_MODELS[
            max(0, min(len(PEDAL_MODELS) - 1, dist_idx))]
        self.current_amp_model = AMP_MODELS[
            max(0, min(len(AMP_MODELS) - 1, amp_idx))]
        self.current_cab_model = CAB_MODELS[
            max(0, min(len(CAB_MODELS) - 1, cab_idx))]
        self.current_pedal_label = PEDAL_MODEL_LABELS[self.current_pedal_model]
        self.current_amp_label = AMP_MODEL_LABELS[self.current_amp_model]
        self.current_cab_label = CAB_MODEL_LABELS[self.current_cab_model]
        self.active_pedals = []
        self.resource_sampler = ResourceSampler()
        self.last_resource_sample = self.resource_sampler.sample()
        self._sync_model_state_to_app_state()
        self._update_dropdown_app_state()

    # ---- SELECTED FX -------------------------------------------------
    def get_selected_fx_actual(self):
        value = getattr(self.app_state, "selected_fx", None)
        if value is not None and str(value).strip():
            return str(value).strip()
        idx = int(getattr(self.app_state, "selected_effect", 0) or 0)
        if idx < 0:
            idx = 0
        if idx >= len(GUI_EFFECTS):
            idx = len(GUI_EFFECTS) - 1
        return GUI_EFFECTS[idx]

    def mark_selected_fx(self, effect_name, reason=None):
        display = canonical_selected_fx(effect_name)
        if not display:
            raise ValueError("effect_name must not be empty")
        self.last_edited_effect = display
        self._set_effect_index_for_selected_fx(display)
        setattr(self.app_state, "selected_fx", display)
        self._update_dropdown_app_state(display)
        self.last_selected_fx_actual = self.get_selected_fx_actual()
        entry = {
            "index": len(self.selected_fx_history) + 1,
            "time_s": time.time(),
            "selected_fx": display,
            "actual": self.last_selected_fx_actual,
            "reason": reason,
        }
        self.selected_fx_history.append(entry)
        return display

    def assert_selected_fx(self, expected):
        actual = self.get_selected_fx_actual()
        self.last_selected_fx_expected = expected
        self.last_selected_fx_actual = actual
        if not self.selected_fx_check_enabled:
            return True
        if normalize_selected_fx(expected) != normalize_selected_fx(actual):
            raise AssertionError(
                "SELECTED FX mismatch: expected {!r}, actual {!r}".format(
                    expected, actual))
        return True

    # ---- AppState helpers ------------------------------------------
    def _sync_model_state_to_app_state(self, active_model_category=None):
        self.current_pedal_label = PEDAL_MODEL_LABELS[self.current_pedal_model]
        self.current_amp_label = AMP_MODEL_LABELS[self.current_amp_model]
        self.current_cab_label = CAB_MODEL_LABELS[self.current_cab_model]

        self.app_state.dist_model_idx = PEDAL_MODEL_TO_INDEX[self.current_pedal_model]
        self.app_state.amp_model_idx = AMP_MODEL_TO_INDEX[self.current_amp_model]
        self.app_state.cab_model_idx = CAB_MODEL_TO_INDEX[self.current_cab_model]
        setattr(self.app_state, "pedal_model", self.current_pedal_model)
        setattr(self.app_state, "amp_model", self.current_amp_model)
        setattr(self.app_state, "cab_model", self.current_cab_model)
        setattr(self.app_state, "pedal_model_label", self.current_pedal_label)
        setattr(self.app_state, "amp_model_label", self.current_amp_label)
        setattr(self.app_state, "cab_model_label", self.current_cab_label)
        setattr(self.app_state, "active_pedals", list(self.active_pedals))
        if active_model_category is not None:
            setattr(self.app_state, "active_model_category",
                    str(active_model_category).upper())
        elif not hasattr(self.app_state, "active_model_category"):
            setattr(self.app_state, "active_model_category", "")
        setattr(self.app_state, "model_slots", {
            "pedal": [
                {
                    "name": name,
                    "label": PEDAL_MODEL_LABELS[name],
                    "active": name == self.current_pedal_model,
                }
                for name in PEDAL_MODELS
            ],
            "amp": [
                {
                    "name": name,
                    "label": AMP_MODEL_LABELS[name],
                    "active": name == self.current_amp_model,
                }
                for name in AMP_MODELS
            ],
            "cab": [
                {
                    "name": name,
                    "label": CAB_MODEL_LABELS[name],
                    "active": name == self.current_cab_model,
                }
                for name in CAB_MODELS
            ],
        })
        self._update_dropdown_app_state()

    def _update_dropdown_app_state(self, selected_fx=None):
        """Phase 6D: keep selected_model_category / dropdown_label on AppState.

        Called from ``mark_selected_fx`` and ``_sync_model_state_to_app_state``
        so the HDMI GUI always sees the conditional [model ▼] marker in
        sync with both the last edited model and the last edited
        effect. Non-model effects (REVERB / EQ / COMPRESSOR / NOISE
        SUPPRESSOR / SAFE / PRESET / OVERDRIVE) yield an empty
        ``dropdown_label`` so the renderer hides the marker.
        """
        if selected_fx is None:
            selected_fx = self.get_selected_fx_actual()
        canonical = canonical_selected_fx(selected_fx)
        category = SELECTED_FX_CATEGORY.get(canonical, canonical)
        label = dropdown_label_for(
            canonical,
            self.current_pedal_label,
            self.current_amp_label,
            self.current_cab_label)
        short = dropdown_short_label(label) if label else ""
        visible = dropdown_visible_for(canonical)
        setattr(self.app_state, "selected_model_category", category)
        setattr(self.app_state, "dropdown_label", label)
        setattr(self.app_state, "dropdown_short_label", short)
        setattr(self.app_state, "selected_model_dropdown_visible",
                bool(visible))

    def _set_current_pedal_model(self, model, enabled=True):
        self.current_pedal_model = normalize_pedal_model(model)
        if enabled:
            self.active_pedals = [self.current_pedal_model]
        else:
            self.active_pedals = []
        self._sync_model_state_to_app_state("PEDAL")

    def _set_current_amp_model(self, model):
        self.current_amp_model = normalize_amp_model(model)
        self._sync_model_state_to_app_state("AMP")

    def _set_current_cab_model(self, model):
        self.current_cab_model = normalize_cab_model(model)
        self._sync_model_state_to_app_state("CAB")

    def _amp_model_from_character(self, value):
        try:
            v = float(value)
        except Exception:
            v = AMP_MODEL_CHARACTER[self.current_amp_model]
        if v < 25:
            return "jc_clean"
        if v < 50:
            return "clean_combo"
        if v < 75:
            return "british_crunch"
        return "high_gain_stack"

    def _set_effect_index_for_selected_fx(self, effect_name):
        canonical = canonical_selected_fx(effect_name)
        idx = EFFECT_INDEX_BY_SELECTED_FX.get(canonical)
        if idx is None:
            return None
        current = int(getattr(self.app_state, "selected_effect", idx) or idx)
        if current != idx or len(getattr(self.app_state, "knob_values", []) or []) != 8:
            self.app_state.selected_effect = idx
            self.app_state.knob_values = _knob_defaults_for_effect_index(idx)
        else:
            self.app_state.selected_effect = idx
        return idx

    def _set_effect_enabled(self, effect_name, enabled):
        idx = EFFECT_INDEX_BY_SELECTED_FX.get(canonical_selected_fx(effect_name))
        if idx is None:
            return
        values = list(getattr(self.app_state, "effect_on", []) or [])
        while len(values) < len(GUI_EFFECTS):
            values.append(False)
        values[idx] = bool(enabled)
        self.app_state.effect_on = values[:len(GUI_EFFECTS)]

    def _set_knobs(self, effect_name, updates):
        idx = self._set_effect_index_for_selected_fx(effect_name)
        if idx is None:
            return
        values = list(getattr(self.app_state, "knob_values", []) or [])
        if len(values) != 8:
            values = _knob_defaults_for_effect_index(idx)
        for knob_index, value in updates.items():
            if 0 <= int(knob_index) < 8:
                values[int(knob_index)] = _clamp_percent(value)
        self.app_state.knob_values = values[:8]

    def _apply_noise_suppressor_state(self, kwargs):
        updates = {}
        for key, idx in (("threshold", 0), ("decay", 1), ("damp", 2)):
            if key in kwargs and kwargs[key] is not None:
                updates[idx] = kwargs[key]
        self._set_knobs("NOISE SUPPRESSOR", updates)
        if "enabled" in kwargs and kwargs["enabled"] is not None:
            self._set_effect_enabled("NOISE SUPPRESSOR", kwargs["enabled"])

    def _apply_compressor_state(self, kwargs):
        updates = {}
        for key, idx in (("threshold", 0), ("ratio", 1),
                         ("response", 2), ("makeup", 3)):
            if key in kwargs and kwargs[key] is not None:
                updates[idx] = kwargs[key]
        self._set_knobs("COMPRESSOR", updates)
        if "enabled" in kwargs and kwargs["enabled"] is not None:
            self._set_effect_enabled("COMPRESSOR", kwargs["enabled"])

    def _apply_distortion_state(self, kwargs, enabled=None):
        updates = {}
        for key, idx in (("drive", 0), ("tone", 1), ("level", 2),
                         ("bias", 3), ("tight", 4), ("mix", 5)):
            if key in kwargs and kwargs[key] is not None:
                updates[idx] = kwargs[key]
        self._set_knobs("DISTORTION", updates)
        if kwargs.get("pedal") is not None:
            self._set_current_pedal_model(kwargs["pedal"], enabled=True)
        elif kwargs.get("pedals") is not None:
            pedals = kwargs.get("pedals")
            selected = None
            if isinstance(pedals, dict):
                for name, is_enabled in pedals.items():
                    if is_enabled:
                        selected = name
            else:
                try:
                    for name in pedals:
                        selected = name
                except TypeError:
                    selected = pedals
            if selected is not None:
                self._set_current_pedal_model(selected, enabled=True)
        if enabled is not None:
            self._set_effect_enabled("DISTORTION", enabled)
            if not enabled:
                self.active_pedals = []
                self._sync_model_state_to_app_state()
        elif kwargs.get("pedal") is not None or kwargs.get("pedals") is not None:
            self._set_effect_enabled("DISTORTION", True)

    def _apply_preset_to_app_state(self, name):
        try:
            from audio_lab_pynq import effect_presets
        except Exception:
            effect_presets = None
        if effect_presets is None or name not in effect_presets.CHAIN_PRESETS:
            self.app_state.preset_name = str(name).upper()
            return

        names = list(effect_presets.CHAIN_PRESETS.keys())
        preset = effect_presets.CHAIN_PRESETS[name]
        idx = names.index(name)
        self.app_state.preset_idx = idx
        self.app_state.preset_id = "{:02d}A".format(idx + 1)
        self.app_state.preset_name = str(name).upper()
        sections = [
            ("noise_suppressor", "NOISE SUPPRESSOR"),
            ("compressor", "COMPRESSOR"),
            ("overdrive", "OVERDRIVE"),
            ("distortion", "DISTORTION"),
            ("amp", "AMP SIM"),
            ("cab", "CAB"),
            ("eq", "EQ"),
            ("reverb", "REVERB"),
        ]
        for section_name, selected_fx in sections:
            section = preset.get(section_name, {})
            self._set_effect_enabled(selected_fx, bool(section.get("enabled", False)))
        dist = preset.get("distortion", {})
        if dist.get("pedal"):
            self._set_current_pedal_model(
                dist.get("pedal"), enabled=bool(dist.get("enabled", False)))
        else:
            self.active_pedals = []
        amp = preset.get("amp", {})
        if "character" in amp:
            self.current_amp_model = self._amp_model_from_character(
                amp.get("character"))
        cab = preset.get("cab", {})
        if "model" in cab:
            cab_idx = max(0, min(len(CAB_MODELS) - 1,
                                 int(cab.get("model"))))
            self.current_cab_model = CAB_MODELS[cab_idx]
        self._sync_model_state_to_app_state()

    def _apply_safe_bypass_to_app_state(self):
        self.app_state.preset_idx = 0
        self.app_state.preset_id = "01A"
        self.app_state.preset_name = "SAFE BYPASS"
        self.app_state.effect_on = [False] * len(GUI_EFFECTS)
        self.active_pedals = []
        self._sync_model_state_to_app_state()

    def _category_from_guitar_kwarg(self, key):
        key_norm = str(key)
        for prefix, category in GUITAR_KWARG_PREFIX_TO_SELECTED_FX:
            if key_norm == prefix or key_norm.startswith(prefix):
                return category
        return None

    def _selected_fx_from_guitar_kwargs(self, kwargs):
        selected = None
        for key in kwargs.keys():
            category = self._category_from_guitar_kwarg(key)
            if category is not None:
                selected = category
        if selected is not None:
            return selected
        present = set()
        for key in kwargs.keys():
            category = self._category_from_guitar_kwarg(key)
            if category is not None:
                present.add(category)
        for category in GUITAR_CATEGORY_PRIORITY:
            if category in present:
                return category
        return None

    def _apply_guitar_effects_state(self, kwargs, selected_fx=None):
        values = dict(kwargs)
        if "noise_gate_on" in values:
            self._set_effect_enabled("NOISE SUPPRESSOR", values["noise_gate_on"])
        if "overdrive_on" in values:
            self._set_effect_enabled("OVERDRIVE", values["overdrive_on"])
        if "distortion_on" in values:
            self._set_effect_enabled("DISTORTION", values["distortion_on"])
            if not values["distortion_on"]:
                self.active_pedals = []
        if "rat_on" in values and values["rat_on"]:
            self._set_effect_enabled("RAT", True)
            self._set_current_pedal_model("rat", enabled=True)
        if "amp_on" in values:
            self._set_effect_enabled("AMP SIM", values["amp_on"])
        if "cab_on" in values:
            self._set_effect_enabled("CAB", values["cab_on"])
        if "eq_on" in values:
            self._set_effect_enabled("EQ", values["eq_on"])
        if "reverb_on" in values:
            self._set_effect_enabled("REVERB", values["reverb_on"])

        if "distortion_pedal_mask" in values:
            try:
                mask = int(values["distortion_pedal_mask"]) & 0x7F
            except Exception:
                mask = 0
            selected = None
            for index, name in enumerate(PEDAL_MODELS):
                if mask & (1 << index):
                    selected = name
            if selected is not None:
                self._set_current_pedal_model(selected, enabled=True)
        if "amp_character" in values:
            self.current_amp_model = self._amp_model_from_character(
                values["amp_character"])
            self._sync_model_state_to_app_state("AMP")
        if "cab_model" in values:
            cab_idx = max(0, min(len(CAB_MODELS) - 1,
                                 int(values["cab_model"])))
            self.current_cab_model = CAB_MODELS[cab_idx]
            self._sync_model_state_to_app_state("CAB")

        if selected_fx is None:
            return
        selected_fx = canonical_selected_fx(selected_fx)
        updates = {}
        if selected_fx == "NOISE SUPPRESSOR":
            if "noise_gate_threshold" in values:
                updates[0] = values["noise_gate_threshold"]
            self._set_knobs(selected_fx, updates)
        elif selected_fx == "OVERDRIVE":
            for key, idx in (("overdrive_drive", 0), ("overdrive_tone", 1),
                             ("overdrive_level", 2)):
                if key in values:
                    updates[idx] = values[key]
            self._set_knobs(selected_fx, updates)
        elif selected_fx == "DISTORTION":
            for key, idx in (("distortion", 0), ("distortion_drive", 0),
                             ("distortion_tone", 1), ("distortion_level", 2),
                             ("distortion_bias", 3), ("distortion_tight", 4),
                             ("distortion_mix", 5)):
                if key in values:
                    updates[idx] = values[key]
            self._set_knobs(selected_fx, updates)
        elif selected_fx == "RAT":
            for key, idx in (("rat_drive", 0), ("rat_filter", 1),
                             ("rat_level", 2), ("rat_mix", 3)):
                if key in values:
                    updates[idx] = values[key]
            self._set_knobs(selected_fx, updates)
        elif selected_fx == "AMP SIM":
            # Phase 6E: PRESENCE and RESONANCE join the AMP knob set at
            # indices 4 and 5; MASTER and CHARACTER move to 6 and 7. The
            # DSP already wires them via axi_gpio_amp.ctrlC/ctrlD on the
            # Amp.hs side -- no bit/hwh change.
            for key, idx in (("amp_input_gain", 0), ("amp_bass", 1),
                             ("amp_middle", 2), ("amp_treble", 3),
                             ("amp_presence", 4), ("amp_resonance", 5),
                             ("amp_master", 6), ("amp_character", 7)):
                if key in values:
                    updates[idx] = values[key]
            self._set_knobs(selected_fx, updates)
        elif selected_fx == "CAB":
            for key, idx in (("cab_mix", 0), ("cab_level", 1),
                             ("cab_air", 3)):
                if key in values:
                    updates[idx] = values[key]
            if "cab_model" in values:
                updates[2] = _cab_model_display_value(values["cab_model"])
            self._set_knobs(selected_fx, updates)
        elif selected_fx == "EQ":
            for key, idx in (("eq_low", 0), ("eq_mid", 1), ("eq_high", 2)):
                if key in values:
                    updates[idx] = _eq_display_value(values[key])
            self._set_knobs(selected_fx, updates)
        elif selected_fx == "REVERB":
            for key, idx in (("reverb_decay", 0), ("reverb_tone", 1),
                             ("reverb_mix", 2)):
                if key in values:
                    updates[idx] = values[key]
            self._set_knobs(selected_fx, updates)

    # ---- render ------------------------------------------------------
    def _renderer_kwargs(self):
        kwargs = {
            "variant": self.variant,
            "placement_label": "p={} off=({:+d},{:+d})".format(
                self.placement, self.offset_x, self.offset_y),
        }
        if self.theme is not None:
            kwargs["theme"] = self.theme
        if self.render_cache is not None:
            kwargs["cache"] = self.render_cache
        try:
            sig = inspect.signature(self.renderer)
            params = sig.parameters
            accepts_kwargs = any(
                p.kind == inspect.Parameter.VAR_KEYWORD
                for p in params.values())
            if accepts_kwargs:
                return kwargs
            return {k: v for k, v in kwargs.items() if k in params}
        except Exception:
            return kwargs

    def _backend_started(self):
        if bool(getattr(self.hdmi_backend, "_started", False)):
            return True
        try:
            return bool((self.hdmi_backend.status() or {}).get("started", False))
        except Exception:
            return False

    def render(self, reason=None, expected_selected_fx=None):
        if expected_selected_fx is not None:
            self.assert_selected_fx(expected_selected_fx)

        t0 = time.time()
        frame = self.renderer(self.app_state, **self._renderer_kwargs())
        render_s = time.time() - t0

        t1 = time.time()
        meta = None
        if self.hdmi_backend is not None:
            if self._backend_started():
                meta = self.hdmi_backend.write_frame(
                    frame, placement=self.placement,
                    offset_x=self.offset_x, offset_y=self.offset_y)
            else:
                started = self.hdmi_backend.start(
                    frame, placement=self.placement,
                    offset_x=self.offset_x, offset_y=self.offset_y)
                meta = started if isinstance(started, dict) else None
        backend_update_s = time.time() - t1

        status = {}
        errors = {}
        if self.hdmi_backend is not None:
            try:
                status = self.hdmi_backend.status()
            except Exception as exc:
                status = {"error": str(exc)}
            try:
                errors = self.hdmi_backend.errors()
            except Exception as exc:
                errors = {"error": str(exc)}
        last_write = {}
        if isinstance(status, dict):
            last_write = status.get("last_frame_write", {}) or {}
        if meta is None:
            meta = last_write

        if expected_selected_fx is not None:
            self.assert_selected_fx(expected_selected_fx)

        try:
            resource_sample = self.resource_sampler.sample()
        except Exception as exc:
            resource_sample = {"error": str(exc)}
        self.last_resource_sample = resource_sample

        info = {
            "index": len(self.render_history) + 1,
            "reason": reason,
            "expected_selected_fx": expected_selected_fx,
            "actual_selected_fx": self.get_selected_fx_actual(),
            "render_s": render_s,
            "backend_update_s": backend_update_s,
            "total_update_s": render_s + backend_update_s,
            "resource_sample": resource_sample,
            "compose_s": meta.get("compose_s") if isinstance(meta, dict) else None,
            "resize_compose_s": (
                meta.get("resize_compose_s") if isinstance(meta, dict) else None),
            "framebuffer_copy_s": (
                meta.get("framebuffer_copy_s") if isinstance(meta, dict) else None),
            "placement": self.placement,
            "offset_x": self.offset_x,
            "offset_y": self.offset_y,
            "variant": self.variant,
            "theme": self.theme,
            "frame_shape": list(getattr(frame, "shape", [])),
            "frame_dtype": str(getattr(frame, "dtype", "")),
            "last_frame_write": meta,
            "hdmi_status": status,
            "hdmi_errors": errors,
            "vdma_error_asserted": _has_asserted_vdma_error(errors),
        }
        self.last_render_info = info
        self.render_history.append(info)
        return info

    # ---- overlay-backed operations ----------------------------------
    def safe_bypass(self):
        if not hasattr(self.overlay, "clear_distortion_pedals"):
            raise AttributeError("overlay is missing clear_distortion_pedals")
        self.overlay.clear_distortion_pedals()
        if hasattr(self.overlay, "set_distortion_settings"):
            self.overlay.set_distortion_settings(
                drive=20, tone=50, level=35, bias=50, tight=50, mix=100)
        if hasattr(self.overlay, "set_noise_suppressor_settings"):
            self.overlay.set_noise_suppressor_settings(enabled=False)
        if hasattr(self.overlay, "set_compressor_settings"):
            self.overlay.set_compressor_settings(enabled=False)
        self.overlay.set_guitar_effects(
            noise_gate_on=False, overdrive_on=False, distortion_on=False,
            rat_on=False, amp_on=False, cab_on=False, eq_on=False,
            reverb_on=False)
        self._apply_safe_bypass_to_app_state()
        expected = self.mark_selected_fx("SAFE BYPASS", reason="safe_bypass")
        return self.render(reason="safe_bypass", expected_selected_fx=expected)

    def apply_chain_preset(self, name):
        result = self.overlay.apply_chain_preset(name)
        self._apply_preset_to_app_state(name)
        expected = self.mark_selected_fx("PRESET",
                                         reason="apply_chain_preset:" + str(name))
        self.render(reason="apply_chain_preset", expected_selected_fx=expected)
        return result

    def set_noise_suppressor_settings(self, *args, **kwargs):
        result = self.overlay.set_noise_suppressor_settings(*args, **kwargs)
        self._apply_noise_suppressor_state(kwargs)
        expected = self.mark_selected_fx(
            "NOISE SUPPRESSOR", reason="set_noise_suppressor_settings")
        self.render(reason="set_noise_suppressor_settings",
                    expected_selected_fx=expected)
        return result

    def set_compressor_settings(self, *args, **kwargs):
        result = self.overlay.set_compressor_settings(*args, **kwargs)
        self._apply_compressor_state(kwargs)
        expected = self.mark_selected_fx(
            "COMPRESSOR", reason="set_compressor_settings")
        self.render(reason="set_compressor_settings",
                    expected_selected_fx=expected)
        return result

    def set_distortion_settings(self, *args, **kwargs):
        result = self.overlay.set_distortion_settings(*args, **kwargs)
        self._apply_distortion_state(kwargs)
        expected = self.mark_selected_fx(
            "DISTORTION", reason="set_distortion_settings")
        self.render(reason="set_distortion_settings",
                    expected_selected_fx=expected)
        return result

    def clear_distortion_pedals(self):
        result = self.overlay.clear_distortion_pedals()
        self._apply_distortion_state({}, enabled=False)
        expected = self.mark_selected_fx(
            "DISTORTION", reason="clear_distortion_pedals")
        self.render(reason="clear_distortion_pedals",
                    expected_selected_fx=expected)
        return result

    # ---- model-selection operations ---------------------------------
    def set_pedal_model(self, model, drive=None, tone=None, level=None,
                        mix=None, bias=None, tight=None, rat_filter=None,
                        filt=None, enabled=True):
        model = normalize_pedal_model(model)
        pedal_idx = PEDAL_MODEL_TO_INDEX[model]
        dist_kwargs = {"pedal": model, "exclusive": True}
        for key, value in (("drive", drive), ("tone", tone),
                           ("level", level), ("mix", mix),
                           ("bias", bias), ("tight", tight)):
            if value is not None:
                dist_kwargs[key] = value
        dist_result = self.overlay.set_distortion_settings(**dist_kwargs)

        guitar_kwargs = {
            "distortion_on": bool(enabled),
            "distortion_pedal_mask": (1 << pedal_idx) if enabled else 0,
            "rat_on": bool(enabled and model == "rat"),
        }
        for key, value in (("distortion", drive),
                           ("distortion_tone", tone),
                           ("distortion_level", level),
                           ("distortion_mix", mix),
                           ("distortion_bias", bias),
                           ("distortion_tight", tight)):
            if value is not None:
                guitar_kwargs[key] = value
        rat_filter_value = rat_filter if rat_filter is not None else filt
        if model == "rat":
            for key, value in (("rat_drive", drive),
                               ("rat_filter", rat_filter_value),
                               ("rat_level", level),
                               ("rat_mix", mix)):
                if value is not None:
                    guitar_kwargs[key] = value
        guitar_result = self.overlay.set_guitar_effects(**guitar_kwargs)

        self._set_current_pedal_model(model, enabled=bool(enabled))
        self._apply_distortion_state(dist_kwargs, enabled=bool(enabled))
        self._apply_guitar_effects_state(guitar_kwargs,
                                         selected_fx="DISTORTION")
        expected = self.mark_selected_fx(
            PEDAL_MODEL_LABELS[model],
            reason="set_pedal_model:" + model)
        self.render(reason="set_pedal_model:" + model,
                    expected_selected_fx=expected)
        return {
            "distortion_settings": dist_result,
            "guitar_effects": guitar_result,
        }

    def set_drive_model(self, model, drive=None, tone=None, level=None,
                        mix=None):
        return self.set_pedal_model(
            model, drive=drive, tone=tone, level=level, mix=mix)

    def clean_boost(self, drive=None, tone=None, level=None, mix=None):
        return self.set_pedal_model(
            "clean_boost", drive=drive, tone=tone, level=level, mix=mix)

    def tube_screamer(self, drive=None, tone=None, level=None, mix=None):
        return self.set_pedal_model(
            "tube_screamer", drive=drive, tone=tone, level=level, mix=mix)

    def rat(self, drive=None, filter=None, filt=None, level=None, mix=None,
            tone=None):
        rat_filter = filter if filter is not None else filt
        return self.set_pedal_model(
            "rat", drive=drive, tone=tone, level=level, mix=mix,
            rat_filter=rat_filter)

    def ds1(self, drive=None, tone=None, level=None, mix=None):
        return self.set_pedal_model(
            "ds1", drive=drive, tone=tone, level=level, mix=mix)

    def big_muff(self, drive=None, tone=None, level=None, mix=None):
        return self.set_pedal_model(
            "big_muff", drive=drive, tone=tone, level=level, mix=mix)

    def fuzz_face(self, drive=None, tone=None, level=None, mix=None):
        return self.set_pedal_model(
            "fuzz_face", drive=drive, tone=tone, level=level, mix=mix)

    def metal(self, drive=None, tone=None, level=None, mix=None):
        return self.set_pedal_model(
            "metal", drive=drive, tone=tone, level=level, mix=mix)

    def set_amp_model(self, model, gain=None, bass=None, mid=None,
                      treble=None, presence=None, resonance=None,
                      master=None, sink=None):
        model = normalize_amp_model(model)
        amp_kwargs = {}
        for key, value in (("amp_input_gain", gain),
                           ("amp_bass", bass),
                           ("amp_middle", mid),
                           ("amp_treble", treble),
                           ("amp_presence", presence),
                           ("amp_resonance", resonance),
                           ("amp_master", master)):
            if value is not None:
                amp_kwargs[key] = value
        if hasattr(self.overlay, "set_amp_model"):
            if sink is None:
                result = self.overlay.set_amp_model(model, **amp_kwargs)
            else:
                result = self.overlay.set_amp_model(
                    model, sink=sink, **amp_kwargs)
        else:
            amp_kwargs["amp_on"] = True
            amp_kwargs["amp_character"] = AMP_MODEL_CHARACTER[model]
            result = self.overlay.set_guitar_effects(**amp_kwargs)

        values = dict(amp_kwargs)
        values.setdefault("amp_on", True)
        values.setdefault("amp_character", AMP_MODEL_CHARACTER[model])
        self._set_current_amp_model(model)
        self._apply_guitar_effects_state(values, selected_fx="AMP SIM")
        expected = self.mark_selected_fx(
            "AMP SIM", reason="set_amp_model:" + model)
        self.render(reason="set_amp_model:" + model,
                    expected_selected_fx=expected)
        return result

    def jc_clean(self, gain=None, bass=None, mid=None, treble=None,
                 presence=None, resonance=None, master=None):
        return self.set_amp_model(
            "jc_clean", gain=gain, bass=bass, mid=mid, treble=treble,
            presence=presence, resonance=resonance, master=master)

    def clean_combo(self, gain=None, bass=None, mid=None, treble=None,
                    presence=None, resonance=None, master=None):
        return self.set_amp_model(
            "clean_combo", gain=gain, bass=bass, mid=mid, treble=treble,
            presence=presence, resonance=resonance, master=master)

    def british_crunch(self, gain=None, bass=None, mid=None, treble=None,
                       presence=None, resonance=None, master=None):
        return self.set_amp_model(
            "british_crunch", gain=gain, bass=bass, mid=mid,
            treble=treble, presence=presence, resonance=resonance,
            master=master)

    def high_gain_stack(self, gain=None, bass=None, mid=None, treble=None,
                        presence=None, resonance=None, master=None):
        return self.set_amp_model(
            "high_gain_stack", gain=gain, bass=bass, mid=mid,
            treble=treble, presence=presence, resonance=resonance,
            master=master)

    def set_cab_model(self, model, air=None, mix=None, level=None,
                      enabled=True):
        model = normalize_cab_model(model)
        cab_kwargs = {
            "cab_on": bool(enabled),
            "cab_model": CAB_MODEL_TO_INDEX[model],
        }
        for key, value in (("cab_air", air), ("cab_mix", mix),
                           ("cab_level", level)):
            if value is not None:
                cab_kwargs[key] = value
        result = self.overlay.set_guitar_effects(**cab_kwargs)
        self._set_current_cab_model(model)
        self._apply_guitar_effects_state(cab_kwargs, selected_fx="CAB")
        expected = self.mark_selected_fx("CAB",
                                         reason="set_cab_model:" + model)
        self.render(reason="set_cab_model:" + model,
                    expected_selected_fx=expected)
        return result

    def cab(self, model="2x12", air=None, mix=None, level=None,
            enabled=True):
        return self.set_cab_model(
            model, air=air, mix=mix, level=level, enabled=enabled)

    def eq(self, enabled=True, low=None, mid=None, high=None):
        kwargs = {"eq_on": bool(enabled)}
        if low is not None:
            kwargs["eq_low"] = low * 2
        if mid is not None:
            kwargs["eq_mid"] = mid * 2
        if high is not None:
            kwargs["eq_high"] = high * 2
        return self.set_guitar_effects(**kwargs)

    def reverb(self, enabled=True, mix=None, decay=None, tone=None):
        kwargs = {"reverb_on": bool(enabled)}
        if mix is not None:
            kwargs["reverb_mix"] = mix
        if decay is not None:
            kwargs["reverb_decay"] = decay
        if tone is not None:
            kwargs["reverb_tone"] = tone
        return self.set_guitar_effects(**kwargs)

    def set_guitar_effects(self, *args, **kwargs):
        selected_fx = self._selected_fx_from_guitar_kwargs(kwargs)
        result = self.overlay.set_guitar_effects(*args, **kwargs)
        self._apply_guitar_effects_state(kwargs, selected_fx=selected_fx)
        if selected_fx is not None:
            expected = self.mark_selected_fx(
                selected_fx, reason="set_guitar_effects")
            self.render(reason="set_guitar_effects",
                        expected_selected_fx=expected)
        else:
            self.render(reason="set_guitar_effects")
        return result

    def update_from_overlay_state(self, reason=None):
        if not hasattr(self.overlay, "get_current_pedalboard_state"):
            raise AttributeError("overlay is missing get_current_pedalboard_state")
        snapshot = self.overlay.get_current_pedalboard_state()
        ns = snapshot.get("noise_suppressor", {})
        comp = snapshot.get("compressor", {})
        dist = snapshot.get("distortion", {})
        if ns:
            self._apply_noise_suppressor_state(ns)
        if comp:
            self._apply_compressor_state(comp)
        if dist:
            self._apply_distortion_state(dist)
        self.render(reason=reason or "update_from_overlay_state")
        return snapshot

    # ---- summaries ---------------------------------------------------
    def get_state_summary(self):
        status = {}
        errors = {}
        if self.hdmi_backend is not None:
            try:
                status = self.hdmi_backend.status()
            except Exception as exc:
                status = {"error": str(exc)}
            try:
                errors = self.hdmi_backend.errors()
            except Exception as exc:
                errors = {"error": str(exc)}
        return {
            "last_edited_effect": self.last_edited_effect,
            "selected_fx_actual": self.get_selected_fx_actual(),
            "selected_fx_expected": self.last_selected_fx_expected,
            "current_pedal_model": self.current_pedal_model,
            "current_amp_model": self.current_amp_model,
            "current_cab_model": self.current_cab_model,
            "current_pedal_label": self.current_pedal_label,
            "current_amp_label": self.current_amp_label,
            "current_cab_label": self.current_cab_label,
            "active_pedals": list(self.active_pedals),
            "selected_fx_history": list(self.selected_fx_history),
            "render_count": len(self.render_history),
            "last_render_info": dict(self.last_render_info),
            "hdmi_status": status,
            "hdmi_errors": errors,
            "app_state": {
                "preset_id": getattr(self.app_state, "preset_id", None),
                "preset_name": getattr(self.app_state, "preset_name", None),
                "preset_idx": getattr(self.app_state, "preset_idx", None),
                "selected_effect": getattr(self.app_state, "selected_effect", None),
                "selected_fx": getattr(self.app_state, "selected_fx", None),
                "pedal_model": getattr(self.app_state, "pedal_model", None),
                "amp_model": getattr(self.app_state, "amp_model", None),
                "cab_model": getattr(self.app_state, "cab_model", None),
                "pedal_model_label": getattr(
                    self.app_state, "pedal_model_label", None),
                "amp_model_label": getattr(
                    self.app_state, "amp_model_label", None),
                "cab_model_label": getattr(
                    self.app_state, "cab_model_label", None),
                "active_model_category": getattr(
                    self.app_state, "active_model_category", None),
                "active_pedals": list(
                    getattr(self.app_state, "active_pedals", []) or []),
                "effect_on": list(getattr(self.app_state, "effect_on", []) or []),
                "knob_values": list(getattr(self.app_state, "knob_values", []) or []),
            },
        }

    def print_selected_fx_history(self):
        print("SELECTED FX history:")
        for item in self.selected_fx_history:
            print("[{index:02d}] {selected_fx}  reason={reason}".format(**item))

    def selected_history(self):
        """Return a copy of the SELECTED FX history list."""
        return [dict(item) for item in self.selected_fx_history]

    def resource_summary(self):
        """Return a snapshot of PS / GUI / HDMI resource usage.

        The dict is safe to print or render in a Notebook widget. Includes
        the latest /proc CPU and memory sample, the last render/compose/
        framebuffer-copy timings, VDMA / VTC status, and the SELECTED FX
        bookkeeping fields the user typically wants to display alongside
        these numbers.
        """
        sample = self.resource_sampler.sample()
        self.last_resource_sample = sample
        info = dict(self.last_render_info or {})
        status = info.get("hdmi_status") or {}
        errors = info.get("hdmi_errors") or {}
        last_write = info.get("last_frame_write") or status.get(
            "last_frame_write", {}) or {}
        return {
            "time_s": sample.get("time_s"),
            "proc_rss_kb": sample.get("proc_rss_kb"),
            "proc_vmsize_kb": sample.get("proc_vmsize_kb"),
            "mem_total_kb": sample.get("mem_total_kb"),
            "mem_avail_kb": sample.get("mem_avail_kb"),
            "mem_free_kb": sample.get("mem_free_kb"),
            "sys_cpu_pct": sample.get("sys_cpu_pct"),
            "proc_cpu_pct": sample.get("proc_cpu_pct"),
            "cpu_count": sample.get("cpu_count"),
            "temperature_c": sample.get("temperature_c"),
            "render_s": info.get("render_s"),
            "backend_update_s": info.get("backend_update_s"),
            "compose_s": info.get("compose_s"),
            "framebuffer_copy_s": info.get("framebuffer_copy_s"),
            "total_update_s": info.get("total_update_s"),
            "vdma_dmacr": status.get("vdma_dmacr"),
            "vdma_dmasr": status.get("vdma_dmasr"),
            "vdma_error_raw": errors.get("raw"),
            "vdma_error_bits": {
                "halted": errors.get("halted"),
                "idle": errors.get("idle"),
                "dmainterr": errors.get("dmainterr"),
                "dmaslverr": errors.get("dmaslverr"),
                "dmadecerr": errors.get("dmadecerr"),
            },
            "vtc_ctl": status.get("vtc_ctl"),
            "last_frame_write": last_write,
            "selected_fx": self.get_selected_fx_actual(),
            "selected_model_category": getattr(
                self.app_state, "selected_model_category", None),
            "dropdown_label": getattr(self.app_state, "dropdown_label", None),
            "dropdown_short_label": getattr(
                self.app_state, "dropdown_short_label", None),
            "current_pedal_model": self.current_pedal_model,
            "current_amp_model": self.current_amp_model,
            "current_cab_model": self.current_cab_model,
            "current_pedal_label": self.current_pedal_label,
            "current_amp_label": self.current_amp_label,
            "current_cab_label": self.current_cab_label,
            "last_edited_effect": self.last_edited_effect,
            "render_count": len(self.render_history),
            "pl_utilization": dict(STATIC_PL_UTILIZATION),
        }

    def summary(self):
        """Phase 6C: combined state + resource snapshot for Notebook UIs."""
        data = self.get_state_summary()
        data["resource"] = self.resource_summary()
        return data

    def summary_json(self):
        return json.dumps(self.get_state_summary(), indent=2, sort_keys=True,
                          default=str)


__all__ = [
    "HdmiEffectStateMirror",
    "METHOD_SELECTED_FX",
    "PEDAL_MODEL_LABELS",
    "AMP_MODEL_LABELS",
    "CAB_MODEL_LABELS",
    "PEDAL_MODEL_TO_INDEX",
    "AMP_MODEL_TO_INDEX",
    "CAB_MODEL_TO_INDEX",
    "PEDAL_MODELS",
    "AMP_MODELS",
    "CAB_MODELS",
    "SELECTED_FX_CATEGORY",
    "DROPDOWN_SHORT_LABELS",
    "STATIC_PL_UTILIZATION",
    "ResourceSampler",
    "selected_fx_category",
    "dropdown_short_label",
    "dropdown_label_for",
    "dropdown_visible_for",
    "normalize_selected_fx",
    "canonical_selected_fx",
    "normalize_pedal_model",
    "normalize_amp_model",
    "normalize_cab_model",
    "pedal_model_label",
    "amp_model_label",
    "cab_model_label",
    "_parse_proc_meminfo_text",
    "_parse_proc_status_text",
    "_parse_proc_stat_cpu_line",
    "_parse_proc_self_stat_times",
]
