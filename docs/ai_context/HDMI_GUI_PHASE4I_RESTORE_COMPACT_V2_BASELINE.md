# HDMI GUI Phase 4I — Restore compact-v2 baseline

## Summary

Phase 4H added a "vertical safe margin + horizontal layout diagnosis"
direction on top of the Phase 4G compact-v2 layout (chassis pushed down
to `y=30`, panel left margin shrunk from `24` to `18`, panels moved
down by ~18 px) and a paired diagnostic that swept `offset_y` upward in
small positive steps. On the real 5-inch HDMI LCD that direction did
not fix the reported top-edge clip; instead the rendered chassis ended
up shifted down and to the right, and the new positive-`offset_y`
recommendation made the layout worse rather than better.

Phase 4I rolls the renderer back to the Phase 4G compact-v2 baseline,
keeps the Phase 4H diagnostic scripts as archived references, and
records the failed direction so a future calibration pass does not
repeat it.

No Vivado rebuild, no bit / hwh changes, no `block_design.tcl`,
`audio_lab.xdc`, `create_project.tcl`, `topEntity`, Clash, GPIO, HDMI
IP, VDMA, or VTC change.

## What changed

### Renderer (`GUI/pynq_multi_fx_gui.py`)

The public `COMPACT_V2_LAYOUT` dict and `compact_v2_panel_boxes()`
helper introduced in Phase 4H are kept so the diagnostic scripts can
still read the same bboxes the renderer draws, but the coordinates
have been reverted to the Phase 4G values:

| Field             | Phase 4H            | Phase 4I (= Phase 4G)        |
| ----------------- | ------------------- | ---------------------------- |
| outer (800x480)   | `(12,30)..(788,470)` | `(12,12)..(788,468)`        |
| `left` margin     | `18`                | `24`                         |
| `right` margin    | `18`                | `24`                         |
| `header_y`        | `(44, 118)`         | `(20, 100)`                  |
| `chain_y`         | `(128, 258)`        | `(110, 250)`                 |
| `bottom_y`        | `(268, 458)`        | `(260, 454)`                 |
| FX / side divider | `Wv//2 +/- 6`       | `Wv//2 +/- 8` (new `divider_half_gap`) |
| variant label y   | `472` (dict key)    | `Hv - 4` (computed)          |
| cache key suffix  | `compact_v2_800x480_p4h` | `compact_v2_800x480`    |

Additionally, the LED-soft inset "safe corner" L-shapes that Phase 4H
drew at the outer-rectangle corners have been removed. Only the
canvas-edge TL / TR / BL / BR markers remain, matching Phase 4G.

The renderer docstring records the rollback so a future reader can
trace why the bbox set differs from the inline-literal Phase 4G code.

### Diagnostic scripts

- `scripts/test_hdmi_800x480_layout_debug.py` — kept; module docstring
  and argparse `description` / `epilog` now state the script is an
  **archived Phase 4H diagnostic**, and a startup banner reminds the
  operator that Phase 4I rolled back the paired positive-`offset_y`
  direction.
- `scripts/test_hdmi_800x480_vertical_offsets.py` — kept; module
  docstring and argparse `description` / `epilog` now state the
  positive-`offset_y` sweep is an **archived / failed direction** and
  not a runtime calibration target. A startup banner reinforces the
  point.
- `scripts/test_hdmi_800x480_frame.py` — unchanged; defaults stayed
  at `--placement manual --offset-x 0 --offset-y 0` throughout Phase 4H
  and remain so in Phase 4I.

### Docs

- `docs/ai_context/CURRENT_STATE.md` — added a Phase 4I section noting
  the rollback, the failed direction, and the recommended placement.
- `docs/ai_context/HDMI_GUI_INTEGRATION_PLAN.md` — added Phase 4I
  status (compact-v2 baseline restored, Vivado / bit / hwh unchanged).
