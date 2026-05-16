# Current state

Last updated: **2026-05-16, Phase 6I C2 deployed** (commits
`5332b7e` / `3afd9c4` / `e2ece2e`, merged to `main` at `e2ece2e`).

## Current load-bearing facts

- **HDMI signal**: VESA SVGA `800x600 @ 60 Hz`, pixel clock
  `40.000 MHz`, `H total 1056`, `V total 628`, `rgb2dvi kClkRange=3`
  (`DECISIONS.md` D25). Not 720p, not native 800x480.
- **Framebuffer**: `audio_lab_pynq/hdmi_backend.py` defaults to
  `DEFAULT_WIDTH=800`, `DEFAULT_HEIGHT=600`. The 800x480 compact-v2
  GUI composes at framebuffer `(0,0)` (top 480 rows = UI, bottom 120
  rows = black). VDMA: `HSIZE=2400, STRIDE=2400, VSIZE=600`.
- **GUI renderer**: `GUI/pynq_multi_fx_gui.py::render_frame_800x480_compact_v2`
  + the (1).py-spec `EFFECT_KNOBS` / `AppState.all_knob_values` /
  `hit_test_compact_v2()` API from Phase 6H port (`DECISIONS.md` D24).
- **Notebook runtime**: `audio_lab_pynq/notebooks/HdmiGui.ipynb`
  (live loop, resource monitor, `OFFSET_X` / `OFFSET_Y` calibration)
  and `audio_lab_pynq/notebooks/HdmiGuiShow.ipynb` (one-shot,
  smart-attach via `download=False` when bit already loaded —
  protects the rgb2dvi PLL at the 800 MHz VCO lower edge from
  re-`download=True` knock-outs in the same Jupyter session).
- **PL timing baseline**: WNS `-8.096 ns`, TNS `-6389.430 ns`,
  WHS `+0.040 ns`, THS `0.000 ns`; Slice LUTs `18618 (35.00%)`,
  Slice Registers `20846 (19.59%)`. Within the historical
  `-7..-9 ns` deploy band. See `TIMING_AND_FPGA_NOTES.md`.

## Phase history (chronological)

Phase 4 integrated HDMI framebuffer deployed; Phase 4C profiled the
deployed bit; Phase 4D added LCD fit modes; Phase 4E tested the
800x480 logical GUI; Phase 4F added manual viewport calibration;
Phase 4G shipped compact-v2 + negative-offset placement; Phase 4H
added vertical safe margins + a layout-debug overlay; Phase 4I rolled
back Phase 4H's chassis push-down to the 4G baseline; Phase 4J's
horizontal-only negative-offset sweep was left uncommitted, superseded
by Phase 5A. Phase 5A started HDMI output-side diagnosis for the
5-inch 800x480 LCD; Phase 5C locked the user-confirmed
`x=0,y=0,w=800,h=480` viewport default on the PYNQ-Z2 at
`192.168.1.9`; the post-5C cleanup kept active `GUI/` and removed the
legacy untracked `HDMI/` tree. Phase 5D added the Pip-Boy-inspired
phosphor-green theme + soft scanline overlay on the (then) 1280x720
path. Phase 6F rechecked the recurring right-shift report (bbox /
backend / framebuffer all `(0,0)`); Phase 6G added strong-UI-bbox
diagnostics + an actual-UI visual test (intermediate renderer
x-tightening was rolled back). Phase 6H (`d7ea0ab`) ported the
compact-v2 renderer to the (1).py spec (single `EFFECT_KNOBS` dict,
inline PEDAL / AMP / CAB model dropdown, Phase 4G / 4I baseline
coordinates restored). The subsequent Phase 6H native 800x480 / 40 MHz
timing pass was **rejected** on the LCD (white screen) and never
committed. Phase 6I rolled back to 720p, swept candidate timings, and
deployed **VESA SVGA 800x600 @ 60 Hz / 40 MHz** as the working HDMI
signal — same H/V totals as the rejected Phase 6H, but with
SVGA-standard 800x600 active that the LCD's HDMI receiver actually
recognises. The Phase 5D / 6F references to a "1280x720 HDMI signal"
below this paragraph describe what was true at those phases; the
current signal is the Phase 6I SVGA 800x600 path.

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

## PYNQ-Z2 network identity

The lab board should be kept at a stable router DHCP reservation:

| Field | Value |
| --- | --- |
| Device name | `PYNQ-Z2` |
| eth0 MAC | `00:05:6B:02:CA:04` |
| Reserved IP | `192.168.1.9` |
| SSH | `ssh xilinx@192.168.1.9` |
| Jupyter | `http://192.168.1.9:9090/tree` |

Use `bash scripts/show_pynq_network_info.sh` to confirm hostname, IP,
and eth0 MAC from the board. The reservation itself must be created in
the router management UI; do not rely on ad-hoc IP scans as normal
operation, and do not write a static IP directly on the PYNQ for this
workflow. After changing the reservation, reboot the PYNQ-Z2 and run:

```sh
ssh xilinx@192.168.1.9 'hostname; ip -br addr; cat /sys/class/net/eth0/address'
bash scripts/deploy_to_pynq.sh
```

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

- The current deployed `audio_lab.bit` contains the Phase 4 HDMI
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

## Internal mono DSP pipeline (this branch, `feature/internal-mono-dsp-pipeline`)

This pass converts the active DSP signal path to mono internally while
preserving the deployed stereo external contract.

What landed:

- `topEntity`, port names, port order, external I/O, AXI Stream 48-bit
  input/output, `block_design.tcl`, GPIO topology, Python API,
  Notebook UI, and Chain Presets are unchanged.
- AXI input still arrives as stereo frames, but `AudioLab.Axis.makeInput`
  treats ADC Left as the guitar mono source and discards Right to avoid
  unconnected-channel noise. The physical `Frame` record keeps its
  L/R-shaped fields for compatibility, but the active helpers use one
  mono sample/state.
- Effect stages in `AudioLab.Effects.*` now process the active path from
  mono helpers/state. The stereo duplicate state in the main path was
  collapsed where safe; coefficients, clip knees, byte mappings, enable
  semantics, and stage order were not retuned.
- `AudioLab.Axis.pipeData` duplicates the mono result to output
  Left/Right, so the external AXI/I2S stream remains stereo-compatible.
- AXI Stream packet metadata remains separate from sample data:
  `Frame.fLast` carries input TLAST to output TLAST, and
  `AudioLab.Pipeline` now paces accepted input frames so the fixed-
  latency DSP pipeline does not drop an in-flight output frame or TLAST
  when the S2MM DMA side briefly deasserts ready.
- No 96 kHz work, PCM1808 / PCM5102 support, external ADC/DAC support,
  I2S addition, internal 32-bit conversion, new GPIO, Delay-line IP, or
  `axi_gpio_delay_line` was added.

Build/deploy status:

- Local tests passed:
  `python3 -m compileall audio_lab_pynq scripts`,
  `python3 tests/test_overlay_controls.py`, and Notebook JSON checks
  for `GuitarPedalboardOneCell.ipynb`, `GuitarEffectSwitcher.ipynb`,
  and `DistortionModelsDebug.ipynb`.
