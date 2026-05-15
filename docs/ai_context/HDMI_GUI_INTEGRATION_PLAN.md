# HDMI GUI integration plan

This document records the design direction for showing the existing
`GUI/pynq_multi_fx_gui.py` rendering on the PYNQ-Z2 HDMI output without
breaking the current AudioLab DSP path.

Status: integrated Phase 4 implementation deployed, Phase 4C runtime
resource profile measured, Phase 4D small-LCD fit modes added, Phase 4E
800x480 logical GUI mode tested, Phase 4F manual viewport calibration
added, Phase 4G compact-v2 layout plus negative-offset placement added,
Phase 4H vertical safe margin + layout-debug overlay + vertical-only
offset sweep added, Phase 4I rolled the Phase 4H push-down +
positive-offset direction back to the Phase 4G compact-v2 baseline,
Phase 4J began a horizontal-only negative-offset sweep but was left
uncommitted, Phase 5A switched diagnosis to the HDMI output side, and
Phase 5C locks the user-confirmed top-left 800x480 visible viewport as
the default. The post-Phase-5C repo cleanup kept active `GUI/` code and
removed the unused untracked legacy `HDMI/` experiment tree after backup.
Phase 1 offscreen render benchmark, Phase 2A PYNQ compatibility, Phase 2B
static/change-driven render optimization, Phase 2C
AppState-to-`AudioLabOverlay` bridge planning, Phase 2D bridge runtime
test on the real deployed overlay, Phase 3 Vivado integration design,
Phase 4 integrated HDMI framebuffer build/deploy/smoke, and Phase 4C
static-frame/resource profiling, Phase 4D LCD safe-area fit testing,
Phase 4E logical-size testing, Phase 4F viewport calibration, Phase 4G
layout correction, Phase 4H vertical safe margin + horizontal layout
diagnosis, and Phase 4I compact-v2 baseline restore are complete.
Phase 4J's offset-side sweep is treated as superseded diagnostic
context, not as a completed default selection. Phase 4 implements
Option B (`axi_vdma` + `v_tc` +
`v_axi4s_vid_out` + Digilent `rgb2dvi`) in the AudioLab bitstream.
No `base.bit` load is used; runtime still loads exactly one
`AudioLabOverlay()`. See
`HDMI_GUI_PHASE1_RENDER_BENCH.md`,
`HDMI_GUI_PHASE2A_PYNQ_COMPAT.md`,
`HDMI_GUI_PHASE2B_RENDER_OPTIMIZATION.md`,
`HDMI_GUI_PHASE2C_BRIDGE_PLAN.md`,
`HDMI_GUI_PHASE2D_BRIDGE_RUNTIME_TEST.md`,
`HDMI_GUI_PHASE3_VIVADO_DESIGN_PROPOSAL.md`,
`HDMI_BLOCK_DESIGN_TCL_PATCH_PLAN.md`, and
`HDMI_GUI_PHASE4_IMPLEMENTATION_PROMPT_DRAFT.md`, and
`HDMI_GUI_PHASE4_IMPLEMENTATION_RESULT.md`,
`HDMI_GUI_PHASE4C_RESOURCE_PROFILE.md`,
`HDMI_GUI_PHASE4D_LCD_FIT_TEST.md`,
`HDMI_GUI_PHASE4E_800X480_LOGICAL_GUI.md`,
`HDMI_GUI_PHASE4F_VIEWPORT_CALIBRATION.md`,
`HDMI_GUI_PHASE4G_800X480_LAYOUT_CORRECTION.md`,
`HDMI_GUI_PHASE4H_VERTICAL_MARGIN_AND_LAYOUT_DIAGNOSIS.md`,
`HDMI_GUI_PHASE4I_RESTORE_COMPACT_V2_BASELINE.md`,
`HDMI_GUI_PHASE5A_OUTPUT_SIDE_DIAGNOSIS.md`, and
`HDMI_GUI_PHASE5B_NATIVE_800X480_TIMING_PLAN.md` for the
measured results, design, build, deploy, timing, smoke logs, runtime
resource profile, LCD fit test, 800x480 logical GUI result, viewport
calibration result, 800x480 compact-v2 layout correction, 800x480
vertical safe margin + horizontal layout diagnosis, 800x480
compact-v2 baseline restore, HDMI output-side diagnosis, and the
native 800x480 timing plan. Phase 5C's adopted runtime mode is the
existing 1280x720 HDMI signal with the 800x480 compact GUI at
framebuffer `x=0,y=0`.

## 1. Current state

### AudioLabOverlay and audio_lab.bit

The live audio system is loaded through `audio_lab_pynq.AudioLabOverlay`.
When constructed, it loads `audio_lab.bit` / `audio_lab.hwh`, configures
the ADAU1761 codec, and exposes the current audio routing and effect
control API.

The current `audio_lab.bit` owns the real-time DSP path:

- Line-in from the ADAU1761 enters the Zynq PL.
- The Clash-generated DSP block processes the guitar chain.
- AXI GPIOs drive effect enable flags and parameters.
- Audio returns to the ADAU1761 headphone / line output.

The current deployed `audio_lab.bit` contains a fixed 1280x720 HDMI
framebuffer output subsystem:

- `axi_vdma_hdmi` MM2S framebuffer scanout at `0x43CE0000`
- `v_tc_hdmi` timing generator at `0x43CF0000`
- `v_axi4s_vid_out_hdmi`
- Digilent `rgb2dvi_hdmi`
- `clk_wiz_hdmi`, `rst_video_0`, and `axi_smc_hdmi`

The HDMI Tcl is isolated in `hw/Pynq-Z2/hdmi_integration.tcl` and is
sourced by `create_project.tcl` after the existing audio block design.

Phase 4C re-ran the static-frame test and profiled the already-deployed
path without rebuilding or changing the bitstream. VDMA scanout started
from framebuffer `0x16900000` with HSIZE/STRIDE `3840`, VSIZE `720`,
`VDMACR=0x00010001`, and no VDMA error bits. The 60-second hold showed
that HDMI scanout itself does not busy-loop on the PS: process CPU
averaged `0.352%` and maxed at `0.418%` while VDMA held the frame.
Phase 5A/5C later confirmed physical output on the 5-inch LCD and
selected the framebuffer's top-left 800x480 region as the practical
visible viewport for that panel.

