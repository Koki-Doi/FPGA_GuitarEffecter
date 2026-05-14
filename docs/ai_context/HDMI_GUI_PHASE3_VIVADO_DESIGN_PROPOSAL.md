# HDMI GUI Phase 3 — Vivado integration design proposal

Date: 2026-05-14

Scope: design-only proposal for adding a HDMI framebuffer output path to
the existing `audio_lab.bit`. **No `hw/Pynq-Z2/block_design.tcl` edit,
no IP change, no Vivado build, no bitstream / hwh rebuild, no deploy,
and no HDMI output is performed in Phase 3.** This document only
prepares Phase 4 by spelling out the IP list, clocking, AXI / DDR
plan, address-map impact, resource and timing risks, and rollback.

This proposal must be revisited before any Phase 4 implementation;
treat every "candidate" or "preferred" item as a starting point that
still needs a one-off Vivado experiment.

## 1. Current AudioLab block design summary

Source of truth: `hw/Pynq-Z2/block_design.tcl` (1320 lines, single
flat block design `block_design`).

### Audio path

```text
ADC line-in (ADAU1761)
    -> sdata_i pad
    -> i2s_to_stream_0  (bclk / lrclk domain -> stream)
    -> axis_switch_sink (M_AXIS routing, NUM_MI=2, controlled by S_AXI_CTRL)
    -> axis_data_fifo_0 (depth 16)
    -> axis_subset_converter_0 (S=8 bytes, M=6 bytes; AXI Stream packing)
    -> clash_lowpass_fir_0 (the Clash-generated DSP, S_AXIS_TDATA=48-bit stereo frame)
    -> axis_subset_converter_1 (S=6 bytes, M=8 bytes; sign-extend back to 64-bit)
    -> axis_switch_source (NUM_MI=2)
    -> axi_dma_0 S_AXIS_S2MM and back to PS DDR for capture / passthrough
    -> i2s_to_stream_0 / sdata_o pad on the playback half
```

The Clash core also drives a separate MM2S path from PS DDR via
`axi_dma_0` when the user wants test signals or recordings.

`fx_gain_0` is a leftover HLS gain block on a separate AXI-Lite slave,
currently unused by the live AudioLab API.

### PS / PL configuration

- `processing_system7_0` v5.5:
  - `M_AXI_GP0` ACLK = `FCLK_CLK0` = 100 MHz
    (`CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100}`).
  - `S_AXI_GP0` enabled; the AXI DMA hits PS DDR through
    `axi_smc -> S_AXI_GP0`.
  - `S_AXI_HP0..3` and `S_AXI_ACP` are all OFF
    (`CONFIG.PCW_USE_S_AXI_HP*=0`, `PCW_USE_S_AXI_ACP=0`).
  - `EN_CLK1`, `EN_CLK2`, `EN_CLK3` all OFF; only `FCLK_CLK0` is
    currently routed.
  - `EMIO_I2S0` is NOT used by AudioLab; the existing audio I/O goes
    through MIO + the custom `i2s_to_stream_0` block.

- `clk_wiz_0` v6.0:
  - input = `FCLK_CLK0` (100 MHz)
  - output = `mclk` at 24 MHz (`CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {24}`)
    routed to a top-level pad as the ADAU1761 master clock.
  - `RESET_PORT {resetn}` / `RESET_TYPE {ACTIVE_LOW}` from
    `rst_ps7_0_100M/peripheral_aresetn`.

- `rst_ps7_0_100M` (proc_sys_reset, slowest_sync_clk = FCLK_CLK0).
- `proc_sys_reset_0` (proc_sys_reset, slowest_sync_clk = `bclk` input).

### AXI GPIO inventory

11 AXI GPIO instances, each 32-bit output-only, plus the two
axis_switch S_AXI_CTRL slaves, `fx_gain_0/s_axi_CTRL`, and
`axi_dma_0/S_AXI_LITE`.

Current `ps7_0_axi_periph` interconnect is `axi_interconnect:2.1`
with `CONFIG.NUM_MI {15}` (M00..M14 in use).

### Address map (current)