- Clash type check and VHDL generation passed. Vivado IP repackage
  passed. Vivado bitstream build completed with
  `write_bitstream completed successfully`.
- Final routed timing: WNS = -8.155 ns, TNS = -6492.876 ns,
  WHS = +0.052 ns, THS = 0.000 ns. Versus the minimal mono build /
  `37ef4c7` baseline (WNS = -8.022 ns), WNS delta is -0.133 ns.
  Hold remains clean.
- Utilization after place: Slice LUTs = 15473 (29.08%), Slice
  Registers = 14914 (14.02%), Block RAM Tile = 7 (5.00%), DSPs = 83
  (37.73%).
- PYNQ-Z2 deploy completed with `bash scripts/deploy_to_pynq.sh`
  using the default `PYNQ_HOST=192.168.1.9`.
- PYNQ smoke test confirmed `ADC HPF: True`, `R19 = 0x23`,
  `has delay_line gpio: False`, `has legacy axi_gpio_delay: True`,
  and all requested chain presets.
- DMA validation after PYNQ reboot used one overlay load and one
  composite DMA packet for Case A (Left nonzero / Right different),
  Case B (Left zero / Right large), and Case C (Right inverted noise).
  All cases completed without timeout; send and recv DMASR both ended
  at `0x00001002`. With `skip_frames = 16`, output L/R were identical
  (`max_abs_lr_diff_steady_state = 0`) and Right input rejection was
  confirmed (`max_abs_output_when_left_zero = 0`,
  `max_abs_output_change_when_right_input_changes = 0`).

## LowPassFir behavior-preserving split (this branch, `feature/split-lowpassfir-behavior-preserving`)

This pass is **only** a Haskell/Clash module split. It prepares the DSP
source for future mono / 96 kHz / external ADC-DAC / internal-width /
I2S work without implementing any of those changes now.

What landed:

- `hw/ip/clash/src/LowPassFir.hs` is now a thin top module that keeps
  the `LowPassFir` module name, `Synthesize` annotation, `topEntity`
  type, port names, port order, and external I/O unchanged.
- New `hw/ip/clash/src/AudioLab/*` modules hold the moved code:
  `Types`, `FixedPoint`, `Control`, `Axis`,
  `Effects.NoiseSuppressor`, `Effects.Compressor`,
  `Effects.Overdrive`, `Effects.Distortion`, `Effects.Amp`,
  `Effects.Cab`, `Effects.Eq`, `Effects.Reverb`, and `Pipeline`.
- Function bodies were moved, not retuned. The split keeps the existing
  `Frame` shape, sample widths, accumulator widths, fixed-point helper
  arithmetic, coefficients, clip knees, enable / bypass behavior, and
  pipeline stage order.
- `AudioLab.Pipeline` owns `fxPipeline`; effect modules expose the
  same stage functions to the pipeline.
- `hw/ip/clash/vhdl/LowPassFir/*` was regenerated and the IP was
  repackaged.
- `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}` was rebuilt locally.

Build/deploy status:

- Local tests passed:
  `python3 -m compileall audio_lab_pynq scripts`,
  `python3 tests/test_overlay_controls.py`, and Notebook JSON checks
  for `GuitarPedalboardOneCell.ipynb`, `GuitarEffectSwitcher.ipynb`,
  and `DistortionModelsDebug.ipynb`.
- Clash type check and VHDL generation passed. Vivado IP repackage
  passed. Vivado bitstream build completed with
  `write_bitstream completed successfully`.
- Final routed timing: WNS = -8.022 ns, TNS = -13937.512 ns,
  WHS = +0.052 ns, THS = 0.000 ns. This is equal to the previous
  deployed Amp Simulator fizz-control baseline (WNS delta 0.000 ns).
  Hold remains clean.
- Utilization after place: Slice LUTs = 21809 (40.99%), Slice
  Registers = 18675 (17.55%), Block RAM Tile = 7 (5.00%), DSPs = 158
  (71.82%).
- PYNQ-Z2 deploy completed with
  `PYNQ_HOST=192.168.1.9 bash scripts/deploy_to_pynq.sh`.
- PYNQ smoke test loaded `AudioLabOverlay`, confirmed `ADC HPF: True`
  and `R19 = 0x23`, confirmed `has delay_line gpio: False` and
  `has legacy axi_gpio_delay: True`, listed all four amp models, and
  applied Safe Bypass, Basic Clean, Tube Screamer Lead, RAT Rhythm,
  DS-1 Crunch, Big Muff Sustain, Vintage Fuzz, Metal Tight, and
  Ambient Clean.

What did **not** change:

- No DSP algorithm change, coefficient change, bit-width change,
  mono conversion, 96 kHz work, PCM1808 / PCM5102 support, I2S
  interface change, or external ADC/DAC support.
- No `topEntity` interface change, no `block_design.tcl` change, no
  new AXI GPIO, and no GPIO address / `ctrlA`-`ctrlD` semantic change.
- No Python API, Notebook UI, Chain Preset, or effect preset change.
- No Delay implementation from `feature/bram-delay-500ms`; no
  `axi_gpio_delay_line`. Legacy `axi_gpio_delay` remains present.
- No C++ DSP prototype or GPL/commercial source-code import.

## Amp Simulator fizz-control pass (this branch, `feature/amp-sim-fizz-control`)

This pass targets **only** high-frequency fizz generated inside the
Amp Simulator. It does not address input -> bypass tone differences,
noise floor, codec/I2S/hardware routing, or capture-analysis tooling.
It also does not touch Cab Sim topology, Compressor, Noise Suppressor,
Reverb, Delay, Python API, Notebook UI, GPIO names/addresses, or
`block_design.tcl`.

What landed:

- `hw/ip/clash/src/LowPassFir.hs`:
  - `ampPreLowpassFrame`: existing one-pole post-clip smoothing keeps
    `baseAlpha = 128 + (charByte >> 2)` but increases the per-model
    darken from `0 / 2 / 8 / 16` to `0 / 4 / 12 / 24`. `jc_clean`
    stays bright; `high_gain_stack` is damped most strongly.
  - `ampTrebleGain`: now takes the existing `amp_character` byte and
    applies a small model-dependent cap. The base treble return is
    reduced from roughly `64 + 7/16*T` to `64 + 13/32*T`, then trimmed
    by `0 / 2 / 5 / 9` for the four amp bands so TREBLE=100 cannot
    restore as much 8..16 kHz fizz.
  - `ampResPresenceProductsFrame`: presence remains tied to the
    existing `amp_presence` byte but gets extra model-dependent trim
    of `0`, `presence>>5`, `presence>>4`, or `presence>>3`. This keeps
    clean presence open while capping the high-gain presence return.
  - `ampPowerFrame` and `ampResPresenceMixFrame`: safety `softClipK`
    knee tightened from `3_500_000` to `3_400_000` to keep internal
    gain spikes from leaking as broad high-frequency fizz.
- `hw/ip/clash/vhdl/LowPassFir/*`: regenerated VHDL + repackaged IP.
- `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}`: rebuilt and deployed.