User visual inspection later confirmed that the small HDMI LCD does show
the GUI but crops the native frame. Phase 4D added Python-only fit modes
to `AudioLabHdmiBackend` so the GUI can be scaled and centered into a
safe area before the existing framebuffer copy:

- `native`: 1280x720, offset `(0,0)`.
- `fit-95`: 1216x684, offset `(32,18)`.
- `fit-90`: 1152x648, offset `(64,36)`.
- `fit-85`: 1088x612, offset `(96,54)`.
- `fit-80`: 1024x576, offset `(128,72)`.

The first small-LCD fit candidate was `fit-90`, but this path was later
superseded by the 800x480 logical GUI and Phase 5C's top-left
`x=0,y=0,w=800,h=480` visible viewport.

Phase 4E then added a real 800x480 logical GUI for the likely 5-inch
LCD instead of only shrinking the full 1280x720 layout. The HDMI signal
and VDMA stay 1280x720, but Python renders `[480,800,3]` and the backend
centers it in the framebuffer at offset `(240,120)`. This path completed
a 60-second PYNQ hold with no VDMA error bits and is the better basis for
future small-LCD UI work than shrinking the dense 1280x720 GUI.

User visual feedback then showed that the centered 800x480 placement
appears strongly right-shifted on the LCD. Phase 4F therefore added
manual logical placement (`placement="manual"`, `offset_x`, `offset_y`)
and a viewport calibration pattern. The HDMI signal remains 1280x720 and
VDMA/VTC settings are unchanged. Calibration and manual-offset GUI tests
for `(0,0)`, `(80,40)`, and `(120,60)` completed on the PYNQ-Z2 with no
VDMA error bits. The final offset is still a user visual decision.

Phase 4G then added a `compact-v2` 800x480 renderer and negative-offset
placement after Phase 4F's positive-offset sweep still left a left-side
blank strip on the LCD. The new renderer uses a 12 px outer margin,
2-3 px strokes, larger text, TL/TR/BL/BR corner markers, and a
variant + offset tag at the bottom edge so any photo identifies the
placement. `compose_logical_frame` now accepts negative offsets and
reports `negative_offset`, `clipped`, `fully_offscreen`, and the
un-clipped `requested_destination_region`.
`scripts/test_hdmi_800x480_cycle_offsets.py` walks the eight offsets
`(0,0)`, `(-80,0)`, `(-120,0)`, `(-160,0)`, `(-240,0)`, `(0,-40)`,
`(-120,-40)`, `(-160,-40)` for user photo comparison. All offsets ran
on the PYNQ-Z2 with no VDMA error bits and the bit/hwh on the board
were not modified.

Phase 4H then handled the residual top-edge clip and the left-strip
"invisible or unused" symptom. Horizontal is treated as a layout /
viewport diagnosis instead of an `offset_x` correction; `offset_x = 0`
remains the default. The compact-v2 outer chassis now starts at `y=30`
(was `y=12`), the inner panels use `x=18` left margin (was `x=24`),
the header band moves to `y=44..118`, the chain to `y=128..258`, the
bottom row to `y=268..458`, and a public `compact_v2_panel_boxes()`
helper exposes those rectangles. Two new diagnostic scripts run:
`scripts/test_hdmi_800x480_layout_debug.py` composites a 50 px grid,
panel bboxes, axis labels, and explicit LEFT STRIP / TOP STRIP bands
on top of the compact-v2 frame; and
`scripts/test_hdmi_800x480_vertical_offsets.py` keeps `offset_x = 0`
and walks `offset_y in {0, 10, 20, 30, 40, 50}`. All steps ran on the
PYNQ-Z2 with no VDMA error bits and the bit/hwh on the board were
not modified.

Phase 4I rolled the Phase 4H direction back. On the real 5-inch HDMI
LCD the chassis push-down to `y=30` plus the tighter `x=18` left
margin, paired with a positive-`offset_y` sweep recommendation, made
the layout shift down and to the right rather than fixing the
reported top-edge clip. The renderer was reverted to the Phase 4G
compact-v2 coordinates (outer `(12,12)..(788,468)` for 800x480,
panel `left` / `right` = `24`, header `(20, 100)`, chain
`(110, 250)`, bottom `(260, 454)`, FX / side divider at
`Wv // 2 +/- 8`, variant label at `Hv - 4`, cache key suffix back to
`compact_v2_800x480`, no inset safe-corner L-shapes). The diagnostic
scripts (`test_hdmi_800x480_layout_debug.py`,
`test_hdmi_800x480_vertical_offsets.py`) are kept only as archived
diagnostics with a banner / docstring stating the positive-`offset_y`
direction was rolled back. Recommended runtime placement remains
`--variant compact-v2 --placement manual --offset-x 0 --offset-y 0`.
No Vivado / bit / hwh / `block_design.tcl` / `audio_lab.xdc` /
`create_project.tcl` / Clash / DSP / `topEntity` / GPIO / HDMI IP /
VDMA / VTC change in Phase 4I.

Phase 4J began the residual horizontal-direction check. The user
reported that with Phase 4I deployed the vertical placement on the
5-inch HDMI LCD is correct, but the layout is shifted to the right
(right edge clipped, empty strip visible on the left). The dirty
Phase 4J files added a horizontal offset sweep, but the work stopped
before commit. Phase 5A backs up that dirty state and supersedes the
offset-side direction because the symptom now looks more like a
1280x720 HDMI timing / LCD scaler viewport mismatch than a Python
placement default.

