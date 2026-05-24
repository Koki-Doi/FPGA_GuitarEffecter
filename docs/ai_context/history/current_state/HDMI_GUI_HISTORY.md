# HDMI GUI history (extracted from CURRENT_STATE.md)

This file consolidates the per-phase HDMI GUI snapshots that used to
live in `docs/ai_context/CURRENT_STATE.md` for Phase 4 through Phase
5D (the snapshot blocks for Phase 6F / 6G / 6H / 6I detail live in
the sibling `PHASE_6F_TO_6I_DETAIL.md`). Per-phase plan / result
memos are still under `docs/ai_context/history/hdmi_phases/`; this
file is the CURRENT_STATE-flavoured prose of the same arc.

Read the live `CURRENT_STATE.md` first; come here only when an old
phase block is the load-bearing reference.
Terms such as "current" below refer to the historical phase being
quoted. The actual live HDMI baseline is Phase 6I C2 SVGA `800x600 @
60 Hz / 40 MHz` with the compact 800x480 GUI at framebuffer `(0,0)`;
see `HDMI_GUI_INTEGRATION_PLAN.md` and `DECISIONS.md` D25.

---

## HDMI GUI integration planning

HDMI GUI integration is now a first integrated implementation, not only
a design proposal. Phase 4 added a fixed 1280x720 framebuffer scanout
path to the AudioLab overlay through `axi_vdma_hdmi`, `v_tc_hdmi`,
`v_axi4s_vid_out_hdmi`, and Digilent `rgb2dvi_hdmi`, without changing
Clash / DSP source, `topEntity`, existing audio GPIO names/addresses, or
the legacy `axi_gpio_delay` RAT contract. The implementation is built by
sourcing `hw/Pynq-Z2/hdmi_integration.tcl` from `create_project.tcl`.

The runtime path still loads exactly one overlay: `AudioLabOverlay()`.
Do not call `Overlay("base.bit")`, do not call
`GUI/pynq_multi_fx_gui.py::run_pynq_hdmi()`, and do not load a second
overlay after the AudioLab overlay.

What was found:

- At that phase, the deployed `audio_lab.bit` contained the Phase 4 HDMI
  framebuffer output path.
- `GUI/pynq_multi_fx_gui.py` is a good rendering candidate because
  `render_frame(state)` returns a 1280x720 RGB `numpy.ndarray`, but its
  existing `run_pynq_hdmi()` helper loads `Overlay("base.bit")`.
- Loading `base.bit` would still replace the AudioLab DSP overlay in the
  PL, so that helper must not be used for the live AudioLab HDMI GUI.
- The former untracked `HDMI/GUI.py` was a Windows Tkinter / PIL preview
  application and was not a direct PYNQ HDMI backend.
- The former untracked `HDMI/FPGA/Vivado_project` was a passthrough
  experiment, not a complete HDMI output design for the current AudioLab
  overlay.
- Repo-wide reference checks found no current deploy, test, or runtime
  script dependency on `HDMI/`; the directory was backed up and removed.

Current design direction:

- Keep `GUI/pynq_multi_fx_gui.py`'s renderer as much as possible.
- Do not use `base.bit` for the live GUI path.
- Do not load another full overlay after `AudioLabOverlay()`.
- The live HDMI GUI uses one integrated `audio_lab.bit` containing both
  the existing AudioLab DSP and a HDMI framebuffer output path.
- GUI state should be bridged to `AudioLabOverlay` APIs at change time or
  at a throttled control rate, not by writing GPIOs every video frame.
- `GUI/audio_lab_gui_bridge.py` now implements that bridge as a separated
  dry-run-first layer; it does not instantiate `AudioLabOverlay` or load
  a bitstream.
- Chain reorder in the GUI must be disabled or display-only because the
  current DSP pipeline order is fixed.

See `docs/ai_context/HDMI_GUI_INTEGRATION_PLAN.md` for the full plan,
risks, prohibited actions, and phase prompts. See
`docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE2A_PYNQ_COMPAT.md` and
`docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE2B_RENDER_OPTIMIZATION.md` for the current
PYNQ rendering results. See
`docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE2C_BRIDGE_PLAN.md` for the bridge design
and dry-run verification. See
`docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE2D_BRIDGE_RUNTIME_TEST.md` for the live
bridge runtime test against the real overlay. See
`docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE3_VIVADO_DESIGN_PROPOSAL.md` for the
recommended HDMI Vivado architecture, IP list, clocking, AXI / DDR
plan, address-map impact, resource / timing risks, and rollback. See
`docs/ai_context/HDMI_BLOCK_DESIGN_TCL_PATCH_PLAN.md` for the proposed
shape of the implemented HDMI Tcl split and
`docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE4_IMPLEMENTATION_RESULT.md` for the
build, deploy, timing, and smoke result. See
`docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE4C_RESOURCE_PROFILE.md` for the
static-frame recheck, PS runtime profile, and PL before/after summary.
See `docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE4D_LCD_FIT_TEST.md` for the small
LCD overscan / safe-area fit test. See
`docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE4E_800X480_LOGICAL_GUI.md` for the
5-inch 800x480 logical GUI mode and centered framebuffer placement.

## HDMI GUI Phase 4 integrated overlay

Phase 4 recovered from a dirty intermediate Vivado state and completed
both Phase 4A and Phase 4B:

- Digilent `vivado-library`: `/home/doi20/digilent-vivado-library`.
- Vivado IP catalog confirmed `digilentinc.com:ip:rgb2dvi:1.4`.
- HDMI OUT pins use the PYNQ-Z2 board-file locations
  `L16/L17/K17/K18/K19/J19/J18/H18`.
- `audio_lab.xdc` constrains only `PACKAGE_PIN` for HDMI TX; `rgb2dvi`
  owns the `OBUFDS` / `TMDS_33` output primitive settings internally.
- Pixel path: GUI RGB888 `[720,1280,3]` / `uint8` -> packed DDR
  `GBR888` -> 24-bit VDMA MM2S -> `v_axi4s_vid_out` ->
  `rgb2dvi`.
- VDMA HSIZE/STRIDE: `3840` bytes; VSIZE: `720`.
- New AXI-Lite addresses: `axi_vdma_hdmi` at `0x43CE0000`,
  `v_tc_hdmi` at `0x43CF0000`.
- Final routed timing: WNS `-8.163 ns`, TNS `-6599.061 ns`,
  WHS `+0.051 ns`, THS `0.000 ns`.
- Utilization after place: LUT `18619`, Registers `20846`, BRAM `9`,
  DSP `83`.
- Deployed to PYNQ-Z2 with `bash scripts/deploy_to_pynq.sh`.
- Smoke passed: ADC HPF `True`, `R19=0x23`,
  `axi_gpio_delay_line=False`, legacy `axi_gpio_delay=True`,
  noise suppressor/compressor GPIOs present, required chain presets
  apply successfully.
- Current `CHAIN_PRESETS` count is `13`; the required `Safe Bypass`,
  `Basic Clean`, and `Metal Tight` smoke cases pass and the board is
  returned to `Safe Bypass` after the test.
- HDMI static frame test passed to the level observable over SSH:
  GUI renderer produced RGB888, VDMA started from framebuffer
  `0x16900000`, `DMASR=0x00011000`, no internal/slave/decode error
  bits. Physical display output still needs a connected monitor for
  visual confirmation.

