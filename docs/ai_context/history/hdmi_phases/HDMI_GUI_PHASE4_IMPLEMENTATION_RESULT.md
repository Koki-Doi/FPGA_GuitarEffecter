# HDMI GUI Phase 4 implementation result

Date: 2026-05-14

This file records two iterations:

- **Attempt 1 — STOPPED at preflight** because Digilent `rgb2dvi` IP
  was missing from the local Vivado 2019.1 catalog.
- **Attempt 2 — Alt-1 retry** with Digilent `vivado-library` cloned
  outside the AudioLab tree at `/home/doi20/digilent-vivado-library`.
  The Phase 3 docs have been corrected for `v_tc` 6.1 (not 6.2), the
  real PYNQ-Z2 HDMI TX pin map (`L16/L17/K17/K18/K19/J19/J18/H18`
  LVCMOS33, not `H16/H17/D19/D20/C20/B20/B19/A20` TMDS_33), and the
  rgb2dvi-internal `SerialClk` path (rgb2dvi's PLL generates the 5x
  TMDS clock from PixelClk on its own — clk_wiz_hdmi only needs the
  74.25 MHz pixel clock output).
- **Recovery / Attempt 3 — COMPLETED** from a dirty Phase 4A restart
  on 2026-05-15. The integrated HDMI framebuffer path was built,
  deployed to PYNQ-Z2 `192.168.1.9`, and smoke-tested without loading
  `base.bit` or a second overlay.

## Recovery / Attempt 3 — completed from dirty Phase 4A state

Status: **Phase 4A and Phase 4B completed.** One integrated
`audio_lab.bit` now contains the existing AudioLab DSP plus a fixed
1280x720 HDMI framebuffer output path. `AudioLabOverlay()` is still the
only overlay loaded at runtime; `Overlay("base.bit")` and
`run_pynq_hdmi()` remain forbidden for AudioLab.

### Recovery starting state

- Branch: `feature/hdmi-gui-phase4-vivado-integration`
- Starting HEAD: `7db1707 Validate HDMI GUI bridge on real overlay and
  draft Vivado integration plan`
- Safety tag already present: `before-hdmi-gui-phase4`
- Dirty files at restart included `hw/Pynq-Z2/create_project.tcl`,
  `hw/Pynq-Z2/audio_lab.xdc`, HDMI docs, untracked
  `hw/Pynq-Z2/hdmi_integration.tcl`,
  `audio_lab_pynq/hdmi_backend.py`, and
  `scripts/test_hdmi_static_frame.py`.
- `hw/Pynq-Z2/bitstreams/audio_lab.bit` and `.hwh` were deleted in the
  working tree at restart. They were regenerated successfully and were
  not committed in a deleted/broken state.
- Dirty-state backup:
  `/tmp/fpga_guitar_effecter_backup/hdmi_phase4_dirty_recovery.patch`
  and `/tmp/fpga_guitar_effecter_backup/hdmi_phase4_dirty_status.txt`
- Bit/hwh backup of the pre-Phase-4 deployed build:
  `/tmp/audio_lab_bit_backup_phase4_20260514_221716/`

### Digilent IP / Vivado preflight

- Digilent `vivado-library` location:
  `/home/doi20/digilent-vivado-library`
- `rgb2dvi` component:
  `/home/doi20/digilent-vivado-library/ip/rgb2dvi/component.xml`
- Vivado 2019.1 IP catalog probe returned:
  `digilentinc.com:ip:rgb2dvi:1.4`
- `hw/Pynq-Z2/create_project.tcl` now adds the Digilent IP repo from
  `$DIGILENT_VIVADO_LIBRARY/ip`, falling back to
  `/home/doi20/digilent-vivado-library/ip`, validates
  `rgb2dvi/component.xml`, and runs `update_ip_catalog`.

### XDC / pin result

The HDMI OUT pin locations match the PYNQ-Z2 board file:
`L16/L17/K17/K18/K19/J19/J18/H18`. The earlier wrong
`H16/H17/D19/D20` style pins are not used.

