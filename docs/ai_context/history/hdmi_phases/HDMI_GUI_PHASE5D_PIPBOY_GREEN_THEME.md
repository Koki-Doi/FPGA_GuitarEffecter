# HDMI GUI Phase 5D -- Pip-Boy-inspired phosphor green theme

Phase 5D adds a "phosphor green monochrome CRT" colour palette and a
soft horizontal scanline overlay to the 800x480 compact-v2 renderer
used on the 5-inch HDMI LCD. The look is inspired by black-green CRT
terminals (Pip-Boy style) but is intentionally generic: **no logos,
fonts, icons, screen text, or layout patterns from any specific game
are copied**. Phase 5D only retunes colours and adds a vectorised
scanline blend.

## What did not change

- `hw/Pynq-Z2/block_design.tcl`
- `hw/Pynq-Z2/audio_lab.xdc`
- `hw/Pynq-Z2/create_project.tcl`
- `hw/Pynq-Z2/bitstreams/audio_lab.bit`
- `hw/Pynq-Z2/bitstreams/audio_lab.hwh`
- `hw/ip/clash/src/LowPassFir.hs`, generated VHDL, packaged IP
- `audio_lab_pynq/hdmi_backend.py` (VDMA / framebuffer layout)
- 800x480 logical layout / panel rectangles
  (`compact_v2_panel_boxes`)
- offset_x / offset_y default (0, 0)
- The `compact-v1` 800x480 path. It still uses the pre-Phase-5D cyan
  look so any prior tooling that pinned that variant stays
  pixel-stable.
- The 1280x720 renderer (`render_frame_fast` etc.). Phase 5D applies
  the new palette **only** through the compact-v2 800x480 path.

## What changed (code)

| File | Change |
| --- | --- |
| `GUI/pynq_multi_fx_gui.py` | New `_make_theme(...)` helper, `CYAN_THEME` (legacy), `PIPBOY_THEME` (Phase 5D), `THEMES` dict, `DEFAULT_800X480_THEME = "pipboy-green"`, `resolve_theme()`, `_apply_scanlines_inplace()`. `_render_frame_800x480_compact_v2` now takes a `theme` kwarg, aliases palette colours to local names, and reads every previously-literal RGB tuple from the active palette. `render_frame_800x480` and `render_frame_800x480_compact_v2` forward the new `theme` kwarg. |
| `scripts/test_hdmi_800x480_frame.py` | New `--theme {pipboy-green, cyan}` flag (default `pipboy-green`); the report dict now records the theme name; phase tag is `5D-pipboy-green-theme`. |

The frame cache key includes the theme name, so swapping themes does
not return a stale cached frame.

## Palette summary

Both themes share the same compact-v2 layout coordinates. The Phase 5D
palette key list (each maps to an RGB or RGBA tuple):

```
LED, LED_SOFT, LED_DIM, LED_DEEP, LED_GHOST
SCR_TEXT, SCR_TEXT_DIM, SCR_TEXT_DEAD, SCR_GRID
INK_HI, INK_MID, INK_LO
WARN_AMBER, BYPASS_COL
BG_GRAD                       # gradient stops for the background
CHASSIS_INNER_FILL            # outer panel inner fill
PANEL_HEADER_FILL             # header / chain / fx panel fills
PANEL_CHAIN_FILL
PANEL_FX_FILL
HEADER_CHIP_FILL              # status chip in the header
FX_CHIP_FILL                  # ON/BYPASS chip in the fx panel
CHAIN_ON_FILL                 # chain cell fills for on / off
CHAIN_OFF_FILL
CHAIN_OFF_OUTLINE
CHAIN_OFF_TEXT
CHAIN_BADGE_OFF
BAR_BG_FILL                   # knob bar background / outline
BAR_OUTLINE
SCANLINE_RGBA                 # per-row alpha-blend colour (or None)
SCANLINE_STEP                 # 0 to disable
```

Phase 5D values (Pip-Boy-inspired phosphor green):

