"""Bridge GUI AppState changes to the AudioLabOverlay control API.

This module intentionally stays independent from HDMI output and overlay
loading. It translates ``pynq_multi_fx_gui.AppState`` into a small list of
``AudioLabOverlay`` API calls, then applies only changed calls at a throttled
control rate. Drawing functions must not import this module for side effects,
and this module must not instantiate ``AudioLabOverlay``.
"""

from __future__ import print_function

import time

try:
    from .pynq_multi_fx_gui import (
        AMP_MODELS,
        CAB_MODELS,
        CHAIN_PRESETS,
        DIST_MODELS,
        EFFECT_KNOBS,
        EFFECTS,
    )
except Exception:  # pragma: no cover - supports flat /tmp copies on PYNQ.
    try:
        from pynq_multi_fx_gui import (  # type: ignore
            AMP_MODELS,
            CAB_MODELS,
            CHAIN_PRESETS,
            DIST_MODELS,
            EFFECT_KNOBS,
            EFFECTS,
        )
    except Exception:
        # Local CI environments for control-layer tests may not have NumPy /
        # Pillow installed, even though PYNQ does. Keep a small copy of the GUI
        # constants so the bridge remains importable without the renderer.
        EFFECTS = ["Noise Sup", "Compressor", "Overdrive", "Distortion",
                   "Amp Sim", "Cab IR", "EQ", "Reverb"]
        EFFECT_KNOBS = {
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
        DIST_MODELS = ["CLEAN BOOST", "TUBE SCREAMER", "RAT", "DS-1",
                       "BIG MUFF", "FUZZ FACE", "METAL"]
        AMP_MODELS = [("JC CLEAN", 10), ("CLEAN COMBO", 35),
                      ("BRITISH CRUNCH", 60), ("HIGH GAIN STACK", 85)]
        CAB_MODELS = ["1x12 COMBO", "2x12 BLACK", "4x12 BRITISH",
                      "4x12 V30", "DIRECT DI"]
        CHAIN_PRESETS = [
            "Safe Bypass", "Basic Clean", "Clean Sustain", "Light Crunch",
            "TS Lead", "RAT Rhythm", "Metal Tight", "Ambient Clean",
            "Solo Boost", "Noise Controlled High Gain",
            "DS-1 Crunch", "Big Muff Sustain", "Vintage Fuzz",
        ]


FIXED_DSP_CHAIN = tuple(range(len(EFFECTS)))
SUPPORTED_EFFECTS = tuple(EFFECTS)
UNSUPPORTED_LIVE_EFFECTS = (
    "chorus",
    "phaser",
    "octaver",
    "delay",
    "bit_crusher",
    "bit effect",
)

KNOB_DRAG_EVENTS = ("knob_drag", "drag", "continuous")
DEFAULT_KNOB_THROTTLE_SECONDS = 0.10

PRESET_NAME_ALIASES = {
    "TS Lead": "Tube Screamer Lead",
}

DISTORTION_PEDAL_ALIASES = {
    "CLEAN BOOST": "clean_boost",
    "TUBE SCREAMER": "tube_screamer",
    "RAT": "rat",
    "DS-1": "ds1",
    "BIG MUFF": "big_muff",
    "FUZZ FACE": "fuzz_face",
    "METAL": "metal",
}


def _clamp(value, lo, hi):
    try:
        value = float(value)
    except Exception:
        value = lo
    if value < lo:
        value = lo
    if value > hi:
        value = hi
    return value


def _percent(value):
    return int(round(_clamp(value, 0, 100)))


def _level_200(value):
    return int(round(_clamp(value, 0, 100) * 2.0))


def _effect_enabled(state, index):
    values = list(getattr(state, "effect_on", []) or [])
    if 0 <= index < len(values):
        return bool(values[index])
    return False


def _selected_effect_index(state):
    idx = int(getattr(state, "selected_effect", 0) or 0)
    if idx < 0:
        return 0
    if idx >= len(EFFECTS):
        return len(EFFECTS) - 1
    return idx


def _knob_values_for_effect(state, effect_name, effect_index):
    defaults = [default for _label, default in EFFECT_KNOBS[effect_name]]
    # Phase 6H+ AppState stores all effect knobs independently. Keep the
    # legacy flat knob_values override for old tests / drag paths, but use the
    # full per-effect table when present.
    if _selected_effect_index(state) == effect_index:
        values = list(getattr(state, "knob_values", []) or [])
        if values:
            defaults[:len(values)] = values[:len(defaults)]
            return defaults
    all_values = getattr(state, "all_knob_values", None)
    if isinstance(all_values, dict):
        values = list(all_values.get(effect_name, []) or [])
        if values:
            defaults[:len(values)] = values[:len(defaults)]
    return defaults


def _knob_map(state, effect_name, effect_index):
    labels = [label for label, _default in EFFECT_KNOBS[effect_name]]
    values = _knob_values_for_effect(state, effect_name, effect_index)
    out = {}
    for label, value in zip(labels, values):
        if label:
            out[label.lower()] = value
    return out


def _distortion_pedal_from_state(state):
    idx = int(getattr(state, "dist_model_idx", 1) or 0)
    if idx < 0:
        idx = 0
    if idx >= len(DIST_MODELS):
        idx = len(DIST_MODELS) - 1
    return DISTORTION_PEDAL_ALIASES.get(DIST_MODELS[idx], "tube_screamer")


def _cab_model_from_state(state, knobs):
    idx = int(getattr(state, "cab_model_idx", 1) or 0)
    if "model" in knobs:
        idx = int(round(_clamp(knobs["model"], 0, 100) * 2.0 / 100.0))
    if idx < 0:
        idx = 0
    if idx > 2:
        idx = 2
    return idx


def _amp_character_from_state(state, knobs):
    if "char" in knobs:
        return _percent(knobs["char"])
    idx = int(getattr(state, "amp_model_idx", 1) or 0)
    if idx < 0:
        idx = 0
    if idx >= len(AMP_MODELS):
        idx = len(AMP_MODELS) - 1
    return _percent(AMP_MODELS[idx][1])


def chain_is_hardware_order(state):
    return tuple(getattr(state, "chain", []) or []) == FIXED_DSP_CHAIN


def chain_preset_name_from_state(state):
    idx = int(getattr(state, "preset_idx", 0) or 0)
    if idx < 0:
        idx = 0
    if idx >= len(CHAIN_PRESETS):
        idx = len(CHAIN_PRESETS) - 1
    gui_name = CHAIN_PRESETS[idx]
    return PRESET_NAME_ALIASES.get(gui_name, gui_name)


def app_state_to_audio_lab_sections(state):
    """Return a dict-of-dicts matching current AudioLab effect sections.

    ``AppState`` stores knob values only for the currently selected effect, so
    non-selected sections use the GUI defaults. Full per-effect knob state can
    be added later without changing the public bridge contract.
    """
    ns = _knob_map(state, "Noise Sup", 0)
    comp = _knob_map(state, "Compressor", 1)
    od = _knob_map(state, "Overdrive", 2)
    dist = _knob_map(state, "Distortion", 3)
    amp = _knob_map(state, "Amp Sim", 4)
    cab = _knob_map(state, "Cab IR", 5)
    eq = _knob_map(state, "EQ", 6)
    rev = _knob_map(state, "Reverb", 7)

    sections = {
        "noise_suppressor": {
            "enabled": _effect_enabled(state, 0),
            "threshold": _percent(ns.get("thresh", 35)),
            "decay": _percent(ns.get("decay", 45)),
            "damp": _percent(ns.get("damp", 80)),
        },
        "compressor": {
            "enabled": _effect_enabled(state, 1),
            "threshold": _percent(comp.get("thresh", 50)),
            "ratio": _percent(comp.get("ratio", 45)),
            "response": _percent(comp.get("resp", comp.get("response", 40))),
            "makeup": _percent(comp.get("makeup", 55)),
        },
        "overdrive": {
            "enabled": _effect_enabled(state, 2),
            "drive": _percent(od.get("drive", 35)),
            "tone": _percent(od.get("tone", 60)),
            "level": _percent(od.get("level", 60)),
        },
        "distortion": {
            "enabled": _effect_enabled(state, 3),
            "pedal": _distortion_pedal_from_state(state),
            "exclusive": True,
            "drive": _percent(dist.get("drive", 50)),
            "tone": _percent(dist.get("tone", 55)),
            "level": _percent(dist.get("level", 35)),
            "bias": _percent(dist.get("bias", 50)),
            "tight": _percent(dist.get("tight", 60)),
            "mix": _percent(dist.get("mix", 100)),
        },
        "amp": {
            "enabled": _effect_enabled(state, 4),
            "input_gain": _percent(amp.get("gain", 45)),
            "bass": _percent(amp.get("bass", 55)),
            "middle": _percent(amp.get("mid", 60)),
            "treble": _percent(amp.get("treb", amp.get("treble", 50))),
            "presence": _percent(amp.get("pres", amp.get("presence", 45))),
            "resonance": _percent(amp.get("res", amp.get("resonance", 35))),
            "master": _percent(amp.get("mstr", amp.get("master", 70))),
            "character": _amp_character_from_state(state, amp),
        },
        "cab": {
            "enabled": _effect_enabled(state, 5),
            "mix": _percent(cab.get("mix", 100)),
            "level": _percent(cab.get("level", 70)),
            "model": _cab_model_from_state(state, cab),
            "air": _percent(cab.get("air", 35)),
        },
        "eq": {
            "enabled": _effect_enabled(state, 6),
            "low": _level_200(eq.get("low", 50)),
            "mid": _level_200(eq.get("mid", 55)),
            "high": _level_200(eq.get("high", 55)),
        },
        "reverb": {
            "enabled": _effect_enabled(state, 7),
            "decay": _percent(rev.get("decay", 30)),
            "tone": _percent(rev.get("tone", 65)),
            "mix": _percent(rev.get("mix", 25)),
        },
    }
    return sections


def _signature_value(value):
    if isinstance(value, dict):
        return tuple((key, _signature_value(value[key])) for key in sorted(value))
    if isinstance(value, (list, tuple)):
        return tuple(_signature_value(item) for item in value)
    return value


class BridgeOperation(object):
    """One AudioLabOverlay API call planned by the bridge."""

    def __init__(self, section, method, kwargs=None, reason="", throttle_key=None,
                 priority=10):
        self.section = section
        self.method = method
        self.kwargs = dict(kwargs or {})
        self.reason = reason
        self.throttle_key = throttle_key
        self.priority = priority

    def key(self):
        return self.section + ":" + self.method

    def signature(self):
        return (self.method, _signature_value(self.kwargs))

    def as_dict(self):
        return {
            "section": self.section,
            "method": self.method,
            "kwargs": dict(self.kwargs),
            "reason": self.reason,
            "throttle_key": self.throttle_key,
            "priority": self.priority,
        }

    def __repr__(self):
        return "BridgeOperation({!r}, {!r}, {!r})".format(
            self.section, self.method, self.kwargs)


class BridgePlan(object):
    """Dry-run friendly plan object returned by ``AudioLabGuiBridge``."""

    def __init__(self, operations=None, warnings=None, sections=None):
        self.operations = list(operations or [])
        self.warnings = list(warnings or [])
        self.sections = sections or {}

    def as_dict(self):
        return {
            "operations": [op.as_dict() for op in self.operations],
            "warnings": list(self.warnings),
            "sections": dict(self.sections),
        }


def _guitar_effects_kwargs(sections):
    ns = sections["noise_suppressor"]
    od = sections["overdrive"]
    dist = sections["distortion"]
    amp = sections["amp"]
    cab = sections["cab"]
    eq = sections["eq"]
    rev = sections["reverb"]
    dist_on = bool(dist["enabled"] and dist.get("pedal"))
    return {
        "noise_gate_on": bool(ns["enabled"]),
        "noise_gate_threshold": ns["threshold"],
        "overdrive_on": bool(od["enabled"]),
        "overdrive_drive": od["drive"],
        "overdrive_tone": od["tone"],
        "overdrive_level": od["level"],
        "distortion_on": dist_on,
        "distortion": dist["drive"],
        "distortion_tone": dist["tone"],
        "distortion_level": dist["level"],
        "distortion_bias": dist["bias"],
        "distortion_tight": dist["tight"],
        "distortion_mix": dist["mix"],
        "rat_on": dist_on and dist.get("pedal") == "rat",
        "amp_on": bool(amp["enabled"]),
        "amp_input_gain": amp["input_gain"],
        "amp_bass": amp["bass"],
        "amp_middle": amp["middle"],
        "amp_treble": amp["treble"],
        "amp_presence": amp["presence"],
        "amp_resonance": amp["resonance"],
        "amp_master": amp["master"],
        "amp_character": amp["character"],
        "cab_on": bool(cab["enabled"]),
        "cab_mix": cab["mix"],
        "cab_level": cab["level"],
        "cab_model": cab["model"],
        "cab_air": cab["air"],
        "eq_on": bool(eq["enabled"]),
        "eq_low": eq["low"],
        "eq_mid": eq["mid"],
        "eq_high": eq["high"],
        "reverb_on": bool(rev["enabled"]),
        "reverb_decay": rev["decay"],
        "reverb_tone": rev["tone"],
        "reverb_mix": rev["mix"],
    }


def full_state_plan(state):
    """Return all overlay calls implied by an ``AppState`` snapshot."""
    sections = app_state_to_audio_lab_sections(state)
    ops = []
    ns = sections["noise_suppressor"]
    comp = sections["compressor"]
    dist = sections["distortion"]

    ops.append(BridgeOperation(
        "noise_suppressor",
        "set_noise_suppressor_settings",
        dict(enabled=ns["enabled"], threshold=ns["threshold"],
             decay=ns["decay"], damp=ns["damp"]),
        reason="Noise Suppressor AppState section",
        throttle_key="noise_suppressor",
    ))
    ops.append(BridgeOperation(
        "compressor",
        "set_compressor_settings",
        dict(enabled=comp["enabled"], threshold=comp["threshold"],
             ratio=comp["ratio"], response=comp["response"],
             makeup=comp["makeup"]),
        reason="Compressor AppState section",
        throttle_key="compressor",
    ))
    if dist["enabled"] and dist.get("pedal"):
        ops.append(BridgeOperation(
            "distortion",
            "set_distortion_settings",
            dict(pedal=dist["pedal"], exclusive=True, drive=dist["drive"],
                 tone=dist["tone"], level=dist["level"], bias=dist["bias"],
                 tight=dist["tight"], mix=dist["mix"]),
            reason="Distortion Pedalboard AppState section",
            throttle_key="distortion",
        ))
    else:
        ops.append(BridgeOperation(
            "distortion",
            "clear_distortion_pedals",
            {},
            reason="Distortion Pedalboard disabled in AppState",
            throttle_key="distortion",
        ))
        ops.append(BridgeOperation(
            "distortion",
            "set_distortion_settings",
            dict(drive=dist["drive"], tone=dist["tone"],
                 level=dist["level"], bias=dist["bias"],
                 tight=dist["tight"], mix=dist["mix"]),
            reason="Keep disabled distortion parameters in cache",
            throttle_key="distortion",
        ))
    ops.append(BridgeOperation(
        "guitar_effects",
        "set_guitar_effects",
        _guitar_effects_kwargs(sections),
        reason="Grouped gate / overdrive / amp / cab / EQ / reverb state",
        throttle_key="guitar_effects",
    ))

    warnings = []
    if not chain_is_hardware_order(state):
        warnings.append(
            "chain reorder is display-only in live mode; current FPGA DSP "
            "order is fixed and no hardware routing write was planned")
    for effect in UNSUPPORTED_LIVE_EFFECTS:
        if effect in [name.lower() for name in EFFECTS]:
            warnings.append("unsupported live effect present in GUI constants: " + effect)
    return BridgePlan(ops, warnings=warnings, sections=sections)


def chain_preset_plan(state):
    name = chain_preset_name_from_state(state)
    return BridgePlan([
        BridgeOperation(
            "chain_preset",
            "apply_chain_preset",
            {"name": name},
            reason="Apply GUI Chain Preset through AudioLabOverlay",
            throttle_key=None,
            priority=0,
        )
    ])


def safe_bypass_plan():
    return BridgePlan([
        BridgeOperation(
            "distortion", "clear_distortion_pedals", {},
            reason="Safe Bypass disables every distortion pedal",
            priority=0),
        BridgeOperation(
            "distortion", "set_distortion_settings",
            dict(drive=20, tone=50, level=35, bias=50, tight=50, mix=100),
            reason="Safe Bypass restores safe distortion defaults",
            priority=0),
        BridgeOperation(
            "noise_suppressor", "set_noise_suppressor_settings",
            dict(enabled=False),
            reason="Safe Bypass disables Noise Suppressor",
            priority=0),
        BridgeOperation(
            "compressor", "set_compressor_settings",
            dict(enabled=False),
            reason="Safe Bypass disables Compressor",
            priority=0),
        BridgeOperation(
            "guitar_effects", "set_guitar_effects",
            dict(noise_gate_on=False, overdrive_on=False,
                 distortion_on=False, rat_on=False, amp_on=False,
                 cab_on=False, eq_on=False, reverb_on=False),
            reason="Safe Bypass disables grouped effect masters",
            priority=0),
    ])


class AudioLabGuiBridge(object):
    """Change-driven bridge from GUI AppState to AudioLabOverlay APIs."""

    def __init__(self, knob_throttle_seconds=DEFAULT_KNOB_THROTTLE_SECONDS):
        self.knob_throttle_seconds = float(knob_throttle_seconds)
        self._last_signatures = {}
        self._last_write_times = {}

    def reset(self):
        self._last_signatures.clear()
        self._last_write_times.clear()

    def build_plan(self, state, event="state_changed", force=False,
                   include_chain_preset=False):
        if include_chain_preset:
            return chain_preset_plan(state)

        plan = full_state_plan(state)
        if force:
            return plan

        changed = []
        for op in plan.operations:
            if self._last_signatures.get(op.key()) != op.signature():
                changed.append(op)
        return BridgePlan(changed, warnings=plan.warnings, sections=plan.sections)

    def build_safe_bypass_plan(self):
        return safe_bypass_plan()

    def apply(self, state=None, overlay=None, dry_run=True,
              event="state_changed", now=None, force=False,
              include_chain_preset=False, plan=None):
        """Apply or dry-run a bridge plan.

        ``dry_run`` defaults to True. With ``dry_run=False`` the caller must
        pass an already-loaded ``AudioLabOverlay`` instance; this class never
        creates or loads an overlay by itself.
        """
        if now is None:
            now = time.monotonic()
        if plan is None:
            if state is None:
                raise ValueError("state is required when plan is not provided")
            plan = self.build_plan(
                state, event=event, force=force,
                include_chain_preset=include_chain_preset)
        if not dry_run and overlay is None:
            raise ValueError("overlay is required when dry_run=False")

        operations = []
        skipped = []
        warnings = list(plan.warnings)
        for op in plan.operations:
            if self._should_throttle(op, event, now):
                skipped.append(op.as_dict())
                continue
            if not dry_run:
                target = getattr(overlay, op.method, None)
                if target is None:
                    warnings.append("overlay is missing method " + op.method)
                    skipped.append(op.as_dict())
                    continue
                target(**op.kwargs)
            operations.append(op.as_dict())
            self._last_signatures[op.key()] = op.signature()
            if op.throttle_key:
                self._last_write_times[op.throttle_key] = now
        return {
            "dry_run": bool(dry_run),
            "operations": operations,
            "skipped": skipped,
            "warnings": warnings,
        }

    def apply_safe_bypass(self, overlay=None, dry_run=True, now=None):
        return self.apply(
            overlay=overlay, dry_run=dry_run, now=now, plan=safe_bypass_plan())

    def apply_chain_preset(self, state, overlay=None, dry_run=True, now=None):
        return self.apply(
            state=state, overlay=overlay, dry_run=dry_run, now=now,
            include_chain_preset=True)

    def _should_throttle(self, op, event, now):
        if event not in KNOB_DRAG_EVENTS:
            return False
        if not op.throttle_key:
            return False
        last = self._last_write_times.get(op.throttle_key)
        if last is None:
            return False
        return (now - last) < self.knob_throttle_seconds


__all__ = [
    "AudioLabGuiBridge",
    "BridgeOperation",
    "BridgePlan",
    "DEFAULT_KNOB_THROTTLE_SECONDS",
    "FIXED_DSP_CHAIN",
    "SUPPORTED_EFFECTS",
    "UNSUPPORTED_LIVE_EFFECTS",
    "app_state_to_audio_lab_sections",
    "chain_is_hardware_order",
    "chain_preset_name_from_state",
    "chain_preset_plan",
    "full_state_plan",
    "safe_bypass_plan",
]