Build/deploy status:

- Local tests passed:
  `python3 -m compileall audio_lab_pynq scripts`,
  `python3 tests/test_overlay_controls.py`, and Notebook JSON checks
  for `GuitarPedalboardOneCell.ipynb`, `GuitarEffectSwitcher.ipynb`,
  and `DistortionModelsDebug.ipynb`.
- Clash type check and VHDL generation passed. Vivado bitstream build
  completed with `write_bitstream completed successfully`.
- Final routed timing: WNS = -8.022 ns, TNS = -13937.512 ns,
  WHS = +0.052 ns, THS = 0.000 ns. This improves WNS by 0.709 ns vs
  the previous deployed audio-analysis baseline (-8.731 ns). Hold
  remains clean.
- Utilization after place: Slice LUTs = 21809 (40.99%), Slice
  Registers = 18675 (17.55%), Block RAM Tile = 7 (5.00%), DSPs = 158
  (71.82%). No BRAM increase was introduced by this pass.
- PYNQ-Z2 deploy completed with
  `PYNQ_HOST=192.168.1.9 bash scripts/deploy_to_pynq.sh`.
- PYNQ smoke test loaded `AudioLabOverlay`, confirmed `ADC HPF: True`
  and `R19 = 0x23`, confirmed `has delay_line gpio: False` and
  `has legacy axi_gpio_delay: True`, exercised all four amp models,
  and applied Safe Bypass, Basic Clean, Tube Screamer Lead, RAT
  Rhythm, DS-1 Crunch, Big Muff Sustain, Vintage Fuzz, Metal Tight,
  and Ambient Clean.

What did **not** change:

- `hw/Pynq-Z2/block_design.tcl`, `topEntity` ports, `Frame` shape,
  GPIO address map, Python API, Notebook UI, or chain preset structure.
- Delay implementation from `feature/bram-delay-500ms` was not mixed
  in; `axi_gpio_delay_line` is absent and legacy `axi_gpio_delay`
  remains present.
- Compressor / Noise Suppressor / Overdrive / Distortion Pedalboard /
  Cab IR / EQ / Reverb voicings were not retuned in this pass.
- No C++ DSP prototype, commercial amp circuit/IR/coefficients, GPL
  code, analysis tool, or test-signal generator was added.

## Amp Simulator named models (this branch, `feature/audio-analysis-voicing-fixes`)

Four named amp voicings (`jc_clean` / `clean_combo` / `british_crunch`
/ `high_gain_stack`) were layered onto the existing
`amp_character` knob. The Python side adds an
`AMP_MODELS` table plus `get_amp_model_names`,
`amp_model_to_character`, and `set_amp_model` convenience helpers; the
numeric `amp_character` argument still works directly. The Clash side
quantises the same character byte into a two-bit `ampModelSel` index
and applies a small extra darken to the post-clip pre-LPF for the
higher-gain bands so high-gain pedals into the amp do not produce a
second brightening on top of the audio-analysis pass. **No new GPIO,
no new `topEntity` port, no `block_design.tcl` change**, no `Frame`
field added; only one cheap helper and one alpha bias.

What landed:

- `hw/ip/clash/src/LowPassFir.hs`: new `ampModelSel :: Unsigned 8 ->
  Unsigned 2` helper, and `ampPreLowpassFrame` subtracts a
  per-model darken (0 / 2 / 8 / 16) from the existing
  `baseAlpha = 128 + (charByte >> 2)`. Bands match the documented
  Python ranges (character 0..24 / 25..49 / 50..74 / 75..100).
- `audio_lab_pynq/effect_defaults.py`: `AMP_MODELS = {jc_clean: 10,
  clean_combo: 35, british_crunch: 60, high_gain_stack: 85}`.
- `audio_lab_pynq/AudioLabOverlay.py`: `AMP_MODELS` class attr,
  `get_amp_model_names()`, `amp_model_to_character(name)`,
  `set_amp_model(name, **overrides)` convenience method.
- `audio_lab_pynq/notebooks/GuitarPedalboardOneCell.ipynb`: Amp
  Model dropdown above the Character slider; selection writes the
  matching centre value into the slider so the chain-preset/safe-
  bypass logic stays untouched. Inline fallback `AMP_MODELS` mirrors
  the package values byte-for-byte.
- `tests/test_overlay_controls.py`: anchor / table-shape / mapping
  / per-model byte-distinctness / overrides tests.
- `hw/ip/clash/vhdl/LowPassFir/*`: regenerated VHDL + repackaged IP.
- `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}`: rebuilt; final routed
  timing recorded in `TIMING_AND_FPGA_NOTES.md`.

What did **not** change:

- `block_design.tcl`, `topEntity` port list, `Frame` shape.
- Existing `amp_character` API surface; the convenience helpers
  share the same byte and write through `set_guitar_effects`.
- The audio-analysis voicing fixes (the cap on the post-clip pre-LPF
  is preserved; the model-specific darken sits on top).
- Cab IR / Compressor / Overdrive / Distortion Pedalboard / EQ /
  Reverb voicings (untouched in this pass).

## Audio-analysis voicing fixes (prior arc on this branch)

Recording analysis of Bypass / NoiseSuppressor / Compressor /
Overdrive / DS-1 / AmpSim / Cabinet / Reverb showed four actionable
voicing gaps: AmpSim had too much >5 kHz fizz, Cabinet roll-off was
directionally right but still weak after high-gain pedals, Overdrive
was nearly indistinguishable from Bypass, and Compressor crest factor
barely moved. The findings are recorded in
`docs/ai_context/AUDIO_RECORDING_ANALYSIS.md`.

This pass is **not** a new effect. It retunes only existing
`LowPassFir.hs` stages and keeps the fixed GPIO contract intact:
no new AXI GPIO, no new `topEntity` port, no `block_design.tcl`
change, no AXI address change, and no Python API / Notebook UI
surface change.

What landed:

- `hw/ip/clash/src/LowPassFir.hs`:
  - Compressor: `compThresholdSample`, `compEnvNext`,
    `compTargetGain`, and `compGainNext` now start compression a bit
    earlier and react a little faster while preserving the makeup
    safety contract.
  - Overdrive: `overdriveDriveMultiplyFrame` has a stronger midrange
    drive curve, `overdriveDriveClipFrame` uses lower asymmetric knees,
    and `overdriveLevelFrame` adds a lower output safety `softClipK`.
  - Amp: `ampDriveMultiplyFrame`, `ampPreLowpassFrame`,
    `ampToneProductsFrame` / `ampTrebleGain`, `ampPowerFrame`,
    `ampResPresenceProductsFrame` / `ampResPresenceMixFrame`, and
    `ampMasterFrame` were retuned to reduce painful high-end fizz and
    keep MASTER / presence / treble from slamming later stages.
  - Cab: `cabCoeff` was rebuilt again so model 0 / 1 / 2 are more
    clearly separated. Model 2 is now the darkest 4x12-style setting
    for DS-1 / RAT / Big Muff / Fuzz / Metal. `cabLevelMixFrame`
    keeps the existing timing-friendly `softClip`; a lower
    `softClipK 3_400_000` trial was rejected after timing slipped too
    far.
