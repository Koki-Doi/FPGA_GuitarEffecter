"""High-level mapping from encoder events to AppState / overlay mutations.

Spec (D47):

* Encoder 0 rotate          -- cycle ``selected_effect``.
* Encoder 0 button-down edge -- toggle ``effect_on[selected_effect]``.
                                Skips toggle when the current slot is PRESET-
                                like (not an EFFECT in ``EFFECT_KNOBS``).
                                Driven by ``button_state`` rising edge, not by
                                ``short_press``; hold does not auto-repeat,
                                release does not toggle.
* Encoder 1 rotate w/o hold -- cycle ``selected_knob``.
* Encoder 1 rotate w/ hold  -- cycle the model index of the selected effect
                                (Overdrive / Distortion / Amp / Cab).
                                Non-model effects ignore hold+rotate.
* Encoder 2 rotate           -- adjust the focused knob value.
* Encoder 1 / Encoder 2 standalone button: no-op.

``short_press`` / ``long_press`` / ``click`` event kinds are NOT used as
command sources. The PL IP still latches them but the controller drops
them. Encoder 0 ON/OFF runs through ``process_button_state(pressed)``.

Live apply (Phase 7G+) goes through ``EncoderEffectApplier``; the
controller never writes raw GPIO.
"""

from typing import Iterable, List, Optional, Sequence

try:  # noqa: SIM105 — import guard is needed to keep this file workstation-safe
    from GUI.compact_v2.knobs import EFFECTS, EFFECT_KNOBS  # type: ignore
except Exception:  # pragma: no cover — fallback when run from inside /GUI
    try:
        from compact_v2.knobs import EFFECTS, EFFECT_KNOBS  # type: ignore
    except Exception:
        EFFECTS = []  # type: ignore
        EFFECT_KNOBS = {}  # type: ignore

from audio_lab_pynq.encoder_effect_apply import RAT_PEDAL_INDEX


# Effects whose top chip shows a model dropdown (per Phase 6H spec, DECISIONS D24).
MODEL_EFFECTS = {"Overdrive", "Distortion", "Amp Sim", "Cab IR"}

# Per-rotate step size on a value knob (0..100 scale). Encoders typically
# emit ~24 detents per revolution; 5 % per detent gives a full sweep in ~4
# revolutions which feels natural for a guitar pedal.
DEFAULT_VALUE_STEP = 5.0


