"""GUI-first encoder -> AudioLabOverlay live-apply layer.

Translates the compact-v2 GUI ``AppState`` into ``AudioLabOverlay``
public-API calls. Only the effects that the 800x480 GUI actually exposes
are written, and every call goes through documented setters
(``set_noise_suppressor_settings``, ``set_compressor_settings``,
``set_distortion_settings``, ``set_guitar_effects``) -- no raw GPIO
writes.

RAT (pedal-mask bit 2 of the Distortion pedalboard) is intentionally
excluded from encoder-driven control. The DSP stage is not removed and
the overlay API is not patched; the apply layer simply refuses to set
``rat_on=True`` or include bit 2 in ``distortion_pedal_mask`` while
``skip_rat=True`` (the default).

This module is import-safe on workstations without ``pynq`` installed.
"""

import time

EFFECT_NOISE_SUP  = "Noise Sup"
EFFECT_COMPRESSOR = "Compressor"
EFFECT_OVERDRIVE  = "Overdrive"
EFFECT_DISTORTION = "Distortion"
EFFECT_AMP        = "Amp Sim"
EFFECT_CAB        = "Cab IR"
EFFECT_EQ         = "EQ"
EFFECT_REVERB     = "Reverb"

# Default throttle: at most one set_guitar_effects burst per 100 ms while
# encoder 3 is being turned continuously.
DEFAULT_APPLY_INTERVAL_S = 0.10

# Pedal-mask bit index that corresponds to the RAT model. Mirrors
# audio_lab_pynq/effect_defaults.py::DISTORTION_PEDALS.
RAT_PEDAL_INDEX = 2

# AppState all_knob_values ordering (mirrors GUI/compact_v2/knobs.py).
#   "Noise Sup":  [THRESH, DECAY, DAMP]
#   "Compressor": [THRESH, RATIO, RESP, MAKEUP]
#   "Overdrive":  [TONE, LEVEL, DRIVE]
#   "Distortion": [TONE, LEVEL, DRIVE, BIAS, TIGHT, MIX]
#   "Amp Sim":    [GAIN, BASS, MID, TREB, PRES, RES, MSTR, CHAR]
#   "Cab IR":     [MIX, LEVEL, MODEL, AIR]
#   "EQ":         [LOW, MID, HIGH]   (GUI 0..100 -> overlay 0..200)
#   "Reverb":     [DECAY, TONE, MIX]


def _clamp_percent(value):
    try:
        v = float(value)
    except Exception:
        return 0.0
    if v < 0.0:
        return 0.0
    if v > 100.0:
        return 100.0
    return v


def _clamp_eq_overlay(value):
    """GUI knob value (0..100, 50 == unity) -> overlay range (0..200)."""
    v = _clamp_percent(value) * 2.0
    if v < 0.0:
        return 0.0
    if v > 200.0:
        return 200.0
    return v


def _knob_list(state, name, fallback):
    vals = getattr(state, "all_knob_values", {}) or {}
    cur = vals.get(name)
    if cur is None or len(cur) < len(fallback):
        return list(fallback)
    return list(cur)


def _effect_on(state, index, default=True):
    on = list(getattr(state, "effect_on", []) or [])
    if 0 <= index < len(on):
        return bool(on[index])
    return bool(default)


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
            ns  = _knob_list(state, EFFECT_NOISE_SUP,  [35, 45, 80])
            cmp_ = _knob_list(state, EFFECT_COMPRESSOR, [50, 45, 40, 55])
            od  = _knob_list(state, EFFECT_OVERDRIVE,  [60, 60, 35])
            dst = _knob_list(state, EFFECT_DISTORTION, [55, 35, 50, 50, 60, 100])
            amp = _knob_list(state, EFFECT_AMP,
                             [45, 55, 60, 50, 50, 50, 70, 60])
            cab = _knob_list(state, EFFECT_CAB,        [100, 70, 33, 35])
            eq  = _knob_list(state, EFFECT_EQ,         [50, 55, 55])
            rv  = _knob_list(state, EFFECT_REVERB,     [30, 65, 25])

            # Distortion pedal-mask: from AppState.dist_model_idx, skipping
            # RAT (bit 2) when skip_rat is True.
            dist_idx = int(getattr(state, "dist_model_idx", 1) or 0)
            dist_idx = max(0, min(6, dist_idx))
            if dist_idx == RAT_PEDAL_INDEX and self.skip_rat:
                self._mark_unsupported("Distortion:rat")
                pedal_mask = 0
            else:
                pedal_mask = (1 << dist_idx) & 0x7F

            cab_idx = int(getattr(state, "cab_model_idx", 1) or 1)
            cab_idx = max(0, min(2, cab_idx))

            # The dedicated noise-suppressor + compressor GPIOs each take
            # their own setter so the cached state stays consistent.
            self.overlay.set_noise_suppressor_settings(
                threshold=_clamp_percent(ns[0]),
                decay=_clamp_percent(ns[1]),
                damp=_clamp_percent(ns[2]),
                enabled=_effect_on(state, 0, True))
            self.overlay.set_compressor_settings(
                threshold=_clamp_percent(cmp_[0]),
                ratio=_clamp_percent(cmp_[1]),
                response=_clamp_percent(cmp_[2]),
                makeup=_clamp_percent(cmp_[3]),
                enabled=_effect_on(state, 1, True))

            kwargs = dict(
                noise_gate_on=_effect_on(state, 0, True),
                overdrive_on=_effect_on(state, 2, False),
                distortion_on=_effect_on(state, 3, False),
                rat_on=False,
                amp_on=_effect_on(state, 4, True),
                cab_on=_effect_on(state, 5, True),
                eq_on=_effect_on(state, 6, True),
                reverb_on=_effect_on(state, 7, True),

                overdrive_drive=_clamp_percent(od[2]),
                overdrive_tone=_clamp_percent(od[0]),
                overdrive_level=_clamp_percent(od[1]),

                distortion=_clamp_percent(dst[2]),
                distortion_tone=_clamp_percent(dst[0]),
                distortion_level=_clamp_percent(dst[1]),
                distortion_bias=_clamp_percent(dst[3]),
                distortion_tight=_clamp_percent(dst[4]),
                distortion_mix=_clamp_percent(dst[5]),
                distortion_pedal_mask=int(pedal_mask) & 0x7F,

                amp_input_gain=_clamp_percent(amp[0]),
                amp_bass=_clamp_percent(amp[1]),
                amp_middle=_clamp_percent(amp[2]),
                amp_treble=_clamp_percent(amp[3]),
                amp_presence=_clamp_percent(amp[4]),
                amp_resonance=_clamp_percent(amp[5]),
                amp_master=_clamp_percent(amp[6]),
                amp_character=_clamp_percent(amp[7]),

                cab_mix=_clamp_percent(cab[0]),
                cab_level=_clamp_percent(cab[1]),
                cab_model=int(cab_idx),
                cab_air=_clamp_percent(cab[3]),

                # EQ knobs are 0..100 in the GUI, 50 == unity.
                # AudioLabOverlay encodes eq_* via _level_to_q7 on a 0..200
                # range where 100 is unity gain.
                eq_low=_clamp_eq_overlay(eq[0]),
                eq_mid=_clamp_eq_overlay(eq[1]),
                eq_high=_clamp_eq_overlay(eq[2]),

                reverb_decay=_clamp_percent(rv[0]),
                reverb_tone=_clamp_percent(rv[1]),
                reverb_mix=_clamp_percent(rv[2]),
            )
            self.overlay.set_guitar_effects(**kwargs)
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
    try:
        return int(idx) == RAT_PEDAL_INDEX
    except Exception:
        return False
