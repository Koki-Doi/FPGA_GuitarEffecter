"""AppState dataclass + on-disk persistence for the compact-v2 GUI.

`save_state_json` / `load_state_json` round-trip the user-visible fields
into ``fx_gui_state.json`` so the same chain / effect_on / knob values
return after a kernel restart.
"""

import json
import os
from typing import List, Tuple

from .knobs import EFFECTS, EFFECT_KNOBS, _EFFECT_KNOB_DEFAULTS

try:
    from dataclasses import dataclass, field
except ImportError:
    _MISSING = object()

    class _CompatField:
        def __init__(self, default=_MISSING, default_factory=_MISSING):
            self.default = default
            self.default_factory = default_factory

        def value(self):
            if self.default_factory is not _MISSING:
                return self.default_factory()
            if self.default is not _MISSING:
                return self.default
            raise TypeError("missing default")

    def field(default=_MISSING, default_factory=_MISSING):
        return _CompatField(default=default, default_factory=default_factory)

    def dataclass(cls):
        annotations = getattr(cls, "__annotations__", {})
        names = list(annotations.keys())
        defaults = {name: getattr(cls, name, _MISSING) for name in names}

        def __init__(self, *args, **kwargs):
            if len(args) > len(names):
                raise TypeError("__init__() takes %d positional arguments but %d were given" %
                                (len(names) + 1, len(args) + 1))
            positional = dict(zip(names, args))
            for name in names:
                if name in positional and name in kwargs:
                    raise TypeError("__init__() got multiple values for argument '%s'" % name)
                if name in positional:
                    value = positional[name]
                elif name in kwargs:
                    value = kwargs.pop(name)
                else:
                    default = defaults.get(name, _MISSING)
                    if isinstance(default, _CompatField):
                        value = default.value()
                    elif default is not _MISSING:
                        value = default
                    else:
                        raise TypeError("__init__() missing required argument: '%s'" % name)
                setattr(self, name, value)
            if kwargs:
                unknown = next(iter(kwargs))
                raise TypeError("__init__() got an unexpected keyword argument '%s'" % unknown)

        def __repr__(self):
            parts = ["%s=%r" % (name, getattr(self, name)) for name in names]
            return "%s(%s)" % (cls.__name__, ", ".join(parts))

        cls.__init__ = __init__
        cls.__repr__ = __repr__
        return cls


@dataclass
class AppState:
    preset_id: str   = "02A"
    preset_name: str = "BASIC  CLEAN"
    preset_idx: int  = 1     # index into CHAIN_PRESETS (0..12)
    bpm: int         = 120
    key: str         = "E"

    # signal-chain (indices into EFFECTS — drag-reorder writes into this list)
    chain: List[int] = field(default_factory=lambda: list(range(8)))
    # ON/OFF per effect (indexed by chain position == EFFECTS index in default order)
    effect_on: List[bool] = field(default_factory=lambda:
        [True,  True, False, False, True, True, True, True])
    selected_effect: int  = 4   # Amp Sim

    # per-effect independent knob storage (effect name → list of floats)
    all_knob_values: dict = field(default_factory=lambda: {
        name: list(vals) for name, vals in _EFFECT_KNOB_DEFAULTS.items()})
    selected_knob: int = 0

    # model-pick indices for the three model-driven effects
    dist_model_idx: int = 1   # Tube Screamer
    amp_model_idx:  int = 2   # British Crunch
    cab_model_idx:  int = 2   # 4x12 British

    # footswitches
    fs_states: List[bool] = field(default_factory=lambda:
        [False, False, True, False, False, True, False, False])
    fs_selected: int = 0

    # visualizer mode: 'wave' | 'spectrum' | 'both'
    display_mode: str = "both"

    # animation clock (seconds)
    t: float = 0.0

    # transient flash (seconds remaining)
    save_flash: float = 0.0

    # I/O metering — driven from t inside the renderer for live feel
    in_level: float  = 0.6
    out_level: float = 0.7
    cpu: int         = 42

    # ------ Phase 7G encoder focus state -----------------------------------
    # These fields mirror selected_effect / selected_knob and add edit /
    # apply / source bookkeeping for the EncoderUiController. Defaults are
    # chosen so existing renderers and notebooks that ignore them keep
    # rendering identically (focus_* equal to selected_*, edit modes off).
    focus_effect_index: int   = 4    # tracks selected_effect by default
    focus_param_index:  int   = 0
    edit_mode:          bool  = False
    model_select_mode:  bool  = False
    value_dirty:        bool  = False
    apply_pending:      bool  = False
    last_control_source: str  = "notebook"   # "notebook" | "encoder"
    last_encoder_event: object = None        # most recent dict from EncoderUiController

    # ------ Phase 7G+ live-apply status (set by EncoderEffectApplier) ------
    live_apply:              bool = True
    apply_interval_ms:       int  = 100
    last_apply_ok:           bool = True
    last_apply_message:      str  = ""
    last_unsupported_label:  str  = ""

    def knobs(self) -> List[Tuple[str, float]]:
        name = EFFECTS[self.selected_effect]
        spec = EFFECT_KNOBS[name]
        vals = self.all_knob_values.get(name, [float(k[1]) for k in spec])
        return [(label, val) for (label, _), val in zip(spec, vals)]

    def set_knob(self, knob_idx: int, value: float) -> None:
        name = EFFECTS[self.selected_effect]
        vals = self.all_knob_values.get(name)
        if vals is not None and 0 <= knob_idx < len(vals):
            vals[knob_idx] = max(0.0, min(100.0, float(value)))


STATE_FILE = "fx_gui_state.json"

_STATE_KEYS = ("preset_id", "preset_name", "preset_idx",
               "selected_effect", "selected_knob",
               "effect_on", "all_knob_values", "chain", "display_mode",
               "dist_model_idx", "amp_model_idx", "cab_model_idx",
               "fs_states", "fs_selected")

def save_state_json(state: AppState, path: str = STATE_FILE) -> None:
    try:
        data = {k: getattr(state, k) for k in _STATE_KEYS}
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
    except Exception as exc:
        print(f"[state] save failed: {exc}")


def load_state_json(path: str = STATE_FILE) -> AppState:
    state = AppState()
    if not os.path.exists(path):
        return state
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        for k in _STATE_KEYS:
            if k in data:
                setattr(state, k, data[k])
        # sanity: list / dict lengths
        if len(state.effect_on) != len(EFFECTS):
            state.effect_on = [True] * len(EFFECTS)
        for _nm in EFFECTS:
            _expected = len(EFFECT_KNOBS.get(_nm, []))
            if (not isinstance(state.all_knob_values, dict) or
                    _nm not in state.all_knob_values or
                    len(state.all_knob_values[_nm]) != _expected):
                if not isinstance(state.all_knob_values, dict):
                    state.all_knob_values = {}
                state.all_knob_values[_nm] = [float(k[1]) for k in EFFECT_KNOBS[_nm]]
        if len(state.chain) != len(EFFECTS):
            state.chain = list(range(len(EFFECTS)))
        state.selected_effect = max(0, min(len(EFFECTS) - 1,
                                           state.selected_effect))
        _n_knobs = len(EFFECT_KNOBS.get(EFFECTS[state.selected_effect], []))
        state.selected_knob = max(0, min(max(0, _n_knobs - 1),
                                         state.selected_knob))
    except Exception as exc:
        print(f"[state] load failed ({exc}); using defaults")
        state = AppState()
    return state