- `audio_lab_pynq/effect_presets.py`:
  - DS-1 Crunch now leans on Cab model 2 with capped `air`.
  - Safe Bypass remains all-off, Compressor makeup stays in 45..60,
    and Distortion levels stay <= 35.
- `tests/test_overlay_controls.py`:
  - Added Overdrive enable-word sanity coverage and high-gain Cab
    model-2 safety coverage for the chain presets.
- `scripts/analyze_effect_recordings.py`:
  - Added a lightweight WAV analysis script that regenerates the nine
    comparison views used for this pass.
- `hw/ip/clash/vhdl/LowPassFir/*` was regenerated and the Vivado IP
  repackaged.
- `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}` was rebuilt and deployed.
  Final routed timing: WNS = -8.731 ns, TNS = -13665.555 ns,
  WHS = +0.051 ns, THS = 0.000 ns. This regresses WNS by 0.814 ns vs
  the previous deployed Amp/Cab build's -7.917 ns, still inside the
  accepted -6..-9 ns deploy band; hold remains clean.
- PYNQ-Z2 deploy completed with
  `PYNQ_HOST=192.168.1.9 bash scripts/deploy_to_pynq.sh`.
  Smoke test loaded `AudioLabOverlay`, confirmed `ADC HPF: True`,
  `R19_ADC_CONTROL = 0x23`, found both Compressor and Noise Suppressor
  GPIOs, applied Overdrive and Compressor sanity settings, and applied
  all chain presets.
- The requested practical check sequence was applied on the board
  (Safe Bypass, Basic Clean, Light Crunch, Overdrive standalone,
  Compressor standalone, Tube Screamer Lead, DS-1 Crunch, RAT Rhythm,
  Big Muff Sustain, Vintage Fuzz, Metal Tight, Ambient Clean). The
  terminal session can verify preset application, not subjective
  loudspeaker / headphone listening.

What did **not** change:

- `hw/Pynq-Z2/block_design.tcl`.
- `topEntity` port list.
- GPIO names, addresses, or `ctrlA` / `ctrlB` / `ctrlC` / `ctrlD`
  meanings.
- Python API method names or Notebook UI structure.
- C++ DSP prototypes (`src/effects` remains removed).
- Commercial amp / cabinet IR / pedal circuit constants or GPL code.

## Amp/Cab real-voicing pass (this branch, `feature/amp-cab-real-voicing`)

The existing Amp Simulator and Cab IR stages were re-voiced toward a
generic guitar amp / cabinet response. This is **not** a new effect:
no new GPIO, no new `topEntity` port, no `block_design.tcl` change,
and no AXI address change. The work only changes constants / clip
helpers inside existing `LowPassFir.hs` stages plus a small chain
preset retune.

What landed:

- `hw/ip/clash/src/LowPassFir.hs`:
  - `ampHighpassFrame`: feedback coefficient `254 -> 253`, tightening
    sub-low rumble before the gain stages.
  - `ampDriveMultiplyFrame`: input gain ceiling reduced from ~31x to
    ~21x so high-gain pedals do not get squared again by the amp.
  - `ampAsymClip`, `ampPreLowpassFrame`, `ampSecondStageMultiplyFrame`:
    lower clip knees, darker pre-LPF range, and a slightly more
    character-driven second stage for clean / crunch / high-gain
    response separation.
  - `ampPowerFrame`, `ampResPresenceMixFrame`, `ampMasterFrame`: safety
    `softClipK` knees lowered so MASTER / presence / resonance cannot
    blow the post-amp chain into hard clipping.
  - `ampResPresenceProductsFrame`: presence capped to 75 % of the byte
    and resonance to 87.5 %, keeping high-end bite and low-end push
    without ice-pick highs or low-frequency bloom.
  - `cabCoeff`: the existing 4-tap cabinet table was rebuilt into
    three clearer models:
    - model 0: 1x12 open back style, lighter body, more open mid/air.
    - model 1: 2x12 combo style, balanced roll-off with presence left.
    - model 2: 4x12 closed back style, more delayed-body taps and the
      strongest fizz damping for Metal / Big Muff / Fuzz Face.
    `air` now restores only a capped direct-tap amount; `air=100` does
    not return to raw line-direct sound.
- `audio_lab_pynq/effect_presets.py`:
  - Basic Clean / Clean Sustain now use mild Amp + model 0 Cab.
  - Light Crunch uses model 0 Cab.
  - Metal / Noise Controlled High Gain use lower presence and model 2
    Cab with lower air.
  - Big Muff Sustain and Vintage Fuzz now lean on model 2 Cab; Vintage
    Fuzz keeps `mix=90` so it stays rawer than Metal.
- `hw/ip/clash/vhdl/LowPassFir/*` was regenerated and the Vivado IP
  repackaged.
- `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}` was rebuilt and deployed.
  Final routed timing: WNS = -7.917 ns, TNS = -13100.457 ns,
  WHS = +0.051 ns, THS = 0.000 ns. This regresses WNS by 0.382 ns vs
  the reserved-pedal build's -7.535 ns, still inside the -7..-9 ns
  deploy band; hold remains clean.
- PYNQ-Z2 deploy completed. Smoke test passed over Safe Bypass, Basic
  Clean, Light Crunch, Tube Screamer Lead, RAT Rhythm, DS-1 Crunch,
  Big Muff Sustain, Vintage Fuzz, Metal Tight, and Ambient Clean.
  `ADC HPF: True`; `R19_ADC_CONTROL = 0x23`.

What did **not** change:

- `hw/Pynq-Z2/block_design.tcl`.
- `topEntity` port list.
- GPIO names, addresses, or `ctrlA` / `ctrlB` / `ctrlC` / `ctrlD`
  meanings for `axi_gpio_amp`, `axi_gpio_amp_tone`, or `axi_gpio_cab`.
- Python API method names or Notebook UI structure.
- C++ DSP prototypes (`src/effects` remains removed).
- Commercial amp / cabinet IR / schematic coefficient copies or GPL
  code. The voicing is generic and hand-rolled.

## Reserved-pedal implementation (this branch, `feature/add-reserved-distortion-pedals`)

The three previously-reserved distortion pedals (`ds1` bit 3,
`big_muff` bit 4, `fuzz_face` bit 5) now have working Clash stages
in the deployed bitstream, slotting into the existing pedal-mask
pipeline alongside `clean_boost` / `tube_screamer` / `metal`. No
new GPIO, no new `topEntity` port, no `block_design.tcl` change.
Bit 7 of the pedal mask remains the only reserved slot, held for a
future 8th pedal.

What landed:

- `hw/ip/clash/src/LowPassFir.hs` -- three new pedal sections:
  - `ds1`: 5-stage chain (HPF -> mul -> asym soft clip with low
    knees -> post LPF -> level+safety). Voicing aim: BOSS DS-1
    style edgy crunch, brighter than tube_screamer.
  - `big_muff`: 5-stage chain (pre-gain ~1.5x..~13x -> softClipK
    medium knee -> softClipK tighter knee with ~0.75x gain ->
    tone LPF -> level+safety). Voicing aim: Big Muff Pi style
    thick fuzz with cascaded soft clip and a darker top end.
  - `fuzz_face`: 4-stage chain (pre-gain ~2x..~10x -> strong
    asymSoftClip with low/asymmetric knees -> tone LPF -> level+
    safety). Voicing aim: Fuzz Face style raw asymmetric breakup,
    "round vs. bright" tone axis.
  - `ds1On` / `bigMuffOn` / `fuzzFaceOn` predicates wired into
    `fxPipeline` between `metalLevelPipe` and `distortionPedalsPipe`.
  - `distortionPedalsPipe = fuzzFaceLevelPipe` (the new last stage
    of the per-pedal section).
- `audio_lab_pynq/effect_defaults.py` --
  `DISTORTION_PEDALS_IMPLEMENTED` now lists all seven pedal names.
- `audio_lab_pynq/effect_presets.py` -- six new
  `DISTORTION_PRESETS` entries (DS-1 Crunch / DS-1 Lead / Big Muff
  Sustain / Big Muff Wall / Fuzz Face / Fuzz Face Vintage), three
  new `CHAIN_PRESETS` entries (DS-1 Crunch / Big Muff Sustain /
  Vintage Fuzz). Every new preset keeps distortion `level <= 35`
  and compressor `makeup` in the 45..60 band so the safety
  contract (`DECISIONS.md` D15) holds.
- `audio_lab_pynq/AudioLabOverlay.py` -- bit-position docstring
  promoted from "reserved" to "implemented" for bits 3-5; no API
  surface change.
- `audio_lab_pynq/notebooks/GuitarPedalboardOneCell.ipynb` --
  Distortion Pedalboard dropdown / SelectMultiple now expose plain
  `ds1` / `big_muff` / `fuzz_face` entries; the legacy
  `*_reserved` labels stay in `PEDAL_LABEL_TO_API` as backward-
  compatible aliases (also resolve to the implemented pedals).
  Reserved-pedal warning banner removed (RESERVED_PEDALS = empty
  set). Preset row split across two HBoxes since the new pedals
  doubled the button count. Fallback inline `PRESETS` /
  `CHAIN_PRESETS_INLINE` updated.
- `audio_lab_pynq/notebooks/DistortionModelsDebug.ipynb` --
  pedal list table updated to mark bits 3-5 as implemented and
  describe the voicing target. Live cell comment lists the new
  pedal names. Stack-mode comment updated for the new chain order.
- `audio_lab_pynq/notebooks/GuitarEffectSwitcher.ipynb` --
  pedalboard section text updated to mark all seven slots as
  implemented; three new preset cells (DS-1 Crunch / Big Muff
  Sustain / Fuzz Face) added after the Metal Tight cell.
- `tests/test_overlay_controls.py` -- new tests:
  `DISTORTION_PEDALS_IMPLEMENTED` shape, exclusive sets for ds1 /
  big_muff / fuzz_face, mask bit 7 stays unused, new presets
  satisfy the level cap, three new chain presets exist with the
  expected pedal name and the makeup/level contract.
- `hw/ip/clash/vhdl/LowPassFir/*` -- regenerated VHDL +
  repackaged IP (no `topEntity` port change; new pedal stages
  appear inside the existing module).

Hardware:

- `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}` -- rebuilt. Final
  routed timing recorded in `TIMING_AND_FPGA_NOTES.md`.
- PYNQ-Z2 deploy + smoke test recorded once the build completes.

What did **not** change:

- `block_design.tcl` (GPIO inventory, addresses, AXI interconnect).
  No new GPIO; no new master count.
- `topEntity` port list of `LowPassFir.hs`.
- `gate_control.ctrlA` flag byte semantics; the section still rides
  on bit 2 (legacy `distortion_on`).
- Existing `clean_boost` / `tube_screamer` / `rat` / `metal`
  voicing -- the new pedals slot in *after* the existing chain so
  none of the prior-build register stages were edited.
- Reserved bytes / bits other than the now-implemented bits 3-5
  (`axi_gpio_eq.ctrlD`, `axi_gpio_noise_suppressor.ctrlD`,
  `axi_gpio_distortion.ctrlD[7]` all stay reserved).
- Existing public Python API surface; chain preset names, byte
  caps, and Safe Bypass shape (existing tests pass byte-for-byte).
- C++ DSP prototypes (still removed, `DECISIONS.md` D13).

---

## Real-pedal voicing pass (prior branch, `feature/real-pedal-voicing-pass`)

Existing effect stages were re-tuned to be closer to recognised
real-pedal voicings, using only the existing GPIOs and `topEntity`
ports. No new effect stage, no new register, no `block_design.tcl`
change. The deployed bit/hwh was rebuilt from the new
`LowPassFir.hs` and pushed to the board.

What landed:

- `hw/ip/clash/src/LowPassFir.hs` -- voicing changes inside the
  existing register stages:
  - **Overdrive**: symmetric `softClip` -> `asymSoftClip` (tube-style
    even-harmonic content).
  - **clean_boost**: drive ceiling lowered from ~5x to ~4x;
    `cleanBoostLevelFrame` safety knee dropped from ~4.2M to ~3.2M.
  - **tube_screamer**: pre-HPF alpha range bumped (3..18), drive
    ceiling lowered (~7x vs. ~9x), asym clip knees dropped to
    `2_900_000 / 2_500_000`, post-LPF range shifted to
    `64..191` (darker top end at every TONE setting).
  - **RAT**: hard-clip floor lowered to `2_500_000` (more aggressive
    at high DRIVE), `ratPostLowpassFrame` alpha 192 -> 176, tone alpha
    base 224 -> 200.
  - **metal**: HPF alpha range bumped (6..37), drive ceiling lowered
    (~19x vs. ~22x), clip floor raised to `1_500_000`, post-LPF range
    shifted to `48..175` (darker top).
  - **Compressor**: soft-knee offset (`softThreshold = threshold -
    (threshold >> 4)`), gentler reduction slope (`excess >> 12` vs.
    `>> 11`).
  - **Noise Suppressor**: threshold hysteresis -- `closeT = threshold
    - (threshold >> 2)`, mid-gain check on the gain register decides
    the in-band region (no chatter).
  - **Cab IR**: 4-tap coefficient table re-balanced -- c0 reduced,
    c1/c2 increased -- so the very-high frequencies (close to
    Nyquist) are damped more.
  - **Reverb**: tone byte scaled (`tone - tone >> 3`) so TONE=100
    still keeps ~12.5 % damping in the recirculation path.
  - **EQ**: post-EQ mix wrapped in `softClip` so a max-boost on all
    three bands saturates softly instead of slamming the saturator.
- `docs/ai_context/REAL_PEDAL_VOICING_TARGETS.md` (new) -- per-effect
  reference style, current implementation, gap, plan, risk, and
  listening points.
- `docs/ai_context/DECISIONS.md` D16 -- recorded the constraints of
  the voicing pass.
