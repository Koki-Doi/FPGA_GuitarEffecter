# Distortion refactor plan

This is the active design document for the selectable-distortion work.
The previous attempt was reverted in plan because it broke FPGA timing;
this file records the replacement design.

## Background

The user wants seven distortion "voicings" available alongside the
existing legacy distortion stage:

- `clean_boost`
- `tube_screamer`
- `rat_style`
- `ds1_style`
- `big_muff`
- `fuzz_face`
- `metal`

The original plan was to add one Clash pipeline that read a numeric
`model_select` and switched its internal arithmetic per model. That
implementation regressed WNS from −7.722 ns to −15.067 ns and was
halted before deploy. See `TIMING_AND_FPGA_NOTES.md` for the timing
data.

## New plan: independent pedal stages

Treat each voicing as its own small pipeline section, structurally
identical to the existing `overdrive`, `distortion`, and `RAT` blocks.
Each stage:

- Has its own enable bit. When the bit is clear, output equals input
  bit-exactly.
- Is a small, independent register chain. **No** big `case` switches
  that fan eight different multiplies / clips into one mux.
- Reuses the existing `Frame` accumulator fields and the per-channel
  filter-state register pattern (see how the RAT section does it).

Target chain layout in `LowPassFir.hs`:

```
gate
  -> overdrive
  -> distortion (legacy; unchanged)
  -> rat (legacy; unchanged)
  -> clean_boost          [enable bit]
  -> tube_screamer        [enable bit]
  -> rat_style            [enable bit; may map onto the existing RAT stage]
  -> ds1_style            [enable bit]
  -> big_muff             [enable bit]
  -> fuzz_face            [enable bit]
  -> metal                [enable bit]
  -> amp -> cab -> eq -> reverb
```

Stages that do not yet exist in Clash are still wired through the API as
no-ops so that the GPIO bit allocation is stable. See "Phasing" below.

## Control plane

| Control | Bit / byte | Owner |
| --- | --- | --- |
| Distortion section master enable | `gate_control` ctrlA bit 2 | existing flag, kept as-is |
| Pedal mask bit 0 | `distortion_control` ctrlD bit 0 | clean_boost |
| Pedal mask bit 1 | `distortion_control` ctrlD bit 1 | tube_screamer |
| Pedal mask bit 2 | `distortion_control` ctrlD bit 2 | rat_style |
| Pedal mask bit 3 | `distortion_control` ctrlD bit 3 | ds1_style |
| Pedal mask bit 4 | `distortion_control` ctrlD bit 4 | big_muff |
| Pedal mask bit 5 | `distortion_control` ctrlD bit 5 | fuzz_face |
| Pedal mask bit 6 | `distortion_control` ctrlD bit 6 | metal |
| Pedal mask bit 7 | reserved | — |
| drive | `distortion_control` ctrlC | shared by every pedal |
| tone | `distortion_control` ctrlA | shared by every pedal |
| level | `distortion_control` ctrlB | shared by every pedal |
| bias | `gate_control` ctrlC | shared by every pedal that uses bias |
| tight | `overdrive_control` ctrlD | shared by every pedal that uses tight |
| mix | `gate_control` ctrlD | shared by every pedal that uses wet/dry |

Every byte is currently spare. **No `block_design.tcl` change.**

A pedal stage processes audio when:

```
flag2(fGate)                                  -- section master
  AND distortion_pedal_enable[bit_for_stage]  -- pedal-specific bit
```

When either is false, the stage is a bit-pass-through.

## Python API

```python
ovl.set_distortion_pedal(name, enabled=True, exclusive=True)
ovl.set_distortion_pedals(clean_boost=False, tube_screamer=True, ...)
ovl.clear_distortion_pedals()
ovl.get_distortion_pedals()           # -> dict[str, bool]
ovl.set_distortion_drive(0..100)
ovl.set_distortion_tone(0..100)
ovl.set_distortion_level(0..100)
ovl.set_distortion_bias(0..100)
ovl.set_distortion_tight(0..100)
ovl.set_distortion_mix(0..100)
ovl.set_distortion_settings(drive=, tone=, level=, bias=, tight=, mix=,
                            pedal=, pedals=, exclusive=)
ovl.get_distortion_settings()
```

- `name` accepts any of the strings listed above.
- `exclusive=True` (default): the call clears every other distortion
  pedal bit before setting the requested one. This keeps casual users
  from stacking three high-gain stages by accident.
- `exclusive=False` allows stacking. Notebooks should mark this path
  as advanced.
- `set_guitar_effects(distortion_on=...)` continues to flip the section
  master in `gate_control` ctrlA bit 2. The pedal mask is preserved
  across that call by reading from the cached `_dist_state`.

## Safe defaults at construction time

| Field | Default |
| --- | --- |
| section master | OFF |
| pedal mask | `0` (all pedals off) |
| drive | 20 |
| tone | 50 |
| level | **35** (intentionally quiet) |
| bias | 50 |
| tight | 50 |
| mix | 100 |

These come from `AudioLabOverlay.DISTORTION_DEFAULTS`. The
`__init__` sequence writes them so that loading the overlay never
produces a loud transient.

## Phasing

Implement and ship in this order, each phase independently deployable:

1. **Phase A** — pedal-mask plumbing on the Python side, with a stub
   Clash where every pedal stage is bit-pass-through. Verifies the
   GPIO layout, the cache discipline, the API surface, and the
   notebook flow without touching synthesis hard.
2. **Phase B** — implement `clean_boost`, `tube_screamer`, `rat_style`,
   `metal` in Clash. Each as its own small register chain.
   `rat_style` may simply forward into the existing RAT stage and the
   new pedal mask bit 2 may be expressed as `flag4(fGate)`.
3. **Phase C** — `ds1_style`, `big_muff`, `fuzz_face`. Only if Phase B
   left enough timing margin.

Each phase ends with a Vivado timing review. A phase that regresses
WNS by more than a small amount goes back to design before it is
deployed.

## Anti-goals

- One Clash function with a `case` over all seven voicings. That is
  what we just removed.
- Hidden global state outside `Frame` and the per-stage `register …`
  values. Everything that crosses pipeline stages must be visible in
  the wiring of `fxPipeline`.
- Reference-source copying. Use the algorithm shape only; write the
  Clash from scratch. **GPL-licensed projects (guitarix, BYOD, …) are
  off-limits even as a quoting source.**
