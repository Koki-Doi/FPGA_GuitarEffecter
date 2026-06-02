"""Footswitch -> action layer for the compact-v2 GUI runtime.

Translates decoded ``FootswitchEvent`` instances (from
``audio_lab_pynq.footswitch_input``) into three fixed actions:

  * channel 0 (FX toggle)   -> toggle the *bound* effect on/off.
  * channel 1 (preset next) -> advance to the next chain preset.
  * channel 2 (preset prev) -> step to the previous chain preset.

FX-target binding
-----------------
A single press of FS1 toggles whichever effect is currently bound
(``AppState.footswitch_fx_target``). To *rebind* FS1 to a different
effect, select that effect in the GUI (encoder 0 drives
``AppState.selected_effect``) and stomp FS1 ``rebind_count`` times within
``rebind_window_s`` seconds. The burst rebinds the target to the
GUI-selected effect and leaves the old target's on/off state unchanged
(``rebind_count`` is odd, so the burst's toggles net back to where they
started and the rebind press itself does not toggle).

The single-press toggle is applied *immediately* (a stomp must feel
instant), so a deliberate rebind burst briefly flickers the old target;
that is accepted because it only happens during the intentional fast-tap
gesture.

Translation discipline
-----------------------
* FX toggle goes through ``EncoderEffectApplier.apply_effect_on_off`` --
  the same single-translation layer the encoder uses. It writes only the
  one effect's enable bit, so a curated preset voicing is preserved.
* Preset switching calls ``AudioLabOverlay.apply_chain_preset`` (the same
  public method the notebook preset buttons use) for the authoritative
  audio write, then mirrors the preset into ``AppState`` for the HDMI GUI
  via ``apply_chain_preset_to_state``.

This module is import-safe on workstations without ``pynq`` installed:
the package-level imports (``effect_presets`` / ``effect_defaults``, which
pull in ``audio_lab_pynq/__init__`` -> ``pynq``) are done lazily inside
the functions that need them.
"""

from .footswitch_input import CH_FX_TOGGLE, CH_PRESET_NEXT, CH_PRESET_PREV

# AppState.effect_on index per effect (mirrors GUI/compact_v2/knobs.py EFFECTS
# and audio_lab_pynq/encoder_effect_apply.py::_EFFECT_ON_INDEX).
IDX_NOISE_SUP  = 0
IDX_COMPRESSOR = 1
IDX_WAH        = 2
IDX_OVERDRIVE  = 3
IDX_DISTORTION = 4
IDX_AMP        = 5
IDX_CAB        = 6
IDX_EQ         = 7
IDX_REVERB     = 8
NUM_EFFECTS    = 9

DEFAULT_REBIND_COUNT    = 5
DEFAULT_REBIND_WINDOW_S = 3.0


def chain_preset_names():
    """Ordered list of chain-preset names (insertion order of CHAIN_PRESETS)."""
    from .effect_presets import CHAIN_PRESETS
    return list(CHAIN_PRESETS.keys())


def _pedal_index(name):
    """Map a distortion pedal name to its pedal-mask bit index, or None."""
    from .effect_defaults import DISTORTION_PEDALS
    try:
        return list(DISTORTION_PEDALS).index(str(name))
    except (ValueError, TypeError):
        return None


def _set_knobs(state, effect_name, values):
    vals = getattr(state, "all_knob_values", None)
    if not isinstance(vals, dict):
        return
    cur = vals.get(effect_name)
    if not isinstance(cur, list):
        return
    for i, v in enumerate(values):
        if i < len(cur) and v is not None:
            try:
                cur[i] = float(v)
            except (TypeError, ValueError):
                pass