Runtime caveat: PYNQ exposes `axi_vdma_hdmi` in `overlay.ip_dict`, but
attribute access tries to instantiate PYNQ's base-video `AxiVDMA`
driver and fails on this MM2S-only instance. Use
`audio_lab_pynq.hdmi_backend.AudioLabHdmiBackend`, which creates direct
`pynq.MMIO` handles from `ip_dict`.

## HDMI GUI Phase 4C resource profile

Phase 4C did not rebuild Vivado, regenerate `audio_lab.bit` /
`audio_lab.hwh`, redeploy the full tree, or change `block_design.tcl`,
`audio_lab.xdc`, `create_project.tcl`, Clash/DSP, `topEntity`, or GPIO
semantics. It added `scripts/profile_hdmi_static_frame.py` and measured
the already-deployed Phase 4 HDMI framebuffer path on PYNQ-Z2.

Static-frame recheck over SSH passed again:

- `AudioLabOverlay()` load OK; no `base.bit`, no `run_pynq_hdmi()`, no
  second overlay.
- ADC HPF `True`, `R19=0x23`, `axi_gpio_delay_line=False`, legacy
  `axi_gpio_delay=True`.
- HDMI IP present in `ip_dict` / HWH.
- Renderer output `[720,1280,3]` / `uint8`; render time `2.924 s`.
- Framebuffer `0x16900000`, format packed DDR `GBR888`, size
  `2764800` bytes.
- VDMA HSIZE/STRIDE `3840`, VSIZE `720`, `VDMACR=0x00010001`,
  `DMASR=0x00011000`, no internal/slave/decode error bits.
- VTC control/status register readback: `0x00000006`.
- Phase 5A/5C later confirmed physical output on the 5-inch LCD and
  selected the framebuffer's top-left 800x480 region as the practical
  visible viewport for that panel.

Resource profile command on the board:

```sh
sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
  python3 scripts/profile_hdmi_static_frame.py \
  --hold-seconds 60 --iterations 10 \
  --out-dir /tmp/hdmi_phase4c_resource_profile
```

Measured PS-side cost:

- Cold GUI render `2.979 s`.
- Same-state cached render avg/p95 `0.00052 s` / `0.00217 s`.
- Change-driven render avg/p95 `0.276 s` / `0.280 s`.
- RGB888 -> packed DDR `GBR888` framebuffer copy avg/p95
  `0.206 s` / `0.206 s`.
- VDMA/VTC init + start `0.0023 s`.
- 60-second static hold: process CPU avg/max `0.352%` / `0.418%`,
  system CPU avg/max `0.190%` / `0.990%`.
- Process max RSS `136876 kB`; `MemAvailable` before/after
  `390860 kB` / `270764 kB`.
- Temperature was unavailable because this PYNQ image exposed no
  thermal/hwmon temp files.

Interpretation: static scanout itself is cheap after VDMA starts. The
expensive parts remain Python/PIL/NumPy rendering and full-frame copy.
Warm change-driven updates are about `0.276 + 0.206 = 0.482 s`, or
roughly `2.1 fps`; continuous 30fps GUI output is not realistic without
a substantially different renderer/copy strategy.

## HDMI GUI Phase 4D LCD fit modes

User visual inspection confirmed that the integrated HDMI output appears
on the small HDMI LCD, but the native 1280x720 GUI is cropped by the
display. Phase 4D fixes this on the Python side only: the backend can
resize the rendered RGB888 frame, center it on a black 1280x720 canvas,
and then use the existing RGB888 -> DDR `GBR888` copy path. VDMA timing
and framebuffer dimensions stay unchanged.

Phase 4D did not rebuild Vivado, regenerate bit/hwh, or change
`block_design.tcl`, `audio_lab.xdc`, `create_project.tcl`, Clash/DSP,
`topEntity`, GPIOs, or HDMI IP configuration. Because this phase was
explicitly required not to overwrite bit/hwh during deploy, only the
changed Python/script files were copied to the PYNQ repo.

Available fit modes:

- `native`: scale `1.00`, size `1280x720`, offset `(0,0)`.
- `fit-97`: scale `0.97`, size `1242x698`, offset `(19,11)`.
- `fit-95`: scale `0.95`, size `1216x684`, offset `(32,18)`.
- `fit-90`: scale `0.90`, size `1152x648`, offset `(64,36)`.
- `fit-85`: scale `0.85`, size `1088x612`, offset `(96,54)`.
- `fit-80`: scale `0.80`, size `1024x576`, offset `(128,72)`.
- `--scale FLOAT` can override the named mode for custom values.

Test results on PYNQ-Z2:

- `scripts/test_hdmi_fit_frame.py --fit-mode native --hold-seconds 60`:
  OK, no VDMA error bits, copy `0.208 s`.
- `scripts/test_hdmi_fit_frame.py --fit-mode fit-95 --hold-seconds 60`:
  OK, no VDMA error bits, resize/compose `0.289 s`, copy `0.207 s`.
- `scripts/test_hdmi_fit_frame.py --fit-mode fit-90 --hold-seconds 60`:
  OK, no VDMA error bits, resize/compose `0.266 s`, copy `0.207 s`.
- `scripts/test_hdmi_static_frame.py --fit-mode fit-90 --hold-seconds 60`:
  OK, no VDMA error bits, GUI render `2.979 s`, resize/compose
  `0.265 s`, copy `0.207 s`.

Common HDMI status remained `VDMACR=0x00010001`,
`DMASR=0x00011000`, VDMA HSIZE/STRIDE `3840`, VSIZE `720`, VTC
`0x00000006`, framebuffer `0x16900000`.

Recommended first user check is `fit-90`. If it still crops the 40 px
border or corner labels, try `fit-85`; if `fit-95` already fully fits,
use `fit-95` to preserve more screen area.

## HDMI GUI Phase 4E 800x480 logical mode

The small HDMI LCD is likely a 5-inch 800x480 panel. Phase 4E adds a
real 800x480 logical GUI instead of only shrinking the 1280x720 GUI.
Vivado, bit/hwh, VDMA settings, VTC timing, HDMI IP topology,
`block_design.tcl`, `audio_lab.xdc`, `create_project.tcl`, Clash/DSP,
`topEntity`, and GPIO contracts were not changed.

New renderer:

- `GUI/pynq_multi_fx_gui.py::render_frame_800x480(AppState())`
- output shape `[480,800,3]`, dtype `uint8`
- same dark AudioLab visual language, but lower information density:
  large preset/status, compact chain, selected-effect summary,
  simplified signal monitor, and input/output levels
- 24 px logical safe margin

Backend placement:

- input logical frame: `800x480`
- HDMI framebuffer: still `1280x720`
- placement: `center`
- offset: `x=240`, `y=120`
- framebuffer format remains RGB888 input -> DDR `GBR888`
- VDMA HSIZE/STRIDE remains `3840`, VSIZE remains `720`

PYNQ result:

- `scripts/test_hdmi_800x480_frame.py --hold-seconds 60` completed.
- `AudioLabOverlay()` loaded once; no `base.bit`, no `run_pynq_hdmi()`,
  no second overlay.
- ADC HPF `True`, `R19=0x23`, `axi_gpio_delay_line=False`, legacy
  `axi_gpio_delay=True`, HDMI IPs present.
- 800x480 render `0.317 s`.
- center compose `0.026 s`.
- full framebuffer copy `0.207 s`.
- total content update approximately `0.550 s`.
- `VDMACR=0x00010001`, `DMASR=0x00011000`, no VDMA error bits,
  VTC `0x00000006`.
- Post-HDMI Safe Bypass smoke passed.

