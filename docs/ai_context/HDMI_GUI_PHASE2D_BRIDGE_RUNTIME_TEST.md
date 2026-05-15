# HDMI GUI Phase 2D bridge runtime test

Date: 2026-05-14

Scope: drive the existing `audio_lab.bit` through
`GUI/audio_lab_gui_bridge.py` with `dry_run=False`, against the deployed
`AudioLabOverlay` on PYNQ-Z2 (`192.168.1.9`). HDMI output remains
unimplemented. No `run_pynq_hdmi()`, no `Overlay("base.bit")`, no second
overlay load, no Vivado / block-design / bitstream / hwh change, no
deploy, no Notebook change, no DSP / Clash edit, and no
`git push` / `pull` / `fetch`.

## Execution environment

| Field | Value |
| --- | --- |
| Board | PYNQ-Z2 |
| Host | `192.168.1.9` |
| MAC | `00:05:6B:02:CA:04` |
| Python | `3.6.5` |
| Repo on PYNQ | `/home/xilinx/Audio-Lab-PYNQ/` (pre-existing) |
| Bridge / test staging | `/tmp/hdmi_gui_phase2d/` (temporary copy, not a deploy) |
| Invocation | `sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ:/tmp/hdmi_gui_phase2d python3 /tmp/hdmi_gui_phase2d/run_phase2d_bridge_test.py` |

Files staged on the board:

- `/tmp/hdmi_gui_phase2d/audio_lab_gui_bridge.py` — copy of
  `GUI/audio_lab_gui_bridge.py` from this repo.
- `/tmp/hdmi_gui_phase2d/run_phase2d_bridge_test.py` — runtime test
  driver written for Phase 2D; not committed to the repo.

The renderer module is intentionally NOT imported by the runtime test.
The test builds a minimal `AppState`-shaped object with only the fields
that `audio_lab_gui_bridge.py` reads. This keeps the bridge runtime path
independent from the offscreen render code and proves that no
`render_frame*` call is required to drive hardware.

## Pre-bridge smoke

The runtime test reads ADAU1761 register 19 from the cached codec
shadow, then asks the overlay for delay-related GPIO presence.

| Check | Value |
| --- | --- |
| ADC HPF | `True` |
| R19 | `0x23` |
| has `axi_gpio_delay_line` | `False` |
| has legacy `axi_gpio_delay` | `True` |

These match `CURRENT_STATE.md`'s deployed baseline (internal mono DSP
pipeline).

## Bridge operations actually written to hardware

`AudioLabGuiBridge` was created with `knob_throttle_seconds=0.10` and
driven by `bridge.apply(state, overlay=overlay, dry_run=False, ...)`
plus `bridge.apply_safe_bypass(overlay=overlay, dry_run=False)` and
`bridge.apply_chain_preset(state, overlay=overlay, dry_run=False)`.

| Step | Bridge call | Real `AudioLabOverlay` methods invoked | Operation count |
| --- | --- | --- | ---: |
| Safe Bypass (first) | `apply_safe_bypass` | `clear_distortion_pedals`, `set_distortion_settings`, `set_noise_suppressor_settings`, `set_compressor_settings`, `set_guitar_effects` | 5 |
| Apply Chain Preset `Basic Clean` | `apply_chain_preset` | `apply_chain_preset(name="Basic Clean")` | 1 |
| Force one full apply to baseline signatures | `apply(..., force=True)` | `set_noise_suppressor_settings`, `set_compressor_settings`, `clear_distortion_pedals`, `set_distortion_settings`, `set_guitar_effects` | 5 |
| Same-state second apply | `apply(state, ...)` | (none) | 0 |
| Change only Noise Sup THRESHOLD | `apply(state, ...)` | `set_noise_suppressor_settings`, `set_guitar_effects` | 2 |
| Change only Compressor RATIO | `apply(state, ...)` | `set_compressor_settings` | 1 |
| Knob-drag inside 100 ms throttle window | `apply(..., event="knob_drag")` | (none, 1 skipped) | 0 |
| Knob-drag after 100 ms window | `apply(..., event="knob_drag")` | `set_compressor_settings` | 1 |
| Safe Bypass (restore at end) | `apply_safe_bypass` | `clear_distortion_pedals`, `set_distortion_settings`, `set_noise_suppressor_settings`, `set_compressor_settings`, `set_guitar_effects` | 5 |

All operations went through the public `AudioLabOverlay` API. The bridge
never touched `axi_gpio_*` attributes directly and never instantiated
`AudioLabOverlay` itself.

The Noise Suppressor THRESHOLD change writes two methods because
`set_guitar_effects` keeps mirroring the legacy `noise_gate_threshold`
byte to `axi_gpio_gate.ctrlB` (`GPIO_CONTROL_MAP.md` line 41) for
backward compatibility with older bitstreams. This is the
documented mirror, not a bridge leak. The Compressor RATIO change
writes exactly `set_compressor_settings` because the compressor section
does not mirror into the grouped helper. Both are section-scoped in
the sense required for Phase 2D.

## Same-state and throttle verification

- `same_state_second_apply`: `0` real operations, `0` skipped
  (the signature cache matched every section).
- `knob_drag` inside the throttle window: `0` real operations,
  `1` skipped op (the bridge recorded but suppressed the write).
- `knob_drag` outside the throttle window: `1` real operation.

This matches the local `tests/test_hdmi_gui_bridge.py` assertions but
confirms the same behavior with the real overlay attached.

## Post-bridge smoke

| Check | Value |
| --- | --- |
| ADC HPF | `True` |
| R19 | `0x23` |
| has `axi_gpio_delay_line` | `False` |
| has legacy `axi_gpio_delay` | `True` |

Identical to the pre-bridge smoke. Safe Bypass at the end of the test
left the board in a quiet, predictable state.

## Explicitly not done

- No HDMI output.
- No call to `run_pynq_hdmi()`.
- No call to `Overlay("base.bit")`.
- No second overlay load — `AudioLabOverlay()` was constructed exactly
  once for the entire Phase 2D run.
- No `render_frame*` call from the bridge or the runtime test driver.
- No GPIO direct write from GUI code. Every byte change went through
  the bridge -> `AudioLabOverlay` public API.
- No Vivado work, no `block_design.tcl` edit, no bitstream / hwh
  rebuild, no `scripts/deploy_to_pynq.sh` invocation.
- No Notebook change.
- No DSP / Clash / `topEntity` change.
- No GPIO address / name / `ctrlA`-`ctrlD` semantic change.
- No `git push` / `pull` / `fetch`.

## Issues observed

None. Every assertion in the runtime driver passed:

- Safe Bypass applied without warnings or skipped ops.
- Basic Clean chain preset applied via one `apply_chain_preset` call.
- Same-state second apply was empty.
- Single-section changes wrote only the matching section (Compressor
  case) or the matching section plus its legacy mirror
  (Noise Suppressor case).
- Knob-drag inside the 100 ms window was suppressed; the next apply
  after the window flushed the change to hardware.

One artifact for review: the runtime driver still expects the bridge to
plan a redundant `set_distortion_settings` after `clear_distortion_pedals`
when the GUI distortion section is OFF. This is by design today (to keep
disabled distortion knob values in the overlay cache), but a future
revision could collapse them. It is not a Phase 2D failure.

## Conclusion

The Phase 2C bridge contract holds against the real, deployed
`audio_lab.bit` on the PYNQ-Z2. The bridge is now safe to use as the
control-side back end for a future live HDMI GUI loop, once the HDMI
framebuffer path lands in the integrated AudioLab bitstream
(Phase 3 / Phase 4).
