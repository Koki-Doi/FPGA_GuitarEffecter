"""High-level mapping from encoder events to AppState / overlay mutations.

Encoder 1: focus / select effect.
Encoder 2: focus / select knob (or model when in model_select_mode).
Encoder 3: change the value of the focused knob; short_press applies pending
           changes to the overlay via the HDMI state mirror.

The controller never writes a raw GPIO. It updates ``AppState``, then -- when
``apply()`` is called -- it pushes the current per-effect values through the
``HdmiEffectStateMirror`` and ``AudioLabOverlay`` public API.

GUI-first live apply (Phase 7G+) goes through an ``EncoderEffectApplier``
which is the only Python object allowed to translate AppState into
``AudioLabOverlay`` ``set_*`` calls. The RAT pedal model is excluded from
encoder-driven control by default; the Clash stage stays intact, the
overlay API is untouched, and the existing notebook can still drive RAT
via the regular mirror calls.
"""

from typing import Iterable, Optional

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
# The encoder UI uses this to decide whether "encoder 2 short press" should
# enter model-select mode or fall back to a parameter-group toggle.
MODEL_EFFECTS = {"Overdrive", "Distortion", "Amp Sim", "Cab IR"}

# Per-rotate step size on a value knob (0..100 scale). Encoders typically
# emit ~24 detents per revolution; 5 % per detent gives a full sweep in ~4
# revolutions which feels natural for a guitar pedal.
DEFAULT_VALUE_STEP = 5.0