- `docs/ai_context/DSP_EFFECT_CHAIN.md`,
  `docs/ai_context/TIMING_AND_FPGA_NOTES.md`,
  `docs/ai_context/RESUME_PROMPTS.md`, `README.md` -- updated.
- `hw/ip/clash/vhdl/LowPassFir/*` -- regenerated VHDL + repackaged IP.
- `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}` -- rebuilt. Final
  routed timing: WNS = -6.405 ns, TNS = -8806.714 ns,
  WHS = +0.052 ns, THS = 0.000 ns. **Improves on the deployed
  Compressor build's WNS (-7.516 ns) by 1.111 ns**; hold remains
  clean.
- PYNQ-Z2 deploy: completed; smoke test (`apply_chain_preset` over
  all 10 presets) passes, `R19_ADC_CONTROL = 0x23`, ADC HPF default-on
  preserved.

What did **not** change:

- `block_design.tcl` (GPIO inventory, addresses, AXI interconnect).
- `topEntity` port list of `LowPassFir.hs`.
- `gate_control.ctrlA` flag byte semantics.
- `axi_gpio_compressor` / `axi_gpio_noise_suppressor` enable
  semantics.
- Reserved bytes / bits (`axi_gpio_eq.ctrlD`,
  `axi_gpio_noise_suppressor.ctrlD`,
  `axi_gpio_distortion.ctrlD[3..5,7]`).
- Existing public Python API surface; chain preset names, byte caps,
  and Safe Bypass shape (no `effect_presets.py` change).
- C++ DSP prototypes (still removed, `DECISIONS.md` D13).

---

## Chain presets (prior branch, `feature/pedalboard-quality-presets`)

Ten named pedalboard voicings (Safe Bypass / Basic Clean / Clean
Sustain / Light Crunch / Tube Screamer Lead / RAT Rhythm / Metal
Tight / Ambient Clean / Solo Boost / Noise Controlled High Gain)
combine every section of the chain (Compressor + Noise Suppressor
+ Overdrive + Distortion Pedalboard + Amp + Cab IR + EQ + Reverb)
into one named state. Compressor `makeup` is held at 45..60 and
Distortion `level` is capped at 35 across every preset, so a click
on the wrong preset cannot blow the chain into clipping.

What landed:

- `audio_lab_pynq/effect_presets.py` -- `CHAIN_PRESETS` dict-of-dicts
  plus `CHAIN_PRESET_SECTIONS` canonical section list.
- `audio_lab_pynq/AudioLabOverlay.py` -- `apply_chain_preset`,
  `get_chain_preset_names`, `get_chain_preset`,
  `get_current_pedalboard_state`. Robust to missing GPIOs (older
  bitstream without `axi_gpio_compressor` still applies the rest).
- `audio_lab_pynq/notebooks/GuitarPedalboardOneCell.ipynb` -- new
  Chain Preset dropdown + Apply Chain Preset / Show Current State
  buttons; existing accordion / Apply / Safe Bypass / Refresh kept
  intact. Two-cell layout preserved. Inline `CHAIN_PRESETS_INLINE`
  fallback for older deployed packages.
- `tests/test_overlay_controls.py` -- chain preset shape /
  Safe-Bypass-off-everywhere / makeup-band / distortion-level-cap /
  apply round-trip / unknown-name / missing-GPIO survival tests.
- `README.md`, `docs/ai_context/*.md` -- this file plus DSP_EFFECT_CHAIN
  / DECISIONS (new D15) / EFFECT_ADDING_GUIDE / RESUME_PROMPTS.

What did **not** change:

- Hardware (`block_design.tcl`, `LowPassFir.hs`, IP packaging,
  bitstream / hwh). The deployed Compressor build (`d216a9c`) is
  unchanged.
- Existing GPIO names, addresses, or ctrlA / B / C / D meanings.
- Compressor / Noise Suppressor / Distortion / amp / cab / eq /
  reverb DSP behaviour.
- Existing public Python API surface
  (every `set_*_settings` / `set_guitar_effects` keyword still
  works the same).

Vivado / Clash were **not** run. No timing review needed.

---


## Compressor add (this branch, `feature/compressor-effect`)

A new stereo-linked feed-forward peak compressor section was added on
its own AXI GPIO. Sits between the noise suppressor and the overdrive
in the Clash pipeline. Enable flag lives inside the new GPIO; the
master flag byte (`gate_control.ctrlA`) was not touched.

What landed:

- `hw/Pynq-Z2/block_design.tcl` -- new `axi_gpio_compressor` IP at
  `0x43CD0000`, `NUM_MI` bumped from 14 to 15, M14_AXI / M14_ACLK /
  M14_ARESETN wired, address segment added.
- `hw/ip/clash/src/LowPassFir.hs` -- new `compressor_control` port,
  `fComp` field on `Frame`, `compEnvNext` / `compTargetGain` /
  `compGainNext` / `compApplyFrame` / `compMakeupFrame` helpers, and
  the `compLevelPipe -> compEnv -> compGain -> compApplyPipe ->
  compMakeupPipe` block in `fxPipeline` between the noise suppressor
  and the overdrive.
- `audio_lab_pynq/control_maps.py` -- `makeup_to_u7`,
  `compressor_enable_makeup_byte`, `compressor_word` helpers.
- `audio_lab_pynq/effect_defaults.py` -- `COMPRESSOR_DEFAULTS`
  (`enabled=False, threshold=45, ratio=35, response=45, makeup=50`).
- `audio_lab_pynq/effect_presets.py` -- `COMPRESSOR_PRESETS`
  (Comp Off / Light Sustain / Funk Tight / Lead Sustain / Limiter-ish).
- `audio_lab_pynq/AudioLabOverlay.py` -- `axi_gpio_compressor`
  attribute, `_compressor_state` cache, `_apply_compressor_state_to_word`,
  `set_compressor_settings(threshold=, ratio=, response=, makeup=,
  enabled=)`, `get_compressor_settings()`, per-knob shortcuts.
- `audio_lab_pynq/notebooks/GuitarPedalboardOneCell.ipynb` -- new
  Compressor accordion section (THRESHOLD / RATIO / RESPONSE /
  MAKEUP sliders + 5 presets); `apply_settings` / `safe_bypass` /
  `refresh_status` updated; chain header includes Compressor.
- `tests/test_overlay_controls.py` -- compressor encoding /
  round-trip / clamp / preset snapshot tests; defaults sanity test.
- `docs/ai_context/*.md` and `README.md` -- this file plus
  GPIO_CONTROL_MAP / DSP_EFFECT_CHAIN / DECISIONS (new D14) /
  BUILD_AND_DEPLOY / EFFECT_ADDING_GUIDE / RESUME_PROMPTS / TIMING.
- `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}` -- rebuilt with the
  new GPIO and DSP block. Final routed timing: WNS=-7.516 ns,
  TNS=-8815.426 ns, WHS=+0.052 ns, THS=0.000 ns. Regresses 0.405 ns
  vs the noise-suppressor build's `-7.111 ns`; still inside the
  historical deploy band.

What did **not** change:

- Existing GPIO names, addresses, or ctrlA / B / C / D meanings.
- Noise Suppressor stage, distortion pedal-mask, RAT, amp / cab / EQ /
  reverb stages.
- The pedal-mask shape from `baa97ff`.
- Existing public Python API surface (every `set_*_settings` /
  `set_guitar_effects` keyword still works the same).

---


## Effect-chain refactor (this branch, `feature/effect-chain-refactor`)

The Python control layer was split into smaller modules, the GPIO
inventory was promoted to a fixed ledger, the C++ DSP prototypes were
removed, and a new effect-adding guide / template were added. **No GPIO
re-allocation, no Clash change, no Vivado / bit / hwh rebuild.** The
deployed bitstream is unchanged.

What landed:

- `audio_lab_pynq/control_maps.py` — pack / unpack / clamp helpers (single
  source of truth for byte encoding).
- `audio_lab_pynq/effect_defaults.py` — per-effect default dicts; the
  legacy class attributes (`AudioLabOverlay.DISTORTION_DEFAULTS`,
  `NOISE_SUPPRESSOR_DEFAULTS`, `DISTORTION_PEDALS`,
  `DISTORTION_PEDALS_IMPLEMENTED`) are re-exported from here.
- `audio_lab_pynq/effect_presets.py` — Notebook + API presets;
  `DISTORTION_PRESETS`, `NOISE_SUPPRESSOR_PRESETS`. The notebook
  imports these with an inline fallback.
- `AudioLabOverlay.py` — the legacy classmethods (`_clamp_percent`,
  `_percent_to_u8`, `_level_to_q7`, `_pack3`, `_pack4`,
  `_noise_threshold_to_u8`, `_noise_suppressor_word`) are now thin
  delegates to `control_maps`. **Every public API is unchanged.**
- `tests/test_overlay_controls.py` — added module-level tests for
  `control_maps` / `effect_defaults` / `effect_presets`, plus
  byte-for-byte snapshot tests covering every preset and the Safe
  Bypass shape so future refactors cannot silently change the bits.
- `docs/ai_context/GPIO_CONTROL_MAP.md` — promoted to a fixed
  inventory with `active / reserved / legacy mirror / unused /
  deprecated` status per byte and an explicit "do not repurpose"
  rule set.
- `docs/ai_context/EFFECT_ADDING_GUIDE.md` (new) — decision flow,
  Clash rules, Python rules, notebook rules, deploy checklist.
- `docs/ai_context/EFFECT_STAGE_TEMPLATE.md` (new) — fillable spec
  sheet for new effects.
- `audio_lab_pynq/notebooks/GuitarPedalboardOneCell.ipynb` — pulled
  presets from `effect_presets.py` (with inline fallback for older
  deployed packages); introduced `make_slider` / `make_section`
  helpers; split `apply_settings` into
  `apply_distortion_settings` / `apply_noise_suppressor_settings` /
  `apply_chain_settings`. Two-cell layout, Apply-button discipline,
  and visual structure are unchanged.
- `src/effects/` — **removed.** The C++ DSP prototypes were never on
  the live PL path; keeping them around invited the "implement in
  C++ then port" pattern that this project does not follow. See
  `DECISIONS.md` D12. `make tests` now runs Python tests only.

What did **not** change:

- GPIO names, addresses, and ctrlA / ctrlB / ctrlC / ctrlD assignments.
- `block_design.tcl`, `LowPassFir.hs` (DSP source), VHDL, IP packaging.
- `audio_lab.bit` / `audio_lab.hwh`. Timing baseline (WNS = -7.111 ns,
  WHS = +0.053 ns, THS = 0.000 ns) is unaffected — no rebuild was
  performed.
- Any audible behaviour. Snapshot tests guarantee the bits sent to
  the FPGA match the previous deployed bitstream byte-for-byte.

## Headline

The reserved-pedal implementation is **shipped**. `ds1` (bit 3),
`big_muff` (bit 4), and `fuzz_face` (bit 5) of the pedal-mask scheme
now have working independent register-staged Clash blocks; the Python
API and notebook UIs treat them as first-class implemented pedals.
Bit 7 stays reserved for a future 8th pedal slot. No new GPIO, no
`topEntity` port, no `block_design.tcl` change.

Earlier shipped milestones (still active in the deployed bitstream):
the pedal-mask distortion refactor (`DECISIONS.md` D6), the noise-
suppressor refactor (`DECISIONS.md` D11), the compressor section
(`DECISIONS.md` D14), the chain-preset layer (`DECISIONS.md` D15),
and the real-pedal voicing pass (`DECISIONS.md` D16). The 8-way
`model_select` distortion attempt remains rejected (`DECISIONS.md` D6).

## Working tree

`feature/add-reserved-distortion-pedals` carries the reserved-pedal
implementation, tagged at the parent commit as
`before-add-reserved-distortion-pedals`. The branch is local-only;
nothing has been pushed.

The previous pedal-mask arc lives on `master`:

```
3f2137d  Update AI context docs after pedal-mask distortion deployment
2198873  Add one-cell guitar pedalboard notebook
e1bb313  Add distortion pedalboard controls to GuitarEffectSwitcher notebook
baa97ff  Refactor distortion models into pedal-style pipeline
```

The noise-suppressor branch touches:

- `hw/Pynq-Z2/block_design.tcl` -- new `axi_gpio_noise_suppressor` IP
  at `0x43CC0000`, `NUM_MI` bumped to 14.
- `hw/ip/clash/src/LowPassFir.hs` -- new `noise_suppressor_control`
  port, `fNs` field on `Frame`, `nsEnvNext` / `nsGainNext` /
  `nsApplyFrame` / helpers, pipeline wiring updated.
- `hw/ip/clash/vhdl/LowPassFir/*` -- regenerated VHDL + repackaged IP.
- `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}` -- rebuilt with the new
  GPIO and DSP block.
- `audio_lab_pynq/AudioLabOverlay.py` -- `NOISE_SUPPRESSOR_*`
  constants, `_noise_threshold_to_u8`, `set_/get_noise_suppressor_*`,
  `_apply_noise_suppressor_state_to_word`, `set_guitar_effects`
  mirrors threshold + on-flag into the new GPIO.
- `audio_lab_pynq/notebooks/GuitarPedalboardOneCell.ipynb` -- Noise
  Gate accordion replaced with Noise Suppressor section (THRESHOLD /
  DECAY / DAMP sliders + four NS presets); `apply_settings` /
  `safe_bypass` / `refresh_status` updated.
- `tests/test_overlay_controls.py` -- threshold scale anchors
  (0/10/50/100 -> 0/3/13/26), clamps, NS settings round trip, GPIO
  word packing, mirror-to-gate test, `set_guitar_effects` NS GPIO
  mirror.
- `docs/ai_context/*.md` -- this file plus GPIO map, DSP chain,
  decisions, build/deploy, project context, timing, resume prompts.

## What ships in the current bitstream

Pedal stages live between the existing RAT block and the amp /
cab / EQ / reverb tail of the pipeline. Master enable stays on
`gate_control` bit 2 (the existing `distortion_on`).

