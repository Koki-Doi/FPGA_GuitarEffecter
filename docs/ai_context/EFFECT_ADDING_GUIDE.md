# Effect adding guide

This document is the playbook for adding a new guitar effect to
Audio-Lab-PYNQ without breaking the rest of the build. Read it
before touching `LowPassFir.hs`, `block_design.tcl`, or any
`axi_gpio_*` topology.

The big rule: **the GPIO design is fixed.** New effects fit into the
slots already documented in [`GPIO_CONTROL_MAP.md`](GPIO_CONTROL_MAP.md).
Adding a new `axi_gpio_*` IP is a last resort and requires user
sign-off.

## 1. Decision flow

Before writing any code, answer these in order. The first "yes" wins.

1. **Is this purely a Python / notebook change?**
   - No new control bits, no new audio behaviour, just a new way of
     calling existing knobs.
   - Examples: a new preset, a UI re-layout, a recording helper, an
     A/B compare cell.
   - → Edit Python / notebook only. **No Vivado, no Clash, no
     bit/hwh.** Run `make tests`, deploy with
     `bash scripts/deploy_to_pynq.sh`.

2. **Does the new effect fit a `reserved` byte / bit already
   documented in `GPIO_CONTROL_MAP.md`?**
   - Reserved slots today: `axi_gpio_distortion.ctrlD[7]`
     (8th pedal slot — bits 3/4/5 were promoted from reserved
     to implemented in the reserved-pedal branch and now carry
     the `ds1` / `big_muff` / `fuzz_face` Clash stages),
     `axi_gpio_noise_suppressor.ctrlD` (mode byte),
     `axi_gpio_eq.ctrlD` (planned EQ-section knob).
   - → Add the Clash stage, wire it on the existing GPIO bit /
     byte, add a Python writer, update the notebook. Vivado bit/hwh
     **must** be rebuilt and timing reviewed.
   - Worked example: the reserved-pedal branch added three
     independent register-staged blocks (`ds1` 5 stages,
     `big_muff` 5 stages, `fuzz_face` 4 stages) on
     `axi_gpio_distortion.ctrlD[3..5]` — no GPIO change, no
     `topEntity` port change, just three new pedal sections in
     `fxPipeline` after `metalLevelPipe`.

3. **Does the new effect need a new control byte but can ride on a
   currently-unused or repurpose-able slot?**
   - There are no truly unused slots in the deployed bitstream. If
     this is what your effect needs, it actually falls under case 4.

4. **Does the new effect need a new `axi_gpio_*` IP?**
   - This is the "block-design change" path. **Do not start without
     explicit user approval.** Once approved:
     - Edit `block_design.tcl` (add IP, address segment, interconnect,
       clock / reset).
     - Bump `NUM_MI` on `ps7_0_axi_periph` to match the new master
       count.
     - Add a new `topEntity` port on `LowPassFir.hs`, regenerate VHDL,
       repackage the IP.
     - Rebuild Vivado bit/hwh, review timing, deploy.
     - Add the GPIO row to `GPIO_CONTROL_MAP.md`, add an ADR entry to
       `DECISIONS.md`, add a Python writer + tests + notebook UI.
   - Shipped exceptions are `axi_gpio_noise_suppressor` at
     `0x43CC0000` (DECISIONS.md D11) and `axi_gpio_compressor` at
     `0x43CD0000` (DECISIONS.md D14). Treat any new IP the same way.

The compressor add is a worked example of case 4. The Compressor
section needed five knobs (threshold / ratio / response / makeup /
enable); none of the existing `reserved` bytes / bits were a fit
(distortion pedal slots are reserved for future pedals, NS ctrlD is
reserved for NS modes, EQ ctrlD is reserved for a future EQ knob,
`gate_control.ctrlA` is full). It landed on a new
`axi_gpio_compressor` GPIO at `0x43CD0000` with explicit user sign-off
and a full Vivado / Clash / bit / hwh rebuild. The Compressor enable
flag lives inside the new GPIO (`ctrlD` bit 7), so the master flag
byte was not touched.

## 2. Priority order when in doubt

1. Python API + UI **reservation** first (declare the parameter,
   accept it, wire a no-op).
2. Map onto an existing GPIO byte / bit (use a `reserved` slot if
   available).
3. Add a Clash stage that consumes the existing byte / bit.
4. Last resort: add a new `axi_gpio_*` IP.

