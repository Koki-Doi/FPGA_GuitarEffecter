"""High-level mapping from encoder events to AppState / overlay mutations.

Encoder 1: focus / select effect.
Encoder 2: focus / select knob (or model when in model_select_mode).
Encoder 3: change the value of the focused knob; short_press applies pending
           changes to the overlay via the HDMI state mirror.

The controller never writes a raw GPIO. It updates ``AppState``, then -- when
``apply()`` is called -- it pushes the current per-effect values through the
``HdmiEffectStateMirror`` and ``AudioLabOverlay`` public API.
"""

from __future__ import annotations

from typing import Iterable, Optional

try:  # noqa: SIM105 — import guard is needed to keep this file workstation-safe
    from GUI.compact_v2.knobs import EFFECTS, EFFECT_KNOBS  # type: ignore
except Exception:  # pragma: no cover — fallback when run from inside /GUI
    try:
        from compact_v2.knobs import EFFECTS, EFFECT_KNOBS  # type: ignore
    except Exception:
        EFFECTS = []  # type: ignore
        EFFECT_KNOBS = {}  # type: ignore


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
        value_step: float = DEFAULT_VALUE_STEP,
        apply_on_value_change: bool = False,
    ):
        self.state = state
        self.mirror = mirror
        self.overlay = overlay
        self.bridge = bridge
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

    # -- event dispatch --------------------------------------------------------

    def handle_event(self, event) -> None:
        self._ensure_focus_fields()
        self.state.last_encoder_event = {
            "kind": event.kind, "encoder_id": event.encoder_id,
            "delta": getattr(event, "delta", 0),
        }
        self.state.last_control_source = "encoder"

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

    def _enc1_long_press(self) -> None:
        # Reserved for preset / model mode toggle. For now: leave model_select_mode.
        self.state.model_select_mode = False

    def _cycle_model_index(self, effect_name: str, delta: int) -> None:
        # Per Phase 6H spec, the three model-driven effects keep their indices on
        # AppState. We use small static lengths here to avoid importing the model
        # tables (which live in audio_lab_pynq.hdmi_state on the board).
        # The PYNQ driver layer clamps further if needed.
        spec = {
            "Distortion": ("dist_model_idx", 7),  # 7 pedal-mask voicings (incl. RAT)
            "Overdrive":  ("dist_model_idx", 7),  # PEDAL group shares the model picker
            "Amp Sim":    ("amp_model_idx",  6),  # named amp models
            "Cab IR":     ("cab_model_idx",  3),  # 0/85/170 preset IRs
        }.get(effect_name)
        if spec is None:
            return
        attr, n = spec
        cur = int(getattr(self.state, attr, 0))
        setattr(self.state, attr, (cur + int(delta)) % n)
        self.state.value_dirty = True
        self.state.apply_pending = True

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

    def _enc2_short_press(self) -> None:
        # Apply pending DSP changes via the mirror / overlay.
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

    # -- apply -----------------------------------------------------------------

    def apply(self) -> None:
        """Push the current AppState into the overlay via the HDMI mirror.

        When a test/dry-run mirror exposes ``update_from_appstate(state)`` or
        ``update(state)``, use that. The live HDMI mirror object is primarily
        notebook-call driven, so the encoder runtime falls back to the existing
        ``AudioLabGuiBridge`` when an overlay is available.
        """
        applied = False
        if self.mirror is not None:
            try:
                self.mirror.update_from_appstate(self.state)
                applied = True
            except AttributeError:
                # Older mirror revisions may expose update(state) instead.
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
