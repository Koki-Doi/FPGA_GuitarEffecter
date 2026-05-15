# HDMI GUI Phase 4H vertical margin + horizontal layout diagnosis

Date: 2026-05-15 JST

## Summary

Phase 4G shipped the compact-v2 800x480 renderer and negative-offset
placement. User visual feedback on the 5-inch HDMI LCD after Phase 4G
was:

- The top edge of the GUI is slightly clipped.
- The horizontal direction does NOT overflow.
- The left side of the panel shows either an invisible area or a
  cosmetically empty strip.
- Conclusion: `offset_x` correction is the wrong tool for the left-side
  symptom; the right tool is to diagnose the renderer / viewport on
  that axis.

Phase 4H is Python-only. No Vivado rebuild. No `audio_lab.bit` or
`audio_lab.hwh` change. No `block_design.tcl`, `audio_lab.xdc`,
`create_project.tcl`, Clash / DSP, `topEntity`, GPIO names / addresses,
HDMI IP topology, VDMA HSIZE / STRIDE / VSIZE, or VTC timing change.

## Compact-v2 layout tuning

The compact-v2 800x480 renderer now exposes its layout as a module-
level dictionary:

```python
COMPACT_V2_LAYOUT = {
    "outer": (12, 30, 788, 470),
    "left": 18,
    "right": 18,
    "header_y": (44, 118),
    "chain_y": (128, 258),
    "bottom_y": (268, 458),
    "variant_label_y": 472,
}
```

Compared with Phase 4G:

| Field | Phase 4G | Phase 4H | Why |
| --- | --- | --- | --- |
| Outer top | `y=12` | `y=30` | Push chassis frame down so the LCD can crop ~20-30 px at the top without clipping the header |
| Outer bottom | `y=468` | `y=470` | Use the same vertical budget on the bottom edge for symmetry |
| Header band | `y=20..100` | `y=44..118` | Header starts below the LCD top-crop band |
| Chain band | `y=110..250` | `y=128..258` | Fit chain just under the lowered header |
| Bottom band | `y=260..454` | `y=268..458` | Fit FX / monitor below the lowered chain |
| Panel left | `x=24` | `x=18` | Use the left strip of the canvas; the user reported it as "unused" on the panel |
| Panel right | `x=Wv-24` | `x=Wv-18` | Symmetrical right margin |
| Variant label `y` | `Hv-4` | `472` | Stays inside the outer chassis |
| Inset "safe corner" marks | none | LED-soft 22 px L-shapes at the outer rectangle corners | A photo can tell whether the chassis itself reaches the panel even when canvas corners are cropped |

Canvas-edge TL / TR / BL / BR markers and text are unchanged; they are
intentionally at `y=2..18` so the user can still see whether the
absolute canvas edge reaches the panel.

`compact_v2_panel_boxes(width=800, height=480)` is a new public helper
that returns the panel bboxes (`outer`, `header`, `chain`, `fx`, `side`)
keyed by name. The layout-debug script uses it directly so the on-LCD
bboxes always match the rendered layout.

## Layout-debug overlay

New `scripts/test_hdmi_800x480_layout_debug.py` composites a diagnostic
overlay on top of the compact-v2 frame:

- 50 px grid covering the whole 800x480 canvas, with stronger lines
  every 100 px.
- White rectangle outline at the absolute canvas border
  `(0,0)..(800,480)`.
- `x{0,100,200,...,800}` labels on the top and bottom edges.
- `y{0,100,200,...,480}` labels on the left and right edges.
- Coloured panel bboxes from `compact_v2_panel_boxes` (`outer` red,
  `header` cyan, `chain` green, `fx` amber, `side` purple). Each bbox
  shows its `(x0,y0)` and `(x1,y1)` corners.
- A red `LEFT STRIP x=0..100` band for the area the user reported as
  unused / invisible.
- A cyan `TOP STRIP y=0..40` band for the area the user reported as
  slightly clipped.
