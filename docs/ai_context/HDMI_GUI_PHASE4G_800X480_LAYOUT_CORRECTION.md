# HDMI GUI Phase 4G 800x480 layout correction

Date: 2026-05-15 JST

## Summary

Phase 4E added an 800x480 logical GUI and centered it inside the fixed
1280x720 HDMI framebuffer. Phase 4F added manual non-negative offsets
and a viewport calibration pattern. On the user's 5-inch HDMI LCD the
GUI still appeared shifted to the right with a large blank strip on the
left. Two factors explain that:

1. The LCD samples only part of the 1280x720 framebuffer; the visible
   viewport is not centered on the framebuffer. To compensate, the
   logical frame has to move toward negative `offset_x` (and possibly
   negative `offset_y`), not only positive ones.
2. The Phase 4E `compact-v1` 800x480 layout used a 24 px inner safe
   margin and an inset card stack. Combined with the LCD's viewport
   cropping, the left side of the card stack landed off-panel and the
   user perceived "the GUI is on the right, with empty space on the
   left."

Phase 4G addresses both. No Vivado rebuild was run. `audio_lab.bit` and
`audio_lab.hwh` were not regenerated. `block_design.tcl`,
`audio_lab.xdc`, `create_project.tcl`, Clash / DSP, `topEntity`, GPIO
names / addresses, HDMI IP topology, VDMA HSIZE / STRIDE / VSIZE, and
VTC timing were not changed. Only Python / scripts / docs changed.

## compact-v2 layout

New renderer:

- `GUI.pynq_multi_fx_gui.render_frame_800x480_compact_v2(state, ...)`
- Selectable via `render_frame_800x480(state, variant="compact-v2",
  placement_label="...")`.
- Output shape `[480, 800, 3]` `uint8` RGB888.

Layout (all coordinates inside the 800x480 logical canvas):

| Region | Coords | Notes |
| --- | --- | --- |
| Outer chassis | `(12,12)`..`(788,468)` | Rounded fill + 2 px LED stroke |
| Header | `(24,20)`..`(776,100)` | PRESET id left, preset name center, status chip + `FX a/b` right |
| Signal chain | `(24,110)`..`(776,250)` | 8 cells, 2 px stroke, selected = 3 px, ON LED bar |
| Selected FX | `(24,260)`..`(392,454)` | FX name + `ON` / `BYPASS` chip + 4 knob rows |
| Monitor | `(408,260)`..`(776,454)` | Spectrum bars + `IN` / `OUT` meters |
| TL / TR / BL / BR | corners | 16 px L-shaped LED markers + text label |
| Variant tag | `(W/2, H-4)` | `v=compact-v2 [placement label]` |

Differences vs the Phase 4E `compact-v1` layout:

- Outer margin shrunk from 24 px to 12 px so the inner area is 776x456
  instead of ~752x432.
- Strokes are uniformly 2 px (3 px for the selected chain cell). 1 px
  decorative fills were dropped.
- Chain row width is full inner width; cells are wider so `NS`, `CMP`,
  `OD`, `DIST`, `AMP`, `CAB`, `EQ`, `RVB` are easier to read.
- Selected FX gets a hero label (`AMP SIM`) and a single full-row
  `ON` / `BYPASS` chip. Knob bars are wider and the value text is
  scaled up.
- Monitor uses 18 wider spectrum bars and two 16-segment IN / OUT
  meters with `IN` / `OUT` text labels at scale 2.
- TL / TR / BL / BR markers are drawn so a photo can verify whether all
  four corners of the logical frame reach the panel.
- The current variant and placement label are printed at the bottom
  edge so a photo also captures the offset.

The Phase 4E layout is kept as `compact-v1` so existing call sites and
tests are unaffected.

## Negative offset placement

`audio_lab_pynq.hdmi_backend.compose_logical_frame` already clipped the
destination region against the 1280x720 framebuffer. Phase 4G clarifies
and documents the negative-offset path and extends the meta dict so the
test scripts can log exactly which source pixels reach which destination
pixels.

Now allowed:

- `offset_x < 0` and / or `offset_y < 0`.
- Fully off-screen requests do not raise; they produce an empty copy.

Meta fields added:

