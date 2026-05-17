"""GUI-first encoder -> AudioLabOverlay live-apply layer.

Translates the compact-v2 GUI ``AppState`` into ``AudioLabOverlay``
public-API calls. Only the effects that the 800x480 GUI actually exposes
are written, and every call goes through documented setters
(``set_noise_suppressor_settings``, ``set_compressor_settings``,
``set_guitar_effects``) -- no raw GPIO writes.

RAT (pedal-mask bit 2 of the Distortion pedalboard) is intentionally
excluded from encoder-driven control. The DSP stage is not removed and
the overlay API is not patched; the apply layer simply refuses to set
``rat_on=True`` or include bit 2 in ``distortion_pedal_mask`` while
``skip_rat=True`` (the default).

This module is import-safe on workstations without ``pynq`` installed.
"""

import time

from audio_lab_pynq.app_state_apply_plan import (
    RAT_PEDAL_INDEX,
    encoder_state_plan,
    is_rat_pedal_index as _is_rat_pedal_index,
)
from audio_lab_pynq.effect_catalog import (
    EFFECT_AMP,
    EFFECT_CAB,
    EFFECT_COMPRESSOR,
    EFFECT_DISTORTION,
    EFFECT_EQ,
    EFFECT_NOISE_SUP,
    EFFECT_OVERDRIVE,
    EFFECT_REVERB,
)

# Default throttle: at most one set_guitar_effects burst per 100 ms while
# encoder 3 is being turned continuously.
DEFAULT_APPLY_INTERVAL_S = 0.10