class EncoderUiController:
    """Translate ``EncoderEvent`` instances into ``AppState`` mutations."""

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
        # live_apply defaults to True when an applier was provided.
        if live_apply is None:
            live_apply = applier is not None
        self.live_apply = bool(live_apply)
        self.skip_rat = bool(skip_rat)
        self.value_step = float(value_step)
        # When False, value changes only commit to the DSP after encoder-3 short_press.
        # When True, every rotate commits immediately (useful for headless smoke).
        self.apply_on_value_change = bool(apply_on_value_change)

    # -- helpers ---------------------------------------------------------------

    def _ensure_focus_fields(self) -> None:
        """Backfill encoder fields onto an old AppState that predates Phase 7G."""
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
                self.state.edit_mode = False

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
        elif event.kind == "short_press":
            if eid == 0:
                self._enc0_short_press()
            elif eid == 1:
                self._enc1_short_press()
            elif eid == 2:
                self._enc2_short_press()
        elif event.kind == "long_press":
            if eid == 0:
                self._enc0_long_press()
            elif eid == 1:
                self._enc1_long_press()
            elif eid == 2:
                self._enc2_long_press()
        # 'release' is informational only

    def handle_events(self, events: Iterable) -> None:
        for ev in events:
            self.handle_event(ev)

    def poll_and_apply(self, encoder_input) -> int:
        """Convenience: poll the driver, dispatch events, optionally apply."""
        events = encoder_input.poll()
        self.handle_events(events)
        if self.apply_on_value_change and getattr(self.state, "apply_pending", False):
            self.apply()
        return len(events)

    # -- encoder 1: focus / select effect --------------------------------------

    def _enc0_rotate(self, delta: int) -> None:
        if not EFFECTS:
            return
        n = len(EFFECTS)
        new_idx = (int(self.state.selected_effect) + int(delta)) % n
        self.state.selected_effect = new_idx
        self.state.focus_effect_index = new_idx
        # Re-clamp the selected knob to the new effect's knob count
        kc = self._knob_count()
        if kc and int(self.state.selected_knob) >= kc:
            self.state.selected_knob = kc - 1
        if hasattr(self.state, "focus_param_index"):
            self.state.focus_param_index = self.state.selected_knob
        # Leaving model-select mode when the effect changes keeps the UI from
        # getting stuck in a sub-mode the new effect doesn't even own.
        self.state.model_select_mode = False
        self.state.edit_mode = False

    def _enc0_short_press(self) -> None:
        idx = int(self.state.selected_effect)
        if 0 <= idx < len(self.state.effect_on):
            self.state.effect_on[idx] = not self.state.effect_on[idx]
            self.state.value_dirty = True
            self.state.apply_pending = True
        # Live apply: flip the corresponding overlay flag immediately.
        if self.applier is not None and self.live_apply:
            name = self._effect_name()
            new_state = bool(self.state.effect_on[idx]) if 0 <= idx < len(self.state.effect_on) else False
            ok = self.applier.apply_effect_on_off(name, new_state)
            self._propagate_applier_status()
            if ok:
                # Push current values once after toggle so the just-enabled
                # section starts from the AppState knobs the user can see.
                self._maybe_live_apply(force=True)

    def _enc0_long_press(self) -> None:
        # Safe-bypass intent: store the previous on/off pattern (round-trip
        # toggle) so a second long_press un-bypasses. Stash the saved pattern
        # on AppState so persistence survives renderer cycles.
        prev = getattr(self.state, "_pre_bypass_effect_on", None)
        if prev is None:
            self.state._pre_bypass_effect_on = list(self.state.effect_on)  # type: ignore[attr-defined]
            self.state.effect_on = [False] * len(self.state.effect_on)
        else:
            self.state.effect_on = list(prev)
            self.state._pre_bypass_effect_on = None  # type: ignore[attr-defined]
        self.state.value_dirty = True
        self.state.apply_pending = True
        # Live apply: call safe_bypass when bypassing, full state push when
        # un-bypassing so the previous ON/OFF pattern lands on the overlay.
        if self.applier is not None and self.live_apply:
            if all(not v for v in self.state.effect_on):
                self.applier.apply_safe_bypass()
                self._propagate_applier_status()
                self.state.value_dirty = False
                self.state.apply_pending = False
            else:
                self._maybe_live_apply(force=True)

    # -- encoder 2: focus / select knob or model --------------------------------

    def _enc1_rotate(self, delta: int) -> None:
        name = self._effect_name()
        if self.state.model_select_mode and name in MODEL_EFFECTS:
            self._cycle_model_index(name, delta)
            return
        kc = self._knob_count()
        if kc <= 0:
            return
        new_idx = (int(self.state.selected_knob) + int(delta)) % kc
        self.state.selected_knob = new_idx
        self.state.focus_param_index = new_idx

    def _enc1_short_press(self) -> None:
        # Toggle model_select_mode if the current effect actually has a model
        # dropdown; otherwise no-op (parameter-group toggle is not used by the
        # 800x480 compact UI today).
        name = self._effect_name()
        if name in MODEL_EFFECTS:
            self.state.model_select_mode = not self.state.model_select_mode
        else:
            # Non-model effects: encoder 2 short press toggles edit_mode so
            # the user gets visual feedback that the short press registered.
            self.state.edit_mode = not bool(getattr(self.state, "edit_mode", False))

    def _enc1_long_press(self) -> None:
        # Reserved for preset / model mode toggle. For now: leave model_select_mode.
        self.state.model_select_mode = False

    def _cycle_model_index(self, effect_name: str, delta: int) -> None:
        # Per Phase 6H spec, the three model-driven effects keep their indices
        # on AppState. Distortion uses pedal-mask bits 0..6; bit 2 == RAT
        # which is intentionally skipped from encoder-driven cycling when
        # ``skip_rat`` is True (Clash stage stays intact, notebook can still
        # drive RAT via the mirror).
        spec = {
            "Distortion": ("dist_model_idx", 7),
            "Overdrive":  ("dist_model_idx", 7),
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
        # Skip RAT when cycling distortion-pedal models.
        if attr == "dist_model_idx" and self.skip_rat:
            guard = 0
            direction = 1 if step > 0 else -1
            while new_idx == RAT_PEDAL_INDEX and guard < n:
                new_idx = (new_idx + direction) % n
                guard += 1
            if new_idx == RAT_PEDAL_INDEX:
                # Every slot was RAT (n==1); leave the index unchanged.
                new_idx = cur
        setattr(self.state, attr, new_idx)
        self.state.value_dirty = True
        self.state.apply_pending = True
        # Live apply the new model immediately when an applier is wired.
        self._maybe_live_apply(force=True)

    # -- encoder 3: change value / apply ---------------------------------------

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
        self.state.edit_mode = True
        self.state.value_dirty = True
        self.state.apply_pending = True
        # Throttled live apply so a fast rotation does not flood AXI.
        self._maybe_live_apply(force=False)

    def _enc2_short_press(self) -> None:
        # Apply pending DSP changes via the applier (preferred) or the
        # legacy mirror/bridge fall-through. An explicit short press always
        # force-applies, even when live_apply=False (live_apply only gates
        # the per-rotate auto apply).
        if self.applier is not None:
            self.applier.apply_appstate(self.state, force=True)
            self._propagate_applier_status()
            self.state.value_dirty = False
            self.state.apply_pending = False
            self.state.edit_mode = False
            return
        if self.state.apply_pending:
            self.apply()

    def _enc2_long_press(self) -> None:
        # Reset the focused knob to its default in EFFECT_KNOBS.
        name = self._effect_name()
        if not name or name not in EFFECT_KNOBS:
            return
        idx = max(0, min(int(self.state.selected_knob), len(EFFECT_KNOBS[name]) - 1))
        defaults = [float(k[1]) for k in EFFECT_KNOBS[name]]
        if idx < len(defaults):
            vals = self.state.all_knob_values.setdefault(name, list(defaults))
            vals[idx] = defaults[idx]
            self.state.value_dirty = True
            self.state.apply_pending = True
            # Apply the reset immediately so the user hears the default.
            self._maybe_live_apply(force=True)

    # -- apply -----------------------------------------------------------------

    def apply(self) -> None:
        """Push the current AppState into the overlay.

        Order of preference:
        1. ``applier`` (Phase 7G live-apply path) -- preferred.
        2. ``mirror.update_from_appstate(state)`` or ``mirror.update(state)``.
        3. ``AudioLabGuiBridge.apply(state, overlay=...)`` as a last resort.
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
        self.state.edit_mode = False