Compared with the 1280x720 GUI `fit-90` path, the renderer/compose cost
is much lower (`2.979 + 0.265 s` -> `0.317 + 0.026 s`), but the full
1280x720 framebuffer copy still costs about `0.207 s`. Future
optimization should copy only the 800x480 active region if update rate
becomes important. Phase 5A/5C later resolved final placement for the
current 5-inch LCD as top-left `800x480` at `offset_x=0`,
`offset_y=0`.

## HDMI GUI Phase 4F viewport calibration

User visual feedback on the likely 5-inch LCD showed that the Phase 4E
800x480 center placement `(240,120)` appears strongly right-shifted. If
the LCD were scaling the full 1280x720 framebuffer, center placement
would look centered, so the current working hypothesis is LCD-side crop
or non-uniform viewport sampling.

Phase 4F is Python-only. It did not rebuild Vivado, regenerate or copy
bit/hwh, change `block_design.tcl`, `audio_lab.xdc`,
`create_project.tcl`, Clash/DSP, `topEntity`, GPIO semantics, HDMI IP
topology, VDMA settings, or VTC timing.

Backend changes:

- `AudioLabHdmiBackend.start()` / `write_frame()` now support
  `placement="manual"`, `offset_x`, and `offset_y` for logical frames.
- `placement="center"` remains the Phase 4E-compatible default.
- Manual placement clips safely if the logical frame extends outside the
  1280x720 framebuffer.
- `last_frame_write` logs requested offset, source visible region,
  framebuffer copied region, compose time, and copy time.

New calibration script:

- `scripts/test_hdmi_viewport_calibration.py --hold-seconds 60`
- draws a 1280x720 coordinate grid, framebuffer corner/center labels,
  and 800x480 candidate boxes at `(0,0)`, `(120,60)`, `(240,120)`, and
  `(320,120)`.

PYNQ result:

- Targeted deploy copied only Python/script files; `audio_lab.bit`
  stayed `4,045,680` bytes and `audio_lab.hwh` stayed `1,054,120`
  bytes.
- Viewport calibration run completed, draw `0.211 s`, native full-frame
  copy `0.208 s`, `VDMACR=0x00010001`, `DMASR=0x00011000`, VTC
  `0x00000006`, no VDMA error bits.
- 800x480 manual offset tests completed for `(0,0)`, `(80,40)`, and
  `(120,60)`. All used `AudioLabOverlay()` once, no `base.bit`, no
  `run_pynq_hdmi()`, no second overlay, ADC HPF `True`, `R19=0x23`,
  post-HDMI Safe Bypass smoke OK, and no VDMA error bits.
- Timing for the manual-offset GUI tests remained about render
  `0.315..0.316 s`, compose `0.025 s`, full framebuffer copy `0.207 s`.

Phase 5A/5C later resolved the decision for the current 5-inch LCD:
`(0,0)` is the correct practical visible viewport, which supports the
LCD-side crop/viewport hypothesis. Full details are in
`docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE4F_VIEWPORT_CALIBRATION.md`.

## HDMI GUI Phase 4G compact-v2 + negative offsets

Phase 4F's center / positive-offset placement on the 5-inch LCD still
showed a left-side blank strip with the GUI shifted right. Phase 4G
keeps the HDMI signal, VDMA configuration, Vivado design, and bit/hwh
unchanged, and adds two Python-side changes:

1. A `compact-v2` 800x480 renderer:
   `GUI/pynq_multi_fx_gui.render_frame_800x480_compact_v2`, also
   reachable via `render_frame_800x480(state, variant="compact-v2",
   placement_label=...)`. It uses a 12 px outer margin (vs. 24 px in
   `compact-v1`), 2-3 px strokes, wider chain cells, hero `AMP SIM`
   text, larger knob bars and value text, two 16-segment IN / OUT
   meters, TL / TR / BL / BR corner markers, and a variant + offset
   tag at the bottom edge so the placement is visible in any photo.
   `compact-v1` is preserved for the existing Phase 4E call sites.
2. Negative `offset_x` / `offset_y` are supported by
   `audio_lab_pynq.hdmi_backend.compose_logical_frame`. The off-screen
   portion of the source is clipped, and meta now reports
   `negative_offset`, `clipped`, `fully_offscreen`, and the un-clipped
   `requested_destination_region` alongside the existing
   `source_visible_region` and `framebuffer_copied_region`.

`scripts/test_hdmi_800x480_frame.py` now takes
`--variant compact-v1|compact-v2`, `--placement center|manual`, and
optionally-negative `--offset-x` / `--offset-y`. A new
`scripts/test_hdmi_800x480_cycle_offsets.py` loads `AudioLabOverlay()`
once and walks the offsets `(0,0)`, `(-80,0)`, `(-120,0)`, `(-160,0)`,
`(-240,0)`, `(0,-40)`, `(-120,-40)`, `(-160,-40)`, holding each for a
configurable interval so the user can photograph the panel and pick the
best fit.

PYNQ runs (selective `scp` only, full deploy script not used):

- Board-side `audio_lab.bit` stayed `4,045,680` bytes and
  `audio_lab.hwh` stayed `1,054,120` bytes.
- `compact-v2` single-frame at `(0,0)`: render `0.337 s` cold, compose
  `0.026 s`, framebuffer copy `0.207 s`, `VDMACR=0x00010001`,
  `DMASR=0x00011000`, `vtc_ctl=0x00000006`, no VDMA error bits.
- Eight-offset cycle: every offset produced no VDMA error bits.
  Per-offset render `~0.09 s` (cache miss because the placement label
  changes), compose `~0.025 s`, copy `~0.206 s`. Negative offsets
  reported `negative_offset=True`, `clipped=True`, `fully_offscreen=False`.
- Post-HDMI Safe Bypass smoke OK in both runs.

Phase 5A/5C later resolved the final offset as `offset_x=0`,
`offset_y=0`; the negative-offset sweep remains diagnostic history.
Phase 4G details are in
`docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE4G_800X480_LAYOUT_CORRECTION.md`.

## HDMI GUI Phase 4H vertical margin + layout-debug

After Phase 4G the user reported on the 5-inch LCD that (a) the top
edge clips a few pixels, (b) the horizontal direction does NOT
overflow, and (c) the left side either shows an invisible band or an
unused cosmetically empty strip. Phase 4H treats the horizontal symptom
as a layout / viewport diagnosis problem instead of an `offset_x`
correction problem. No Vivado / bit / hwh / block_design / xdc /
GPIO / VDMA / VTC change.

Compact-v2 layout updates:

- New module dict `COMPACT_V2_LAYOUT` plus public helper
  `compact_v2_panel_boxes(width=800, height=480)`. The renderer reads
  its coordinates from the dict.
- Outer chassis moved from `(12,12)..(788,468)` to
  `(12,30)..(788,470)`; the canvas now has ~18 px more breathing room
  at the top so a LCD that crops 20-30 px at the top no longer kills
  the header.
- Panels moved from `x=24` left margin to `x=18` left margin (and
  matching `x=Wv-18` right margin); the left strip is now used by the
  panel content instead of left as cosmetic padding.
- Header band `y=44..118` (was `y=20..100`), chain `y=128..258` (was
  `y=110..250`), bottom row `y=268..458` (was `y=260..454`), variant
  label `y=472` (was `y=Hv-4`).
- New inset "safe corner" L-shapes are drawn in LED-soft at the outer
  rectangle corners alongside the existing canvas-edge TL / TR / BL /
  BR markers. A photo can tell whether the chassis frame itself
  reaches the panel even when the absolute canvas corner is cropped.

New scripts:

- `scripts/test_hdmi_800x480_layout_debug.py`: renders compact-v2,
  composites a 50 px coordinate grid, axis labels, panel bboxes from
  `compact_v2_panel_boxes`, a red `LEFT STRIP x=0..100` band, a cyan
  `TOP STRIP y=0..40` band, and a footer with the current variant /
  offset / canvas size.
- `scripts/test_hdmi_800x480_vertical_offsets.py`: keeps `offset_x=0`
  and walks `offset_y` through `{0, 10, 20, 30, 40, 50}`. Emits a
  warning if `--offset-x` is non-zero because Phase 4H's hypothesis is
  that horizontal correction is the wrong tool.

`scripts/test_hdmi_800x480_frame.py` defaults stay at
`--variant compact-v2 --placement manual --offset-x 0 --offset-y 0`.
The recommended `offset_y` initial range based on the Phase 4G
top-clip observation is `20..30`, but the final value waits on a user
photo session.

PYNQ runs (selective `scp` only):

- Board-side `audio_lab.bit` stayed `4,045,680` bytes,
  `audio_lab.hwh` stayed `1,054,120` bytes, both with the same May 14
  mtime.
- Layout-debug at `offset_y=0`: base render `0.336 s`, overlay compose
  `0.204 s`, framebuffer copy `0.207 s`, `VDMACR=0x00010001`,
  `DMASR=0x00011000`, `vtc_ctl=0x00000006`, no VDMA error bits.
- Vertical sweep `offset_y in {0,10,20,30,40,50}`: every step
  `compose~0.025 s`, `copy~0.206 s`, `clipped=False`, no VDMA error
  bits.
- Single-frame `offset_y=30`: same state, no VDMA error bits.

Phase 4H's positive-`offset_y` direction was rolled back in Phase 4I.
Phase 5A/5C later resolved the current LCD placement as top-left
`800x480` at `offset_x=0`, `offset_y=0`.
Phase 4H details are in
`docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE4H_VERTICAL_MARGIN_AND_LAYOUT_DIAGNOSIS.md`.

## HDMI GUI Phase 4I restore compact-v2 baseline

Phase 4H deployed but on the real 5-inch HDMI LCD the chassis
push-down (`y=30`) and tighter left margin (`18`), paired with a
positive-`offset_y` sweep recommendation, produced a layout shifted
down and to the right rather than fixing the reported top-edge clip.
Phase 4I rolls the renderer back to the Phase 4G compact-v2 baseline
and keeps the Phase 4H diagnostic scripts only as archived
references. No Vivado / bit / hwh / `block_design.tcl` /
`audio_lab.xdc` / `create_project.tcl` / Clash / DSP / `topEntity` /
GPIO / HDMI IP / VDMA / VTC change.

Renderer rollback in `GUI/pynq_multi_fx_gui.py`:

- `COMPACT_V2_LAYOUT` and `compact_v2_panel_boxes()` kept (so
  diagnostic scripts still read the same bboxes the renderer draws),
  but every coordinate moved back to Phase 4G values: outer
  `(12,12)..(788,468)` for 800x480, panel `left` / `right` `24`,
  header `(20, 100)`, chain `(110, 250)`, bottom `(260, 454)`, FX /
  side divider at `Wv//2 +/- 8` via new `divider_half_gap = 8`,
  variant label `y = Hv - 4`.
- Cache key suffix back to `compact_v2_800x480` (was
  `compact_v2_800x480_p4h`).
- Inset LED-soft "safe corner" L-shapes added in Phase 4H removed;
  only the canvas-edge TL / TR / BL / BR markers remain, matching
  Phase 4G.

Phase 4H diagnostic scripts kept as archived diagnostics:

- `scripts/test_hdmi_800x480_layout_debug.py` — module docstring and
  argparse `description` / `epilog` declare the script an archived
  Phase 4H diagnostic; startup banner reinforces that Phase 4I rolled
  back the paired positive `offset_y`.
- `scripts/test_hdmi_800x480_vertical_offsets.py` — same treatment;
  module docstring states the positive-`offset_y` direction is a
  failed direction, not a runtime calibration target. Recommended
  runtime placement remains `offset_x = 0`, `offset_y = 0`.
- `scripts/test_hdmi_800x480_frame.py` — unchanged; defaults stayed
  at `--variant compact-v2 --placement manual --offset-x 0
  --offset-y 0` through Phase 4H and Phase 4I.

Next direction for the 5-inch LCD top-clip / unused-left-strip
symptoms is internal UI density / size tuning at offset `0, 0` and,
if needed, a smaller logical canvas (e.g. 760x440 at composite offset
`(20, 20)`). Changing the HDMI timing to native 800x480 in Vivado is
explicitly deferred to a Phase 5 task because it requires a bit / hwh
rebuild and a timing-summary review.

Phase 4I details are in
`docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE4I_RESTORE_COMPACT_V2_BASELINE.md`.

## HDMI GUI Phase 4J horizontal sweep (superseded)

With Phase 4I deployed the user reports the vertical placement on the
5-inch HDMI LCD is now correct but the layout is shifted to the
right: the right edge of the chassis is clipped by the LCD viewport
and a corresponding empty strip is visible on the left. Phase 4J began
an offset-side horizontal sweep in Python, without disturbing the
(now correct) vertical direction or adding new UI to the left strip.
Claude hit a limit before the Phase 4J work was committed. Phase 5A
backs up this dirty state and treats the Phase 4J sweep as an
interrupted diagnostic log, not as a completed correction or runtime
default. No Vivado / bit / hwh / `block_design.tcl` /
`audio_lab.xdc` / `create_project.tcl` / Clash / DSP / `topEntity` /
GPIO / HDMI IP / VDMA / VTC change. `offset_y` is held at `0` for
the entire phase.

New diagnostic script:

- `scripts/test_hdmi_800x480_horizontal_offsets.py` walks
  `offset_x in {0, -20, -40, -60, -80, -100, -120}` with
  `offset_y = 0` held constant, paints a large `OFFSET X=<value>`
  banner on top of each rendered frame so the active offset is
  readable from a 5-inch LCD photo, captures per-step VDMA error
  bits, and finishes with a Safe Bypass smoke. AudioLabOverlay is
  loaded once; `base.bit` is not loaded and `run_pynq_hdmi()` is
  not called.

Renderer / backend unchanged in Phase 4J:

- `GUI/pynq_multi_fx_gui.py` — Phase 4I (= Phase 4G) compact-v2
  coordinates untouched.
- `audio_lab_pynq/hdmi_backend.py` — manual negative-`offset_x`
  placement path already exists from Phase 4G.
- `scripts/test_hdmi_800x480_frame.py` — defaults still
  `--variant compact-v2 --placement manual --offset-x 0
  --offset-y 0`; Phase 4J runs pass `--offset-x -40` via CLI, no
  default rewrite was made. Phase 5C later kept `offset_x=0`,
  `offset_y=0` as the default.

PYNQ runs (selective `scp` only; deploy script does not stage
`scripts/test_hdmi_800x480_*.py`):

- Single frame `offset_x=-40, offset_y=0`: render `0.446 s`,
  compose `0.0254 s`, framebuffer copy `0.2073 s`,
  `negative_offset=true`, `clipped=true` (40 px clipped on the left
  as designed), `source_visible_region = (40, 0, 800, 480)`,
  `VDMACR=0x00010001`, `DMASR=0x00011000`, `vtc_ctl=0x00000006`, no
  VDMA error bits, post Safe Bypass smoke OK.
