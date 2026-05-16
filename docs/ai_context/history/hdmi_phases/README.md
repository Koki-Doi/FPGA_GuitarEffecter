# HDMI GUI phase history (Phase 1 – Phase 6I)

Per-phase docs from the HDMI GUI integration arc, kept here as a
historical record. The current load-bearing reference is
[`HDMI_GUI_INTEGRATION_PLAN.md`](../../HDMI_GUI_INTEGRATION_PLAN.md)
(see Section 11 for the Phase 6I C2 SVGA 800x600 result) plus
[`DECISIONS.md`](../../DECISIONS.md) D24 / D25. Read the per-phase
files below only when you need the contemporaneous detail (what was
tried, what numbers were measured, what bit was deployed).

| Phase | File | Topic |
| --- | --- | --- |
| 1 | `HDMI_GUI_PHASE1_RENDER_BENCH.md` | PYNQ-side offscreen render benchmark for the AppState-driven renderer. |
| 2A | `HDMI_GUI_PHASE2A_PYNQ_COMPAT.md` | PYNQ compatibility shims for the Phase 1 renderer. |
| 2B | `HDMI_GUI_PHASE2B_RENDER_OPTIMIZATION.md` | Static-cache / partial redraw optimisation pass. |
| 2C | `HDMI_GUI_PHASE2C_BRIDGE_PLAN.md` | AppState <-> AudioLabOverlay bridge plan. |
| 2D | `HDMI_GUI_PHASE2D_BRIDGE_RUNTIME_TEST.md` | Bridge runtime test on real hardware. |
| 3 | `HDMI_GUI_PHASE3_VIVADO_DESIGN_PROPOSAL.md` | Vivado design proposal for the integrated HDMI path. |
| 4 prompt | `HDMI_GUI_PHASE4_IMPLEMENTATION_PROMPT_DRAFT.md` | Phase 4 implementation prompt draft. |
| 4 result | `HDMI_GUI_PHASE4_IMPLEMENTATION_RESULT.md` | Phase 4 integrated framebuffer landed. |
| 4C | `HDMI_GUI_PHASE4C_RESOURCE_PROFILE.md` | Resource profile of the deployed Phase 4 bit. |
| 4D | `HDMI_GUI_PHASE4D_LCD_FIT_TEST.md` | LCD fit-mode experiments (retired with the `fit-90/95/...` removal). |
| 4E | `HDMI_GUI_PHASE4E_800X480_LOGICAL_GUI.md` | First 800x480 logical GUI placed inside the 720p framebuffer. |
| 4F | `HDMI_GUI_PHASE4F_VIEWPORT_CALIBRATION.md` | Manual viewport calibration. |
| 4G | `HDMI_GUI_PHASE4G_800X480_LAYOUT_CORRECTION.md` | compact-v2 layout + negative-offset placement. |
| 4H | `HDMI_GUI_PHASE4H_VERTICAL_MARGIN_AND_LAYOUT_DIAGNOSIS.md` | Vertical safe margin + layout diagnostics. |
| 4I | `HDMI_GUI_PHASE4I_RESTORE_COMPACT_V2_BASELINE.md` | Rolled back the 4H push-down to the 4G baseline. |
| 5A | `HDMI_GUI_PHASE5A_OUTPUT_SIDE_DIAGNOSIS.md` | LCD output-side diagnosis. |
| 5B | `HDMI_GUI_PHASE5B_NATIVE_800X480_TIMING_PLAN.md` | Original native 800x480 timing plan (later superseded by Phase 6H attempt and the Phase 6I SVGA pivot). |
| 5D | `HDMI_GUI_PHASE5D_PIPBOY_GREEN_THEME.md` | Pip-Boy phosphor-green palette + scanline overlay. |
| 6A | `HDMI_GUI_PHASE6A_SELECTED_FX_STATE_MIRROR.md` | Selected-FX state mirror between notebook and HDMI GUI. |
| 6B | `HDMI_GUI_PHASE6B_MODEL_SELECTION_UI.md` | DIST / AMP / CAB model dropdown UI. |
| 6C | `HDMI_GUI_PHASE6C_REALTIME_NOTEBOOK_PEDALBOARD.md` | Realtime notebook pedalboard mirrored to the HDMI GUI. |
| 6D | `HDMI_GUI_PHASE6D_RESTORE_UI_AND_CONDITIONAL_DROPDOWN.md` | Restored compact UI + conditional dropdown. |
| 6E knob | `HDMI_GUI_PHASE6E_PER_EFFECT_KNOB_GRID.md` | Per-effect knob grid expansion. |
| 6E restore | `HDMI_GUI_PHASE6E_RESTORE_PIPBOY_COMPACT_UI.md` | Restore Pip-Boy compact UI plus the VTC `hsync_shift` diagnostic hook (later removed in the Phase 6I post-fix cleanup). |
| 6F | `HDMI_GUI_PHASE6F_FIX_HDMI_X_ORIGIN.md` | First right-shift fix attempt. |
| 6G | `HDMI_GUI_PHASE6G_ACTUAL_UI_X_ORIGIN.md` | Strong-UI-bbox detector + actual-UI visual test. |
| 6H port | `HDMI_GUI_PHASE6H_PORT_1PY_SPEC.md` | (1).py spec port — single `EFFECT_KNOBS`, inline model dropdown (`DECISIONS.md` D24). |
| 6H native | `HDMI_GUI_PHASE6H_NATIVE_800X480_TIMING.md` | **Rejected** native 800x480 / 40 MHz timing (LCD white screen). |
| 6I | `HDMI_GUI_PHASE6I_800X480_TIMING_SWEEP.md` | Phase 6I C2 SVGA 800x600 / 40 MHz **deployed** baseline (`DECISIONS.md` D25). |
