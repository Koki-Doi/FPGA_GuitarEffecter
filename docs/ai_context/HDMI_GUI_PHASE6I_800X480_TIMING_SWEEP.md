# HDMI GUI Phase 6I 800x480 Timing Sweep

Date: 2026-05-16

## Reason

Phase 6H deployed a `40.000 MHz` native 800x480 timing
(`H total 1056`, `V total 628`). On the actual 5-inch LCD the
screen rendered as fully white. AudioLabOverlay loaded fine, the
VDMA and VTC reported no error bits, the Python framebuffer probe
landed in `0..799 x 0..479`, but the LCD receiver / scaler did
not lock onto the timing.

The Phase 6H bit/hwh and `hw/Pynq-Z2/hdmi_integration.tcl` change
were therefore **not committed**. The Phase 6I sweep documents
that rejection and tries a small set of safer 800x480 candidates
one at a time, keeping the working `74.250 MHz / 1280x720` path
as the rollback target.

## Rollback target (working baseline)

Restored from `HEAD` (`d7ea0ab`):

- Active: `1280x720` (with the 800x480 compact-v2 UI placed at
  framebuffer `x=0, y=0` via
  `AudioLabHdmiBackend.write_frame(..., placement="manual",
   offset_x=0, offset_y=0)`).
- Pixel clock: `74.250 MHz`.
- H: `fp 110, sync 40, bp 220, total 1650`.
- V: `fp 5, sync 5, bp 20, total 750`.
- VDMA: `HSIZE 3840, STRIDE 3840, VSIZE 720`.
- `rgb2dvi_hdmi`: `kClkRange=3`.

PYNQ rollback backup of this baseline lives at
`/home/xilinx/Audio-Lab-PYNQ/backups/phase6h_720p/`.

## Rejected: 6H 40MHz / 1056x628

- name: `800x480_40M_1056x628`
- pixel clock: `40.000 MHz`
- H: `active 800, fp 40, sync 128, bp 88, total 1056`,
  `sync start/end 840/968`
- V: `active 480, fp 13, sync 3, bp 132, total 628`,
  `sync start/end 493/496`
- `rgb2dvi_hdmi`: `kClkRange=3`
- LCD: white screen (no useful image)
- VDMA / VTC: no error bits
- status: **rejected**, not committed

Failed bit/hwh archived at
`/tmp/fpga_guitar_effecter_backup/phase6h_failed_white_screen/`.

## rgb2dvi pixel-clock floor

`rgb2dvi v1.4` with `kClkRange=3` requires the internal PLLE2 VCO to
land between `800 MHz` and `1600 MHz`. The IP's fixed internal multiplier
is M=20, so the valid pixel-clock band for `kClkRange=3` is roughly
`40..80 MHz`. The Phase 6H 40 MHz attempt and the working 720p
74.25 MHz both sit inside that band; the originally planned `33.333`,
`33.000`, and `27.000` MHz candidates fall below the lower edge and
were rejected by route DRC. The Phase 6I sweep therefore moves to
higher pixel-clock variants of 800x480 (and a SVGA fallback) that
still synthesize without touching Digilent `rgb2dvi` source.

## Planned candidates

Each candidate is built individually. After each Vivado build the
bit/hwh deploys to PYNQ, the rollback smoke
(`scripts/test_hdmi_800x480_origin_guard.py`) runs, and the user
inspects the LCD.

A candidate is accepted only if:

- AudioLabOverlay loads.
- `ADC HPF True`, `R19 == 0x23`.
- `axi_vdma_hdmi`, `v_tc_hdmi`, `rgb2dvi_hdmi` present.
- VDMA error bits all zero.
- LCD shows a usable, non-white, non-blank image with the
  compact-v2 UI in (or near) the visible 800x480 region.

### Candidate C2 (tried first): SVGA 800x600 @ 60 Hz, 40 MHz

- Standard VESA DMT mode that most HDMI scalers recognise.
- pixel clock: `40.000 MHz`
- H: `active 800, fp 40, sync 128, bp 88, total 1056`,
  sync start/end `840/968`