| Offset | Range | Slave | Notes |
| --- | --- | --- | --- |
| `0x40400000` | `0x00010000` | `axi_dma_0/S_AXI_LITE/Reg` | |
| `0x43C00000` | `0x00010000` | `axis_switch_source/S_AXI_CTRL/Reg` | |
| `0x43C10000` | `0x00010000` | `axis_switch_sink/S_AXI_CTRL/Reg` | |
| `0x43C20000` | `0x00010000` | `fx_gain_0/s_axi_CTRL/Reg` | Unused live API. |
| `0x43C30000` | `0x00010000` | `axi_gpio_reverb` | |
| `0x43C40000` | `0x00010000` | `axi_gpio_gate` | |
| `0x43C50000` | `0x00010000` | `axi_gpio_overdrive` | |
| `0x43C60000` | `0x00010000` | `axi_gpio_distortion` | |
| `0x43C70000` | `0x00010000` | `axi_gpio_eq` | |
| `0x43C80000` | `0x00010000` | `axi_gpio_delay` | legacy name; drives RAT |
| `0x43C90000` | `0x00010000` | `axi_gpio_amp` | |
| `0x43CA0000` | `0x00010000` | `axi_gpio_amp_tone` | |
| `0x43CB0000` | `0x00010000` | `axi_gpio_cab` | |
| `0x43CC0000` | `0x00010000` | `axi_gpio_noise_suppressor` | |
| `0x43CD0000` | `0x00010000` | `axi_gpio_compressor` | |

The S_AXI_GP0 path also exposes DDR (`0x00000000`, range 0x2000_0000)
and QSPI (`0xFC000000`).

### Timing baseline