def apply_chain_preset_to_state(state, preset_name):
    """Mirror a CHAIN_PRESETS entry into AppState for GUI display.

    Audio is written separately by ``AudioLabOverlay.apply_chain_preset``;
    this only updates the on-screen state so the HDMI GUI follows a
    footswitch preset change. Sections absent from a preset (e.g. Wah) are
    left untouched, matching what ``apply_chain_preset`` writes.

    Knob-scale notes:
      * D80 presets are user-facing physical knob positions. The audio write
        path applies ``knob_tapers`` inside ``AudioLabOverlay.apply_chain_preset``;
        this mirror intentionally keeps the raw positions for display.
      * EQ presets are on the overlay 0..200 scale (100 = unity); the GUI
        knob is 0..100 (50 = unity), so values are halved here.
      * Cab MODEL is carried by ``AppState.cab_model_idx`` (the applier
        overrides the MODEL knob with it).
      * Amp model index / Overdrive model index / Amp drive mode are not
        carried by the legacy presets, so they are left unchanged.
    """
    from .effect_presets import CHAIN_PRESETS
    spec = CHAIN_PRESETS.get(preset_name)
    if not spec:
        return

    eff_on = list(getattr(state, "effect_on", []) or [])
    if len(eff_on) < NUM_EFFECTS:
        eff_on = (eff_on + [False] * NUM_EFFECTS)[:NUM_EFFECTS]

    comp = spec.get("compressor", {})
    ns   = spec.get("noise_suppressor", {})
    od   = spec.get("overdrive", {})
    dist = spec.get("distortion", {})
    amp  = spec.get("amp", {})
    cab  = spec.get("cab", {})
    eq   = spec.get("eq", {})
    rev  = spec.get("reverb", {})

    # ON/OFF flags
    eff_on[IDX_NOISE_SUP]  = bool(ns.get("enabled", False))
    eff_on[IDX_COMPRESSOR] = bool(comp.get("enabled", False))
    eff_on[IDX_OVERDRIVE]  = bool(od.get("enabled", False))
    dist_on = bool(dist.get("enabled", False)) and bool(dist.get("pedal"))
    eff_on[IDX_DISTORTION] = dist_on
    eff_on[IDX_AMP]        = bool(amp.get("enabled", False))
    eff_on[IDX_CAB]        = bool(cab.get("enabled", False))
    eff_on[IDX_EQ]         = bool(eq.get("enabled", False))
    eff_on[IDX_REVERB]     = bool(rev.get("enabled", False))
    state.effect_on = eff_on

    # Knob values (orderings mirror GUI/compact_v2/knobs.py).
    _set_knobs(state, "Noise Sup",
               [ns.get("threshold"), ns.get("decay"), ns.get("damp")])
    _set_knobs(state, "Compressor",
               [comp.get("threshold"), comp.get("ratio"),
                comp.get("response"), comp.get("makeup")])
    _set_knobs(state, "Overdrive",
               [od.get("tone"), od.get("level"), od.get("drive")])
    _set_knobs(state, "Distortion",
               [dist.get("tone"), dist.get("level"), dist.get("drive"),
                dist.get("bias"), dist.get("tight"), dist.get("mix")])
    _set_knobs(state, "Amp Sim",
               [amp.get("input_gain"), amp.get("bass"), amp.get("middle"),
                amp.get("treble"), amp.get("presence"), amp.get("resonance"),
                amp.get("master"), None])
    _set_knobs(state, "Cab IR",
               [cab.get("mix"), cab.get("level"), None, cab.get("air")])
    # EQ presets are 0..200 (100 unity); GUI knob is 0..100 (50 unity).
    def _half(v):
        return None if v is None else float(v) / 2.0
    _set_knobs(state, "EQ",
               [_half(eq.get("low")), _half(eq.get("mid")), _half(eq.get("high"))])
    _set_knobs(state, "Reverb",
               [rev.get("decay"), rev.get("tone"), rev.get("mix")])

    # Model indices that the presets DO carry.
    if dist_on:
        pidx = _pedal_index(dist.get("pedal"))
        if pidx is not None:
            state.dist_model_idx = int(pidx)
    cab_model = cab.get("model")
    if cab_model is not None:
        try:
            state.cab_model_idx = max(0, min(2, int(cab_model)))
        except (TypeError, ValueError):
            pass