The final XDC applies **PACKAGE_PIN only** to the HDMI top-level ports.
Vivado placement failed when `IOSTANDARD LVCMOS33` was also applied to
the differential top-level ports, because Digilent `rgb2dvi` internally
instantiates `OBUFDS` with its own `TMDS_33` setting. Leaving the
IOSTANDARD owned by `rgb2dvi` is the buildable configuration.

### Pixel format / data width

- GUI renderer output: RGB888 ndarray, shape `[720, 1280, 3]`,
  dtype `uint8`.
- DDR framebuffer: 24-bit packed `GBR888`.
- Python swizzle: `byte0=G`, `byte1=B`, `byte2=R`.
- VDMA MM2S stream width: 24-bit.
- VDMA HSIZE: `3840` bytes.
- VDMA STRIDE: `3840` bytes.
- VDMA VSIZE: `720` lines.
- `v_axi4s_vid_out` input data width: 24-bit RGB stream.
- `rgb2dvi` input mapping: `vid_pData[23:16]=R`,
  `[15:8]=B`, `[7:0]=G`.
- No XRGB8888 path is used, so there is no implicit 32-bit to 24-bit
  truncation.

### Added Vivado IP

The HDMI integration is isolated in `hw/Pynq-Z2/hdmi_integration.tcl`,
which is sourced by `create_project.tcl` after the existing
`block_design.tcl`.

New cells / address map:

| IP | Purpose | Address |
| --- | --- | --- |
| `clk_wiz_hdmi` | 74.25 MHz pixel clock from FCLK0 | n/a |
| `rst_video_0` | video-domain reset | n/a |
| `axi_smc_hdmi` | VDMA MM2S to PS HP0 DDR | n/a |
| `axi_vdma_hdmi` | MM2S framebuffer scanout | `0x43CE0000` |
| `v_tc_hdmi` | 1280x720 video timing generator | `0x43CF0000` |
| `v_axi4s_vid_out_hdmi` | AXI4-Stream to native video | HWH-only |
| `rgb2dvi_hdmi` | Digilent HDMI TX encoder | HWH-only |

Existing DSP, Clash `topEntity`, audio GPIO names/addresses, and
`axi_gpio_delay` legacy RAT semantics were not changed.

### Vivado build / timing / utilization

Build command:

```sh
cd hw/Pynq-Z2
make 2>&1 | tee /tmp/hdmi_phase4_vivado_build_iostandard_fix.log
```

Result:

- `validate_bd_design` passed.
- Synthesis, implementation, routing, and `write_bitstream` completed.
- Generated `hw/Pynq-Z2/bitstreams/audio_lab.bit`.
- Generated `hw/Pynq-Z2/bitstreams/audio_lab.hwh`.
- HWH contains `axi_vdma_hdmi`, `v_tc_hdmi`,
  `v_axi4s_vid_out_hdmi`, and `rgb2dvi_hdmi`.

Timing:

| Metric | Value |
| --- | --- |
| WNS | `-8.163 ns` |
| TNS | `-6599.061 ns` |
| WHS | `+0.051 ns` |
| THS | `0.000 ns` |

Utilization after place:

| Resource | Value |
| --- | --- |
| Slice LUTs | `18619` (`35.00%`) |
| Slice Registers | `20846` (`19.59%`) |
| Block RAM Tile | `9` (`6.43%`) |
| DSPs | `83` (`37.73%`) |

The HDMI pixel domain closed with positive setup slack. The remaining
negative setup slack is in the existing audio-side clock domains and is
within the Phase 4 deploy gate (`WNS >= -9.0 ns`, hold clean).

### Deploy / runtime smoke

Deploy command:

```sh
bash scripts/deploy_to_pynq.sh
```

The deploy script now copies:

- `audio_lab_pynq/` including the new bit/hwh and `hdmi_backend.py`
- `scripts/test_hdmi_static_frame.py`
- tracked GUI Python renderer files needed by the static frame test

PYNQ smoke result:

