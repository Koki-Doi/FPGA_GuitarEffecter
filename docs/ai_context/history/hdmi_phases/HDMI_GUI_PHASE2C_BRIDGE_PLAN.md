# HDMI GUI Phase 2C AppState bridge plan

Date: 2026-05-14

Scope: add a Python bridge that translates
`GUI/pynq_multi_fx_gui.py` `AppState` snapshots into existing
`AudioLabOverlay` control API calls. This phase stays offscreen-only and
does not implement HDMI output.

No HDMI output, `run_pynq_hdmi()`, `Overlay("base.bit")`,
`AudioLabOverlay()` construction, Vivado change, `block_design.tcl`
change, bitstream rebuild, deploy, notebook change, Clash / DSP edit, or
git push / pull / fetch was performed.

## Code changes

New file:

- `GUI/audio_lab_gui_bridge.py`

Validation file:

- `tests/test_hdmi_gui_bridge.py`

The bridge is intentionally separated from the renderer. It imports GUI
state constants when available, but it does not draw frames, call HDMI
APIs, instantiate `AudioLabOverlay`, or touch GPIO objects directly.

The public entry point is `AudioLabGuiBridge`:

- `build_plan(state, ...)` creates a dry-run friendly list of
  `AudioLabOverlay` API calls.
- `apply(state, overlay=None, dry_run=True, ...)` dry-runs by default.
  With `dry_run=False`, the caller must pass an already-loaded
  `AudioLabOverlay` instance.
- `apply_safe_bypass(...)` builds the safe bypass command sequence.
- `apply_chain_preset(...)` calls the existing chain-preset API by name.

The bridge stores the last applied operation signature and only emits
operations when values changed. It also throttles continuous knob-drag
events to `0.10 s` by default, which is about 10 Hz. Button / preset /
release-style events are not throttled.

## AppState mapping

`AppState` currently stores `knob_values` only for the selected effect.
Phase 2C therefore maps the selected effect's live knob values and uses
the GUI defaults for non-selected sections. This is enough for
change-driven bridge validation, but a future live controller should
store per-effect parameter values if it needs to preserve independent
knob edits across effect selection changes.

| GUI section | Bridge output |
| --- | --- |
| Noise Suppressor | `set_noise_suppressor_settings(enabled, threshold, decay, damp)` |
| Compressor | `set_compressor_settings(enabled, threshold, ratio, response, makeup)` |
| Overdrive | grouped `set_guitar_effects(overdrive_on, overdrive_drive, overdrive_tone, overdrive_level)` |
| Distortion Pedalboard | `set_distortion_settings(pedal, exclusive=True, drive, tone, level, bias, tight, mix)` plus grouped `set_guitar_effects(distortion_on, rat_on, distortion_*)`; when disabled, `clear_distortion_pedals()` is planned |
| RAT | treated as the `rat` distortion pedal, not a separate chain block |
| Amp | grouped `set_guitar_effects(amp_on, amp_input_gain, amp_bass, amp_middle, amp_treble, amp_presence, amp_resonance, amp_master, amp_character)` |
| Cab | grouped `set_guitar_effects(cab_on, cab_mix, cab_level, cab_model, cab_air)` with `cab_model` clamped to hardware models `0..2` |
| EQ | grouped `set_guitar_effects(eq_on, eq_low, eq_mid, eq_high)`; GUI 0..100 knobs map to overlay 0..200 level bytes |
| Reverb | grouped `set_guitar_effects(reverb_on, reverb_decay, reverb_tone, reverb_mix)` |
| Chain Preset | `apply_chain_preset(name)` |
| Safe Bypass | `clear_distortion_pedals()`, safe distortion defaults, Noise Suppressor off, Compressor off, grouped effect masters off |

The GUI label `TS Lead` is mapped to the overlay preset name
`Tube Screamer Lead`.

## Change-driven write policy

The bridge does not write on render frames. It plans or applies writes
only from explicit state-change events:

- same `AppState` twice: no operations emitted on the second call
- knob drag: operations throttled to about 10 Hz
- preset / safe bypass: high-priority operation, not throttled
- render cache hits: no hardware operation path exists

The bridge calls only the `AudioLabOverlay` public API. It does not pack
GPIO words itself and does not access `axi_gpio_*` members.

## Chain reorder

The current FPGA DSP pipeline order is fixed:

```text
Noise Suppressor -> Compressor -> Overdrive -> Distortion Pedalboard
-> Amp Simulator -> Cab IR -> EQ -> Reverb
```

If `AppState.chain` differs from that order, the bridge emits a warning
and plans no hardware routing operation. In live HDMI mode, chain drag
reorder should be disabled or treated as display-only.

## Unsupported effects

The live bridge exposes only the current AudioLab chain sections:

- Noise Suppressor
- Compressor
- Overdrive
- Distortion Pedalboard
- Amp Simulator
- Cab IR
- EQ
- Reverb

Older GUI / asset names such as chorus, phaser, octaver, delay, and
bit-crusher are not mapped to live operations and must not be presented
as controllable effects unless a future approved DSP implementation adds
them.

## PYNQ-Z2 verification

The verification copied only `GUI/pynq_multi_fx_gui.py` and
`GUI/audio_lab_gui_bridge.py` to `/tmp/hdmi_gui_phase2c/` on the board.
This was not a deploy.

| Field | Value |
| --- | --- |
| Board | PYNQ-Z2 |
| Host | `192.168.1.9` |
| Python | `3.6.5` |
| Temp path | `/tmp/hdmi_gui_phase2c/` |

Result:

| Check | Value |
| --- | ---: |
| raw import | success |
| import time | `1442.238 ms` |
| dry-run plan methods | `set_noise_suppressor_settings`, `set_compressor_settings`, `clear_distortion_pedals`, `set_distortion_settings`, `set_guitar_effects` |
| same-state second apply | `0` operations |
| knob-drag throttled apply | `0` operations / `1` skipped |
| knob-drag after throttle window | `1` operation |
| offscreen render function | `render_frame_pynq_static(AppState())` |
| frame shape / dtype | `[720, 1280, 3]` / `uint8` |
| offscreen render time | `2921.310 ms` |

The board-side check did not instantiate `AudioLabOverlay`, did not load
`base.bit`, and did not access HDMI output.

## Local validation

Commands run locally:

```sh
python3 -m compileall GUI audio_lab_pynq scripts
python3 tests/test_hdmi_gui_bridge.py
python3 tests/test_overlay_controls.py
```

All commands passed. `tests/test_overlay_controls.py` reported:

```text
AudioLabOverlay guitar effect control tests passed
```

## Historical untracked files

These files / directories were already untracked and were not used or
staged for Phase 2C:

- `GUI/README.md`
- `GUI/fx_gui_state.json`
- `HDMI/`

Post-Phase-5C cleanup resolved this historical state: `GUI/README.md`
was replaced with current integrated-HDMI documentation, `GUI/fx_gui_state.json`
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
- No Notebook change.
- No Clash / DSP edit.
- No direct GPIO write from GUI code.
- No git push / pull / fetch.
