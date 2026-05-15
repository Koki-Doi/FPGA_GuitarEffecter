# HDMI GUI Phase 4F viewport calibration

Date: 2026-05-15 JST

## Summary

Phase 4E added an 800x480 logical GUI and placed it in the center of the
fixed 1280x720 HDMI framebuffer at offset `(240,120)`. User visual
feedback on the 5-inch HDMI LCD showed that this centered placement
appears strongly shifted to the right. If the LCD were scaling the full
1280x720 framebuffer uniformly, the centered 800x480 frame would appear
centered. The observed shift therefore points to LCD-side cropping or
non-uniform viewport sampling rather than a simple whole-frame scale.

Phase 4F keeps the HDMI signal, VDMA configuration, Vivado design, and
bitstream unchanged. It adds Python-side manual logical placement so the
800x480 frame can be moved to the portion of the 1280x720 framebuffer
that the LCD actually shows.

No Vivado rebuild was run. `audio_lab.bit` / `audio_lab.hwh` were not
regenerated or copied to the board. `block_design.tcl`, `audio_lab.xdc`,
`create_project.tcl`, Clash/DSP, `topEntity`, GPIO names/addresses, HDMI
IP topology, VDMA HSIZE/STRIDE/VSIZE, and VTC timing were not changed.

## Cause Hypothesis

- If the LCD scaled the complete 1280x720 framebuffer to its physical
  panel, the Phase 4E center placement `(240,120)` would look centered.
- The actual LCD view is shifted right when using that center placement.
- The LCD is likely cropping the 1280x720 signal or sampling a viewport
  that does not correspond to the full framebuffer.
- Therefore logical frame placement must be offset-configurable instead
  of hard-coded to center.

## Manual Placement API

`audio_lab_pynq.hdmi_backend.AudioLabHdmiBackend` now supports:

```python
backend.write_frame(frame_800x480, placement="manual", offset_x=0, offset_y=0)
backend.start(frame_800x480, placement="manual", offset_x=80, offset_y=40)
backend.write_logical_frame(frame_800x480, placement="manual", offset_x=120, offset_y=60)
```

Supported placement modes:

| Placement | Behavior |
| --- | --- |
| `center` | Existing Phase 4E behavior. 800x480 -> `(240,120)`. |
| `manual` | Use caller-provided `offset_x` / `offset_y`; default is `(0,0)`. |

Manual placement is clipped safely if the requested frame extends outside
the 1280x720 framebuffer. The backend logs the requested offset, source
visible region, framebuffer copied region, compose time, and copy time in
`last_frame_write`.

The framebuffer remains 1280x720 RGB888 input -> packed DDR `GBR888`.
VDMA remains HSIZE `3840`, STRIDE `3840`, VSIZE `720`.

## Calibration Pattern

New script:

```sh
scripts/test_hdmi_viewport_calibration.py --hold-seconds 60
```

Pattern contents:

- 1280x720 full-framebuffer coordinate grid.
- X labels at `0, 100, 200, ... 1280`.
- Y labels at `0, 100, 200, ... 720`.
- Framebuffer corner labels: `FB TL 0,0`, `FB TR 1280,0`,
  `FB BL 0,720`, `FB BR 1280,720`.
- Center marker: `FB CENTER 640,360`.
- Multiple 800x480 candidate frames:
  - offset `(0,0)`
  - offset `(120,60)`
  - center offset `(240,120)`
  - offset `(320,120)`

The user should read the visible top-left and bottom-right coordinates on
the LCD, then choose the 800x480 offset whose frame best matches the
physical visible viewport.

## PYNQ Runs

Only these Python/script files were copied to the board:

- `audio_lab_pynq/hdmi_backend.py`
- `scripts/test_hdmi_800x480_frame.py`
- `scripts/test_hdmi_viewport_calibration.py`

Board-side bit/hwh sizes remained unchanged:

- `audio_lab.bit`: `4,045,680` bytes.
- `audio_lab.hwh`: `1,054,120` bytes.

All runs loaded `AudioLabOverlay()` once. No `Overlay("base.bit")`, no
`run_pynq_hdmi()`, and no second overlay load were used.

### Viewport Calibration

Command:

```sh
sudo env PYTHONUNBUFFERED=1 PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
  python3 scripts/test_hdmi_viewport_calibration.py --hold-seconds 60
```

Result:

- `AudioLabOverlay()` load OK.
- ADC HPF `True`.
- `R19=0x23`.
- `axi_gpio_delay_line=False`.
- legacy `axi_gpio_delay=True`.
- `axi_vdma_hdmi` and `v_tc_hdmi` present.
- Pattern draw time `0.211 s`.
- Backend start `0.240 s`.
- Framebuffer `0x16900000`.
- `VDMACR=0x00010001`.
- `DMASR=0x00011000`.
- VDMA error bits: none.
- VTC `0x00000006`.
- Native full-frame copy `0.208 s`.
- Physical coordinate reading was superseded by the Phase 5A output
  mapping test; Phase 5C adopts `x=0,y=0,w=800,h=480` as the default
  visible viewport.

### 800x480 Manual Offset Tests

| Offset | Render | Compose | Copy | Copied region | Result |
| --- | ---: | ---: | ---: | --- | --- |
| `(0,0)` | `0.316 s` | `0.025 s` | `0.207 s` | `x=0..800, y=0..480` | OK, no VDMA errors |
| `(80,40)` | `0.315 s` | `0.025 s` | `0.207 s` | `x=80..880, y=40..520` | OK, no VDMA errors |
| `(120,60)` | `0.315 s` | `0.025 s` | `0.207 s` | `x=120..920, y=60..540` | OK, no VDMA errors |

Common status:

- `VDMACR=0x00010001`.
- `DMASR=0x00011000`.
- VDMA error bits: none.
- VDMA HSIZE/STRIDE `3840`, VSIZE `720`.
- VTC `0x00000006`.
- Framebuffer `0x16900000`.
- Post-HDMI Safe Bypass smoke passed.

## Interpretation

The HDMI framebuffer path remains stable for all tested offsets. The
right-shifted Phase 4E center placement is not a VDMA or VTC error; it is
a physical-display viewport issue. Phase 4F provides the calibration
pattern and manual placement controls needed to select a per-LCD offset.
Phase 5C later resolved the current 5-inch LCD default as `(0,0)`.

Initial decision guide:

- If `(0,0)` fits best, the LCD is effectively showing a left/top crop of
  the 1280x720 framebuffer.
- If `(80,40)` fits best, the LCD has a light viewport offset/overscan.
- If `(120,60)` fits best, the LCD has a medium viewport offset.
- If none fit, HDMI timing or the LCD controller's 720p sampling behavior
  is likely the next suspect.

## Remaining Work

- User visual choice is complete for the current 5-inch LCD:
  `offset_x=0`, `offset_y=0`.
- Future panels may still use this calibration script to choose a
  different offset.
- Color order and aspect ratio remain user visual checks.
- The default for the 5-inch LCD path is now Phase 5C compact-v2 at
  `placement=manual`, `offset_x=0`, `offset_y=0`.
- Phase 5 can then build the change-driven GUI loop on top of the
  calibrated 800x480 logical mode.
