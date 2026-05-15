# HDMI GUI Phase 1 render benchmark

Date: 2026-05-14

Status: benchmark completed, implementation not started. No HDMI output,
Vivado change, bitstream rebuild, deploy, GPIO bridge, `base.bit` load,
or `Overlay()` call was performed.

## Scope

This phase measured whether `GUI/pynq_multi_fx_gui.py` can render a
single offscreen GUI frame on the PYNQ-Z2, and how expensive that render
is on the board CPU.

The file `GUI/pynq_multi_fx_gui.py` was not present in
`/home/xilinx/Audio-Lab-PYNQ/GUI/` on the board, and deploy was
explicitly prohibited. For measurement only, the local file was copied
to:

```text
/tmp/hdmi_gui_phase1/pynq_multi_fx_gui.py
```

The saved preview frame was copied back to local `/tmp` for visual
inspection. No repository file or installed package on the PYNQ was
modified.

## Environment

| Item | Value |
| --- | --- |
| Board | PYNQ-Z2 |
| Host | `192.168.1.9` |
| Remote user | `xilinx` |
| Python | `3.6.5` |
| NumPy | `1.16.0` |
| Pillow | `5.1.0` |
| Initial loadavg | about `0.07 0.10 0.08` |
| `/proc/meminfo` before benchmark | `MemTotal: 506504 kB`, `MemAvailable: 390752 kB` |

Safety checks:

- `run_pynq_hdmi()` was not called.
- `Overlay("base.bit")` was not called.
- `AudioLabOverlay()` was not loaded.
- No GPIO write was performed.
- No HDMI framebuffer or video IP was touched.

## Import result

Raw import of `pynq_multi_fx_gui.py` on the PYNQ image failed:

```text
ModuleNotFoundError: No module named 'dataclasses'
```

This is expected because the PYNQ Python is 3.6 and the `dataclasses`
backport is not installed.

After installing a process-local benchmark shim for `dataclasses`, import
succeeded. The import took about `1114.94 ms` with the shim.

Additional compatibility gaps found during rendering:

- `np.random.default_rng` is not available in NumPy 1.16.0.
- Pillow 5.1.0 lacks several newer `ImageDraw` keyword-compatible calls
  used by the GUI (`width` / `joint` style arguments on primitives).

For performance measurement only, the benchmark process installed
temporary shims for:

- `dataclasses.dataclass` / `dataclasses.field`
- `np.random.default_rng`
- selected `PIL.ImageDraw` methods (`rectangle`, `ellipse`, `arc`,
  `line`, `polygon`) to ignore unsupported newer keyword arguments

These shims were not written to the repository.

Conclusion: as currently written, `GUI/pynq_multi_fx_gui.py` is not
directly compatible with the deployed PYNQ Python stack. A future
implementation needs either package/runtime updates or a small
compatibility pass before this GUI can run on-board without shims.

## Render result

With the temporary compatibility shims, offscreen rendering succeeded.

| Item | Value |
| --- | --- |
| Function | `render_frame_fast(AppState(), cache=RenderCache())` |
| Shape | `[720, 1280, 3]` |
| dtype | `uint8` |
| Pixel range | `0..255` |
| Saved PNG | `/tmp/hdmi_gui_phase1/phase1_render.png` |
| PNG size | `133664 bytes` |

The saved PNG was visually inspected after copying it to local
`/tmp/phase1_render.png`. The frame was coherent and recognizable as the
expected `pynq_multi_fx_gui.py` layout. Because Pillow compatibility
shims were used, this inspection only confirms broad layout integrity,
not pixel-equivalence with a modern Pillow render.

## Timing results

### Cold render

One cold 1280x720 render with a fresh `RenderCache`:

| Metric | Value |
| --- | ---: |
| cold render | `3871.43 ms` |
| estimated FPS | `0.26 fps` |

Cold render includes static background, semistatic GUI layer, text,
gradients, knobs, monitor graphics, and cache population.

### Cached same-state render

Thirty repeated calls with identical `AppState` and an already populated
cache:

| Metric | Value |
| --- | ---: |
| n | `30` |
| avg | `0.177 ms/frame` |
| min | `0.169 ms/frame` |
| max | `0.248 ms/frame` |
| p95 | `0.242 ms/frame` |
| estimated FPS from avg | `5658 fps` |
| reused same ndarray object | `True` |

This path is effectively a frame-cache hit. It is useful for repeating
an unchanged static frame, but it is not representative of animated
meters, visualizer updates, or control changes.

### Dynamic 30-frame loop

Thirty calls attempted at 30fps-style `state.t` increments after a warm
first frame, with the existing GUI cache settings (`visualizer_fps=5`,
`meter_fps=10`):

| Metric | Value |
| --- | ---: |
| n | `30` |
| avg | `744.49 ms/frame` |
| min | `0.182 ms/frame` |
| max | `2250.28 ms/frame` |
| p95 | `2246.92 ms/frame` |
| estimated FPS from avg | `1.34 fps` |