From `TIMING_AND_FPGA_NOTES.md`, deployed `audio_lab.bit` ("Internal
mono DSP pipeline", 2026-05-09):

- WNS = `-8.155 ns`
- TNS = `-6492.876 ns`
- WHS = `+0.052 ns`
- THS = `0.000 ns`
- Slice LUTs: 15473 (29.08%)
- Slice Registers: 14914 (14.02%)
- Block RAM Tile: 7 (5.00%)
- DSPs: 83 (37.73%)

The `clk_fpga_0` (FCLK_CLK0) timing is the critical clock. `bclk` is
treated as asynchronous (`set_false_path` both directions in
`audio_lab.xdc`).

WNS is already negative on the audio domain. Any HDMI integration
that pushes WNS materially below `-8.5 ns` should NOT be deployed;
the deploy gate in `TIMING_AND_FPGA_NOTES.md` and `CLAUDE.md` is
"no significantly worse than the previous deployed build."

## 2. Integration policy

- Keep AudioLab DSP in one integrated `audio_lab.bit`. Do not load
  `base.bit`. Do not load any second overlay after
  `AudioLabOverlay()`.
- The HDMI subsystem lives entirely in PL, on its own clock domain,
  reading a PS DDR framebuffer.
- The Python renderer keeps producing 1280x720 RGB ndarrays.
- A new HDMI back end transfers the ndarray into the PS DDR
  framebuffer; the PL scans the framebuffer to TMDS at the pixel
  clock with no Python intervention per pixel.
- The DSP bridge (`GUI/audio_lab_gui_bridge.py`) writes
  `AudioLabOverlay` controls on change events / at a low control
  rate only.
- Renderer, HDMI back end, DSP bridge, and `AppState` stay separated
  Python modules.

## 3. Candidate architectures

The three candidates below all keep the existing AudioLab DSP exactly
as deployed. They differ in how much of the PYNQ video subsystem they
absorb and what the timing risk looks like.

### Option A — Port PYNQ base video subsystem (`base.bit` style)

Embed the full PYNQ-Z2 base video chain inside `audio_lab.bit`:
`axi_vdma` + `v_tc` (Video Timing Controller) + AXI4-Stream to Video
Out + Digilent `rgb2dvi` IP, plus a `color_convert` and `pixel_pack`
pair so the same Python `pynq.lib.video` API works.

- **Pros**
  - Maximum compatibility with existing PYNQ Python video helpers
    (`hdmi_out.configure(mode, PIXEL_RGB)`, `frame =
    hdmi_out.newframe(); hdmi_out.writeframe(frame)`).
  - Mode set / un-set already proven in PYNQ images.
  - Re-uses well-tested Digilent IP from the standard PYNQ-Z2 image.
- **Cons**
  - Largest LUT / register / BRAM impact in PL.
  - Largest AXI interconnect rework: VDMA needs HP slave port
    (S_AXI_HP0) wired to DDR, which is currently OFF.
  - Brings several IPs (`v_tc`, `v_axi4s_vid_out`, `color_convert`,
    `pixel_pack`) the audio design has never carried.
  - Highest timing closure risk in the audio domain because the
    interconnect topology changes a lot.
- **Required IP**: `axi_vdma`, `v_tc`, `v_axi4s_vid_out`,
  `color_convert`, `pixel_pack`, `rgb2dvi` (Digilent), one
  `proc_sys_reset` for the video domain, one extra `clk_wiz` (or
  use an additional FCLK) for pixel + 5x serial clock, one
  `axi_interconnect` (or smartconnect) for HP0.
- **PYNQ Python video API**: full compatibility.
- **Implementation difficulty**: high. Most rework on the audio side
  interconnect.
- **Timing risk**: high. Adds another clock domain with several CDC
  paths to existing AudioLab AXI segments.
- **Runtime risk**: medium. Larger HDMI buffer pool can mask Python
  slowness, but the audio AXI path now shares HP0/SMC arbitration.
- **Rollback**: easy on the git side, painful on Vivado IDE
  conflicts because the BD changes a lot. Reverting one commit
  restores the audio-only bit.
- **Recommendation**: medium. Use only if the live HDMI GUI requires
  the full PYNQ `pynq.lib.video` API surface (multiple modes,
  hotplug, RX support).

### Option B — Minimal `axi_vdma` + Video Timing Controller + `rgb2dvi`

Same general path as Option A, but drop `color_convert` and
`pixel_pack`. Lock the resolution to a single mode (1280x720@60 or
800x480@60) and feed `axi_vdma` directly from a PS DDR framebuffer in
its native pixel format (XRGB8888 or RGB888 — see section 7).

- **Pros**
  - Smaller PL footprint than Option A.
  - Single fixed mode keeps the Python back end small and avoids
    runtime mode-set machinery on PYNQ-Z2.
  - Still uses standard, well-known IP (`axi_vdma`, `v_tc`,
    `v_axi4s_vid_out`, `rgb2dvi`) and Vivado wizards can connect
    most of them automatically.
- **Cons**
  - Python `pynq.lib.video` compatibility is partial. You either
    drive `axi_vdma` directly via `pynq.lib.dma` and a
    `pynq.allocate` buffer, or import only the parts of
    `pynq.lib.video` that work without `color_convert` /
    `pixel_pack`.
  - One additional pixel clock domain is still required.
- **Required IP**: `axi_vdma`, `v_tc`, `v_axi4s_vid_out`,
  `rgb2dvi`, one extra `clk_wiz`, one `proc_sys_reset` (video
  domain), an AXI SmartConnect or extra master port on the
  existing audio SmartConnect for VDMA -> HP0.
- **PYNQ Python video API**: partial; we ship our own thin Python
  wrapper for `axi_vdma`. The PYNQ official `VideoMode` / `HDMI`
  classes can be reused for the timing part.
- **Implementation difficulty**: medium.
- **Timing risk**: medium. The pixel clock and the 5x TMDS clock
  add new domains, but the audio AXI tree only grows by one master.
- **Runtime risk**: medium-low. VDMA does the scanout, Python only
  writes the framebuffer.
- **Rollback**: easy. One reverted commit removes the entire video
  branch.
- **Recommendation**: high. Best balance for "static / change-driven
  GUI on top of the AudioLab DSP."

### Option C — Lightweight low-resolution framebuffer

Use a custom AXI4-Stream HDMI back end at 800x480@60 or 960x540@60,
written as a small RTL block that reads PS DDR through HP0 and feeds
`rgb2dvi`. No `axi_vdma`; the scanout RTL streams a fixed framebuffer
each frame using a small line buffer (one BRAM tile) and synchronous
counters.

- **Pros**
  - Smallest possible PL footprint.
  - One simple AXI master read into HP0 (no VDMA configuration
    surface in Python).
  - Pixel clock is much lower (33.75 MHz at 800x480, 40.5 MHz at
    960x540).
- **Cons**
  - Requires writing or vendoring a small VHDL/Verilog scanout
    block. The project rule (`DECISIONS.md` D7) forbids pasting
    GPL DSP / video source, but a clean-room small scanout block
    can be authored in-tree.
  - Reduces visible GUI fidelity vs. 1280x720.
  - No reuse of PYNQ `pynq.lib.video` API.
  - Per-frame tear is harder to avoid without a double-buffer
    machine (still doable in custom RTL).
- **Required IP**: `rgb2dvi`, `clk_wiz` for pixel + 5x TMDS,
  `proc_sys_reset` (video), AXI SmartConnect or HP0 wiring. The
  scanout RTL is custom.
- **PYNQ Python video API**: not used.
- **Implementation difficulty**: high (custom RTL) but isolated.
- **Timing risk**: low on the audio side; the custom RTL only has
  to meet the pixel clock period.
- **Runtime risk**: low-medium.
- **Rollback**: easy.
- **Recommendation**: medium. Best fallback if Option B closes
  too tight on PL utilisation, but the engineering cost is higher.

## 4. Recommended option

**Option B — minimal `axi_vdma` + `v_tc` + `rgb2dvi` at a single fixed
mode.** Reasons:

- The existing AudioLab BD already includes `axi_smc` and one
  AXI DMA. Adding one more AXI master to PS DDR through HP0 (or
  through the existing SMC + a new master segment on GP0 — see
  section 7) is incremental and standard practice on Zynq-7.
- The Digilent `rgb2dvi` IP is the standard PYNQ-Z2 TMDS encoder
  and the constraints for the PYNQ-Z2 HDMI TX pins are public in
  the Digilent reference design.
- 1280x720 RGB matches the renderer output (`render_frame_pynq_static`
  already produces `[720, 1280, 3]` `uint8`). Static / change-driven
  redraw at ~256 ms (Phase 2B) is acceptable when the framebuffer is
  written from Python once per change.
- A future second mode (800x480 fallback) can be slotted in by
  reprogramming `v_tc` and `clk_wiz` without re-routing the BD.

## 5. Concrete IP candidates (Vivado 2019.1 / PYNQ-Z2)

| IP | Vendor / VLNV (candidate) | Purpose |
| --- | --- | --- |
| `axi_vdma:6.3` | `xilinx.com:ip:axi_vdma:6.3` | Framebuffer scanout; MM2S into AXI4-Stream video |
| `v_tc:6.2` | `xilinx.com:ip:v_tc:6.2` | Video timing generator for 1280x720@60 |
| `v_axi4s_vid_out:4.0` | `xilinx.com:ip:v_axi4s_vid_out:4.0` | AXI4-Stream -> parallel video |
| `rgb2dvi:1.4` (or current) | `digilentinc.com:ip:rgb2dvi:1.4` | TMDS encoder for HDMI TX |
| `clk_wiz:6.0` (new) | `xilinx.com:ip:clk_wiz:6.0` | Generate `pixel_clk = 74.25 MHz` and `serial_clk = 5x pixel_clk = 371.25 MHz`; input is `FCLK_CLK0` (100 MHz) |
| `proc_sys_reset:5.0` (new) | `xilinx.com:ip:proc_sys_reset:5.0` | Synchronous reset for pixel + 5x domains |
| `axi_smartconnect:1.0` (or reuse existing `axi_smc`) | `xilinx.com:ip:smartconnect:1.0` | One new SI for VDMA MM2S; routes to S_AXI_HP0 |
| Optional `axi_interconnect:2.1` extension | `xilinx.com:ip:axi_interconnect:2.1` | If we choose to add the VDMA AXI-Lite control via `ps7_0_axi_periph` (NUM_MI 15 -> 16 or 17) |

Notes:

- Do NOT reuse `axi_gpio_delay` (legacy RAT) for any HDMI-related
  byte. Do NOT touch other AudioLab GPIO addresses or `ctrlA`-`ctrlD`
  semantics.
- `fx_gain_0` (HLS, currently unused) is not a candidate to be
  removed under Phase 4 — its presence on AXI-Lite does not change
  the audio path; leave it in place to avoid stirring address-map
  churn.

## 6. Clocking plan

1280x720@60 requires:

- pixel clock: 74.25 MHz
- 5x TMDS serial clock: 371.25 MHz

Plan:

- Add a new `clk_wiz` instance (separate from `clk_wiz_0` which still
  drives `mclk = 24 MHz`).
  - Input: `FCLK_CLK0` (100 MHz). FCLK1/2/3 are currently OFF; we do
    **not** turn them on to avoid changing the PS7 clock plan.
  - Output 0: `pixel_clk` 74.25 MHz, BUFG.
  - Output 1: `serial_clk` 371.25 MHz, BUFG.
- Add a new `proc_sys_reset` for the video domain.
- Audio stays on `FCLK_CLK0` exactly as today. The `clash_lowpass_fir_0`
  and every `axi_gpio_*` ACLK keep their FCLK_CLK0 connections — that
  net is not modified.
- Reset domain for video is asynchronous to `FCLK_CLK0`; XDC must
  `set_false_path` between `clk_fpga_0` and the new `pixel_clk` /
  `serial_clk` clocks (the AXI4-Stream FIFO inside `v_axi4s_vid_out`
  handles the actual CDC).
- HDMI TMDS pins are board fixed (PYNQ-Z2 schematic). XDC will need a
  new section assigning `TMDS_clk_p/n` and `TMDS_data_p/n[2:0]` to the
  HDMI TX pads.

CDC risk:

- `v_axi4s_vid_out` has an internal FIFO between AXI-Stream (FCLK
  domain via VDMA) and the pixel clock. This is the standard CDC
  point; no extra synchronizers are required.
- `v_tc` runs in the pixel domain; its AXI-Lite control crosses to
  FCLK via the AXI interconnect's CDC. The `axi_clock_converter` is
  inserted automatically by SmartConnect / interconnect tooling if
  the master / slave aclks differ.
- The VDMA MM2S engine should clock on FCLK to keep the AXI master
  side stable; only the M_AXIS_MM2S domain crosses to pixel through
  `v_axi4s_vid_out`.

## 7. AXI / DDR / framebuffer plan

Framebuffer location:

- PS DDR. Allocate one or two contiguous buffers with
  `pynq.allocate(shape=(720, 1280, 4), dtype="u1")` so the buffer is
  PL-visible and 4-byte-aligned.
- Use XRGB8888 (or BGRX8888 / RGBX8888 depending on `rgb2dvi`
  channel mapping) as the in-DDR pixel format. The renderer produces
  RGB888; a small NumPy view `frame_xrgb[:, :, :3] = rgb888` (and
  `frame_xrgb[:, :, 3] = 0`) reaches 1280x720x4 = 3.6 MiB per
  framebuffer. 32-bit-per-pixel is friendlier to AXI bursts than
  packed RGB888.
- Double-buffer to keep tear off the visible frame.

AXI path:

- VDMA MM2S issues 32-bit reads at 1280 px/line x 720 lines x 60 Hz
  = ~221 MB/s. With one read per pixel that is well inside an HP0
  port budget (3.2 GB/s theoretical). On the AudioLab side the
  audio AXI traffic is tiny (one 64-bit sample per 48 kHz audio
  frame).
- Wire VDMA M_AXI_MM2S to `processing_system7_0/S_AXI_HP0`, NOT to
  `S_AXI_GP0`. The audio `axi_dma_0` keeps its current GP0 SMC
  route. HP0 must be enabled in the PS7 config
  (`CONFIG.PCW_USE_S_AXI_HP0 {1}` will need to flip).
- VDMA AXI-Lite control goes through the existing
  `ps7_0_axi_periph` interconnect; expand `NUM_MI` from 15 to 16,
  and add an M15 segment for VDMA control. Address candidate:
  `0x43CE0000` (next free 64 KiB slot in the `0x43C00000` PL
  segment).
- `v_tc` AXI-Lite control also needs a master segment; choose
  `0x43CF0000` (`NUM_MI` -> 17). Both addresses are candidates
  only; final assignment in Phase 4.

Python NumPy / framebuffer copy plan:

- Renderer produces RGB888 `numpy.ndarray` shape `(720, 1280, 3)`,
  dtype `uint8`. Copy into the XRGB framebuffer with a stride of
  5120 bytes per line (1280 * 4). On the PYNQ-Z2 CPU this is a
  single contiguous memcpy through NumPy slicing; we measured
  Phase 2B redraw at ~256 ms which dominates the per-frame cost.
- After the copy, flush the cache range so VDMA reads the fresh
  pixels (`pynq.allocate(cacheable=False)` avoids the explicit
  flush; the cost is slightly slower CPU writes).
- Buffer lifetime is managed by Python: hold the
  `pynq.allocate` handle alive for as long as VDMA scans from it.
  On HDMI back end shutdown the Python class stops VDMA and frees
  the buffer.

Practical FPS:

- Phase 2B PYNQ static redraw is ~256 ms / frame (~3.9 fps cold
  redraw, lower if a copy + cache flush adds another 30..60 ms).
- Realistic target: 2..4 fps on visible state changes, with the
  scanout running at 60 Hz reading the latest committed
  framebuffer.
- Live mode must be change-driven, not a continuous animation loop.

## 8. Address-map impact

Decisions:

- **Do not change any existing AXI GPIO address.** The deployed
  `0x43C30000`..`0x43CD0000` block stays exactly as today.
- **Do not change AXI DMA, axis_switch, or fx_gain addresses.**
- New AXI-Lite masters for the HDMI path land in the same
  `0x43C00000` segment, after the existing `axi_gpio_compressor`:
  - VDMA control: candidate `0x43CE0000`, range `0x00010000`.
  - `v_tc` control: candidate `0x43CF0000`, range `0x00010000`.
  - If `rgb2dvi` exposes an AXI-Lite slave (some configurations
    don't), candidate `0x43D00000`, range `0x00010000`.
- HP0 framebuffer access does not consume a PL address segment; it
  uses PS DDR via `S_AXI_HP0`.

Address map after Phase 4 (proposal):

| Offset | Range | Slave |
| --- | --- | --- |
| ... | ... | (existing) |
| `0x43CD0000` | `0x00010000` | `axi_gpio_compressor` |
| `0x43CE0000` | `0x00010000` | `axi_vdma_hdmi/S_AXI_LITE` (new) |
| `0x43CF0000` | `0x00010000` | `v_tc_hdmi/CTRL` (new) |
| `0x43D00000` | `0x00010000` | `rgb2dvi_hdmi/CTRL` (new, if applicable) |

These addresses must not overlap with `axi_gpio_*`. They also must
not steal the `0x43CD0000` slot or be allocated at `0x43C20000`
(currently `fx_gain_0/s_axi_CTRL/Reg`).

## 9. Resource and timing risk

Baseline (deployed, internal-mono build):

- WNS = `-8.155 ns`, TNS = `-6492.876 ns`, WHS = `+0.052 ns`,
  THS = `0.000 ns`.
- LUTs 15473 (29.08%), Regs 14914 (14.02%), BRAM 7 (5.00%),
  DSPs 83 (37.73%).

Estimated incremental resource for Option B (rough; Vivado will tell
us the true number in Phase 4):

| Component | Approx LUTs | Approx FFs | BRAM | DSPs |
| --- | ---: | ---: | ---: | ---: |
| `axi_vdma` (1 channel, 32-bit) | ~1600 | ~2200 | 4..6 (line buffers) | 0 |
| `v_tc` | ~700 | ~900 | 0 | 0 |
| `v_axi4s_vid_out` | ~500 | ~700 | 0..1 | 0 |
| `rgb2dvi` | ~250 | ~500 | 0 | 0 |
| `clk_wiz` (new) | ~50 | ~80 | 0 | 0 (uses 1 MMCM) |
| `proc_sys_reset` (new) | ~30 | ~80 | 0 | 0 |
| SmartConnect / interconnect changes | ~300..600 | ~400..800 | 0 | 0 |
| **Total estimate** | **~3.4 k..4.0 k LUTs** | **~4.8 k..5.3 k FFs** | **4..7** | **0** |

That brings LUT usage to roughly 35..37% and BRAM to ~10%. All
within budget. DSP usage does not change.

Timing risk drivers:

- The new MMCM consumes one of two on the device; the existing
  `clk_wiz_0` already uses one. Two MMCM is fine on `xc7z020`.
- Adding HP0 enables S_AXI_HP0 inside PS7 — this changes the PS7
  configuration block and triggers a full Vivado synth. The audio
  side AXI tree is otherwise untouched.
- Negative WNS on the audio domain is the main risk. The pixel
  clock and the 5x TMDS clock are independent domains and will
  have their own WNS; that does not by itself degrade the audio
  WNS. But re-placement of the audio cells around the new HDMI
  IP could shift critical paths by ~0.2..0.5 ns. Anything that
  drops audio WNS below ~-8.6 ns should not be deployed.

DDR / AXI bandwidth:

- Audio AXI DMA: <1 MB/s.
- HDMI MM2S at 1280x720@60 with XRGB8888 = 221 MB/s. HP0 can
  sustain 1.6..3.2 GB/s; this is safe.
- If a future user wants 1080p, recompute: 1920x1080x4x60 = 498 MB/s
  (still inside HP0 budget but tighter on the PYNQ-Z2 DDR3 -- defer).

**Deploy gate (new)**: a Phase 4 bitstream may be deployed only if:

1. Vivado prints `write_bitstream completed successfully`.
2. Audio-domain WNS is not significantly worse than `-8.5 ns`.
3. Pixel-domain WNS >= 0 ns.
4. Hold remains clean on every domain (WHS >= 0 ns, THS = 0 ns).
5. Existing `tests/test_overlay_controls.py` and Phase 2D bridge
   smoke pass on the new bit.
6. ADC HPF still on, R19 still `0x23`, `has delay_line gpio = False`,
   `has legacy axi_gpio_delay = True`.

## 10. Python runtime design (future)

Phase 4+ runtime (Python only, not implemented yet):

```python
overlay = AudioLabOverlay()           # one and only Overlay load
hdmi = AudioLabHdmiBackend(overlay)   # uses overlay.axi_vdma_hdmi etc.
hdmi.start(mode="1280x720@60")
state = AppState()
cache = make_pynq_static_render_cache()
bridge = AudioLabGuiBridge()
frame = render_frame_pynq_static(state, cache)
hdmi.write(frame)
while running:
    event = input_queue.get()
    state = apply_input(state, event)
    bridge.apply(state, overlay=overlay, dry_run=False, event=event.kind)
    if state_changed_visually:
        frame = render_frame_pynq_static(state, cache)
        hdmi.write(frame)
hdmi.stop()
```

Key contracts:

- `AudioLabOverlay()` is constructed exactly once per session.
- HDMI back end uses `overlay`'s integrated VDMA / VTC / rgb2dvi
  handles. It does not call `Overlay("base.bit")`.
- Bridge writes go through `apply()` only on state-changed events,
  not per video frame.
- Safe Bypass remains a high-priority bridge command; it is not
  throttled and is independent of HDMI state.
- Jupyter Notebook sessions should not be running the same
  AudioLabOverlay control APIs concurrently with the HDMI GUI;
  treat one of them as authoritative per session.

## 11. Rollback plan

1. The Phase 4 implementation lives on a dedicated feature branch
   (e.g. `feature/hdmi-vivado-integration`). Master / main / current
   deploy branch keep the audio-only bit.
2. Before any Phase 4 Vivado build, copy
   `hw/Pynq-Z2/bitstreams/audio_lab.bit` and
   `hw/Pynq-Z2/bitstreams/audio_lab.hwh` to a dated backup path
   (e.g. `audio_lab.bit.pre-hdmi-2026-05-14`).
3. PYNQ deploy `scripts/deploy_to_pynq.sh` only runs when timing /
   smoke gates pass.
4. PYNQ smoke test required after deploy:
   - ADC HPF True / R19 0x23.
   - `has legacy axi_gpio_delay True`, no `axi_gpio_delay_line`.
   - All deployed chain presets still apply through
     `apply_chain_preset(name)`.
   - Local `tests/test_overlay_controls.py` passes against the
     new bit.
   - Phase 2D bridge runtime test passes (now with the HDMI back
     end constructed but the HDMI screen kept off if no monitor is
     attached).
5. If any of the above fail, revert the Vivado build, restore the
   pre-HDMI `audio_lab.bit` / `audio_lab.hwh` from backup, and
   redeploy with `bash scripts/deploy_to_pynq.sh`.
6. Git rollback uses `git revert` of the Phase 4 commits on the
   feature branch. Local commits only — `git push` / `pull` /
   `fetch` are forbidden by `CLAUDE.md`.

## 12. Phase 4 task list (for later approval)

Do NOT execute these in Phase 3. They are listed so Phase 4 starts
from a concrete checklist.

1. Create a feature branch `feature/hdmi-vivado-integration` (or
   similar) from the current main.
2. Back up `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}` to a dated
   path.
3. Edit `hw/Pynq-Z2/block_design.tcl`:
   - Add `clk_wiz_hdmi` (pixel + 5x serial).
   - Add `proc_sys_reset_hdmi`.
   - Add `axi_vdma`, `v_tc`, `v_axi4s_vid_out`, `rgb2dvi`.
   - Enable `S_AXI_HP0` on `processing_system7_0`.
   - Add the new master segments on `ps7_0_axi_periph`
     (`NUM_MI {17}`).
   - Wire VDMA MM2S -> SmartConnect -> S_AXI_HP0.
   - Wire VDMA M_AXIS_MM2S -> v_axi4s_vid_out -> rgb2dvi.
   - Wire v_tc -> v_axi4s_vid_out and v_tc -> rgb2dvi for
     hsync / vsync.
   - Expose TMDS pads on the top wrapper.
4. Edit `hw/Pynq-Z2/audio_lab.xdc`:
   - Add `TMDS_clk_p/n` and `TMDS_data_p/n[2:0]` constraints from
     the PYNQ-Z2 schematic.
   - Add `set_false_path` between `clk_fpga_0` and the new
     `pixel_clk` / `serial_clk` clocks.
5. Add the new VDMA / VTC / rgb2dvi addresses to the address map
   (sections 7, 8 of this document).
6. Confirm `hw/Pynq-Z2/bitstreams/audio_lab.hwh` exposes
   `axi_vdma_hdmi`, `v_tc_hdmi`, and `rgb2dvi_hdmi` (or whatever
   names land) after a clean rebuild.
7. Add a new Python back end `audio_lab_pynq/HdmiOutput.py` that:
   - Takes an `AudioLabOverlay` instance.
   - Allocates a `pynq.allocate` framebuffer.
   - Drives the VDMA registers.
   - Exposes `write(frame_rgb)` and `start/stop`.
8. Run Vivado bitstream build through the existing
   `hw/Pynq-Z2/Makefile`.
9. Record timing: WNS / TNS / WHS / THS for audio and pixel domains.
   Compare with the `-8.155 ns` baseline. Block deploy if WNS
   slips significantly.
10. Deploy via `PYNQ_HOST=192.168.1.9 bash scripts/deploy_to_pynq.sh`.
11. Run PYNQ smoke test:
    - `AudioLabOverlay` loads.
    - ADC HPF True / R19 0x23 / no delay_line / has legacy
      axi_gpio_delay.
    - Chain Presets apply.
12. Show one static `render_frame_pynq_static` frame on HDMI.
13. Run a 2..4 fps change-driven HDMI loop and verify no audio
    dropout.
14. Audio passthrough smoke (`tests/test_overlay_controls.py`)
    still passes.
15. Commit Phase 4 work locally only.

## 13. Phase 4 prompt template

(Do NOT execute. Hand back to the user for approval first.)

> HDMI GUI統合の Phase 4 を実施してください。前提として Phase 2D の
> `AudioLabGuiBridge` runtime test と Phase 3 の Vivado 設計案
> (`docs/ai_context/HDMI_GUI_PHASE3_VIVADO_DESIGN_PROPOSAL.md`) は
> 完了しています。
>
> 作業対象:
> - 作業ブランチ作成 (例: `feature/hdmi-vivado-integration`)
> - `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}` のバックアップ
> - `hw/Pynq-Z2/block_design.tcl` に Option B 構成を追加
>   (`axi_vdma`, `v_tc`, `v_axi4s_vid_out`, `rgb2dvi`,
>    新 `clk_wiz`, 新 `proc_sys_reset`, `S_AXI_HP0` 有効化,
>    `ps7_0_axi_periph` `NUM_MI` 拡張)
> - `hw/Pynq-Z2/audio_lab.xdc` に TMDS 制約と video-domain false_path 追加
> - 既存 AXI GPIO address / name / `ctrlA`-`ctrlD` semantics を保持
> - 新規 AXI-Lite address は `0x43CE0000` / `0x43CF0000` / `0x43D00000`
>   候補。既存 GPIO 帯域とは重複させない
> - Vivado bitstream build, timing summary 比較
>   (audio WNS が `-8.5 ns` を significantly に下回らないこと)
> - `audio_lab_pynq/HdmiOutput.py` 追加 (`AudioLabOverlay` 1 ロード前提)
> - `bash scripts/deploy_to_pynq.sh` で deploy
> - PYNQ smoke: ADC HPF True / R19 0x23 / delay_line なし /
>   legacy `axi_gpio_delay` あり / Chain Preset 適用 OK
> - HDMI 静止 1 フレーム表示 (audio passthrough を壊さない)
> - `tests/test_overlay_controls.py` と Phase 2D bridge smoke が通ること
>
> 禁止事項:
> - `Overlay("base.bit")`
> - `AudioLabOverlay()` の後に別 Overlay() をロード
> - `run_pynq_hdmi()` の旧経路をそのまま使用
> - 既存 GPIO address / name / `ctrlA`-`ctrlD` semantics 変更
> - GPIO `axi_gpio_delay_line` の追加 (legacy `axi_gpio_delay` は保持)
> - DSP / Clash / `topEntity` interface 変更
> - GPL / 商用ペダル / IR の source コピー
> - WNS が baseline 比で大幅に悪化した bitstream の deploy
> - `git push` / `git pull` / `git fetch`
>
> 必ず読む:
> - `CLAUDE.md`
> - `docs/ai_context/CURRENT_STATE.md`
> - `docs/ai_context/DECISIONS.md`
> - `docs/ai_context/TIMING_AND_FPGA_NOTES.md`
> - `docs/ai_context/GPIO_CONTROL_MAP.md`
> - `docs/ai_context/HDMI_GUI_INTEGRATION_PLAN.md`
> - `docs/ai_context/HDMI_GUI_PHASE3_VIVADO_DESIGN_PROPOSAL.md`
> - `docs/ai_context/HDMI_GUI_PHASE2D_BRIDGE_RUNTIME_TEST.md`
>
> 結果は `docs/ai_context/HDMI_GUI_PHASE4_*` 系として記録してください。
