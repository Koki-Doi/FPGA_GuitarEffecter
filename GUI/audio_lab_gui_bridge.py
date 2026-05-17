"""Bridge GUI AppState changes to the AudioLabOverlay control API.

This module intentionally stays independent from HDMI output and overlay
loading. The AppState -> overlay-call planning now lives in
``audio_lab_pynq.app_state_apply_plan`` so the notebook bridge and encoder
runtime share one translation path.
"""

from __future__ import print_function

import time

from audio_lab_pynq.app_state_apply_plan import (
    BridgeOperation,
    BridgePlan,
    FIXED_DSP_CHAIN,
    SUPPORTED_EFFECTS,
    UNSUPPORTED_LIVE_EFFECTS,
    app_state_to_audio_lab_sections,
    chain_is_hardware_order,
    chain_preset_name_from_state,
    chain_preset_plan,
    full_state_plan,
    safe_bypass_plan,
)
from audio_lab_pynq.effect_catalog import (
    CHAIN_PRESETS,
    DIST_MODELS,
    EFFECTS,
    EFFECT_KNOBS,
    GUI_AMP_MODELS as AMP_MODELS,
    GUI_CAB_MODELS as CAB_MODELS,
)


KNOB_DRAG_EVENTS = ("knob_drag", "drag", "continuous")
DEFAULT_KNOB_THROTTLE_SECONDS = 0.10


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
        return BridgePlan(
            changed,
            warnings=plan.warnings,
            sections=plan.sections,
            unsupported=plan.unsupported,
        )

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
    "AMP_MODELS",
    "AudioLabGuiBridge",
    "BridgeOperation",
    "BridgePlan",
    "CAB_MODELS",
    "CHAIN_PRESETS",
    "DEFAULT_KNOB_THROTTLE_SECONDS",
    "DIST_MODELS",
    "EFFECTS",
    "EFFECT_KNOBS",
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
