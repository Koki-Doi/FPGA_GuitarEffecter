"""Notebook-driven AudioLab effect state mirror for the HDMI GUI.

``HdmiEffectStateMirror`` is deliberately one-way:

Notebook helper -> AudioLabOverlay existing API -> AppState display update
-> 800x480 HDMI redraw.

It does not make the GUI interactive, does not poll GPIOs every frame, and
does not monkey-patch ``AudioLabOverlay``. The wrapper exists because direct
``ovl.set_*`` calls do not carry enough context to infer which effect the
user last edited.
"""
from __future__ import print_function

import inspect
import json
import time


GUI_EFFECTS = [
    "Noise Sup", "Compressor", "Overdrive", "Distortion",
    "Amp Sim", "Cab IR", "EQ", "Reverb",
]

GUI_EFFECT_KNOBS = {
    "Noise Sup":  [("THRESH", 35), ("DECAY", 45), ("DAMP", 80),
                   ("", 0), ("", 0), ("", 0)],
    "Compressor": [("THRESH", 50), ("RATIO", 45), ("RESPONSE", 40),
                   ("MAKEUP", 55), ("", 0), ("", 0)],
    "Overdrive":  [("DRIVE", 35), ("TONE", 60), ("LEVEL", 60),
                   ("", 0), ("", 0), ("", 0)],
    "Distortion": [("DRIVE", 50), ("TONE", 55), ("LEVEL", 35),
                   ("BIAS", 50), ("TIGHT", 60), ("MIX", 100)],
    "Amp Sim":    [("GAIN", 45), ("BASS", 55), ("MID", 60),
                   ("TREBLE", 50), ("MASTER", 70), ("CHAR", 60)],
    "Cab IR":     [("MIX", 100), ("LEVEL", 70), ("MODEL", 33),
                   ("AIR", 35), ("", 0), ("", 0)],
    "EQ":         [("LOW", 50), ("MID", 55), ("HIGH", 55),
                   ("", 0), ("", 0), ("", 0)],
    "Reverb":     [("DECAY", 30), ("TONE", 65), ("MIX", 25),
                   ("", 0), ("", 0), ("", 0)],
}


CANONICAL_SELECTED_FX = {
    "PRESET": "PRESET",
    "SAFE BYPASS": "SAFE BYPASS",
    "NOISE SUPPRESSOR": "NOISE SUPPRESSOR",
    "COMPRESSOR": "COMPRESSOR",
    "OVERDRIVE": "OVERDRIVE",
    "DISTORTION": "DISTORTION",
    "RAT": "RAT",
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
    "RAT": "RAT",
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
    "RAT": 3,
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


def _clamp_percent(value):
    try:
        value = float(value)
    except Exception:
        value = 0.0
    if value < 0.0:
        value = 0.0
    if value > 100.0:
        value = 100.0
    return int(round(value))


def _eq_display_value(value):
    try:
        return _clamp_percent(float(value) / 2.0)
    except Exception:
        return 50


def _cab_model_display_value(value):
    try:
        ivalue = int(value)
    except Exception:
        ivalue = 1
    if ivalue < 0:
        ivalue = 0
    if ivalue > 2:
        ivalue = 2
    return ivalue * 50


def _knob_defaults_for_effect_index(index):
    effect_name = GUI_EFFECTS[int(index)]
    return [default for _label, default in GUI_EFFECT_KNOBS[effect_name]]


def _has_asserted_vdma_error(errors):
    return bool(
        errors
        and (errors.get("dmainterr")
             or errors.get("dmaslverr")
             or errors.get("dmadecerr"))
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
        setattr(self.app_state, "selected_fx", display)
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
    def _set_effect_index_for_selected_fx(self, effect_name):
        canonical = canonical_selected_fx(effect_name)
        idx = EFFECT_INDEX_BY_SELECTED_FX.get(canonical)
        if idx is None:
            return None
        current = int(getattr(self.app_state, "selected_effect", idx) or idx)
        if current != idx or len(getattr(self.app_state, "knob_values", []) or []) != 6:
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
        if len(values) != 6:
            values = _knob_defaults_for_effect_index(idx)
        for knob_index, value in updates.items():
            if 0 <= int(knob_index) < 6:
                values[int(knob_index)] = _clamp_percent(value)
        self.app_state.knob_values = values[:6]

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
        if enabled is not None:
            self._set_effect_enabled("DISTORTION", enabled)
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

    def _apply_safe_bypass_to_app_state(self):
        self.app_state.preset_idx = 0
        self.app_state.preset_id = "01A"
        self.app_state.preset_name = "SAFE BYPASS"
        self.app_state.effect_on = [False] * len(GUI_EFFECTS)

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
        if "rat_on" in values:
            self._set_effect_enabled("RAT", values["rat_on"])
        if "amp_on" in values:
            self._set_effect_enabled("AMP SIM", values["amp_on"])
        if "cab_on" in values:
            self._set_effect_enabled("CAB", values["cab_on"])
        if "eq_on" in values:
            self._set_effect_enabled("EQ", values["eq_on"])
        if "reverb_on" in values:
            self._set_effect_enabled("REVERB", values["reverb_on"])

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
            for key, idx in (("amp_input_gain", 0), ("amp_bass", 1),
                             ("amp_middle", 2), ("amp_treble", 3),
                             ("amp_master", 4), ("amp_character", 5)):
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

        info = {
            "index": len(self.render_history) + 1,
            "reason": reason,
            "expected_selected_fx": expected_selected_fx,
            "actual_selected_fx": self.get_selected_fx_actual(),
            "render_s": render_s,
            "backend_update_s": backend_update_s,
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
                "effect_on": list(getattr(self.app_state, "effect_on", []) or []),
                "knob_values": list(getattr(self.app_state, "knob_values", []) or []),
            },
        }

    def print_selected_fx_history(self):
        print("SELECTED FX history:")
        for item in self.selected_fx_history:
            print("[{index:02d}] {selected_fx}  reason={reason}".format(**item))

    def summary_json(self):
        return json.dumps(self.get_state_summary(), indent=2, sort_keys=True,
                          default=str)


__all__ = [
    "HdmiEffectStateMirror",
    "METHOD_SELECTED_FX",
    "normalize_selected_fx",
    "canonical_selected_fx",
]