- `docs/ai_context/RESUME_PROMPTS.md` — added a Phase 4I resume entry
  so a fresh context can pick up where Phase 4I left off without
  re-applying the failed Phase 4H direction.

## Why the Phase 4H direction was wrong

1. The reported symptom on the 5-inch LCD was a **slight top-edge
   clip** plus a **subjective "left strip is invisible or unused"**.
2. Phase 4H read this as "shift the whole layout downward" and added
   a top safe margin to the chassis plus a paired positive-`offset_y`
   sweep.
3. On the real panel the chassis push-down stacked with whatever
   viewport offset the LCD already imposes, so the chassis ended up
   visibly shifted down and to the right. The "unused left strip"
   was not addressed because shrinking the left margin only moved the
   panel content closer to the chassis edge, not to the viewport
   edge.
4. The correct response is **not** to add a vertical offset on top of
   a frame whose chassis has been pushed down. Either the framebuffer
   is being cropped by the LCD viewport (a Vivado / VTC / placement
   problem, deliberately out of scope for Phase 4) or the renderer
   itself needs to use a smaller logical canvas so the UI region
   fits the visible viewport without any offset.

## Phase 4I bit / hwh / Vivado status

- `hw/Pynq-Z2/block_design.tcl` — unchanged.
- `hw/Pynq-Z2/audio_lab.xdc` — unchanged.
- `hw/Pynq-Z2/create_project.tcl` — unchanged.
- `hw/Pynq-Z2/bitstreams/audio_lab.bit` — unchanged (same size and
  mtime as the Phase 4G / Phase 4H deploy).
- `hw/Pynq-Z2/bitstreams/audio_lab.hwh` — unchanged.
- No Vivado rebuild, no Clash regenerate, no `make clean`, no
  `bit` / `hwh` regeneration, no `block_design.tcl` reload.
- `AudioLabOverlay()` is still loaded exactly once at runtime;
  `base.bit` is not loaded and `run_pynq_hdmi()` is not called.

## Recommended runtime placement

`scripts/test_hdmi_800x480_frame.py --variant compact-v2
--placement manual --offset-x 0 --offset-y 0`.

This is the Phase 4G compact-v2 baseline. The Phase 4H positive
`offset_y` recommendation (initial range `20..30`) is rolled back —
do **not** use a positive `offset_y` to "fix" the top-clip; that
direction has been verified as wrong on the real panel.

## Next direction (not yet implemented)

The remaining 5-inch-LCD symptoms (top-clip, unused left strip) are
better addressed by changing the UI itself rather than chasing
viewport offsets:

1. **Internal UI density / size tuning at offset 0,0** — shrink the
   chassis outline stroke, header band height, and chain row height
   so the UI consumes less of the 800x480 logical canvas at the top
   and bottom. Leaves coordinates predictable; no diagnostic offset
   sweep needed.
2. **Smaller logical canvas** — render at e.g. 760x440 logical and
   composite at offset `(20, 20)` on the 800x480 framebuffer so the
   UI sits in the LCD's visible viewport with a known margin. Still
   no Vivado / VTC / VDMA change, no positive runtime offset.
3. **Phase 5 (out of scope for Phase 4)** — change the HDMI timing to
   match the 5-inch panel's native 800x480 mode in Vivado. Requires
   a bit / hwh rebuild and a timing-summary review, so it is
   explicitly deferred.

## Files touched

- `GUI/pynq_multi_fx_gui.py`
- `scripts/test_hdmi_800x480_layout_debug.py`
- `scripts/test_hdmi_800x480_vertical_offsets.py`
- `docs/ai_context/CURRENT_STATE.md`
- `docs/ai_context/HDMI_GUI_INTEGRATION_PLAN.md`
- `docs/ai_context/RESUME_PROMPTS.md`
- `docs/ai_context/HDMI_GUI_PHASE4I_RESTORE_COMPACT_V2_BASELINE.md` (this file)
