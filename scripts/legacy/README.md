# scripts/legacy/

One-off HDMI diagnostic scripts from the Phase 4D / 4F / 4H / 5A / 6F
/ 6H eras. They were useful at the time for narrowing down LCD output
issues and were never intended for long-term operation. The Phase 6I
SVGA 800x600 baseline (`DECISIONS.md` D25) makes most of them either
non-applicable (`720p` mapping tests, `1280x720` viewport sweeps) or
broken (depend on the `hsync_shift` / `fit_mode` hooks that were
removed when the matching diagnostics were retired).

They are kept here for archaeology — `git log` can recover them and
the original phase docs in `docs/ai_context/HDMI_GUI_PHASE*.md`
describe what they were doing — but they are not part of the deploy
flow and `scripts/deploy_to_pynq.sh` does not stage them.

| Script | Era | Notes |
| --- | --- | --- |
| `test_hdmi_output_mapping_720p.py` | Phase 5A | LCD mapping probe assuming a 720p signal; the Phase 6I path is SVGA 800x600. |
| `test_hdmi_fit_frame.py` | Phase 4D | LCD overscan experiments. The `fit-90/95/97/85/80` modes were removed from `audio_lab_pynq/hdmi_backend.py`, so this no longer imports. |
| `test_hdmi_800x480_cycle_offsets.py` | Phase 4H | Vertical-offset sweep. Phase 5C / 6I locked offset to `(0, 0)`. |
| `test_hdmi_800x480_vertical_offsets.py` | Phase 4H | Same as above. |
| `test_hdmi_800x480_layout_debug.py` | Phase 4H | Layout overlay diagnostics. |
| `test_hdmi_viewport_calibration.py` | Phase 4F | First-pass viewport calibration. |
| `test_hdmi_800x480_viewport_calibration.py` | Phase 4F-superseded | Second-pass; superseded by Phase 5C `(0, 0)` default. |
| `test_hdmi_vtc_dump.py` | Phase 6F | Right-shift diagnostics. |
| `test_hdmi_vtc_hsync_shift.py` | Phase 6F | Used the `hsync_shift` constructor kwarg, removed from `AudioLabHdmiBackend` in the Phase 6I post-fix cleanup. |
| `test_hdmi_vtc_hsync_sweep.py` | Phase 6F | Same hook; broken since removal. |
| `test_hdmi_actual_ui_origin_visual.py` | Phase 6H | Visual origin test targeted at the rejected Phase 6H native 800x480 framebuffer; asserts `output_height=480` and breaks on the Phase 6I `800x600` backend. Was never tracked. |

The current `scripts/` directory contains the live diagnostics:

- `test_hdmi_800x480_frame.py` — standard 5-inch LCD smoke
- `test_hdmi_800x480_origin_guard.py` — bbox / placement origin guard
- `test_hdmi_render_bbox.py` — strong-UI-bbox detector
- `test_hdmi_model_selection_ui.py` — DIST / AMP / CAB dropdown test
- `test_hdmi_realtime_pedalboard_controls.py` — realtime pedalboard mirror
- `test_hdmi_selected_fx_switch.py` — selected-FX state mirror

For the most-common runtime check, use
`audio_lab_pynq/notebooks/HdmiGuiShow.ipynb` (one-cell, smart-attach;
see `DECISIONS.md` D25).