class EncoderUiController:
    """Translate ``EncoderEvent`` + button_state into ``AppState`` mutations."""

    def __init__(
        self,
        state,
        *,
        mirror=None,
        overlay=None,
        bridge=None,
        applier=None,
        live_apply=None,
        skip_rat=True,
        value_step: float = DEFAULT_VALUE_STEP,
        apply_on_value_change: bool = False,
    ):
        self.state = state
        self.mirror = mirror
        self.overlay = overlay
        self.bridge = bridge
        self.applier = applier
        if live_apply is None:
            live_apply = applier is not None
        self.live_apply = bool(live_apply)
        self.skip_rat = bool(skip_rat)
        self.value_step = float(value_step)
        self.apply_on_value_change = bool(apply_on_value_change)
        # Live button state per encoder, updated each tick/poll.
        self._current_pressed: List[bool] = [False, False, False]
        # Previous button state -- None until first observation so we never
        # emit a spurious rising-edge on first tick.
        self._prev_pressed: Optional[List[bool]] = None
        # Set inside tick() when the HW short_press latch already triggered
        # the Encoder 0 toggle, so the subsequent level-edge check inside
        # process_button_state() does not double-fire on the same tap.
        self._enc0_toggle_consumed_this_tick: bool = False

    # -- helpers ---------------------------------------------------------------

    def _ensure_focus_fields(self) -> None:
        for name, default in (
            ("focus_effect_index", getattr(self.state, "selected_effect", 0)),
            ("focus_param_index",  getattr(self.state, "selected_knob",   0)),
            ("edit_mode",          False),
            ("model_select_mode",  False),
            ("value_dirty",        False),
            ("apply_pending",      False),
            ("last_encoder_event", None),
            ("last_control_source", "notebook"),
            ("live_apply",         self.live_apply),
            ("last_apply_ok",      True),
            ("last_apply_message", ""),
            ("last_unsupported_label", ""),
        ):
            if not hasattr(self.state, name):
                setattr(self.state, name, default)

    def _effect_name(self, idx: Optional[int] = None) -> str:
        if idx is None:
            idx = getattr(self.state, "selected_effect", 0)
        if not EFFECTS:
            return ""
        return EFFECTS[max(0, min(int(idx), len(EFFECTS) - 1))]

    def _knob_count(self) -> int:
        name = self._effect_name()
        if not name or name not in EFFECT_KNOBS:
            return 0
        return len(EFFECT_KNOBS[name])

    def _propagate_applier_status(self):
        if self.applier is None:
            return
        self.state.last_apply_ok = bool(getattr(self.applier, "last_apply_ok", True))
        self.state.last_apply_message = str(
            getattr(self.applier, "last_apply_message", ""))
        unsupported = getattr(self.applier, "unsupported", []) or []
        self.state.last_unsupported_label = ", ".join(str(u) for u in unsupported)

    def _maybe_live_apply(self, *, force=False) -> None:
        if self.applier is None or not self.live_apply:
            return
        ran = self.applier.apply_appstate(self.state, force=force)
        if ran:
            self._propagate_applier_status()
            if force:
                self.state.value_dirty = False
                self.state.apply_pending = False

    # -- button state ----------------------------------------------------------

    def set_button_state(self, pressed: Sequence[bool]) -> None:
        """Set the current encoder button state without emitting edges.

        Useful in tests to position the controller before dispatching a rotate
        event (i.e. simulating ``encoder 1 held while rotating``).
        """
        cur = list(self._current_pressed)
        for i, val in enumerate(pressed):
            if i < 3:
                cur[i] = bool(val)
        self._current_pressed = cur

    def process_button_state(self, current: Sequence[bool]) -> None:
        """Update the current button state and emit Encoder 0 rising-edge toggle.

        Encoder 1 / Encoder 2 standalone presses are intentionally no-ops
        (their hold state is consulted by the rotate dispatch instead).
        Hold does not auto-repeat; release does not toggle.
        """
        self._ensure_focus_fields()
        cur = [False, False, False]
        for i, val in enumerate(current):
            if i < 3:
                cur[i] = bool(val)

        if self._prev_pressed is None:
            # First observation: seed prev/current without emitting any edge.
            self._prev_pressed = list(cur)
            self._current_pressed = list(cur)
            # Live-press status mirrored onto AppState for the renderer hint.
            self.state.model_select_mode = bool(cur[1])
            return

        prev = self._prev_pressed
        if (not prev[0]) and cur[0] and not self._enc0_toggle_consumed_this_tick:
            self._enc0_button_down_edge()
        # Encoder 1 / Encoder 2 button: no-op.
        # No short_press / long_press / click handling on any encoder.

        self._prev_pressed = list(cur)
        self._current_pressed = list(cur)
        # Reflect the live encoder-1 hold so the renderer can flag MODEL.
        self.state.model_select_mode = bool(cur[1])

    def _is_preset_slot(self, idx: int) -> bool:
        """Return True if the current selection is a PRESET-like slot.

        Today ``EFFECTS`` carries no PRESET item so this only fires on a
        future PRESET being injected into ``EFFECTS`` without a matching
        ``EFFECT_KNOBS`` entry. Either way PRESET is not bypassable from
        the encoder, so we treat it as a no-op.
        """
        if not EFFECTS or not (0 <= idx < len(EFFECTS)):
            return True
        name = EFFECTS[idx]
        if name not in EFFECT_KNOBS:
            return True
        if "preset" in name.lower() or "safe bypass" in name.lower():
            return True
        return False

    def _enc0_button_down_edge(self) -> None:
        idx = int(getattr(self.state, "selected_effect", 0))
        on_list = getattr(self.state, "effect_on", []) or []
        if not (0 <= idx < len(on_list)):
            return
        if self._is_preset_slot(idx):
            return
        self.state.effect_on[idx] = not self.state.effect_on[idx]
        self.state.value_dirty = True
        self.state.apply_pending = True
        self.state.last_control_source = "encoder"
        if self.applier is not None and self.live_apply:
            new_state = bool(self.state.effect_on[idx])
            name = self._effect_name(idx)
            ok = self.applier.apply_effect_on_off(name, new_state)
            self._propagate_applier_status()
            if ok:
                self._maybe_live_apply(force=True)

    # -- event dispatch --------------------------------------------------------

    def handle_event(self, event) -> None:
        self._ensure_focus_fields()
        self.state.last_encoder_event = {
            "kind": event.kind, "encoder_id": event.encoder_id,
            "delta": getattr(event, "delta", 0),
        }
        self.state.last_control_source = "encoder"
        self.state.live_apply = self.live_apply

        eid = event.encoder_id
        if event.kind == "rotate":
            if eid == 0:
                self._enc0_rotate(event.delta)
            elif eid == 1:
                self._enc1_rotate(event.delta)
            elif eid == 2:
                self._enc2_rotate(event.delta)
            return
        # The HW short_press latch on Encoder 0 is consumed here as a
        # fallback for taps shorter than the poll period. The level-edge
        # path in process_button_state() still catches long presses; the
        # consumed flag prevents a double toggle in the same tick.
        # Encoder 1 / Encoder 2 button events (short / long / release)
        # remain dropped per D47.
        if event.kind == "short_press" and eid == 0:
            self._enc0_button_down_edge()
            self._enc0_toggle_consumed_this_tick = True

    def handle_events(self, events: Iterable) -> None:
        for ev in events:
            self.handle_event(ev)

    def tick(self, encoder_input, *, timestamp: float = 0.0) -> int:
        """Convenience for the runner loop.

        Reads events + button_state from the encoder driver, dispatches
        rotate events, and processes the Encoder 0 button-down edge.
        Returns the number of events dispatched.
        """
        events = encoder_input.poll(timestamp=timestamp)
        cur = [False, False, False]
        try:
            level = int(encoder_input.read_button_state()) & 0x7
            cur = [bool((level >> i) & 1) for i in range(3)]
        except Exception:
            cur = list(self._current_pressed)
        # Position pressed state BEFORE handle_events so encoder-1 rotate
        # dispatch sees the live hold.
        self._current_pressed = list(cur)
        self._enc0_toggle_consumed_this_tick = False
        self.handle_events(events)
        self.process_button_state(cur)
        if self.apply_on_value_change and getattr(self.state, "apply_pending", False):
            self.apply()
        return len(events)

    # Kept for backwards compatibility with the previous runner shape.
    poll_and_apply = tick

    # -- encoder 0: select effect ---------------------------------------------

    def _enc0_rotate(self, delta: int) -> None:
        if not EFFECTS:
            return
        n = len(EFFECTS)
        new_idx = (int(self.state.selected_effect) + int(delta)) % n
        self.state.selected_effect = new_idx
        self.state.focus_effect_index = new_idx
        kc = self._knob_count()
        if kc and int(self.state.selected_knob) >= kc:
            self.state.selected_knob = kc - 1
        if hasattr(self.state, "focus_param_index"):
            self.state.focus_param_index = self.state.selected_knob

    # -- encoder 1: select knob or model --------------------------------------

    def _enc1_rotate(self, delta: int) -> None:
        if self._current_pressed[1]:
            name = self._effect_name()
            if name in MODEL_EFFECTS:
                self._cycle_model_index(name, delta)
            # Non-model effect with encoder-1 held: no-op (do not touch knob).
            return
        kc = self._knob_count()
        if kc <= 0:
            return
        new_idx = (int(self.state.selected_knob) + int(delta)) % kc
        self.state.selected_knob = new_idx
        self.state.focus_param_index = new_idx

    def _cycle_model_index(self, effect_name: str, delta: int) -> None:
        spec = {
            "Distortion": ("dist_model_idx", 7),
            # Overdrive owns ``overdrive_model_idx`` (D45 / D46). It does NOT
            # alias ``dist_model_idx``; cycling on Overdrive must leave the
            # distortion pedal mask untouched.
            "Overdrive":  ("overdrive_model_idx", 6),
            "Amp Sim":    ("amp_model_idx",  6),
            "Cab IR":     ("cab_model_idx",  3),
        }.get(effect_name)
        if spec is None:
            return
        attr, n = spec
        cur = int(getattr(self.state, attr, 0))
        step = int(delta)
        if step == 0:
            return
        new_idx = (cur + step) % n
        if attr == "dist_model_idx" and self.skip_rat:
            guard = 0
            direction = 1 if step > 0 else -1
            while new_idx == RAT_PEDAL_INDEX and guard < n:
                new_idx = (new_idx + direction) % n
                guard += 1
            if new_idx == RAT_PEDAL_INDEX:
                new_idx = cur
        setattr(self.state, attr, new_idx)
        self.state.value_dirty = True
        self.state.apply_pending = True
        self._maybe_live_apply(force=True)

    # -- encoder 2: change knob value -----------------------------------------

    def _enc2_rotate(self, delta: int) -> None:
        kc = self._knob_count()
        if kc <= 0:
            return
        idx = max(0, min(int(self.state.selected_knob), kc - 1))
        name = self._effect_name()
        vals = self.state.all_knob_values.get(name)
        if vals is None or idx >= len(vals):
            return
        new_val = float(vals[idx]) + (float(delta) * self.value_step)
        new_val = max(0.0, min(100.0, new_val))
        vals[idx] = new_val
        # ``edit_mode`` is a renderer-visible hint, not a persistent toggle.
        self.state.edit_mode = True
        self.state.value_dirty = True
        self.state.apply_pending = True
        # Throttled live apply -- a fast rotation cannot flood AXI.
        self._maybe_live_apply(force=False)

    # -- apply -----------------------------------------------------------------

    def apply(self) -> None:
        """Push the current AppState into the overlay (explicit call only).

        No encoder button triggers this in the D47 spec. The method stays
        for off-board tests / future callers that want to force a flush.
        """
        applied = False
        if self.applier is not None:
            self.applier.apply_appstate(self.state, force=True)
            self._propagate_applier_status()
            applied = True
        if not applied and self.mirror is not None:
            try:
                self.mirror.update_from_appstate(self.state)
                applied = True
            except AttributeError:
                if hasattr(self.mirror, "update"):
                    self.mirror.update(self.state)
                    applied = True
        if not applied and self.overlay is not None:
            bridge = self.bridge
            if bridge is None:
                from GUI.audio_lab_gui_bridge import AudioLabGuiBridge  # type: ignore
                bridge = AudioLabGuiBridge()
                self.bridge = bridge
            bridge.apply(self.state, overlay=self.overlay, dry_run=False,
                         force=True, event="encoder_apply")
            applied = True
        self.state.apply_pending = False
        self.state.value_dirty = False