- V: `active 600, fp 1, sync 4, bp 23, total 628`,
  sync start/end `601/605`
- rgb2dvi `kClkRange=3`, VCO `= 40 * 20 = 800 MHz` (at edge).
- VDMA: `HSIZE 2400, STRIDE 2400, VSIZE 600`.
- backend `DEFAULT_WIDTH=800, DEFAULT_HEIGHT=600`. The compact-v2
  GUI is composed at framebuffer `(0, 0)` so the visible UI lives in
  rows `0..479`; rows `480..599` stay black. The LCD's HDMI receiver
  may letterbox, crop, or downscale the 600 lines to its 480-line
  panel; that scaler behaviour is the unknown the candidate tests.

### Candidate A2 (fallback if C2 rejected): 800x480 native, 50 MHz

- pixel clock: `50.000 MHz`
- H: `active 800, fp 200, sync 80, bp 200, total 1280`,
  sync start/end `1000/1080`
- V: `active 480, fp 50, sync 5, bp 116, total 651`,
  sync start/end `530/535`
- Refresh: `50e6 / (1280 * 651) ≈ 60.01 Hz`.
- rgb2dvi `kClkRange=3`, VCO `= 50 * 20 = 1000 MHz`.
- VDMA: `HSIZE 2400, STRIDE 2400, VSIZE 480`.
- backend `DEFAULT_WIDTH=800, DEFAULT_HEIGHT=480`.

### Candidate B2 (fallback if A2 rejected): 800x480 native, 60 MHz

- pixel clock: `60.000 MHz`
- H: `active 800, fp 200, sync 80, bp 200, total 1280`,
  sync start/end `1000/1080`
- V: `active 480, fp 80, sync 10, bp 211, total 781`,
  sync start/end `560/570`
- Refresh: `60e6 / (1280 * 781) ≈ 60.0 Hz`.
- rgb2dvi `kClkRange=3`, VCO `= 60 * 20 = 1200 MHz`.
- VDMA: `HSIZE 2400, STRIDE 2400, VSIZE 480`.
- backend `DEFAULT_WIDTH=800, DEFAULT_HEIGHT=480`.

### Candidate D (fallback only): 720p + LCD-aware UI profile

- Used only if C2, A2, B2 all fail.
- Keeps the working `1280x720 / 74.250 MHz` path.
- Adds a per-LCD UI profile so the compact-v2 layout fits the
  LCD's actual visible region without touching `offset_x` /
  `offset_y` in the backend.

## Results table

Updated as each candidate completes.

| Candidate | Active | Pixel clock | H total | V total | VCO | WNS | TNS | LUT % | Reg % | LCD result | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 6H_40M_1056x628 | 800x480 | 40.000 | 1056 | 628 | 800 | n/r | n/r | n/r | n/r | white screen | rejected |
| original A_33M3_928x525 | 800x480 | 33.333 | 928 | 525 | 667 | route fail | n/a | n/a | n/a | n/a | rejected (rgb2dvi VCO) |
| original B_33M_1056x525 | 800x480 | 33.000 | 1056 | 525 | 660 | route fail | n/a | n/a | n/a | n/a | rejected (rgb2dvi VCO) |
| original C_27M_900x500 | 800x480 | 27.000 | 900 | 500 | 540 | route fail | n/a | n/a | n/a | n/a | rejected (rgb2dvi VCO) |
| **C2_40M_svga800x600** | **800x600** | **40.000** | **1056** | **628** | **800** | **-8.096** | **-6389** | **35.00** | **19.59** | **UI visible, left-aligned, clear improvement** | **accepted** |
| A2_50M_800x480_1280x651 | 800x480 | 50.000 | 1280 | 651 | 1000 | n/r | n/r | n/r | n/r | not tried (C2 succeeded) | superseded |
| B2_60M_800x480_1280x781 | 800x480 | 60.000 | 1280 | 781 | 1200 | n/r | n/r | n/r | n/r | not tried (C2 succeeded) | superseded |

## Accepted candidate: C2 SVGA 800x600 @ 40 MHz