class EncoderEffectApplier(object):
    """Map AppState -> AudioLabOverlay public setters with throttling.

    The encoder runtime instantiates one of these per session and calls:

    * ``apply_effect_on_off(name, enabled)`` when the user toggles the
      currently selected effect (encoder 1 short press).
    * ``apply_safe_bypass()`` when the user requests Safe Bypass
      (encoder 1 long press).
    * ``apply_appstate(state)`` when the user changes a parameter
      (encoder 3 rotate / short / long). The throttle keeps continuous
      rotation from flooding the AXI bus.

    ``dry_run=True`` skips every overlay call but still updates
    ``last_apply_message`` so the GUI / resource print path stays the
    same off-board.
    """

    def __init__(self, overlay, *,
                 apply_interval_s=DEFAULT_APPLY_INTERVAL_S,
                 dry_run=False, skip_rat=True):
        self.overlay = overlay
        self.apply_interval_s = float(apply_interval_s)
        self.dry_run = bool(dry_run)
        self.skip_rat = bool(skip_rat)
        self._last_apply_t = 0.0
        self.last_apply_ok = True
        self.last_apply_message = "init"
        self.unsupported = []
        self.apply_count = 0
        self.error_count = 0

    # ------------------------------------------------------------------
    # internal helpers
    # ------------------------------------------------------------------
    def _throttled(self):
        now = time.time()
        if (now - self._last_apply_t) < self.apply_interval_s:
            return True
        self._last_apply_t = now
        return False

    def force_next(self):
        """Bypass the throttle on the next apply_appstate() call."""
        self._last_apply_t = 0.0

    def _record_ok(self, message):
        self.last_apply_ok = True
        self.last_apply_message = str(message)
        self.apply_count += 1

    def _record_err(self, message):
        self.last_apply_ok = False
        self.last_apply_message = str(message)
        self.error_count += 1

    def _mark_unsupported(self, label):
        label = str(label)
        if label and label not in self.unsupported:
            self.unsupported.append(label)

    # ------------------------------------------------------------------
    # effect on/off (encoder 1 short press)
    # ------------------------------------------------------------------
    def apply_effect_on_off(self, effect_name, enabled):
        enabled = bool(enabled)
        if self.dry_run or self.overlay is None:
            self._record_ok("dry on/off %s=%s" % (effect_name, enabled))
            return True
        try:
            if effect_name == EFFECT_NOISE_SUP:
                self.overlay.set_noise_suppressor_settings(enabled=enabled)
            elif effect_name == EFFECT_COMPRESSOR:
                self.overlay.set_compressor_settings(enabled=enabled)
            elif effect_name == EFFECT_OVERDRIVE:
                self.overlay.set_guitar_effects(overdrive_on=enabled)
            elif effect_name == EFFECT_DISTORTION:
                self.overlay.set_guitar_effects(distortion_on=enabled,
                                                rat_on=False)
            elif effect_name == EFFECT_AMP:
                self.overlay.set_guitar_effects(amp_on=enabled)
            elif effect_name == EFFECT_CAB:
                self.overlay.set_guitar_effects(cab_on=enabled)
            elif effect_name == EFFECT_EQ:
                self.overlay.set_guitar_effects(eq_on=enabled)
            elif effect_name == EFFECT_REVERB:
                self.overlay.set_guitar_effects(reverb_on=enabled)
            else:
                self._mark_unsupported(str(effect_name))
                self._record_err("unsupported on/off %s" % effect_name)
                return False
            self._record_ok("on/off %s=%s" % (effect_name, enabled))
            self._last_apply_t = time.time()
            return True
        except Exception as exc:
            self._record_err("on/off %s err %r" % (effect_name, exc))
            return False

    # ------------------------------------------------------------------
    # safe bypass (encoder 1 long press)
    # ------------------------------------------------------------------
    def apply_safe_bypass(self):
        if self.dry_run or self.overlay is None:
            self._record_ok("dry safe-bypass")
            return True
        try:
            ovl = self.overlay
            if hasattr(ovl, "clear_distortion_pedals"):
                ovl.clear_distortion_pedals()
            if hasattr(ovl, "set_noise_suppressor_settings"):
                ovl.set_noise_suppressor_settings(enabled=False)
            if hasattr(ovl, "set_compressor_settings"):
                ovl.set_compressor_settings(enabled=False)
            ovl.set_guitar_effects(
                noise_gate_on=False, overdrive_on=False, distortion_on=False,
                rat_on=False, amp_on=False, cab_on=False, eq_on=False,
                reverb_on=False)
            self._record_ok("safe-bypass")
            self._last_apply_t = time.time()
            return True
        except Exception as exc:
            self._record_err("safe-bypass err %r" % (exc,))
            return False

    # ------------------------------------------------------------------
    # full state push (encoder 2/3, or after on/off)
    # ------------------------------------------------------------------
    def apply_appstate(self, state, *, force=False):
        """Push every supported section based on the AppState snapshot.

        Returns True if the apply ran (success or attempted), False if it
        was suppressed by the throttle. Inspect ``last_apply_ok`` /
        ``last_apply_message`` for the result.
        """
        if not force and self._throttled():
            return False
        if self.dry_run or self.overlay is None:
            self._record_ok("dry state-push")
            return True
        try:
            plan = encoder_state_plan(state, skip_rat=self.skip_rat)
            for label in plan.unsupported:
                self._mark_unsupported(label)
            for op in plan.operations:
                target = getattr(self.overlay, op.method)
                target(**op.kwargs)
            self._record_ok("state-push")
            return True
        except Exception as exc:
            # Attempt was made but errored; return True so the caller knows
            # not to retry within the throttle window. last_apply_ok captures
            # the failure for the GUI / resource print.
            self._record_err("state-push err %r" % (exc,))
            return True

    # ------------------------------------------------------------------
    # status helpers
    # ------------------------------------------------------------------
    def status_snapshot(self):
        return {
            "apply_count": int(self.apply_count),
            "error_count": int(self.error_count),
            "last_apply_ok": bool(self.last_apply_ok),
            "last_apply_message": str(self.last_apply_message),
            "unsupported": list(self.unsupported),
            "apply_interval_s": float(self.apply_interval_s),
            "dry_run": bool(self.dry_run),
            "skip_rat": bool(self.skip_rat),
        }


def is_rat_pedal_index(idx):
    """Return True iff the given dist_model_idx is RAT (bit 2)."""
    return _is_rat_pedal_index(idx)