Reaching step 4 means a `block_design.tcl` change and a full
hardware rebuild — escalate first.

## 3. GPIO allocation rules (recap)

These rules are also in [`GPIO_CONTROL_MAP.md`](GPIO_CONTROL_MAP.md);
repeating here for the effect-adding context.

- **Never rename a GPIO.** `axi_gpio_delay` controls the RAT, not a
  delay; the name is locked into the block design and the `.hwh`.
- **Never change addresses.** Address map is part of the deployed
  bitstream contract.
- **Never repurpose a `legacy mirror` byte** (`axi_gpio_gate.ctrlB`).
  It is dead in the live bitstream but writers still feed it; deleting
  the writer will break older bitstreams.
- **Never repurpose a `reserved` byte for a different feature.**
  Bit 7 of `axi_gpio_distortion.ctrlD` is held for the 8th pedal
  slot; do not stuff a chorus or any non-pedal feature into it.
- **Use `reserved` slots first.** They were carved out so new effects
  can land without GPIO churn.
- **AXI GPIO is output-only** — Python keeps a cache and does
  read-modify-write on the cached word. Every new writer must
  preserve every byte it does not own.
- **All four layers must agree.** Python writer, Clash stage, notebook
  UI, and tests must move in lock-step.

## 4. Clash DSP stage rules

These come from the timing post-mortem in
[`TIMING_AND_FPGA_NOTES.md`](TIMING_AND_FPGA_NOTES.md) and the design
notes in [`DSP_EFFECT_CHAIN.md`](DSP_EFFECT_CHAIN.md). Breaking one of
these is what regressed WNS from -7.7 ns to -15.1 ns last time.

1. **Bit-exact bypass when the enable bit is clear.** Use the pattern
   `f { fL = if on then new else fL f }`. The synthesiser must see
   that `(off, X)` and `(off, Y)` produce identical output for every
   input.
2. **One operation per register stage.** A multiply, a shift+saturate,
   a clip, a one-pole IIR — pick one per stage, then register.
3. **Never put a wide `case` on a model selector inside a stage.** The
   8-way `case modelSelect of …` is what broke timing; the pedal-mask
   pattern with one independent stage per pedal replaced it.
4. **Saturate before re-entering the `Sample` lane.** Every `Wide`
   output ends in `satWide` / `satShiftN` / one of the `*Clip`
   helpers. No unsaturated `Wide` may flow into the next multiplier
   chain.
5. **Per-channel filter state lives in pipeline-level registers.**
   See `ratHpInPrevL` / `tsHpfLpPrevL` / `metalPostLpPrevR` for the
   shape. Use `register 0 (frameOr ... <$> reg <*> pipe)`.
6. **Reuse `Frame` accumulator fields for transients only.**
   `fAccL/R`, `fAcc2L/R`, `fAcc3L/R`, `fEqLowL/R`, `fEqHighLpL/R` are
   downstream-overwritten and safe to reuse inside a stage.
7. **Insert the new stage between the closest two existing stages.**
   For pedal-mask additions, insert between `tube_screamer` and
   `metal`. Avoid touching the order of unrelated stages.
8. **Run `clash --vhdl` and confirm `component.xml` shows the new
   port** if you added one. Without it the block-design connection
   fails to bind.

## 5. Python API rules

The pattern in `AudioLabOverlay.py` is consistent and the new
`control_maps.py` / `effect_defaults.py` / `effect_presets.py` modules
make it easier to follow:

1. **Defaults live in `effect_defaults.py`.** A new dict like
   `MY_EFFECT_DEFAULTS = {"enabled": False, ...}` keeps the safe
   start-up shape in one place.
2. **Encoding helpers go through `control_maps.py`.** Use
   `pack_u8x4`, `set_byte`, `get_byte`, `percent_to_u8`,
   `level_to_q7`, `clamp_u8`, etc. Do not re-implement byte packing
   in the overlay class.
3. **Public API.** Provide:
   - `set_<effect>_settings(**kwargs)` — partial updates allowed,
     unset params keep cached values.
   - `get_<effect>_settings()` — returns the cached state plus byte
     view for the notebook.
   - Per-knob shortcuts (`set_<effect>_<knob>`) only when there is a
     real reason — a notebook callback rarely benefits from them.