- `AudioLabOverlay()` load: OK.
- ADC HPF: `True`.
- `R19_ADC_CONTROL`: `0x23`.
- `has delay_line gpio`: `False`.
- `has legacy axi_gpio_delay`: `True`.
- `axi_gpio_noise_suppressor`: present.
- `axi_gpio_compressor`: present.
- `axi_vdma_hdmi`: present in `ip_dict`.
- `v_tc_hdmi`: present in `ip_dict`.
- `rgb2dvi_hdmi` / `v_axi4s_vid_out_hdmi`: present in HWH.
- Chain presets: current implementation exposes `13` names. The
  required `Safe Bypass`, `Basic Clean`, and `Metal Tight` presets were
  applied successfully, then the board was returned to `Safe Bypass`.
- Audio DSP control path: preset APIs completed without exception.

### HDMI static frame test

Command:

```sh
ssh xilinx@192.168.1.9 \
  'sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
   python3 /home/xilinx/Audio-Lab-PYNQ/scripts/test_hdmi_static_frame.py'
```

Result:

- GUI renderer produced `[720, 1280, 3]` / `uint8` RGB888.
- Render time: `2.914 s`.
- Framebuffer physical address: `0x16900000`.
- Framebuffer size: `2764800` bytes.
- Framebuffer format: `GBR888 packed in DDR from RGB888 input`.
- VDMA HSIZE: `3840`.
- VDMA VSIZE: `720`.
- VDMA STRIDE: `3840`.
- VDMA mode: parked frame 0, internal genlock.
- `VDMACR` after start: `0x00010001`.
- `DMASR` after start: `0x00011000`.
- Error bits: `dmainterr=False`, `dmaslverr=False`,
  `dmadecerr=False`, `halted=False`, `idle=False`.
- `v_tc_hdmi` control register: `0x00000006`.
- Post-HDMI smoke kept ADC HPF `True`, `R19=0x23`,
  `axi_gpio_delay_line=False`, legacy `axi_gpio_delay=True`.

The backend is scanning out. Physical HDMI display visibility still
requires a connected monitor and human visual check; this session
verified framebuffer copy, VDMA/VTC status, and no VDMA error bits.

### Runtime implementation note

On PYNQ, `axi_vdma_hdmi` appears in `overlay.ip_dict`, but accessing
`overlay.axi_vdma_hdmi` tries to instantiate PYNQ's base-video
`AxiVDMA` driver and fails because this AudioLab MM2S-only instance
does not expose the interrupt attributes that driver expects.
`audio_lab_pynq.hdmi_backend.AudioLabHdmiBackend` therefore creates
bare `pynq.MMIO` handles from `ip_dict` for `axi_vdma_hdmi` and
`v_tc_hdmi`.

`rgb2dvi_hdmi` and `v_axi4s_vid_out_hdmi` are not AXI-Lite MMIO
peripherals, so they are verified from HWH rather than through PYNQ
overlay attributes.

The rest of this document keeps Attempt 1's preflight findings as
historical context.

## Attempt 1 — preflight stop

Status: **Phase 4A halted at the preflight gate. Phase 4B not started.**
No `hw/Pynq-Z2/block_design.tcl` edit, no Vivado build, no
`audio_lab.bit` / `audio_lab.hwh` rebuild, no `scripts/deploy_to_pynq.sh`
run, no Python HDMI backend code added, no commit. This file is the
failure record requested by the Phase 4 prompt and is intentionally
left **uncommitted** because the user's Phase 4 instructions list
`rgb2dvi IPが無い` as a `commit禁止条件`.

## What was actually done

- Switched to a new local branch `feature/hdmi-gui-phase4-vivado-integration`
  from the Phase 3 tip `7db1707`.
- Created safety tag `before-hdmi-gui-phase4` at `7db1707`.
- Backed up the current deployed bit and hwh:
  - source: `hw/Pynq-Z2/bitstreams/audio_lab.bit` (4,045,680 bytes)
  - source: `hw/Pynq-Z2/bitstreams/audio_lab.hwh` (811,365 bytes)
  - backup directory: `/tmp/audio_lab_bit_backup_phase4_20260514_221716/`
  - both files copied bit-for-bit; the backup is the deployed
    Internal-mono DSP build documented in `CURRENT_STATE.md` and
    `TIMING_AND_FPGA_NOTES.md`.