Phase 5A therefore adds a 1280x720 output mapping pattern instead of
another offset test. `scripts/test_hdmi_output_mapping_720p.py` loads
`AudioLabOverlay()` once, draws a 50 px 720p coordinate grid with
800x480 candidate boxes, starts `AudioLabHdmiBackend`, prints VDMA/VTC
status, and holds the frame so the user can read visible x/y labels on
the physical LCD. The 60-second PYNQ run completed with no VDMA error
bits (`DMASR=0x00011000`, `vtc_ctl=0x00000006`). EDID was not
available through Linux DRM, and the
current XDC does not connect HDMI OUT DDC. Phase 5B native 800x480
timing is documented as the next implementation candidate, but it is
deferred until separately approved because it requires a Vivado rebuild,
fresh timing summary, and bit/hwh deploy decision.

Phase 5C records the user's visual conclusion from the output mapping
test: the `800x480 x0 y0` candidate box is perfectly positioned on the
5-inch LCD. The project now treats the top-left `800x480` region of the
fixed 1280x720 framebuffer as the default visible viewport for this
panel. The standard command is
`scripts/test_hdmi_800x480_frame.py --variant compact-v2 --placement
manual --offset-x 0 --offset-y 0 --hold-seconds 60`. Center placement
`(240,120)` and further positive/negative offset sweeps are not adopted
for normal operation on this LCD. Native 800x480 timing remains useful
as a future optimization or compatibility experiment, but it is no
longer required to achieve correct placement. The Phase 5C PYNQ run
completed with render `0.417 s`, compose `0.0254 s`, framebuffer copy
`0.2076 s`, copied region `x=0..800, y=0..480`,
`DMASR=0x00011000`, `vtc_ctl=0x00000006`, and no VDMA error bits.

The AudioLab control contract must remain intact:

- Keep existing `topEntity` ports and DSP pipeline behavior unless a
  separate DSP change explicitly requires otherwise.
- Keep existing GPIO names, addresses, and `ctrlA` / `ctrlB` /
  `ctrlC` / `ctrlD` semantics.
- Do not change `hw/Pynq-Z2/block_design.tcl` without explicit user
  approval.
- Do not rebuild or deploy a bitstream for documentation-only work.

### GUI/pynq_multi_fx_gui.py

`GUI/pynq_multi_fx_gui.py` is the best candidate for HDMI GUI reuse. It
is structured as a renderer plus optional desktop preview helpers:

- `AppState` holds GUI state such as selected effect, enabled effects,
  knobs, chain-preset label, model indices, meters, and animation time.
- `render_frame(state, width=1280, height=720)` returns a RGB
  `numpy.ndarray` shaped `(height, width, 3)` with `dtype=uint8`.
- The default rendering target is 1280x720 RGB, which matches the
  intended HDMI display resolution.
- The Tkinter path is only for desktop preview. Tk handles mouse /
  keyboard input; PIL and NumPy do the actual frame rendering.
- `run_pynq_hdmi(bitfile="base.bit", fps=5)` is a simple PYNQ HDMI hook,
  but it loads a separate overlay and is not safe for the live AudioLab
  DSP overlay.

The renderer can be preserved. The overlay-loading and HDMI backend must
be replaced before it can be used with the live audio DSP.

### Removed legacy HDMI/GUI.py

The former untracked `HDMI/GUI.py` was a separate Tkinter application.
Before removal, it was inspected and found to use:

- `tkinter.Canvas`
- `PIL.ImageTk`
- Windows monitor enumeration through `ctypes.windll.user32`
- Windows fullscreen / monitor selection assumptions
- image assets under the old `HDMI/assets`

This file was not a direct PYNQ HDMI solution. It was Windows-desktop GUI
code and could not drive the PYNQ-Z2 HDMI framebuffer directly. Current
live GUI work uses `GUI/pynq_multi_fx_gui.py`,
`GUI/audio_lab_gui_bridge.py`, and `audio_lab_pynq/hdmi_backend.py`.

It also contains effect names such as chorus, phaser, octaver, delay,
and bit-crusher style labels that do not match the current deployed
AudioLab DSP chain. Those must not be presented as live controllable
DSP effects unless corresponding FPGA stages exist.

### Removed legacy HDMI/FPGA/Vivado_project

The former untracked `HDMI/FPGA/Vivado_project` was not a completed HDMI
output design for AudioLab. The observed files described an older /
separate passthrough experiment:

- `passthrough.cpp` is a small AXI Stream HLS passthrough.
- `build_passthrough_bd.tcl` creates a PS7 + AXI DMA + passthrough block
  design.
- No HDMI output IP, video timing controller, VDMA-to-HDMI path, or
  PYNQ video subsystem equivalent was found in this directory.
- The design was not integrated with the current `hw/Pynq-Z2` AudioLab
  block design.

Repo-wide reference checks found no current deploy, test, or runtime
script dependency on the untracked `HDMI/` tree. It was backed up under
`/tmp/fpga_guitar_effecter_backup/` and removed from the working tree.
Do not reintroduce it as a HDMI solution.

### run_pynq_hdmi() problem

`GUI/pynq_multi_fx_gui.py` includes a `run_pynq_hdmi()` helper that does:

```python
base = Overlay(bitfile)
hdmi_out = base.video.hdmi_out
```

The default `bitfile` is `"base.bit"`. On PYNQ, loading this overlay
would replace the live AudioLab bitstream in the PL. That makes the
function unsuitable for the current goal.

## 2. Why the base.bit approach cannot be used

PYNQ full-bitstream overlays are mutually exclusive in normal use. The
PL holds one full design at a time. Loading another full overlay
reconfigures the PL.

Therefore:

- `AudioLabOverlay()` loads `audio_lab.bit`, which contains the current
  audio DSP path.
- `Overlay("base.bit")` loads the PYNQ base overlay, which contains its
  own video subsystem.
- Loading `base.bit` after `AudioLabOverlay()` removes the AudioLab DSP
  design from the PL.
- Loading `AudioLabOverlay()` after `base.bit` removes the base overlay
  video subsystem.

That means the existing `run_pynq_hdmi()` cannot be used for a live
AudioLab HDMI GUI. It would display graphics only by sacrificing the
current guitar-effect bitstream.

To keep the current audio functionality and add HDMI GUI output, the
audio DSP and the HDMI output path must live in one integrated bitstream.

## 3. Recommended architecture

