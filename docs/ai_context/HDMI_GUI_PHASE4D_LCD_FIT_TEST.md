# HDMI GUI Phase 4D LCD fit test

Date: 2026-05-15 JST

## Summary

User visual inspection confirmed that the Phase 4 HDMI output does appear
on the small HDMI LCD, but the native 1280x720 GUI frame is cropped by
the display. Phase 4D keeps the Vivado design, bitstream, VTC timing,
VDMA HSIZE/STRIDE/VSIZE, and HDMI IP configuration unchanged. The fix is
Python-side pre-scanout composition: render the 1280x720 RGB frame, scale
it down if requested, center it on a black 1280x720 RGB canvas, then copy
that canvas into the existing packed DDR `GBR888` framebuffer.

No Vivado rebuild was run. `audio_lab.bit` / `audio_lab.hwh` were not
regenerated and were not changed. `block_design.tcl`, `audio_lab.xdc`,
`create_project.tcl`, Clash/DSP, `topEntity`, GPIO names/addresses, and
HDMI IP topology were not changed.

## Cause Hypothesis

The most likely cause is LCD-side scaling / overscan / crop behavior:

- The AudioLab HDMI path outputs fixed 1280x720 timing.
- The GUI renderer fills the full 1280x720 canvas.
- The small LCD displays the signal, proving HDMI scanout is working,
  but does not show the entire active area.
- A Python letterbox/safe-area pass can compensate without touching
  the PL design.

## Fit Modes

`audio_lab_pynq.hdmi_backend.AudioLabHdmiBackend` now accepts named fit
modes through `start(..., fit_mode=...)` and
`write_frame(..., fit_mode=...)`.

| Mode | Scale | Scaled size | Offset |
| --- | ---: | ---: | ---: |
| `native` | `1.00` | `1280x720` | `(0, 0)` |
| `fit-97` | `0.97` | `1242x698` | `(19, 11)` |
| `fit-95` | `0.95` | `1216x684` | `(32, 18)` |
| `fit-90` | `0.90` | `1152x648` | `(64, 36)` |
| `fit-85` | `0.85` | `1088x612` | `(96, 54)` |
| `fit-80` | `0.80` | `1024x576` | `(128, 72)` |

`--scale FLOAT` is also supported for custom values in the `0.0..1.0`
range. Native mode remains backward compatible: it uses the existing
RGB888 -> DDR `GBR888` copy path with no resize/compose step.

## Test Pattern

New script: `scripts/test_hdmi_fit_frame.py`.

The generated 1280x720 test pattern includes:

- 1 px outer border.
- 10 px, 20 px, and 40 px inset borders.
- Colored edge bands.
- Corner labels: `TL`, `TR`, `BL`, `BR`.
- Center label and center crosshair.
- Horizontal / vertical grid.
- `1280x720` size text.
- Fit mode text.

The purpose is to let the user determine whether crop is coming from the
LCD and how much safe area is needed.

## Deploy

Only Python/script files were copied to the board:

- `audio_lab_pynq/hdmi_backend.py`
- `scripts/test_hdmi_static_frame.py`
- `scripts/test_hdmi_fit_frame.py`

The full deploy script was not used for Phase 4D because this task
explicitly required not overwriting bit/hwh during deploy. The board-side
bit/hwh files kept their existing sizes and timestamps:

- `hw/Pynq-Z2/bitstreams/audio_lab.bit`: `4,045,680` bytes
- `hw/Pynq-Z2/bitstreams/audio_lab.hwh`: `1,054,120` bytes

## Test Results

All tests loaded exactly one `AudioLabOverlay()`. No test loaded
`Overlay("base.bit")`, called `run_pynq_hdmi()`, or loaded a second
overlay. All tests reported ADC HPF `True`, `R19=0x23`,
`axi_gpio_delay_line=False`, legacy `axi_gpio_delay=True`, and HDMI IPs
present in `ip_dict`.

| Test | Result | Scale / placement | Resize/compose | Copy | VDMA errors |
| --- | --- | --- | ---: | ---: | --- |
| Pattern `native` | OK, 60s hold | `1280x720`, offset `(0,0)` | `0.000 s` | `0.208 s` | none |
| Pattern `fit-95` | OK, 60s hold | `1216x684`, offset `(32,18)` | `0.289 s` | `0.207 s` | none |
| Pattern `fit-90` | OK, 60s hold | `1152x648`, offset `(64,36)` | `0.266 s` | `0.207 s` | none |
| GUI `fit-90` | OK, 60s hold | `1152x648`, offset `(64,36)` | `0.265 s` | `0.207 s` | none |

GUI `fit-90` render time was `2.979 s`. Backend start including
framebuffer allocation, resize/compose, copy, VDMA programming, and VTC
start was `0.511 s`.

## HDMI Status

Common status across the Phase 4D runs:

- Framebuffer physical address: `0x16900000`.
- Framebuffer format: RGB888 input -> packed DDR `GBR888`.
- Framebuffer size: `2764800` bytes.
- VDMA HSIZE: `3840`.
- VDMA STRIDE: `3840`.
- VDMA VSIZE: `720`.
- `VDMACR`: `0x00010001`.
- `DMASR`: `0x00011000`.
- VDMA error bits: `dmainterr=False`, `dmaslverr=False`,
  `dmadecerr=False`, `halted=False`, `idle=False`.
- VTC status: `vtc_ctl=0x00000006`.

Codex cannot visually inspect the physical LCD. The verified claim is
healthy VDMA/VTC scanout with the requested frame composition. The final
choice of fit mode was later superseded by Phase 5A/5C output mapping:
the 5-inch LCD uses the top-left `800x480` framebuffer viewport rather
than a centered scaled 1280x720 fit mode.

## Historical recommendation

Start with `fit-90` for the small HDMI LCD. It gives a 64 px horizontal
and 36 px vertical safety margin while preserving the GUI's aspect ratio
and readability better than `fit-85` / `fit-80`.

If the LCD still clips the 40 px border or corner labels in `fit-90`,
try `fit-85`. If `fit-95` already shows every outer marker, it is the
less conservative choice and wastes less screen area.

Post-Phase-5C recommendation: use `scripts/test_hdmi_800x480_frame.py`
with `--variant compact-v2 --placement manual --offset-x 0 --offset-y 0`
for this 5-inch LCD. Keep fit modes only as diagnostics for other panels.

## User Visual Checklist

- In `native`, note which sides crop and roughly which inset border is
  first fully visible.
- In `fit-95`, check whether the outer border and all corner labels are
  visible.
- In `fit-90`, check whether the outer border and all corner labels are
  visible with comfortable margin.
- Confirm `TL` / `TR` / `BL` / `BR` all appear.
- Confirm the GUI top, bottom, left, and right edges are not cut off.
- Confirm color order looks correct.
- Confirm text remains readable.
- Confirm aspect ratio is not distorted.

## Remaining Work

- Default fit-mode selection is no longer the active path for this LCD;
  Phase 5C selected top-left 800x480 logical placement instead.
- Text size / layout are not redesigned yet; this phase only adds
  safe-area composition.
- HDMI hotplug / reconnect behavior is still untested.
- Phase 5 change-driven GUI loop is still not implemented.
