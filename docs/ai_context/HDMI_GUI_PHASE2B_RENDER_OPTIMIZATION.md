# HDMI GUI Phase 2B render optimization

Date: 2026-05-14

Scope: optimize `GUI/pynq_multi_fx_gui.py` for PYNQ-Z2 static /
change-driven offscreen rendering. This phase does not implement HDMI
output or the `AudioLabOverlay` bridge.

No HDMI output, Vivado change, block-design change, bitstream rebuild,
deploy, `AudioLabOverlay()` load, GPIO bridge, DSP change, `base.bit`
load, or `run_pynq_hdmi()` call was performed.

## Starting point

Phase 2A made the renderer compatible with the PYNQ software stack:

| Metric | Phase 2A value |
| --- | ---: |
| import | success |
| frame shape / dtype | `[720, 1280, 3]` / `uint8` |
| cold render | `3764.514 ms` |
| cached same-state avg / p95 | `0.171034 ms` / `0.201208 ms` |
| change-driven redraw avg / p95 | `1972.889 ms` / `2111.738 ms` |

## Cost analysis

One warmed change-driven redraw was profiled on the PYNQ before the Phase
2B optimization. The representative wall time was `2049.620 ms`; the main
contributors were:

| Function / group | Time |
| --- | ---: |
| `render_semistatic_layer` | `1794.637 ms` |
| `draw_main_display` | `1306.173 ms` |
| `inset_screen` | `560.124 ms` |
| `draw_knob_panel` | `479.564 ms` |
| `panel_with_bevel` | `417.607 ms` |
| `draw_knob` | `335.291 ms` |
| `draw_visualizer` | `294.366 ms` |
| `add_brushed_metal` | `265.170 ms` |
| `draw_text` | `83.008 ms` |
| `draw_signal_chain` | `82.011 ms` |
| `_draw_right_panel` | `65.931 ms` |
| `draw_meter` | `40.393 ms` |

The slow path was not the same-state cache; it was a semistatic cache
miss. Any visible UI state change rebuilt the whole LCD panel and knob
panel, including state-independent chrome, brushed-metal texture,
blurred inset surfaces, synthetic visualizer, meter glow, and knob chrome.

## Code changes

`GUI/pynq_multi_fx_gui.py` now separates cached chrome from state-dependent
content:

- `render_static_base()` draws and caches the chassis background, main LCD
  chrome, separators, and knob-panel chrome.
- `render_semistatic_layer()` now draws only state-dependent content:
  preset card, signal chain, right panel, knob title strip, and knobs.
- `draw_main_display_static_chrome()` and `draw_main_display_content()`
  split the main display.
- `draw_knob_panel_static_chrome()` and `draw_knob_panel_content()` split
  the knob panel.
- Knob body chrome is cached by `_knob_body_layer()` instead of rebuilt
  for every knob.
- `RenderCache(..., pynq_static_mode=True)` enables the static /
  change-driven profile.
- `make_pynq_static_render_cache()` creates that cache profile.
- `render_frame_pynq_static()` renders through that profile.

In PYNQ static mode:

- synthetic visualizer / waveform animation is frozen into the cached
  static base;
- `state.t` no longer invalidates the dynamic signature;
- high-cost glow / blur stamps are skipped for text glow, LED bloom,
  wire glow, selected-chain halos, chain-block bloom, meter glow, and
  knob indicator glow;
- the monitor still looks like a signal monitor, but is marked
  `STATIC PREVIEW` and does not imply live audio metering.

The normal `render_frame_fast()` path is still available. It also benefits
from cached chrome, but keeps the animated visualizer path.

## PYNQ environment

The test copied only `GUI/pynq_multi_fx_gui.py` to
`/tmp/hdmi_gui_phase2b/` on the board. This was not a deploy.

| Field | Value |
| --- | --- |
| Board | PYNQ-Z2 |
| Host | `192.168.1.9` |
| Python | `3.6.5` |
| NumPy | `1.16.0` |
| Pillow | `5.1.0` |

Raw import still succeeds without shims:

| Metric | Value |
| --- | ---: |
| import result | success |
| import time | `464.178 ms` |
| RSS after import | `23876 kB` |

## After measurements

Default fast path after cached-chrome split:

| Metric | Value |
| --- | ---: |
| frame shape / dtype | `[720, 1280, 3]` / `uint8` |
| cold render | `3407.583 ms` |
| cached same-state avg | `0.183408 ms/frame` |
| cached same-state p95 | `0.222741 ms/frame` |
| change-driven avg | `690.397 ms/frame` |
| change-driven p95 | `726.448 ms/frame` |
| RSS high-water mark | `105728 kB` |
| PNG | `/tmp/hdmi_gui_phase2b/phase2b_default.png` |
| PNG size | `130585 bytes` |

PYNQ static/change-driven path:

| Metric | Value |
| --- | ---: |
| render function | `render_frame_pynq_static()` |
| frame shape / dtype | `[720, 1280, 3]` / `uint8` |
| cold render | `2886.108 ms` |
| cached same-state avg | `0.491993 ms/frame` |
| cached same-state p95 | `0.200019 ms/frame` |
| change-driven avg | `255.625 ms/frame` |
| change-driven p95 | `276.171 ms/frame` |
| RSS high-water mark | `137168 kB` |
| PNG | `/tmp/hdmi_gui_phase2b/phase2b_pynq_static.png` |
| PNG size | `90383 bytes` |

The same-state average includes one scheduler outlier (`10.233613 ms`);
the p95 remains sub-millisecond and cache-hit behavior is preserved.

## Improvement

| Metric | Phase 2A | Phase 2B default fast | Phase 2B PYNQ static |
| --- | ---: | ---: | ---: |
| cold render | `3764.514 ms` | `3407.583 ms` | `2886.108 ms` |
| cached same-state avg | `0.171034 ms` | `0.183408 ms` | `0.491993 ms` |
| cached same-state p95 | `0.201208 ms` | `0.222741 ms` | `0.200019 ms` |
| change-driven avg | `1972.889 ms` | `690.397 ms` | `255.625 ms` |
| change-driven p95 | `2111.738 ms` | `726.448 ms` | `276.171 ms` |

The PYNQ static mode moved change-driven redraws from about `2.0 s` to
about `0.26 s`, which meets the Phase 2B target of approaching
`<500 ms`. It is still not a 5/10/15/30fps animation path, but it is
practical for static or user-change-driven HDMI updates.

## Post-optimization profile

A representative warmed PYNQ static redraw measured `266.990 ms` wall
time. The semistatic redraw portion dropped to `119.678 ms`.

| Function / group | Time |
| --- | ---: |
| `render_semistatic_layer` | `119.678 ms` |
| `draw_main_display_content` | `74.509 ms` |
| `draw_signal_chain` | `40.718 ms` |
| `draw_text` | `40.118 ms` |
| `draw_knob_panel_content` | `36.393 ms` |
| `draw_knob` | `32.060 ms` |
| `_draw_right_panel` | `25.950 ms` |
| `_draw_preset_card` | `7.723 ms` |
| `draw_meter` | `4.627 ms` |
| `_knob_body_layer` | `0.104 ms` |

Remaining wall time is mostly full-frame composition and conversion to the
RGB ndarray, plus state-dependent text / signal-chain drawing.

## PNG inspection

`phase2b_pynq_static.png` was copied back to local `/tmp` and visually
inspected. The layout remains coherent at 1280x720. The main intentional
visual difference is that the signal monitor is a frozen `STATIC PREVIEW`
instead of an animated waveform / spectrum.

## Historical untracked files

The following files / directories were already untracked and were not used
or staged for Phase 2B:

- `GUI/README.md`
- `GUI/fx_gui_state.json`
- `HDMI/`

Post-Phase-5C cleanup resolved this historical state: `GUI/README.md`
was replaced with an accurate current renderer README, `GUI/fx_gui_state.json`
is runtime state ignored by git, and the unused untracked `HDMI/` tree was
backed up and removed.

## Explicitly not done

- No HDMI output.
- No call to `run_pynq_hdmi()`.
- No call to `Overlay("base.bit")`.
- No call to `AudioLabOverlay()`.
- No second overlay load.
- No Vivado or `block_design.tcl` change.
- No bitstream / hwh rebuild.
- No deploy.
- No GPIO bridge or DSP control implementation.
- No Clash / DSP edit.
- No git push / pull / fetch.