4. **Cache discipline.** Store `_<effect>_state = dict(MY_EFFECT_DEFAULTS)`
   and `_cached_<effect>_word = 0` in `__init__`. Read-modify-write
   the cached word on every change; never assume the GPIO is
   readable.
5. **`set_guitar_effects` integration.** If the new effect rides on
   `gate_control.ctrlA`, hook it in at the en-masse writer, mirror
   any cached bytes back into the kwargs so they survive. Add
   regression tests.
6. **Tests in `tests/test_overlay_controls.py`.** Every new public
   API surface must come with tests. For a new GPIO byte, add a
   snapshot test in the same file so the encoding cannot drift.

## 6. Notebook rules

Live UI is `audio_lab_pynq/notebooks/GuitarPedalboardOneCell.ipynb`.

1. **Add a new accordion section** rather than restructuring the
   existing ones. The accordion is where users expect to find each
   effect; reordering breaks muscle memory.
2. **Use `make_slider` / `make_section`** helpers in the cell — they
   keep the layout / style consistent.
3. **Apply via the Apply button.** Never write to the GPIO on
   slider-change events; users expect to tweak then apply.
4. **Safe Bypass must reset your widgets too.** Append the resets in
   `safe_bypass()`.
5. **Presets go through `effect_presets.py`** with an inline fallback
   in the notebook for older deployed packages. Mirror any value
   change into the fallback in the same commit.
6. **JSON sanity.** After editing, run
   `python3 -c "import json; json.load(open(<path>))"` to confirm the
   notebook still parses.

## 7. Build / deploy checklist

Use the matching column for the change you made.

| Change scope | Vivado | Clash | bit/hwh | PYNQ deploy | Smoke test |
| --- | --- | --- | --- | --- | --- |
| Notebook only | no | no | no | yes (`scripts/deploy_to_pynq.sh`) | re-run notebook |
| Python only | no | no | no | yes | NS / dist round-trip print |
| Reserved-bit Clash stage | yes | yes | yes | yes | per-pedal smoke + timing |
| New `axi_gpio_*` IP | yes | yes | yes (block design too) | yes | board-side `hasattr` check |

After any Clash / Vivado run, compare the WNS / WHS / THS to the
[`TIMING_AND_FPGA_NOTES.md`](TIMING_AND_FPGA_NOTES.md) baseline.
**Do not deploy** a bitstream whose WNS is significantly worse than
the previous deployed value.

## 7b. Chain presets vs. new effects

Practical pedalboard voicings (Safe Bypass / Basic Clean / Tube
Screamer Lead / Metal Tight / ...) are **not** new effects. They are
named entries in `audio_lab_pynq.effect_presets.CHAIN_PRESETS` that
orchestrate the existing setters. Adding one is a Python-only change
(case 1 in section 1): no Vivado, no Clash, no bit/hwh.

Constraints to keep:

- Compressor `makeup` ∈ [45, 60] across every preset. Distortion
  `level` ≤ 35. `Safe Bypass` has every section `enabled=False` and
  `reverb.mix=0`. The tests in `tests/test_overlay_controls.py`
  enforce these so a future preset cannot silently regress them.
- One section dict per `CHAIN_PRESET_SECTIONS` entry. Match the
  argument names of the corresponding `set_*_settings` calls so
  `apply_chain_preset` can pass them straight through.
- If a preset wants behaviour the FPGA does not currently expose
  (e.g. lookahead compressor, multiband EQ), do **not** quietly add
  a new GPIO from the preset layer. File a separate ADR (D11 / D14
  style) and follow section 1 case 4.

See [`DECISIONS.md`](DECISIONS.md) D15.

## 8. C++ DSP prototypes are not the path

The earlier reference C++ implementations under `src/effects/` were
removed (`DECISIONS.md` D12). The single source of truth for DSP
behaviour is `hw/ip/clash/src/LowPassFir.hs`. **Do not** write a new
C++ prototype as a stepping stone. New effect work goes:

1. Python API + UI reservation.
2. Clash stage on an existing GPIO bit / byte.
3. (rare) New AXI GPIO with explicit user sign-off.

Algorithmic structure of GPL projects (guitarix, BYOD, etc.) is fair
game as inspiration; their source is not (`DECISIONS.md` D7).

## 9. Where to write the effect

Use [`EFFECT_STAGE_TEMPLATE.md`](EFFECT_STAGE_TEMPLATE.md) as a
fillable spec. Submit it (filled in) alongside the implementation
PR — it doubles as the design memo.