class FootswitchController(object):
    """Map ``FootswitchEvent`` instances to FX-toggle / preset actions.

    Parameters
    ----------
    applier : EncoderEffectApplier
        Used for the FX on/off write (``apply_effect_on_off``). Shared with
        the encoder runtime so there is a single overlay-write translation
        layer for effect enables.
    state : AppState
        Mutated in place (effect_on, preset_idx/name, footswitch_fx_target).
    effects : sequence of str
        EFFECTS name list (GUI/compact_v2/knobs.py order).
    overlay : AudioLabOverlay or None
        Receives ``apply_chain_preset`` for the audio side of a preset
        switch. ``None`` (or ``dry_run``) skips the hardware write.
    preset_names : sequence of str or None
        Preset cycle order. Defaults to ``chain_preset_names()``.
    """

    def __init__(self, *, applier, state, effects, overlay=None,
                 preset_names=None, dry_run=False,
                 rebind_count=DEFAULT_REBIND_COUNT,
                 rebind_window_s=DEFAULT_REBIND_WINDOW_S):
        self.applier = applier
        self.state = state
        self.effects = list(effects)
        self.overlay = overlay
        self.dry_run = bool(dry_run)
        self.preset_names = list(preset_names) if preset_names else chain_preset_names()
        self.rebind_count = int(rebind_count)
        self.rebind_window_s = float(rebind_window_s)

        self._fx_press_ts = []
        self.last_action = "init"
        self.action_count = 0

        # Make sure the bound target is in range.
        self._clamp_target()

    # -- helpers --------------------------------------------------------------
    def _clamp_target(self):
        t = int(getattr(self.state, "footswitch_fx_target", 0) or 0)
        self.state.footswitch_fx_target = max(0, min(len(self.effects) - 1, t))

    def _target(self):
        self._clamp_target()
        return int(self.state.footswitch_fx_target)

    def _target_on(self, target):
        on = list(getattr(self.state, "effect_on", []) or [])
        return bool(on[target]) if 0 <= target < len(on) else False

    def _set_target_on(self, target, value):
        on = list(getattr(self.state, "effect_on", []) or [])
        if 0 <= target < len(on):
            on[target] = bool(value)
            self.state.effect_on = on

    def _record(self, message):
        self.last_action = str(message)
        self.action_count += 1

    # -- FX toggle (channel 0) ------------------------------------------------
    def _on_fx_press(self, ts):
        # Prune presses outside the rebind window, then register this one.
        self._fx_press_ts = [t for t in self._fx_press_ts
                             if (ts - t) <= self.rebind_window_s]
        self._fx_press_ts.append(ts)

        if len(self._fx_press_ts) >= self.rebind_count:
            # Rebind gesture: point FS1 at the GUI-selected effect. The
            # preceding (rebind_count - 1) toggles are even in number and
            # have already netted the old target back to its pre-burst
            # state, and this press intentionally does not toggle.
            self._fx_press_ts = []
            new_target = int(getattr(self.state, "selected_effect", self._target()))
            new_target = max(0, min(len(self.effects) - 1, new_target))
            self.state.footswitch_fx_target = new_target
            self._record("rebind FX -> %s" % self.effects[new_target])
            return

        # Normal single press: toggle the bound effect now.
        target = self._target()
        new_on = not self._target_on(target)
        self._set_target_on(target, new_on)
        name = self.effects[target]
        if not self.dry_run and self.applier is not None:
            self.applier.apply_effect_on_off(name, new_on)
        self._record("FX %s=%s" % (name, "ON" if new_on else "OFF"))

    # -- preset step (channels 1/2) -------------------------------------------
    def _change_preset(self, delta):
        names = self.preset_names
        n = len(names)
        if n == 0:
            return
        idx = (int(getattr(self.state, "preset_idx", 0) or 0) + delta) % n
        name = names[idx]
        self.state.preset_idx = idx
        self.state.preset_name = str(name).upper()
        self.state.preset_id = "%02d" % idx
        # Authoritative audio write via the curated preset path.
        if not self.dry_run and self.overlay is not None:
            try:
                self.overlay.apply_chain_preset(name)
            except Exception as exc:  # keep the loop alive on a bad write
                self._record("preset %+d ERR %r" % (delta, exc))
                apply_chain_preset_to_state(self.state, name)
                return
        # Mirror into AppState for the HDMI GUI.
        apply_chain_preset_to_state(self.state, name)
        self._record("preset %+d -> %s" % (delta, name))

    # -- dispatch -------------------------------------------------------------
    def handle_event(self, event):
        ch = getattr(event, "channel", None)
        ts = float(getattr(event, "timestamp", 0.0) or 0.0)
        if ch == CH_FX_TOGGLE:
            self._on_fx_press(ts)
        elif ch == CH_PRESET_NEXT:
            self._change_preset(+1)
        elif ch == CH_PRESET_PREV:
            self._change_preset(-1)

    def handle_events(self, events):
        n = 0
        for ev in events or ():
            self.handle_event(ev)
            n += 1
        return n

    def tick(self, footswitch, *, timestamp=0.0):
        """Poll the footswitch IP once and dispatch the resulting events."""
        events = footswitch.poll(timestamp=timestamp)
        return self.handle_events(events)
