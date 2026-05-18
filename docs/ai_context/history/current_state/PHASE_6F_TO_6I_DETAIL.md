# Phase 6F / 6G / 6H / 6I detail paragraphs (extracted from CURRENT_STATE.md)

Detailed dated paragraphs for Phase 6F (recurrence check), Phase 6G
(actual UI x-origin fix, partially rolled back), Phase 6H (1).py
spec port + rejected native 800x480 HDMI timing, and Phase 6I HDMI
timing sweep (C2 SVGA 800x600 deployed). Originally lived inline in
`CURRENT_STATE.md` under "Phase history (chronological)"; moved here
because the live state is now summarised in one short paragraph in
the parent file.

Per-phase plan / result memos for the same arc are in
`docs/ai_context/history/hdmi_phases/` (HDMI_GUI_PHASE6F_* through
HDMI_GUI_PHASE6I_*); this file is the CURRENT_STATE-flavoured prose.

---


2026-05-16 Phase 6F recurrence check: after the GitHub-code replacement
on `feature/hdmi-gui-model-selection-ui`, the recurring right-shifted
LCD report was rechecked without changing bit/hwh. Renderer bbox is
`(0,799,0,479)`, backend compose writes `dst_x0=0`, `dst_y0=0`,
`src_width=800`, `src_height=480`, and the live PYNQ framebuffer probe
shows non-black data only in `[0,799] x [0,479]` with
`outside_800x480_sum=0`. PYNQ origin guard, model-selection UI, and
realtime pedalboard CLI tests all pass. The standard remains compact-v2
`pipboy-green`, `placement="manual"`, `offset_x=0`, `offset_y=0`,
800x480 at the top-left of the 1280x720 framebuffer. No Vivado,
bitstream, HWH, Clash, GPIO, or block-design change was made.

2026-05-16 Phase 6G actual UI x-origin fix (intermediate, partially
rolled back): Phase 6F's `nonzero_bbox=[0,799,0,479]` check was too
weak because background / scanline / synthetic marker pixels can make
x=0 look populated even if the real panel body starts too far right.
Phase 6G initially tightened the compact-v2 renderer coordinates to
outer frame `x=4..796`, header `x=8..792`, chain and selected-FX
panels `x=12..788`, plus a normal phosphor left rail at `x=0..1`, and
shipped a strong-UI-bbox detector
(`scripts/test_hdmi_render_bbox.py`) plus an actual-UI visual test
(`scripts/test_hdmi_actual_ui_origin_visual.py`, renders compact UI
with `X0` / `X799` markers). The intermediate renderer coordinate
tightening was reverted by the same-day `d7ea0ab` (1).py spec port
(see Phase 6H block below). The strong-UI-bbox detector and the
actual-UI visual test were retained.

2026-05-16 Phase 6H (1).py spec port (`d7ea0ab`): replaces
`GUI/pynq_multi_fx_gui.py` with the user-supplied `(1).py` refactor.
Compact-v2 layout is restored to the Phase 4G / 4I baseline (outer
`(12, 12, 788, 468)`, header / chain / fx panels at `left=24`,
`right=24`), the per-effect knob spec is consolidated into a single
`EFFECT_KNOBS` dict keyed by the title-case `EFFECTS` names with
short labels (`THRESH`, `RATIO`, `RESP`, `MAKEUP`, `MID`, `TREB`,
`PRES`, `RES`, `MSTR`, `CHAR`, ...), and the legacy
`SELECTED_FX_PARAM_LAYOUT` plus the
`_should_show_selected_model_dropdown` / `_selected_model_dropdown_label`
/ `_dropdown_short` / `_pedal/amp/cab_label` /
`selected_fx_param_layout` helpers are removed. PEDAL / AMP / CAB
draw the dropdown chip inline; REVERB / COMPRESSOR / NOISE
SUPPRESSOR / SAFE BYPASS / PRESET hide it. The model label uses
`draw_smooth_text` with a fit-to-chip size search (`22 → 14`) so
long labels such as `HIGH GAIN STACK` / `1x12 OPEN BACK` /
`BRITISH CRUNCH` / `TUBE SCREAMER` stay inside the chip. `AppState`
now stores knob values in a single per-effect dict
`all_knob_values: Dict[str, List[float]]` (flat `knob_values`
removed), and exposes `state.knobs()` / `state.set_knob()` helpers
plus a `hit_test_compact_v2()` entry point. The Phase 6G strong UI
diagnostics continue to PASS at `strong_ui_bbox=[24,776,20,454]`,
with all `estimated_*_left_x` values at `24` (well inside the `<=28`
and `<=40` thresholds). No bit/hwh / Vivado / Clash / GPIO change.
See `docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE6H_PORT_1PY_SPEC.md`.