- Footer `debug=layout variant=compact-v2 offset=(+0,+0) canvas=800x480`.

The script loads `AudioLabOverlay()` exactly once, never loads
`base.bit`, never loads a second overlay, and never calls
`run_pynq_hdmi()`. It accepts `--offset-x` and `--offset-y` so the
overlay can be reused after picking a vertical offset.

## Vertical-only offset sweep

New `scripts/test_hdmi_800x480_vertical_offsets.py` keeps
`offset_x = 0` and walks `offset_y` through `[0, 10, 20, 30, 40, 50]`
(configurable via `--offsets-y "0,10,20,30,40,50"`). Each step:

- Re-renders compact-v2 with a fresh `placement_label` that prints the
  current offset.
- Writes the frame through `AudioLabHdmiBackend.write_frame(..., 
  placement="manual", offset_x=0, offset_y=oy)`.
- Records VDMA error bits, compose time, framebuffer copy time, and
  the source / destination regions.

`--seconds-per-offset` controls per-step hold time (default 10).
`--hold-final-seconds` parks on the last offset for a longer photo
window (default 30). `--offset-x` is allowed for symmetry but emits a
warning if non-zero because Phase 4H's working hypothesis is that
horizontal correction is not the right tool.

## test_hdmi_800x480_frame.py defaults

The single-frame test script still defaults to `--variant compact-v2
--placement manual --offset-x 0 --offset-y 0`. After the LCD viewport
is calibrated, the recommended path is:

1. Run the layout-debug script first to confirm what the LCD's visible
   viewport is and which logical (x, y) range reaches the panel.
2. Run the vertical-offset sweep to pick the best `offset_y`.
3. Once `offset_y` is decided (initial recommended range based on the
   Phase 4G top-clip observation is `20..30`), invoke the single-frame
   script with that value, e.g.

   ```sh
   sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
     python3 scripts/test_hdmi_800x480_frame.py \
       --variant compact-v2 --placement manual \
       --offset-x 0 --offset-y 30 --hold-seconds 60
   ```

`--offset-x` is deliberately kept at `0` for Phase 4H so the
horizontal direction stays a layout question, not a placement question.

## PYNQ runs

Only Python / scripts were copied to the board with `scp`. The full
`deploy_to_pynq.sh` was not used so `audio_lab.bit` / `audio_lab.hwh`
were not regenerated, packaged, or transferred. Board-side sizes
verified before and after:

- `audio_lab.bit`: `4,045,680` bytes (`May 14 16:21`, unchanged).
- `audio_lab.hwh`: `1,054,120` bytes (`May 14 16:21`, unchanged).

Single overlay rule: every run loaded `AudioLabOverlay()` once and did
not call `Overlay("base.bit")`, `run_pynq_hdmi()`, or load a second
overlay.

### Layout-debug run

Command:

```sh
sudo env PYTHONUNBUFFERED=1 PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
  python3 scripts/test_hdmi_800x480_layout_debug.py \
    --offset-y 0 --hold-seconds 5
```

Result:

- ADC HPF `True`, `R19=0x23`, legacy `axi_gpio_delay=True`,
  `axi_gpio_delay_line=False`, HDMI IPs present in `ip_dict` / HWH.
- Base compact-v2 render `0.336 s` (cold).
- Overlay compose `0.204 s`.
- Backend start `0.266 s`.
- Framebuffer copy `0.207 s`.
- `VDMACR=0x00010001`, `DMASR=0x00011000`, HSIZE / STRIDE `3840`,
  VSIZE `720`, `vtc_ctl=0x00000006`.
- VDMA error bits: none.
- Panel bboxes printed:
  `outer (12,30)..(788,470)`,
  `header (18,44)..(782,118)`,
  `chain (18,128)..(782,258)`,
  `fx (18,268)..(394,458)`,
  `side (406,268)..(782,458)`.