- Cycle `offset_x in {0,-20,-40,-60,-80,-100,-120}`,
  `--seconds-per-offset 15 --hold-final-seconds 30`: every step
  `compose ~0.025 s`, `framebuffer copy ~0.206 s`,
  `banner overlay ~0.077 s`, `render` jumps to `~0.09 s` on negative
  offsets because each step has a distinct `placement_label` and
  therefore misses the per-label compact-v2 frame cache (steady-state
  runtime keeps the label constant so this only affects the
  diagnostic sweep). No VDMA error bits at any offset. Final
  `VDMACR=0x00010001`, `DMASR=0x00011000`, `vtc_ctl=0x00000006`. Post
  Safe Bypass smoke OK.

Phase 5A supersedes the Phase 4J offset-side path. The useful record is
that all tested Python offsets kept VDMA/VTC healthy, but the user
judgement is now that the symptom likely comes from the HDMI output
timing / LCD viewport relationship. Do not default-ize a Phase 4J
negative offset unless the user explicitly returns to that path.
The untracked Phase 4J script/doc contents were backed up under
`/tmp/fpga_guitar_effecter_backup/` before Phase 5A edits.

## HDMI GUI Phase 5A output-side diagnosis

Phase 5A stops Python offset chasing and investigates the HDMI output
side of the 5-inch LCD issue. The main suspicion is that the current
1280x720 active area is not being scaled to the LCD's native 800x480
panel as expected; the LCD controller may be cropping, shifting, or
mis-detecting the active viewport.

Phase 5A is docs/script-only. No Vivado rebuild, no bit/hwh
regeneration, no deploy of a new bitstream, no `block_design.tcl`,
`audio_lab.xdc`, `create_project.tcl`, Clash/DSP, `topEntity`, GPIO,
VDMA, VTC, `v_axi4s_vid_out`, or `rgb2dvi` change.

Safety and dirty-state handling:

- Dirty pre-Phase-5A state backed up to
  `/tmp/fpga_guitar_effecter_backup/phase5a_before_output_diagnosis_dirty.patch`
  and
  `/tmp/fpga_guitar_effecter_backup/phase5a_before_output_diagnosis_status.txt`.
- Because untracked files are not included in `git diff`, the
  Phase 4J untracked script/doc were also copied into the same backup
  directory.
- `hw/Pynq-Z2/block_design.tcl`, `hw/Pynq-Z2/audio_lab.xdc`,
  `hw/Pynq-Z2/create_project.tcl`,
  `hw/Pynq-Z2/bitstreams/audio_lab.bit`, and
  `hw/Pynq-Z2/bitstreams/audio_lab.hwh` had no dirty status at
  Phase 5A preflight.

Current output-side facts:

- HDMI signal remains 1280x720 with 74.25 MHz pixel clock.
- `axi_vdma_hdmi` at `0x43CE0000`, `v_tc_hdmi` at `0x43CF0000`.
- `v_axi4s_vid_out_hdmi` and `rgb2dvi_hdmi` are HWH-only pipeline IPs.
- VDMA is MM2S-only, 32-bit memory, 24-bit stream.
- Framebuffer is 1280x720 RGB888 input packed as DDR `GBR888`.
- VDMA HSIZE/STRIDE/VSIZE remain `3840` / `3840` / `720`.
- VTC HWH reports active `1280x720`, H frame `1650`, V frame `750`,
  high-polarity H/V sync, and 720p video mode.
- `rgb2dvi_hdmi` receives `vid_pData[23:16]=R`, `[15:8]=B`,
  `[7:0]=G`, plus `vid_pVDE`, `vid_pHSync`, and `vid_pVSync` from
  `v_axi4s_vid_out_hdmi`.

New output mapping script:

- `scripts/test_hdmi_output_mapping_720p.py` loads `AudioLabOverlay()`
  once, draws a full 1280x720 coordinate grid with 800x480 candidate
  boxes, starts `AudioLabHdmiBackend`, prints VDMA/VTC status, and
  holds the frame so the user can read visible x/y coordinates on the
  physical LCD. It does not tune offsets.
- PYNQ run with `--hold-seconds 60` completed without exception.
  `VDMACR=0x00010001`, `DMASR=0x00011000`, VDMA HSIZE/STRIDE/VSIZE
  `3840/3840/720`, framebuffer `0x16900000`, framebuffer size
  `2,764,800` bytes, `vtc_ctl=0x00000006`, and VDMA error bits
  `dmainterr/dmaslverr/dmadecerr/halted/idle` all false.
  Codex cannot visually inspect the LCD; the user must read the visible
  x/y coordinate labels and candidate boxes from the panel.

EDID/DDC status:

- The local PYNQ-Z2 board file exposes HDMI OUT TMDS pins and
  `hdmi_tx_hpd`, but only HDMI IN DDC pins (`hdmi_in_ddc_scl/sda`).
- The current `audio_lab.xdc` connects PS IIC_1 to audio I2C pins
  `U9/T9`, not HDMI OUT DDC.
- Board-side `/sys/class/drm` exposes `card0`, `renderD128`, and
  `version`, but no EDID file or connector status for the PL HDMI out.
- `/dev/i2c-0` and `/dev/i2c-1` exist (`Cadence I2C` adapters), but
  Phase 5A did not perform blind I2C probing or writes. EDID is not
  currently available from the software path.

The next approved implementation candidate is Phase 5B native 800x480
HDMI timing. The plan is documented in
`docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE5B_NATIVE_800X480_TIMING_PLAN.md`.
Phase 5A details are in
`docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE5A_OUTPUT_SIDE_DIAGNOSIS.md`.

## HDMI GUI Phase 5C default visible viewport

After the Phase 5A output mapping test, the user visually confirmed
that the `800x480 x0 y0` candidate box is the correct viewport on the
5-inch HDMI LCD. The practical operating model is now:

- HDMI signal remains `1280x720`.
- Treat framebuffer `x=0`, `y=0`, `w=800`, `h=480` as the LCD-visible
  UI viewport.
- Standard compact GUI placement is `placement=manual`,
  `offset_x=0`, `offset_y=0`.
- `scripts/test_hdmi_800x480_frame.py` defaults are the standard path:
  `--variant compact-v2 --placement manual --offset-x 0 --offset-y 0
  --hold-seconds 60`.
- Center placement `(240,120)` is not adopted for this LCD.
- Positive and negative offset sweeps are ended for normal operation.
- Native 800x480 HDMI timing remains a Phase 5B candidate, but it is
  not required for correct visible placement now.

`scripts/test_hdmi_800x480_frame.py` keeps CLI overrides for diagnostic
use, but its logs now identify the default run as Phase 5C. It still
loads `AudioLabOverlay()` once, does not load `base.bit`, does not call
`run_pynq_hdmi()`, and does not load a second overlay.

PYNQ-Z2 run:

```sh
sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
  python3 scripts/test_hdmi_800x480_frame.py \
  --variant compact-v2 --placement manual \
  --offset-x 0 --offset-y 0 --hold-seconds 60
```

Result:

- render `0.417 s`
- compose `0.0254 s`
- framebuffer copy `0.2076 s`
- backend start `0.276 s`
- requested destination/source/framebuffer copied region all
  `x0=0`, `y0=0`, `x1=800`, `y1=480`
- `clipped=false`, `negative_offset=false`, `fully_offscreen=false`
- `VDMACR=0x00010001`, `DMASR=0x00011000`
- VDMA HSIZE/STRIDE/VSIZE `3840/3840/720`
- framebuffer `0x16900000`, size `2,764,800` bytes
- `vtc_ctl=0x00000006`
- VDMA error bits all false
- pre/post HDMI smoke kept ADC HPF `true`, `R19=0x23`,
  `axi_gpio_delay_line=false`, HDMI IPs present