2026-05-16 Phase 6H native 800x480 HDMI timing (**rejected**):
`hw/Pynq-Z2/hdmi_integration.tcl` was switched to native `800x480`
with pixel clock `40.000 MHz`, H total `1056`, V total `628`. Vivado
built without errors and the bit/hwh staged with timing in the
historical band. **On the 5-inch LCD the screen rendered fully white**;
the receiver did not lock on the timing. The Phase 6H bit/hwh were
**not committed**. See
`docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE6H_NATIVE_800X480_TIMING.md` and
`docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE6I_800X480_TIMING_SWEEP.md`.

2026-05-16 Phase 6I HDMI timing sweep, C2 deployed:
After Phase 6H's white-screen failure the design rolled back to the
working `1280x720 / 74.250 MHz` baseline and swept candidate 800x480
timings. The originally planned `33.333 / 33.000 / 27.000 MHz` cuts
all fell below the `rgb2dvi v1.4` `kClkRange=3` PLL VCO floor
(`~40 MHz pixel clock`). Phase 6I therefore tried VESA SVGA `800x600 @
60 Hz / 40.000 MHz` (Candidate C2) as a standard scaler-friendly mode
that keeps the LCD's panel-native 800 pixel width. `hdmi_integration.tcl`
now sets `VIDEO_MODE Custom` in a first `set_property` pass before the
per-field `GEN_*` values (the previous flat call left the v_tc 6.1 IP
on its 1280x720 preset because the per-field params are disabled until
`VIDEO_MODE` switches to Custom), explicitly sets
`GEN_F0_VBLANK_HSTART = GEN_F0_VBLANK_HEND = HDMI_ACTIVE_W (800)`, and
drops the non-existent `GEN_CHROMA_PARITY` parameter. Vivado 2019.1
build: WNS `-8.096 ns`, TNS `-6389.430 ns`, WHS `+0.040 ns`, THS
`0.000 ns`; utilization LUTs `18618` (35.00%), Registers `20846`
(19.59%) — within the historical -7..-9 ns deploy band, hold clean.
`audio_lab_pynq/hdmi_backend.py` now defaults to a `800x600`
framebuffer (`DEFAULT_WIDTH=800`, `DEFAULT_HEIGHT=600`); the
compact-v2 UI composes at framebuffer `(0,0)` so visible rows
`0..479` carry the UI and rows `480..599` stay black. VDMA programmed
to `HSIZE=2400`, `STRIDE=2400`, `VSIZE=600`. `v_tc_hdmi` `GEN_ACTSZ`
reads `0x02580320` (`V=600 / H=800`) on real hardware. Smoke passed:
`AudioLabOverlay` loads, ADC HPF `True`, `R19=0x23`, no VDMA error
bits. **5-inch LCD: UI now appears left-aligned/centred with a clear
improvement over the previously right-shifted 720p path.** PYNQ
deploy syncs all three bit copies
(`hw/Pynq-Z2/bitstreams/`, repo `audio_lab_pynq/bitstreams/`,
`/usr/local/lib/python3.6/dist-packages/audio_lab_pynq/bitstreams/`);
the Phase 6H failed bit is archived under
`/tmp/fpga_guitar_effecter_backup/phase6h_failed_white_screen/`, and
the 720p rollback baseline under
`/home/xilinx/Audio-Lab-PYNQ/backups/phase6h_720p/` and
`/tmp/fpga_guitar_effecter_backup/phase6i_baseline_720p/`. See
`docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE6I_800X480_TIMING_SWEEP.md`.
