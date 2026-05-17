"""Pure AppState -> AudioLabOverlay apply planning.

Both the notebook GUI bridge and the standalone encoder runtime need to
translate the compact-v2 ``AppState`` into the same AudioLabOverlay public
setter calls. Keeping that translation here prevents drift in knob ordering,
model indexes, EQ scaling, and RAT exclusion rules.
"""

from __future__ import print_function

from audio_lab_pynq.effect_catalog import (
    AMP_MODEL_CHARACTER,
    AMP_MODELS,
    CHAIN_PRESETS,
    DIST_MODELS,
    EFFECTS,
    EFFECT_KNOBS,
    EFFECT_AMP,
    EFFECT_CAB,
    EFFECT_COMPRESSOR,
    EFFECT_DISTORTION,
    EFFECT_EQ,
    EFFECT_NOISE_SUP,
    EFFECT_OVERDRIVE,
    EFFECT_REVERB,
    PEDAL_LABEL_TO_MODEL,
    PRESET_NAME_ALIASES,
)


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

RAT_PEDAL_INDEX = 2

_DEFAULT_EFFECT_ON = {}
_ENCODER_EFFECT_ON_DEFAULTS = {
    0: True,
    1: True,
    2: False,
    3: False,
    4: True,
    5: True,
    6: True,
    7: True,
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


def percent(value):
    return int(round(_clamp(value, 0, 100)))


def percent_float(value):
    return float(_clamp(value, 0, 100))


def level_200(value):
    return int(round(_clamp(value, 0, 100) * 2.0))


def level_200_float(value):
    return float(_clamp(value, 0, 100) * 2.0)


def _selected_effect_index(state):
    idx = int(getattr(state, "selected_effect", 0) or 0)
    if idx < 0:
        return 0
    if idx >= len(EFFECTS):
        return len(EFFECTS) - 1
    return idx


def effect_enabled(state, index, defaults=None):
    values = list(getattr(state, "effect_on", []) or [])
    if 0 <= index < len(values):
        return bool(values[index])
    defaults = defaults or _DEFAULT_EFFECT_ON
    return bool(defaults.get(index, False))


def knob_values_for_effect(state, effect_name, effect_index,
                           prefer_legacy_selected=True):
    defaults = [default for _label, default in EFFECT_KNOBS[effect_name]]
    if prefer_legacy_selected and _selected_effect_index(state) == effect_index:
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


def knob_map(state, effect_name, effect_index, prefer_legacy_selected=True):
    labels = [label for label, _default in EFFECT_KNOBS[effect_name]]
    values = knob_values_for_effect(
        state, effect_name, effect_index,
        prefer_legacy_selected=prefer_legacy_selected)
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
    return PEDAL_LABEL_TO_MODEL.get(DIST_MODELS[idx], "tube_screamer")


def _distortion_pedal_index_from_state(state):
    idx = int(getattr(state, "dist_model_idx", 1) or 0)
    if idx < 0:
        idx = 0
    if idx >= len(DIST_MODELS):
        idx = len(DIST_MODELS) - 1
    return idx


def _cab_model_from_state(state, knobs, source):
    idx = int(getattr(state, "cab_model_idx", 1) or 0)
    if source == "knob_or_state" and "model" in knobs:
        idx = int(round(_clamp(knobs["model"], 0, 100) * 2.0 / 100.0))
    if idx < 0:
        idx = 0
    if idx > 2:
        idx = 2
    return idx


def _amp_character_from_state(state, knobs):
    if "char" in knobs:
        return percent(knobs["char"])
    idx = int(getattr(state, "amp_model_idx", 1) or 0)
    if idx < 0:
        idx = 0
    if idx >= len(AMP_MODELS):
        idx = len(AMP_MODELS) - 1
    return percent(AMP_MODEL_CHARACTER[AMP_MODELS[idx]])


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


def app_state_to_audio_lab_sections(state, effect_on_defaults=None,
                                    cab_model_source="knob_or_state",
                                    prefer_legacy_selected=True):
    """Return a dict-of-dicts matching current AudioLab effect sections."""
    ns = knob_map(state, EFFECT_NOISE_SUP, 0, prefer_legacy_selected)
    comp = knob_map(state, EFFECT_COMPRESSOR, 1, prefer_legacy_selected)
    od = knob_map(state, EFFECT_OVERDRIVE, 2, prefer_legacy_selected)
    dist = knob_map(state, EFFECT_DISTORTION, 3, prefer_legacy_selected)
    amp = knob_map(state, EFFECT_AMP, 4, prefer_legacy_selected)
    cab = knob_map(state, EFFECT_CAB, 5, prefer_legacy_selected)
    eq = knob_map(state, EFFECT_EQ, 6, prefer_legacy_selected)
    rev = knob_map(state, EFFECT_REVERB, 7, prefer_legacy_selected)

    defaults = effect_on_defaults or _DEFAULT_EFFECT_ON
    return {
        "noise_suppressor": {
            "enabled": effect_enabled(state, 0, defaults),
            "threshold": percent(ns.get("thresh", 35)),
            "decay": percent(ns.get("decay", 45)),
            "damp": percent(ns.get("damp", 80)),
        },
        "compressor": {
            "enabled": effect_enabled(state, 1, defaults),
            "threshold": percent(comp.get("thresh", 50)),
            "ratio": percent(comp.get("ratio", 45)),
            "response": percent(comp.get("resp", comp.get("response", 40))),
            "makeup": percent(comp.get("makeup", 55)),
        },
        "overdrive": {
            "enabled": effect_enabled(state, 2, defaults),
            "drive": percent(od.get("drive", 35)),
            "tone": percent(od.get("tone", 60)),
            "level": percent(od.get("level", 60)),
        },
        "distortion": {
            "enabled": effect_enabled(state, 3, defaults),
            "pedal": _distortion_pedal_from_state(state),
            "pedal_index": _distortion_pedal_index_from_state(state),
            "exclusive": True,
            "drive": percent(dist.get("drive", 50)),
            "tone": percent(dist.get("tone", 55)),
            "level": percent(dist.get("level", 35)),
            "bias": percent(dist.get("bias", 50)),
            "tight": percent(dist.get("tight", 60)),
            "mix": percent(dist.get("mix", 100)),
        },
        "amp": {
            "enabled": effect_enabled(state, 4, defaults),
            "input_gain": percent(amp.get("gain", 45)),
            "bass": percent(amp.get("bass", 55)),
            "middle": percent(amp.get("mid", 60)),
            "treble": percent(amp.get("treb", amp.get("treble", 50))),
            "presence": percent(amp.get("pres", amp.get("presence", 45))),
            "resonance": percent(amp.get("res", amp.get("resonance", 35))),
            "master": percent(amp.get("mstr", amp.get("master", 70))),
            "character": _amp_character_from_state(state, amp),
        },
        "cab": {
            "enabled": effect_enabled(state, 5, defaults),
            "mix": percent(cab.get("mix", 100)),
            "level": percent(cab.get("level", 70)),
            "model": _cab_model_from_state(state, cab, cab_model_source),
            "air": percent(cab.get("air", 35)),
        },
        "eq": {
            "enabled": effect_enabled(state, 6, defaults),
            "low": level_200(eq.get("low", 50)),
            "mid": level_200(eq.get("mid", 55)),
            "high": level_200(eq.get("high", 55)),
        },
        "reverb": {
            "enabled": effect_enabled(state, 7, defaults),
            "decay": percent(rev.get("decay", 30)),
            "tone": percent(rev.get("tone", 65)),
            "mix": percent(rev.get("mix", 25)),
        },
    }


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
    """Dry-run friendly plan object returned by apply planners."""

    def __init__(self, operations=None, warnings=None, sections=None,
                 unsupported=None):
        self.operations = list(operations or [])
        self.warnings = list(warnings or [])
        self.sections = sections or {}
        self.unsupported = list(unsupported or [])

    def as_dict(self):
        return {
            "operations": [op.as_dict() for op in self.operations],
            "warnings": list(self.warnings),
            "sections": dict(self.sections),
        }


def guitar_effects_kwargs(sections, include_noise_gate_threshold=True,
                          include_distortion_pedal_mask=False,
                          distortion_on_requires_pedal=True,
                          skip_rat=False,
                          force_rat_off=False):
    ns = sections["noise_suppressor"]
    od = sections["overdrive"]
    dist = sections["distortion"]
    amp = sections["amp"]
    cab = sections["cab"]
    eq = sections["eq"]
    rev = sections["reverb"]
    pedal = dist.get("pedal")
    pedal_index = int(dist.get("pedal_index", 0) or 0)
    unsupported = []

    if distortion_on_requires_pedal:
        dist_on = bool(dist["enabled"] and pedal)
    else:
        dist_on = bool(dist["enabled"])

    pedal_mask = 0
    if pedal:
        if pedal_index == RAT_PEDAL_INDEX and skip_rat:
            unsupported.append("Distortion:rat")
        else:
            pedal_mask = (1 << pedal_index) & 0x7F

    rat_on = False
    if not force_rat_off:
        rat_on = bool(dist_on and pedal == "rat")

    kwargs = {
        "noise_gate_on": bool(ns["enabled"]),
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
        "rat_on": rat_on,
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
    if include_noise_gate_threshold:
        kwargs["noise_gate_threshold"] = ns["threshold"]
    if include_distortion_pedal_mask:
        kwargs["distortion_pedal_mask"] = int(pedal_mask) & 0x7F
    return kwargs, unsupported


def full_state_plan(state):
    """Return all overlay calls implied by an AppState snapshot."""
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
    guitar_kwargs, unsupported = guitar_effects_kwargs(sections)
    ops.append(BridgeOperation(
        "guitar_effects",
        "set_guitar_effects",
        guitar_kwargs,
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
    return BridgePlan(
        ops, warnings=warnings, sections=sections, unsupported=unsupported)


def encoder_state_plan(state, skip_rat=True):
    """Plan the Phase 7G+ encoder live-apply write sequence.

    This preserves D37: use dedicated noise/compressor setters plus one
    grouped ``set_guitar_effects`` call; do not use raw GPIO writes or
    distortion shortcut setters from the encoder runtime.
    """
    sections = app_state_to_audio_lab_sections(
        state,
        effect_on_defaults=_ENCODER_EFFECT_ON_DEFAULTS,
        cab_model_source="state",
        prefer_legacy_selected=False)
    ns = sections["noise_suppressor"]
    comp = sections["compressor"]
    ops = [
        BridgeOperation(
            "noise_suppressor",
            "set_noise_suppressor_settings",
            dict(threshold=ns["threshold"], decay=ns["decay"],
                 damp=ns["damp"], enabled=ns["enabled"]),
            reason="Encoder AppState Noise Suppressor section",
            throttle_key="noise_suppressor",
        ),
        BridgeOperation(
            "compressor",
            "set_compressor_settings",
            dict(threshold=comp["threshold"], ratio=comp["ratio"],
                 response=comp["response"], makeup=comp["makeup"],
                 enabled=comp["enabled"]),
            reason="Encoder AppState Compressor section",
            throttle_key="compressor",
        ),
    ]
    guitar_kwargs, unsupported = guitar_effects_kwargs(
        sections,
        include_noise_gate_threshold=False,
        include_distortion_pedal_mask=True,
        distortion_on_requires_pedal=False,
        skip_rat=skip_rat,
        force_rat_off=True)
    ops.append(BridgeOperation(
        "guitar_effects",
        "set_guitar_effects",
        guitar_kwargs,
        reason="Encoder grouped effect state",
        throttle_key="guitar_effects",
    ))
    return BridgePlan(ops, sections=sections, unsupported=unsupported)


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


def is_rat_pedal_index(idx):
    try:
        return int(idx) == RAT_PEDAL_INDEX
    except Exception:
        return False


__all__ = [
    "BridgeOperation",
    "BridgePlan",
    "FIXED_DSP_CHAIN",
    "RAT_PEDAL_INDEX",
    "SUPPORTED_EFFECTS",
    "UNSUPPORTED_LIVE_EFFECTS",
    "app_state_to_audio_lab_sections",
    "chain_is_hardware_order",
    "chain_preset_name_from_state",
    "chain_preset_plan",
    "effect_enabled",
    "encoder_state_plan",
    "full_state_plan",
    "guitar_effects_kwargs",
    "is_rat_pedal_index",
    "knob_map",
    "knob_values_for_effect",
    "level_200",
    "level_200_float",
    "percent",
    "percent_float",
    "safe_bypass_plan",
]