| Pedal | bit (`distortion_control.ctrlD`) | Status |
| --- | --- | --- |
| `clean_boost` | 0 | Clash stage implemented (3 register stages). |
| `tube_screamer` | 1 | Clash stage implemented (5 register stages). |
| `rat` | 2 | Mapped onto the existing RAT stage; Python forces `gate_control` bit 4 high when this bit is set. |
| `ds1` | 3 | Clash stage implemented (5 register stages; HPF -> mul -> asym soft clip -> post LPF -> level+safety). BOSS DS-1 style voicing. |
| `big_muff` | 4 | Clash stage implemented (5 register stages; pre-gain -> two cascaded soft clip stages -> tone LPF -> level+safety). Big Muff Pi style voicing. |
| `fuzz_face` | 5 | Clash stage implemented (4 register stages; pre-gain -> strong asym soft clip -> tone LPF -> level+safety). Fuzz Face style voicing. |
| `metal` | 6 | Clash stage implemented (5 register stages). |
| reserved | 7 | Unused; held for a future 8th pedal slot. |

Legacy distortion (the original `distortion_*` API and Clash stages)
still works: it gates on `distortion_legacyOn = flag2(fGate) AND
NOT anyDistPedalOn`. As soon as any pedal-mask bit is set, the
legacy stage steps aside.

## Live verification

Run on the board after deploy:

```
ADC HPF        : True
R19_ADC_CONTROL: 0x23
clean_boost    mask=0x01  drive=40 level=35
tube_screamer  mask=0x02  drive=40 level=35
rat            mask=0x04  drive=40 level=35
ds1            mask=0x08  drive=40 level=35
big_muff       mask=0x10  drive=40 level=35
fuzz_face      mask=0x20  drive=40 level=35
metal          mask=0x40  drive=40 level=35
cleared        mask=0x00
```

ADC HPF default-on (`R19_ADC_CONTROL = 0x23`) survives. Every pedal
mask bit lands at the documented position. `clear_distortion_pedals`
returns the section to zero.

## Vivado timing summary (deployed bit)

| Build | WNS | TNS | Verdict |
| --- | --- | --- | --- |
| Pre-refactor baseline | -7.722 ns | -4613.495 ns | Shipped, audio works in practice. |
| Rejected `model_select` | -15.067 ns | -7308.247 ns | Not deployed. |
| pedal-mask (initial) | -7.801 ns | -7381.742 ns | Deployed. |
| Noise suppressor add | -7.111 ns | -7683.480 ns | Deployed. |
| Compressor add | -7.516 ns | -8815.426 ns | Deployed. |
| Real-pedal voicing pass | -6.405 ns | -8806.714 ns | Deployed. |
| Reserved-pedal implementation | -7.535 ns | -11297.604 ns | Deployed. WNS regresses 1.130 ns vs voicing-pass build, still inside the historical -7..-9 ns band. |
| Amp/Cab real-voicing pass | -7.917 ns | -13100.457 ns | Deployed. WNS regresses 0.382 ns vs reserved-pedal build; hold clean. |
| **Audio-analysis voicing fixes (current)** | **-8.731 ns** | -13665.555 ns | Deployed. WNS regresses 0.814 ns vs Amp/Cab build; hold clean and still inside the accepted deploy band. |

Hold timing is fine (`WHS = +0.051 ns`, `THS = 0.000 ns`). Setup is
still slightly negative; not a regression versus the historical
deploy band, but the build is not formally clean. Treat any further
timing slip with suspicion. The full chronology (with per-build
notes) is in
[`TIMING_AND_FPGA_NOTES.md`](TIMING_AND_FPGA_NOTES.md).

## Notebooks

| Notebook | Status |
| --- | --- |
| `audio_lab_pynq/notebooks/InputDebug.ipynb` | Existing input-noise triage notebook, ADC HPF default-on aware. |
| `audio_lab_pynq/notebooks/GuitarEffectsChain.ipynb` | Existing chain UI. Untouched in this refactor. |
| `audio_lab_pynq/notebooks/GuitarEffectSwitcher.ipynb` | **Updated** for the reserved-pedal implementation: pedalboard section text marks all seven slots implemented; new DS-1 Crunch / Big Muff Sustain / Fuzz Face preset cells added after the Metal Tight cell. |
| `audio_lab_pynq/notebooks/DistortionModelsDebug.ipynb` | **Updated** for the reserved-pedal implementation: pedal table now marks bits 3-5 as implemented; live cell comment lists the new pedals; stack-mode comment mentions the updated chain order. |
| `audio_lab_pynq/notebooks/GuitarPedalboardOneCell.ipynb` | **Updated** for the reserved-pedal implementation: dropdown / SelectMultiple expose plain `ds1` / `big_muff` / `fuzz_face` entries (legacy `*_reserved` aliases kept for backward compat); reserved-pedal warning banner removed; preset row split into two HBoxes; fallback inline `PRESETS` / `CHAIN_PRESETS_INLINE` updated. |

All five notebooks are deployed under
`/home/xilinx/jupyter_notebooks/audio_lab/` on the board.

## What to do next

Open work, in roughly priority order:

1. **8th pedal slot.** Bit 7 of `distortion_control.ctrlD` is the
   only remaining reserved pedal slot. If a future voicing wants
   in, it lands there as a new register-staged Clash block
   following the same shape as the new `ds1` / `big_muff` /
   `fuzz_face` stages.
2. **Drive WNS toward 0.** The deployed build is at the value
   recorded in `TIMING_AND_FPGA_NOTES.md`; the audio path
   tolerates the current band in practice but the build is not
   formally clean. Worth a pass that splits any remaining deeper
   combinational stage and / or pipelines the cab or reverb tap
   address paths.
3. **UI / preset polish** in the notebooks. Possible adds:
   per-pedal default presets, an A/B compare cell, a quick-record
   cell that pairs the pedalboard with the existing diagnostic
   capture helpers.
4. **Diagnostic capture for distortion stages.** Re-use
   `diagnostics.capture_input` to log a clip waveform per pedal so
   we can compare voicings without ear fatigue.

## Things to be careful about

- Do **not** silently revert the ADC HPF default-on. `R19_ADC_CONTROL`
  must read back as `0x23` after `config_codec()`.
- Do **not** reintroduce a single function with a `case` over all
  seven pedals. That is exactly what regressed timing the first time;
  see `TIMING_AND_FPGA_NOTES.md`.
- Do **not** deploy a bitstream whose WNS is significantly worse than
  the current audio-analysis voicing build's WNS (-8.731 ns) without
  flagging the regression first. A -15 ns-class result remains a hard
  reject.
- Do **not** revive the legacy `gateGainNext` / `gateFrame` registers
  in the active pipeline. The active gain stage is the noise
  suppressor (`nsApplyFrame`); the legacy helpers are kept as Haskell
  source for backward compatibility but are not wired up.
- Do **not** drop the legacy `gate_control.ctrlB` write from
  `set_guitar_effects` -- older bitstreams without
  `axi_gpio_noise_suppressor` still rely on it.
- Do **not** push, pull, or fetch.