- Post Safe Bypass smoke OK.

### Vertical offset sweep

Command:

```sh
sudo env PYTHONUNBUFFERED=1 PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
  python3 scripts/test_hdmi_800x480_vertical_offsets.py \
    --seconds-per-offset 3 --hold-final-seconds 3
```

(Short hold for local validation. User should rerun with
`--seconds-per-offset 15 --hold-final-seconds 30` for the actual
panel photo session.)

| `offset_y` | Render | Compose | Copy | Clipped | VDMA errors |
| ---: | ---: | ---: | ---: | --- | --- |
| `0` | cache hit | `0.025 s` | `0.206 s` | `False` | none |
| `10` | `0.092 s` | `0.025 s` | `0.206 s` | `False` | none |
| `20` | `0.094 s` | `0.025 s` | `0.206 s` | `False` | none |
| `30` | `0.092 s` | `0.025 s` | `0.206 s` | `False` | none |
| `40` | `0.091 s` | `0.026 s` | `0.206 s` | `False` | none |
| `50` | `0.097 s` | `0.025 s` | `0.206 s` | `False` | none |

`clipped=False` for every offset because `offset_x=0, offset_y in
{0..50}` keeps the 800x480 frame inside the 1280x720 framebuffer
(`requested_destination_region` ends at `y <= 530 < 720`).

Common state across the sweep:

- `VDMACR=0x00010001`, `DMASR=0x00011000`.
- HSIZE / STRIDE `3840`, VSIZE `720`, `vtc_ctl=0x00000006`.
- VDMA error bits: none.
- Framebuffer physical address: `0x16900000`.
- Post Safe Bypass smoke OK.

### Single-frame at offset_y = 30

Command:

```sh
sudo env PYTHONUNBUFFERED=1 PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
  python3 scripts/test_hdmi_800x480_frame.py \
    --variant compact-v2 --placement manual \
    --offset-x 0 --offset-y 30 --hold-seconds 5
```

Result:

- `negative_offset=False`, `clipped=False`, `fully_offscreen=False`.
- Compose `0.025 s`, framebuffer copy `0.207 s`.
- `VDMACR=0x00010001`, `DMASR=0x00011000`, `vtc_ctl=0x00000006`.
- VDMA error bits: none.
- Post Safe Bypass smoke OK.

## Open user-visual decisions

The HDMI path is stable. The remaining choices need the panel:

1. Is the top edge no longer clipping the header at `offset_y=0` thanks
   to the Phase 4H top safe margin alone, or is a `+offset_y` still
   needed? Compare `offset_y in {0, 10, 20, 30}` photos.
2. Does the LEFT STRIP x=0..100 actually reach the LCD viewport? The
   layout-debug overlay's red strip + `x100` label answer this in one
   photo.
3. Are `header`, `chain`, `fx`, `side` bboxes fully visible at the
   chosen `offset_y`?
4. Do TL / TR / BL / BR markers reach the panel, or are only the
   inset LED-soft "safe corner" marks visible?

If the LEFT STRIP is actually invisible on the LCD, the right next
step is still NOT to apply `offset_x > 0`; instead it points to the
panel cropping its left edge, which would be confirmed by the
layout-debug photo and then addressed either by an HDMI timing /
panel-driver change (out of scope here, would require LCD-side work)
or by moving non-critical compact-v2 content out of `x=0..100` while
keeping critical content centred. If the LEFT STRIP is visible but
empty, the compact-v2 panel left margin can be reduced further in a
future pass, again without offset_x.

Candidate next steps after the panel photos are reviewed:

- Bake the chosen `offset_y` into the compact-v2 default placement.
- Promote compact-v2 to be the default 800x480 variant.
- Add a partial framebuffer copy that writes only the visible logical
  region instead of the full 1280x720 swizzle (currently `~0.207 s`
  per frame).
- Build the Phase 5 change-driven update loop on top of compact-v2.
