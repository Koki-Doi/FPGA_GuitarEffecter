# HDMI GUI Phase 2A PYNQ compatibility

Date: 2026-05-14

Scope: minimal compatibility changes to `GUI/pynq_multi_fx_gui.py` so the
renderer can be imported and run offscreen on the PYNQ-Z2 without external
benchmark shims.

No HDMI output, Vivado change, block-design change, bitstream rebuild,
deploy, `AudioLabOverlay()` load, GPIO bridge, or `base.bit` load was
performed.

## Environment

The test copied only `GUI/pynq_multi_fx_gui.py` to
`/tmp/hdmi_gui_phase2a/` on the board. This was not a deploy.

| Field | Value |
| --- | --- |
| Board | PYNQ-Z2 |
| Host | `192.168.1.9` |
| PYNQ image | `Linux-5.4.0-xilinx-v2020.1-armv7l-with-pynqlinux-v2.6-WFH` |
| Python | `3.6.5` |
| NumPy | `1.16.0` |
| Pillow | `5.1.0` |
| Test path | `/tmp/hdmi_gui_phase2a/pynq_multi_fx_gui.py` |
| PNG output | `/tmp/hdmi_gui_phase2a/phase2a_render.png` |

## Compatibility changes

`GUI/pynq_multi_fx_gui.py` now contains local compatibility helpers for the
old PYNQ software stack:

- `dataclasses` fallback for Python 3.6 images that do not have the
  backport installed. The fallback covers the subset used by `AppState`:
  class defaults and `field(default_factory=...)`.
- NumPy RNG adapter. Calls that used `np.random.default_rng(...)` now go
  through `_rng(...)`, which uses `default_rng` on new NumPy and
  `np.random.RandomState` on NumPy 1.16.
- Pillow `ImageDraw` keyword compatibility. The module accepts newer
  `width` / `joint` keyword call sites and drops unsupported keywords on
  Pillow 5.1.
- The top-level module documentation now describes the safe PYNQ offscreen
  usage and warns that AudioLab must not use the legacy
  `run_pynq_hdmi()` / `base.bit` path.

These changes do not instantiate PYNQ overlays and do not touch DSP control.

## PYNQ result

Raw import now succeeds on the PYNQ-Z2 without process-local shims:

| Metric | Value |
| --- | ---: |
| import result | success |
| import time | `451.188 ms` |
| RSS after import | `23548 kB` |

Offscreen render also succeeds:

| Metric | Value |
| --- | ---: |
| render function | `render_frame_fast(AppState())` |
| render result | success |
| frame shape | `[720, 1280, 3]` |
| frame dtype | `uint8` |
| frame bytes | `2764800` |
| cold render | `3764.514 ms` |
| RSS after cold render | `75824 kB` |
| RSS delta after cold render | `52276 kB` |

Same-state cached path, 30 calls after the cold render:

| Metric | Value |
| --- | ---: |
| avg | `0.171034 ms/frame` |
| min | `0.161997 ms/frame` |
| max | `0.310791 ms/frame` |
| p95 | `0.201208 ms/frame` |
| estimated FPS from avg | `5846.79 fps` |

Change-driven redraw sample, with animation time held static and eight
distinct UI states rendered through a low-frequency cache:

| Metric | Value |
| --- | ---: |
| samples | `8` |
| avg | `1972.889 ms/frame` |
| min | `1866.536 ms/frame` |
| max | `2119.467 ms/frame` |
| p95 | `2111.738 ms/frame` |
| estimated FPS equivalent | `0.51 fps` |

The saved PNG was `1280 x 720`, RGB, non-interlaced, `133664` bytes. Visual
inspection showed the expected GUI layout with no obvious corruption.

## Interpretation

The renderer is now portable enough to run directly on the board for
offscreen generation, but the performance conclusion did not change:

- idle/static frame reuse is cheap because the frame cache returns the
  existing ndarray;
- a UI state change that misses the semistatic cache is still about
  two seconds on the PYNQ-Z2 CPU;
- animated 5/10/15/30fps HDMI display remains unrealistic with the current
  1280x720 PIL renderer;
- a future HDMI backend should be static/change-driven, not continuously
  animated.

## Change-driven live HDMI design note

For the future live HDMI mode, treat `render_frame_fast()` as a producer of
static frames:

- Render only when user-visible state changes, or on a very slow heartbeat.
- Keep `state.t` fixed in the live HDMI path unless a deliberate low-rate
  refresh is requested.
- Disable or freeze the animated visualizer, waveform, and synthetic meters
  by default.
- If real DSP meters are later added, update them at a low rate such as
  `0.5` to `1` Hz and accept visible stepping.
- Reuse the last RGB ndarray and framebuffer while the state is unchanged.
- Keep DSP control writes separate from rendering and perform them only on
  actual state changes.

This keeps the current AudioLab control path safe and avoids burning CPU on
frames that do not communicate new information.

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