| Key | Value |
| --- | --- |
| LED | (90, 220, 110) |
| LED_SOFT | (175, 245, 185) |
| LED_DIM | (52, 140, 76) |
| LED_DEEP | (28, 76, 38) |
| LED_GHOST | (12, 30, 16) |
| SCR_TEXT | (170, 240, 180) |
| SCR_TEXT_DIM | (90, 160, 100) |
| SCR_TEXT_DEAD | (50, 90, 60) |
| SCR_GRID | (16, 50, 22) |
| INK_HI | (210, 245, 210) |
| INK_MID | (130, 195, 140) |
| INK_LO | (80, 130, 90) |
| WARN_AMBER | (255, 178, 60) |
| BYPASS_COL | (235, 165, 70) |
| BG_GRAD | (12, 28, 14) -> (6, 16, 8) -> (3, 8, 4) |
| CHASSIS_INNER_FILL | (5, 14, 7, 220) |
| PANEL_HEADER_FILL | (8, 22, 12, 255) |
| PANEL_CHAIN_FILL | (7, 18, 10, 255) |
| PANEL_FX_FILL | (7, 20, 11, 255) |
| HEADER_CHIP_FILL | (6, 16, 9, 255) |
| FX_CHIP_FILL | (4, 10, 6, 255) |
| CHAIN_ON_FILL | (10, 46, 18, 255) |
| CHAIN_OFF_FILL | (10, 22, 14, 255) |
| CHAIN_OFF_OUTLINE | (60, 100, 70, 220) |
| CHAIN_OFF_TEXT | (110, 160, 120, 255) |
| CHAIN_BADGE_OFF | (38, 64, 44) |
| BAR_BG_FILL | (4, 10, 6, 255) |
| BAR_OUTLINE | (0, 0, 0, 255) |
| SCANLINE_RGBA | (0, 100, 40, 32) (alpha ~ 12.5 %) |
| SCANLINE_STEP | 3 |

Amber-leaning `BYPASS_COL` keeps the "Safe Bypass" / "BYPASS" chip
visually distinct against the phosphor green field. `WARN_AMBER`
stays available for future amber accents (oversaturation indicators,
clip warnings).

## Scanline implementation

The scanline overlay is applied **after** the PIL frame has been
flattened to RGB, as a single vectorised numpy operation on the
output uint8 array:

```python
rows = arr[step-1::step, :, :].astype(float32)
rows = (1 - a) * rows + a * blend
arr[step-1::step, :, :] = clip(rows, 0, 255).astype(uint8)
```

With `step = 3` and `alpha = 32/255`, every third row is blended
12.5 % toward `(0, 100, 40)` -- subtle horizontal banding instead of
the heavier-handed solid scanline a PIL alpha-composite would produce.

The earlier PIL `alpha_composite` prototype added ~100 ms to the cold
render on the PYNQ (about +30 % over the previous baseline). The
numpy implementation lands the cold render back inside the +10..15 %
budget.

## Geometric guarantees

| Property | Value |
| --- | --- |
| `render_frame_800x480` variant | `compact-v2` |
| Default theme | `pipboy-green` |
| Default placement | `manual`, `offset_x = 0`, `offset_y = 0` |
| Source visible region | (0..800, 0..480) |
| Framebuffer copied region | (0..800, 0..480) on the 1280x720 buffer |
| `clipped` / `negative_offset` / `fully_offscreen` | False / False / False |

5-inch LCD viewport flush against framebuffer (0, 0) -- unchanged from
the Phase 5C baseline. `compact_v2_panel_boxes()` returns the same
outer / header / chain / fx rectangles.

## PYNQ run

Command:

```
sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
  scripts/test_hdmi_800x480_frame.py \
  --variant compact-v2 --theme pipboy-green --placement manual \
  --offset-x 0 --offset-y 0 --hold-seconds 60
```

Captured (see `/tmp/hdmi_phase5d_pipboy_green.log` on the dev box for
the full report):

- VDMA error bits `dmainterr` / `dmaslverr` / `dmadecerr`: all False
- VDMA status register: `vdma_dmasr = 0x00011000`
- VTC control: `vtc_ctl = 0x00000006`
- framebuffer copied region: (0..800, 0..480)
- `clipped`, `negative_offset`, `fully_offscreen`: all False
- pre / post smoke: `ADC HPF = True`, `R19 = 0x23`, HDMI IPs present
- render / compose / framebuffer-copy timings recorded in the log

## Visual checks (manual, on the 5-inch LCD)

- Position unchanged: corner markers `TL`, `TR`, `BL`, `BR` still flush
  with the visible LCD edges; the same panel rectangles align with
  the same pixel rows.
- Phosphor green dominates the chain / fx panels; the background is a
  dark olive gradient. The header / status chip retains its amber
  border when `bypassed`.
- Scanlines are visible but not so dense that they make the bitmap
  font unreadable on the 5-inch panel. If the LCD shows them as
  flickering or too dark, lower `SCANLINE_RGBA` alpha or raise
  `SCANLINE_STEP` in `PIPBOY_THEME`.

## Follow-ups for later phases

- Brightness / contrast knobs on the palette (currently the colour
  table is the only control).
- Amber warning accent expansion: clip indicators, "WARN" status row,
  or peak-meter overruns once a meter section returns.
- Theme switch UI on top of `state.theme_name` (Phase 5D ships with
  a fixed compile-time theme + a CLI flag; the renderer is already
  cache-keyed by theme).
- Change-driven GUI loop -- skip the render call entirely while the
  semistatic signature is unchanged.