## Repository cleanup after Phase 5C

A repo-wide reference check was run before cleanup:

- `GUI/` is active and must be kept. `GUI/pynq_multi_fx_gui.py` and
  `GUI/audio_lab_gui_bridge.py` are tracked, copied by
  `scripts/deploy_to_pynq.sh`, imported by HDMI tests, and covered by
  local tests/docs.
- The old untracked `GUI/README.md` described a stale `base.bit` /
  `run_pynq_hdmi()` workflow. It has been replaced with a current README
  that documents the integrated `AudioLabOverlay()` HDMI path and the
  Phase 5C top-left 800x480 default viewport.
- `HDMI/` was untracked legacy material. Current tracked source did not
  import it, deploy it, or require its assets. The useful historical
  judgement is preserved in the HDMI docs: it was a Windows preview /
  passthrough experiment, not the live AudioLab HDMI implementation.
- The untracked Phase 4J horizontal-offset sweep script/doc were also
  obsolete after Phase 5A/5C and were not committed as a runtime default.

Backup before deletion:

```text
/tmp/fpga_guitar_effecter_backup/repo_cleanup_unused_hdmi_phase4j_20260515_130135.tar.gz
```

Removed from the working tree after backup:

- `HDMI/`
- `docs/ai_context/HDMI_GUI_PHASE4J_HORIZONTAL_LEFT_SHIFT.md`
- `scripts/test_hdmi_800x480_horizontal_offsets.py`

No Vivado rebuild, bit/hwh regeneration, deploy, `git push`, `git pull`,
or `git fetch` was performed for this cleanup.

## HDMI GUI Phase 5D notebook + renderer cleanup

After Phase 5C confirmed the `x=0,y=0,w=800,h=480` LCD viewport, three
follow-up changes finished the GUI runtime story (`DECISIONS.md` D24):

1. **Single-cell HDMI GUI notebook** — `audio_lab_pynq/notebooks/HdmiGui.ipynb`
   is the canonical Jupyter entry point. One code cell loads
   `AudioLabOverlay()`, brings up `AudioLabHdmiBackend`, renders
   `render_frame_800x480_compact_v2(state)` at ~5 fps, and prints a live
   resource report (target/actual FPS, render+VDMA-write ms, CPU%,
   loadavg, MemAvailable-based RAM use, VDMA error bits, current
   `OFFSET_X`/`OFFSET_Y`, `framebuffer_copied_region`). `OFFSET_X` and
   `OFFSET_Y` are configurable at the top of the cell so an LCD whose
   visible viewport drifts off `(0,0)` can be recalibrated without
   editing the renderer. `Interrupt Kernel` (`I,I`) drops into a
   `finally:` that calls `backend.stop()` cleanly.

2. **1280x720 reference renderer + Windows preview removed.**
   `GUI/pynq_multi_fx_gui.py` shrank from 3372 to ~1314 lines after
   removing `render_frame`, `render_frame_fast`, `render_frame_legacy`,
   `render_frame_pynq_static`, `_render_full`, the static/semistatic
   layer cache helpers, `TkApp`, `run_windows_window`,
   `run_windows_fullscreen`, `get_monitor_rects`, the demo PNG / CLI
   loop / hit-test / benchmark sections, `run_pynq_hdmi()`, the
   `_build_argparser` CLI entry, and the 1280x720 chassis chrome
   helpers (`draw_background`, `draw_top_status`, `draw_main_display*`,
   `_draw_preset_card`, `_draw_right_panel`, `draw_signal_chain`,
   `_io_marker` / `_wire` / `_block_icon` / `_draw_chain_block`,
   `draw_visualizer*`, `draw_knob_panel*`, `draw_knob`,
   `_knob_body_layer`, `draw_footswitch*`, `draw_led`, plus
   `panel_with_bevel`, `inset_screen`, `screw`, `add_brushed_metal`,
   and the orphan `W, H, CHASSIS_PAD, Y_TOPBAR_T/B, RECT_*, COL_*`
   layout constants). Public API is now `AppState`,
   `render_frame_800x480`, `render_frame_800x480_compact_v2`,
   `make_pynq_static_render_cache`, `compact_v2_panel_boxes`,
   `save_state_json`, `load_state_json`. Dependent scripts
   `scripts/test_hdmi_static_frame.py` and
   `scripts/profile_hdmi_static_frame.py` were deleted; remaining
   diagnostic scripts use the 800x480 path or build their own 1280x720
   test pattern directly. `GUI/README.md` and the top of
   `audio_lab_pynq/hdmi_backend.py` were updated to point at
   `render_frame_800x480_compact_v2`.

3. **compact-v2 layout: full-width SELECTED FX + per-effect knob grid.**
   The `side` (MONITOR + IN/OUT meters) panel was removed and `fx`
   now spans `(24, 260, 776, 454)`. The selected-FX knob grid is
   driven by `state.knobs()` filtered against the empty `("", 0)`
   slots in `EFFECT_KNOBS`, and chooses cols/rows from the live knob
   count:

   | Effect | Knobs (from `EFFECT_KNOBS`) | Grid |
   | --- | --- | --- |
   | Noise Sup | THRESH, DECAY, DAMP | 3 × 1 |
   | Compressor | THRESH, RATIO, RESPONSE, MAKEUP | 2 × 2 |
   | Overdrive | DRIVE, TONE, LEVEL | 3 × 1 |
   | Distortion | DRIVE, TONE, LEVEL, BIAS, TIGHT, MIX | 3 × 2 |
   | Amp Sim | GAIN, BASS, MID, TREBLE, MASTER, CHAR | 3 × 2 |
   | Cab IR | MIX, LEVEL, MODEL, AIR | 2 × 2 |
   | EQ | LOW, MID, HIGH | 3 × 1 |
   | Reverb | DECAY, TONE, MIX | 3 × 1 |

   `compact_v2_panel_boxes()` now returns `outer`, `header`, `chain`,
   and `fx` only (no `side`); `divider_half_gap` was dropped.
   `scripts/test_hdmi_800x480_layout_debug.py` iterates the dict and
   already tolerates the smaller set.

4. **`install_notebooks()` is `shutil`-based.** During an earlier
   re-deploy, the Jupyter copy of `HdmiGui.ipynb` ended up as a
   zero-byte file (Jupyter refused to open it). Root cause was the
   module-level `_path_created` cache inside
   `distutils.dir_util.copy_tree`, which on retry can mark a directory
   as already-handled and skip the real copy. `audio_lab_pynq/__init__.py`
   now uses `shutil.copytree` for the notebooks tree (after the
   existing `rmtree`) and an explicit per-file `shutil.copyfile` loop
   for the bitstreams subdir. The 0-byte deploy was repaired
   in place by `sudo cp` from
   `/usr/local/lib/python3.6/dist-packages/audio_lab_pynq/notebooks/HdmiGui.ipynb`
   onto the Jupyter tree; the next clean `bash scripts/deploy_to_pynq.sh`
   confirmed md5 `632c58fbdfb995f969862af8bc618c10` end-to-end.

No Vivado rebuild, bit/hwh regeneration, `git push`, `git pull`, or
`git fetch` was performed for Phase 5D.

## HDMI GUI Phase 5D Pip-Boy inspired green theme