Cache statistics for that dynamic loop:

| Counter | Value |
| --- | ---: |
| frame hits | `20` |
| frame misses | `11` |
| static hits / misses | `10 / 1` |
| semistatic hits / misses | `0 / 11` |
| text hits / misses | `640 / 75` |
| gradient hits / misses | `177 / 12` |
| visualizer updates | `11` |
| meter updates | `11` |

The very fast frames are cache hits. The slow frames are semistatic-layer
regenerations, which still include expensive visualizer and meter drawing.

## Memory observations

Process memory from `/proc/self/status`:

| Point | VmRSS | VmHWM | VmSize |
| --- | ---: | ---: | ---: |
| before import | `6652 kB` | `6652 kB` | `10936 kB` |
| after import | `20004 kB` | `20004 kB` | `33736 kB` |
| after cold render | `43944 kB` | `54336 kB` | `57816 kB` |
| after dynamic loop | `110252 kB` | `129380 kB` | `123972 kB` |

`resource.getrusage(...).ru_maxrss` also reported `129380 kB`.

This is workable within the observed available memory, but it is large
enough that a long-running HDMI GUI should avoid unbounded cache growth
and should be tested alongside AudioLab runtime memory use.

## CPU / FPS assessment

The benchmark is CPU-bound. A full semistatic redraw on PYNQ-Z2 takes on
the order of seconds, not tens of milliseconds. The cache makes unchanged
frames cheap, but animated monitor / meter updates force slow redraws.

Practical HDMI frame-rate assessment for the current renderer on this
PYNQ image:

| Target | Assessment |
| --- | --- |
| 30fps | Not realistic with current full-frame renderer. |
| 15fps | Not realistic with current full-frame renderer. |
| 10fps | Not realistic while visualizer / meters update. |
| 5fps | Not realistic for animated redraws; possible only if most frames are cache hits or the display is mostly static. |
| 1fps | Plausible for occasional updates, but redraw misses can still exceed 2 seconds. |
| Static / change-only | Plausible because cache hits are sub-millisecond after a frame is generated. |

For a live HDMI GUI, the current renderer should be treated as a
static/change-driven UI unless it is optimized. Continuous 5fps or higher
will likely require reducing dynamic content, lowering resolution,
pre-rendering more layers, limiting visualizer redraws, or simplifying
PIL effects.

## Phase 1 conclusions

1. `render_frame(AppState())` cannot run as-is on the current PYNQ image
   because of Python / NumPy / Pillow compatibility gaps.
2. With process-local compatibility shims, a 1280x720 RGB frame can be
   generated offscreen.
3. Frame shape and dtype match the intended HDMI framebuffer contract:
   `(720, 1280, 3)` / `uint8`.
4. Cold render is about `3.87 s`.
5. Exact same-state cache hits are effectively free (`~0.18 ms`).
6. A 30-frame dynamic loop averages `744 ms/frame` with p95 around
   `2.25 s`, because cache misses require expensive PIL redraws.
7. Current renderer is not suitable for animated 5/10/15/30fps HDMI GUI
   on PYNQ-Z2 without optimization.
8. Next implementation work should start with compatibility fixes and a
   bridge/offscreen path before any HDMI Vivado integration.

## Follow-up requirements before Phase 2

Before building an `AppState` / `AudioLabOverlay` bridge on the board,
decide how to handle PYNQ Python compatibility:

- install or vendor the `dataclasses` backport, or remove the dependency
  in the GUI module;
- replace `np.random.default_rng` usage with NumPy 1.16-compatible calls,
  or require a newer NumPy;
- avoid newer Pillow `ImageDraw` keyword arguments, or require a newer
  Pillow.

These are Python compatibility changes only. They do not require Vivado
or bitstream work, but they should be implemented intentionally and
tested on both desktop and PYNQ.

## Phase 2A follow-up

Phase 2A implemented those Python compatibility fixes in
`GUI/pynq_multi_fx_gui.py` and re-tested on the PYNQ-Z2 without
process-local shims. Raw import and `render_frame_fast(AppState())`
now succeed directly on Python 3.6.5 / NumPy 1.16.0 / Pillow 5.1.0.

Key Phase 2A numbers:

- import time: `451.188 ms`
- frame shape / dtype: `[720, 1280, 3]` / `uint8`
- cold render: `3764.514 ms`
- same-state cached render: avg `0.171034 ms/frame`, p95
  `0.201208 ms/frame`
- change-driven redraw sample with animation time held static: avg
  `1972.889 ms/frame`, p95 `2111.738 ms/frame`

The conclusion remains that animated HDMI at 5/10/15/30fps is not
realistic on the current PYNQ-Z2 CPU path. The future HDMI backend should
be static/change-driven and should freeze or heavily throttle visualizer,
waveform, and meter animation. Full Phase 2A details are in
`HDMI_GUI_PHASE2A_PYNQ_COMPAT.md`.