- Ran a Vivado 2019.1 batch IP-catalog probe to verify every IP the
  Phase 3 proposal asked for.
- Searched the host filesystem for the Digilent `rgb2dvi` IP
  (`component.xml`, repo directories, vivado-library clones).
- Read the PYNQ-Z2 board file (`TUL/pynq-z2/1.0/part0_pins.xml`) to
  confirm the actual HDMI TX pin map.
- Did **NOT** edit `hw/Pynq-Z2/block_design.tcl`. Did **NOT** edit
  `hw/Pynq-Z2/audio_lab.xdc`. Did **NOT** run `vivado` past the IP
  probe. Did **NOT** call `scripts/deploy_to_pynq.sh`. Did **NOT**
  add `audio_lab_pynq/HdmiOutput.py` or any HDMI test script.

## Preflight gate result

The Phase 4 prompt is explicit:

> rgb2dvi IPが無い場合、block_design.tclを編集せず停止してください。
> HDMI OUT XDCが確認できない場合、適当なpinを作らず停止してください。
> port名が不明な場合も強行しないでください。

### Vivado availability

```
/home/doi20/vivado/Vivado/2019.1/bin/vivado
Vivado v2019.1 (64-bit)
SW Build 2552052 on Fri May 24 14:47:09 MDT 2019
```

OK.

### Vivado IP catalog probe (xc7z020clg400-1, board.repoPaths set to the
existing AudioLab project paths)

The probe used a fresh in-memory project and
`get_ipdefs -filter "VLNV =~ *:<name>:*"` for each candidate IP:

| Probe | Result | Verdict |
| --- | --- | --- |
| `rgb2dvi` | (empty — `WARNING: [Coretcl 2-175] No Catalog IPs found`) | **BLOCKER** |
| `dvi2rgb` | (empty) | absent (relevant for future HDMI RX work) |
| `axi_vdma` | `xilinx.com:ip:axi_vdma:6.3` | OK |
| `v_tc` | `xilinx.com:ip:v_tc:6.1` | OK (note: 6.1, not the 6.2 the Phase 3 proposal assumed) |
| `v_axi4s_vid_out` | `xilinx.com:ip:v_axi4s_vid_out:4.0` | OK |
| `clk_wiz` | `xilinx.com:ip:clk_wiz:6.0` | OK |
| `proc_sys_reset` | `xilinx.com:ip:proc_sys_reset:5.0` | OK |

The Digilent `rgb2dvi` IP is not in the current Vivado IP catalog and
no `component.xml` was found under `/home/doi20/`, `/opt/`, `/tools/`,
or `/usr/local/` after a recursive `find`.

### HDMI TX pins on PYNQ-Z2 (from the board file)

From `/home/doi20/board_files/XilinxBoardStore/boards/TUL/pynq-z2/1.0/part0_pins.xml`:

| Net | LOC | IOSTANDARD |
| --- | --- | --- |
| `TMDS_OUT_clk_p` | `L16` | `LVCMOS33` |
| `TMDS_OUT_clk_n` | `L17` | `LVCMOS33` |
| `TMDS_OUT_data_p_0` | `K17` | `LVCMOS33` |
| `TMDS_OUT_data_n_0` | `K18` | `LVCMOS33` |
| `TMDS_OUT_data_p_1` | `K19` | `LVCMOS33` |
| `TMDS_OUT_data_n_1` | `J19` | `LVCMOS33` |
| `TMDS_OUT_data_p_2` | `J18` | `LVCMOS33` |
| `TMDS_OUT_data_n_2` | `H18` | `LVCMOS33` |
| `hdmi_tx_hpd` | `R19` | `LVCMOS33` |
| `hdmi_tx_cec` | `G15` | `LVCMOS33` |

Important: the PYNQ-Z2 HDMI TX header is wired as **single-ended LVCMOS33
pairs** that feed a board-side external network, not as `TMDS_33`
differential pads. The Phase 3 / `HDMI_BLOCK_DESIGN_TCL_PATCH_PLAN.md`
draft assumed `IOSTANDARD TMDS_33` and used pins `H16/H17/D19/D20/C20/B20/B19/A20`.
Those are **wrong** for PYNQ-Z2 (those numbers come from a different
Digilent board — likely a Zybo Z7 / Arty Z7 mistake). Phase 4 must use
the `LVCMOS33` net names and locations from the board file above, which
in turn implies the TMDS encoder block must drive single-ended outputs
that the on-board passive network turns into a differential pair.
Digilent's standard `rgb2dvi` IP is exactly that style of encoder, so
this is consistent with the architecture decision in Phase 3 — but the
IP itself is missing locally.