`v_tc_hdmi` `GEN_ACTSZ = 0x02580320` (V=600, H=800) ✓.
VDMA `HSIZE=2400, STRIDE=2400, VSIZE=600`; VDMA error bits all zero.
`AudioLabOverlay` loads, ADC HPF `True`, R19 `0x23`. Compact-v2 UI
renders at framebuffer `(0, 0)` in the 800x600 framebuffer; the bottom
120 rows stay black. The 5-inch LCD's HDMI receiver locks onto the
standard VESA SVGA mode and the on-screen UI is no longer shifted
right.

PL timing delta vs the deployed HDMI Phase 4 baseline
(`WNS -8.163 ns / TNS -6599.061 ns`):

- WNS `-8.163 → -8.096 ns` (improves by 0.067 ns).
- TNS `-6599.061 → -6389.430 ns` (improves by 210 ns).
- WHS `+0.051 → +0.040 ns`; THS `0.000 ns` (hold remains clean).
- Slice LUTs `18619 → 18618` (-1); Slice Registers `20846 → 20846`
  (unchanged).
- Inter-clock CDC paths `clk ↔ bclk` retain the historical small
  negative slack already present in baseline.

Within the historical -7..-9 ns deploy band; deployable per
`docs/ai_context/TIMING_AND_FPGA_NOTES.md` gating.

## Build / deploy gotchas discovered

1. **`v_tc:6.1` `VIDEO_MODE` gates `GEN_*` params** — without a prior
   `set_property -dict { CONFIG.VIDEO_MODE {Custom} ... }` pass, every
   `CONFIG.GEN_HACTIVE_SIZE` / `GEN_VACTIVE_SIZE` / `GEN_HSYNC_*`
   override is silently ignored. The bit then runs at the original
   `1280x720p` preset regardless of the tcl. Memory:
   `vtc-video-mode-gating`.
2. **`GEN_F0_VBLANK_HSTART` / `GEN_F0_VBLANK_HEND`** carry over from
   the previous preset (e.g. 1280 from `1280x720p`) and exceed
   `GEN_HFRAME_SIZE`. Set both to `HDMI_ACTIVE_W` explicitly so the
   IP emits a clean `vblank` waveform.
3. **`GEN_CHROMA_PARITY`** does not exist on `v_tc:6.1`. Use
   `GEN_CPARITY` if you need it; otherwise drop it.
4. **Three bit/hwh copies on the PYNQ** — `hw/Pynq-Z2/bitstreams/`,
   `audio_lab_pynq/bitstreams/` under the repo, and
   `/usr/local/lib/python3.6/dist-packages/audio_lab_pynq/bitstreams/`.
   `AudioLabOverlay` loads whichever sits next to the `audio_lab_pynq`
   package that `PYTHONPATH` happens to resolve first. All three must
   be synced on every deploy or rollback. Memory:
   `pynq-site-packages-bit-cache`.

## Constraints

- No `git push`, `git pull`, `git fetch`.
- No `git reset --hard`, `git clean`.
- Failed candidates' `bit/hwh` are not committed.
- DSP / Clash / `LowPassFir.hs` / `topEntity` are not changed.
- GPIO addresses, names, and `ctrlA..D` semantics unchanged.
- Audio DSP chain unchanged.
- GUI layout unchanged.
- No `Overlay("base.bit")`, no second overlay after AudioLab,
  no `run_pynq_hdmi()`.
- No `offset_x` / `offset_y` correction in the backend.

## Backups

- Pre-Phase 6I working tree diff:
  `/tmp/fpga_guitar_effecter_backup/phase6i_before_rollback_and_timing_sweep.patch`
- Pre-Phase 6I `git status`:
  `/tmp/fpga_guitar_effecter_backup/phase6i_before_rollback_and_timing_sweep_status.txt`
- Failed Phase 6H `bit/hwh` and supporting files:
  `/tmp/fpga_guitar_effecter_backup/phase6h_failed_white_screen/`
- PYNQ working 720p backup:
  `/home/xilinx/Audio-Lab-PYNQ/backups/phase6h_720p/`