The implemented architecture is a single integrated `audio_lab.bit`
containing both:

- the existing AudioLab audio DSP, codec routing, AXI Stream path, and
  effect-control GPIOs
- a HDMI video-output path capable of scanning out a framebuffer written
  by Python

The Python-side runtime should load only one overlay:

```text
AudioLabOverlay()
    |
    |-- existing audio codec / DSP / GPIO control
    |
    `-- integrated HDMI framebuffer output handle
```

The high-level runtime split should be:

- GUI renderer: keep `render_frame(state)` as the visual producer.
- HDMI backend: transfer the RGB ndarray into the integrated HDMI
  framebuffer.
- DSP bridge: translate GUI actions into `AudioLabOverlay` API calls.
- State model: keep visual `AppState` separate from hardware write
  throttling and overlay state synchronization.

At runtime:

1. Load `AudioLabOverlay()` once.
2. Create or obtain the integrated HDMI output handle from that overlay.
3. Build an `AppState` from safe defaults, the selected preset, or a
   cached GUI state file.
4. Render `rgb = render_frame(state)`.
5. Copy `rgb` into a HDMI framebuffer and submit it.
6. When the user changes a control, update `AppState` immediately for
   visual feedback.
7. Reflect changed controls into `AudioLabOverlay` only on change events
   or at a throttled control-rate, not every video frame.

This keeps the GUI drawing path independent from DSP control and reduces
the risk that rendering load or mouse interaction causes repeated GPIO
writes.

## 4. Likely Vivado architecture

The exact Vivado IP choices should be designed in a later phase, but the
integrated bitstream will likely need the following video pieces:

- AXI VDMA or a PYNQ-video-subsystem-equivalent framebuffer scanout path
- HDMI output IP appropriate for PYNQ-Z2
- video timing generation for 1280x720
- pixel clock / dynamic clocking as required by the chosen HDMI path
- AXI memory path from PS DDR to video scanout
- RGB framebuffer format compatible with the Python renderer

Implemented display format:

- Resolution: 1280x720
- GUI renderer output: RGB888 ndarray `[720,1280,3]` / `uint8`
- DDR framebuffer format: packed `GBR888`
- VDMA MM2S stream: 24-bit, HSIZE/STRIDE `3840`, VSIZE `720`
- Frame source: Python-generated NumPy / PIL frame copied to PS DDR
  framebuffer by `audio_lab_pynq.hdmi_backend.AudioLabHdmiBackend`

Measured Phase 4C update cost on the PYNQ-Z2:

- Cold render: `2.979 s`.
- Same-state cached render avg/p95: `0.00052 s` / `0.00217 s`.
- Change-driven render avg/p95: `0.276 s` / `0.280 s`.
- RGB888 -> DDR `GBR888` full-frame copy avg/p95:
  `0.206 s` / `0.206 s`.
- VDMA/VTC init + start: `0.0023 s`.
- Practical warm change-driven update rate: about `2.1 fps`.

Measured Phase 4D fit overhead:

- Pattern `fit-95`: resize/compose `0.289 s`, framebuffer copy
  `0.207 s`.
- Pattern `fit-90`: resize/compose `0.266 s`, framebuffer copy
  `0.207 s`.
- GUI `fit-90`: render `2.979 s`, resize/compose `0.265 s`,
  framebuffer copy `0.207 s`.

Fit mode does not alter VDMA HSIZE/STRIDE/VSIZE or the HDMI IP
configuration; it only changes the Python RGB frame before scanout.

Measured Phase 4E 800x480 logical mode cost:

- Render: `0.317 s`.
- Center compose into 1280x720: `0.026 s`.
- RGB888 -> DDR `GBR888` full-frame copy: `0.207 s`.
- Total content update: about `0.550 s`.

The renderer/compose work is much cheaper than the 1280x720 `fit-90`
path, but the current copy still swizzles the full 1280x720 framebuffer.
Partial copy of the 800x480 active region is the next obvious
optimization if update rate matters.

The integration must preserve the existing AudioLab design:

- Do not change the Clash `topEntity` interface just to add HDMI GUI.
- Do not reorder or retune the DSP pipeline.
- Do not rename or move existing AXI GPIOs.
- Do not change existing GPIO addresses.
- Do not repurpose reserved / legacy GPIO fields for HDMI.
- Do not touch codec configuration behavior, including ADC HPF default
  on.
- Keep existing notebooks and Python APIs working.

Any `hw/Pynq-Z2/block_design.tcl` change is a separate approved Vivado
task and must be followed by bit/hwh rebuild, timing summary, and PYNQ
smoke tests.

## 5. GUI-side migration plan

### Preserve the renderer

Keep `GUI/pynq_multi_fx_gui.py` rendering functions intact where
possible:

- `AppState`
- `render_frame()`
- `render_frame_800x480()`
- drawing helpers and render cache

The renderer already returns the correct RGB ndarray shape for a
framebuffer-style HDMI backend.

### Replace the HDMI backend

Do not use the current `run_pynq_hdmi()` overlay-loading behavior. In the
AudioLab integration path:

- `run_pynq_hdmi()` must not load `base.bit`.
- It must not call `Overlay("base.bit")`.
- It must not load any overlay after `AudioLabOverlay()`.
- The HDMI output object must come from the already-loaded integrated
  AudioLab overlay, or from a helper owned by that overlay.

In practice, a future implementation should add a new backend such as:

```text
AudioLabOverlay -> integrated HDMI output object -> writeframe(rgb)
```

rather than:

```text
Overlay("base.bit") -> base.video.hdmi_out -> writeframe(rgb)
```

### Add an AppState / AudioLabOverlay bridge

The GUI should not write GPIOs directly from draw functions. Add a bridge
layer that maps user-visible state to existing safe overlay APIs:

- GUI interaction updates `AppState`.
- Bridge computes the corresponding effect section settings.
- Bridge writes only changed sections.
- Bridge throttles continuous knob drags to a reasonable control rate.
- Bridge applies Safe Bypass through the existing safe API sequence.
- Bridge applies Chain Presets through `AudioLabOverlay.apply_chain_preset`
  when available.

Phase 2C added `GUI/audio_lab_gui_bridge.py` for this role. The bridge is
separate from rendering and defaults to dry-run planning. It only calls
the public `AudioLabOverlay` API when the caller explicitly passes an
already-loaded overlay with `dry_run=False`; it never instantiates
`AudioLabOverlay` and never loads a bitstream by itself.

Avoid writing effect GPIOs every video frame. A practical strategy is:

- immediate visual update every frame or at GUI FPS
- hardware update on button release, model/preset click, toggle click, or
  at a low control-rate during knob drag, such as 10 to 20 Hz

### Keep chain order honest

The current FPGA DSP order is fixed:

```text
Noise Suppressor -> Compressor -> Overdrive -> Distortion Pedalboard
-> Amp Simulator -> Cab IR -> EQ -> Reverb
```

`pynq_multi_fx_gui.py` currently supports chain-block drag reorder in the
visual state. The current hardware cannot reorder stages. Therefore a
live AudioLab HDMI GUI must choose one of these safe behaviors:

- disable chain drag reorder, or
- keep it display-only and clearly avoid applying it to hardware, or
- remove the drag handler from the live PYNQ mode while preserving it in
  desktop preview if useful.

The UI must not imply a hardware routing feature that does not exist.

### Remove or neutralize unsupported effects

The current live DSP chain does not include chorus, phaser, octaver,
bit-crusher, or a general delay effect. Assets and older GUI files may
show those labels, but the live HDMI GUI must not present them as
controllable effects.

If such labels are kept for future placeholders, they must be visibly
non-active / unsupported and must not write AudioLab GPIOs.

## 6. Control API mapping

This section maps the intended GUI sections to the current
`AudioLabOverlay` API surface.

### Noise Suppressor

GUI controls:

- enabled
- threshold
- decay
- damp

Overlay API:

- `set_noise_suppressor_settings(enabled=..., threshold=..., decay=..., damp=...)`
- `get_noise_suppressor_settings()`
- `set_guitar_effects(noise_gate_on=..., noise_gate_threshold=...)` still
  mirrors the enable / threshold into the legacy gate flag path.

Notes:

- Enable rides on `gate_control` bit 0 through the existing API.
- Dedicated GPIO is `axi_gpio_noise_suppressor`.

### Compressor

GUI controls:

- enabled
- threshold
- ratio
- response
- makeup

Overlay API:

- `set_compressor_settings(enabled=..., threshold=..., ratio=..., response=..., makeup=...)`
- `get_compressor_settings()`

Notes:

- Dedicated GPIO is `axi_gpio_compressor`.
- Enable lives in the compressor GPIO, not `gate_control.ctrlA`.

### Overdrive

GUI controls:

- enabled
- drive
- tone
- level

Overlay API:

- `set_guitar_effects(overdrive_on=..., overdrive_drive=..., overdrive_tone=..., overdrive_level=...)`

Notes:

- Overdrive shares the grouped `set_guitar_effects()` write path.

### Distortion Pedalboard

GUI controls:

- section enabled
- pedal selection
- optional stacked-pedal advanced mode
- drive
- tone
- level
- bias
- tight
- mix

Overlay API:

- `set_distortion_settings(pedal=..., exclusive=..., drive=..., tone=..., level=..., bias=..., tight=..., mix=...)`
- `set_distortion_pedal(name, enabled=True, exclusive=True)`
- `set_distortion_pedals(**pedal_flags)`
- `clear_distortion_pedals()`
- `set_guitar_effects(distortion_on=...)` for the section master flag

Supported pedals:

- `clean_boost`
- `tube_screamer`
- `rat`
- `ds1`
- `big_muff`
- `fuzz_face`
- `metal`

Notes:

- The pedal-mask design must not be replaced by a numeric model-selector
  mux.
- Distortion level should preserve existing safety expectations from
  presets.

### RAT

RAT is exposed as the `rat` entry in the Distortion Pedalboard. The
Python facade maps the RAT pedal bit onto the legacy RAT stage by also
asserting the existing `rat_on` behavior.

GUI should treat RAT as one of the supported distortion pedals, not as a
separate new chain block.

### Amp

GUI controls:

- enabled
- input gain
- bass
- middle
- treble
- presence
- resonance
- master
- character or named amp model

Overlay API:

- `set_guitar_effects(amp_on=..., amp_input_gain=..., amp_bass=..., amp_middle=..., amp_treble=..., amp_presence=..., amp_resonance=..., amp_master=..., amp_character=...)`
- `set_amp_model(name, **overrides)` when selecting a named model
- `get_amp_model_names()`
- `amp_model_to_character(name)`

Notes:

- Named amp models are a convenience layer over `amp_character`.
- Do not add a new amp model GPIO.

### Cab

GUI controls:

- enabled
- mix
- level
- model
- air

Overlay API:

- `set_guitar_effects(cab_on=..., cab_mix=..., cab_level=..., cab_model=..., cab_air=...)`

Notes:

- Current hardware model range is `cab_model` 0..2.
- GUI labels must be reduced or mapped to the actual three models.
- Do not expose five cab models as live hardware choices unless the FPGA
  design is extended in a separate approved DSP change.

### EQ

GUI controls:

- enabled
- low
- mid
- high

Overlay API:

- `set_guitar_effects(eq_on=..., eq_low=..., eq_mid=..., eq_high=...)`

### Reverb

GUI controls:

- enabled
- decay
- tone
- mix

Overlay API:

- `set_guitar_effects(reverb_on=..., reverb_decay=..., reverb_tone=..., reverb_mix=...)`
- `set_reverb(...)` remains available for narrower legacy usage.

### Chain Preset

GUI controls:

- preset previous / next
- preset apply
- preset name / id display

Overlay API:

- `get_chain_preset_names()`
- `get_chain_preset(name)`
- `apply_chain_preset(name)`
- `get_current_pedalboard_state()`

Notes:

- Presets are Python / UI only and do not imply new GPIO or bitstream
  changes.

### Safe Bypass

GUI controls:

- panic / bypass command

Overlay API sequence:

- `clear_distortion_pedals()`
- `set_distortion_settings(...)` with safe defaults
- `set_noise_suppressor_settings(enabled=False)`
- `set_compressor_settings(enabled=False)` when available
- `set_guitar_effects(noise_gate_on=False, overdrive_on=False, distortion_on=False, rat_on=False, amp_on=False, cab_on=False, eq_on=False, reverb_on=False)`

Notes:

- Safe Bypass must stay available even if HDMI rendering is slow.
- The command should be handled as a high-priority input action.

### Unsupported GUI effects

These names appear in older GUI / asset material but are not current live
AudioLab DSP sections:

- chorus
- phaser
- octaver
- general delay
- bit-crusher / bit effect

Live HDMI GUI must not make these effects controllable. They can only be
hidden, greyed out as unsupported, or left in reference assets that are
not used by the live PYNQ mode.

## 7. Risks

### Vivado and timing risk

HDMI GUI integration requires a Vivado block-design change. This is the
largest risk because the current design already runs with negative setup
slack. Adding video output IP can increase:

- LUT / register utilization
- BRAM usage
- DDR / AXI interconnect pressure
- clocking complexity
- implementation runtime
- timing closure difficulty

Any integrated bitstream must include a fresh timing summary. A bitstream
whose WNS is significantly worse than the previous deployed build must
not be deployed.

### Resource risk

A framebuffer scanout path usually needs VDMA / video timing / HDMI
output IP and possibly additional clock generation. The PYNQ-Z2 PL
resource budget is limited. The added video path must not starve the DSP
or destabilize audio.

### Runtime concurrency risk

The final system must run audio DSP, HDMI scanout, Python rendering, and
user input handling together. Risks include:

- Python rendering taking too long per frame
- 1280x720 RGB copy cost consuming CPU time
- HDMI frame transfer competing for memory bandwidth
- repeated GPIO writes during knob drags causing unnecessary bus traffic
- Jupyter / Notebook sessions and the HDMI GUI both writing effect state
  at the same time

Only one control frontend should be considered authoritative during a
live performance session, or the system needs explicit state arbitration.

### UI honesty risk

The GUI must not present non-existent DSP capabilities. In particular:

- chain reorder is not supported by the current FPGA pipeline
- unsupported effects must not look enabled or controllable
- five Cab choices must not be exposed if only three hardware models are
  available

### Operational risk

PYNQ overlay and contiguous memory operations usually need root. Future
board-side tests should follow the existing runtime rule:

```sh
sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 ...
```

## 8. Phased implementation plan

### Phase 0: docs only

Create this design document and record the project state. No code,
Vivado, bitstream, or deploy change.

### Phase 1: offscreen render benchmark on PYNQ

Run `render_frame(AppState())` on the PYNQ without HDMI output. Measure:

- cold render time
- cached render time
- 1280x720 frame generation time
- lower-resolution fallback time if needed
- memory allocation behavior

Goal: decide realistic GUI FPS before touching Vivado.

Phase 1 result (2026-05-14):

- Raw import failed on the current PYNQ image because Python 3.6 lacks
  the `dataclasses` backport.
- After process-local benchmark shims, rendering also needed
  NumPy 1.16-compatible `default_rng` and Pillow 5.1 `ImageDraw`
  compatibility shims.
- With those temporary shims, one 1280x720 RGB frame rendered
  successfully with shape `(720, 1280, 3)` and dtype `uint8`.
- Cold render time was about `3871 ms`.
- Exact same-state cache hits averaged about `0.177 ms/frame`.
- A dynamic 30-frame loop averaged about `744 ms/frame` with p95 around
  `2247 ms`, giving roughly `1.34 fps`.
- Continuous 5/10/15/30fps HDMI GUI is not realistic with the current
  full-frame PIL renderer on the PYNQ-Z2 CPU. Static or change-driven
  display is plausible after compatibility fixes.

Detailed numbers are recorded in
`docs/ai_context/HDMI_GUI_PHASE1_RENDER_BENCH.md`.

### Phase 2A: PYNQ offscreen compatibility without HDMI

Make the GUI renderer run on the PYNQ-Z2 without process-local benchmark
shims. This phase is Python compatibility only:

- no HDMI output
- no `run_pynq_hdmi()`
- no `Overlay("base.bit")`
- no `AudioLabOverlay()`
- no Vivado or bitstream work
- no GPIO bridge

Phase 2A result (2026-05-14):

- `GUI/pynq_multi_fx_gui.py` now has local compatibility helpers for
  missing `dataclasses`, NumPy 1.16 RNG, and Pillow 5.1 `ImageDraw`
  keyword support.
- Raw import on the PYNQ-Z2 succeeds without shims.
- `render_frame_fast(AppState())` succeeds offscreen with frame shape
  `[720, 1280, 3]` and dtype `uint8`.
- Import time was `451.188 ms`.
- Cold render was `3764.514 ms`.
- Same-state cached render averaged `0.171034 ms/frame` with p95
  `0.201208 ms/frame`.
- Change-driven redraw samples with animation time held static averaged
  `1972.889 ms/frame` with p95 `2111.738 ms/frame`.
- The generated PNG at `/tmp/hdmi_gui_phase2a/phase2a_render.png` was
  visually inspected and showed the expected 1280x720 GUI.
- Continuous animated HDMI output remains unrealistic; future live mode
  should be static/change-driven.

Detailed numbers are recorded in
`docs/ai_context/HDMI_GUI_PHASE2A_PYNQ_COMPAT.md`.

Live HDMI mode should therefore freeze or heavily throttle the current
animated visualizer / waveform / synthetic meters. The backend should
render only on visible state changes, reuse the previous RGB frame while
unchanged, and keep `state.t` fixed unless an explicit low-rate refresh
is requested.

### Phase 2B: PYNQ static/change-driven render optimization

Optimize the renderer for static HDMI GUI use before adding any hardware
bridge. This phase stays offscreen-only:

- no HDMI output
- no `run_pynq_hdmi()`
- no `Overlay("base.bit")`
- no `AudioLabOverlay()`
- no Vivado or bitstream work
- no GPIO bridge

Phase 2B result (2026-05-14):

- Static LCD / knob-panel chrome moved into the cached base layer.
- Semistatic redraw now draws only state-dependent content.
- Knob body chrome is cached.
- `RenderCache(pynq_static_mode=True)`,
  `make_pynq_static_render_cache()`, and `render_frame_pynq_static()`
  provide the PYNQ static/change-driven profile.
- PYNQ static mode freezes the synthetic visualizer / waveform into the
  cached base and suppresses high-cost glow / blur stamps.
- Raw import still succeeds on PYNQ.
- Frame shape / dtype remains `[720, 1280, 3]` / `uint8`.
- Default fast path change-driven redraw improved from Phase 2A
  `1972.889 ms` avg / `2111.738 ms` p95 to `690.397 ms` avg /
  `726.448 ms` p95.
- PYNQ static mode change-driven redraw measured `255.625 ms` avg /
  `276.171 ms` p95.
- Same-state cache p95 stayed sub-millisecond.
- PNG output was saved to `/tmp/hdmi_gui_phase2b/phase2b_pynq_static.png`
  and visually checked.

Detailed numbers are recorded in
`docs/ai_context/HDMI_GUI_PHASE2B_RENDER_OPTIMIZATION.md`.

### Phase 2C: AppState / AudioLabOverlay bridge without HDMI

Build a Python bridge that translates `AppState` changes into
`AudioLabOverlay` API calls. This phase remains HDMI-free and overlay-load
free.

Phase 2C result (2026-05-14):

- Added `GUI/audio_lab_gui_bridge.py`.
- Added `tests/test_hdmi_gui_bridge.py`.
- Bridge plans calls to `set_noise_suppressor_settings`,
  `set_compressor_settings`, `set_distortion_settings`,
  `clear_distortion_pedals`, `set_guitar_effects`, and
  `apply_chain_preset`.
- Same-state calls are suppressed by operation signature.
- Continuous knob drags are throttled to about 10 Hz by default.
- Safe Bypass and Chain Preset commands are high-priority and not
  throttled.
- Chain reorder is warning-only because the FPGA DSP order is fixed.
- Unsupported effects such as chorus / phaser / octaver / delay /
  bit-crusher are not mapped to live operations.
- PYNQ-Z2 dry-run verification succeeded from `/tmp/hdmi_gui_phase2c/`
  without `AudioLabOverlay()` or HDMI output.
- `render_frame_pynq_static(AppState())` still produced
  `[720, 1280, 3]` / `uint8` on the PYNQ during the bridge check.

Detailed results are recorded in
`docs/ai_context/HDMI_GUI_PHASE2C_BRIDGE_PLAN.md`.

### Phase 2D: AppState / AudioLabOverlay bridge runtime test (real overlay)

Drive the Phase 2C bridge against the deployed `audio_lab.bit` on the
PYNQ-Z2 with `dry_run=False`. Still HDMI-free.

Phase 2D result (2026-05-14):

- One `AudioLabOverlay()` load for the entire run.
- Pre and post smoke: `ADC HPF=True`, `R19=0x23`,
  `has delay_line gpio=False`, `has legacy axi_gpio_delay=True`.
- Real `AudioLabOverlay` methods invoked:
  `clear_distortion_pedals`, `set_distortion_settings`,
  `set_noise_suppressor_settings`, `set_compressor_settings`,
  `set_guitar_effects`, `apply_chain_preset`.
- Same-state second apply emitted `0` operations.
- Noise Sup THRESHOLD change wrote only the NS section plus the
  documented legacy `noise_gate_threshold` mirror inside
  `set_guitar_effects`.
- Compressor RATIO change wrote only `set_compressor_settings`.
- `knob_drag` event inside the 100 ms throttle window suppressed
  the real write; the same event after the window was applied.
- No HDMI output, no `Overlay("base.bit")`, no second overlay load,
  no `render_frame*` call from the bridge, no Vivado / block-design /
  bitstream / hwh change, no deploy, no Notebook / DSP edit.

Detailed results are recorded in
`docs/ai_context/HDMI_GUI_PHASE2D_BRIDGE_RUNTIME_TEST.md`.

### Phase 3: integrated HDMI Vivado design proposal

Create a detailed Vivado design proposal for adding HDMI output to the
existing AudioLab block design. This phase is still design-only until the
user explicitly approves `block_design.tcl` edits.

The proposal must include:

- exact IP list
- clocking plan
- AXI / DDR path
- address map impact
- expected resource impact
- expected timing risk
- rollback plan

Phase 3 result (2026-05-14):

- Recommendation: Option B — `axi_vdma` (Xilinx) + `v_tc` (Xilinx) +
  `v_axi4s_vid_out` (Xilinx) + `rgb2dvi` (Digilent), at a single
  fixed mode of 1280x720@60.
- Add one new `clk_wiz` to generate `pixel_clk = 74.25 MHz` and
  `serial_clk = 371.25 MHz` from the existing `FCLK_CLK0` (100 MHz).
- Add one new `proc_sys_reset` for the pixel / serial domain.
- Enable `S_AXI_HP0` on `processing_system7_0` and route VDMA MM2S
  through a new SmartConnect to HP0; keep the audio AXI DMA on
  the existing GP0 SmartConnect path.
- Extend `ps7_0_axi_periph` `NUM_MI` from 15 to 17 for VDMA and VTC
  AXI-Lite control.
- New AXI-Lite address candidates: `0x43CE0000` (VDMA),
  `0x43CF0000` (VTC), `0x43D00000` (rgb2dvi, if applicable). All
  existing `axi_gpio_*` addresses, names, and `ctrlA`-`ctrlD`
  semantics stay unchanged.
- Framebuffer is XRGB8888 in PS DDR (allocated via
  `pynq.allocate`), double-buffered, fed from the existing
  RGB888 `render_frame_pynq_static` output via a one-shot NumPy
  slice copy.
- Realistic Python redraw rate is 2..4 fps based on Phase 2B
  measurements (~256 ms per static redraw). HDMI scanout itself
  is 60 Hz from the framebuffer.
- Resource budget estimate: ~3.4 k..4.0 k extra LUTs, ~4.8 k..5.3 k
  extra FFs, ~4..7 extra BRAM tiles, 0 extra DSPs over the
  current baseline (Internal mono DSP pipeline, deployed).
- Deploy gate (new): audio-domain WNS must not slip materially
  below `-8.5 ns`; pixel and serial domains must close (WNS >= 0).
- Rollback: dated bit/hwh backups plus `git revert` on a future
  feature branch; `git push` / `pull` / `fetch` stay forbidden.

The full proposal lives at
`docs/ai_context/HDMI_GUI_PHASE3_VIVADO_DESIGN_PROPOSAL.md`. The
`block_design.tcl` patch shape (design-only, NOT applied) is at
`docs/ai_context/HDMI_BLOCK_DESIGN_TCL_PATCH_PLAN.md`. The Phase 4
implementation prompt draft is at
`docs/ai_context/HDMI_GUI_PHASE4_IMPLEMENTATION_PROMPT_DRAFT.md`.

### Phase 4: bit/hwh rebuild and timing check

After explicit approval, implement the Vivado integration and rebuild
`audio_lab.bit` / `audio_lab.hwh`.

Required checks:

- Vivado build completes
- timing summary recorded
- WNS / TNS / WHS / THS compared with baseline
- utilization recorded
- no GPIO address/name regression
- existing AudioLab smoke tests still pass

### Phase 5: static HDMI frame

Show one static RGB frame generated by `render_frame()` on HDMI while
preserving audio passthrough / Safe Bypass behavior.

Goal: prove scanout path works before adding a continuous GUI loop.

### Phase 6: low-FPS GUI display

Run the GUI at a conservative FPS, such as 3 to 10 FPS, and verify:

- HDMI output remains stable
- audio path remains stable
- CPU load is acceptable
- frame writes do not cause underruns or UI stalls

### Phase 7: GUI controls drive AudioLabOverlay

Enable user interactions that modify supported DSP controls:

- toggles
- knob changes
- model selection
- Chain Preset
- Safe Bypass

Hardware writes should be throttled and section-scoped.

### Phase 8: full real-instrument validation

Run PYNQ-Z2 with guitar input and HDMI display connected. Verify:

- no audio dropout during rendering
- no codec regression
- ADC HPF remains enabled
- Safe Bypass works immediately
- every supported effect section responds correctly
- Notebook workflows still work after stopping the HDMI GUI

## 9. Prohibited implementation actions

Until a future implementation phase explicitly approves otherwise:

- Do not load `base.bit` for the live AudioLab HDMI GUI.
- Do not call `Overlay("base.bit")` from the live AudioLab GUI path.
- Do not load any second full overlay after `AudioLabOverlay()`.
- Do not change `hw/Pynq-Z2/block_design.tcl` without explicit user
  approval.
- Do not rebuild or deploy a bitstream for docs-only work.
- Do not rename or move existing AXI GPIOs.
- Do not change existing GPIO addresses or `ctrlA` / `ctrlB` /
  `ctrlC` / `ctrlD` semantics.
- Do not change `LowPassFir.topEntity` unless a separate approved DSP
  change requires it.
- Do not alter the existing DSP pipeline for HDMI GUI work.
- Do not break current Notebook APIs.
- Do not present unsupported effects as controllable live DSP effects.
- Do not copy GPL or incompatible reference source into this project.
- Do not use `git push`, `git pull`, `git fetch`, or other remote git
  operations.

## 10. Future implementation prompt templates

### Phase 1 prompt: PYNQ offscreen render benchmark

> HDMI GUI統合の Phase 1 を実施してください。実装対象は
> `GUI/pynq_multi_fx_gui.py` の `render_frame(AppState())` を PYNQ-Z2 上で
> offscreen 実行し、1フレーム生成時間と cached path の時間を測定することです。
> HDMI出力、Vivado変更、bitstream rebuild、deploy、`base.bit` ロードは
> しないでください。`AudioLabOverlay()` をロードする必要がある場合は
> `sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 ...` を使い、
> 既存DSP機能を壊さないでください。結果は
> `docs/ai_context/HDMI_GUI_INTEGRATION_PLAN.md` または関連docsに追記して
> ください。`git push` / `git pull` / `git fetch`は禁止です。

### Phase 2C prompt: AppState / AudioLabOverlay bridge

> HDMI GUI統合の Phase 2C を実施してください。まだ HDMI 出力と Vivado変更は
> しないでください。`GUI/pynq_multi_fx_gui.py` の描画をなるべく温存し、
> `AppState` の変更を `AudioLabOverlay` の既存API
> (`set_noise_suppressor_settings`, `set_compressor_settings`,
> `set_distortion_settings`, `set_guitar_effects`, `apply_chain_preset`,
> Safe Bypass 相当) へ反映する bridge を設計・実装してください。
> GPIO write は毎frameではなく変更時または低rateにしてください。
> chain drag reorder は現行DSP固定順序と矛盾するため、ライブモードでは
> 表示専用または無効にしてください。`base.bit` はロード禁止です。
> Python tests / import checks を追加し、docsも更新してください。

### Phase 3 prompt: integrated HDMI Vivado proposal

> HDMI GUI統合の Phase 3 として、`audio_lab.bit` に HDMI video out 系を
> 統合する Vivado設計案だけを作成してください。まだ
> `hw/Pynq-Z2/block_design.tcl` は変更しないでください。AXI VDMA または
> PYNQ video subsystem 相当、HDMI output IP、video timing、clocking、
> framebuffer path、1280x720 RGB、既存Audio DSPとの共存、AXI/DDR負荷、
> リソース見積り、timingリスク、address map影響、rollback案をまとめて
> ください。既存GPIO address / `topEntity` / DSP pipeline は維持する前提です。
> 結果は docs に記録し、実装が必要な場合はユーザ承認を待ってください。