Phase 5D also retunes the 800x480 compact-v2 renderer's colour palette
toward a "phosphor green monochrome CRT" look with a soft horizontal
scanline overlay. No Pip-Boy / Fallout logo, font, icon, screen text,
or layout pattern is copied; the inspiration is the generic black-green
CRT aesthetic. The 800x480 logical GUI keeps `placement=manual`,
`offset_x=0`, `offset_y=0` inside the fixed 1280x720 HDMI signal.
`audio_lab.bit`, `audio_lab.hwh`, `block_design.tcl`, `audio_lab.xdc`,
`create_project.tcl`, and `LowPassFir.hs` were not touched. compact-v1
keeps the pre-Phase-5D cyan look so prior tooling pinned to that
variant stays pixel-stable.

What landed:

- `GUI/pynq_multi_fx_gui.py` -- new `_make_theme(...)` helper,
  `CYAN_THEME` (legacy) and `PIPBOY_THEME` (Pip-Boy-inspired phosphor
  green), `THEMES` dict, `DEFAULT_800X480_THEME = "pipboy-green"`,
  `resolve_theme()`, and a numpy `_apply_scanlines_inplace(...)`
  helper. `_render_frame_800x480_compact_v2` now takes a `theme=`
  kwarg, aliases palette colours to local names, and reads every
  previously-literal RGB tuple from the active palette; the frame
  cache key now includes the theme name. `render_frame_800x480` /
  `render_frame_800x480_compact_v2` forward the new `theme` argument.
- `scripts/test_hdmi_800x480_frame.py` -- new
  `--theme {pipboy-green, cyan}` flag (default `pipboy-green`);
  report tag is `5D-pipboy-green-theme`. The script is not in the
  `deploy_to_pynq.sh` manifest, so manual `scp` is required when
  running it on the PYNQ.
- `docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE5D_PIPBOY_GREEN_THEME.md` -- full
  palette table, scanline parameters, and the captured PYNQ smoke
  results.

PYNQ smoke (`--variant compact-v2 --theme pipboy-green --placement
manual --offset-x 0 --offset-y 0 --hold-seconds 60`):

- VDMA error bits `dmainterr` / `dmaslverr` / `dmadecerr`: all False
- `vdma_dmasr = 0x00011000`, `vtc_ctl = 0x00000006`
- framebuffer copied region: (0..800, 0..480)
- `clipped` / `negative_offset` / `fully_offscreen`: all False
- pre / post smoke: `ADC HPF = True`, `R19 = 0x23`, HDMI IPs present
- render / compose / framebuffer-copy timings recorded in
  `/tmp/hdmi_phase5d_pipboy_green.log` on the dev box

The first PYNQ run used a PIL `alpha_composite` scanline that cost
about 100 ms cold render. The shipped renderer replaces that with a
single vectorised numpy slice on the final RGB array, keeping the
cold render inside the +10..15 % budget; the deployed visual output
is identical row-by-row. The board went off the network shortly
after the first successful run, so the numpy-optimised path has
local smoke coverage only -- re-running the on-board smoke once the
board is reachable again is recommended.

## HDMI GUI Phase 1 render benchmark (docs only)

Phase 1 measured `GUI/pynq_multi_fx_gui.py` offscreen rendering on the
PYNQ-Z2. The test did not call `run_pynq_hdmi()`, did not load
`base.bit`, did not instantiate `AudioLabOverlay()`, did not write GPIOs,
did not use HDMI output, and did not change Vivado, bitstreams, deploy
scripts, or Python source files.

Board-side environment:

- Host: `192.168.1.9`
- Python: `3.6.5`
- NumPy: `1.16.0`
- Pillow: `5.1.0`
- Benchmark file location: `/tmp/hdmi_gui_phase1/pynq_multi_fx_gui.py`
  (temporary copy only; no deploy)

Key result:

- Raw import fails on the current PYNQ image:
  `ModuleNotFoundError: No module named 'dataclasses'`.
- Rendering also needs compatibility work for NumPy 1.16
  (`np.random.default_rng`) and Pillow 5.1 `ImageDraw` keyword support.
- With process-local benchmark shims only, `render_frame_fast(AppState())`
  produced a 1280x720 RGB frame: shape `[720, 1280, 3]`, dtype `uint8`.
- Cold render: `3871.43 ms`.
- Same-state cached render: avg `0.177 ms/frame`, p95 `0.242 ms/frame`
  over 30 calls; the same cached ndarray object was reused.
- Dynamic 30-frame loop: avg `744.49 ms/frame`, p95 `2246.92 ms/frame`,
  estimated `1.34 fps`.
- Memory high-water mark during the benchmark was about `129380 kB`.

Assessment:

- Current renderer is not suitable for animated 5/10/15/30fps HDMI output
  on the PYNQ-Z2 CPU.
- Static or change-driven display is plausible after compatibility fixes,
  because cache hits are sub-millisecond once a frame is generated.
- Future Python work should first handle `dataclasses`, NumPy 1.16, and
  Pillow 5.1 compatibility before building the `AppState` /
  `AudioLabOverlay` bridge.

Full results are in
`docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE1_RENDER_BENCH.md`.

## HDMI GUI Phase 2A PYNQ compatibility

Phase 2A changed only `GUI/pynq_multi_fx_gui.py` and docs. It did not call
`run_pynq_hdmi()`, did not load `base.bit`, did not instantiate
`AudioLabOverlay()`, did not write GPIOs, did not use HDMI output, and did
not change Vivado, block design, bitstreams, deploy scripts, notebooks, or
DSP source.

PYNQ-Z2 result from `/tmp/hdmi_gui_phase2a/pynq_multi_fx_gui.py`:

- raw import without shims: success
- import time: `451.188 ms`
- `render_frame_fast(AppState())`: success
- frame shape / dtype: `[720, 1280, 3]` / `uint8`
- cold render: `3764.514 ms`
- same-state cached render over 30 calls: avg `0.171034 ms/frame`, p95
  `0.201208 ms/frame`
- change-driven redraw samples with animation time held static: avg
  `1972.889 ms/frame`, p95 `2111.738 ms/frame`
- saved PNG: `/tmp/hdmi_gui_phase2a/phase2a_render.png`, 1280x720 RGB,
  visually checked

Conclusion: the module is now usable for offscreen static frame generation
on the board, but live animated HDMI remains unrealistic. The future HDMI
backend should be static/change-driven, freeze or heavily throttle
visualizer / waveform / meter animation, and reuse the previous RGB frame
while state is unchanged.

## HDMI GUI Phase 2B render optimization

Phase 2B changed only `GUI/pynq_multi_fx_gui.py` and docs. It did not call
`run_pynq_hdmi()`, did not load `base.bit`, did not instantiate
`AudioLabOverlay()`, did not write GPIOs, did not use HDMI output, and did
not change Vivado, block design, bitstreams, deploy scripts, notebooks, or
DSP source.

Key renderer changes:

- cached static LCD / knob-panel chrome in `render_static_base()`
- split main display and knob panel into static chrome and state content
- cached knob body chrome
- added `make_pynq_static_render_cache()` and `render_frame_pynq_static()`
- in PYNQ static mode, froze the synthetic visualizer / waveform and
  suppressed high-cost glow / blur stamps

PYNQ-Z2 result from `/tmp/hdmi_gui_phase2b/pynq_multi_fx_gui.py`:

- raw import without shims: success
- import time: `464.178 ms`
- frame shape / dtype: `[720, 1280, 3]` / `uint8`
- default fast cold render: `3407.583 ms`
- default fast change-driven redraw: avg `690.397 ms/frame`, p95
  `726.448 ms/frame`