- `negative_offset`: `True` if either requested offset is negative.
- `clipped`: `True` if the requested rectangle extends off any side of
  the 1280x720 framebuffer.
- `fully_offscreen`: `True` if no pixels are copied.
- `requested_destination_region`: the un-clipped requested rectangle
  before clamping.

`source_visible_region` and `framebuffer_copied_region` are unchanged
in shape. They report the actual source crop applied and the actual
framebuffer rectangle written.

Clipping math (verified by simulation against the 8 phase 4G offsets):

| Offset | Requested | Dst clipped | Src crop | Copied |
| --- | --- | --- | --- | --- |
| `( 0,  0)` | `(0,0)..(800,480)` | `(0,0)..(800,480)` | `(0,0)..(800,480)` | `800x480` |
| `(-80, 0)` | `(-80,0)..(720,480)` | `(0,0)..(720,480)` | `(80,0)..(800,480)` | `720x480` |
| `(-120, 0)` | `(-120,0)..(680,480)` | `(0,0)..(680,480)` | `(120,0)..(800,480)` | `680x480` |
| `(-160, 0)` | `(-160,0)..(640,480)` | `(0,0)..(640,480)` | `(160,0)..(800,480)` | `640x480` |
| `(-240, 0)` | `(-240,0)..(560,480)` | `(0,0)..(560,480)` | `(240,0)..(800,480)` | `560x480` |
| `(0, -40)` | `(0,-40)..(800,440)` | `(0,0)..(800,440)` | `(0,40)..(800,480)` | `800x440` |
| `(-120, -40)` | `(-120,-40)..(680,440)` | `(0,0)..(680,440)` | `(120,40)..(800,480)` | `680x440` |
| `(-160, -40)` | `(-160,-40)..(640,440)` | `(0,0)..(640,440)` | `(160,40)..(800,480)` | `640x440` |

## Single-frame test

`scripts/test_hdmi_800x480_frame.py` now takes:

- `--variant compact-v1 | compact-v2` (default `compact-v2`).
- `--placement center | manual` (default `manual`).
- `--offset-x` and `--offset-y` may be negative.
- `--hold-seconds` is unchanged.

It also prints a `placement_summary` block with input shape, requested
destination, source crop, framebuffer copy region, compose time,
framebuffer copy time, `clipped`, `negative_offset`, and `fully_offscreen`.

## Cycle script

New: `scripts/test_hdmi_800x480_cycle_offsets.py`.

- Loads `AudioLabOverlay()` exactly once.
- Renders the 800x480 logical frame with `variant="compact-v2"` and a
  per-offset `placement_label` so each photo identifies the offset.
- Cycles through the eight offsets `(0,0), (-80,0), (-120,0), (-160,0),
  (-240,0), (0,-40), (-120,-40), (-160,-40)`.
- Holds each offset for `--seconds-per-offset` (default `10`).
- Holds the last offset for `--hold-final-seconds` (default `30`).
- Records per-offset VDMA error bits, compose time, framebuffer copy
  time, and the source / destination regions.
- Does not load `base.bit`, does not load a second overlay, and does
  not call `run_pynq_hdmi()`.

CLI options:

- `--variant compact-v1 | compact-v2`.
- `--offsets "x,y;x,y;..."` to override the default sweep.

## PYNQ runs

Only these files were copied to the board (`scp`, not the full
`deploy_to_pynq.sh`):

- `audio_lab_pynq/hdmi_backend.py`
- `GUI/pynq_multi_fx_gui.py`
- `scripts/test_hdmi_800x480_frame.py`
- `scripts/test_hdmi_800x480_cycle_offsets.py`

Board-side bit / hwh sizes were verified before and after:

- `audio_lab.bit`: `4,045,680` bytes (May 14 16:21, unchanged).
- `audio_lab.hwh`: `1,054,120` bytes (May 14 16:21, unchanged).

### Single-frame run, compact-v2, manual `(0, 0)`

Command:

```sh
sudo env PYTHONUNBUFFERED=1 PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
  python3 scripts/test_hdmi_800x480_frame.py \
    --variant compact-v2 --placement manual \
    --offset-x 0 --offset-y 0 --hold-seconds 5
```

Result:

- `AudioLabOverlay()` loaded once. No `Overlay("base.bit")`, no second
  overlay, no `run_pynq_hdmi()`.
- ADC HPF `True`, `R19=0x23`, `axi_gpio_delay_line=False`, legacy
  `axi_gpio_delay=True`, `axi_gpio_noise_suppressor` and
  `axi_gpio_compressor` present.
- HDMI: `axi_vdma_hdmi` and `v_tc_hdmi` in `ip_dict`, `rgb2dvi_hdmi`
  and `v_axi4s_vid_out_hdmi` in HWH.
- Render `0.337 s` (cold), compose `0.026 s`, framebuffer copy
  `0.207 s`.
- `negative_offset=false`, `clipped=false`, `fully_offscreen=false`.
- `VDMACR=0x00010001`, `DMASR=0x00011000`, VDMA HSIZE / STRIDE `3840`,
  VSIZE `720`.
- VDMA error bits: `dmainterr=False`, `dmaslverr=False`,
  `dmadecerr=False`, `halted=False`, `idle=False`.
- `vtc_ctl=0x00000006`.
- Post-HDMI Safe Bypass smoke passed.

### Offset cycle run, compact-v2, eight placements

Command:

```sh
sudo env PYTHONUNBUFFERED=1 PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
  python3 scripts/test_hdmi_800x480_cycle_offsets.py \
    --seconds-per-offset 4 --hold-final-seconds 4
```

(Short hold times so the local validation completes quickly. The user
should re-run with `--seconds-per-offset 15 --hold-final-seconds 30` or
similar when photographing the panel.)

Per-offset measurements:

| Offset | Render | Compose | Copy | Clipped | Negative | VDMA errors |
| --- | ---: | ---: | ---: | --- | --- | --- |
| `(0,0)` | cache hit | `0.025 s` | `0.206 s` | `False` | `False` | none |
| `(-80,0)` | `0.093 s` | `0.025 s` | `0.206 s` | `True` | `True` | none |
| `(-120,0)` | `0.097 s` | `0.025 s` | `0.206 s` | `True` | `True` | none |
| `(-160,0)` | `0.093 s` | `0.025 s` | `0.206 s` | `True` | `True` | none |
| `(-240,0)` | `0.093 s` | `0.025 s` | `0.206 s` | `True` | `True` | none |
| `(0,-40)` | `0.097 s` | `0.025 s` | `0.206 s` | `True` | `True` | none |
| `(-120,-40)` | `0.093 s` | `0.025 s` | `0.206 s` | `True` | `True` | none |
| `(-160,-40)` | `0.093 s` | `0.025 s` | `0.206 s` | `True` | `True` | none |

(The cache key includes the placement label so each new label is a
cache miss. The label changes with offset, hence the ~0.09 s render at
every new offset. Render time is the bitmap composition; compose time
is the 800x480 -> 1280x720 placement; copy time is the
RGB-to-DDR-GBR swizzle.)

Common HDMI state across the cycle:

- `VDMACR=0x00010001`, `DMASR=0x00011000`.
- VDMA HSIZE / STRIDE `3840`, VSIZE `720`.
- `vtc_ctl=0x00000006`.
- Framebuffer physical address: `0x16900000`.
- VDMA error bits remained `none` for every offset.

Post-HDMI Safe Bypass smoke passed.

## Open user-visual decisions

The HDMI path is stable. The remaining choices need the physical panel:

- Which offset out of the eight tested makes the compact-v2 GUI fit the
  LCD best.
- Whether TL / TR / BL / BR corner markers are all visible at that
  offset.
- Whether the variant + offset tag at the bottom edge is visible.
- Whether IN / OUT meters, knob bars, and the chain row text are
  readable.
- Color order and aspect ratio.

Once the user picks a final offset, follow-up candidates:

1. Make the picked offset the default for the 5-inch LCD path and
   document the rationale in `HDMI_GUI_INTEGRATION_PLAN.md`.
2. Add a partial framebuffer copy that writes only the clipped
   destination region instead of the full 1280x720 swizzle.
3. Build the Phase 5 change-driven update loop on top of compact-v2.
4. Promote compact-v2 to the default 800x480 variant once the LCD path
   is calibrated.