## Decision: STOP

Per the user's explicit Phase 4 stop condition (`rgb2dvi IPが無い場合、
block_design.tcl を編集せず停止してください。`), the Phase 4 implementation
is halted at the preflight gate. No tracked file in the repository
has been edited; the only side effects of this session are:

- new local branch `feature/hdmi-gui-phase4-vivado-integration`
- new local tag `before-hdmi-gui-phase4` at `7db1707`
- bit/hwh backup at `/tmp/audio_lab_bit_backup_phase4_20260514_221716/`
- this file as an untracked `?? docs/ai_context/HDMI_GUI_PHASE4_IMPLEMENTATION_RESULT.md`

## What did NOT change

- `hw/Pynq-Z2/block_design.tcl` (unchanged).
- `hw/Pynq-Z2/audio_lab.xdc` (unchanged).
- `hw/Pynq-Z2/bitstreams/audio_lab.bit` (unchanged — same as the
  deployed Internal-mono build).
- `hw/Pynq-Z2/bitstreams/audio_lab.hwh` (unchanged).
- `hw/ip/clash/src/LowPassFir.hs` (unchanged).
- `hw/ip/clash/src/AudioLab/*` (unchanged).
- Any `axi_gpio_*` address, name, or `ctrlA`-`ctrlD` semantics
  (unchanged).
- The legacy `axi_gpio_delay` (legacy RAT) (unchanged).
- The ADAU1761 codec config / R19 ADC HPF default-on (unchanged).
- `audio_lab_pynq/AudioLabOverlay.py`, `AudioCodec.py`,
  `control_maps.py`, `effect_defaults.py`, `effect_presets.py`
  (unchanged).
- Every Notebook (unchanged).
- Every Chain Preset (unchanged).
- The list of supported live effects (Noise Sup / Compressor /
  Overdrive / Distortion / Amp Sim / Cab IR / EQ / Reverb) is
  unchanged. chorus / phaser / octaver / delay / bit-crusher are
  still **not** live effects.

No PYNQ-side action was taken in Phase 4. The board is still running
the same `audio_lab.bit` it was running at the end of Phase 2D.

## Why this is the correct outcome

If I had edited `block_design.tcl` and asked Vivado to instantiate a
`digilentinc.com:ip:rgb2dvi:1.4` cell without that IP in the catalog,
`validate_bd_design` would fail and `write_bitstream` would never run.
Without `rgb2dvi`, the BD also has no path from `v_axi4s_vid_out` to
the TMDS output pads. Hand-rolling an OSERDESE2-based TMDS encoder
inside `block_design.tcl` is a substantially larger piece of RTL work
that needs its own review (see "Alternatives" below).

Bypassing the stop condition would have produced a half-finished BD,
no bit, no hwh, and a dirty working tree. The Phase 4 prompt explicitly
forbids that:

> Vivado build失敗
> bit/hwh不完全
> 何を変更したかわからない状態

are all on the `commit禁止条件` list.

## Alternatives (proposed only — not implemented)

These are options the user can choose between before re-running Phase 4.
All three keep the existing AudioLab DSP exactly as deployed.

### Alt-1 — install Digilent `vivado-library` locally (recommended)

1. `git clone https://github.com/Digilent/vivado-library.git
   /home/doi20/digilent-vivado-library` (this is a normal local clone
   into the user's home; the repo rule "do not clone reference repos
   into the tree" applies to *into the AudioLab repo*, which this would
   not be).
2. Add the clone path to `hw/Pynq-Z2/create_project.tcl` so that
   `set_property ip_repo_paths` includes it alongside `../ip`.
3. Re-run the Vivado IP probe; expect `digilentinc.com:ip:rgb2dvi:1.4`
   (or 1.5 depending on the library tag) to appear.
4. Rebuild the Phase 4A patch with `rgb2dvi:1.X` and re-validate the
   port names against the local IP version.
5. Re-run preflight, then continue Phase 4A.

This is the lowest-engineering path to a working HDMI TX block.

### Alt-2 — substitute a Xilinx-only TMDS encoder

Avoid `rgb2dvi` entirely. Implement a small RTL block that takes the
24-bit RGB + hsync/vsync from `v_axi4s_vid_out`, runs the TMDS-style
8b/10b encoding, and drives three pairs of OSERDESE2 primitives plus
one clock OSERDESE2. The PYNQ-Z2 single-ended LVCMOS33 board net is
compatible with this approach.

- Pros: no external IP catalog dependency.
- Cons: real RTL to write and verify, including OSERDESE2 timing
  closure at 371.25 MHz; non-trivial Phase 4 scope expansion.
- Risk: significantly higher timing risk than the audio domain's
  current `-8.155 ns` baseline allows for.
- Recommendation: not for the first Phase 4 pass.

### Alt-3 — drop to a much lower resolution custom path

Use 800x480@60 or 640x480@60 with a simple custom scanout RTL and a
self-contained TMDS encoder. Reduces pixel and serial clocks
(800x480@60 = 33.75 MHz pixel, ~168.75 MHz serial) and PL footprint,
at the cost of GUI fidelity and continued lack of `pynq.lib.video`
compatibility. Same engineering downside as Alt-2 plus the GUI
re-layout cost.

### Recommended next step

**Alt-1 (install Digilent `vivado-library`)** is the only one of the
three that is consistent with both the existing AudioLab build flow
(`create_project.tcl` already passes `ip_repo_paths`) and the Phase 3
architecture decision. The user should explicitly approve the local
clone outside the AudioLab tree, then a Phase 4 retry can pick up at
the `block_design.tcl` edit step.

## Phase 3 docs that need a correction before any retry

When Phase 4 retries, these Phase 3 docs need updates so the Vivado
build does not silently use wrong constants:

- `docs/ai_context/HDMI_BLOCK_DESIGN_TCL_PATCH_PLAN.md`:
  - The `v_tc:6.2` candidate VLNV should be changed to `v_tc:6.1`
    (that is what is in the local Vivado 2019.1 catalog).
  - The PYNQ-Z2 HDMI TX pin assignments must be replaced with the
    actual board nets (`L16/L17/K17/K18/K19/J19/J18/H18`), with
    IOSTANDARD `LVCMOS33`, not `TMDS_33` and not the
    `H16/H17/D19/D20/C20/B20/B19/A20` pins from the existing
    Phase 3 draft.
- `docs/ai_context/HDMI_GUI_PHASE3_VIVADO_DESIGN_PROPOSAL.md`:
  - Same `v_tc` version note.
  - Same XDC correction.

These corrections are NOT being applied in this stopped session,
to keep the diff zero across `git status`. They are recorded here for
the Phase 4 retry.

## Smoke / runtime state of the project

The Phase 2D runtime test result is still authoritative. No PYNQ-side
operation was repeated during Phase 4 preflight. The deployed
`audio_lab.bit` on the PYNQ-Z2 is unchanged.

## Working tree at stop time

```
?? GUI/README.md
?? HDMI/
?? docs/ai_context/HDMI_GUI_PHASE4_IMPLEMENTATION_RESULT.md   (this file)
```

Branch: `feature/hdmi-gui-phase4-vivado-integration`, tip = `7db1707`.
Tag: `before-hdmi-gui-phase4` at `7db1707`.
Backup: `/tmp/audio_lab_bit_backup_phase4_20260514_221716/`.

No `git push` / `git pull` / `git fetch` was performed.

Post-Phase-5C cleanup note: the historical untracked `GUI/README.md` was
replaced with current integrated-HDMI renderer documentation, and the
unused untracked `HDMI/` tree was backed up under
`/tmp/fpga_guitar_effecter_backup/` and removed after repo-wide reference
checks confirmed it was not used by deploy, tests, or runtime scripts.