- PYNQ static cold render: `2886.108 ms`
- PYNQ static same-state cache: avg `0.491993 ms/frame`, p95
  `0.200019 ms/frame` (one scheduler outlier affected the avg)
- PYNQ static change-driven redraw: avg `255.625 ms/frame`, p95
  `276.171 ms/frame`
- saved PNG: `/tmp/hdmi_gui_phase2b/phase2b_pynq_static.png`, 1280x720
  RGB, visually checked

Conclusion: static/change-driven HDMI updates are now plausible from a
Python rendering perspective. This is still not a live animated
5/10/15/30fps path; the future HDMI backend should render on visible
state changes and reuse the previous RGB frame while unchanged.

## HDMI GUI Phase 2C AppState bridge

Phase 2C added a renderer-separated bridge in
`GUI/audio_lab_gui_bridge.py` plus `tests/test_hdmi_gui_bridge.py`. It did
not call `run_pynq_hdmi()`, did not load `base.bit`, did not instantiate
`AudioLabOverlay()`, did not write GPIOs on the board, did not use HDMI
output, and did not change Vivado, block design, bitstreams, deploy
scripts, notebooks, or DSP source.

Bridge behavior:

- maps `AppState` to existing `AudioLabOverlay` APIs only
- produces dry-run plans by default
- suppresses same-state writes by operation signature
- throttles continuous knob-drag events to about 10 Hz
- treats Chain Preset / Safe Bypass as high-priority commands
- treats chain reorder as warning-only because the FPGA DSP order is
  fixed
- does not expose chorus, phaser, octaver, delay, or bit-crusher as live
  controllable effects

PYNQ-Z2 result from `/tmp/hdmi_gui_phase2c/`:

- raw import without shims: success
- Python: `3.6.5`
- import time: `1442.238 ms`
- dry-run plan methods:
  `set_noise_suppressor_settings`, `set_compressor_settings`,
  `clear_distortion_pedals`, `set_distortion_settings`,
  `set_guitar_effects`
- same-state second apply: `0` operations
- knob-drag throttle: `0` operations / `1` skipped inside the throttle
  window, then `1` operation after the window
- `render_frame_pynq_static(AppState())` still produced frame shape /
  dtype `[720, 1280, 3]` / `uint8`

Conclusion at the time: the bridge shape was ready for a later real
overlay-backed test, but Phase 2C deliberately verified only dry-run
planning. The integrated HDMI video path was later implemented in Phase 4.

## HDMI GUI Phase 2D bridge runtime test on real AudioLabOverlay

Phase 2D ran `GUI/audio_lab_gui_bridge.py` with `dry_run=False` against
the deployed `audio_lab.bit` on the PYNQ-Z2 (`192.168.1.9`). The
`AudioLabOverlay()` was loaded exactly once for the entire test. No
HDMI output, no `run_pynq_hdmi()`, no `Overlay("base.bit")`, no second
overlay load, no Vivado / block-design / bitstream / hwh / Notebook /
DSP change, no `scripts/deploy_to_pynq.sh`, and no
`git push` / `pull` / `fetch`.

Operations actually written via the public `AudioLabOverlay` API (in
order, single `AudioLabOverlay()` load throughout):

- Safe Bypass: `clear_distortion_pedals`, `set_distortion_settings`,
  `set_noise_suppressor_settings`, `set_compressor_settings`,
  `set_guitar_effects`.
- Chain Preset apply: `apply_chain_preset(name="Basic Clean")`.
- Forced baseline `apply(force=True)`: `set_noise_suppressor_settings`,
  `set_compressor_settings`, `clear_distortion_pedals`,
  `set_distortion_settings`, `set_guitar_effects`.
- Same-state second apply: `0` operations, `0` skipped.
- Noise Sup THRESHOLD only: `set_noise_suppressor_settings` +
  `set_guitar_effects` (legacy mirror byte; documented in
  `GPIO_CONTROL_MAP.md`).
- Compressor RATIO only: `set_compressor_settings` (1 op).
- Knob-drag inside the 100 ms throttle window: `0` operations,
  `1` skipped.
- Knob-drag after the throttle window: `1` operation.
- Final Safe Bypass at end of test.

Pre and post smoke (`/tmp/hdmi_gui_phase2d/phase2d_report.json`):

- `ADC HPF`: `True`
- `R19`: `0x23`
- `has delay_line gpio`: `False`
- `has legacy axi_gpio_delay`: `True`

Detailed results are recorded in
`docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE2D_BRIDGE_RUNTIME_TEST.md`.

## HDMI GUI Phase 3 Vivado integration design proposal

Phase 3 is a design-only proposal for adding a HDMI framebuffer output
path to the existing `audio_lab.bit`. **No `hw/Pynq-Z2/block_design.tcl`
edit, no IP add, no Vivado build, no bitstream / hwh rebuild, no deploy,
and no HDMI output** was performed.

Recommendation: **Option B** — minimal `axi_vdma` + `v_tc` +
`v_axi4s_vid_out` + Digilent `rgb2dvi`, with one new `clk_wiz` for
`pixel_clk = 74.25 MHz` and `serial_clk = 371.25 MHz`, one new
`proc_sys_reset` for the pixel / serial domain, and `S_AXI_HP0` enabled
on the existing `processing_system7_0` for the VDMA MM2S framebuffer
read path. Single fixed mode is 1280x720@60.

Address-map additions (candidates, not yet allocated):

- `axi_vdma_hdmi/S_AXI_LITE` -> `0x43CE0000`, range `0x00010000`
- `v_tc_hdmi/CTRL` -> `0x43CF0000`, range `0x00010000`
- `rgb2dvi_hdmi/CTRL` -> `0x43D00000`, range `0x00010000` (if applicable)

No existing AXI GPIO address, name, or `ctrlA`-`ctrlD` semantic is
changed. The legacy `axi_gpio_delay` stays at `0x43C80000`. The
`fx_gain_0` HLS block stays where it is at `0x43C20000`.

Framebuffer plan:

- 1280x720 XRGB8888 in PS DDR, allocated via `pynq.allocate` (or
  `cacheable=False` for a small write penalty and no cache flush).
- Renderer keeps producing RGB888 `(720, 1280, 3)` `uint8`; the HDMI
  back end copies into XRGB888.
- Double-buffered scanout to avoid tear.
- Realistic target: 2..4 fps change-driven update on top of a 60 Hz
  scanout. Phase 2B PYNQ static redraw cost (~256 ms / frame)
  remains the dominant cost; the scanout itself is free.

Resource / timing budget estimate (Vivado run will replace these
numbers):

- Audio baseline (deployed `audio_lab.bit`): WNS `-8.155 ns`,
  LUTs 15473 (29.08%), Regs 14914 (14.02%), BRAM 7 (5.00%),
  DSPs 83 (37.73%).
- Estimated extra: ~3.4 k..4.0 k LUTs, ~4.8 k..5.3 k FFs, ~4..7 BRAM,
  0 extra DSPs. PYNQ-Z2 still has plenty of headroom.
- Deploy gate: audio-domain WNS must not slip materially below
  `-8.5 ns`. Pixel and serial domains must close (WNS >= 0).

Rollback: dated bit/hwh backups + `git revert` on the future
feature branch. Local commits only.

Detailed proposal is in
`docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE3_VIVADO_DESIGN_PROPOSAL.md`. The
proposed `block_design.tcl` patch shape is in
`docs/ai_context/HDMI_BLOCK_DESIGN_TCL_PATCH_PLAN.md`. The Phase 4
implementation prompt draft is in
`docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE4_IMPLEMENTATION_PROMPT_DRAFT.md`.
