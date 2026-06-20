# Design decisions (ADR-style)

Each entry is a decision that earlier work made and that future work
should not silently revisit. New decisions go at the bottom; old ones do
not get removed even when superseded — they get updated.

Baseline statements inside older ADRs are historical unless the newest ADRs and
`CURRENT_STATE.md` say otherwise. The current canonical deployed baseline is
D135 (`765323b`, bit `533d5869...`), tracked in
`docs/ai_context/baselines.json` / `docs/ai_context/BASELINES.md`.

---

## D1 — ADAU1761 ADC HPF is enabled by default

- **Decision.** `config_codec()` writes `R19_ADC_CONTROL = 0x03`, then
  uses RMW via `enable_adc_hpf()` to set R19[5], so the post-init value
  is `0x23`. A 300 ms settle is included before the DAC is enabled.
- **Why.** With the HPF off, capture-with-input-shorted showed a
  significant DC offset and elevated RMS. Toggling R19[5] removed the
  offset and dropped RMS dramatically, so the user requested it be the
  permanent default.
- **Important caveats.**
  - This is a ~2 Hz DC blocker, **not** a 20–40 Hz guitar low-cut.
    Treat it as an offset remover, nothing more.
  - The IIR has τ ≈ 80 ms at 48 kHz. After any toggle, allow ~3–4 τ
    (≈ 300 ms) before measurement, and discard the first ~50 ms of any
    capture (handled in `diagnostic_capture` with `settling_ms` and
    `discard_initial_frames`).
- **How to apply.** Never remove the `enable_adc_hpf()` call from
  `config_codec()`. If a future test needs it off, do it explicitly and
  restore the default.

## D2 — `block_design.tcl` is off-limits by default

- **Decision.** New control bits and new effect stages reuse the spare
  bytes of the existing `axi_gpio_*` IPs. Adding or reconfiguring an
  AXI GPIO requires a `block_design.tcl` change and explicit user
  approval.
- **Why.** The existing block design has timing margin already eaten
  (see `TIMING_AND_FPGA_NOTES.md`). Touching the block design risks
  regenerating addresses, breaking the C++/Python address map, and
  destabilising the build.
- **How to apply.** When asked for new control bits, look for a spare
  byte first (`GPIO_CONTROL_MAP.md`). Only escalate to a block-design
  change when the user agrees in writing.

## D3 — Deploys go through `scripts/deploy_to_pynq.sh`

- **Decision.** Any change that ships to the PYNQ-Z2 goes through that
  script, which uses SSH key auth and never stores a password.
- **Why.** Earlier ad-hoc `scp` flows risked interactive password
  prompts that the agent could not satisfy and risked desyncing the
  package install vs the bitstream.
- **How to apply.** Use the script. Override host or paths via env
  vars (`PYNQ_HOST`, `PYNQ_USER`, `PYNQ_REPO_DIR`, `PYNQ_NB_DIR`,
  `SSH_KEY`).

## D4 — PYNQ overlay work needs root

- **Decision.** Anything that touches `Overlay()`, DMA, `pynq.allocate`
  or the `/dev/uio*` devices runs as `sudo`. Use
  `sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 …`.
- **Why.** The PYNQ Linux image gates UIO and contiguous-memory
  allocation behind root. Trying to use the overlay as `xilinx`
  fails with surprising error messages that point in the wrong
  direction.

## D5 — Live package source is `/home/xilinx/Audio-Lab-PYNQ/`

- **Decision.** Always put `/home/xilinx/Audio-Lab-PYNQ` first on
  `PYTHONPATH` for board-side runs.
- **Why.** The PYNQ image carries an older copy of `audio_lab_pynq`
  under `/usr/local/lib/python3.6/dist-packages/`. Without the
  PYTHONPATH override the test may run the wrong code and silently
  succeed, hiding regressions.

## D6 — The `model_select` 8-way mux distortion plan is dead

- **Decision.** Selectable distortion models are implemented as
  independent pedal stages (each with its own enable bit), not as a
  numeric `model_select` driving a giant case statement. This
  decision shipped in commit `baa97ff`.
- **Why.** The `model_select` build pushed Vivado WNS from -7.722 ns
  to -15.067 ns. The combinational depth of the per-stage 8-way case
  was the cause; the design did not deploy safely in that shape. The
  pedal-mask replacement restored WNS to -7.801 ns and was deployed.
- **How to apply.** Read `DISTORTION_REFACTOR_PLAN.md`. Do not add
  new `case modelSelect of …` blocks to `LowPassFir.hs`. Pedal
  enables live in `distortion_control.ctrlD`; the section master
  stays at `gate_control.ctrlA[2]`.

## D7 — Reference repositories are read-only inspiration

- **Decision.** Algorithmic structure of guitarix, BYOD, JS-Rocks,
  PunkMuff, ToobAmp, dm-Rat, etc. may be studied. Their **source
  code is not copied** into this repository.
- **Why.** Several of those projects are GPL-licensed. This
  repository is WTFPL. Pasting GPL code (whole or near-verbatim) is
  not compatible. Beyond the licence question, hand-rolling the Clash
  forces us to keep the implementation small enough to fit the FPGA.
- **How to apply.** No `git submodule add`, no `git clone` into the
  tree. If a reference is needed for a session, clone it into
  `/tmp` or another scratch path the repo never sees.

## D8 — `rat` pedal maps onto the existing RAT stage

- **Decision.** The `rat` entry in the new pedal-mask API does not
  add a new Clash stage. Instead, when bit 2 of
  `distortion_control.ctrlD` is set, the Python facade
  (`_apply_distortion_state_to_words`) also forces `gate_control`
  bit 4 high, engaging the existing RAT block (`ratHighpassFrame`
  through `ratMixFrame`).
- **Why.** The existing RAT implementation is a complete, tested,
  parameter-rich voicing. Re-implementing it inside the new
  pedal-mask pipeline would have duplicated logic, eaten timing,
  and produced a slightly different sound for no gain.
- **How to apply.** Do not add a `ratStyle*Frame` chain. If the
  user wants a different RAT-style flavour, expose it as a new
  pedal bit (e.g. an unused reserved slot) rather than rewriting
  the existing one.
- **Naming alias.** The underlying AXI GPIO at `0x43C80000` is
  still named `axi_gpio_delay` in the block design and HWH — that
  name is locked under D2 / D12 so it cannot move. New code reading
  the overlay should prefer `AudioLabOverlay.axi_gpio_rat`, a
  read-only `@property` that returns the same MMIO object as
  `axi_gpio_delay`. Internal write paths in `AudioLabOverlay` and
  the GPIO map docs still use `axi_gpio_delay` because that is
  what `overlay.ip_dict` advertises.

## D9 — `ds1` / `big_muff` / `fuzz_face` reservation lifted; bits 3-5 are now implemented

- **Decision (original).** Bits 3, 4, 5 of `distortion_control.ctrlD`
  were reserved for `ds1`, `big_muff`, and `fuzz_face` while the
  Python API and notebook UI already accepted the names; the FPGA
  passed audio through bit-exact when only those bits were set.
- **Decision (current, `feature/add-reserved-distortion-pedals`).**
  All three reserved pedals now have working Clash stages in the
  deployed bitstream:
  - `ds1` (bit 3): 5 register stages — HPF -> mul -> asym soft clip
    with low knees -> post LPF -> level+safety. Voicing aim is
    BOSS DS-1 style edgy crunch.
  - `big_muff` (bit 4): 5 register stages — pre-gain -> softClipK
    medium knee -> softClipK tighter knee with ~0.75x gain ->
    tone LPF -> level+safety. Voicing aim is Big Muff Pi style
    cascaded soft clip with a darker top end.
  - `fuzz_face` (bit 5): 4 register stages — pre-gain -> strong
    asymSoftClip -> tone LPF -> level+safety. Voicing aim is
    Fuzz Face style raw asymmetric breakup; the TONE knob doubles
    as a "round vs. bright" axis since real Fuzz Faces typically
    lack a tone control.
  Each block is gated by its own enable predicate (`ds1On` /
  `bigMuffOn` / `fuzzFaceOn`); when the bit is clear every stage is
  bit-exact bypass. The new sections slot into `fxPipeline` after
  `metalLevelPipe`, with `distortionPedalsPipe = fuzzFaceLevelPipe`.
- **Why the original reservation was kept.** Locking the bit
  positions early kept the GPIO layout and Python API stable across
  the staged rollout, so the implementation work was a pure code
  addition: no GPIO shuffle, no Python API churn, no notebook
  rewrite of the per-pedal pipeline.
- **Trade-offs not taken.**
  - **No** copying of source code from BOSS DS-1 schematics-exact
    coefficient tables, the public Big Muff Pi schematic, or
    Dallas Arbiter / Dunlop Fuzz Face circuit transcriptions, nor
    from any GPL DSP project (guitarix, BYOD, JS-Rocks,
    PunkMuff, dm-Rat, ToobAmp, etc.). Algorithmic shape (HPF ->
    drive -> clip -> post LPF -> level, soft / hard / asym clip
    helper choice, cascaded soft clip for Muff-style fuzz, low-knee
    asym clip for fuzz-face-style breakup) is the only thing taken
    (`DECISIONS.md` D7).
  - **No** new GPIO. Bit 7 of the pedal mask remains the only
    reserved slot, held for a future 8th pedal.
  - **No** revival of the 8-way `model_select` mux structure; each
    pedal stays in its own register-staged block (`DECISIONS.md`
    D6 / `TIMING_AND_FPGA_NOTES.md`).
  - **No** new C++ DSP prototype as a stepping stone (`DECISIONS.md`
    D13). Implementation went Python API + UI relabel -> Clash
    stages directly.
- **How to apply.**
  - When changing a `ds1` / `big_muff` / `fuzz_face` voicing, edit
    the matching `ds1*Frame` / `bigMuff*Frame` / `fuzzFace*Frame`
    block in `LowPassFir.hs`. Do not introduce a wider case over
    pedal selectors; each block is independently enabled.
  - The Python API surface (`set_distortion_pedal`,
    `set_distortion_pedals`, `set_distortion_settings(pedal=...)`)
    is unchanged; the only public change is that
    `DISTORTION_PEDALS_IMPLEMENTED` now lists every pedal name.
  - Notebook reserved-pedal warning banners are dropped. Keep the
    legacy `*_reserved` PEDAL_LABEL_TO_API aliases pointing at the
    implemented pedals so older live notebook sessions still work.

## D11 — Noise suppressor lives on its own AXI GPIO; legacy gate is replaced

- **Decision.** A dedicated `axi_gpio_noise_suppressor` IP at
  `0x43CC0000` carries THRESHOLD / DECAY / DAMP / mode for a BOSS
  NS-2 / NS-1X-style noise suppressor. The Clash side replaces the
  legacy hard noise gate stages (`gateLevelPipe -> gateEnv -> gateOpen
  -> gateGain -> gatePipe`) with new envelope + smoothed-gain stages
  (`nsLevelPipe -> nsEnv -> nsGain -> nsPipe`). Enable still rides on
  `gate_control` bit 0 (the legacy `noise_gate_on` flag).
- **Why.** The legacy noise gate exposed a single hard threshold whose
  Python 0..100 range collapsed onto 0..10 in practice and chopped
  signal at the close transition. NS-2 / NS-1X-style THRESHOLD /
  DECAY / DAMP gives users a smoothed close ramp and a controllable
  closed-gain floor while staying cheap on the FPGA (one envelope
  register feedback + one smoothed-gain register feedback + one
  saturating multiply, same shape as the legacy gate).
- **Trade-offs not taken.**
  - **No** RNNoise / FFT / spectral subtraction. Way too heavy for the
    PYNQ-Z2 PL budget; the suppressor is purely a smoothed time-domain
    gate.
  - **No** copying of source code from BOSS units, JS-Rocks NS-style
    blocks, or `noise-suppression-for-voice` / `libspecbleach` /
    similar GPL projects. Algorithmic shape (envelope follower,
    threshold compare, smoothed gain, damp closed-gain floor) is the
    only thing taken from the references.
- **Threshold scale change.** Python `noise_gate_threshold` is now on a
  one-tenth scale: byte = `round(threshold * 255 / 1000)`, so the new
  100 maps to the legacy 10 byte. `set_guitar_effects(noise_gate_threshold=...)`
  uses the same scaling and mirrors the byte to both the legacy
  `gate_control.ctrlB` slot (dead in the new bitstream, kept for
  backward compatibility) and the new `noise_suppressor_control.ctrlA`.
- **How to apply.**
  - When changing the noise stage, edit the `ns*` block in
    `LowPassFir.hs`. Do **not** revive the legacy `gateGainNext` /
    `gateFrame` registers in the active pipeline.
  - `block_design.tcl` carries the new GPIO; any further GPIO change
    must keep `axi_gpio_noise_suppressor` and its address `0x43CC0000`
    intact so overlays match.
  - Reserved knobs (mode byte, attack, hold, NS-2 vs NS-1X switch)
    should land on `noise_suppressor_control.ctrlD` rather than
    grabbing more bytes from existing GPIOs.

## D12 — GPIO design is fixed; effect refactors do not move bytes

- **Decision.** Once a GPIO has been deployed (name, address, and the
  meaning of `ctrlA` / `ctrlB` / `ctrlC` / `ctrlD`), refactors must
  not move it. Adding a new effect should land on a `reserved` byte
  / bit already documented in `GPIO_CONTROL_MAP.md`. Adding a new
  `axi_gpio_*` IP is a last resort and requires explicit user
  approval (D2 still applies).
- **Why.** Multiple deployed bitstreams already carry this address
  map. Renaming or shuffling bytes risks silently breaking older
  bitstreams in the field (cf. `axi_gpio_delay`, which is named for
  a delay but drives the RAT — and cannot be renamed without a
  block-design change). Locking the layout also keeps Python /
  Clash / notebook / tests in lock-step.
- **How to apply.**
  - When you reach `GPIO_CONTROL_MAP.md`, treat the table as a
    contract; never edit a row's address or its `ctrlA`-`ctrlD`
    semantics in the same change as a refactor.
  - If a refactor "wants" to rename a GPIO, propose a follow-up
    change instead and flag it for user approval.
  - The shipped exception is `axi_gpio_noise_suppressor` at
    `0x43CC0000` (D11). Any future exception goes through the same
    gate.

## D13 — C++ DSP prototypes were removed from the active tree

- **Decision.** The earlier `src/effects/*.cpp` files
  (`RatStyleDistortion`, `SimpleAmpSimulator`, `CabIRSimulator`)
  were removed, along with their CPU-side tests
  (`tests/test_rat_style_distortion.cpp`,
  `tests/test_amp_cab_simulators.cpp`). The single source of truth
  for DSP behaviour on the live build is
  `hw/ip/clash/src/LowPassFir.hs`.
- **Why.** The C++ files were only reference implementations and
  never ran on the PYNQ-Z2 audio path. Their continued presence in
  the tree invited the "implement in C++ then port" pattern, which
  is not how this project ships effects — every effect is built
  directly in Clash for fixed-point + pipelined synthesis. Keeping
  the prototypes also confused agents and humans into believing
  `make tests` validated the FPGA path, which it never did.
- **How to apply.**
  - New effects start at the Python / UI / Clash layer; do not
    introduce a new C++ prototype.
  - Algorithm shape from GPL projects (guitarix, BYOD, etc.) is
    fair to reference (D7); their source is not.
  - `make tests` now runs Python tests only. The earlier
    `make cpp_tests` / `make test_cpp` no-op stubs were kept for a
    transition window after the prototypes were deleted; those stub
    targets are now gone (`Makefile`). If a future agent finds
    documentation that still references them, treat the doc as stale.

## D14 — Compressor lives on its own AXI GPIO

- **Decision.** A dedicated `axi_gpio_compressor` IP at `0x43CD0000`
  carries THRESHOLD / RATIO / RESPONSE / enable+MAKEUP for a stereo-
  linked feed-forward peak compressor. The Clash side adds a new
  `compressor_control` port and a `compLevelPipe -> compEnv ->
  compGain -> compApplyPipe -> compMakeupPipe` block between the
  noise suppressor and the overdrive. Enable lives **inside this
  GPIO** (`ctrlD` bit 7), not on `gate_control.ctrlA`.
- **Why.**
  - The compressor needed five distinct knobs (threshold / ratio /
    response / makeup / enable). Stuffing them onto an existing
    `reserved` byte / bit was not possible:
    `axi_gpio_distortion.ctrlD[3..5,7]` is held for the reserved
    distortion pedals (`DECISIONS.md` D9),
    `axi_gpio_noise_suppressor.ctrlD` is held for NS-2 vs NS-1X
    mode / attack / hold (D11), `axi_gpio_eq.ctrlD` is held for a
    future EQ-section knob. Repurposing any of those would violate
    `DECISIONS.md` D12.
  - `gate_control.ctrlA` is the master flag byte and every bit is
    already owned by an existing effect's enable. Adding a new
    flag bit there would touch the meaning of an `active` byte,
    which D12 forbids.
  - The compressor benefits from being able to flip its own enable
    without read-modify-write on a shared flag byte; keeping the
    enable inside its own GPIO makes the section fully self-
    contained.
- **Trade-offs not taken.**
  - **No** copying of source code from the references studied for
    parameter naming and design philosophy: harveyf2801/AudioFX-
    Compressor, bdejong/musicdsp simple compressor, DanielRudrich/
    SimpleCompressor, chipaudette/OpenAudio_ArduinoLibrary,
    p-hlp/SMPLComp (GPL-3.0), Ashymad/bancom (GPL-3.0). Algorithmic
    structure (feed-forward peak detect, stereo link, gain
    reduction computer, envelope follower, makeup) is the only
    thing taken (`DECISIONS.md` D7).
  - **No** lookahead, knee, multiband, sidechain input, or
    dB/log-domain math. The first compressor build is intentionally
    a 1-GPIO, light-weight ggitar-friendly section.
  - **No** C++ DSP prototype as a stepping stone (`DECISIONS.md`
    D13). Implementation went Python API + UI reservation -> Clash
    stage -> new GPIO directly.
- **How to apply.**
  - When changing the compressor stage, edit the `comp*` block in
    `LowPassFir.hs`. Do not move or rename the block;
    `axi_gpio_compressor` and the `compressor_control` port are
    pinned by `block_design.tcl` and the deployed `.hwh`.
  - Reserved knobs (sidechain HPF, knee, mix, lookahead, attack and
    release as separate parameters) should land on a new GPIO via
    a new ADR rather than steal bytes from existing GPIOs.
  - The Python `set_compressor_settings(...)` API and the byte
    encoding in `control_maps.compressor_word` /
    `control_maps.makeup_to_u7` are the source of truth; keep
    notebook and tests in lock-step.

## D15 — Chain presets are Python/UI only, never new GPIO

- **Decision.** Practical pedalboard voicings ship as named entries in
  `effect_presets.CHAIN_PRESETS` and are applied via the Python
  facade (`AudioLabOverlay.apply_chain_preset`). They orchestrate the
  existing per-section setters and `set_guitar_effects`; they do
  **not** introduce new AXI GPIOs, new Clash stages, or new bitstream
  artefacts.
- **Why.** The chain-preset work is a usability layer on top of an
  already-deployed bitstream. Adding a new GPIO would force a full
  Vivado / Clash rebuild, a timing review, and a new bit/hwh deploy
  for what is essentially a curated lookup table. Keeping presets in
  Python also makes them easy to edit, snapshot-test, and iterate on
  without touching hardware.
- **Safety guarantees in the preset table.**
  - Compressor `makeup` is held to the 45..60 band (~unity to ~1.25x)
    in every preset, so flipping presets cannot produce a sudden
    volume jump that blows the rest of the chain.
  - Distortion `level` is capped at 35 in every preset.
  - The `Safe Bypass` preset has every section's `enabled=False` and
    `reverb.mix=0`. Tests enforce both.
- **How to apply.**
  - When adding a new preset, append it to `CHAIN_PRESETS` with one
    entry per section (`compressor` / `noise_suppressor` /
    `overdrive` / `distortion` / `amp` / `cab` / `eq` / `reverb`).
    The notebook picks it up automatically through
    `get_chain_preset_names()`.
  - Keep makeup in 45..60 and distortion `level` <= 35 unless you
    have a specific reason and update the safety tests in lock-step.
  - Do not introduce a new GPIO or a new Clash stage from this layer
    -- if a preset wants behaviour the FPGA does not currently
    expose, file it as a separate ADR (D11 / D14 style) instead.

## D16 — Real-pedal voicing pass tunes existing stages, never adds new ones

- **Decision.** Effect voicings can be moved closer to recognised
  real-pedal voicings (TS / RAT / MT-2 / Dyna Comp / NS-2 / cab IR /
  pedal reverb) by editing the constants and clip-helper choice
  inside the existing register stages of `LowPassFir.hs`. A voicing
  pass must **not** add a new GPIO, a new `topEntity` port, a new
  Clash register stage, or a new effect block. Reserved bytes / bits
  documented in `GPIO_CONTROL_MAP.md` stay reserved.
- **Why.**
  - Adding a GPIO or a new stage forces a `block_design.tcl` change
    (forbidden by D2 without explicit user approval) and re-opens
    timing risk that the pedal-mask refactor (D6 / `model_select`
    post-mortem) already paid down.
  - Existing chain presets and the public Python API are
    byte-for-byte compatible across the voicing pass: the bytes the
    notebook writes to each GPIO are unchanged, only the meaning
    given to those bytes by the live Clash bitstream shifts. Users
    keep the same control range and the same slider numbers.
  - The reference style for each effect is documented in
    `REAL_PEDAL_VOICING_TARGETS.md` so future passes have a clear
    "did the change land in the intended direction?" check.
- **Trade-offs not taken.**
  - **No** copying of source code from Tube Screamer / RAT / MT-2 /
    Dyna Comp / NS-2 / NS-1X schematics-exact coefficient tables, or
    GPL DSP projects. Algorithmic shape (HPF -> drive -> clip ->
    post LPF -> level, soft / hard / asym clip choice, hysteresis
    around a threshold, IR coefficient damping) is the only thing
    taken (`DECISIONS.md` D7).
  - **No** new C++ DSP prototype as a stepping stone (`DECISIONS.md`
    D13). Voicing changes go directly into Clash.
  - **No** new lookahead, no new multi-band processing, no new
    spectral methods. The PL budget is what it is.
- **How to apply.**
  - Read `REAL_PEDAL_VOICING_TARGETS.md` before changing the voicing
    of an effect; record the new target / current / gap / plan rows
    in the same file.
  - Constant changes inside an existing stage are fine. Replacing
    `softClip` with `softClipK` / `asymSoftClip` / `hardClip` is
    fine. Changing a `mulU8` to a different gain expression is fine.
  - Adding a new register-staged block, a new `Frame` field, or a
    new `topEntity` port is **not** a voicing change; that is a new
    effect (case 4 in `EFFECT_ADDING_GUIDE.md`).
  - After any voicing pass that touches `LowPassFir.hs`: run
    `clash --vhdl`, repackage the IP via Vivado `create_ip.tcl`,
    rebuild bit/hwh, check timing, deploy, smoke-test all chain
    presets on the board.
  - The first voicing pass landed on the `feature/real-pedal-voicing-
    pass` branch and rebuilt the deployed bitstream from
    WNS = -7.516 ns to WNS = -6.405 ns (improved by 1.111 ns); hold
    stayed clean.

## D10 — `GuitarPedalboardOneCell.ipynb` is the user-facing entry point

- **Current status.** Historical for the original ADAU/DSP notebook
  surface. The current Pmod I2S2 bench entry point is
  `PmodI2S2EffectControlOneCell.ipynb` (D49/D50), while
  `GuitarPedalboardOneCell.ipynb` remains the generic pedalboard UI and
  chain-preset compatibility surface.
- **Decision.** A new two-cell notebook,
  `audio_lab_pynq/notebooks/GuitarPedalboardOneCell.ipynb`, is the
  primary single-screen UI for the live chain. It exists alongside
  the existing `GuitarEffectSwitcher.ipynb` and
  `DistortionModelsDebug.ipynb`; none of them is being deprecated.
- **Why.** The existing switcher and debug notebooks have specific
  jobs (per-effect tweak / per-pedal walkthrough). The one-cell
  notebook is what a player should open: Apply / Safe Bypass /
  Refresh + four presets, with the distortion pedalboard as a
  first-class UI section.
- **How to apply.** Notebook-only edits land here; no
  bitstream rebuild needed. Reserved pedals stay selectable so the
  UI does not change shape when those Clash stages land later.

## D17 — Audio-analysis-driven voicing fixes tune existing stages only

- **Decision.** Recording-analysis-driven voicing fixes are implemented by
  retuning constants, coefficient tables, and clip-helper knees inside
  existing `LowPassFir.hs` stages. They must not add a new GPIO, a new
  `topEntity` port, a new `block_design.tcl` change, or a new selector
  topology.
- **Why.**
  - The recording analysis in `AUDIO_RECORDING_ANALYSIS.md` showed four
    actionable gaps: AmpSim had too much >5 kHz fizz, Cabinet roll-off
    was correct but still too weak for high-gain pedals, Overdrive was
    nearly indistinguishable from Bypass, and Compressor crest factor was
    almost unchanged.
  - The existing controls already expose the needed musical axes:
    Overdrive drive/tone/level, Compressor threshold/ratio/response/makeup,
    Amp input gain / master / presence / resonance / BMT / character, and
    Cab mix / level / model / air. Reusing them preserves the Python API
    and Notebook UI.
  - The design already runs with negative setup slack. A long cabinet IR,
    a new amp model selector, extra dB/log-domain processing, or a new
    GPIO would reopen timing and integration risk for a voicing problem.
- **What changed in the analysis pass.**
  - Amp: input gain ceiling trimmed again, post-clip pre-LPF darkened,
    treble and presence contribution capped harder, resonance/presence /
    power/master safety `softClipK` knees moved earlier.
  - Cab: the existing 4-tap coefficient table was rebuilt again with
    stronger model separation. Model 0 remains a lighter 1x12 open-back
    style, model 1 a balanced 2x12 combo style, and model 2 the darkest
    4x12 closed-back style for DS-1 / Metal / Big Muff / Fuzz.
  - Overdrive: drive mapping increased moderately, asymmetric clip knees
    lowered, and level output wrapped in a lower `softClipK` safety.
  - Compressor: effective threshold lowered, soft knee widened, reduction
    slope increased modestly, and response smoothing made more reactive.
  - Chain preset retune was numeric only: DS-1 Crunch now leans on Cab
    model 2 with capped air. Safe Bypass and safety caps are unchanged.
  - The deployed build kept `cabLevelMixFrame` on the existing
    timing-friendly `softClip`; a lower `softClipK 3_400_000` trial
    reached WNS = -9.891 ns and was not deployed.
  - Final deployed timing was WNS = -8.731 ns, TNS = -13665.555 ns,
    WHS = +0.051 ns, THS = 0.000 ns.
- **Trade-offs not taken.**
  - **No** commercial amp circuit constants, commercial cabinet IRs,
    pedal circuit coefficient tables, or schematic-derived coefficients
    were copied.
  - **No** GPL DSP code was moved into this WTFPL project.
  - **No** long FIR / convolution IR loader, dB/log math, lookahead,
    multiband compressor, amp model selector, new AXI GPIO, or revived
    C++ DSP prototype was added.
- **How to apply.**
  - Future voicing work should follow the loop: record -> analyze ->
    make the smallest existing-stage DSP change -> rebuild -> redeploy
    -> re-record / listen.
  - Keep Amp/Cab changes in `amp*Frame`, `ampAsymClip`, `cabCoeff`,
    `cabProductsFrame`, `cabIrFrame`, and `cabLevelMixFrame` unless the
    user explicitly approves a new topology.
  - Keep Overdrive changes in `overdriveDriveMultiplyFrame`,
    `overdriveDriveBoostFrame`, `overdriveDriveClipFrame`,
    `overdriveToneFrame` / tone blend, and `overdriveLevelFrame`.
  - Keep Compressor changes in `compThresholdSample`, `compTargetGain`,
    `compGainNext`, `compMakeupFrame`, and the existing compressor block.
  - Preserve every GPIO name, address, and `ctrlA` / `ctrlB` / `ctrlC` /
    `ctrlD` meaning from `GPIO_CONTROL_MAP.md`.
  - After any `LowPassFir.hs` voicing change: regenerate VHDL, repackage
    IP, rebuild bit/hwh, check timing, deploy only if WNS remains in the
    accepted band and WHS/THS stay clean, then smoke-test chain presets.


## D18 — Amp Simulator named models reuse `amp_character`, never new GPIO

- **Status.** Historical Amp model decision. Superseded by D53/D54/D55
  and D58.2: the live Amp Sim is now six researched models carried by
  `axi_gpio_amp_tone.ctrlD[2:0]` plus `ctrlD[7]` Drive mode; the
  `amp_character` percent API remains only as a compatibility fallback.
- **Decision.** The Amp Simulator section shipped four named voicings —
  `jc_clean` / `clean_combo` / `british_crunch` / `high_gain_stack` —
  as a convenience layer on top of the existing `amp_character`
  knob. The Python side adds an `AMP_MODELS` table, `set_amp_model`,
  `get_amp_model_names`, and `amp_model_to_character` helpers; the
  Clash side quantises the same byte into a two-bit `ampModelSel`
  index that adds a tiny per-band darken to the post-clip pre-LPF.
  The numeric `amp_character` knob still works directly.
- **Why.**
  - Listening to the audio-analysis recordings showed that high-gain
    pedals into the amp produced a second top-end brightening at the
    same `amp_character` value that worked well for clean settings.
    Splitting the character byte into 4 bands gives each named voicing
    a slightly different LPF target without making `amp_character`
    discontinuous and without breaking the chain-preset / safe-bypass
    logic that already drives the byte directly.
  - Adding a separate GPIO or `topEntity` port for an amp model
    selector would have been a `block_design.tcl` change (forbidden
    by D2 without explicit user approval) and would also have eaten
    timing on a build that is already running with negative setup
    slack. Reusing the existing byte avoids both.
  - The `model_select` post-mortem (D6) still applies. The new
    `ampModelSel` is consumed in **one** stage only and only
    biases a single alpha constant, not a wide mux over independent
    multipliers / clippers / filters.
- **Trade-offs not taken.**
  - **No** copying of commercial amp circuit constants, schematic-
    derived coefficients, or GPL DSP code (`DECISIONS.md` D7 / D11 /
    D14 / D17). The model names are inspirations only.
  - **No** new GPIO and **no** new `topEntity` port; the Frame shape
    is unchanged.
  - **No** model-specific switching of the asym clip knees, second-
    stage gain, presence cap, or resonance amount. Those stay
    continuously controlled by the existing `amp_character` /
    `amp_presence` / `amp_resonance` bytes; only the post-clip
    pre-LPF alpha is biased per band.
- **How to apply.**
  - Voicing tweaks to a specific amp model edit the matching band
    inside `ampPreLowpassFrame` (or extend `ampModelSel` to cover a
    second amp stage). Do not introduce a wide case over per-stage
    coefficient tables.
  - The Python `AMP_MODELS` mapping is the source of truth for the
    centre-of-band character values. Keep it in lock-step with the
    `ampModelSel` thresholds in `LowPassFir.hs` and the inline
    fallback inside `GuitarPedalboardOneCell.ipynb`.
  - In this historical D18 layer, the `amp_character` numeric API
    stayed public and `set_amp_model` was a thin wrapper around
    `set_guitar_effects(amp_character=...)`. In the current D55/D58.2
    layer, `amp_model_idx` + `amp_drive_mode` are the live model fields.
    Tests in `tests/test_overlay_controls.py` lock the mapping
    anchors and the per-model byte distinctness.

## D20 — Amp Simulator fizz-control pass stays within existing Amp stage

- **Decision.** The May 8 Amp Simulator high-frequency fizz-control
  pass is an existing-stage Amp retune only. It targets the excessive
  high-frequency content generated by Amp Sim itself, especially the
  broad 8..16 kHz fizz heard on high-gain voicings, without changing
  the input -> bypass path, codec/I2S/hardware routing, noise floor,
  Cab Sim topology, or any non-Amp effect.
- **What changed.**
  - `ampPreLowpassFrame` keeps the existing one-pole post-clip
    smoothing and `ampModelSel`, but increases the per-model alpha
    darken from `0 / 2 / 8 / 16` to `0 / 4 / 12 / 24`. The clean
    model stays brightest; `high_gain_stack` rolls off most.
  - `ampTrebleGain` now accepts the character byte, lowers the base
    high-band return slightly, and applies a small model trim
    (`0 / 2 / 5 / 9`) so TREBLE=100 does not restore as much
    8..16 kHz energy.
  - `ampResPresenceProductsFrame` keeps presence on the existing
    `amp_presence` byte but subtracts a model-dependent trim
    (`0`, `presence>>5`, `presence>>4`, or `presence>>3`) so
    high-gain presence is capped harder than clean presence.
  - `ampPowerFrame` and `ampResPresenceMixFrame` move the safety
    `softClipK` knee from `3_500_000` to `3_400_000`.
- **Boundaries.**
  - **No** new GPIO, no `topEntity` port, no `Frame` field, no
    `block_design.tcl` change, and no new register stage.
  - **No** Delay implementation from `feature/bram-delay-500ms`; no
    `axi_gpio_delay_line`. Legacy `axi_gpio_delay` remains present.
  - **No** Compressor / Noise Suppressor / Overdrive / Distortion
    Pedalboard / Cab IR / EQ / Reverb retune in this pass.
  - **No** analysis tool, test signal generator, C++ DSP prototype,
    commercial amp circuit / IR / coefficient copy, or GPL code.
- **Build / deploy result.** Clash type check, VHDL generation, IP
  repackage, and Vivado bit/hwh rebuild completed successfully.
  Final routed timing was WNS = -8.022 ns, TNS = -13937.512 ns,
  WHS = +0.052 ns, THS = 0.000 ns, improving WNS by 0.709 ns vs the
  prior audio-analysis deployed baseline (-8.731 ns). Utilization
  after place: Slice LUTs 21809 (40.99%), Slice Registers 18675
  (17.55%), Block RAM Tile 7 (5.00%), DSPs 158 (71.82%).
- **PYNQ result.** Deployed to PYNQ-Z2 with
  `PYNQ_HOST=192.168.1.8 bash scripts/deploy_to_pynq.sh`. Smoke test
  confirmed `ADC HPF: True`, `R19 = 0x23`,
  `has delay_line gpio: False`, `has legacy axi_gpio_delay: True`,
  all four amp models, and the requested chain presets.
- **How to apply.** Future Amp fizz work should stay inside the
  existing `amp*Frame` stages unless the user explicitly approves a
  topology change. Reuse `ampModelSel` only for small per-band
  constant trims, not for a wide model-select mux over independent
  filters, clippers, or multipliers.

## D21 — LowPassFir split is behavior-preserving only

- **Decision.** The May 8 LowPassFir split refactor separates the
  Clash source into smaller `AudioLab.*` modules without changing DSP
  behavior. `LowPassFir.hs` remains the Vivado-visible top module and
  keeps the `topEntity` type, port names, port order, and external
  I/O unchanged.
- **What changed.**
  - Type aliases, `Frame`, `AxisOut`, and common memory definitions
    moved to `AudioLab.Types`.
  - Fixed-point and clipping helpers moved to `AudioLab.FixedPoint`.
  - `ctrlA` / `ctrlB` / `ctrlC` / `ctrlD`, flag helpers, and
    distortion-pedal enable helpers moved to `AudioLab.Control`.
  - AXIS pack/unpack and input/output packet helpers moved to
    `AudioLab.Axis`.
  - Existing effect stage functions moved into
    `AudioLab.Effects.NoiseSuppressor`, `Compressor`, `Overdrive`,
    `Distortion`, `Amp`, `Cab`, `Eq`, and `Reverb`.
  - `fxPipeline` and the unchanged register-stage wiring moved to
    `AudioLab.Pipeline`.
- **Boundaries.**
  - **No** DSP algorithm change, coefficient change, clip-knee change,
    fixed-point arithmetic change, bit-width change, register-stage
    order change, enable / disable behavior change, or bypass behavior
    change.
  - **No** mono conversion, 96 kHz work, PCM1808 / PCM5102 support,
    external ADC/DAC support, I2S interface change, or internal 32-bit
    conversion.
  - **No** `block_design.tcl` change, no new AXI GPIO, no GPIO address
    or `ctrlA`-`ctrlD` semantic change, no Python API change, no
    Notebook UI change, and no Chain Preset change.
  - **No** Delay implementation from `feature/bram-delay-500ms`; no
    `axi_gpio_delay_line`. Legacy `axi_gpio_delay` remains present.
  - **No** C++ DSP prototype revival, commercial source import, or GPL
    code import.
- **Build result.** Clash type check, VHDL generation, IP repackage,
  and Vivado bit/hwh rebuild completed locally. Final routed timing:
  WNS = -8.022 ns, TNS = -13937.512 ns, WHS = +0.052 ns,
  THS = 0.000 ns. This matches the previous deployed Amp Simulator
  fizz-control baseline (WNS delta 0.000 ns). Utilization after place:
  Slice LUTs 21809 (40.99%), Slice Registers 18675 (17.55%),
  Block RAM Tile 7 (5.00%), DSPs 158 (71.82%).
- **PYNQ result.** Deployed to PYNQ-Z2 with
  `PYNQ_HOST=192.168.1.9 bash scripts/deploy_to_pynq.sh`. Smoke test
  confirmed `ADC HPF: True`, `R19 = 0x23`,
  `has delay_line gpio: False`, `has legacy axi_gpio_delay: True`,
  all four amp models, and the requested chain presets.
- **How to apply.** Future DSP work should keep dependencies flowing
  from `LowPassFir` -> `AudioLab.Pipeline` -> `AudioLab.Effects.*` ->
  `AudioLab.Types` / `FixedPoint` / `Control` / `Axis`. Shared
  helpers belong in the common modules, not in an effect module that
  another effect imports.

## D22 — DSP pipeline uses mono internal processing while preserving stereo AXI I/O

- **Decision.** The May 9 internal mono DSP pass keeps the external
  AXI/I2S interface stereo-compatible while treating guitar audio as a
  Left-derived mono signal inside the DSP pipeline.
- **What changed.**
  - AXI input and output remain 48-bit stereo. `packChan` /
    `unpackChan`, `topEntity`, port names, port order, and external
    I/O are unchanged.
  - `AudioLab.Axis.makeInput` uses ADC Left as the mono source and
    explicitly discards Right to avoid unconnected-channel noise.
  - The physical `Frame` record keeps its L/R-shaped fields for module
    compatibility, but the active path uses mono helpers/state in
    `AudioLab.Types`, `AudioLab.Pipeline`, and `AudioLab.Effects.*`.
  - `AudioLab.Axis.pipeData` duplicates the final mono sample to
    output Left and Right.
  - AXI Stream metadata is not derived from sample data. `Frame.fLast`
    carries input TLAST to output TLAST, and `AudioLab.Pipeline` paces
    accepted DMA input frames so the fixed-latency DSP pipeline keeps
    one output frame per accepted input frame when S2MM ready briefly
    deasserts.
- **Boundaries.**
  - **No** DSP coefficient retune, clip-knee retune, byte mapping
    change, enable semantics change, Python API change, Notebook UI
    change, Chain Preset change, GPIO change, or `block_design.tcl`
    change.
  - **No** 96 kHz work, PCM1808 / PCM5102 support, external ADC/DAC
    support, I2S addition, internal 32-bit conversion, new GPIO, Delay
    line implementation, or `axi_gpio_delay_line`.
- **Build / deploy result.** Local Python tests, Notebook JSON checks,
  Clash type check / VHDL generation, IP repackage, and Vivado bit/hwh
  rebuild passed. Final routed timing: WNS = -8.155 ns,
  TNS = -6492.876 ns, WHS = +0.052 ns, THS = 0.000 ns. Versus the
  minimal mono build / `37ef4c7` baseline (WNS = -8.022 ns), WNS delta
  is -0.133 ns. Utilization after place: Slice LUTs 15473 (29.08%),
  Slice Registers 14914 (14.02%), Block RAM Tile 7 (5.00%), DSPs 83
  (37.73%).
- **PYNQ result.** Deployed to PYNQ-Z2 at `192.168.1.9` with
  `bash scripts/deploy_to_pynq.sh`. Smoke test confirmed
  `ADC HPF: True`, `R19 = 0x23`, no `axi_gpio_delay_line`, legacy
  `axi_gpio_delay` present, and the requested chain presets.
- **DMA / L-R result.** After PYNQ reboot, one overlay load and one
  composite DMA packet covered Case A (Left nonzero / Right different),
  Case B (Left zero / Right large), and Case C (Right inverted noise).
  All cases completed without DMA timeout. Send and recv DMASR both
  ended at `0x00001002`; with `skip_frames = 16`, output L/R were
  identical (`max_abs_lr_diff_steady_state = 0`) and Right input
  rejection was confirmed (`max_abs_output_when_left_zero = 0`,
  `max_abs_output_change_when_right_input_changes = 0`).
- **How to apply.** Future audio-format changes should preserve the
  external interface until the user explicitly approves a top-level /
  block-design migration. For guitar input, continue to treat Left as
  the mono source and keep AXI metadata propagation independent of
  sample values.

## D23 — HDMI GUI uses integrated AudioLab overlay and top-left 800x480 LCD viewport

- **Decision.** The live HDMI GUI path uses the integrated AudioLab
  `audio_lab.bit`; it must not load PYNQ `base.bit` or any second full
  overlay. This entry records the Phase 5C viewport decision: the
  top-left `x=0,y=0,w=800,h=480` region of the then-720p framebuffer was
  the adopted LCD-visible area. **Superseded by D25 for signal timing**:
  the current bit emits VESA SVGA `800x600 @ 60 Hz / 40 MHz` and keeps
  the same 800x480 compact GUI at framebuffer `(0,0)`, with rows
  `480..599` black.
- **Why.** Phase 5A output mapping showed that the LCD does not behave
  like a clean full-frame 1280x720-to-800x480 scaler. User visual
  inspection confirmed the `800x480 x0 y0` candidate box is correctly
  positioned. Center placement `(240,120)` and further positive/negative
  offset sweeps are therefore not the normal runtime path.
- **Runtime contract.**
  - Load `AudioLabOverlay()` exactly once.
  - Use `audio_lab_pynq.hdmi_backend.AudioLabHdmiBackend`.
  - Use `GUI/pynq_multi_fx_gui.py::render_frame_800x480(...,
    variant="compact-v2")` for the default small-LCD frame.
  - Do not call `GUI/pynq_multi_fx_gui.py::run_pynq_hdmi()`.
  - Do not call `Overlay("base.bit")`.
  - Do not load another overlay after `AudioLabOverlay()`.
- **Current default command.**

  ```sh
  sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
    python3 scripts/test_hdmi_800x480_frame.py \
      --variant compact-v2 --placement manual \
      --offset-x 0 --offset-y 0 --hold-seconds 60
  ```

- **Boundaries.** Native 800x480 HDMI timing was later attempted in
  Phase 6H and rejected on the real LCD; do not restore it. The old
  untracked `HDMI/` experiment tree was removed after confirming deploy,
  tests, and runtime scripts use `GUI/` plus
  `audio_lab_pynq/hdmi_backend.py` instead.

## D24 — 800x480 compact-v2 is the only renderer; HDMI GUI runs from `HdmiGui.ipynb`

- **Decision.** `GUI/pynq_multi_fx_gui.py` is now an 800x480-only
  renderer. The 1280x720 reference renderer (`render_frame`,
  `render_frame_fast`, `render_frame_legacy`, `render_frame_pynq_static`,
  `_render_full`, the static / semistatic layer cache, all 1280x720
  chassis chrome helpers, `panel_with_bevel`, `inset_screen`, `screw`,
  `add_brushed_metal`, `draw_led`) and the Windows preview app
  (`TkApp`, `run_windows_window`, `run_windows_fullscreen`,
  `get_monitor_rects`, the demo PNG / CLI loop / hit-test / `run_bench`
  / `run_pynq_hdmi` / `_build_argparser` blocks) are removed. Public
  API is `AppState`, `render_frame_800x480`,
  `render_frame_800x480_compact_v2`, `make_pynq_static_render_cache`,
  `compact_v2_panel_boxes`, `save_state_json`, `load_state_json`. The
  compact-v2 layout drops the bottom-right `side` panel
  (MONITOR + IN/OUT meters); `fx` spans the full bottom row
  `(24, 260, 776, 454)`. The selected-FX knob grid adapts per effect
  (3 → 3×1, 4 → 2×2, 6 → 3×2) by filtering `EFFECT_KNOBS` against
  the empty `("", 0)` slots, so adding a new effect only requires
  extending `EFFECT_KNOBS`. `audio_lab_pynq/notebooks/HdmiGui.ipynb`
  is the canonical runtime entry: one cell, live CPU / RAM / FPS /
  VDMA-error monitor, with `OFFSET_X` / `OFFSET_Y` calibration knobs
  for LCDs whose visible viewport drifts off `(0,0)`.
- **Why.** The 1280x720 renderer and Tk preview were a legacy
  Windows-side reference design that has not been the live runtime
  since Phase 4E (800x480 logical mode) and Phase 5C (top-left LCD
  viewport). They paid context cost on every read of the file without
  contributing to the actual HDMI output. The compact-v2 side monitor
  was a placeholder for input / output meters that never reflected
  real codec levels; the saved space gives the selected-FX knobs (3-6
  per effect, depending on `EFFECT_KNOBS`) enough room to render real
  labels and values.
- **Boundaries.**
  - Reintroducing a 1280x720 layout requires a new design pass; do
    not resurrect the removed helpers piecemeal.
  - The bottom-right `side` panel is gone for compact-v2; any new
    side panel must come with a real signal source (real codec
    meters or scope data), not a placeholder animation.
  - Adding an effect: extend `EFFECT_KNOBS` with the real knob labels
    and defaults; the grid (3 / 2 columns, 1 / 2 rows) follows
    automatically from the live knob count. Do not hard-code a fixed
    knob count in the renderer.
- **`install_notebooks()` implementation.**
  `audio_lab_pynq/__init__.py::install_notebooks()` uses
  `shutil.copytree` (after `shutil.rmtree`) for the notebooks tree and
  an explicit `shutil.copyfile` loop for the bitstreams subdir.
  `distutils.dir_util.copy_tree` was dropped because its module-level
  `_path_created` cache occasionally left a zero-byte
  `/home/xilinx/jupyter_notebooks/audio_lab/HdmiGui.ipynb` on retry,
  which Jupyter refused to open.
- **Phase 6H (1).py spec port (`d7ea0ab`, 2026-05-16).** Compact-v2
  renderer was ported to the user-supplied `(1).py` spec. `EFFECT_KNOBS`
  is now a single dict keyed by the title-case `EFFECTS` names with
  short labels (`THRESH`, `RATIO`, `RESP`, `MAKEUP`, `MID`, `TREB`,
  `PRES`, `RES`, `MSTR`, `CHAR`, ...). `AppState` stores knob values
  in a single per-effect dict `all_knob_values: Dict[str, List[float]]`;
  the flat `knob_values` field is removed. New helpers:
  `state.knobs()`, `state.set_knob(label, value)`,
  `hit_test_compact_v2(x, y, state)`. The PEDAL / AMP / CAB model
  dropdown chip is drawn inline by the renderer and only for those
  three categories; legacy helpers (`SELECTED_FX_PARAM_LAYOUT`,
  `_should_show_selected_model_dropdown`,
  `_selected_model_dropdown_label`, `_dropdown_short`,
  `_pedal/amp/cab_label`, `selected_fx_param_layout`) are removed.
  Long model labels are sized down via `draw_smooth_text` with a
  fit-to-chip search (`22 -> 14`). Compact-v2 coordinates remain the
  Phase 4G / 4I baseline: `COMPACT_V2_LAYOUT.outer=(12,12,788,468)`,
  `left=right=24`. The HDMI runtime contract (1280x720 signal,
  800x480 logical frame at framebuffer `x=0,y=0`, manual placement,
  one `AudioLabOverlay()`, no `base.bit`) was unchanged at the time
  of this port. **Superseded by D25** for the HDMI timing only: the
  signal is now VESA SVGA `800x600 @ 60 Hz / 40 MHz` with the same
  800x480 compact-v2 GUI composed at framebuffer `(0,0)` of a
  `800x600` framebuffer. The "single overlay, no `base.bit`,
  one-`AudioLabOverlay()`" runtime contract from this entry is still
  in force; only the on-the-wire signal width / framebuffer
  dimensions changed. Renderer / `AppState` / `EFFECT_KNOBS` /
  `hit_test_compact_v2()` and the canonical entry
  `audio_lab_pynq/notebooks/HdmiGui.ipynb` are still as described
  here; D25 adds the `HdmiGuiShow.ipynb` one-shot variant. No
  Clash / GPIO / block-design change. See
  `docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE6H_PORT_1PY_SPEC.md` and D25.

## D25 — Integrated HDMI runs VESA SVGA 800x600 @ 40 MHz, not native 800x480

- **Rule.** The integrated HDMI output in `hw/Pynq-Z2/hdmi_integration.tcl`
  drives the LCD at **VESA SVGA 800x600 @ 60 Hz, pixel clock 40.000 MHz**,
  H total `1056` (`fp 40, sync 128, bp 88`), V total `628`
  (`fp 1, sync 4, bp 23`), `rgb2dvi_hdmi.kClkRange=3`. The framebuffer
  in `audio_lab_pynq/hdmi_backend.py` is `800x600` (`DEFAULT_WIDTH=800`,
  `DEFAULT_HEIGHT=600`); the compact-v2 GUI composes at framebuffer
  `(0,0)` so visible rows `0..479` carry the UI and rows `480..599`
  stay black. Do not switch back to a 720p signal carrying an 800x480
  viewport, and do not retry a "native 800x480" timing at 40 MHz
  (Phase 6H attempt; the 5-inch LCD did not lock and showed a fully
  white screen). See
  `docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE6I_800X480_TIMING_SWEEP.md` and
  `docs/ai_context/history/hdmi_phases/HDMI_GUI_PHASE6H_NATIVE_800X480_TIMING.md`.
- **Why.** The 5-inch LCD's HDMI receiver scaler rejects the Phase 6H
  `800x480 / 40 MHz / 1056 x 628` timing (active area sized differently
  from the standard SVGA mode that shares those H/V totals). VESA SVGA
  `800x600 @ 60 Hz` is a standard DMT mode the LCD's scaler does
  recognise; the panel's panel-native 800 pixel width then maps the
  signal directly without the right-shift seen on the previous
  `1280x720` path. Lower-clock candidates (33.333 / 33.000 / 27.000
  MHz) are not synthesisable with the unmodified Digilent
  `rgb2dvi v1.4` IP because they push the internal PLLE2 VCO below
  the `800..1600 MHz` valid band; SVGA at 40 MHz keeps the VCO at
  `800 MHz` (band edge) and synthesises cleanly. Phase 6I C2 build
  shows WNS `-8.096 ns` / TNS `-6389.430 ns` / WHS `+0.040 ns` /
  THS `0.000 ns` — within the historical `-7..-9 ns` deploy band and
  hold remains clean.
- **Boundaries.**
  - Do **not** flip `DEFAULT_HEIGHT` back to `480` without also
    changing the v_tc IP, the framebuffer size, and `VDMA VSIZE`.
  - Do **not** add an `offset_x` / `offset_y` correction in the
    backend to "compensate" the 600-line frame; the bottom-120-line
    black margin is intentional and the LCD's scaler maps the 800x600
    signal correctly.
  - When editing `hw/Pynq-Z2/hdmi_integration.tcl` for any future
    timing change, set `CONFIG.VIDEO_MODE {Custom}` and
    `CONFIG.GEN_VIDEO_FORMAT {RGB}` in a first `set_property` pass
    before the per-field `CONFIG.GEN_*` values. Otherwise the
    individual `GEN_HACTIVE_SIZE` / `GEN_VACTIVE_SIZE` /
    `GEN_HSYNC_*` parameters are disabled and silently ignored, and
    the bit ships with whatever preset the IP defaulted to (`1280x720p`
    out of the box).
  - Set `CONFIG.GEN_F0_VBLANK_HSTART` and `CONFIG.GEN_F0_VBLANK_HEND`
    explicitly to `HDMI_ACTIVE_W` for every new timing — the preset
    leaves them at `1280`, which exceeds `GEN_HFRAME_SIZE` for any
    non-720p mode and emits a "should not exceed" warning.
  - Drop `CONFIG.GEN_CHROMA_PARITY` (does not exist on `v_tc:6.1`).
  - On deploy / rollback, sync **all five** bit/hwh copies on the
    PYNQ-Z2:
    - `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}` (staging copy that
      `deploy_to_pynq.sh` reads from)
    - `/home/xilinx/Audio-Lab-PYNQ/audio_lab_pynq/bitstreams/audio_lab.{bit,hwh}`
      (loaded when scripts run with
      `PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ`)
    - `/usr/local/lib/python3.6/dist-packages/audio_lab_pynq/bitstreams/audio_lab.{bit,hwh}`
      (loaded when scripts run without `PYTHONPATH`)
    - `/home/xilinx/jupyter_notebooks/audio_lab/bitstreams/audio_lab.{bit,hwh}`
      (the `install_notebooks()` destination; some scripts reference
      the jupyter-side copy directly)
    - `/usr/local/lib/python3.6/dist-packages/pynq/overlays/audio_lab/audio_lab.{bit,hwh}`
      (`pynq`'s overlay registry; resolves bare
      `Overlay("audio_lab")`)
    `AudioLabOverlay` loads whichever sits next to the
    `audio_lab_pynq` package that the current `PYTHONPATH` resolves
    first; missing any copy can keep the FPGA on the previous bit
    silently. After deploy, verify each location's `md5sum` matches
    and read `v_tc_hdmi GEN_ACTSZ (0x60)` from MMIO — it must read
    `0x02580320` (V=600 / H=800) for SVGA 800x600.
  - **rgb2dvi PLL is at the band edge.** `40 MHz × M=20 = 800 MHz`
    sits at the absolute lower limit of `rgb2dvi v1.4 kClkRange=3`'s
    valid `800..1600 MHz` VCO range. The PLL locks cleanly on a fresh
    PYNQ-Z2 power-on, but a second `Overlay(..., download=True)` in
    the same session can knock it out and drop the LCD to white even
    with VDMA and VTC still reporting healthy state. User-facing
    tooling that may be re-run in the same Jupyter session must
    detect "bit already loaded" (read `GEN_ACTSZ`, expect
    `0x02580320`) and attach with `AudioLabOverlay(download=False)`
    so the running rgb2dvi MMCM is left alone.
    `audio_lab_pynq/notebooks/HdmiGuiShow.ipynb` implements this
    workaround; `HdmiGui.ipynb`'s live loop also benefits from the
    same pattern. Recovery from a stuck-PLL white screen is a
    PYNQ-Z2 power cycle, then run the cell exactly once.
  - `block_design.tcl` is unchanged; D2 still applies.

## D26 — Post-Phase-6I refactor: facade + per-effect subpackages

- **Decision.** Three companion refactor passes landed on `main` after
  Phase 6I to make per-effect work and AI-context loading cheaper.
  None of them change the runtime DSP / FPGA / GPIO / block-design
  contract; all preserve external Python import paths byte-for-byte.

  - **`set_guitar_effects` thin facade** (`d1c4e8e`,
    `audio_lab_pynq/AudioLabOverlay.py`).
    The 100-line `set_guitar_effects(self, sink=..., **kwargs)`
    method was split into a 17-line dispatch over six private
    helpers (`_require_effect_gpios`,
    `_merge_cached_distortion_state`,
    `_merge_cached_noise_suppressor_state`,
    `_write_effect_gpios`, `_refresh_cached_words`,
    `_route_effect_chain`) plus two new class-level constants
    (`_REQUIRED_EFFECT_GPIOS`, `_OPTIONAL_EFFECT_GPIOS`,
    `_DIST_STATE_SCALAR_PAIRS`). The public signature, return value,
    GPIO write order, cached-state semantics, and "missing GPIO"
    `RuntimeError` text are unchanged.

  - **`hdmi_state` subpackage** (`52c5ea4`).
    The 1727-line `audio_lab_pynq/hdmi_effect_state_mirror.py` was
    split: the constant tables (pedal / amp / cab model names +
    labels + aliases), the SELECTED FX dropdown plumbing, the
    `GUI_EFFECT_KNOBS` layout, the `/proc`-based `ResourceSampler`,
    and the cross-effect helpers moved into
    `audio_lab_pynq/hdmi_state/{pedals, amps, cabs, selected_fx,
    knobs, resource_sampler, common}.py`. The mirror file
    (`audio_lab_pynq/hdmi_effect_state_mirror.py`) is now a
    1117-line shim that holds the `HdmiEffectStateMirror` class
    itself and re-exports every public + private name from the
    subpackage. Every existing import like
    `from audio_lab_pynq.hdmi_effect_state_mirror import
    HdmiEffectStateMirror, PEDAL_MODEL_LABELS, ResourceSampler,
    STATIC_PL_UTILIZATION, ...` keeps working.

  - **`GUI/compact_v2/` subpackage** (`5173baf`).
    The 1685-line `GUI/pynq_multi_fx_gui.py` was split per the
    user-requested {layout, renderer, knobs, state, hit_test}
    themes into `GUI/compact_v2/{knobs, state, layout, renderer,
    hit_test}.py` (+ `__init__.py`). `GUI/pynq_multi_fx_gui.py` is
    now a 120-line re-export shim with a `try/except` block so both
    `from pynq_multi_fx_gui import X` (`REPO_ROOT/GUI` on sys.path
    — notebooks / scripts) and `from GUI.pynq_multi_fx_gui import
    X` (`REPO_ROOT` on sys.path — tests / packagers) resolve all
    exports. Render output verified byte-for-byte identical against
    the pre-split file for three themes + two render variants +
    `hit_test_compact_v2(400, 240)`.

- **Why.** Each pre-refactor file was a merge-conflict magnet
  whenever per-effect or per-theme work landed in parallel. The
  splits localise each section so an AI agent reading just the
  pedal name mapping pulls in `audio_lab_pynq/hdmi_state/pedals.py`
  (~60 lines) instead of `hdmi_effect_state_mirror.py` (~1700
  lines), and a contributor editing the compact-v2 palette can
  touch `GUI/compact_v2/layout.py` (~270 lines) instead of the
  whole `pynq_multi_fx_gui.py`.

- **Boundaries.**
  - Do not undo the splits by re-flattening the subpackages back
    into the shim files. The shim files exist so external import
    paths stay stable; they should not gain new top-level
    definitions.
  - Inside `GUI/compact_v2/` and `audio_lab_pynq/hdmi_state/`, use
    **relative imports** (`from .knobs import X`) so the modules
    work under both call-site conventions (top-level package vs
    nested-under-GUI / nested-under-audio_lab_pynq).
  - When adding a new effect that needs a model dropdown,
    extend `audio_lab_pynq/hdmi_state/{pedals,amps,cabs}.py`
    (or add a sibling) instead of touching the mirror file. When
    adding a new compact-v2 panel, extend `GUI/compact_v2/layout.py`
    (panel boxes), `GUI/compact_v2/renderer.py` (`_draw_800x480_*`),
    and `GUI/compact_v2/hit_test.py` (input mapping) — keep each
    in its own file.
  - The `tests/_pynq_mock.py` shim is the canonical way to import
    `audio_lab_pynq.hdmi_effect_state_mirror` via
    `spec_from_file_location` on a workstation without `pynq`
    installed. New offline tests that load the file directly should
    `import _pynq_mock` first.
  - No DSP / Clash / GPIO / block_design / bit / hwh / tcl change in
    any of the three refactors; the same `audio_lab.bit` is in use.

## D27 — Phase 7 では PCM1808 + PCM5102 を外付け codec 候補として計画する (ADAU1761 即置換禁止)

- **状況.** PYNQ-Z2 onboard ADAU1761 は音は出るが、外付け codec
  module を扱える前提を整えたい (line-level 入出力、I2S 接続、
  将来の analog front-end 追加の余地)。
- **決定.** 外付け codec として **Youmile PCM1808** (ADC) と
  **PCM5102 / PCM5102A** (DAC) を採用する前提で Phase 7 を進める。
  Phase 7A は **planning only**: ピン予約 / 信号一覧 / mode / clock
  方針 / analog 注意 / 段階的実装計画を docs に記録するだけで、
  XDC / block_design / bit / hwh は一切変更しない。
- **境界.**
  - 既存 ADAU1761 経路は **破壊しない**。Phase 7B 以降も外付け codec
    は **別 I2S path** として追加する (`EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md`
    section 7 の選択肢 A または C)。即置換 (選択肢 B) は採用しない。
  - PCM1808 の analog input にギターを **直結しない**。line-level
    想定で先に動かし、analog front-end (高 impedance buffer / AC
    coupling / bias / gain / anti-alias LPF / clamp) は Phase 7E
    以降に分離する。
  - PCM5102 の出力は **line out** として扱う。headphone 直接駆動を
    前提にせず、必要なら output buffer を追加する。pop noise / GND
    routing は実装時に確認する。
  - 実モジュールは販売ロットによりピン名 / strap / 電源が異なる
    可能性があるので、**Phase 7B で実物確認** してから XDC を書く。
- **Why.** ADAU1761 を残しておけば、外付け path の動作 / 音質 /
  ノイズフロアを直接比較でき、Phase 7B 以降の作業中に音が出なく
  なるリスクを排除できる。analog front-end と DSP 置換を同時に
  攻めると失敗時の原因切り分けが困難になる。

## D28 — 外付け ADC / DAC pin を encoder GPIO より優先して予約する

- **状況.** Phase 7 は外付け codec と rotary encoder × 3 を同時に
  追加したい。PYNQ-Z2 上の未使用 IO ヘッダは PMOD JA / JB、
  Raspberry Pi header、Arduino header。どれを何に割り当てるかで
  audio が劣化したり再配線が必要になったりする可能性がある。
- **決定.** **外付け audio (PCM1808 + PCM5102) を最優先**で
  PMOD JB に連続配置する。追加 control / strap pin が必要なら
  PMOD JA に分散する。**rotary encoder 用 GPIO は audio 予約 pin の
  余りではなく** Raspberry Pi header に配置する。
- **境界.**
  - PMOD JB は外付け I2S audio (`EXT_AUDIO_MCLK` / `EXT_AUDIO_BCLK` /
    `EXT_AUDIO_LRCLK` / `EXT_ADC_DOUT` / `EXT_DAC_DIN`) 用に
    確保する。最低 5 pin (mode pin を strap 固定する場合) で
    収まる。
  - PMOD JA は `EXT_ADC_FMT` / `EXT_ADC_MD0` / `EXT_ADC_MD1` /
    `EXT_DAC_XSMT` / `EXT_CODEC_RESET_N` / `EXT_AUDIO_SPARE0..3`
    用に確保する。
  - encoder 9 pin + spare GPIO は Raspberry Pi header 候補 (低速で
    十分)。Arduino header は最後の予備。
  - 実 Package Pin は Phase 7B で確定する。Phase 7A の本決定は
    **論理予約レベル**。XDC 変更はしない。
  - すべて 3.3V LVCMOS33 統一。5V を PL pin へ直接入れない
    (level shifter 必須)。
- **Why.** audio は clock skew / cross-talk に弱いため隣接 pin に
  集約したい。encoder は kHz オーダーの低速入力なので、PMOD の
  clean 8-pin block を潰してまで配置する必要がない。先に audio を
  確保して余りを encoder に回すと、後で audio を増やしたいときに
  encoder 配線をやり直す羽目になる。

## D29 — FPGA を外付け I2S clock master にする (48 kHz / 24-bit / 12.288 MHz MCLK 第一候補)

- **状況.** PCM1808 / PCM5102 のクロックを誰が出すか決める必要が
  ある。ADAU1761 経路は既に `mclk` (`U5`) を FPGA から供給して
  おり、`bclk` / `lrclk` も FPGA 主導。
- **決定.** Phase 7 でも **FPGA / PYNQ-Z2 を I2S clock master** に
  する。
  - sample rate: 48 kHz
  - word length: 24-bit (frame は stereo / 64-bit)
  - `BCLK` = 64 × fs = **3.072 MHz**
  - `MCLK / SCKI` 第一候補 = 256 × fs = **12.288 MHz**
    (384 / 512 fs は将来の高 SNR option として残す)
  - PCM1808 は **slave mode** 固定 (`MD0` / `MD1` を strap)
  - PCM1808 `FMT` = I2S 24-bit (strap 推奨)
  - PCM5102 は I2S 3-wire 入力 (`BCK` / `LCK` / `DIN`)、`SCK` の
    扱いは module 仕様で決定 (内蔵 PLL 駆動 or 12.288 MHz 駆動)
- **境界.**
  - 既存 DSP は 48 kHz / `AudioDomain` 前提なので、外付け path も
    48 kHz で揃える。sample rate 変更は Phase 7 範囲外。
  - `BCLK` / `LRCLK` / `MCLK` は generated clock として XDC 宣言
    する (Phase 7B 以降)。
  - PCM1808 `DOUT` には input delay 制約が必要 (Phase 7B 以降)。
- **Why.** clock master を FPGA にすることで、ADAU1761 path と
  外付け path で同じ sample timing を持てる。比較が公平になり、
  Python / GUI 側から sample rate を変えない契約が維持できる。
  PCM5102 が PLL 内蔵で MCLK なしでも動く構成があるとはいえ、
  PCM1808 は SCKI 必須なので、結局 MCLK は FPGA が出すのが
  最もシンプル。

## D30 — Rotary encoder は PL 側で debounce + quadrature decode + event 化 (Python polling 禁止)

- **状況.** PYNQ-Z2 + Jupyter 環境で rotary encoder を 3 個扱う
  と、Python polling 経路は CPU 負荷 / polling 周期 / debounce の
  すべてで弱い。HDMI GUI を encoder で操作する以上、入力検出の
  信頼性は必須。
- **決定.** rotary encoder 入力 (`ENC0..2_A / B / SW`、9 pin) は
  **PL fabric 側で**:
  - 2-stage synchronizer
  - debounce counter (CONFIG レジスタの `debounce_ms` で設定可能)
  - quadrature state machine
  - signed delta accumulator (per encoder)
  - absolute count register (per encoder)
  - event latch (rotate / short_press / long_press / release)

  を実装し、PS 側 Python は **delta + event レジスタを polling
  するだけ** にする。
- **境界.**
  - 既存 `axi_gpio_*` (`0x43C30000` ~ `0x43CD0000`) には混ぜない。
    encoder 用は **新規 AXI IP** (または新規 AXI GPIO input)。
    base address は **TBD** (Phase 7F で確定)。`0x43CE0000`
    (`axi_vdma_hdmi`) と `0x43CF0000` (`v_tc_hdmi`) は **禁止**
    (`DECISIONS.md` D32、Phase 7B 訂正)。
  - 既存 `ctrlA` / `ctrlB` / `ctrlC` / `ctrlD` 4-byte unpacking 構造は
    encoder には流用しない (event bit と signed delta が混在する
    ため別 layout)。
  - `block_design.tcl` 変更は Phase 7F でユーザ承認の上で行う。
    `axi_gpio_noise_suppressor` (`DECISIONS.md` D11) /
    `axi_gpio_compressor` (`DECISIONS.md` D14) と同じ "個別承認の
    例外" 扱い。
  - Python 側 API は `audio_lab_pynq/encoder_input.py` (低位) と
    `audio_lab_pynq/encoder_ui.py` (高位 / AppState 反映) の 2 段。
    encoder 経由の値変更は `apply_to_overlay` で debounce + apply
    タイミング制御し、回転ごとに GPIO write しない。
  - notebook 操作と encoder 操作の競合は **後勝ち**、ただし
    `apply_pending` 中は notebook を上書きしない (`value_dirty`
    で示す)。
- **Why.** encoder の典型回転速度は数百 pulse/s 以上で、PS polling
  は数十 Hz 程度しか出ない。生信号を PS で読むと **必ず取りこぼす**。
  debounce を PS でやるとボタン応答が遅れる。PL fabric なら
  encoder 3 個でも数百 LUT 程度で済み、現状の Vivado リソース枠
  内に余裕で収まる。GUI 更新周期 (30 ~ 60 Hz) と入力検出周期
  (PL clock、~ MHz) を完全分離できるのも大きい。

## D31 — Rotary encoder module pins are documented as CLK / DT / SW / + / GND (not generic A / B / SW)

- **状況.** Phase 7A では encoder の信号を `ENC*_A` / `ENC*_B` /
  `ENC*_SW` と書いていたが、実モジュール (Amazon / 共立等の 5 pin
  rotary encoder + tactile switch ボード) のシルクは
  **`CLK` / `DT` / `SW` / `+` / `GND`** だった。配線指示と XDC 候補で
  異なる呼び方を併用すると現場で配線ミスが起きる。
- **決定.**
  - **外部配線指示 / XDC 候補 / 物理表は `CLK` / `DT` / `SW` /
    `+` / `GND` 表記** を使う。
  - 論理信号名は **`ENC*_CLK` / `ENC*_DT` / `ENC*_SW`** に統一
    (`*` は `0` / `1` / `2`)。
  - 電源 / GND は **`ENC_3V3` / `ENC_GND`** という名前で記録し、
    GPIO としてはカウントしない。
  - **`+` は 3.3V 専用**。5V に繋がない。理由: 多くの encoder
    module は基板上 pull-up を `+` ピンに繋いでおり、`+` を 5V に
    すると `CLK` / `DT` / `SW` も 5V 化して PYNQ-Z2 PL pin (3.3V
    LVCMOS33) を直撃する。最悪の場合 PL pin が壊れる。
  - PL 内部 (Clash / HDL / register) では quadrature の慣例上
    `A` (= CLK) / `B` (= DT) と呼んでもよい。Python / API 公開名は
    semantic (`rotate` / `short_press` / `long_press`) を優先する。
  - 回転方向 / 極性が期待と逆になった場合は **CONFIG レジスタの
    `invert_clk` / `invert_dt` / `clk_dt_swap` / `reverse_direction` /
    `sw_active_low` で補正** する。物理 rewiring は最後の手段。
- **境界.**
  - module 側に pull-up があるかは Phase 7B の物理確認項目
    (`IO_PIN_RESERVATION.md` section 4.4、
    `ENCODER_GUI_CONTROL_SPEC.md` section 7)。
  - 3.3V で pull-up が弱い場合は外付け 10 kΩ → 3.3V または PL 側
    `set_property PULLUP true`。
- **Why.** シルクと docs が一致していないと、配線時に CLK / DT を
  入れ替えたまま気付かない / `+` を 5V に繋いで PL pin が壊れる
  / quadrature の方向が逆で GUI が変な動きをする、といった事故の
  原因になる。シルクを source of truth にして、論理 / register /
  driver に揃える。

## D32 — Encoder PL IP の AXI base address は TBD、`0x43CE0000` / `0x43CF0000` は禁止

- **状況.** Phase 7A の `DECISIONS.md` D30 と
  `ENCODER_GUI_CONTROL_SPEC.md` で encoder IP の base address を
  `0x43CE0000` と仮置きしていた。Phase 7B で `CURRENT_STATE.md` /
  `HDMI_GUI_INTEGRATION_PLAN.md` / `HDMI_BLOCK_DESIGN_TCL_PATCH_PLAN.md`
  を確認したところ、`0x43CE0000` は **既存 `axi_vdma_hdmi`** (HDMI
  フレームバッファ VDMA、`DECISIONS.md` D23)、`0x43CF0000` は
  **既存 `v_tc_hdmi`** (HDMI Video Timing Controller) の address で
  あり、encoder IP を置くと HDMI が動かなくなる。
- **決定.**
  - encoder IP base address は **TBD**。Phase 7F で確定する。
  - **`0x43CE0000` 禁止** (`axi_vdma_hdmi` 占有)。
  - **`0x43CF0000` 禁止** (`v_tc_hdmi` 占有)。
  - 既存 `axi_gpio_*` (`0x43C30000` ~ `0x43CD0000`) とも衝突禁止。
  - `0x43D00000` 以降 (HDMI integration plan で rgb2dvi 用 control
    候補とされた range) も避け、念のため `0x43D10000` 以降または
    `0x43C00000` 以下の空き range を Phase 7F で
    `pynq.PL.ip_dict` + Vivado address editor + HWH で確認の上で
    選ぶ。
- **境界.**
  - block_design.tcl 変更は Phase 7F でユーザ承認の上で行う。
    `axi_gpio_noise_suppressor` (`DECISIONS.md` D11) /
    `axi_gpio_compressor` (`DECISIONS.md` D14) と同じ "個別承認の
    例外" 扱い。
  - Phase 7A の docs / D30 にあった `0x43CE0000` 記述は Phase 7B で
    TBD へ訂正済み (本決定の理由)。
- **Why.** HDMI 経路は `audio_lab.bit` の中心機能であり、address を
  踏むと VDMA / VTC が動かなくなり LCD が真っ黒になる。block_design
  / HWH を読んで address map を確認してから encoder IP を置く。

## D33 — Encoder input は独立 AXI-Lite IP (`axi_encoder_input`)、既存 `axi_gpio_*` には混ぜない

- **状況.** Phase 7F でロータリーエンコーダー 3 個 (CLK / DT / SW × 3 = 9 input)
  を PL から扱う実装フェーズに入った。既存 effect 制御は `axi_gpio_*`
  (output-only、`ctrlA..D` 4-byte unpacking) で実装されていて、その
  ledger は `GPIO_CONTROL_MAP.md` に固定されている。
- **決定.** encoder は **新規 Verilog IP `axi_encoder_input`** を 1 個
  追加し、ps7_0_axi_periph の M17 (HDMI VDMA M15 / HDMI VTC M16 の隣)
  に AXI-Lite slave で接続する。register layout は
  `ENCODER_INPUT_MAP.md`、base address は `0x43D10000`。
  既存 `axi_gpio_*` の byte / bit にも、`GPIO_CONTROL_MAP.md` の
  `ctrlA..D` 構造にも混ぜない。block design integration は
  `hw/Pynq-Z2/encoder_integration.tcl` (HDMI と同じ pattern) として
  切り出し、`create_project.tcl` から `hdmi_integration.tcl` の後に
  source する。
- **境界.**
  - PL 内部は 2-stage synchroniser + debounce (1 ms tick × N) +
    quadrature decoder + signed delta accumulator + event latch
    (rotate / short_press / long_press)。raw CLK/DT/SW を PS まで
    流さない (PS polling を不要にする)。
  - Verilog 単一ファイル module reference として bd に instantiate
    する (`create_bd_cell -type module -reference axi_encoder_input
    enc_in_0`)。IP catalog 用 component.xml / package_ip は不要。
  - 既存 effect GPIO の output-only / cache / `ctrlA..D` 契約は
    一切変更しない。
  - block_design.tcl 自体は `NUM_MI` の bump 以外は手を入れない
    (`hdmi_integration.tcl` と同じく、本体は分離 tcl で完結させる)。
    ただし NUM_MI bump は `encoder_integration.tcl` 側で
    `set_property NUM_MI {18}` 一行のみ実行する。
- **Why.** AXI GPIO に CLK/DT/SW を raw で配線したら結局 PS polling
  に戻ってしまい、`DECISIONS.md` D30 で否定した方式に逆戻りする。
  独立 IP にすれば PS は decoded delta + event だけ読めばよい
  (debounce / quadrature / 押下計時はすべて PL fabric 内で完結)。
  既存 `axi_gpio_*` の `ctrlA..D` レイアウトに event/delta を混ぜると
  `GPIO_CONTROL_MAP.md` の output-only 契約が壊れ、ledger が崩れる
  恐れがある。

## D34 — PMOD JB / PMOD JA は外付け codec 予約のまま温存、encoder は RPi header (JA 非共有 pin) を使う

- **状況.** Phase 7F の encoder 実装と Phase 7B 以降の外付け codec
  (PCM1808 + PCM5102) 計画は同時並行で進める必要があり、pin の取り合いに
  なりがち。`DECISIONS.md` D28 で「外付け audio を優先して PMOD JB に
  集約、PMOD JA を audio control / strap 用に残す、encoder は RPi
  header」と決めている。
- **決定.** Phase 7F の encoder 実装でも **PMOD JB と PMOD JA は一切
  使わない**。encoder pin は Raspberry Pi header のうち **PMOD JA と
  物理共有しない `raspberry_pi_tri_i_6..14`** を使う:
  - `ENC0_CLK = F19`, `ENC0_DT = V10`, `ENC0_SW = V8`
  - `ENC1_CLK = W10`, `ENC1_DT = B20`, `ENC1_SW = W8`
  - `ENC2_CLK = V6`, `ENC2_DT = Y6`, `ENC2_SW = B19`
  電源は `ENC_3V3` = PYNQ-Z2 3.3V rail (5V 厳禁、`DECISIONS.md` D31)、
  `ENC_GND` = 共通 GND。
- **境界.**
  - PMOD JB / PMOD JA は Phase 7C 以降の外付け codec 実装まで未配線で
    残す。encoder 用に audio 予約 pin を消費しない。
  - JA1..JA10 は RPi GPIO 0..5 + `respberry_sd_i` / `respberry_sc_i` と
    物理共有している (`IO_PIN_RESERVATION.md` 4.6) ので、encoder には
    その共有領域も使わない。
  - 将来フットスイッチ / LED を増やしたい場合は
    `raspberry_pi_tri_i_15..24` か Arduino header を使う
    (`IO_PIN_RESERVATION.md` 4A.3 / 4A.5)。
- **Why.** 外付け codec は同期 clock を `BCLK` / `LRCLK` / `MCLK` で
  扱うので skew 最小化のために PMOD JB の連続 8 pin を確保しておきたい。
  audio control / strap pin (PCM1808 `FMT` / `MD0` / `MD1` / PCM5102
  `XSMT`) は PMOD JA に確保する余地が必要。encoder は kHz オーダーの
  低速 input なので RPi header 側で十分。先に encoder で audio 用 pin
  を潰すと Phase 7C 以降に rewiring を強いられる。

## D35 — Rotary encoder standalone operation is not claimed until physical smoke passes

- **状況.** Phase 7F/7G で PL IP、Python driver、HDMI GUI controller、
  standalone runner、offline tests は追加できるが、ロータリーエンコーダー
  3 個はまだ Raspberry Pi header に物理配線されていない。未配線のまま
  `scripts/test_encoder_input.py` を走らせても、VERSION / CONFIG /
  idle read までは確認できる一方、実際の CLK / DT / SW edge、押下、
  方向、チャタリング、pull-up 強度は検証できない。
- **決定.** 「encoder 操作で HDMI GUI が standalone 動作した」と
  記録してよいのは、物理配線後に以下が PASS してから:
  - `scripts/test_encoder_input.py` で 3 encoder の rotate /
    short_press / long_press / release が出ること。
  - 必要なら CONFIG の `reverse_direction` / `clk_dt_swap` /
    `sw_active_low` / `debounce_ms` で方向と極性を補正し、その設定を
    docs に記録すること。
  - `scripts/run_encoder_hdmi_gui.py` または
    `scripts/test_hdmi_encoder_gui_control.py --use-real-encoder` で
    live HDMI GUI 操作が確認できること。
- **境界.**
  - 未配線状態で実施できるのは bit/hwh build、HWH/ip_dict に encoder
    IP が存在すること、register idle read、synthetic event GUI smoke
    まで。これらを physical encoder smoke の代替として扱わない。
  - `+` は必ず 3.3V、GND は PYNQ と共通、PMOD JB / JA は使わない
    (`DECISIONS.md` D31 / D34)。
- **Why.** quadrature 方向、detent あたり edge 数、pull-up の有無、
  contact bounce は実モジュール依存であり、offline test や synthetic
  HDMI event では確認できない。未配線の成功扱いは field wiring 時の
  誤診につながる。

## D36 — Deployed encoder module-reference IP is addressed through `enc_in_0/s_axi`

- **状況.** `c7a8680` の bit/hwh を PYNQ-Z2 (`192.168.1.9`) に deploy
  したところ、Vivado BD instance は `enc_in_0` のままだが、PYNQ
  2020.1 の `ip_dict` では module-reference AXI interface が
  **`enc_in_0/s_axi`** として露出した。bare `ovl.enc_in_0` attribute は
  MMIO `DefaultIP` ではなく hierarchy object なので、そのまま
  `EncoderInput` に渡すと register read/write できない。
- **決定.**
  - Python driver は `enc_in_0/s_axi` を正式な discovery candidate に
    含める。
  - `EncoderInput.from_overlay()` は overlay attribute を採用する前に
    `.mmio` または `read` / `write` を持つことを確認する。
  - 候補名で見つからない場合は `ip_dict` 内の `encoder` または
    `enc_in` を含む key を探索する。
  - docs / Notebook / smoke 結果では、BD instance `enc_in_0` と
    PYNQ runtime key `enc_in_0/s_axi` を区別して書く。
- **境界.**
  - RTL module name は `axi_encoder_input`、BD instance は `enc_in_0`、
    AXI base は `0x43D10000` のまま。address / XDC / block design は
    この決定で変更しない。
  - `GPIO_CONTROL_MAP.md` は effect output ledger のまま変更しない。
- **Why.** HWH / PYNQ の naming は module-reference flow 固有の
  runtime detail であり、ここを driver 側で吸収すれば Verilog IP
  packaging や block design rename を避けられる。HDMI / DSP / GPIO
  契約を動かさずに deploy 済 bitstream をそのまま使える。

## D37 — Encoder runtime は AppState を `EncoderEffectApplier` 経由でのみ AudioLabOverlay に反映 (raw GPIO 直書き禁止、RAT は既定で除外)

- **状況.** Phase 7G の `EncoderUiController` は AppState を更新するだけで、
  実際の overlay write は `AudioLabGuiBridge` 経由 (encoder 3 short
  press でのみ apply) だった。3 個の rotary encoder で HDMI GUI を
  notebook 無しに実操作する用途では、回転中に音色が即時に変化することと、
  RAT pedal model のように "Clash stage は残すが encoder 操作からは外したい"
  という選択的除外が必要になった。
- **決定.**
  - `audio_lab_pynq/encoder_effect_apply.py::EncoderEffectApplier` を
    encoder runtime から AudioLabOverlay への **唯一の翻訳層** とする。
    使う overlay public API は次の 3 つのみ:
    `set_noise_suppressor_settings`、`set_compressor_settings`、
    `set_guitar_effects(**kwargs)`。distortion pedal 選択は
    `set_distortion_settings` ではなく
    `set_guitar_effects(distortion_pedal_mask=...)` に集約する
    (cached 状態と整合)。
  - raw GPIO write、`set_distortion_pedal*` ショートカット、
    `HdmiEffectStateMirror.render()` 経由の二重描画は encoder loop からは
    呼ばない。HDMI render は dirty-flag loop が単独で所有する。
  - throttle (`apply_interval_s`、`EncoderEffectApplier` class 既定 100 ms;
    D76 以降の runner 既定は 20 ms) で連続回転中の AXI flood を
    抑える。encoder 3 short press は throttle を bypass して force apply。
    例外は `last_apply_ok=False` / `last_apply_message=<repr>` に保存し
    loop は落とさない。
  - RAT (`distortion_pedal_mask` bit 2) は `skip_rat=True` (既定) の時
    `EncoderUiController._cycle_model_index` と
    `EncoderEffectApplier.apply_appstate` の両方で除外する。Clash stage、
    `HdmiEffectStateMirror.rat()`、notebook からの RAT 直接呼び出しは
    手付かず。`--include-rat` で encoder からも有効化可。
  - GUI 仕様 (`GUI/compact_v2/knobs.py::EFFECTS` / `EFFECT_KNOBS`) に存在
    しない effect / parameter は触らない。`unsupported` ラベルとして記録
    し GUI status strip / resource print に小さく出すだけにする。
  - EQ knob は GUI 0..100 → overlay 0..200 (50 == unity) に変換 (overlay
    の `_level_to_q7` 仕様)。Cab `MODEL` knob は表示専用、overlay へは
    `AppState.cab_model_idx` (0..2) を送る。
  - `EncoderUiController` に `applier=` / `live_apply=` / `skip_rat=`
    kwargs を追加。`applier` 未指定時は既存 `mirror=` / `bridge=`
    fall-through を温存。
- **境界.**
  - bit / hwh / XDC / RTL / `block_design.tcl` / `create_project.tcl` /
    `hdmi_integration.tcl` / `encoder_integration.tcl` はこの決定で
    変更しない。
  - `GPIO_CONTROL_MAP.md` の effect output 契約は変更しない (D12)。
  - `HdmiEffectStateMirror` (`audio_lab_pynq/hdmi_effect_state_mirror.py`)
    は notebook-driven 用途として残存。encoder runtime は applier を
    優先する。
  - HDMI baseline (SVGA `800x600 @ 40 MHz`、D25) は変更しない。
- **Why.** GUI から見える項目だけを操作対象にすることで、未対応 API
  を encoder で叩く事故を防げる。applier を 1 箇所に閉じ込めれば、
  対応 / 未対応 / RAT 除外 / throttle / 例外捕捉のルールを 1 ファイルで
  読める。GUI render と overlay apply を分離 (dirty-flag loop) すれば
  idle 時 CPU を低く保ちつつ操作時のみ AXI を叩ける。
  RAT は実機 voicing 検証が他 pedal より遅れているため、Clash stage は
  残しつつ encoder からの誤操作を既定で防ぐ。

## D38 — PCM5102 external DAC bring-up is DAC-only and free-running (Phase 7C)

- **Decision.** The external PCM5102 DAC on PMOD JB is brought up as a
  self-contained, free-running I2S master tone generator. A new RTL
  module `hw/ip/pcm5102_dac_tone/src/pcm5102_dac_tone.v` drives the
  four I2S signals out of PMOD JB and emits a 1 kHz / 24-bit /
  quarter-scale sine to both stereo channels. A new dedicated MMCM
  `clk_wiz_audio_ext` (`100 MHz -> 12.288 MHz exact`,
  `DIVCLK_DIVIDE=5, MULT_F=48.0, CLKOUT0_DIVIDE_F=78.125, VCO=960 MHz`)
  feeds the module. Integration tcl `hw/Pynq-Z2/pcm5102_dac_integration.tcl`
  is sourced from `create_project.tcl` after `encoder_integration.tcl`.
  The PCM1808 ADC is NOT implemented in this phase (Phase 7D).
- **Boundary.**
  - XDC: four new ports added under `## Phase 7C: PCM5102 ...`:
    `ext_audio_mclk_o W14 / ext_audio_bclk_o Y14 /
    ext_audio_lrclk_o T11 / ext_dac_din_o V16`, all `LVCMOS33`,
    no `PULLUP`.
  - `block_design.tcl` is untouched directly; the new clk_wiz and
    module reference are added via the dedicated integration tcl that
    matches the `encoder_integration.tcl` pattern.
  - NO AXI-Lite slave is added. No new GPIO. `GPIO_CONTROL_MAP.md` is
    unchanged (D12).
  - ADAU1761 path (`mclk U5`, `bclk R18`, `lrclk T17`, `sdata_i F17`,
    `sdata_o G18`, `clk_wiz_0`, `i2s_to_stream_0`, `clash_lowpass_fir_0`,
    `axis_switch_*`, `axi_dma_0`) is untouched.
  - HDMI integration (D25, SVGA 800x600 @ 40 MHz) is untouched.
  - Encoder integration (D32 / D33 / D36, `axi_encoder_input` at
    `0x43D10000` mapped as `enc_in_0/s_axi`) is untouched.
  - LowPassFir DSP (`hw/ip/clash/src/LowPassFir.hs`) is untouched.
  - No second overlay, no AXIS switch to route DSP output to PCM5102 —
    the DSP path still terminates at ADAU1761 only. Routing DSP into
    the external DAC is Phase 7E and not started.
- **Frame format.** I2S Philips, 32-bit slot per channel, 24-bit data
  MSB-first with 1 BCLK delay after LRCLK transition, 7 zero LSB pads
  per slot. BCLK = MCLK / 4 = 3.072 MHz. LRCLK = BCLK / 64 = 48 kHz.
  Tone amplitude is quarter scale (`2^21 = 2097152`) by design — small
  enough to make accidental headphone-direct connections survivable
  while still being clearly audible on line-in.
- **Timing.** Post-route summary (full design):
  `WNS = -8.410 ns`, `TNS = -7313 ns` on `clk_fpga_0` (100 MHz, same
  failing domain as the baseline `-8.096 ns`, within historical band).
  PCM5102 new clock domain
  `clk_out1_block_design_clk_wiz_audio_ext_0` (12.288 MHz):
  `WNS = +77.576 ns`, 0 violations. HDMI / bclk / clash domains
  unchanged. Deploy approved.
- **Why.** Land the DAC PHY and external clock generation alone, with
  no DSP integration risk, so the wiring / module strap / line-out can
  be verified end-to-end before Phase 7D introduces the ADC and Phase
  7E touches the DSP routing. Free-running tone removes any software
  step from the bring-up smoke: power on, load overlay, listen.
- **How to apply.**
  - Listen / scope on PMOD JB pins via the smoke script
    `scripts/test_pcm5102_dac_tone.py`.
  - Do NOT add an AXI register to enable / disable the tone here — the
    module is intentionally trivial. Phase 7E will replace it with an
    AXIS path from the DSP chain.
  - PCM1808 (ADC) goes in Phase 7D following the same DAC-only +
    free-running + smoke pattern, sharing the same `clk_wiz_audio_ext`
    12.288 MHz MCLK.

## D39 — PCM5102 becomes external DAC output for AudioLab processed audio; ADAU1761 remains input codec (Phase 7E)

- **Decision.** The Phase 7C free-running tone path (`pcm5102_dac_tone`)
  is no longer instantiated by the block design. The new RTL module
  `hw/ip/pcm5102_audio_out/src/pcm5102_audio_out.v` is a *trivial
  4-signal pass-through* that mirrors the existing ADAU1761 I2S DAC
  interface onto the four PMOD JB pins:
  - `ext_audio_mclk_o`  (JB1, W14) <- `clk_wiz_audio_ext/clk_out1`
    (12.288 MHz from the Phase 7C MMCM, kept intact)
  - `ext_audio_bclk_o`  (JB2, Y14) <- top-level input port `bclk`
    (R18) -- the ADAU1761 I2S BCLK
  - `ext_audio_lrclk_o` (JB3, T11) <- top-level input port `lrclk`
    (T17) -- the ADAU1761 I2S LRCLK
  - `ext_dac_din_o`     (JB7, V16) <- `i2s_to_stream_0/so` -- the
    same serial DAC bitstream that drives ADAU `sdata_o` at G18
  PCM5102 therefore receives bit-for-bit the same processed audio
  the ADAU1761 DAC receives. Both DACs run in parallel; the user
  picks the listening source by where they plug the cable in. The
  ADAU1761 ADC / DSP chain (`i2s_to_stream_0` / `axis_data_fifo_0`
  / `clash_lowpass_fir_0` / `axis_switch_*` / `axi_dma_0`) is
  untouched.
- **Boundary.**
  - **No AXIS, FIFO, or CDC was added.** PCM5102 receives the exact
    same I2S signal ADAU receives. The 12.288 MHz MCLK to PCM5102
    SCK is NOT bit-synchronous to ADAU's `bclk` (3.072 MHz from
    ADAU's PLL), but the 256:1 ratio sits inside the PCM510x
    internal-PLL lock window. If a future board reveals lock
    issues, the fallback is to drive `ext_audio_mclk_o` constant
    low (PCM5102 then enters internal-PLL mode and derives SYSCLK
    from BCK alone). Currently the wizard output is kept driving
    JB1 because the smoke (`scripts/test_pcm5102_dsp_output.py`)
    confirms the chip locks at the user-reported wiring.
  - **No XDC change.** The four PMOD JB pin assignments stay as
    Phase 7C (D38). The new RTL is plumbed through the same four
    top-level ports.
  - **`block_design.tcl` is untouched directly.** The new module
    instance and the three new fanout connections are added via
    `hw/Pynq-Z2/pcm5102_dac_integration.tcl`, which now reads the
    existing `bclk` / `lrclk` ports and `i2s_to_stream_0/so` pin
    as additional net sinks. No existing net source or sink is
    rewired.
  - **No AXI-Lite slave**, **no new GPIO**, **no
    `GPIO_CONTROL_MAP.md` change** (D12), **no `topEntity`
    change**, **no `LowPassFir.hs` change**, **no DSP behaviour
    change**.
  - HDMI baseline (SVGA 800x600 @ 40 MHz, D25) and encoder
    integration (`enc_in_0/s_axi` at `0x43D10000`, D32 / D33 / D36)
    are untouched.
  - The Phase 7C tone module file `pcm5102_dac_tone.v` is kept in
    the repo as a free-running debug reference but NOT instantiated.
    `scripts/test_pcm5102_dac_tone.py` is kept as a callable
    historical smoke; the active smoke for Phase 7E is
    `scripts/test_pcm5102_dsp_output.py`.
- **Frame format.** Inherited unchanged from the existing ADAU1761
  DAC path: I2S Philips, 32-bit slot per channel, 24-bit data MSB
  first. PCM5102 just reads the same bits from a different physical
  pin set.
- **Timing.** Post-route summary (full design):
  `WNS = -8.724 ns`, `TNS = -7029.676 ns` on `clk_fpga_0` (100 MHz,
  same failing domain as Phase 6I C2 `-8.096 ns` and Phase 7C
  `-8.410 ns`); regression `+0.314 ns` vs Phase 7C, still inside
  the historical `-7..-9 ns` deploy band. `bclk` (3.072 MHz, ADAU
  domain that now also drives PCM5102 BCK fanout):
  `WNS = +320.751 ns`, 0 setup or hold violations. WHS `+0.051 ns`,
  THS `0.000 ns`. Utilization after place: Slice LUTs `19102`
  (`35.91%`), Slice Registers `21255` (`19.98%`), Block RAM Tile
  `9` (`6.43%`), DSPs `83` (`37.73%`); essentially identical to
  Phase 7C.
- **Why.** Land the processed-audio path to the external DAC with
  the smallest possible delta from the deployed-and-verified
  ADAU1761 I2S signal. Tapping the ADAU master clocks and the
  i2s_to_stream serial output keeps every existing register
  stage, register count, AXIS contract, and TLAST timing
  unchanged; no CDC, no FIFO, no rate-matching SRC. Running both
  DACs in parallel makes A/B comparison trivial.
- **How to apply.**
  - For listening / measurement: connect the audio source to
    ADAU1761 Line In; either the on-board ADAU DAC out or the
    PMOD JB PCM5102 line out should produce the same processed
    signal.
  - For Phase 7D (PCM1808 ADC): add the input pin (JB4, T10) and
    reuse the existing `clk_wiz_audio_ext` 12.288 MHz wizard for
    PCM1808 SCKI. The output path stays as Phase 7E.
  - For Phase 7E next iteration (runtime DAC source switching,
    XSMT control from PL, pop-noise suppression): keep the
    pass-through topology and add a small mute-gate ahead of
    `ext_dac_din_o`. Do not put a second AXIS-to-I2S serializer
    in the design unless the rate mismatch becomes a measured
    problem.

## D40 — PCM5102 SCK is tied LOW (internal-SYSCLK mode), not driven by clk_wiz_audio_ext

- **Decision.** `pcm5102_audio_out.v` drives `ext_audio_mclk_o` (PMOD JB1
  / PCM5102 SCK pin) to **constant `1'b0`**, ignoring its
  `mclk_12m288_i` input. The PCM510x therefore enters its internal-PLL
  / internal-SYSCLK mode and re-derives sysclk from BCK alone. The
  `clk_wiz_audio_ext` 12.288 MHz MMCM is *kept* in
  `hw/Pynq-Z2/pcm5102_dac_integration.tcl` (and its `clk_out1` is still
  wired into the module's input port to preserve the integration tcl
  shape) but the wizard's downstream consumer is now a no-op and
  synthesis prunes the 12.288 MHz domain entirely. The module keeps
  the `mclk_12m288_i` input plus a one-line `wire _unused_mclk` hook
  so synth does not warn about a missing port; the integration tcl
  does not need to be rewritten.
- **Why.** Phase 7E initial bring-up (`9f21546`) drove
  `ext_audio_mclk_o` from `clk_wiz_audio_ext/clk_out1` while BCK on
  PMOD JB came from the ADAU1761 PLL via the existing top-level
  `bclk` input port. The two are sourced from independent PLLs (PS
  FCLK_CLK0 100 MHz vs ADAU's own analog PLL) and are not bit-true
  synchronous. PCM510x's external-SCK mode requires the SCK/BCK
  ratio to stay at an exact 64/128/192/256/384/512 fs; with the two
  PLLs drifting at the ppm level, the chip's internal phase
  estimator went in and out of lock and produced an audible
  graininess / periodic jitter on the output (user-reported on the
  bench, `9f21546` deploy). Switching to internal-SYSCLK mode (SCK
  low) takes the external MCLK out of the locking equation
  entirely; the chip uses BCK transitions to drive its own sysclk
  and the audible artifacts disappear. This is the configuration
  most PCM5102 breakout boards ship with SCK tied to GND on the
  PCB for exactly this reason.
- **Boundary.**
  - **No XDC change.** The four PMOD JB pin assignments stay as Phase
    7C (D38). JB1 is now driven at static 0 instead of toggling at
    12.288 MHz.
  - **No `block_design.tcl` direct edit.** The wizard stays in the
    integration tcl; only the RTL one-line assignment changed.
  - **No new GPIO, no AXI-Lite, no `GPIO_CONTROL_MAP.md` change.**
  - **No `topEntity` / `LowPassFir.hs` / DSP behaviour change.**
    HDMI / encoder integration untouched.
  - **Phase 7C tone module `pcm5102_dac_tone` stays in the repo as a
    debug reference**, not instantiated. The Phase 7C smoke
    `scripts/test_pcm5102_dac_tone.py` would now produce zero
    instead of a 1 kHz tone if anyone re-instantiated the module
    because its MCLK input is also constant low under this bit;
    that is fine for the deferred reference role.
- **Timing.** Post-route summary (full design) on the SCK-low bit:
  `WNS = -8.004 ns`, `TNS = -6767.334 ns` on `clk_fpga_0`. WNS
  *improves* by `+0.720 ns` vs the initial Phase 7E `-8.724 ns`
  because the unused 12.288 MHz domain was pruned and the critical
  path no longer competes with the wizard's clock buffer / network.
  Hold remains clean (`WHS = +0.052 ns`, `THS = 0.000 ns`).
- **How to apply.**
  - If a future bit needs to drive an external MCLK to PCM5102 (e.g.
    a different DAC module that requires it), un-tie the SCK output
    AND make sure the source is bit-true synchronous to BCK. A
    second MMCM fed by FCLK_CLK0 is not enough; the only clean way
    is to derive MCLK from the ADAU BCK net via a PLL whose input
    can accept 3.072 MHz (PLLE2_BASE input minimum is 19 MHz, so
    that path is not directly available -- prefer keeping SCK low).
  - For Phase 7D (PCM1808 ADC SCKI), re-attach the 12.288 MHz
    wizard output to a *separate* top-level port dedicated to
    PCM1808; do NOT route it back into PCM5102 SCK.

## D41 — PCM1808 becomes external ADC source via a build-time input mux; PCM5102 DAC output preserved (Phase 7D)

- **Decision.** The new RTL
  `hw/ip/pcm1808_adc_input/src/pcm1808_input_select.v` is a 2:1
  combinational wire mux inserted between the existing top-level
  `sdata_i` port (ADAU1761 ADC I2S serial input, F17) and the new
  top-level `ext_adc_dout_i` port (PCM1808 DOUT, JB4 / T10). The mux
  output drives the existing `i2s_to_stream_0/si` pin. The mux
  `sel_external_i` is tied by a single-bit `xlconstant` in
  `hw/Pynq-Z2/pcm1808_adc_integration.tcl`:
    - `CONST_VAL = 1` -> Phase 7D default, **PCM1808** is the active ADC
    - `CONST_VAL = 0` -> rebuilds back to **ADAU1761** ADC fallback
  Runtime / AXI control of the select line is deferred. The existing
  `i2s_to_stream_0` IP, its `bclk` / `lrclk` inputs, all AXIS
  downstream (data fifo / Clash LowPassFir / axis_switch_* /
  axi_dma_0), the GPIO contract, and the output side
  (`i2s_to_stream_0/so` -> ADAU `sdata_o` G18 + PMOD JB7 PCM5102 DIN)
  are untouched. PCM1808 BCK / LRCK share the same physical PMOD JB
  pins (JB2 / JB3) that PCM5102 already uses, so both external chips
  see the same ADAU-PLL-sourced I2S clocks.
- **PCM1808 SCKI clocking.** PCM1808 requires SCKI in slave mode (no
  PCM510x-style "SCKI absent -> internal PLL from BCK" fallback). For
  this bring-up the SCKI source is the 12.288 MHz output of the
  `clk_wiz_audio_ext` MMCM that Phase 7C added (FCLK_CLK0 100 MHz ->
  exact 12.288 MHz). `pcm5102_audio_out.v` was simultaneously reverted
  from the D40 SCK-low fix back to the original 12.288 MHz
  passthrough; the same wizard output is therefore now wired to JB1,
  which feeds PCM1808 SCKI. PCM5102 SCK is intentionally NOT on JB1
  any more -- the user's Phase 7D physical board rewiring hard-ties
  PCM5102 SCK to GND on the module side so PCM5102 stays in internal-
  SYSCLK mode (D40 preserved at the wiring layer instead of the RTL
  layer).
- **Async-clocks caveat (deliberately accepted for this bring-up).**
  The 12.288 MHz SCKI from `clk_wiz_audio_ext` is sourced from the PS
  FCLK_CLK0 100 MHz PLL, while BCK / LRCK on the same physical PMOD
  JB pins are sourced from the ADAU1761 PLL. The two are NOT bit-true
  synchronous and drift at the ppm level. PCM1808 in slave mode
  expects SCKI to be synchronous to BCK at a valid 256/384/512 fs
  ratio. Phase 7E showed PCM5102 producing audible graininess under
  this same async-clocks condition; PCM5102 was rescued by tying SCK
  low (D40), but PCM1808 has no equivalent rescue path. The decision
  is to ship Phase 7D and listen on the bench:
    - If PCM1808 -> PCM5102 sounds clean, async clocks are tolerated.
    - If PCM1808 produces noisy / unlocked output, the next phase
      (deferred) is to make the FPGA the I2S master, generate BCK /
      LRCK / SCKI from a single clean source, and reconfigure the
      ADAU1761 over I2C as I2S slave -- significant change to the
      existing audio path, intentionally not attempted here.
- **Boundary.**
  - XDC adds **one** new pin (`ext_adc_dout_i` on T10 / JB4,
    LVCMOS33, no pull). Other PMOD JB pin assignments stay as
    Phase 7C / 7E.
  - `block_design.tcl` is untouched directly. The integration tcl
    deletes the existing `sdata_i_1` net, inserts the mux + an
    `xlconstant`, and re-routes the ADAU port and the new PCM1808
    port through the mux.
  - No AXI-Lite slave, no new GPIO, no `GPIO_CONTROL_MAP.md`
    change (D12), no `topEntity` / `LowPassFir.hs` / DSP behaviour
    change. HDMI / encoder integration untouched. PCM5102 DSP
    output path (D39) untouched.
  - PCM1808 mode pins (FMT / MD0 / MD1) are **strapped on the
    module** to I2S slave mode; the FPGA does not drive them.
    PCM1808 module VCC is whatever the onboard regulator expects
    in order to keep DOUT at 3.3V (do NOT inject 5V on a PL pin).
- **Timing.** Post-route summary (full design) on the Phase 7D bit:
  `WNS = -8.158 ns`, `TNS = -6474.516 ns` on `clk_fpga_0` (between
  the Phase 7E pre-fix `-8.724 ns` and the D40 SCK-low post-fix
  `-8.004 ns`, all inside the historical `-7..-9 ns` deploy band).
  Hold remains clean (`WHS = +0.051 ns`, `THS = 0.000 ns`). The
  12.288 MHz domain (`clk_out1_block_design_clk_wiz_audio_ext_0`)
  is back in the design (was pruned in D40 because nothing
  consumed it; now consumed by `ext_audio_mclk_o`) and reports 0
  setup/hold violations. `bclk` domain (now driving PCM1808 BCK
  fanout in addition to ADAU `i2s_to_stream_0/bclk` and PCM5102
  BCK): `WNS = +321.256 ns`, 0 violations. Utilization after
  place: Slice LUTs `19099` (`35.90%`), Slice Registers `21253`
  (`19.97%`), Block RAM Tile `9` (`6.43%`), DSPs `83` (`37.73%`)
  -- essentially identical to Phase 7E.
- **Why.** Land the input side of the external-codec path with the
  smallest possible delta from the deployed Phase 7E PCM5102 output
  bit. Build-time mux preserves ADAU1761 fallback without committing
  to runtime switching infrastructure. Keeping i2s_to_stream_0 / AXIS
  / DSP / output side untouched isolates the change to a single new
  RTL file + a single new top-level input port + a single new
  integration tcl + a single XDC line, which makes regression
  bisection trivial.
- **How to apply.**
  - For listening / measurement: feed a line-level source into
    PCM1808's analog input (NOT a guitar -- PCM1808 is line-level
    Hi-Z incompatible; analog front-end is deferred to Phase 7E
    follow-up / Phase 7H). Listen on PCM5102 line out.
  - To fall back to ADAU1761 ADC: edit
    `hw/Pynq-Z2/pcm1808_adc_integration.tcl` and change
    `CONFIG.CONST_VAL {1}` to `{0}`, then rebuild bit / hwh + deploy.
  - If PCM1808 audio is grainy / noisy: see the async-clocks caveat
    above; the next escalation is FPGA-as-I2S-master, not another
    RTL tweak.

## D42 — PCM1808 SCKI is on dedicated PMOD JB8 / W16; JB1 stays constant low (Phase 7D follow-up)

- **Decision.** The Phase 7D first attempt drove the 12.288 MHz
  `clk_wiz_audio_ext/clk_out1` onto JB1 (`ext_audio_mclk_o`) so the
  same wire could feed PCM1808 SCKI. The user's board has PCM5102
  SCK hard-tied to GND on the module, so in theory JB1 toggling
  should not have affected PCM5102. In practice it did -- the
  12.288 MHz signal cross-coupled onto PCM5102 SCK closely enough
  that the async-clocks jitter that D40 fixed came back as audible
  graininess on PCM5102 line out. The Phase 7D follow-up:
  - `pcm5102_audio_out.v` keeps `assign ext_audio_mclk_o = 1'b0;`
    (D40 preserved structurally inside the RTL). `mclk_12m288_i`
    input port stays for ABI compatibility, ignored via
    `wire _unused_mclk = mclk_12m288_i;`.
  - A new top-level output port `ext_pcm1808_sckie_o` is added
    in `pcm1808_adc_integration.tcl` and is driven directly from
    `clk_wiz_audio_ext/clk_out1`. The PMOD JB pin assignment in
    `hw/Pynq-Z2/audio_lab.xdc` is **JB8 / W16, LVCMOS33, no pull**.
  - Physical wire change required by the user: PCM1808 SCKI moves
    from JB1 to JB8 / W16. JB1 has no consumer any more.
- **Boundary.**
  - XDC: adds one new `set_property PACKAGE_PIN W16 ...` block
    under "Phase 7D follow-up". JB1 / JB2 / JB3 / JB4 / JB7
    assignments are unchanged.
  - `block_design.tcl` is untouched directly. The new top-level
    port + the `clk_wiz_audio_ext/clk_out1 -> ext_pcm1808_sckie_o`
    connection are added in `pcm1808_adc_integration.tcl`.
  - No AXI-Lite slave, no new GPIO, no `GPIO_CONTROL_MAP.md`
    change, no `topEntity` / `LowPassFir.hs` / DSP change. HDMI /
    encoder integration untouched. PCM5102 DSP-output path (D39)
    is preserved bit-for-bit.
  - PCM5102 SCK stays tied to GND on the module side. With JB1 now
    constant 0 from the RTL and JB8 carrying the wizard output, the
    constant-low guarantee on the PCM5102 SCK net is independent of
    any further physical wiring around JB1.
- **Why.** Preserving D40's SCK-low guarantee on PCM5102 requires
  JB1 to stay quiescent. Any future need for an external MCLK on
  PMOD JB therefore has to land on a *different* pin. JB8 / W16 is
  the next free PMOD JB pin and was already reserved as
  `EXT_AUDIO_SPARE_JB8` in `IO_PIN_RESERVATION.md` 4A.1, so the
  move costs one new XDC line and one new `create_bd_port` /
  `connect_bd_net` pair.
- **How to apply.**
  - PCM5102 SCK -> hard-tied to GND on the module. Never to JB1.
  - PCM1808 SCKI -> JB8 / W16 (driven by `clk_wiz_audio_ext`,
    12.288 MHz). Never to JB1.
  - PCM5102 BCK / LCK -> JB2 / JB3 (shared with PCM1808 BCK /
    LRCK on the same physical nets).
  - PCM5102 DIN -> JB7 (driven by `i2s_to_stream_0/so`).
  - PCM1808 DOUT -> JB4 (read by the mux into
    `i2s_to_stream_0/si`).
  - JB1 -> nothing. If a future revision needs to expose another
    audio clock externally, add yet another dedicated PMOD JB pin
    rather than re-purposing JB1.

## D43 — Phase 7D ships with mux=ADAU (CONST_VAL=0); PCM1808 hardware diagnosis deferred

- **Decision.** The Phase 7D bring-up bit was built first with the
  build-time mux constant at `CONST_VAL=1` (PCM1808 as the active
  ADC source). On the bench:
  - `--inject-sine` confirmed the output path (DMA -> i2s_to_stream_0
    -> ADAU sdata_o / PCM5102 DIN) plays a clean 1 kHz tone after
    the D42 SCKI move.
  - `--capture-adc` returned **pure zeros** on both L and R from
    PCM1808 regardless of analog input: silent loopback, finger
    touch (which lowered the values to 0, showing the chip is at
    least clocking out I2S frames), and a smartphone line-out
    signal fed directly into PCM1808 `L_IN/R_IN` with the
    loopback temporarily disconnected.
  - Hardware checklist was exhausted: VCC=5V from Arduino POWER,
    VDD=3.3V from PMOD JB12 (the dual-supply fix from
    [[pcm1808-dual-supply-and-pmod-brownout]]), GND common,
    BCK/LRCK arriving from ADAU PLL, SCKI on JB8, DOUT on JB4,
    mode straps verified at GND (`MD0=MD1=GND` slave 256fs,
    `FMT=GND` I2S Philips -- the "FMY" silk on the user's module
    is a poor rendering of `FMT`).
  - Most plausible remaining hypothesis: PCM1808 chip or analog
    front-end (`VINL/VINR/VREF/VCOM`) was damaged earlier when
    the user connected PMOD 3.3V to `VCC` (which expects 5V) and
    the chip pulled the rail down hard enough to brown-out
    PCM5102 -- the chip survived enough to keep clocking out I2S,
    but its analog-to-digital path does not encode input.
  - Decision: ship Phase 7D with **`CONFIG.CONST_VAL {0}` in
    `pcm1808_adc_integration.tcl`** so the deployed mux selects
    ADAU1761 ADC. The Phase 7E ADAU-mirror DSP-output path stays
    fully functional and the user can keep working / iterating
    on the audio chain while the PCM1808 module is replaced or
    deeper hardware diagnosis is done in a future session.
  - User confirmed on the bench: ADAU Line In -> AudioLab DSP ->
    PCM5102 line out works (minor audio-quality nits noted,
    deferred -- separate from the PCM1808 bring-up).
- **Boundary.**
  - Only `CONFIG.CONST_VAL` in `pcm1808_adc_integration.tcl`
    differs from the Phase 7D first attempt; everything else
    (RTL, XDC, smoke script with diagnostic flags, integration
    structure) is preserved.
  - To flip back to PCM1808 for a future bring-up retry, change
    the value to `{1}` and rebuild. No other change needed.
- **Smoke diagnostic additions** (kept in
  `scripts/test_pcm1808_adc_to_pcm5102.py`):
  - `--inject-sine`: DMA -> i2s_to_stream_0 -> PCM5102 (bypasses
    the input mux entirely). Confirms output side independently.
  - `--capture-adc`: forces route `line_in -> passthrough -> DMA`
    and prints `min / max / mean / RMS / peak_dBFS / top16 range
    / low16 range` so the caller can tell silence / DC bias /
    bit-shift / real signal apart on the input.
- **Timing.** Post-route summary (full design) on the deployed
  mux=ADAU bit: `WNS = -7.931 ns`, `TNS = -6359.881 ns` on
  `clk_fpga_0` (best in the Phase 7E/7D series; the mux's PCM1808
  fanout pruned because the constant=0 makes the PCM1808 branch
  unused, freeing some routing). `WHS = +0.051 ns`, `THS = 0 ns`
  (hold clean). 12.288 MHz domain stays (driving JB8 SCKI),
  reports 0 violations. `bclk` domain `WNS = +321 ns`-class as
  in earlier Phase 7E/7D builds. Inside the historical
  `-7..-9 ns` deploy band.
- **How to apply.**
  - On a fresh PCM1808 module: change `CONST_VAL {0}` to `{1}`,
    rebuild bit/hwh, deploy, re-run `--capture-adc` to see if
    PCM1808 produces non-zero samples for a known input. If yes,
    keep PCM1808 as the default source; if no, leave it at 0 and
    investigate further (multimeter on `VREF` / `VCOM`, scope on
    `DOUT`, etc.).
  - The audio-quality nits the user mentioned at Phase 7D close-out
    (minor noise / artefacts in the ADAU -> PCM5102 path) are not
    in scope of D43; they will be triaged separately and may relate
    to the JB8 12.288 MHz crosstalk into JB7 (PCM5102 DIN) along
    the PMOD ribbon. Mitigations to try later: shorter wires,
    twisted-pair ground returns for JB7/8, or moving SCKI further
    from DIN on the PMOD.

## D44 — PCM5102 quality follow-up starts with unused-SCKI gating and output diagnostics

- **Decision.** Do not start with a DSP / Clash change for the
  remaining "PCM5102 sounds worse than desired" report. This entry
  describes the Phase 7D close-out state, before D48 retired the
  PCM5102 / PCM1808 path in favour of Pmod I2S2. At that time, the
  output path was still the ADAU DAC serial bitstream mirrored to
  PCM5102 (`i2s_to_stream_0/so`), PCM5102 SCK was correctly tied low
  for internal-SYSCLK mode, and the deployed mux selected ADAU input.
  The first non-physical improvement proposed for that historical path was:
  **when PCM1808 is not the active ADC source, stop the unused
  `ext_pcm1808_sckie_o` 12.288 MHz output on JB8 / W16**. The second
  improvement is a PCM5102-oriented debug output mode that can select
  processed audio, digital silence, a `-18 dBFS` 1 kHz tone, and a
  ramp on the PCM5102 output path.
- **Why.**
  - The deployed Phase 7D close-out bit has `CONFIG.CONST_VAL {0}`
    (ADAU input), but `clk_wiz_audio_ext/clk_out1` still drives JB8
    at 12.288 MHz for the deferred PCM1808. JB8 is adjacent to JB7,
    which carries PCM5102 DIN, so an unused high-speed clock remains
    the most plausible RTL-side contributor to residual external-DAC
    artifacts.
  - Physical checks (shorter wires, PMOD GND return, decoupling,
    line-level loading) still matter, but this build option removes a
    known unnecessary aggressor without changing the DSP chain.
  - A debug output mode makes future reports concrete: if digital
    silence is noisy, the fault is downstream of the serializer; if
    `-18 dBFS` tone is clean but processed audio is poor, the fault is
    input / DSP / gain staging; if the ramp or tone shows bit slips,
    inspect the I2S serializer / external wiring.
- **Boundary.**
  - This is a follow-up plan only in this docs/comment pass. No RTL,
    XDC, Vivado build, bit/hwh regeneration, deploy, `LowPassFir.hs`,
    HDMI timing, encoder pin, GPIO map, or block design change is made
    by this decision record.
  - The eventual SCKI-gating implementation should not remove the
    PCM1808 path. It should preserve the ability to rebuild with
    PCM1808 active later, at which point JB8 must again provide the
    required 12.288 MHz SCKI unless a larger FPGA-as-I2S-master phase
    replaces the clocking scheme.
  - PCM5102 SCK stays tied to GND / low. Do not reconnect it to MCLK
    and do not drive it high.
- **Likely implementation shape.**
  - Minimal variant: in `pcm1808_adc_integration.tcl`, condition the
    JB8 output source on the same build-time ADC-source choice so
    mux=ADAU drives `ext_pcm1808_sckie_o` low and mux=PCM1808 drives
    `clk_wiz_audio_ext/clk_out1`. This requires a Vivado rebuild and
    timing review.
  - Debug mode: add a small PCM5102 output selector near
    `pcm5102_audio_out` with modes for processed audio, silence,
    `-18 dBFS` 1 kHz tone, and ramp. Prefer a simple build-time or
    low-risk control path first; do not introduce a wide DSP mux or
    touch `LowPassFir.hs` unless measurement proves it is needed.
  - Documentation/comments that still describe JB1 as a live 12.288 MHz
    SCK/SCKI pin should be corrected to the D42 reality: JB1 is
    constant 0 / unused, PCM5102 SCK is GND, and PCM1808 SCKI is JB8.

## D45 — Evaluate Digilent Pmod I2S2 as a stable external I2S I/O reference before further PCM1808 work

- **Decision (plan only, later implemented by D48/D49/D50).** Add
  Digilent **Pmod I2S2** (CS4344 24-bit
  stereo DAC + CS5343 24-bit stereo ADC on a single PMOD board) as an
  evaluation reference for external I2S I/O before the next PCM1808
  bring-up attempt. The plan is staged in
  `docs/ai_context/PMOD_I2S2_INTEGRATION_PLAN.md`. **This decision
  records the planning step only — no RTL / XDC / Tcl / Vivado /
  bit / hwh / Python / Notebook change is made by this commit.**
- **Why.**
  - PCM1808 hardware is suspected damaged (`DECISIONS.md` D43,
    `--capture-adc` returns pure 0 even with line-in present). Going
    back to the same PCM1808 module is not a healthy starting point
    for the next audio-quality pass.
  - At the Phase 7D close-out, PCM5102 line out and PCM1808 line in
    lived on two separate breakout boards with hand-routed jumper wires
    on PMOD JB;
    JB7 (PCM5102 DIN) / JB8 (PCM1808 SCKI) crosstalk is one suspected
    contributor to the residual PCM5102 audio-quality nits the user
    reported at Phase 7D close-out (`DECISIONS.md` D42 / D44).
  - Pmod I2S2 places DAC and ADC on the same board sharing a single
    MCLK / BCLK / LRCLK tree, behind a single PMOD 12-pin connector
    that mates directly to PMOD JB. Long jumper ribbons disappear.
  - The Pmod I2S2 MCLK target (256 fs = 12.288 MHz at 48 kHz) lines
    up exactly with the existing `clk_wiz_audio_ext` MMCM
    (`100 MHz -> 12.288 MHz exact`, `DECISIONS.md` D38), so no new
    clock infrastructure is required for the 48 kHz initial spec.
  - The existing Clash `I2S.hs` (`vecFromSamples`) emits exactly the
    24-bit MSB-first / 32-bit slot / I2S Philips frame that CS4344 /
    CS5343 want, so no SRC, CDC, or AXIS rework is needed to feed
    Pmod I2S2 from the existing DSP path.
- **Boundary.**
  - This decision changes **only docs** (the integration plan plus
    minimal cross-references in CURRENT_STATE / EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN
    / IO_PIN_RESERVATION / RESUME_PROMPTS). No `hw/` / `audio_lab_pynq/`
    / `GUI/` / `scripts/` / `tests/` / `bitstreams/` change.
  - ADAU1761 input / DSP / ADAU DAC output (D27) stay untouched.
  - PCM5102 ADAU-mirror output path (D39) stays untouched. PCM5102
    SCK stays GND-tied / internal-SYSCLK mode (D40 / D42). JB1 stays
    constant 0 at the RTL layer.
  - PCM1808 build-time mux ships with `CONFIG.CONST_VAL {0}` (D43).
    This is **not** the lever to reactivate PCM1808; the PCM1808
    module is still suspected damaged and the freeze stays in place.
  - HDMI baseline (D25 SVGA 800x600 @ 40 MHz) is untouched.
  - Encoder PL IP (D32 / D33 / D34 / D36 / D37, `enc_in_0/s_axi` at
    `0x43D10000`) is untouched.
  - GPIO_CONTROL_MAP (D12) is untouched. No new AXI GPIO is planned
    for the Pmod I2S2 path; build-time mux + XDC pin map only.
  - 96 kHz operation is a Phase Pmod-5 future option on a separate
    branch; the initial 48 kHz spec is the only one this decision
    commits to.
- **Phase plan summary** (full detail in
  `PMOD_I2S2_INTEGRATION_PLAN.md` section 11):
  - Phase Pmod-0 — initial docs-only commit + a follow-up docs-only
    commit (2026-05-18) confirming the PMOD JB pin mapping against
    the Digilent Pmod I2S2 reference manual. Pin 1..4 = D/A MCLK /
    LRCK / SCLK / SDIN on JB1/JB2/JB3/JB4 (`W14 / Y14 / T11 / T10`),
    Pin 7..10 = A/D MCLK / LRCK / SCLK / SDOUT on JB7/JB8/JB9/JB10
    (`V16 / W16 / V12 / W13`), Pin 5/11 = GND, Pin 6/12 = VCC 3.3V.
    D/A 側と A/D 側は別 pin だが FPGA 内部で 1 系統の MCLK / LRCK /
    BCLK を生成して両側に fanout する方針 (D40 / D41 で経験した
    async-clocks 問題を構造的に排除)。
  - Phase Pmod-1 — Pmod I2S2 DAC-only 1 kHz tone bring-up (after the
    user removes the existing PCM5102 / PCM1808 jumpers from PMOD JB).
  - Phase Pmod-2 — Pmod I2S2 ADC-to-DAC physical loopback (no DSP).
  - Phase Pmod-3 — Pmod I2S2 ADC -> existing mono DSP -> Pmod I2S2 DAC.
  - Phase Pmod-4 — A/B comparison ADAU vs PCM5102 vs Pmod I2S2.
  - Phase Pmod-5 (optional) — 96 kHz experiment on a separate branch.
- **How to apply.**
  - Do not start Phase Pmod-1 until the user has the Pmod I2S2 module
    in hand, has filled in the `要公式確認` items in
    `PMOD_I2S2_INTEGRATION_PLAN.md` section 6 / section 15 from the
    Digilent Pmod I2S2 reference manual + CS4344 / CS5343 datasheets,
    and has physically removed the existing PCM5102 / PCM1808 jumper
    wires from PMOD JB.
  - When implementation starts, follow the Phase Pmod-1 prompt in
    `PMOD_I2S2_INTEGRATION_PLAN.md` section 16. Each subsequent phase
    must keep ADAU1761 / DSP / HDMI / encoder integration tcls
    untouched and treat Pmod I2S2 as a separate build variant rather
    than a runtime mux until A/B comparison proves it is the reference.

## D46 — Replace generic Overdrive with six selectable inspired-by models (TS9 / OD-1 / BD-2 / Jan Ray / OCD / CENTAUR)

- **Decision.** The single-character Overdrive stage was retired and
  replaced by **six selectable models** chosen at runtime via a 3-bit
  `overdriveModel` field. Every overlay load picks one of these
  voicings; there is no "generic OD" fallback. The Python API stays
  source-compatible (`set_guitar_effects(overdrive_on=True, ...)`
  still works) and a new `model=` kwarg / `set_overdrive_model()` API
  exposes the model select.

  Model labels are **inspired-by**, not commercial circuit /
  schematic copies (same rule as `DECISIONS.md` D7 / D17 for the
  distortion pedals and amp models):

  | `overdriveModel` | Internal enum | UI label |
  | --- | --- | --- |
  | 0 | `ts9`     | Ibanez / TS9       |
  | 1 | `od1`     | BOSS / OD-1        |
  | 2 | `bd2`     | BOSS / BD-2        |
  | 3 | `jan_ray` | Vemuram / Jan Ray  |
  | 4 | `ocd`     | Fulltone / OCD     |
  | 5 | `centaur` | CENTAUR            |

  Values 6 / 7 are reserved and fall back to model 0 (TS9) in the
  Clash coefficient case lookup.

- **Why.**
  - Parity with the distortion-section pedal-mask refactor
    (`DECISIONS.md` D6 / D9 / D17 / D20 / D21). The distortion side
    already shipped six selectable pedals plus reserved-pedal slots;
    the overdrive section was the last stage carrying only a
    generic voicing.
  - The user spec calls for six named overdrive voicings so a single
    DSP build can switch between TS-style, BD-style, OCD-style etc.
    without a Vivado rebuild.
  - "model-based always" simplifies the Python / GUI / encoder API
    relative to "generic + optional model layer", which is the
    pattern that already worked for `AMP_MODELS` (named voicings
    over one numeric character knob, `DECISIONS.md` D17).

- **What changes in this decision.**
  - **Clash side** (`hw/ip/clash/src/AudioLab/Effects/Overdrive.hs` +
    `Control.hs`):
    - New `overdriveModel :: Ctrl -> Unsigned 3` accessor on
      `overdrive_control.ctrlD[2:0]` (= word bits 26..24).
    - Four small per-model coefficient lookups:
      `odDriveK / odKneeP / odKneeN / odSafetyKnee`. Each is a 6-way
      constant `case` whose output feeds the input of one existing
      arithmetic op.
    - Same 6-stage register pipeline (mul -> boost -> clip ->
      toneMul -> toneBlend -> level). No new register stage, no new
      multiplier, no new `topEntity` port.
  - **GPIO map** (`GPIO_CONTROL_MAP.md`): the 3-bit `overdriveModel`
    field shares `axi_gpio_overdrive.ctrlD` with the existing
    `distTight` byte. `ctrlD[7:3]` keeps `distTight` (the only bits
    that ever survived the `>> 3` / `>> 4` shifts in the
    distortion-section Clash code); `ctrlD[2:0]` carries the model.
    No new AXI GPIO, no `block_design.tcl` change.
  - **Python API** (`audio_lab_pynq/AudioLabOverlay.py` +
    `effect_defaults.py`):
    - New `OVERDRIVE_MODELS` / `OVERDRIVE_MODEL_LABELS` tables (six
      entries each).
    - New `set_overdrive_model(model)` / `get_overdrive_model()` /
      `set_overdrive_settings(model=...)` methods.
    - New `overdrive_model=` kwarg in
      `guitar_effect_control_words(...)` and
      `set_guitar_effects(...)`. Default = 0 (TS9). Invalid values
      clamp to 0.
    - `_apply_distortion_state_to_words` composes `ctrlD` as
      `(tight & 0xF8) | (od_model & 0x07)` so a partial tight write
      cannot corrupt the model select and vice versa.
    - The OD cache (`_od_state`) tracks `enabled / drive / tone /
      level / model`; `_merge_cached_distortion_state` keeps it in
      sync with `set_guitar_effects` so the cache and GPIO never
      drift apart.
  - **Compact-v2 GUI** (`GUI/compact_v2/{knobs, state, renderer,
    hit_test}.py`):
    - `OVERDRIVE_MODELS` model-label table added next to the
      existing `DIST_MODELS / AMP_MODELS / CAB_MODELS`.
    - `AppState.overdrive_model_idx` added; persisted to / loaded
      from `fx_gui_state.json` via `_STATE_KEYS`.
    - The renderer's [model ▼] dropdown chip now draws for
      `selected_short in ("DIST", "OD", "AMP", "CAB")`; the OD
      branch resolves through `OVERDRIVE_MODELS`.
    - `hit_test_compact_v2()` treats OD the same as DIST / AMP / CAB
      so left-arrow / right-arrow clicks cycle `overdrive_model_idx`.
  - **Encoder runtime** (`audio_lab_pynq/encoder_ui.py` +
    `encoder_effect_apply.py`):
    - `EncoderUiController._cycle_model_index` now maps
      `"Overdrive" -> ("overdrive_model_idx", 6)`; it previously
      aliased to `dist_model_idx`. Encoder 2 short press still
      enters model-select mode, encoder 2 rotate cycles the new
      `overdrive_model_idx`.
    - `EncoderEffectApplier.apply_appstate` now reads
      `state.overdrive_model_idx` (clamp 0..5) and forwards it as
      `overdrive_model=` to `AudioLabOverlay.set_guitar_effects`.
  - **HDMI state mirror** (`audio_lab_pynq/hdmi_effect_state_mirror.py`
    + new `audio_lab_pynq/hdmi_state/overdrives.py`):
    - New `OVERDRIVE_MODELS / OVERDRIVE_MODEL_LABELS` tables in the
      `hdmi_state` subpackage.
    - `current_overdrive_model` / `current_overdrive_label` tracked
      next to the existing pedal / amp / cab pair; sync helpers
      mirror them onto `AppState.overdrive_model{,_idx,_label}`.
    - `dropdown_label_for(...)` accepts a new keyword
      `overdrive_label=` and `dropdown_visible_for(...)` now
      returns True for OVERDRIVE too. PEDAL / AMP / CAB callers
      keep working byte-for-byte.

- **Constraint (timing).**
  - The May 4 `model_select` attempt put eight parallel non-linear
    computations behind one `case modelSelect` mux and regressed WNS
    from -7.7 ns to -15.1 ns (rejected, never deployed, see
    `TIMING_AND_FPGA_NOTES.md`).
  - This decision is explicitly the cheap counterpart: the 6-way
    case appears **only** at the inputs of existing arithmetic ops
    (one multiplier input, one clip-helper knee, one safety-knee
    constant). The audio sample's combinational path is unchanged.
  - The new design adds no extra pipeline register stage and no
    extra multiplier. The expected WNS impact is sub-1 ns and must
    stay inside the historical `-7..-9 ns` deploy band; the deploy
    gate rule from `TIMING_AND_FPGA_NOTES.md` still applies (any
    -10 ns-class regression is a hard reject; -15 ns-class is
    unconditional reject).

- **Boundary.**
  - **No** `hw/Pynq-Z2/block_design.tcl` change. No new AXI GPIO.
    No new `topEntity` port. No new HDMI / encoder / PCM5102 /
    PCM1808 / ADAU1761 path. No XDC change.
  - The legacy `distTight` semantics are preserved bit-for-bit: every
    Clash consumer already discards the low 3 bits via `>> 3` /
    `>> 4`, and the Python writer masks tight to the top 5 bits
    before ORing in the model select.
  - Existing `set_guitar_effects(overdrive_on=True, overdrive_drive=,
    overdrive_tone=, overdrive_level=, ...)` notebooks keep working;
    `overdrive_model=` defaults to 0 (TS9).
  - HDMI baseline (D25 SVGA 800x600 @ 40 MHz) untouched.
  - Encoder PL IP (D32 / D33 / D34 / D36 / D37, `enc_in_0/s_axi` at
    `0x43D10000`) untouched.
  - PCM5102 ADAU-mirror output (D39) and SCK-tied-low rule
    (D40 / D42) untouched. PCM1808 mux=ADAU fallback (D43)
    untouched.

- **Per-model voicing intent (character knobs, not measurements).**
  - **TS9** (driveK=5, kneeP=2.7M, kneeN=2.3M, safety=3.2M) — the
    prior generic OD baseline; mid-focused soft clip with TS-style
    asymmetry.
  - **OD-1** (driveK=4, kneeP=2.6M, kneeN=2.1M, safety=3.0M) — a
    touch earlier asymmetric clip, tighter ceiling so the section
    sounds simpler / cruder than TS9.
  - **BD-2** (driveK=6, kneeP=3.0M, kneeN=2.7M, safety=3.4M) — late
    knees with more headroom for a wider, picky, broader-band response.
  - **Jan Ray** (driveK=3, kneeP=3.2M, kneeN=3.0M, safety=3.4M) —
    transparent low-gain voicing: small driveK ceiling, near-symmetric
    soft clip, high headroom.
  - **OCD** (driveK=7, kneeP=2.3M, kneeN=1.9M, safety=3.5M) — highest
    driveK with the lowest knees so the clip stage saturates
    aggressively; the higher safety knee keeps the output dynamics.
  - **CENTAUR** (driveK=5, kneeP=2.8M, kneeN=2.6M, safety=3.4M) —
    smooth, gently asymmetric, midway between TS9 and BD-2; the high
    safety knee preserves the "dynamic clean blend" character without
    needing a separate dry-path stage.

- **Smoke / verification.**
  - `tests/test_overdrive_model_select.py` (new) covers byte-layout
    contracts (model ends up in `ctrlD[2:0]`, tight in `ctrlD[7:3]`,
    invalid model -> 0) and Python defaults / AppState round-trip.
  - `scripts/test_overdrive_models.py` (new) cycles each model on
    PYNQ with the PCM5102 output so the user can audibly compare.
  - Live verification on board: ADAU Line In -> AudioLab DSP ->
    PCM5102 line out; each model must produce an audibly distinct
    voicing while `gain` / `tone` / `level` continue to behave;
    every other section (Distortion / Amp / Cab / Reverb) must keep
    working unchanged.

## D47 — Replace short/long-press encoder actions with button-state edge controls

- **Why.** Field testing of Phase 7G+ on PYNQ-Z2 showed that the PL
  `axi_encoder_input` IP latches `short_press` / `long_press` /
  `click` reliably enough on the bench but inconsistently in the
  rack: certain detent + push combinations would either swallow the
  short press (rotate fired, latch never set) or echo it as a long
  press, which made encoder 0 ON/OFF and encoder 1 model-select
  feel unpredictable. The previous spec (`ENCODER_GUI_CONTROL_SPEC.md`
  Phase 7G mapping) leaned on those press classifications for safe
  bypass, model-select toggle, edit toggle, forced apply, and knob
  reset; any one of them mis-firing required a notebook intervention.
- **What changed.** `EncoderUiController` (audio_lab_pynq/encoder_ui.py)
  no longer treats `short_press` / `long_press` / `click` as command
  sources. The controller drops those event kinds. The only press-driven
  action is **Encoder 0 button-down rising edge** — detected by
  comparing the current debounced `BUTTON_STATE` against the previous
  poll's value. Hold does not auto-repeat, release does not toggle,
  and the first observation after construction seeds without emitting
  any edge. The runner reads `BUTTON_STATE` alongside each
  `EncoderInput.poll()` via the new `EncoderUiController.tick()`
  helper.
- **Per-encoder semantics (final).**
  - Encoder 0 rotate -> `selected_effect` += delta (wraps over EFFECTS).
  - Encoder 0 button-down edge -> toggle `effect_on[selected_effect]`
    and emit one `apply_effect_on_off` call. PRESET-like slots (any
    `EFFECTS` entry not present in `EFFECT_KNOBS`, or whose name
    contains "preset" / "safe bypass") are no-op.
  - Encoder 1 rotate, button released -> `selected_knob` += delta.
  - Encoder 1 rotate, button held -> cycle the model index for the
    selected effect (`overdrive_model_idx` / `dist_model_idx` /
    `amp_model_idx` / `cab_model_idx`). Non-model effects (Noise Sup
    / Compressor / EQ / Reverb) hold+rotate is a no-op.
  - Encoder 2 rotate -> selected knob value ±5 (clamped 0..100),
    throttled live apply.
  - Encoder 1 / Encoder 2 standalone button: no-op.
  - Encoder 0 / Encoder 2 button state does NOT influence Encoder 1
    dispatch (gating uses only `_current_pressed[1]`).
- **Removed actions.**
  - Encoder 0 long press safe-bypass round-trip.
  - Encoder 1 short press model_select_mode toggle.
  - Encoder 1 short press edit_mode toggle.
  - Encoder 1 long press model_select_mode clear.
  - Encoder 2 short press forced apply.
  - Encoder 2 long press knob reset.
  - `model_select_mode` as a persistent toggle. The field stays on
    `AppState` for the renderer hint and is set to the live
    `Encoder 1` button state on every poll so MODEL only lights up
    while the user is actively holding it.
- **Overdrive model select.** `overdrive_model_idx` stays the sole
  source for Overdrive model selection (D45 / D46). Hold+rotate on
  Overdrive must NOT touch `dist_model_idx`, and hold+rotate on
  Distortion must NOT touch `overdrive_model_idx`.
- **PRESET.** PRESET is not an effect and is intentionally not
  bypassable from the encoder. No new PRESET ON/OFF, no entry in
  `effect_on` / `fs_states`. The renderer's PRESET chip is mouse-only.
- **Surface.** Pure Python / docs change. No bit/hwh rebuild, no
  RTL/XDC change, no `block_design.tcl` edit, no Clash regenerate,
  no notebook touch (the user's notebook smoke path was unstable in
  the previous session and is intentionally left alone).
- **Smoke / verification.**
  - `tests/test_encoder_ui_controller.py` rewritten to the new spec
    (button-down edge, hold+rotate model select, short/long press
    no-op, PRESET guard, per-encoder isolation).
  - `tests.test_overdrive_model_select.test_encoder_overdrive_model_cycle_uses_dedicated_index`
    rewritten to drive hold+rotate via `set_button_state([F,T,F])`
    instead of `state.model_select_mode = True`.
  - On-board: `scripts/run_encoder_hdmi_gui.py` (direct script
    launch; notebook intentionally untouched).
- **SW polarity (bench rig).** The bench encoder modules on this rig
  report `SW=HIGH` when pressed, not low — opposite to the
  `ENCODER_GUI_CONTROL_SPEC.md` Phase 7B assumption and to the IP's
  RTL default (`sw_active_low=1`). With the RTL default, Encoder 1's
  `_current_pressed[1]` reads True at rest and False when held,
  inverting hold+rotate semantics. The runner now defaults to
  `sw_active_low=False` (CONFIG bit 16 cleared) so the live press
  state matches the physical button. The `--sw-active-low` /
  `--sw-active-high` CLI options remain for any future module with
  the opposite polarity; the default is active-high. Cold-start the
  PYNQ-Z2 after a deploy if the LCD shows white / black even with
  VTC + VDMA healthy (rgb2dvi PLL at the lower kClkRange=3 VCO edge
  fails to re-lock on a same-session `download=True` re-load —
  memory `rgb2dvi-pll-edge-at-40mhz`).

## D48 — Use Digilent Pmod I2S2 (CS4344 DAC + CS5343 ADC) as the PMOD JB external audio module; retire the PCM5102 / PCM1808 path

- **Why.** D45 (2026-05-18) committed the Pmod I2S2 paper plan and
  D48 (first attempt, 2026-05-19) added it as an opt-in build variant
  alongside the Phase 7D close-out PCM5102 / PCM1808 path. The
  variant-with-fallback structure proved fragile in practice: the
  shared `audio_lab.xdc` could not carry conditional pin
  constraints (Vivado 2019.1's XDC parser silently drops `if`
  blocks → `Designutils 20-1307` → IO placement infeasible), and
  the env-var switch added a class of "wrong bit on the wrong
  board" mistakes the user did not want. On the bench Pmod I2S2 is
  now the **only** external audio module attached to PMOD JB: the
  CS4344 DAC and CS5343 ADC share one PMOD with a common clock
  tree, the Line Out ↔ Line In analog jumper is in place for ADC
  validation, and PCM5102 / PCM1808 jumper wiring has been removed.
  This decision retires the PCM5102 / PCM1808 PMOD JB path and
  makes Pmod I2S2 the unconditional build choice.
- **Build flow.** `create_project.tcl` always
  - adds `audio_lab.xdc` (ADAU1761 + HDMI + encoder) +
    `audio_lab_pmod_i2s2.xdc` (the eight Pmod I2S2 ports) to
    `constrs_1`,
  - adds `hw/ip/encoder_input/src/axi_encoder_input.v` and
    `hw/ip/pmod_i2s2/src/{pmod_i2s2_master,axi_pmod_i2s2_status}.v`
    to `sources_1`,
  - sources `block_design.tcl` → `hdmi_integration.tcl` →
    `encoder_integration.tcl` → `pmod_i2s2_integration.tcl`.
  The Phase 7D close-out integration tcls
  (`pcm5102_dac_integration.tcl`, `pcm1808_adc_integration.tcl`)
  and the PCM5102 / PCM1808 RTL under `hw/ip/pcm5102_*` /
  `hw/ip/pcm1808_*` stay in the repo as **archival only**; they are
  no longer added to `sources_1` or sourced. `audio_lab_pcm.xdc`
  also stays as archival reference. No env var is needed any more.
- **RTL.** Two new self-contained Verilog modules under
  `hw/ip/pmod_i2s2/src/`:
  - `pmod_i2s2_master.v` — FPGA-master I2S engine. Takes 12.288 MHz
    from the existing `clk_wiz_audio_ext` MMCM (same math the Phase
    7C `pcm5102_dac_integration.tcl` used; the Pmod variant
    recreates the MMCM in its own integration tcl so PCM5102 /
    PCM1808 tcls are not needed). Generates BCLK=MCLK/4=3.072 MHz
    and LRCK=BCLK/64=48 kHz internally and **fans out one clock
    tree to both D/A pins (JB1/JB2/JB3) and A/D pins (JB7/JB8/JB9)**
    so the two sides are bit-true synchronous (the D40 / D41
    async-clocks problem cannot happen here, structurally). I2S
    Philips frame, 24-bit MSB-first in a 32-bit slot, LRCK low =
    LEFT. SDIN data source = either a 1 kHz quarter-scale sine ROM
    (`cfg_mode=0`, the same 48-sample table the PCM5102 tone module
    uses) or the just-captured ADC sample (`cfg_mode=1`, ADC → DAC
    direct loopback). SDOUT is sampled into a 2-FF synchronizer
    and shifted MSB-first into a 24-bit register; on slot completion
    the value latches into `rx_left_captured` / `rx_right_captured`.
    Status counters (`frame_count_o`, `nonzero_count_o`,
    `sdout_transition_count_o`, `clip_count_o`, `last_left_o`,
    `last_right_o`, `peak_abs_left_o`, `peak_abs_right_o`,
    `lrclk_seen_o`, `bclk_seen_o`, `sdout_alive_o`) live in the
    MCLK domain. `cfg_mode_i` is 2-FF-synchronized inside the
    master; `cfg_clear_toggle_i` is a toggle bit (any flip = 1
    MCLK-period CLEAR pulse) so the AXI ↔ MCLK clock-period
    mismatch cannot drop the request.
  - `axi_pmod_i2s2_status.v` — Tiny AXI4-Lite slave, same shape as
    `axi_encoder_input.v`. Registers at byte offsets:
    0x00 VERSION (0x00480001), 0x04 STATUS (lrclk/bclk/sdout flags +
    current mode), 0x08 FRAME_COUNT, 0x0C NONZERO_COUNT,
    0x10 SDOUT_XCOUNT, 0x14 CLIP_COUNT, 0x18 LAST_LEFT (signed
    sign-extended), 0x1C LAST_RIGHT, 0x20 PEAK_ABS_LEFT (unsigned
    24-bit), 0x24 PEAK_ABS_RIGHT, 0x28 MODE (R/W [1:0]), 0x2C CLEAR
    (W bit0 toggles the clear bit). The slave 2-FF-synchronizes every
    MCLK-domain status input before exposing it on AXI.
- **Block-design integration.** `hw/Pynq-Z2/pmod_i2s2_integration.tcl`
  (sourced unconditionally by `create_project.tcl`):
  - Instantiates `clk_wiz_audio_ext` with the exact same config
    (100 MHz → 12.288 MHz, MMCM, M_F=48, D=5, VCO=960 MHz,
    CLKOUT0_DIVIDE_F=78.125) that Phase 7C built; PCM5102 /
    PCM1808 scripts are not sourced in this variant, so the MMCM
    cannot be inherited from them.
  - Bumps `ps7_0_axi_periph/NUM_MI` from 18 → 19 to add M18 for the
    new status slave. M00..M16 + M17 (encoder, D32) are preserved.
  - Creates the eight new top-level ports
    `ext_pmod_i2s2_da_mclk_o / da_lrck_o / da_sclk_o / da_sdin_o /
    ad_mclk_o / ad_lrck_o / ad_sclk_o / ad_sdout_i` and binds them
    to `pmod_master_0`.
  - Wires `pmod_master_0`'s 11 status output buses to
    `pmod_status_0`'s matching status input buses (the slave does
    the CDC). Wires `pmod_status_0`'s `cfg_mode_o` /
    `cfg_clear_toggle_o` back to the master's control inputs.
  - Maps the status slave at **AXI-Lite 0x43D20000 / 0x10000**.
    The address sits one slot above the encoder (`0x43D10000`,
    D32) and below any future reservation. HDMI VDMA
    (`0x43CE0000`, D25) / VTC (`0x43CF0000`) and the reserved
    `0x43D00000` are not touched.
- **XDC.** `audio_lab_pmod_i2s2.xdc` carries the eight LVCMOS33
  entries for the Pmod I2S2 ports. `audio_lab.xdc` keeps only the
  universal constraints (ADAU1761 codec, HDMI TX, encoder pins).
  Pin map matches the official Digilent Pmod I2S2 PMOD pinout
  confirmed by D45 (PMOD_I2S2_INTEGRATION_PLAN.md section 10):
  - JB1 W14 → D/A MCLK (12.288 MHz)
  - JB2 Y14 → D/A LRCK (48 kHz)
  - JB3 T11 → D/A SCLK (3.072 MHz)
  - JB4 T10 → D/A SDIN (out)
  - JB7 V16 → A/D MCLK (12.288 MHz, fanout)
  - JB8 W16 → A/D LRCK (48 kHz, fanout)
  - JB9 V12 → A/D SCLK (3.072 MHz, fanout)
  - JB10 W13 → A/D SDOUT (in, only input pin)
- **Python smoke.** Two new scripts:
  - `scripts/test_pmod_i2s2.py` loads `AudioLabOverlay`, verifies
    the usual IPs (DMA / DSP GPIO / encoder / HDMI VDMA / VTC) are
    still present and that a `pmod_status` AXI-Lite block is
    mapped, then samples the status counters over a few seconds
    and prints PASS / WARN / FAIL.
  - `scripts/pmod_i2s2_capture_probe.py` polls the same status
    block on a `--interval` loop and prints a per-tick delta line
    so the user can correlate plugging the analog Line Out → Line
    In cable with the ADC counter movement.
- **Boundary (what this decision does NOT touch).**
  - `hw/Pynq-Z2/block_design.tcl` is not edited — every change goes
    through `pmod_i2s2_integration.tcl`.
  - `GPIO_CONTROL_MAP.md` (D12) is untouched; no new `axi_gpio`,
    no byte reassignment.
  - `LowPassFir.hs` / `topEntity` / Clash DSP pipeline are
    untouched.
  - HDMI (D24 / D25 / D26), encoder PL IP (D32 / D33 / D34 / D36 /
    D37 / D47), PCM5102 ADAU-mirror (D39 / D40), PCM1808 mux=ADAU
    fallback (D43), and ADAU1761 codec init (D1) are all
    untouched.
  - The compact-v2 GUI / notebooks / encoder runtime are not
    edited. The Pmod I2S2 status block is read-only from Python
    and only used by the two new smoke scripts.
  - No `git push` / `git pull` / `git fetch`. PMOD JA / Raspberry
    Pi header / Arduino header / sample rate (still 48 kHz) /
    mono DSP policy (D22) all unchanged.
- **Rollback.**
  - Branch-level: `git checkout main` returns to the Phase 7D
    close-out state (PCM5102 ADAU-mirror + PCM1808 mux fallback to
    ADAU). The `feature/pmod-i2s2-bringup` branch keeps the Pmod
    I2S2 commits for forward reference.
  - Bit-level: copy `hw/Pynq-Z2/bitstreams/audio_lab.bit` / `.hwh`
    from any earlier commit (e.g. `git show
    78ef562:hw/Pynq-Z2/bitstreams/audio_lab.bit > /tmp/old.bit`)
    or from the working-tree `audio_lab.baseline.bit` /
    `.baseline.hwh` if still present, then sync to the five PYNQ
    locations. Physical wiring also has to be reverted: remove
    Pmod I2S2 from PMOD JB and re-attach the PCM5102 / PCM1808
    jumpers.
  - File-level: the PCM5102 / PCM1808 integration tcls + RTL +
    `audio_lab_pcm.xdc` are intentionally left in the repo as
    archival reference. Re-enabling the Phase 7D path requires
    putting them back into `create_project.tcl` (`add_files` for
    the RTL, `source` for the two tcls, `add_files` for
    `audio_lab_pcm.xdc`) AND dropping the Pmod I2S2 references
    since they share PMOD JB pins.

### D48 follow-up (2026-05-20, branch `feature/pmod-i2s2-mode1-loopback`)

- **Mode 1 verified.** `pmod_i2s2_master.v` already implemented the
  ADC → DAC direct loopback at `cfg_mode == 2'd1` (echoes the
  just-captured `rx_left_captured` / `rx_right_captured` 24-bit
  sample straight back into the TX serializer, no DSP, no
  attenuation). The Python smoke
  (`scripts/test_pmod_i2s2.py --mode loopback --confirm-loopback`)
  flips the AXI-Lite MODE register, the master 2-FF-syncs it into
  the MCLK domain, and the next stereo frame already comes out of
  JB4 SDIN as a copy of JB10 SDOUT. The on-module Line Out ↔ Line
  In jumper plus the full-scale echo means the analog loop can
  feed back, so the script refuses `--mode loopback` unless
  `--confirm-loopback` is also passed.
- **Historical D48 follow-up only; superseded by D49.** In this
  branch, the Pmod I2S2 ADC was **not** wired into the AudioLab DSP
  chain because the user requested NOT to implement a
  "mode 2 = ADC → DSP → DAC" path yet. D49 later added that mode and
  made it the current active audio path.
- **AXI write FSM bug fix.** The original `axi_pmod_i2s2_status.v`
  write path used `axi_awaddr_q[5:2]` in the same `always @(posedge
  s_axi_aclk)` cycle that the assignment to `axi_awaddr_q`
  happened. Non-blocking semantics meant the WREADY case statement
  picked up the *previous* address, so back-to-back MMIO writes
  (e.g. `mmio.write(MODE, 0)` immediately followed by
  `mmio.write(CLEAR, 1)`) committed the CLEAR write at the MODE
  address and silently flipped `cfg_mode_o`. The fix is a proper
  AW-then-W FSM with a `write_in_progress` flag and an explicit
  `write_addr_lat` register, mirroring the `axi_encoder_input.v`
  pattern (which has been deployed on-board since D32 with no
  similar symptom). Bit / hwh were rebuilt (`audio_lab.bit`
  re-issued at md5 different from the previous Pmod I2S2 build);
  WNS / utilization deltas are negligible.
- **Smoke results (post-fix).** `scripts/test_pmod_i2s2.py
  --mode tone --clear --duration 5` reports MODE=0 after the
  CLEAR pulse (was incorrectly MODE=1 in the pre-fix build);
  frame_count rises at 48 kHz, peak_abs_left/right ~250k.
  `scripts/test_pmod_i2s2.py --mode loopback --confirm-loopback
  --clear --duration 3` reports MODE=1 and CLIP_COUNT=0 with the
  ADC seeing the just-emitted DAC sample.
- **Boundary (still untouched).** `block_design.tcl`,
  `GPIO_CONTROL_MAP`, `LowPassFir.hs`, `topEntity`, HDMI
  integration, encoder PL IP, compact-v2 GUI, notebooks, encoder
  runtime, and ADAU1761 codec init.

## D49 — Route Pmod I2S2 ADC/DAC through the existing AudioLab DSP chain (mode 2)

- **Why.** D48 brought up the Pmod I2S2 as a standalone audio
  module with two modes: internal 1 kHz tone + ADC probe
  (`cfg_mode = 0`) and ADC → DAC direct loopback (`cfg_mode = 1`).
  Neither uses the AudioLab DSP pipeline, so the practical bench
  workflow ("plug a guitar into Line In, hear Overdrive on Line
  Out") was not reachable. D49 closes that gap by adding
  `cfg_mode = 2` (ADC → DSP → DAC) without touching any existing
  GPIO byte, effect algorithm, or top-level interface.
- **Architecture (one clock tree, no CDC inside the I2S converter).**
  `pmod_i2s2_master.v` already generates `mclk_int` (12.288 MHz from
  `clk_wiz_audio_ext`), `bclk_int = mclk_int / 4 = 3.072 MHz`, and
  `lrck_int = bclk_int / 64 = 48 kHz` and fans them out to JB1/JB2/
  JB3 (D/A side) and JB7/JB8/JB9 (A/D side). D49 exposes these
  internal clocks as new module outputs (`dsp_bclk_o`,
  `dsp_lrck_o`) and a new module input `dsp_dac_sdin_i` for the
  bit-serial DSP output. `pmod_i2s2_integration.tcl` deletes the
  pre-existing `bclk_1` / `lrclk_1` / `sdata_i_1` block-design nets
  (which used to ferry ADAU1761 `bclk` R18 / `lrclk` T17 /
  `sdata_i` F17 to `i2s_to_stream_0`) and re-routes them onto the
  Pmod clock tree:
  - `pmod_master_0/dsp_bclk_o` → `i2s_to_stream_0/bclk` +
    `proc_sys_reset_0/slowest_sync_clk`.
  - `pmod_master_0/dsp_lrck_o` → `i2s_to_stream_0/lrclk`.
  - Top-level `ext_pmod_i2s2_ad_sdout_i` → `i2s_to_stream_0/si`
    (the same Pmod ADC SDOUT line that also feeds
    `pmod_master_0/ext_pmod_i2s2_ad_sdout_i` for the status
    counters).
  - `i2s_to_stream_0/so` keeps driving the legacy `sdata_o` G18
    pin AND now also drives `pmod_master_0/dsp_dac_sdin_i`. The
    DAC SDIN mux inside the master selects between the internal
    serializer (tone / ADC echo) and `dsp_dac_sdin_i` based on
    `cfg_mode`. No multi-driver: the JB4 SDIN pin only has one
    driver, the mux's combinational output.
  This shifts the entire `i2s_to_stream_0` block into the
  Pmod-MMCM-derived 3.072 MHz / 48 kHz clock domain. The
  downstream `axis_data_fifo_0` already handles the CDC from
  `i2s_to_stream_0`'s bclk domain to `clk_fpga_0` 100 MHz, exactly
  as before -- only the upstream clock source changed.
- **MODE register.** `cfg_mode` was already 2 bits.  D49 uses both
  bits, mapping the four values to:
  - `2'd0` = tone (default at reset; SDIN = internal sine ROM)
  - `2'd1` = loopback (SDIN = internal serializer with ADC echo)
  - `2'd2` = dsp (SDIN = `dsp_dac_sdin_i`, i.e. the DSP chain
    serial output)
  - `2'd3` = mute (SDIN = 0)
  The DAC SDIN mux is in the MCLK domain after a 2-FF synchronizer
  on `cfg_mode_i`. AXI-Lite VERSION stays `0x00480001`; STATUS bits
  `[9:8]` still carry the live `cfg_mode` so the smoke can confirm
  the write.
- **Python smoke.** `scripts/test_pmod_i2s2.py` extends
  `--mode` to accept `tone`/`loopback`/`dsp`/`mute` (and numeric
  `0`..`3`). Mode 2 requires the new `--confirm-dsp` flag with the
  same shape as `--confirm-loopback`: without it the script prints
  a strong warning ("PHYSICALLY DISCONNECT the on-module Line Out
  ↔ Line In jumper before engaging mode 2") and falls back to
  mode 0.
- **Boundary (what this decision does NOT change).**
  - `hw/Pynq-Z2/block_design.tcl` is not edited; the rewiring is
    all in `pmod_i2s2_integration.tcl` via `delete_bd_objs` +
    `connect_bd_net`, the same pattern `pcm1808_adc_integration.tcl`
    used in the retired Phase 7D path.
  - `GPIO_CONTROL_MAP.md` (D12) is untouched. No new AXI GPIO. No
    byte / ctrlA/B/C/D reassignment.
  - `LowPassFir.hs`, `topEntity`, the AXIS DSP chain
    (`axi_dma_0` / `axis_subset_converter_*` / `axis_switch_*` /
    `axis_data_fifo_0` / `clash_lowpass_fir_0`), the effect API,
    notebooks, compact-v2 GUI, encoder PL IP, encoder runtime,
    HDMI integration, and ADAU1761 codec init are all unchanged.
  - 48 kHz / 24-bit / mono DSP policy unchanged (D22).
  - ADAU1761 line-out is still a top-level port; it will receive
    a Pmod-clocked stream (visible only to a debug scope on G18),
    but it is NOT in the deployed audio path any more. ADAU input
    pin F17 is unloaded internally (the `sdata_i_1` net was
    deleted) but the codec stays alive via I2C config so
    `ADC HPF True` keeps reporting.
- **Smoke (post-deploy, see TIMING_AND_FPGA_NOTES.md for numbers).**
  - mode 0 regression: frame_count rises at 48 kHz, MODE = 0,
    peak_abs > 0 with the on-module Line Out → Line In jumper.
  - mode 1 regression: requires `--confirm-loopback`; MODE = 1,
    CLIP_COUNT = 0.
  - mode 2: requires `--confirm-dsp`; Line In external source →
    Line Out audible; Overdrive / Distortion / Reverb effects
    audibly change the output via the existing AudioLab API
    (`AudioLabOverlay.set_guitar_effects(...)`).
- **Rollback.**
  - Branch-level: `git checkout main^` (before this commit) returns
    to the D48 follow-up state where mode 2 does not exist and
    `i2s_to_stream_0` is driven by ADAU bclk.
  - Bit-level: redeploy any earlier `audio_lab.bit` / `.hwh` from
    `git log` and resync the five PYNQ locations.
  - Mode-level: writing `2'd3` (mute) to MODE silences the Pmod DAC
    without rebuilding; useful while debugging the DSP chain.

## D50 — Mode 2 RIGHT-to-LEFT mirror in `pmod_i2s2_master.v` (work around the i2s_to_stream IP LEFT-extraction + 1-BCLK setup bugs)
- **Context.** After D49 deployed `cfg_mode = 2'd2` (Pmod ADC → AudioLab
  DSP chain → Pmod DAC) the user reported that the chain sounded
  "slightly distorted" even with every effect off. A diagnostic capture
  via `scripts/diagnose_pmod_i2s2_dma_capture.py` (DMA from
  `axis_switch_sink/M01` while the mode 2 path is otherwise live)
  confirmed two issues inside the existing `i2s_to_stream` IP:
  1. The IP's `i2sIn` LEFT extraction did not match the Pmod-master's
     own deserializer. DMA-captured LEFT regularly hit `-0 dBFS` peaks
     and held a large DC offset while Pmod-master `peak_abs_left` for
     the same SDOUT bits stayed near `-7 dBFS`. RIGHT extraction
     matched the Pmod-master exactly (delta = 0 across multiple
     captures). Bit-prevalence histograms showed LEFT bits 16..21
     set roughly **half** as often as RIGHT, isolating the bug to
     the IP's LEFT slot extraction.
  2. The IP's `i2sOut` updates `so` on BCLK rising edges -- the same
     edge the CS4344 DAC samples on. Without a half-BCLK setup margin
     the DAC can latch the OLD bit and play a 1-BCLK-shifted bit
     stream that sounds like asymmetric distortion. This was likely
     masked on the legacy ADAU codec setup where the codec drove the
     bclk and any race resolved in its favour, but it surfaces on the
     Pmod-as-slave configuration.
- **Decision.** Add a Verilog-only RIGHT-to-LEFT mirror inside
  `pmod_i2s2_master.v` so that in mode 2 the DAC SDIN comes from a
  Pmod-master-internal 32-bit buffer instead of the IP's live `so`:
  1. `mode2_right_snapshot[31:0]` -- a 32-bit register indexed by
     `slot_idx` (`bit_idx[4:0]`). It captures `dsp_dac_sdin_i` on
     `bclk_fall_pre` whenever `bit_idx[5] == 1` (RIGHT slot). At
     that MCLK posedge `dsp_dac_sdin_i` is the IP's post-rising
     `so` value, so the bit is the IP's intended payload for the
     just-finished BCLK period (not the pre-edge stale value the
     DAC would otherwise see).
  2. The mode 2 branch of the DAC SDIN mux drives
     `mode2_right_snapshot[bit_idx[4:0]]` regardless of LEFT or
     RIGHT slot. As a result both ears get the previous frame's
     RIGHT slot bits with the same one-frame (~21 us) delay --
     the user hears clean mono.
  - Mode 0 / 1 / 3 paths in `pmod_i2s2_master.v` are unchanged.
  - The Clash DSP chain still receives the IP's `axis_li_tdata`
    LEFT/RIGHT (LEFT is still corrupt at the chain input, but the
    chain output is only audible via the RIGHT slot bits, so the
    LEFT corruption never reaches the listener).
- **What this is NOT.**
  - Not a fix to the IP. The IP's `i2sIn` / `i2sOut` are unchanged;
    we work around them. The user-confirmed test plan covers mode 2
    clean + Overdrive A/B and is sufficient for the current PMOD
    audio scope; revisiting the IP itself is deferred.
  - Not a stereo restoration. True stereo through the DSP chain is
    lost in mode 2 -- both ears carry the chain's RIGHT output.
- **Scope guard.** No `block_design.tcl` edit. No new GPIO. No new
  `topEntity` / `LowPassFir.hs` port or coefficient change. No new
  Clash work. No notebook UI change. No PCM5102 / PCM1808 revival.
- **Smoke (post-deploy, branch `feature/pmod-i2s2-dsp-clean-fix`).**
  - mode 1 regression: `--mode loopback --confirm-loopback` reports
    MODE=1, CLIP_COUNT=0, frame_count rising at 48 kHz exactly,
    peak_abs_left/right > 0 (external source ~ -6 dBFS).
  - mode 2 clean (effects all off, `scripts/diagnose_pmod_i2s2_dsp_clean.py
    --duration 15`): MODE=2, frame delta `+720,720` / 15 s, CLIP_COUNT=0,
    peak_abs_left/right ~ `-13.6` / `-11.9 dBFS`. **User-confirmed
    "mode 1 と同じくクリーン" (clean, matches mode 1).**
  - mode 2 A/B with Overdrive (`--ab-overdrive` 6 s each): Phase A
    clean, Phase B `set_guitar_effects(overdrive_on=True, ...)`
    audibly engages overdrive, Phase C `overdrive_on=False` returns
    to clean. **User-confirmed "ON で歪んで、OFF でクリーンに戻った"**.
  - mode 3 (mute): MODE=3, DAC silent.
- **Timing.** WNS `-7.985 ns` (TNS `-8737.608 ns`, WHS `+0.050 ns`,
  THS `0 ns`). Inside the historical `-7..-9 ns` deploy band and
  improves the previous D49 deployed baseline (`-8.521 ns`) by
  `0.536 ns`. The mode2 buffer is a single 32-bit register; adds
  ~32 FFs, no DSP, no BRAM.
- **Rollback.**
  - Branch-level: `git checkout main` returns to the D49 state
    (mode 2 routes the IP's live `so` to the DAC directly; LEFT
    extraction bug and 1-BCLK race re-appear).
  - File-level: revert the `pmod_i2s2_master.v` edit that adds
    `mode2_right_snapshot` and switches the mode 2 mux to use it.
  - Mode-level: writing `2'd1` (loopback) keeps the IP out of
    the audio path entirely; mode `2'd3` (mute) silences the DAC
    without rebuilding.

## D51 — Encoder 0 short_press HW latch fallback + poll/render uplift (sluggish-GUI fix)

- **Date.** 2026-05-20.
- **Why.** Bench feedback after the D47 / D50 series: the GUI felt
  sluggish under sustained encoder use, and Encoder 0 short taps
  ("拾い損ね") were frequently missed. Root causes:
  1. `EncoderUiController` (D47) dispatched Encoder 0 ON/OFF only on
     the `BUTTON_STATE` level rising edge. Polled at 10 Hz active /
     4 Hz idle, any tap shorter than the poll period (≤100 ms active,
     ≤250 ms idle) slipped between two polls — the rising edge never
     reached the controller. The HW `short_press` latch on the IP was
     reliably set in that window but `handle_event` dropped every
     `event.kind != "rotate"`, so the latch was thrown away.
  2. The dirty-flag render loop was capped at 5 fps (200 ms) with a
     100 ms apply throttle. Even when events were detected, the
     visible feedback lagged enough to feel "もっさり".
- **What changed (pure Python, no RTL / bit / hwh / Tcl edit).**
  - `audio_lab_pynq/encoder_ui.py`:
    - `handle_event` now consumes a `short_press` event for Encoder 0
      as the same toggle that the level-edge path produces, then sets
      a tick-local `_enc0_toggle_consumed_this_tick` flag.
    - `process_button_state` checks that flag before firing the level
      rising-edge toggle, so a tap that triggered both paths in the
      same tick only toggles once.
    - `tick()` resets the flag at the top of each iteration.
    - Encoder 1 / Encoder 2 `short_press` / every `long_press` /
      `click` event remain dropped (the D47 invariant is preserved).
  - `scripts/run_encoder_hdmi_gui.py` defaults:
    - `--poll-hz-active 10 → 30`, `--poll-hz-idle 4 → 10`,
      `--max-render-fps 5 → 20`, `--apply-interval-ms 100 → 50`.
    - `--poll-hz-idle 10` keeps the idle period (100 ms) at or below
      the short_press latch detection window so brief taps after an
      idle stretch are still caught.
  - `audio_lab_pynq/notebooks/EncoderGuiSmoke.ipynb`:
    - `POLL_HZ_ACTIVE 10 → 30`, `POLL_HZ_IDLE 4 → 10`,
      `MAX_RENDER_FPS 5 → 20`, `APPLY_INTERVAL_MS 100 → 50`.
    - Loop body replaced `enc.poll() + controller.handle_events(events)`
      with `controller.tick(enc, timestamp=...)` so the notebook now
      shares the same press / button_state path as the standalone
      runner (level-edge + short_press fallback both fire). Comment
      header rewritten to the D47 / D51 mapping (the old text still
      referenced the pre-D47 short/long-press spec).
  - `tests/test_encoder_ui_controller.py`:
    - `test_enc0_short_press_event_is_noop` replaced with
      `test_enc0_short_press_event_toggles_current_effect` and a new
      `test_enc0_short_press_and_level_edge_in_same_tick_toggles_once`
      that pins the no-double-toggle invariant.
    - `test_short_long_press_events_never_trigger_overlay_writes`
      now asserts the guard for every (kind, encoder_id) **except**
      Encoder 0 short_press, which is the new sanctioned trigger.
  - `CLAUDE.md` Rotary-encoder runtime bullet updated with the new
    throttle / poll / render numbers and the short_press fallback
    rule.
- **Per-encoder semantics (delta vs D47).**
  - Encoder 0 button toggle now fires on **either** the BUTTON_STATE
    rising edge **or** a HW `short_press` event consumed inside the
    same `tick()`. Whichever is observed first wins; the second is
    suppressed by the consumed flag.
  - Long press, release, and Encoder 1 / Encoder 2 button events stay
    no-ops. The D47 "hold does not auto-repeat, release does not
    toggle" invariant is preserved.
- **Scope guard.**
  - No change to the encoder PL IP, no new GPIO, no
    `block_design.tcl` / Tcl integration / XDC / Clash / Vivado /
    bit / hwh edit. No HDMI signal change. No effect-defaults change.
  - The applier (`EncoderEffectApplier`) is untouched; the throttle
    parameter still defaults to 50 ms via the runner / notebook
    constants. RAT skip behaviour is preserved.
  - The `HdmiEffectStateMirror` API and notebooks that drive the
    overlay directly (e.g. the Pmod I2S2 one-cell control) are
    untouched.
- **Test.**
  - `python3 tests/test_encoder_ui_controller.py` → 32 / 32 PASS
    (includes the two new D51 tests). Adjacent suites
    `tests/test_encoder_effect_apply.py`,
    `tests/test_encoder_input_decode.py`,
    `tests/test_compact_v2_encoder_state.py` all PASS.
- **Bench verification (pending).** User to run
  `scripts/run_encoder_hdmi_gui.py --live-apply --skip-rat` on the
  PYNQ-Z2 and confirm (a) short taps on Encoder 0 are no longer
  missed during continuous knob editing, (b) knob movement on
  Encoder 2 produces visible response within ~50 ms, (c) idle
  proc_cpu remains low (the idle poll rate trebled, so a small
  rise is expected; previously ~0–1 %).
- **Rollback.** Revert the four edits (`encoder_ui.py`,
  `run_encoder_hdmi_gui.py`, `EncoderGuiSmoke.ipynb`, test file)
  and restore the D47 numbers in `CLAUDE.md`. No bit / hwh
  involved.

## D52 — Pmod I2S2 HDMI GUI one-cell Notebook (encoder-driven mode-2 audio)
- **Goal.** A single Jupyter cell that brings up the rotary encoder
  + HDMI GUI runtime on top of the Pmod I2S2 mode-2 audio path
  (Pmod Line In → ADC → AudioLab DSP → DAC → Pmod Line Out) without
  duplicating the existing GUI / runner code inside the Notebook
  and without forcing the Notebook kernel to re-download
  `audio_lab.bit` or re-init the ADAU1761 codec.
- **Why.** D49 added the mode-2 audio routing and
  `PmodI2S2EffectControlOneCell.ipynb` exposes the effect API via
  ipywidgets, but the rotary encoders / compact-v2 HDMI GUI were
  only reachable through `scripts/run_encoder_hdmi_gui.py` (and the
  ADAU-driven `EncoderGuiSmoke.ipynb`). Drum-machine-style bench
  use wants "HDMI GUI + encoders on the Pmod I2S2 audio path" in
  one click, with a Panic button.
- **Shape.**
  - `scripts/run_encoder_hdmi_gui.py` gains one option
    `--pmod-mode {keep,tone,loopback,dsp,mute}` (default `keep`,
    i.e. preserves the prior behaviour exactly). When non-keep, the
    runner writes `pmod_status_0` MODE at startup, and writes MODE=3
    (mute) in the `finally` block at shutdown so SIGTERM / Ctrl+C
    silences the Pmod DAC.
  - New helper `scripts/pmod_i2s2_mode.py` (`--mode … | --read |
    --clear`, optional `--confirm-loopback`) attaches with
    `pynq.Overlay(<bit>, download=False)` (raw `pynq.Overlay`, NOT
    `AudioLabOverlay`) so the helper does not run
    `codec.config_pll()` / `config_codec()` and cannot disturb the
    live DSP. Falls back to the documented physical address
    `0x43D20000` if `ip_dict` lookup fails. Refuses to touch /dev/mem
    unless `pynq.PL.bitfile_name` already points at `audio_lab.bit`.
  - New Notebook
    `audio_lab_pynq/notebooks/PmodI2S2HdmiGuiOneCell.ipynb` (single
    code cell, no markdown cells) builds an ipywidgets toolbar
    (Start / Stop / Panic-Mute / Set Pmod mode 2 DSP / Refresh Pmod
    status / Show command) plus a runner-log `Output` widget and a
    `pmod_status` snapshot panel. It spawns the runner as
    `sudo env PYTHONPATH=$PROJECT_ROOT python3 -u
    scripts/run_encoder_hdmi_gui.py --live-apply --skip-rat
    --pmod-mode dsp` via `subprocess.Popen` with `preexec_fn =
    os.setsid` so Stop / Panic can `os.killpg(SIGTERM, pgid)` and
    drag the whole runner process group down. A daemon reader
    thread streams the runner's stdout/stderr into the log
    `Output`. Set DSP / Refresh / Panic-fallback shell out to
    `scripts/pmod_i2s2_mode.py`; the Notebook itself never imports
    `pynq` or `AudioLabOverlay`, so the
    `pynq-mmio-before-overlay-kills-kernel` foot-gun is avoided
    entirely. The cell auto-starts the runner on execution so
    "open + Run all" is the only required step.
- **Hardware safety.** Notebook header and the `Refresh Pmod
  status` panel both restate the mode-2 wiring contract: disconnect
  the on-module Line Out ↔ Line In jumper, external source on Line
  In at LOW level, Line Out into a separate audio interface. The
  runner's startup banner and `--pmod-mode dsp` write are visible
  in the runner log; Panic-Mute SIGTERMs the runner, the runner's
  `finally` writes MODE=3, the LCD goes dark when the HDMI backend
  stops.
- **Scope guard.**
  - No RTL change, no Tcl change, no XDC change, no
    `block_design.tcl` change, no bit / hwh rebuild, no
    `LowPassFir.hs` / `topEntity` / `GPIO_CONTROL_MAP` change.
  - The default behaviour of every existing runner invocation
    (i.e. without `--pmod-mode`) is byte-identical to the D51
    state. Existing notebooks
    (`EncoderGuiSmoke.ipynb`, `HdmiGuiShow.ipynb`,
    `PmodI2S2EffectControlOneCell.ipynb`, …) are untouched.
  - The runner's Pmod write goes through the same ip_dict-lookup
    pattern that `scripts/test_pmod_i2s2.py` and
    `PmodI2S2EffectControlOneCell.ipynb` use; failure is logged
    but never aborts the GUI loop.
- **Test.** `python3 -m py_compile` PASS for the runner and the
  new helper script. `python3 -c "import ast, json;
  ast.parse(''.join(json.load(open(<notebook>))['cells'][0]['source']))"`
  PASS for the new Notebook source. Bench verification on the
  PYNQ-Z2 (running the cell, confirming HDMI GUI + encoder ops,
  Pmod Line Out audible, Panic-Mute silences) is pending.
- **Rollback.** Delete
  `audio_lab_pynq/notebooks/PmodI2S2HdmiGuiOneCell.ipynb` and
  `scripts/pmod_i2s2_mode.py`, revert the
  `scripts/run_encoder_hdmi_gui.py` diff (the option block, the
  `_find_pmod_status_mmio` / `_write_pmod_mode` helpers, the two
  call sites in `main`), and revert the doc additions in
  `CLAUDE.md`, `docs/ai_context/PYNQ_RUNTIME.md`,
  `docs/ai_context/AUDIO_SIGNAL_PATH.md`,
  `docs/ai_context/RESUME_PROMPTS.md`,
  `docs/ai_context/CURRENT_STATE.md`. No bit / hwh involved.

## D53 — Replace Amp Sim character knob with model-only voicing and binary drive mode

- **Date.** 2026-05-21.
- **Status.** Implemented, Python-only (no Vivado / Clash / bit /
  hwh change). Bench verification on the PYNQ-Z2 (Encoder 1 hold +
  rotate cycles amp models, Encoder 2 on AMP slot 7 toggles 0/1,
  Pmod I2S2 mode 2 audible difference between drive_mode=0 and
  drive_mode=1) pending.
- **Context.** Amp Sim shipped an 8th continuous knob `CHAR` (the
  Clash side reads `ctrlD(fAmpTone)` as an 8-bit character byte
  with `ampModelSel` quantising into four bands at 63 / 126 / 190).
  The user-facing voicing was therefore controlled by two knobs at
  once: the `Amp Model` dropdown (which sets the band centre via
  `AMP_MODELS`) **and** the `CHAR` slider (free to walk the byte
  away from the labelled centre). That made the labelled voicings
  ambiguous and forced the encoder runtime to expose a continuous
  byte for what is conceptually a 0/1 switch.
- **Decision.** Replace the Amp Sim CHAR knob with a binary
  `DRV MODE` (0 / 1):
  - Amp character is now derived from `amp_model_idx` only. The
    Python helper
    `AudioLabOverlay.amp_character_byte_for_model(idx, drive_mode)`
    picks the model-centre byte (`AMP_MODEL_CHARACTER_BYTES =
    (26, 89, 153, 216)` for jc_clean / clean_combo /
    british_crunch / high_gain_stack) and, when `drive_mode=1`,
    shifts the byte by `AMP_DRIVE_MODE_OFFSET = 30`. Every result
    stays inside the same Clash `ampModelSel` band so the model
    identity is preserved across drive modes.
  - `drive_mode=0` produces the byte the previous percent-only
    path produced for each labelled model -- existing bitstreams
    are bit-for-bit compatible.
  - `drive_mode=1` lowers `ampAsymClip`'s positive / negative
    knees (more clipping), raises `ampSecondStageMultiplyFrame`
    gain by `(character >> 2) / 9`, and darkens
    `ampPreLowpassFrame`'s `baseAlpha = 128 + (character >> 2)`
    -- a "more drive / more darkened" voicing nudge with no
    volume-only effect.
  - The 8th Amp Sim knob is now binary (`is_binary_knob("Amp Sim",
    7) == True`), value clamped to {0.0, 1.0}; mirrored into
    `AppState.amp_drive_mode` so the encoder applier and Notebook
    UIs can read a single canonical 0/1.
  - Encoder 2 on the DRV MODE slot snaps to 0/1 via delta sign
    (positive -> 1, negative -> 0) and forces a live apply on
    every toggle (no value_step accumulation).
  - HDMI GUI renderer special-cases binary knobs: integer 0/1 in
    the value readout instead of the percent integer, and full
    bar segments lit at value=1.
  - Notebook UIs (`PmodI2S2EffectControlOneCell.ipynb`,
    `GuitarPedalboardOneCell.ipynb`) drop the Character slider and
    expose `amp_drive_mode` as a 0/1 Dropdown; `safe_clean` /
    `panic_mute` / `all_effects_off` set `amp_drive_mode=0`.
- **Encoding (no new GPIO).**
  - `axi_gpio_amp_tone.ctrlD` continues to carry the 8-bit
    character byte. No address change. No `block_design.tcl`
    change. No new AXI GPIO.
  - In-band shift instead of bit-pack: `ctrlD = AMP_MODEL_CHARACTER_BYTES[idx]
    + (drive_mode * 30)`. Values land at:
    - `(0, 0)` -> 26, `(0, 1)` -> 56 (both <63, band M0)
    - `(1, 0)` -> 89, `(1, 1)` -> 119 (both <126, band M1)
    - `(2, 0)` -> 153, `(2, 1)` -> 183 (both <190, band M2)
    - `(3, 0)` -> 216, `(3, 1)` -> 246 (both >=190, band M3)
  - The user-recommended encoding ("`ctrlD[6:0]` = character,
    `ctrlD[7]` = drive_mode") was rejected: the existing model
    centre bytes 153 and 216 already have bit 7 set, so a
    bit-7-only drive-mode would corrupt M2 / M3 character bands
    unless the Clash side was rewritten to mask `ctrlD & 0x7F`
    -- which is a Vivado rebuild that the task explicitly avoided
    when an alternative encoding exists. CLAUDE.md mandates a
    WNS-summary review on any `LowPassFir.hs` edit, so the
    in-band shift was preferred per the user's own
    "既存設計を優先 / docsに採用理由を書く" escape clause.
- **API impact.**
  - `AudioLabOverlay.guitar_effect_control_words` gains
    `amp_model_idx=None, amp_drive_mode=0` kwargs. When
    `amp_model_idx` is supplied the new path wins over the
    legacy `amp_character` percent; otherwise the legacy path
    is preserved bit-for-bit.
  - `AudioLabOverlay.set_guitar_effects` accepts both new kwargs
    transparently through `**kwargs`.
  - `EncoderEffectApplier.apply_appstate` stops passing
    `amp_character`; it forwards `amp_model_idx` +
    `amp_drive_mode` derived from
    `AppState.amp_model_idx` and the binary value at
    `AppState.all_knob_values["Amp Sim"][7]` (with
    `AppState.amp_drive_mode` as the canonical store).
  - `HdmiEffectStateMirror._apply_guitar_effects_state` mirrors
    the new `amp_drive_mode` kwarg into `AppState.amp_drive_mode`
    and slot 7 of the AMP knob list. `set_amp_model` defaults
    `drive_mode` to the current `AppState.amp_drive_mode`.
- **Files changed.**
  - `GUI/compact_v2/knobs.py` (`Amp Sim` slot 7 CHAR -> DRV MODE,
    new `BINARY_KNOBS` / `is_binary_knob` helpers).
  - `GUI/compact_v2/state.py` (`amp_drive_mode` AppState field,
    binary `set_knob` clamp, legacy state.json migration).
  - `GUI/compact_v2/renderer.py` (binary-knob display: 0/1
    integer + full bar segments at value 1).
  - `audio_lab_pynq/encoder_ui.py` (delta-sign 0/1 toggle on
    binary knobs, force live apply on toggle).
  - `audio_lab_pynq/encoder_effect_apply.py` (forward
    `amp_model_idx` + `amp_drive_mode`; never `amp_character`).
  - `audio_lab_pynq/AudioLabOverlay.py`
    (`AMP_MODEL_CHARACTER_BYTES`, `AMP_DRIVE_MODE_OFFSET`,
    `amp_character_byte_for_model`,
    `guitar_effect_control_words` model-first path).
  - `audio_lab_pynq/hdmi_state/knobs.py` (`AMP SIM` knob 7
    label -> DRV MODE, default 0).
  - `audio_lab_pynq/hdmi_effect_state_mirror.py` (mirror
    `amp_drive_mode` into AppState; drop `amp_character` mapping
    from the AMP SIM knob updates).
  - `audio_lab_pynq/notebooks/PmodI2S2EffectControlOneCell.ipynb`
    (new `amp_drive_mode` state key + Dropdown widget;
    `amp_character` no longer forwarded).
  - `audio_lab_pynq/notebooks/GuitarPedalboardOneCell.ipynb`
    (drop Character slider; replace with DRV MODE Dropdown).
  - `docs/ai_context/GPIO_CONTROL_MAP.md` (note that
    `axi_gpio_amp_tone.ctrlD` is now model-derived + drive-mode
    shifted, not a user-facing percent).
  - `tests/test_overlay_controls.py`,
    `tests/test_encoder_effect_apply.py`,
    `tests/test_encoder_ui_controller.py`,
    `tests/test_compact_v2_encoder_state.py` (new D53 tests).
- **Backward compatibility.**
  - Older chain presets and legacy Notebooks that still pass
    `amp_character=<percent>` via `set_guitar_effects` keep
    working byte-for-byte (the new model-first path is opt-in
    via `amp_model_idx`).
  - Older `fx_gui_state.json` files that stored a continuous
    CHAR percent at slot 7 of Amp Sim are migrated on load: the
    value is snapped to 0 / 1 based on the >=50% threshold and
    mirrored into `amp_drive_mode`. Values are clamped before
    the renderer ever sees them, so a stale character byte
    cannot resurface.
  - The legacy single-character `amp_character` knob still
    exists in the overlay public API (and inside
    `AudioLabOverlay.set_amp_model`); only the GUI / encoder
    runtime stopped exposing it.
- **Tests.** `python3 -m py_compile` PASS for every edited Python
  module. `python3 -m unittest -v` PASS for
  `tests.test_encoder_input_decode`, `tests.test_encoder_ui_controller`,
  `tests.test_compact_v2_encoder_state`, `tests.test_encoder_effect_apply`,
  `tests.test_overdrive_model_select` (87 tests, 0 failures).
  `python3 tests/test_overlay_controls.py` PASS. Notebook JSON
  validation (`ast.parse(''.join(cell['source']))`) PASS for the
  two edited one-cell notebooks. The pre-existing
  `tests.test_hdmi_origin_mapping` import error is unrelated
  (confirmed against main).
- **Rollback.** Revert the `Amp Sim` slot 7 edit in
  `GUI/compact_v2/knobs.py` (DRV MODE -> CHAR), delete the
  `BINARY_KNOBS` constant, drop `AppState.amp_drive_mode` +
  the legacy migration in `GUI/compact_v2/state.py`, undo the
  binary branch in `GUI/compact_v2/renderer.py` and
  `audio_lab_pynq/encoder_ui.py`, revert
  `AudioLabOverlay.amp_character_byte_for_model` /
  `AMP_MODEL_CHARACTER_BYTES` /
  `AMP_DRIVE_MODE_OFFSET` and the `amp_model_idx` /
  `amp_drive_mode` parameters of
  `guitar_effect_control_words`, restore
  `amp_character=_clamp_percent(amp[7])` in the encoder applier,
  revert the notebooks and the GPIO map note, and drop the new
  tests. No Vivado / bit / hwh involved.

## D54 — Amp Sim Clean/Drive becomes a real Clash DSP branch (retires D53 character shift)

- **Date.** 2026-05-21.
- **Status.** Implemented end-to-end: Clash + VHDL regenerated, Vivado batch build run, deployed to PYNQ-Z2. Bench A/B (Clean vs Drive audibly distinct under the same amp model, clip_count stays bounded) pending the next session.
- **Context.** D53 introduced an Amp Sim `DRV MODE` 0/1 binary knob and replaced the user-facing continuous CHAR knob with a model-only character byte derived from `amp_model_idx`. To avoid a Vivado rebuild, D53 simulated "drive" by shifting the same character byte by `+30` within the Clash `ampModelSel` band. That fakes a drive effect by re-using existing character-driven branches (clip knees, alpha, second-stage gain) but the Clash side has no separate Clean/Drive concept: the byte alone decides everything, and "more drive" is indistinguishable from "different character within the same model". The user flagged this and asked for the in-band shift to be retired in favour of a real DSP branch.
- **Decision.**
  - **`axi_gpio_amp_tone.ctrlD` is re-defined as a two-field bit-pack.**
    - `ctrlD[1:0]` = `ampModelIdx` (0..3 = jc_clean / clean_combo / british_crunch / high_gain_stack).
    - `ctrlD[7]` = `ampDriveMode` (0 = Clean, 1 = Drive).
    - `ctrlD[6:2]` is reserved; the Python writer always sets it to 0 and the Clash side ignores it.
    - Python composer: `AudioLabOverlay.amp_model_drive_byte(amp_model_idx, amp_drive_mode) = ((mode & 1) << 7) | (idx & 0x03)`. `amp_character_byte_for_model` is preserved as a thin alias so the D53 helper name keeps working.
  - **Clash `Amp.hs` decodes the two fields independently and adds real Drive-mode DSP branches.**
    - `ampModelIdxF f = unpack (slice d25 d24 (fAmpTone f))`.
    - `ampDriveModeF f = slice d31 d31 (fAmpTone f) == (1 :: BitVector 1)`.
    - `ampCharForModel idx` returns the four legacy D52 band centres (26, 89, 153, 216) so every character-driven branch keeps its identity for Clean mode.
    - `ampAsymClip intensity drive x` shrinks the positive knee by an extra `ch * 2_000` and the negative knee by `ch * 1_800` in Drive mode (linear in the per-model `intensity` byte so high-gain models cut deeper); the negative-side post-knee shift drops from `>> 3` to `>> 2`, sharpening the clip plateau.
    - `ampPreLowpassFrame` subtracts `12` from the LPF alpha when `drive` is set, on top of the per-model darken `0 / 4 / 12 / 24`, absorbing the new clipper's high-frequency content so Drive mode does not just brighten.
    - `ampSecondStageMultiplyFrame` adds `+24` to the Q7-style second-stage gain coefficient in Drive mode, pushing more signal into the second clipper instead of just lifting output level.
    - `ampWaveshapeFrame`, `ampSecondStageFrame`, `ampPreLowpassFrame`, `ampToneProductsFrame`, `ampResPresenceProductsFrame` now derive `character` from `ampModelIdx` directly; the old `ampModelSel :: Unsigned 8 -> Unsigned 2` quantiser is removed (the model is now an explicit 2-bit field).
    - `ampMasterFrame`, `ampPowerFrame`, `ampResPresenceMixFrame` unchanged: the post-amp safety stages still cap the chain output (`softClipK 3_300_000` / `3_400_000`) so the harder Drive-mode clip cannot run `clip_count` away.
  - **The D53 in-band byte shift is retired.** `AMP_DRIVE_MODE_OFFSET` stays defined as `0` for back-compat (external code that imports it sees a safe no-op rather than `AttributeError`), and `amp_character_byte_for_model` now returns the D54 bit-pack byte. The `AMP_MODEL_CHARACTER_BYTES` tuple is preserved as documentation of the four band centres but no longer participates in ctrlD composition.
  - **No new GPIO, no address change, no `block_design.tcl` change.** Only `Amp.hs` and `AudioLabOverlay.py` change.
- **Backward compatibility.**
  - Older notebooks / chain presets that call `set_guitar_effects(amp_character=<percent>)` without an `amp_model_idx` keep using the legacy percent path (`_percent_to_u8(amp_character, 255)`), so their existing voicing bytes pass through unchanged. The Clash side then interprets that byte as a bit-pack; the four labelled percents (10 / 35 / 60 / 85) map to bytes 26 / 89 / 153 / 216, whose low 2 bits collide with the D54 model field. This is an acceptable regression for legacy callers: they were already coupled to specific character bytes, and the user-facing path now goes through `amp_model_idx`.
  - The compact-v2 GUI, encoder runtime, HDMI mirror, and the two D53-edited Notebooks (`PmodI2S2EffectControlOneCell.ipynb`, `GuitarPedalboardOneCell.ipynb`) all already pass `amp_model_idx + amp_drive_mode` after D53. No GUI / encoder / notebook edits were needed for D54 beyond the overlay byte change.
- **Files changed.**
  - `hw/ip/clash/src/AudioLab/Effects/Amp.hs` (new `ampModelIdxF` / `ampDriveModeF` / `ampCharForModel`; `ampAsymClip` takes a `drive :: Bool`; `ampPreLowpassFrame` adds drive darken; `ampSecondStageMultiplyFrame` adds drive gain bonus; `ampTrebleGain` signature changed from `Unsigned 8 -> Unsigned 8 -> Unsigned 8` to `Unsigned 2 -> Unsigned 8 -> Unsigned 8`; legacy `ampModelSel` byte quantiser removed).
  - `hw/ip/clash/vhdl/LowPassFir/` regenerated by Clash + `create_ip.tcl`.
  - `hw/Pynq-Z2/bitstreams/audio_lab.bit` + `audio_lab.hwh` rebuilt by Vivado batch.
  - `audio_lab_pynq/AudioLabOverlay.py` (`amp_model_drive_byte` helper, `AMP_MODEL_IDX_MASK` / `AMP_DRIVE_MODE_BIT` constants, `guitar_effect_control_words` uses the new helper when `amp_model_idx` is supplied).
  - `docs/ai_context/GPIO_CONTROL_MAP.md` (amp_tone.ctrlD row rewritten for the D54 bit-pack).
  - `docs/ai_context/CURRENT_STATE.md` / `RESUME_PROMPTS.md` / `TIMING_AND_FPGA_NOTES.md` (D54 entry).
  - `tests/test_overlay_controls.py` (D54 bit-pack tests; D53 in-band-shift tests retired).
- **Tests.** `python3 -m py_compile` PASS for every edited Python file. `python3 -m unittest -v` PASS for the encoder / state / overlay suite (87 + 5 new D54 tests, 0 failures). `python3 tests/test_overlay_controls.py` PASS.
- **Rollback.** Revert `Amp.hs` to the pre-D54 `ampAsymClip :: Unsigned 8 -> Sample -> Sample` shape, restore the legacy `ampModelSel` byte quantiser, drop `ampModelIdxF` / `ampDriveModeF` / `ampCharForModel`, restore the `_percent_to_u8(amp_character, 255)` path in `AudioLabOverlay.guitar_effect_control_words`, revert `amp_model_drive_byte` to the D53 `amp_character_byte_for_model` shape, regenerate Clash VHDL, re-run Vivado, redeploy. The D53 bit-shift gives the same UI surface (DRV MODE 0/1) for a no-rebuild fallback if the new bit decoding regresses timing on a future P&R seed.

## D55 — Replace Amp Sim model set with six researched amp voicings

- **Date.** 2026-05-22.
- **Status.** Implemented end-to-end: research notes drafted, Python /
  GUI / HDMI mirror / encoder runtime / notebooks / tests updated,
  Clash regenerated, Vivado batch rebuild kicked off, deploy +
  on-board smoke pending the next session.
- **Context.** D54 wired the Amp Sim DRV MODE bit into a real Clash
  Clean/Drive branch, but the model set was still the legacy D52
  four-band lineup (`jc_clean` / `clean_combo` / `british_crunch` /
  `high_gain_stack`) whose voicing differences came from one shared
  per-model "character byte" and only nudged a single LPF / clip
  knee. The user requested six researched amp models with real
  voicing differences, with each model having a Clean and Drive
  variant via the existing D54 bit.
- **Decision.**
  - **Six inspired-by amp voicings replace the D52 set.** The new
    table (snake_case enum, integer idx, title-case label) is:
    - `0 = jc_120` — `JC-120` (Roland Jazz Chorus 120 SS clean)
    - `1 = twin_reverb` — `Twin Reverb` (Fender Blackface AB763)
    - `2 = ac30` — `AC30` (Vox Top Boost EL84 chime)
    - `3 = rockerverb` — `Rockerverb` (Orange EL34 dirty)
    - `4 = jcm800` — `JCM800` (Marshall 2203 master volume)
    - `5 = triamp_mk3` — `TriAmp Mk3` (Hughes & Kettner modern HG)
    The research notes / source URLs / DSP coefficient rationale
    live in `docs/ai_context/AMP_MODEL_RESEARCH_D55.md`. Labels are
    inspired-by, not commercial circuit / IR / coefficient copies
    (`DECISIONS.md` D7).
  - **`axi_gpio_amp_tone.ctrlD` widened from 2-bit to 3-bit model
    field.** D55 layout:
    - `ctrlD[7]` = `ampDriveMode` (0 = Clean, 1 = Drive, unchanged from D54).
    - `ctrlD[6:3]` = reserved, Python writer must set 0; Clash side
      ignores them.
    - `ctrlD[2:0]` = `ampModelIdx` (3-bit, 0..5 valid; 6..7
      reserved -> Clash falls back to 0 = JC-120 as a safety default
      so an unexpected write does not run `clip_count` away on the
      highest-gain voicing).
    - Python composer:
      `AudioLabOverlay.amp_model_drive_byte(amp_model_idx, amp_drive_mode)
      = ((mode & 1) << 7) | (idx & 0x07)`, with idx clamped to
      `AMP_MODEL_IDX_MAX = 5` before pack.
  - **Per-model coefficient tables in `Amp.hs`, not just a shared
    character byte.** New helpers:
    - `ampModelIdxF f = unpack (slice d26 d24 (fAmpTone f))` returns
      `Unsigned 3` (was `Unsigned 2` in D54).
    - `ampCharForModel` returns the per-model centre intensity
      (`26 / 89 / 153 / 200 / 220 / 240`). The two new high-gain
      indices get bigger intensities so the existing knee / alpha /
      second-stage formulas (which consume the byte) already react
      harder before the Drive bit fires.
    - `ampModelDarken` / `ampPreLpfDriveDarken` /
      `ampSecondStageDriveBonus` / `ampDrivePosDelta` /
      `ampDriveNegDelta` are six independent per-model tables driving
      `ampPreLowpassFrame`, `ampSecondStageMultiplyFrame`, and
      `ampAsymClip`. JC-120 lands at the tightest / brightest end;
      TriAmp Mk3 at the darkest / most saturated end.
    - `ampTrebleGain :: Unsigned 3 -> Unsigned 8 -> Unsigned 8` now
      carries a 6-entry case (`0..12`) so the top-octave fizz cut
      scales with the voicing.
    - `ampResPresenceProductsFrame` has its `presenceTrim` case
      widened to 6 entries (`0`, `>>6`, `>>5`, `>>4`, `>>4`, `>>3`).
  - **Output safety preserved.** `softClipK 3_300_000` /
    `3_400_000` are kept at the same values, so the TriAmp Mk3 +
    Drive combo cannot run `clip_count` past the historical band.
  - **The legacy continuous `amp_character` percent knob stays
    retired (D53 / D54).** `amp_character` kwarg remains as a
    chain-preset back-compat path -- callers that supply only
    `amp_character` still get a byte from the percent, but the user-
    facing UI / encoder / notebook / HDMI all pass
    `amp_model_idx + amp_drive_mode`.
- **Backward compatibility.**
  - `audio_lab_pynq/hdmi_state/amps.py` aliases the four retired
    D52 snake_case names onto the closest D55 voicing
    (`jc_clean -> jc_120`, `clean_combo -> twin_reverb`,
    `british_crunch -> ac30`, `high_gain_stack -> jcm800`); the
    legacy `mirror.jc_clean() / mirror.clean_combo() /
    mirror.british_crunch() / mirror.high_gain_stack()` helpers stay
    callable and route onto the new voicings.
  - Legacy state.json files written by D54 / D53 / D52 load cleanly:
    `compact_v2/state.py::load_state_json` clamps
    `amp_model_idx` into the new 0..5 range. A pre-D52 state file
    with idx=3 still loads as `Rockerverb` after D55 (the closest
    high-gain slot to the retired `high_gain_stack`).
  - `AMP_MODEL_CHARACTER_BYTES`, `AMP_DRIVE_MODE_OFFSET` constants
    are preserved as 0-shift placeholders for any external caller
    that imported them; new code should use
    `AMP_MODEL_IDX_MASK = 0x07` / `AMP_MODEL_IDX_MAX = 5` instead.
- **Files changed.**
  - `hw/ip/clash/src/AudioLab/Effects/Amp.hs` (3-bit model field,
    six-way coefficient tables, `ampAsymClip` signature changed to
    `Unsigned 3 -> Unsigned 8 -> Bool -> Sample -> Sample`).
  - `hw/ip/clash/vhdl/LowPassFir/` regenerated by Clash + `create_ip.tcl`.
  - `audio_lab_pynq/effect_defaults.py` (AMP_MODELS rewritten to the
    six snake_case names; new `AMP_MODEL_LABELS` /
    `AMP_MODELS_LEGACY_PERCENT` exports).
  - `audio_lab_pynq/AudioLabOverlay.py` (`AMP_MODEL_IDX_MASK = 0x07`,
    `AMP_MODEL_IDX_MAX = 5`, new `get_amp_model_labels` /
    `amp_model_to_idx`; six `set_amp_model` helpers in
    `HdmiEffectStateMirror`; legacy `set_amp_model` route updated).
  - `audio_lab_pynq/encoder_effect_apply.py` (clamps to
    `overlay.AMP_MODEL_IDX_MAX` if exposed; D55 docstring).
  - `audio_lab_pynq/hdmi_effect_state_mirror.py` (`_amp_model_from_
    character` rewritten for six bands; six new named helpers; four
    legacy aliases preserved).
  - `audio_lab_pynq/hdmi_state/amps.py` (AMP_MODELS / labels /
    aliases rewritten for D55).
  - `audio_lab_pynq/hdmi_state/selected_fx.py` (`DROPDOWN_SHORT_LABELS`
    rewritten for the six D55 amp names).
  - `GUI/compact_v2/knobs.py` (AMP_MODELS list rewritten to six
    title-case labels; index = `amp_model_idx`).
  - `GUI/compact_v2/state.py` (default `amp_model_idx = 2`
    (`AC30`); load_state clamps to 0..len(AMP_MODELS)-1).
  - `audio_lab_pynq/notebooks/GuitarPedalboardOneCell.ipynb`
    (inline AMP_MODELS fallback dict updated to six entries).
  - `audio_lab_pynq/notebooks/PmodI2S2EffectControlOneCell.ipynb`
    (default `amp_model = "twin_reverb"`).
  - `audio_lab_pynq/notebooks/HdmiGuiShow.ipynb` (demo
    `state.amp_model_label = "JCM800"`).
  - `tests/test_overlay_controls.py` /
    `tests/test_encoder_effect_apply.py` /
    `tests/test_hdmi_model_state_mapping.py` /
    `tests/test_hdmi_resource_monitor.py` /
    `tests/test_hdmi_selected_fx_state.py` /
    `tests/test_hdmi_origin_mapping.py` updated for the six-model
    set + 3-bit field + alias behaviour.
  - `docs/ai_context/AMP_MODEL_RESEARCH_D55.md` (new, research notes).
  - `docs/ai_context/GPIO_CONTROL_MAP.md`,
    `docs/ai_context/CURRENT_STATE.md`,
    `docs/ai_context/RESUME_PROMPTS.md`,
    `docs/ai_context/TIMING_AND_FPGA_NOTES.md` updated for D55.
- **Tests.** `python3 -m py_compile` PASS for every edited Python
  file. `python3 -m unittest -v
  tests.test_encoder_input_decode tests.test_encoder_ui_controller
  tests.test_compact_v2_encoder_state tests.test_encoder_effect_apply
  tests.test_overdrive_model_select tests.test_hdmi_selected_fx_state`
  PASS (90 + 3 new D55 tests). `python3 tests/test_overlay_controls.py`
  PASS. `python3 tests/test_hdmi_model_state_mapping.py` /
  `tests/test_hdmi_resource_monitor.py` /
  `tests/test_hdmi_gui_bridge.py` PASS as scripts.
- **Rollback.** Revert `Amp.hs` to the D54 2-bit
  `ampModelIdxF :: Unsigned 2` shape, drop the per-model coefficient
  tables, restore `AMP_MODELS` in `effect_defaults.py` to the four
  D52 snake_case names, restore `AMP_MODEL_IDX_MASK = 0x03`, revert
  the GUI / HDMI / encoder / notebook edits, regenerate Clash VHDL,
  re-run Vivado, redeploy. The D54 bit-pack remains a clean
  fallback target because the bit positions of the drive bit and
  the model field's LSB are preserved.

## D58.2 — Balanced Amp Drive Mode saturation, fixed-scalar retake (after the D58 bypass-path P&R regression)

- **Date.** 2026-05-23.
- **Status.** Implemented: `Amp.hs` re-edited with per-model fixed
  scalars, Clash VHDL + IP repackaged, Vivado batch rebuild PASS with
  DSP count back to D55's `83` (vs the failed D58's `87`), bit/hwh
  deployed 5-site to PYNQ, programmatic smoke incl. the D58
  bypass-path regression guard PASS. On-bench audio verification by
  ear is pending the user's next session.
- **Context.** D58 (`feature/amp-drive-mode-balanced-gain`, commit
  `797467c`) replaced the D55 fixed-scalar Drive deltas with
  `ch * factor` (`Unsigned 3 -> Signed 25 -> Signed 25`) so the knee
  shrink would scale with each model's intensity byte. Functionally
  the change targeted exactly the "between D55 and D57" sweet spot
  the user asked for, and programmatic smoke (CLIP_COUNT, GUI
  startup, MODE registers) all passed. On hardware the user heard
  a **high-frequency saturation noise** in *every* configuration --
  including all six amp models, both Drive and Clean, **Amp OFF
  (`amp_on=False`), and full safe bypass (every `effect_on=False`)**.
  Disconnecting the Pmod ADC cable silenced the symptom, so the
  noise was carried by an in-chain signal path, not generated by
  the DAC or downstream analog. D55 was clean in the same scenarios.
  - Diagnosis: D58 added four new DSP48E1 multiplications (DSP count
    `83 -> 87` in `block_design_wrapper_utilization_placed.rpt`) for
    the `ch * 500..1400` and `ch * 420..1250` Drive deltas. Vivado
    P&R re-packed the design around the new multipliers and the new
    placement happened to make the ADC -> I2S serializer -> DAC
    bypass path tight enough at the rising edge of `BCLK` that the
    high-frequency content audibly saturated. The macroscopic
    timing summary still looked fine (WNS `-8.209 ns`, WHS
    `+0.053 ns`, both inside the historical band) -- the regression
    was in a sub-path that the static timing report did not flag.
  - The D58 bit (sha `7481e2f7...`) was rolled back on the PYNQ to
    the D55 bit (sha `8df39b06...`) via a one-off 5-site re-sync
    that left the source tree on the D58 commit -- the user
    confirmed by ear "治りました" after a cold power-cycle.
- **Decision.**
  - **Re-shape the Drive deltas so they cost zero new DSP slices.**
    `ampDrivePosDelta` / `ampDriveNegDelta` revert to the D55
    signature `Unsigned 3 -> Signed 25` -- per-model fixed scalars
    with no `ch` argument. Values are picked to approximate the
    D58 first-stage `ch * factor` evaluated at each model's own
    `ampCharForModel` peak so the audible character matches D58's
    target without the DSP cost:

    | idx | model        | posDelta  | negDelta  |
    | --- | ------------ | --------- | --------- |
    | 0   | JC-120       | `13_000`  | `11_000`  |
    | 1   | Twin Reverb  | `58_000`  | `50_000`  |
    | 2   | AC30         | `130_000` | `113_000` |
    | 3   | Rockerverb   | `210_000` | `180_000` |
    | 4   | JCM800       | `264_000` | `231_000` |
    | 5   | TriAmp Mk3   | `336_000` | `300_000` |

    The `_` fallback (reserved indices 6, 7) maps to the JC-120 row
    so an unexpected ctrlD write does not run `clip_count` away on
    the highest-gain voicing.
  - **Side-effect on the second stage.** `ampAsymClip` is called
    from both the first stage (`ampWaveshapeFrame`, `intensity =
    ampCharForModel idx`) and the second stage
    (`ampSecondStageFrame`, `intensity = ampCharForModel idx >> 1`).
    Because the new D58.2 deltas are fixed (no `ch` argument), both
    stages get the same value -- the second stage therefore sees a
    slightly tighter knee than D58 would have given there (D58
    halved its `ch * factor` automatically because `ch` was
    halved). On the high-gain voicings the second-stage posKnee
    drops by `~ delta / 2` vs the D58 design (e.g. TriAmp Mk3 first
    stage posKnee `2_884_000` matches D58; second stage posKnee
    `3_724_000` is `168_000` lower than D58's `3_892_000`). This
    extra second-stage tightness:
    - generates more harmonic content,
    - is partially absorbed by the D58 `ampPreLpfDriveDarken` Drive
      darken (`5..24`, unchanged from D58),
    - is capped by the existing `softClipK 3_300_000` / `3_400_000`
      output safety so `clip_count` stays bounded
      (programmatic 3 s smoke with TriAmp Mk3 + Drive on the deployed
      bit reports `CLIP_COUNT delta = 0`),
    and is judged acceptable as a side-effect of the DSP-saving
    fixed-scalar form.
  - **Keep the D58 darken / bonus tables verbatim.**
    `ampPreLpfDriveDarken` `5 / 7 / 10 / 16 / 16 / 24` and
    `ampSecondStageDriveBonus` `14 / 18 / 28 / 42 / 48 / 56` are
    bit-for-bit the same as D58. They are simple per-model
    subtractor / adder constants -- no DSP cost, no P&R risk.
  - **`ampAsymClip` call sites revert to the D55 form.**
    `posDriveDelta = if drive then ampDrivePosDelta modelIdx else 0`
    and `negDriveDelta = if drive then ampDriveNegDelta modelIdx
    else 0` -- no `ch` argument forwarded to the delta helpers.
  - **D55 structure preserved verbatim** everywhere else: six-model
    lineup (`JC-120` / `Twin Reverb` / `AC30` / `Rockerverb` /
    `JCM800` / `TriAmp Mk3`), `ctrlD[7] = ampDriveMode` /
    `ctrlD[6:3] = 0` / `ctrlD[2:0] = ampModelIdx`,
    `softClipK 3_300_000 / 3_400_000` output safety, second-stage
    `intensity = ampCharForModel idx >> 1`, six-entry
    `ampTrebleGain` / `presenceTrim`.
  - **D57 anti-patterns explicitly NOT adopted.** No
    `ampInputDriveGainBonus`, no pre-clip push, no `ch * 5000+`
    multiplier in either delta helper, no full-intensity
    second-stage clip.
  - **No Python / GUI / encoder / HDMI / Pmod / block_design /
    GPIO / `topEntity` change.** Six-model labels in
    `GUI/compact_v2/knobs.py` / `audio_lab_pynq/hdmi_state/amps.py`
    / `audio_lab_pynq/AudioLabOverlay.AMP_MODEL_LABELS` are
    untouched. ctrlD layout, `AMP_MODEL_IDX_MAX = 5`, encoder
    cycling, and the HDMI mirror all stay D55-shape.
- **Files touched.**
  - `hw/ip/clash/src/AudioLab/Effects/Amp.hs` (delta helper values
    + comments; bonus / darken values + comments; call sites already
    in D55 form, no re-edit needed).
  - `hw/ip/clash/vhdl/LowPassFir/LowPassFir.topEntity/clash_lowpass_fir.vhdl`
    (regenerated VHDL).
  - `hw/ip/clash/vhdl/LowPassFir/LowPassFir.topEntity/clash-manifest.json`
    (regenerated SHA).
  - `hw/ip/clash/vhdl/LowPassFir/component.xml` (Vivado IP repack
    timestamp + checksum).
  - `hw/Pynq-Z2/bitstreams/audio_lab.bit` /
    `hw/Pynq-Z2/bitstreams/audio_lab.hwh` (sha
    `93f31348...` / `25991dc0...`).
  - `docs/ai_context/AMP_MODEL_RESEARCH_D55.md` (DSP coefficient
    summary table -- D58.2 column added).
  - `docs/ai_context/CURRENT_STATE.md`, this file
    (`DECISIONS.md`), `docs/ai_context/TIMING_AND_FPGA_NOTES.md`.
- **Build / deploy.**
  - Clash: `clash -package-id
    clash-prelude-1.8.1-...e64d575898...144c -isrc -fclash-hdldir
    /tmp/clash_d582 --vhdl src/LowPassFir.hs` (`-package-id` pins the
    `clash-prelude` that matches the installed `clash-ghc` -- same
    workaround as D58).
  - Vivado IP repack: `vivado -mode batch -source create_ip.tcl
    -tclargs "./vhdl/LowPassFir"` in `hw/ip/clash/`.
  - Vivado full project: `vivado -mode batch -source
    create_project.tcl` in `hw/Pynq-Z2/`.
  - Deploy: `PYNQ_HOST=192.168.1.9 bash scripts/deploy_to_pynq.sh`;
    bit/hwh sha matches across all five PYNQ sites.
- **Timing.** WNS `-8.495 ns` (D55 baseline `-8.231 ns`; regresses
  by `0.264 ns`); inside the historical `-7..-9 ns` deploy band and
  well above the `-9.5 ns` hard gate. WHS `+0.051 ns`; THS
  `0.000 ns` (hold clean). Failing setup endpoints
  `3224 / 60227` (`5.35 %`). Utilization after place: Slice LUTs
  `19713` (`37.05 %`; -73 vs D55), Slice Registers `22110`
  (`20.78 %`; -50 vs D55), Block RAM Tile `6` (`4.29 %`;
  unchanged), **DSPs `83` (`37.73 %`; same as D55, four below
  D58's `87`)**. The DSP count is the load-bearing metric that
  proves the fixed-scalar form actually removed the four
  multiplications that triggered the D58 bypass-path regression.
- **Tests / smoke.**
  - `python3 -m py_compile` PASS for `audio_lab_pynq/AudioLabOverlay.py`,
    `encoder_ui.py`, `encoder_effect_apply.py`.
  - `python3 -m unittest -v
    tests.test_encoder_input_decode tests.test_encoder_ui_controller
    tests.test_compact_v2_encoder_state tests.test_encoder_effect_apply
    tests.test_overdrive_model_select tests.test_hdmi_selected_fx_state`
    PASS (91 tests). `python3 tests/test_overlay_controls.py` PASS.
  - PYNQ programmatic smoke: `ADC HPF True`; six amp models `0..5`
    ctrlD readback OK across Clean + Drive; `scripts/pmod_i2s2_mode.py`
    MODE writes `0 / 1 / 2 / 3` all readback OK; **safe bypass
    (all `effect_on = False`) + mode-2 DSP 3 s CLIP_COUNT delta = `0`,
    FRAME_COUNT delta = `144150` (exact 48 kHz cadence) -- this is
    the D58 regression guard**; Amp OFF (others default) 3 s
    CLIP_COUNT delta = `0`; TriAmp Mk3 + Drive (full chain) 3 s
    CLIP_COUNT delta = `0`; `scripts/run_encoder_hdmi_gui.py
    --live-apply --skip-rat --pmod-mode dsp` starts cleanly,
    `AudioLabOverlay loaded`, `HDMI backend started at 800x600`,
    `live=ON apply=OK`, no Python exceptions in a 12 s hold.
  - **Audio verification by ear is pending the user's bench
    session.** Programmatic smoke alone cannot prove the D58
    high-frequency saturation noise on the bypass path is actually
    gone -- the symptom was audible only, not flagged by any
    overlay register. The key listening checks for the next session
    are: (a) safe bypass + Pmod mode 2 with the Line In cable in
    place must be clean (the original D58 regression), (b) Amp OFF
    + default chain must be clean, (c) per-model Drive should sit
    audibly between D55 and D57, and (d) no `clip_count` runaway
    on TriAmp Mk3 + Drive at sane input levels.
- **Rollback.**
  - **Step 1 (audio-only rollback, no Vivado).** Revert the PYNQ
    bit/hwh to D55 with `git show 314b7c6:hw/Pynq-Z2/bitstreams/
    audio_lab.bit > /tmp/d55.bit && git show 314b7c6:hw/Pynq-Z2/
    bitstreams/audio_lab.hwh > /tmp/d55.hwh` plus a 5-site PYNQ
    `cp` (the same procedure used to revert from D58 on
    2026-05-23). Source tree may stay on this branch. A cold
    PYNQ-Z2 power-cycle is recommended afterwards so the
    rgb2dvi PLL re-locks cleanly when the next overlay load runs.
  - **Step 2 (full revert).** `git checkout main` to drop the
    Amp.hs / VHDL / IP / bit / hwh / docs back to D55 source.
    Branches `feature/amp-drive-mode-balanced-gain` (D58) and
    `feature/amp-drive-mode-balanced-gain-v2` (this D58.2 attempt)
    remain available for inspection.

## D59 — Rejected Compressor target-gain pipeline split with full `Frame` carry

- **Decision.** D59 is rejected for deployment. It split the Compressor
  target-gain calculation into three registered stages and improved
  routed WNS, but the user heard the same high-frequency saturation
  noise pattern that D58.1/D58 exposed.
- **What D59 changed.** `compTargetStage1` did threshold /
  soft-threshold comparison, excess calculation, and excess clamp;
  `compTargetStage2` did `excessU12 * ratioByte`, reduction shift /
  clamp, and target-gain conversion; `compGainNext` kept the smoothing
  register update. D59 also carried the full `Frame` through
  `compTargetStage1Pipe`, `compTargetPipe`, and `compGainFramePipe`.
- **Why it was rejected.** Programmatic smoke was clean
  (`FRAME_COUNT delta = 144150`, `CLIP_COUNT delta = 0`), but this is
  the same class of regression as D58: a P&R-sensitive audible artifact
  that counters and the top-level timing summary do not prove away. The
  extra full-frame carry added 254 registers and likely moved enough
  placement/routing to disturb the audio path.
- **Rollback.** The PYNQ-Z2 board was immediately restored to the D58.2
  clean baseline from `feature/amp-drive-mode-balanced-gain-v2`: bit/hwh
  md5 `1c9071b5f2e1eec63ef6abbcfcacbf02` /
  `21c1ca7a6ddd5c26fd39f8746abe28d8`. Board smoke after rollback:
  `ADC HPF True`, `R19_ADC_CONTROL 0x23`, Pmod mode 2 readback `2`,
  `FRAME_COUNT delta = 144154`, `CLIP_COUNT delta = 0`.
- **D59 timing record.** Routed WNS improved from D58.2 `-8.495 ns` to
  `-8.138 ns`; TNS `-8756.266 ns`; WHS `+0.052 ns`; THS `0.000 ns`.
  Utilization after place: Slice LUTs `19698`, Slice Registers `22364`,
  Block RAM Tile `6`, DSPs `83`. bit/hwh md5
  `a42358803798acc1e63ef5d4abd45b33` /
  `1ddd377d077401ccf60a9096d319ed52`. Do not redeploy this bit.

## D60 — Compressor target-gain split, control-only retake

- **Decision.** Keep the Compressor gain-calculation split, but do not
  carry the audio `Frame` through the target-gain pipeline. Only the
  Compressor control word and target terms flow through
  `compTargetStage1Pipe` / `compTargetPipe`; the audio frame stays on
  the original `compLevelPipe -> compApplyPipe` data path.
- **Reason.** D60 still breaks the packed
  threshold/soft-threshold/excess/multiply/reduction/target/smoothing
  path, but avoids the broad full-frame register insertion that made
  D59 risky. Compressor gain reaction is delayed by a small number of
  samples, which was explicitly allowed; the DSP chain effect order and
  global audio-frame latency are not changed.
- **Scope intentionally excluded.** No DS-1 / Distortion, `Amp.hs`,
  GUI, Pmod I2S2, `block_design.tcl`, GPIO map, `topEntity` port,
  Vivado strategy, Compressor coefficient, threshold/ratio/response /
  makeup semantic, or effect-order change.
- **Files touched.**
  - `hw/ip/clash/src/AudioLab/Effects/Compressor.hs`
  - `hw/ip/clash/src/AudioLab/Pipeline.hs`
  - regenerated Clash/VHDL/IP artifacts under
    `hw/ip/clash/vhdl/LowPassFir/`
  - rebuilt local `hw/Pynq-Z2/bitstreams/audio_lab.bit` /
    `hw/Pynq-Z2/bitstreams/audio_lab.hwh`
  - `docs/ai_context/CURRENT_STATE.md`,
    `docs/ai_context/TIMING_AND_FPGA_NOTES.md`, and this file
- **Build / timing.** Clash regeneration, Vivado IP repackage, and full
  `hw/Pynq-Z2 make clean && make` completed with
  `write_bitstream completed successfully` and 0 errors. Routed WNS
  `-8.300 ns`, TNS `-8836.632 ns`, failing setup endpoints
  `3181 / 60265`, WHS `+0.043 ns`, THS `0.000 ns`. This is
  `+0.195 ns` better than D58.2 (`-8.495 ns`) and `0.162 ns` worse
  than rejected D59 (`-8.138 ns`). Utilization after place: Slice LUTs
  `19728` (`37.08 %`), Slice Registers `22253` (`20.91 %`), Block RAM
  Tile `6` (`4.29 %`), DSPs `83` (`37.73 %`).
- **Critical-path result.** The top routed setup path remains DS-1-side,
  not Compressor: `ARG__6__3` DSP48E1 -> `ds1_5_reg[1015]`, slack
  `-8.300 ns`, logic levels
  `18 (CARRY4=11 DSP48E1=1 LUT2=2 LUT3=1 LUT4=1 LUT5=1 LUT6=1)`.
  DS-1 remains explicitly out of scope for this task.
- **Deploy status.** D60 bit/hwh md5:
  `078f39c78991f1b36e6bfd1806b830a5` /
  `48160ae4acdf3abb9d1abf14dd65cc6d`. **Deployed 2026-05-24 to
  PYNQ-Z2 192.168.1.9 and audio-rejected on bench.**
  Deploy-time programmatic smoke PASSed: cold-power-cycled PYNQ +
  explicit `AudioLabOverlay(download=True)` to force a fresh PL
  program (`PL.timestamp` confirmed re-program), `ADC HPF True`,
  Pmod mode 2 readback `2`, three-second `FRAME_COUNT delta` between
  `144148` and `144154` across `all_off` / `comp_on_mild` /
  `comp_on_stronger` / `comp_off_again` cases, `CLIP_COUNT delta = 0`
  in every window,
  `set_compressor_settings(threshold/ratio/response/makeup/enabled)`
  readback consistent, GUI keep-mode + dsp-mode 20 s holds clean with
  `live=ON apply=OK` and no Python exceptions, LCD compact-v2 rendered
  correctly, final mute=3 confirmed. **On-bench audio verification by
  ear FAILED: high-frequency saturation noise was audible even in
  safe-bypass (all `effect_on = False`, Pmod mode 2 ADC -> DSP -> DAC).**
  This is the same class of regression as D58
  (`feature/amp-drive-mode-balanced-gain`) and D59 -- a Vivado P&R-induced
  bypass-path artifact that the macroscopic timing summary and
  `CLIP_COUNT` do not flag.
- **Rollback.** PYNQ board was rolled back to D58.2 (bit/hwh md5
  `1c9071b5f2e1eec63ef6abbcfcacbf02` /
  `21c1ca7a6ddd5c26fd39f8746abe28d8`) via
  `git checkout HEAD -- hw/Pynq-Z2/bitstreams/{audio_lab.bit,audio_lab.hwh}`
  + `scripts/deploy_to_pynq.sh` + explicit
  `AudioLabOverlay(download=True)` to force a fresh PL program.
  Post-rollback Pmod mode 2 safe-clean smoke PASSed
  (`FRAME_COUNT delta = 144153`, `CLIP_COUNT delta = 0`,
  `ADC HPF True`, `VERSION 0x00480001`, final mute=3). The D60 bit
  `078f39c7...` / hwh `48160ae4...` must not be redeployed.
- **Source revert in this commit.**
  `hw/ip/clash/src/AudioLab/Effects/Compressor.hs`,
  `hw/ip/clash/src/AudioLab/Pipeline.hs`, and the regenerated Clash
  artifacts under `hw/ip/clash/vhdl/LowPassFir/` are reverted back to
  the D58.2 baseline so the source tree matches the deployed bit. The
  D60 attempt is preserved in this `DECISIONS.md` entry, in
  `CURRENT_STATE.md`'s "Superseded D60 attempt note", and in the D60
  row of `TIMING_AND_FPGA_NOTES.md` so the design rationale and
  measurements stay discoverable in history.
- **Conclusion: rule for future Compressor target-pipeline work.**
  Both D59 (full-`Frame` carry) and D60 (control-only split, audio
  frame left on the original `compLevelPipe -> compApplyPipe` path)
  split-pipeline Compressor target-gain reworks have been
  audio-rejected for the same class of P&R artifact. **The bench ear
  on safe-bypass is the only sensor that has caught this class of
  regression so far**; macroscopic timing summary, CLIP_COUNT,
  FRAME_COUNT, GUI smoke, and `apply=OK` traces are not dispositive
  on their own. Any further Compressor target-pipeline split must be
  validated by listening on safe-bypass before being treated as a
  candidate, and must be ready to be rolled back to D58.2 without a
  Vivado rebuild (the D58.2 bit/hwh are at HEAD in
  `hw/Pynq-Z2/bitstreams/` for this reason).

## D61 -- Rejected BD-2 Overdrive model fidelity attempt (both v1 and v2)

- **Decision.** D61 is rejected for deployment in both forms (v1 and v2).
  The BD-2 differentiation the attempt added (pre-clip HPF, upper-mid
  emphasis, first-stage mild asymmetric soft clip, post-clip fizz-guard
  LPF) sounded audibly correct on the bench when engaged, but safe-bypass
  (every `effect_on = False`, Pmod mode 2 ADC -> DSP -> DAC) was clearly
  noisier than D58.2 on the same A/B. This is the same class of regression
  as D58 / D59 / D60: a Vivado P&R-induced bypass-path artifact that the
  macroscopic timing summary, CLIP_COUNT, FRAME_COUNT, and the rest of
  the programmatic smoke do not flag.
- **Research deliverable kept on main.** `docs/ai_context/BD2_MODEL_RESEARCH.md`
  is the source-by-source circuit research note for the BD-2 Blues Driver
  (Analog Is Not Dead, Guitar Pedals Visualized, Aion FX Sapphire,
  PedalPCB / Chuck D. Bones breadboard, Premier Guitar mods). It survives
  this rollback so the next BD-2 attempt does not have to repeat the
  research. The note also explicitly records what the real BD-2 does
  *not* do (diode clippers D7-D10 are effectively inactive in stock per
  measurement) so the next attempt does not waste cycles modelling them.
- **Files reverted in this commit.**
  - `hw/ip/clash/src/AudioLab/Effects/Overdrive.hs`
  - `hw/ip/clash/src/AudioLab/Pipeline.hs`
  - `hw/ip/clash/vhdl/LowPassFir/LowPassFir.topEntity/clash-manifest.json`
  - `hw/ip/clash/vhdl/LowPassFir/LowPassFir.topEntity/clash_lowpass_fir.vhdl`
  - `hw/ip/clash/vhdl/LowPassFir/component.xml`
  - `hw/Pynq-Z2/bitstreams/audio_lab.bit`
  - `hw/Pynq-Z2/bitstreams/audio_lab.hwh`
  All revert back to the D58.2 baseline so the source tree matches the
  deployed bit. No D61 bit / hwh is committed.
- **D61 v1 (rejected without bench listen, DSP count out of budget).**
  v1 added new BD-2-only state registers (`bd2PreLpPrev`, `bd2PostLpPrev`)
  in `Pipeline.hs` and used `onePoleU8` (two `mulU8` per IIR pole) plus
  one `mulU8` for the upper-mid emphasis. Vivado batch build PASSed;
  routed WNS `-7.891 ns` (+0.604 ns better than D58.2 `-8.495 ns`),
  TNS `-6724.798 ns`, WHS `+0.051 ns`, THS `0 ns`. **DSP count climbed
  from 83 to 88 (+5)**, which is the same class of DSP-count delta that
  triggered the D58 bypass regression (DSP 83 -> 87). v1 was not even
  bench-listened on this basis; the bit/hwh md5
  `13429faf72b87015725dfee2ee814dee` / `fe6cd05ef0ea78f4fe5c15abf4bc9432`
  are recorded for traceability but must not be redeployed.
- **D61 v2 (built, deployed, bench-listened, rejected on bypass noise).**
  v2 rewrote the same two BD-2 IIRs and the upper-mid emphasis as
  shift-only leaky-integrator expressions
  (`y = prev + ((x - prev) >> N)`), so the synth maps them to pure
  adder + subtractor + shifter logic with zero DSP48E1. The first-stage
  BD-2 mild clip stayed as a constant-LUT mux on the existing
  `asymSoftClip` in the boost stage. **DSP count back to 83 (same as
  D58.2 baseline)**, which removes the D58-class DSP-count risk. Routed
  WNS `-8.083 ns` (+0.412 ns better than D58.2), TNS `-5959.880 ns`,
  WHS `+0.052 ns`, THS `0 ns`, failing setup endpoints `2172 / 52784`,
  Slice LUTs `20048` (+335 vs D58.2), Slice Registers `22277` (+167 vs
  D58.2), BRAM `6` (unchanged). bit/hwh md5
  `065a869a34e2bde86051c6a96c4aaa2f` / `927a3dfcc9819171226cb0686348fb01`
  deployed five-site to PYNQ-Z2 192.168.1.9. Deploy-time programmatic
  smoke PASS across the full audition cycle: FRAME_COUNT delta ~480k
  per 10 s, CLIP_COUNT delta = 0 for every case (all_off, TS9, OD-1,
  BD-2 G20 / G50 / G80 at T50, BD-2 G50 at T30 / T70, Centaur), MUTE 3
  honoured, GUI keep + dsp 20 s holds clean with `live=ON apply=OK`.
  Bench audition with proper monitoring (CLAUDE.md spec connection,
  no Pmod Line Out -> Line In direct loopback): **BD-2 G20 / G50 / G80
  produced the documented edge-of-breakup / canonical / fuzzy-splatty
  gradation; tone 30 / 50 / 70 gave dark / flat / bright with no
  ice-pick; TS9 / OD-1 / Centaur sounded identical to D58.2 (no leak
  to other models).** However safe-bypass was clearly noisier than
  D58.2 on the same A/B by ear, so D61 v2 was rejected. Do not
  redeploy this bit.
- **Rollback executed.** PYNQ rolled back to D58.2 (bit/hwh md5
  `1c9071b5f2e1eec63ef6abbcfcacbf02` / `21c1ca7a6ddd5c26fd39f8746abe28d8`)
  via `git checkout HEAD -- hw/Pynq-Z2/bitstreams/{audio_lab.bit,audio_lab.hwh}`
  + `scripts/deploy_to_pynq.sh` + `AudioLabOverlay(download=True)`.
  Post-rollback Pmod mode 2 safe-clean smoke PASS: FRAME_COUNT delta
  144150, CLIP_COUNT delta 0, ADC HPF True, VERSION 0x00480001, MUTE 3.
- **Diagnostic note: loopback positive feedback (sweep-test artifact).**
  During the failure investigation the user temporarily connected
  Pmod Line Out -> Pmod Line In with a direct cable for measurement;
  this creates a positive feedback loop through the DSP chain whose
  small (>1) loop gain in mode 2 builds up to near-FS in seconds.
  Programmatic peak-L on either D58.2 or D61 v2 under this loopback
  reads ~7M (-1.3 dBFS) on the left channel and is *not* a bit-specific
  regression; both bits show the same loopback resonance. The
  bench-listening rejection of D61 v2 was reproduced separately with
  the loopback cable removed (CLAUDE.md spec connection), so it is the
  load-bearing evidence -- not the sweep numbers. The sweep also showed
  that D58.2 and D61 v2 share comparable left-channel peak energy per
  (freq, level) bucket but their per-freq pattern is shifted (e.g. at
  16 kHz / 0 dBFS, D58.2 peak ~2.6 M vs D61 v2 ~5.0 M; at 12 kHz / 0 dBFS
  D58.2 ~3.2 M vs D61 v2 ~0.03 M); the shift is consistent with the
  ~1-sample additional group delay D61 v2 introduces in the OD section
  rotating the cable-loop standing-wave pattern in frequency.
- **Rule for the next BD-2 attempt (load-bearing for the next session).**
  Do *not* add new register stages or new feedback state registers in
  `Pipeline.hs`. Do *not* add new `mulU8` / `mulU12` invocations
  anywhere on the OD path. Limit the BD-2 differentiation to:
  1. New per-model constant entries in the existing tables
     (`odDriveK` / `odKneeP` / `odKneeN` / `odSafetyKnee`).
  2. New per-model constant tables that feed the *existing* arithmetic
     operators in the existing six stages
     (`overdriveDriveMultiplyFrame` / `overdriveDriveBoostFrame` /
     `overdriveDriveClipFrame` / `overdriveToneMultiplyFrame` /
     `overdriveToneBlendFrame` / `overdriveLevelFrame`).
  Anything richer (pre-HPF, upper-mid emphasis, post-LPF) requires
  feedback state, and D61 v2 demonstrated that even shift-only
  leaky-integrator feedback inside the OD section is enough to perturb
  the Vivado P&R and re-introduce the bypass artifact. The bench ear
  on safe-bypass remains the only sensor that has caught this class
  of regression across D58 / D59 / D60 / D61; macroscopic timing,
  CLIP_COUNT, FRAME_COUNT, GUI smoke, and DMA-capture peaks are
  necessary but not sufficient. D62 is now the deployed baseline; the
  D58.2 bit/hwh remain the historical rollback target if D62 itself
  needs to be undone.

## D62 -- BD-2 Overdrive coefficient-only retune (accepted on bench)

- **Decision.** D62 is accepted as the new deployed baseline. The
  three-numeric-edit retune of BD-2 (`Overdrive.hs` model index 2)
  achieved the BD-2 fidelity target documented in
  `docs/ai_context/BD2_MODEL_RESEARCH.md` without any structural
  change. Bench audition confirmed: (a) safe-bypass is as quiet as
  D58.2 -- the D58 / D59 / D60 / D61 v2 class of bypass HF
  saturation noise did NOT reappear; (b) BD-2 G20 / G50 / G80
  audibly clips earlier and with stronger even-harmonic asymmetry
  than the D58.2 BD-2; (c) TS9 / OD-1 / Centaur sound identical to
  D58.2 (byte-exact for the other five models).
- **What changed (exhaustive).** Three case entries in `Overdrive.hs`:
  - `odDriveK 2`: `6` -> `7`. Matches OCD's `7` ceiling (per the
    documented two-cascaded ~40 dB op-amp character in
    BD2_MODEL_RESEARCH.md sources [1] / [4]); BD-2's max drive
    multiplier goes from `~1..6.97x` to `~1..7.97x`.
  - `odKneeP 2`: `3_000_000` -> `2_400_000`. Pre-D62 value treated
    BD-2 as "transparent"; source [4]'s breadboard measurement
    (Chuck D. Bones) reports audible op-amp rail clipping well
    below mid-drive, with the diodes essentially inactive. `2.4M`
    places BD-2 between OCD (`2.3M`) and OD-1 (`2.6M`).
  - `odKneeN 2`: `2_700_000` -> `1_900_000`. The BD-2 op-amps run
    from a single supply with the rail offset documented in source
    [1]; their saturation is asymmetric. P/N gap is now `500k` (vs
    OCD's `400k` and OD-1's `500k`), so the BD-2 entry carries the
    most pronounced even-harmonic colour in the six-model lineup.
  - `odSafetyKnee 2`: unchanged at `3_400_000`.
- **What did NOT change.** `Pipeline.hs` is byte-for-byte unchanged.
  No new register stage, no new feedback state register, no new
  `mulU8` / `mulU12` invocation, no new combinational fan-out, no
  GPIO map / `topEntity` / `block_design.tcl` / GUI / Pmod I2S2 /
  Compressor / Amp / Distortion / DS-1 / RAT touch. The five
  non-BD-2 Overdrive models (TS9 / OD-1 / Jan Ray / OCD / Centaur)
  are byte-exact preserved -- their per-model entries in the same
  `odDriveK` / `odKneeP` / `odKneeN` / `odSafetyKnee` case statements
  are not touched.
- **Build / timing.** Clash -> VHDL -> IP repackage -> Vivado batch
  build PASS (`write_bitstream completed successfully`, 0 Errors).
  Routed WNS `-8.497 ns` (vs D58.2 `-8.495 ns`, delta `-0.002 ns`
  -- noise floor, essentially identical), TNS `-5876.740 ns`
  (improved over D58.2's `-9052.753`), WHS `+0.053 ns`,
  THS `0.000 ns`, failing setup endpoints `2107 / 52730` (better
  than D58.2's `3224 / 60227`). Utilization after place: Slice LUTs
  `19700` (-13 vs D58.2), Slice Registers `22280` (+170 vs D58.2),
  Block RAM Tile `6` (unchanged), DSPs `83` (unchanged from D58.2).
  bit/hwh md5
  `349ebbe609ac15f58d8b676d2dedee94` /
  `3a90e966c5d76762b60ba3ab0e982685`. The near-zero WNS delta vs
  D58.2 is the load-bearing signal that Vivado P&R landed on
  essentially the same placement -- which D58 / D59 / D60 / D61 v2
  collectively proved is the prerequisite for keeping the safe-bypass
  path clean.
- **Deploy + smoke.** Deployed 5-site to PYNQ-Z2 192.168.1.9 via
  `scripts/deploy_to_pynq.sh`. PL freshly programmed via
  `AudioLabOverlay(download=True)`. Pmod mode 2 safe-clean 3 s:
  FRAME_COUNT delta `144150`, CLIP_COUNT delta `0`, ADC HPF True,
  VERSION `0x00480001`, MUTE 3 readback. Audition cycle 10 cases x
  15 s ran clean (no Python exceptions, FRAME / CLIP nominal, MUTE
  honoured at end). Bench audition (CLAUDE.md spec connection,
  no Pmod direct loopback): pass on all three criteria.
- **Conclusion for the D58 / D59 / D60 / D61 history.** D62
  demonstrates that the bypass-path P&R sensitivity documented
  across the prior four rejected attempts is specifically a response
  to *structural* changes (new DSP48E1 multipliers in D58, new
  `Pipeline.hs` register stages in D59 / D60 / D61 v1 / D61 v2).
  A pure constant edit in the existing per-model tables does NOT
  perturb Vivado P&R enough to leak into the safe-bypass path.
  This is the engineering rule that survives this commit: any
  *audio* improvement on the existing six-stage Overdrive (or any
  other section with the same structural sensitivity) should first
  try a constant-only retune; only if the audible target genuinely
  cannot be reached without new arithmetic / new register stages
  should the more expensive structural path be considered, and even
  then with the understanding that the bypass-path is the dispositive
  acceptance gate.
- **Rollback target.** D58.2 bit/hwh
  (`1c9071b5f2e1eec63ef6abbcfcacbf02` /
  `21c1ca7a6ddd5c26fd39f8746abe28d8`) remain available via
  `git show <previous-commit>:hw/Pynq-Z2/bitstreams/audio_lab.bit`
  if D62 ever needs to be undone. The D62 bit/hwh are tracked in
  this commit so they likewise survive in git history.

## D63 -- Rejected DS-1 Distortion model fidelity attempt (two-stage clip cascade)

- **Decision.** D63 is rejected for deployment. The DS-1 retake bench-failed
  on all four acceptance criteria simultaneously (bypass artifact + DS-1
  character anomalous + tone discrimination impossible + leak to other
  distortion pedals and the entire Overdrive section). The PYNQ board has
  been rolled back to the D62 baseline; the D63 source / VHDL / bit / hwh
  are NOT committed; only the research note
  `docs/ai_context/DS1_MODEL_RESEARCH.md` and this rejection record ship.
- **Research deliverable kept on main.**
  `docs/ai_context/DS1_MODEL_RESEARCH.md` is the source-by-source research
  note for the BOSS DS-1 (ElectroSmash, sonicfields.be, Guitar Pedals
  Visualized, electric-safari, MUMT 618 academic report, Boss articles
  marketing-side). It survives this rollback so D63.1 or any later DS-1
  retake does not have to repeat the literature search.
- **Files reverted in this commit.**
  - `hw/ip/clash/src/AudioLab/Effects/Distortion.hs`
  - `hw/ip/clash/vhdl/LowPassFir/LowPassFir.topEntity/clash-manifest.json`
  - `hw/ip/clash/vhdl/LowPassFir/LowPassFir.topEntity/clash_lowpass_fir.vhdl`
  - `hw/ip/clash/vhdl/LowPassFir/component.xml`
  - `hw/Pynq-Z2/bitstreams/audio_lab.bit` (already reverted in deploy step)
  - `hw/Pynq-Z2/bitstreams/audio_lab.hwh` (already reverted in deploy step)
  All revert back to the D62 baseline so the source tree matches the
  deployed bit. No D63 bit / hwh is committed.
- **What D63 attempted.** Four edits in `Distortion.hs`, scoped to the
  `ds1*Frame` functions only (no `Pipeline.hs` edit, no per-stage register
  added, no `mulU8` / `mulU12` invocation added):
  1. `ds1ClipFrame`: chained `asymSoftClip` (Q2 emulator, soft asymmetric
     pre-knee at softKneeP=`3_000_000` / softKneeN=`2_600_000`) before
     `asymHardClip` (op-amp diode-pair emulator, symmetric hard knee at
     hardKneeP=hardKneeN=`2_200_000`). Both helpers are pure
     compare-add-shift -- zero DSP48E1 cost.
  2. `ds1MulFrame`: drive coefficient `8 -> 10` (~1x..~11x).
  3. `ds1ToneFrame`: alpha base `96 -> 80` (range 80..207 instead of
     96..223) to emulate the always-on 7.2 kHz feedback LPF of the real
     pedal (R14+C10 per ElectroSmash).
  4. `ds1HpfFrame` / `ds1LevelFrame`: unchanged.
- **Build outcome (programmatic, looked excellent).** Clash regen +
  Vivado batch build PASS (`write_bitstream completed successfully`, 0
  Errors). Routed WNS `-8.426 ns` (`+0.071 ns` better than D62
  `-8.497 ns`), TNS `-6452.238 ns`, WHS `+0.051 ns`, THS `0 ns`, failing
  setup endpoints `2127 / 52725`. Utilization: Slice LUTs `19755` (+55
  vs D62), Slice Registers `22195` (-85 vs D62), BRAM `6` (unchanged),
  **DSPs `83` (unchanged from D62)**. bit/hwh md5
  `b9bb64260d0c9b2ed86f9543a8392359` /
  `6fb1210f60970118d80993035460342d`. Deploy-time programmatic smoke
  PASS (Pmod mode 2 safe-clean: FRAME_COUNT delta `144154`,
  CLIP_COUNT delta `0`, ADC HPF True, MUTE 3 readback).
- **Bench audition (CLAUDE.md spec connection, no Pmod direct loopback):
  failed on all four criteria.**
  1. **bypass all_off**: produced a bit-crusher-like artifact (a
     *different* failure mode from the HF saturation noise that
     D58/D59/D60/D61 v2 produced; suggests AXIS-stream sample
     quantisation / glitching rather than HF leakage).
  2. **DS-1 D20 / D50 / D80 sweep at T50**: did NOT produce the intended
     light-crunch -> canonical-hard-clip -> heavy-square-ish
     progression; the actual sound was anomalous.
  3. **DS-1 T30 / T50 / T70 sweep at D50**: indistinguishable; the
     sound was too anomalous for the user to judge tone direction.
  4. **RAT / TS9 / BD-2** (which the D63 edits did NOT touch in source
     -- they are independent pedals / Overdrive models): sounded
     different from D62. **The DS-1-only source edit LEAKED into other
     pedals and the entire Overdrive section.** This is the strongest
     evidence yet that a combinational-logic addition inside a single
     stage perturbs Vivado P&R enough to disturb unrelated nets.
- **Load-bearing engineering lesson (added to the D58 / D59 / D60 /
  D61 / D62 sequence).** D63 categorised the
  `asymSoftClip -> asymHardClip` cascade in `ds1ClipFrame` as a
  "zero-DSP helper swap, safe like D62's pure-constant retune". That
  categorisation is **wrong**. Adding a second clip-helper invocation
  inside a single existing stage is a structural change in the
  Vivado-P&R sense, even when DSP48E1 count, BRAM count, register
  count, and WNS all look fine; the cascade increases combinational
  depth and fan-out and Vivado's downstream placement / routing of
  unrelated nets shifts enough to leak a perceptible audio artifact.
  The stricter rule the D58 / D59 / D60 / D61 / D62 / D63 cumulative
  evidence supports: **any change inside `LowPassFir.hs` or any DSP-
  effect module that adds combinational logic (not just constants
  inside an existing LUT) MUST be assumed structural until proven
  otherwise by bench audition on `all_off` bypass and on every other
  effect that shares the same axis_switch path**. The acceptance gate
  is the bench ear on bypass, not the macroscopic timing summary,
  CLIP_COUNT, FRAME_COUNT, GUI smoke, or DSP count.
- **Rule for the next DS-1 retake (D63.1 or later).**
  1. At most ONE clip-helper invocation per existing stage (no
     cascade in `ds1ClipFrame`).
  2. Permitted source changes: numeric constant edits in the existing
     `ds1*Frame` functions, and `if model == X then constA else constB`
     style muxing on operands of the *existing* helper invocation.
     Never an *additional* helper invocation.
  3. The most promising D63.1 candidate is the simplest possible: keep
     the current `asymSoftClip` invocation in `ds1ClipFrame` and only
     reduce the knee constants further (e.g. softKneeP -> 2_000_000 /
     softKneeN -> 1_700_000) to push DS-1 closer to a hard-knee feel
     without adding any new arithmetic.
  4. A bolder D63.1 candidate (still inside the rule): swap the
     `asymSoftClip` call to `asymHardClip` with symmetric knees, but
     keep it as a *single* helper invocation -- no Q2 emulation
     cascade. This sacrifices the soft-asym Q2 character but matches
     the dominant DS-1 sonic signature (op-amp diode hard clip).
  5. If even that single-helper-swap retake triggers the bypass artifact
     on bench, DS-1 fidelity work in this section is permanently
     limited to per-knee constant retunes within the existing
     `asymSoftClip` invocation.
  6. The Big Muff style ~500 Hz mid-scoop in `ds1ToneFrame` requires
     either two `mulU8` invocations or an internal restructure of the
     stage; both are now strongly contraindicated by the D63 evidence
     and are deferred indefinitely.
- **Rollback target.** D62 bit/hwh
  (`349ebbe609ac15f58d8b676d2dedee94` /
  `3a90e966c5d76762b60ba3ab0e982685`) remain the deployed and
  in-source baseline. D58.2 bit/hwh
  (`1c9071b5f2e1eec63ef6abbcfcacbf02` /
  `21c1ca7a6ddd5c26fd39f8746abe28d8`) remain available via
  `git show <previous-commit>:hw/Pynq-Z2/bitstreams/audio_lab.bit`
  if D62 ever needs to be undone too.

## D64 -- Rejected distortion-wide asymSoftClip knee-only retune (5 constants, 3 pedals)

- **Decision.** D64 is rejected for deployment. The build was the strictest
  possible interpretation of the D62 / D63 cumulative rule (constants only
  on existing `asymSoftClip` invocations, no helper added / swapped /
  cascaded, no `Pipeline.hs` edit, no DSP / BRAM / register count change),
  yet still triggered a bypass-path HF regression vs D62 on the bench.
  Per-pedal audition itself was a mixed picture: TS9 and Fuzz Face moved
  in the right direction audibly, DS-1 moved in the right direction but
  not far enough; the bypass regression alone made the build
  non-deployable.
- **Research deliverable kept on main.**
  `docs/ai_context/DISTORTION_ASYMSOFTCLIP_RETUNE_RESEARCH.md` is the
  source-by-source research note (ElectroSmash TS-9, ElectroSmash DS-1,
  ElectroSmash Fuzz Face, stompboxelectronics TS-9). It is the
  prerequisite for any future per-pedal retake. The note remains in
  git history; future retakes can pull individual coefficient targets
  from it without redoing the literature search.
- **Files reverted in this commit.**
  - `hw/ip/clash/src/AudioLab/Effects/Distortion.hs`
  - `hw/ip/clash/vhdl/LowPassFir/LowPassFir.topEntity/clash-manifest.json`
  - `hw/ip/clash/vhdl/LowPassFir/LowPassFir.topEntity/clash_lowpass_fir.vhdl`
  - `hw/ip/clash/vhdl/LowPassFir/component.xml`
  - `hw/Pynq-Z2/bitstreams/audio_lab.bit` (already reverted in deploy step)
  - `hw/Pynq-Z2/bitstreams/audio_lab.hwh` (already reverted in deploy step)
  All revert back to the D62 baseline. No D64 bit / hwh is committed.
- **What D64 attempted (exhaustive).** Five numeric constants in
  `Distortion.hs`, scoped to the three existing `asymSoftClip` invocations:
  | Pedal | `kneeP` (old -> new) | `kneeN` (old -> new) | Per-knee delta | Direction |
  | ----- | -------------------- | -------------------- | -------------- | --------- |
  | TS9 (`tubeScreamerClipFrame`) | 2_900_000 -> 2_900_000 (unchanged) | 2_500_000 -> 2_700_000 | P 0 %, N +8 % | gap 400k -> 200k, more symmetric (real D1/D2 antiparallel IS symmetric per ElectroSmash TS9 analysis) |
  | DS-1 (`ds1ClipFrame`) | 2_400_000 -> 2_200_000 | 2_000_000 -> 2_100_000 | P -8 %, N +5 % | gap 400k -> 100k, nearly symmetric + slightly earlier clip (real op-amp diode pair IS symmetric per ElectroSmash DS-1 analysis) |
  | Fuzz Face (`fuzzFaceClipFrame`) | 1_900_000 -> 2_000_000 | 1_400_000 -> 1_200_000 | P +5 %, N -14 % | gap 500k -> 800k, more asymmetric (real BJT pair is strongly asymmetric and that asymmetry is "important for the musical quality" per ElectroSmash Fuzz Face analysis) |
  All per-knee deltas within ±25 % of D62 baseline; ACTUAL `asymSoftClip`
  invocation count unchanged (3); ACTUAL `asymHardClip` invocation count
  unchanged (0); no other helper / arithmetic / register / pipeline
  edit.
- **Build outcome (programmatic, looked excellent).** Clash regen +
  Vivado batch build PASS (`write_bitstream completed successfully`, 0
  Errors). Routed WNS `-7.903 ns` (+0.594 ns vs D62 `-8.497 ns` --
  notably *better* than D62, not worse), TNS `-5457.133 ns`, WHS
  `+0.052 ns`, THS `0 ns`, failing setup endpoints `2038 / 52739`.
  Utilization: Slice LUTs `19690` (-10 vs D62), Slice Registers `22304`
  (+24 vs D62), BRAM `6` (unchanged), **DSPs `83` (unchanged from
  D62)**. bit/hwh md5 `ea647168adda426d4d7d35656c7ca91f` /
  `a15147c3c5f832826f78c588c3a7551b`. Deploy-time programmatic smoke
  PASS (Pmod mode 2 safe-clean 3 s: FRAME_COUNT delta `144150`,
  CLIP_COUNT delta `0`, ADC HPF True, MUTE 3).
- **Bench audition (CLAUDE.md spec connection, no Pmod direct loopback).**
  - **bypass all_off**: MORE noise than D62. **Audio-reject.**
  - TS9 D50 / D80: more symmetric and smoother, as intended (OK).
  - DS-1 D50 / D80: harder + closer to symmetric direction was audible,
    but the user wants the change pushed further ("more hard, more
    sym"); a follow-up retake should drop knees further.
  - Fuzz Face D50 / D80: clearly more asymmetric and "broken-up"
    germanium-style, as intended (OK).
  Per-pedal directions are validated by bench; the failure is the
  bypass regression alone.
- **Load-bearing engineering lesson (revising D62's interpretation).**
  D62 demonstrated that constants-only changes CAN be safe. D64
  demonstrates that **this is only true at very small edit scope**.
  The D62 outcome (3 constants in one Overdrive model) is now
  understood to have been load-bearing in itself; D64 touched 5
  constants across 3 distortion pedals and triggered a P&R-induced
  bypass regression even though every individual edit was within the
  D62 "safe" pattern. **The revised rule is "one model at a time, and
  as few constants as possible per build".** Touching multiple
  pedals' clip knees simultaneously is now classified as a structural
  change in the Vivado-P&R sense, similar to (but smaller than) the
  helper-cascade structural class D63 demonstrated. The bench ear on
  safe-bypass remains the only sensor that has caught these
  regressions across D58 / D59 / D60 / D61 v2 / D63 / D64; macroscopic
  WNS / TNS / DSP / BRAM / CLIP_COUNT / FRAME_COUNT / GUI smoke /
  programmatic-smoke / deploy-time numeric checks have NEVER caught
  the bypass-path regression class on their own.
- **Rule for the next distortion retake (D64.1 / D65 / ...).**
  1. Each pedal gets its OWN Vivado rebuild + bench cycle. No
     simultaneous edit to multiple pedals' knees in one build.
  2. Within a single pedal's retake, prefer the smallest possible
     numeric move that still hits the target audibly. The D62
     successful pattern was P shifted ~17 %, N shifted ~30 %, and
     the overall envelope was clearly inside ±30 % per knee with
     only one model touched -- treat that as the empirical ceiling.
  3. Of the three direction-validated D64 changes:
     - **Fuzz Face widened P/N gap** -- highest priority retake target
       because the bench audition confirmed the direction is right.
     - **TS9 narrowed P/N gap** -- next priority. Smoother symmetric
       sound was audible and desired.
     - **DS-1 harder + symmetric** -- direction OK but needs more
       magnitude; do this *after* TS9 and Fuzz Face are individually
       validated, so DS-1's bigger move doesn't get blamed on a
       multi-pedal build.
  4. If a *single-pedal* knee retake triggers the bypass artifact,
     the per-pedal asymSoftClip knee constant retake is permanently
     off-limits in this build and the affected pedal stays at its
     current values forever. The distortion fidelity ceiling for
     this build is then D62, not "D62 plus N more iterations".
- **Rollback target.** D62 bit/hwh
  (`349ebbe609ac15f58d8b676d2dedee94` /
  `3a90e966c5d76762b60ba3ab0e982685`) remain the deployed and
  in-source baseline. D58.2 bit/hwh
  (`1c9071b5f2e1eec63ef6abbcfcacbf02` /
  `21c1ca7a6ddd5c26fd39f8746abe28d8`) remain available via
  `git show <previous-commit>:hw/Pynq-Z2/bitstreams/audio_lab.bit`
  as the deeper fallback.

## D65 -- Pmod I2S2 self-loopback diagnostic (added; D62 hardware path verified clean)

- **Decision.** Diagnostic-only change. No bit / hwh / VHDL / Clash /
  DSP source touched. `scripts/diagnose_pmod_loopback.py` and
  `docs/ai_context/PMOD_LOOPBACK_DIAGNOSTIC.md` are added so any future
  build can re-run the same check before deploy.
- **Why this was needed.** After the D63 (DS-1 cascade) and D64
  (5-constant distortion retune) bench rejections, the user reported a
  "high-frequency bit-crusher" symptom and asked whether the Pmod I2S2 /
  ADC / DAC / AXIS path could itself be corrupting high-frequency
  content. The diagnostic answers that question without an external
  instrument: Pmod Line Out -> Pmod Line In direct cable loop, then
  exercise every MODE of `pmod_i2s2_master.v` (TX_TONE / RTL loopback
  / DSP path / MUTE) plus axis_switch routes via MM2S sine sweep.
- **What the script checks.** Per-phase metrics include `uniq1k`
  (unique sample values in the first 1000 polls of LAST_LEFT) and
  `max_run` (longest run of identical consecutive samples). These two
  are the dispositive bit-crusher / quantisation indicators: clean
  audio gives `uniq1k` near 1000 and `max_run = 1 or 2`. They are
  not corrupted by the ~26-37 kHz Python polling rate (the spectrum
  peaks are; the bit-pattern indicators are not).
- **Verdict.** All phases passed on D62 baseline. MODE 0 1 kHz DMA
  capture clean (single peak, harmonics >1000x below). MM2S sweep
  via `dma -> passthrough -> headphone` and via `dma ->
  guitar_chain -> headphone` both clean: every (freq, level) cell
  in 100 Hz..15 kHz at -30..-12 dBFS shows `uniq1k` >= 845 and
  `max_run = 2`. **The deployed D62 I2S / ADC / DAC / AXIS /
  DSP-pass-through path is clean.**
- **Implication for D63 / D64.** The "bit-crusher" / "HF noise" /
  "leak to other pedals" symptoms in those rejected bench auditions
  cannot be from the hardware layer or from the D62 baseline DSP
  chain. They must be **build-specific Vivado P&R-induced artifacts**,
  consistent with the engineering rule already documented in the
  D58 / D59 / D60 / D61 / D62 / D63 / D64 sequence: structural Clash
  edits (helper cascades, new `Pipeline.hs` registers, even
  multi-constant simultaneous retunes) can perturb Vivado P&R enough
  to leak audio artifacts into the safe-bypass path. D62 remains the
  deployed baseline.
- **Files added in this commit.**
  - `scripts/diagnose_pmod_loopback.py` (new diagnostic script,
    no Vivado / no bit / no DSP edit)
  - `docs/ai_context/PMOD_LOOPBACK_DIAGNOSTIC.md` (new procedure +
    verdict doc)
  - `docs/ai_context/CURRENT_STATE.md` (latest-work entry updated)
  - `docs/ai_context/DECISIONS.md` (this D65 entry)
- **How to re-run.** From the host:
  ```
  ssh xilinx@192.168.1.9 'sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
      python3 scripts/diagnose_pmod_loopback.py'
  ```
  Exit code 0 on PASS, 1 on any quantisation flag. See
  `PMOD_LOOPBACK_DIAGNOSTIC.md` for phase-by-phase detail and
  the limitations of the cable-loop diagnostic.
- **Rollback target unchanged.** D62 bit/hwh
  (`349ebbe609ac15f58d8b676d2dedee94` /
  `3a90e966c5d76762b60ba3ab0e982685`) remain the deployed and
  in-source baseline.
- **Follow-up A/B comparison: D62 vs reproduced D64.** Per a follow-up
  request, the D64 5-constant retune was temporarily restored,
  rebuilt, deployed, put through the same diagnostic, then
  immediately reverted to D62. The D64 reproduction landed on
  identical Vivado timing (WNS `-7.903 ns`, DSP `83`, BRAM `6`,
  matching the original D64) and produced a fresh bit (md5
  `0c31cf02db2011102bf07c3219264043` -- timestamp metadata differs
  from the original D64 `ea647168...`, logical behaviour is the
  same). **Verdict on D64 reproduction: also PASS.** Phase B
  per-cell `uniq1k` 930..1000 and `max_run = 2` are statistically
  indistinguishable from D62's 845..1000 / 2; Phase 1 MODE 0
  baseline peakL `1.18M` matches D62 exactly; Phase 1 MODE 2
  cable-loop feedback peakL `7.14M` matches D62's `7.26M` within
  noise; the only metric that diverges is the Phase 3 DMA capture
  peak (D64 ~4x higher) which is a route-change transient
  artifact at capture start, not a steady-state audio difference.
  **Conclusion: the self-loopback test does NOT distinguish D62
  from D64**; both pass the bit-pattern checks. The audible
  "bit-crusher" the user reported during the D64 bench audition
  cannot be reproduced under cable-loop self-test conditions and
  must require external-instrument input, the user's analog
  monitoring path, or bypass-path P&R artifacts that stay below
  the `uniq1k` / `max_run` thresholds the script catches. The
  D58 / D59 / D60 / D61 v2 / D63 / D64 rule continues to apply:
  the bench ear remains the dispositive sensor.
- **Final post-comparison state.** Distortion.hs / clash VHDL /
  bit / hwh all reverted to D62 baseline. PYNQ-Z2 PL D62 freshly
  downloaded, MODE 3 mute, FRAME_COUNT delta 144151 / CLIP_COUNT
  0 confirmed. **No D64 source / VHDL / bit / hwh committed.**
  Only the diagnostic comparison record is added to
  `PMOD_LOOPBACK_DIAGNOSTIC.md` and this D65 entry.

## D66 -- DS-1-only asymSoftClip knee retune accepted

- **Decision.** Accept and deploy the DS-1-only retune on branch
  `feature/ds1-only-asymsoftclip-retune`. The only functional source
  edit is in `hw/ip/clash/src/AudioLab/Effects/Distortion.hs`
  `ds1ClipFrame`: `kneeP` `2_400_000 -> 1_900_000` and `kneeN`
  `2_000_000 -> 1_900_000`.
- **Why.** D64 proved that DS-1 needed a harder, more symmetric move,
  but D64 touched TS9 / DS-1 / Fuzz Face together and was rejected for
  bypass regression. D66 applies the D64 lesson at the minimal safe
  scope: one pedal, two constants, existing helper topology only.
  The result keeps the existing `asymSoftClip` approximation while
  making the DS-1 stage fully symmetric and lower-knee.
- **What did not change.** No TS9 / RAT / Fuzz Face / Big Muff / Metal
  / clean boost retune, no `Overdrive.hs`, no `Amp.hs`, no
  `Compressor.hs`, no `Pipeline.hs`, no `LowPassFir.hs`, no GUI /
  HDMI / Pmod RTL / `block_design.tcl`, no helper addition, no helper
  swap, no cascade, no `asymHardClip`, no new register, no new IIR,
  no drive / tone / level / highpass / lowpass coefficient change.
  `asymSoftClip` call count remains `3`; `asymHardClip` remains `0`;
  `mulU8` / `mulU12` counts remain `13` / `8`.
- **Build result.** Vivado completed with `write_bitstream completed
  successfully` and `0 Errors`. Routed timing: WNS `-8.016 ns`,
  TNS `-9648.033 ns`, WHS `+0.051 ns`, THS `0.000 ns`; main
  `clk_fpga_0` setup group worst endpoint is `ARG__7__1/CLK ->
  ds1_5_reg[1032]/D`. Utilization: LUT `19712`, FF `22160`, BRAM
  `6`, DSP `83`.
- **Deployment record.** bit/hwh md5 are
  `52f0e9937993dca11272d561f6cf6b32` /
  `d75d38394a529ac3524e0a64f73bcd34`; all PYNQ board copies matched.
  `AudioLabOverlay(download=True)` updated PL to timestamp
  `2026/5/24 14:15:57 +844083`; ADC HPF True, VERSION `0x00480001`,
  MODE 3 mute, CLIP_COUNT 0.
- **Smoke / acceptance.** `scripts/diagnose_pmod_loopback.py` PASSed
  with no QUANT! / STAIR! flags. The diagnostic remains a smoke check
  only, not an adoption criterion by itself. The user then requested
  merge to `main`; that request is the acceptance signal for this
  D66 build.
- **Baseline.** D66 was the deployed source-control baseline until the
  D67 JCM800 amp-model retune superseded it. D62 bit/hwh
  (`349ebbe609ac15f58d8b676d2dedee94` /
  `3a90e966c5d76762b60ba3ab0e982685`) remain the deeper rollback
  reference.

## D67 -- JCM800 amp model constants-only retune accepted

- **Decision.** Accept and deploy the JCM800-only amp retune on branch
  `feature/jcm800-amp-model-retune`, committed on `main` as
  `Retune JCM800 amp model constants only`. The only functional source
  edit is in `hw/ip/clash/src/AudioLab/Effects/Amp.hs`, and only
  model index `4` (`JCM800`) changes:
  - `ampPreLpfDriveDarken`: `16 -> 13`
  - `ampSecondStageDriveBonus`: `48 -> 54`
  - `ampDriveNegDelta`: `231_000 -> 200_000`
  `ampDrivePosDelta` stays `264_000`; JCM800 `ampTrebleGain` and
  `presenceTrim` stay unchanged.
- **Why.** The D55 / D58.2 amp lineup already had JCM800 as model
  index 4, but it sat too close to the thicker Rockerverb / high-gain
  side in Drive mode. The retune pushes only the existing JCM800
  constants toward a Marshall JCM800 2203-style target: tighter low end,
  brighter upper-mid bark, faster attack, more cascaded crunch, and
  more cold-clipper-like asymmetry without making it a modern TriAmp
  voice. Lowering `ampPreLpfDriveDarken` keeps more cutting brightness
  in Drive mode; raising `ampSecondStageDriveBonus` adds preamp crunch;
  lowering only `ampDriveNegDelta` makes the negative side clip earlier
  relative to the positive side.
- **What did not change.** No JC-120 / Twin Reverb / AC30 /
  Rockerverb / TriAmp Mk3 amp table entry changed. No `Distortion.hs`,
  `Overdrive.hs`, `Compressor.hs`, `Pipeline.hs`, `LowPassFir.hs`,
  GUI, HDMI, Pmod RTL, GPIO mapping, `amp_model_idx` allocation,
  `amp_drive_mode` bit allocation, or `block_design.tcl` changed. No
  helper was added, swapped, or cascaded; no IIR, register, `mulU8`,
  or `mulU12` was added. This is the accepted "one model, few
  constants, existing table only" pattern.
- **Build result.** Clash VHDL was regenerated and Vivado completed
  with `write_bitstream completed successfully` and `0 Errors`. Routed
  timing: WNS `-8.204 ns`, TNS `-9300.746 ns`, WHS `+0.034 ns`, THS
  `0.000 ns`; design summary failing endpoints `3284 / 60261`, main
  `clk_fpga_0` group `2229 / 52745`. The worst setup path remains in
  the DS-1-side logic (`ARG__17/CLK -> ds1_5_reg[1032]/D`), not in a
  new JCM800-specific structure. Utilization: LUT `19836`, FF `22174`,
  BRAM `6`, DSP `83`.
- **Deployment record.** bit/hwh md5 are
  `70b5dc7d972510c26fbb3b1014aa06eb` /
  `dc42290dc7fb46d7486068cc1d11032a`; PYNQ board copies matched the
  local files. `AudioLabOverlay(download=True)` was run, ADC HPF was
  True, and the board was returned to MODE 3 mute after the bench
  check.
- **Smoke / acceptance.** Python py_compile, 91 unittest cases,
  `tests/test_overlay_controls.py`, and `scripts/diagnose_pmod_loopback.py`
  passed. The self-loopback smoke produced no QUANT! / STAIR! flags
  and CLIP_COUNT stayed clean, but is still only a structural smoke
  check. During bench setup, two control mistakes were found and
  corrected: Pmod MODE lives at `pmod_status_0` offset `0x28`, and
  `axi_gpio_amp` is at `0x43C90000` (not the RAT / legacy
  `axi_gpio_delay` address `0x43C80000`). After those corrections,
  Amp ON / JCM800 model 4 / Drive mode / gain max was auditioned, and
  the user answered **Adopt & merge**. D67 is now the deployed
  source-control baseline; D66 is the immediate previous rollback
  reference, and D62 remains the deeper rollback reference.

## D68 -- Global Amp / Distortion / Overdrive constants retune accepted

- **Decision.** Accept and deploy the global real-pedal / real-amp
  constants retune on branch
  `feature/global-amp-dist-od-real-pedal-retune-20260525-192457`.
  The edit deliberately touched multiple existing model entries in one
  experiment because the user explicitly allowed the high-risk bulk
  pass and required a recorded rollback to the D67 baseline
  `882a1cfe928a0aabdd02aefa4a8c6c80b0fd7e36`.
- **Scope.** Functional source edits are limited to existing constants
  in `hw/ip/clash/src/AudioLab/Effects/Amp.hs`,
  `hw/ip/clash/src/AudioLab/Effects/Distortion.hs`, and
  `hw/ip/clash/src/AudioLab/Effects/Overdrive.hs`. Existing model
  indices, GPIO control mapping, AXI addresses, helper topology, and
  pipeline shape are unchanged. No `Pipeline.hs`, `LowPassFir.hs`, GUI,
  HDMI, Pmod RTL, `block_design.tcl`, new register, new IIR, helper
  addition, helper swap, helper cascade, or new DSP operation was
  introduced. JCM800 D67 and BD-2 D62 successful entries were preserved.
- **Why.** The goal was not volume-only improvement; it was stronger
  model separation against the documented real references: JC-120
  cleaner/brighter/headroom-first; Twin Reverb glassy and scooped;
  AC30 chime and earlier breakup; Rockerverb thicker/darker; JCM800
  tight upper-mid drive retained; TriAmp Mk3 tighter modern saturation;
  Clean Boost mostly clean; Tube Screamer / TS9 mid-forward and smooth;
  DS-1 harder and more symmetric; Big Muff thicker and sustained;
  Fuzz Face more asymmetric and broken-up; Metal tighter/aggressive;
  RAT thicker and older op-amp style; OD-1 warmer/asymmetric; Jan Ray
  lower-gain transparent; OCD open/dynamic; Centaur smooth low-mid
  push.
- **Build result.** Clash VHDL was regenerated and Vivado completed
  with `write_bitstream completed successfully` and `0 Errors`. Routed
  timing: WNS `-7.333 ns`, TNS `-9235.637 ns`, WHS `+0.051 ns`, THS
  `0.000 ns`; design summary failing endpoints `3595 / 60350`, worst
  path `compLevelPipe_reg[638]/C -> compGain_reg[7]/D`. Utilization:
  LUT `19842`, FF `22246`, BRAM `6`, DSP `83`.
- **Deployment record.** bit/hwh md5 are
  `cabb9bca3fbcc41f06f8b9fe8301cff1` /
  `299485480dcc46aa0c679cef8f1a048a`; all PYNQ board copies matched.
  `AudioLabOverlay(download=True)` updated PL to timestamp
  `2026/5/25 14:20:29 +658847`; ADC HPF True, R19 `0x23`, VERSION
  `0x00480001`, final MODE 3 mute, CLIP_COUNT 0.
- **Smoke / acceptance.** Python py_compile, 91 unittest cases,
  `tests/test_overlay_controls.py`, and `scripts/diagnose_pmod_loopback.py`
  passed. The loopback smoke produced no `QUANT!` / `STAIR!` flags;
  Phase B all-off DSP-chain sweep passed and ended in MODE 3 mute. The
  user then reported external bench PASS for all_off bypass, all Amp
  models, all Distortion models, and all Overdrive models, and asked to
  merge to `main`.
- **Rollback.** The rollback target remains the D67 baseline recorded
  in `docs/ai_context/GLOBAL_RETUNE_ROLLBACK_PLAN.md`: source files,
  regenerated VHDL, bit, and hwh can be restored from
  `882a1cfe928a0aabdd02aefa4a8c6c80b0fd7e36`, redeployed, and
  verified with the documented board md5 / MODE 3 / loopback-smoke
  procedure. D68 is the accepted deployed baseline; D67 is the
  immediate rollback reference and D62 remains the deeper known-good
  reference.

## D69 -- Amp Drive Mode saturation candidate pending bench

- **Decision.** Deploy a bench candidate that strengthens only Amp Sim
  Drive Mode saturation in `hw/ip/clash/src/AudioLab/Effects/Amp.hs`.
  This is not accepted yet; external-instrument bench still decides
  whether it becomes the source-control baseline.
- **Scope.** Functional edits are limited to existing Drive-mode
  constants in `Amp.hs`. Clean-mode tables, Amp OFF routing,
  `amp_model_idx`, `amp_drive_mode` bit allocation, GPIO control
  mapping, AXI addresses, helper topology, pipeline shape,
  `Overdrive.hs`, `Distortion.hs`, `Compressor.hs`, `Pipeline.hs`,
  `LowPassFir.hs`, GUI, HDMI, Encoder, Pmod RTL, and
  `block_design.tcl` are unchanged. No new GPIO, register, IIR,
  helper, cascade, or DSP operation was added.
- **Constants.** The per-model Drive values are:

  | model | `ampDrivePosDelta` | `ampDriveNegDelta` | `ampPreLpfDriveDarken` | `ampSecondStageDriveBonus` |
  | --- | ---: | ---: | ---: | ---: |
  | JC-120 | `16_200` | `13_500` | 6 | 22 |
  | Twin Reverb | `85_800` | `74_100` | 8 | 30 |
  | AC30 | `232_400` | `199_200` | 12 | 42 |
  | Rockerverb | `374_400` | `322_400` | 20 | 62 |
  | JCM800 | `462_000` | `407_000` | 20 | 74 |
  | TriAmp Mk3 | `615_000` | `541_200` | 30 | 88 |

- **Why.** D68 left Drive Mode too close to Clean Mode on the cleaner
  amp models and not saturated enough on Rockerverb / JCM800 /
  TriAmp Mk3. The change lowers Drive-only clip knees and raises the
  Drive-only second-stage gain bonus so Drive Mode sounds closer in
  change magnitude to enabling Overdrive or Distortion, while keeping
  Clean Mode and Amp OFF untouched. The extra Drive-only
  `ampPreLpfDriveDarken` values absorb some high-end fizz from the
  stronger clipping.
- **Fixed-scalar rule.** `ampDrivePosDelta` / `ampDriveNegDelta` remain
  per-model fixed scalars (`Unsigned 3 -> Signed 25`). They are the
  requested `ch * factor` values pre-evaluated at the current
  `ampCharForModel` table (`18 / 78 / 166 / 208 / 220 / 246`) so the
  abandoned D58 runtime-multiplier shape is not reintroduced.
- **Build result.** Clash VHDL was regenerated and Vivado completed
  with `write_bitstream completed successfully` and `0 Errors`. Routed
  timing: WNS `-8.111 ns`, TNS `-9246.014 ns`, WHS `+0.052 ns`, THS
  `0.000 ns`; design summary failing endpoints `3157 / 60278`.
  Utilization: LUT `19717`, FF `22156`, BRAM `6`, DSP `83`.
- **Deployment record.** bit/hwh md5 are
  `6a1834b7f66693f82663c2c8a2fda28b` /
  `927191b506c68588eaae286f4ccce112`; all five PYNQ board copies
  matched the local files. `AudioLabOverlay(download=True)` programmed
  the PL, ADC HPF was True, R19 was `0x23`, VERSION was `0x00480001`,
  and the board was returned to MODE 3 mute after smoke checks.
- **Smoke.** Python py_compile, 91 unittest cases,
  `tests/test_overlay_controls.py`, and
  `scripts/diagnose_pmod_loopback.py` passed. The loopback diagnostic
  produced no `QUANT!` / `STAIR!` flags. A DMA-sine Amp-state smoke
  at 1 kHz / `-12 dBFS` had `clip_d=0` for all_off passthrough,
  Amp OFF with Drive bits ignored, JC-120 Clean, JC-120 Drive, AC30
  Drive, Rockerverb Drive, JCM800 Drive, and TriAmp Drive.
- **Acceptance gate.** Adopt only if the external-instrument bench
  confirms all_off bypass is D68-clean, Amp OFF is quiet, Clean Mode
  is not broken, Drive Mode is audibly stronger on all six models,
  TriAmp Mk3 does not produce pops, and CLIP_COUNT remains normal.
  Until then, D68 remains the accepted rollback baseline.

## D70 -- Cabinet speaker character improvement (bench candidate)

- **Decision.** Deploy a bench candidate that improves cabinet simulator
  resonance, model separation, and speaker compression in
  `hw/ip/clash/src/AudioLab/Effects/Cab.hs`. This is not accepted yet;
  external-instrument bench decides whether it becomes the baseline.
- **Scope.** Functional edits are `Cab.hs` only (coefficient table
  redesign + body-resonance term in `fAcc3L` + per-model `softClipK`
  speaker knee). A secondary fix patches the missing D54 BRAM wrapper
  for `trueDualPortBlockRamWrapper_0.vhdl` (unrelated to Cab; enables
  fresh Vivado builds after `make clean`). No `Pipeline.hs`,
  `LowPassFir.hs`, `Amp.hs`, `Overdrive.hs`, `Distortion.hs`, GUI,
  HDMI, Encoder, Pmod RTL, or `block_design.tcl` change. No new GPIO,
  register, IIR, DSP48, or BRAM.
- **Cab coefficient redesign.** The 4-tap FIR table was rebuilt for
  stronger model separation and Nyquist rejection:

  | Model | c0+c1 : c2+c3 (air 0) | Nyquist resp | Speaker knee |
  | --- | --- | --- | --- |
  | 0 (1×12 open) | 188 : 64 (2.9:1) | -8 (3%) | 5,200,000 |
  | 1 (2×12 combo) | 152 : 110 (1.4:1) | -2 (1%) | 4,200,000 |
  | 2 (4×12 closed) | 88 : 192 (0.46:1) | -32 (11%) | 3,400,000 |

  Previous D69 ratios were 2.2:1 / 1.3:1 / 0.69:1 with Nyquist
  responses of 28 / 20 / -20. All models now have better HF rejection.
- **Body resonance.** `cabProductsFrame` routes body products through
  `satShift8` → `softClipK(cabBodyResKnee)` → `resize << N` into
  `fAcc3L`. At normal levels this is a proportional body boost; at high
  gain the `softClipK` saturates, creating a speaker-cone-compression
  effect. Per-model shift: open `<<5` (subtle), combo `<<6` (moderate),
  closed `<<7` (strong). No new DSP48 — only shifts, comparisons, and
  additions.
- **Speaker saturation.** `cabLevelMixFrame` replaces the fixed
  `softClip` (knee 4,194,304) with per-model `softClipK`: open
  5,200,000 (most headroom), combo 4,200,000, closed 3,400,000
  (tightest compression).
- **BRAM wrapper fix.** `ADAU1761_topEntity_trueDualPortBlockRamWrapper_0.vhdl`
  received the same D54 patch (shared variable → signal + `ram_style
  "distributed"`) that the non-`_0` variant already had. Without this
  patch, `make clean` + fresh rebuild fails with `Unsupported Dual Port
  Block-RAM template`. This is a pre-existing build-infrastructure bug
  unrelated to Cab.
- **Build result.** Clash VHDL regenerated; Vivado completed with
  `write_bitstream completed successfully` and `0 Errors`. Routed
  timing: WNS `-9.413 ns`, TNS `-10233.182 ns`, WHS `+0.051 ns`, THS
  `0.000 ns`; design summary failing endpoints `3219 / 60414`.
  Utilization: LUT `19956`, FF `22260`, BRAM `6`, DSP `83`.
- **WNS delta.** -1.302 ns vs D69 (-8.111). The delta includes both
  the Cab combinational-logic addition and the i2s_to_stream BRAM
  wrapper change (shared variable → signal alters the P&R landscape).
  Bypass-path bench is required before acceptance.
- **Deployment record.** bit/hwh md5 are
  `aab907a4e56260543dc48adb35a3f09f` /
  `f28f08674d25c65a48cd240ae31a578a`; board copies md5-matched.
  `AudioLabOverlay(download=True)` programmed the PL, ADC HPF True.
  `diagnose_pmod_loopback.py` PASS: no QUANT! / STAIR!, CLIP_COUNT 0.
- **Acceptance gate.** Adopt only if the external-instrument bench
  confirms: all_off bypass is D69-clean, Cab model difference is
  clearly audible, high-gain fizz is reduced, low-end is not muddy,
  and CLIP_COUNT remains normal. D69 remains the rollback baseline
  until bench result is reported.

## D71 -- Cabinet multi-band pseudo-IR speaker character (bench candidate)

- **Decision.** Deploy a bench candidate that extends the D70 cabinet
  simulator with a multi-band pseudo-IR blend for stronger speaker
  character and model separation. This is not accepted yet;
  external-instrument bench decides whether it becomes the baseline.
- **Scope.** Functional edits are `Cab.hs` only. No `Pipeline.hs`,
  `LowPassFir.hs`, `Amp.hs`, `Overdrive.hs`, `Distortion.hs`,
  `Compressor.hs`, GUI, HDMI, Encoder, Pmod RTL, or `block_design.tcl`
  change. No new GPIO, register, IIR, DSP48, or BRAM. One `softClipK`
  added (LUT-only) for presence/cone breakup.
- **Changes from D70.**
  1. FIR coefficient table redesigned: sums normalized to 256/260/264,
     Nyquist rejection strengthened (model 0: -8 -> -16, model 2:
     -32 -> -44 at air 0), early:body ratios widened (model 0: 2.76:1,
     model 1: 1.24:1, model 2: 0.42:1).
  2. Presence/cone breakup: `softClipK(cabPresenceKnee)` on the
     saturated early component in `cabProductsFrame`, carried to
     `cabIrFrame` via `fEqLowL` (transient field). Per-model mix:
     open 25%, combo 12.5%, closed 12.5%.
  3. Fizz suppression: `cabIrFrame` computes `input - mainSat` HF
     residual and subtracts per-model fraction (open 12.5%, combo 25%,
     closed 50%). Creates effective H_eff(f) = H(f) + fraction*(H(f)-1)
     that deepens the FIR null near 12 kHz.
  4. Mid body emphasis: per-model extra body in `cabIrFrame` (open 0%,
     combo 6.25%, closed 12.5%).
  5. Speaker compression knees widened: 5.6M / 4.0M / 2.8M (was
     5.2M / 4.2M / 3.4M).
  6. Body resonance knees retuned: 2.4M / 1.6M / 1.2M (was
     2.2M / 1.8M / 1.4M).
- **Speaker references.** Celestion Vintage 30: 70 Hz -- 5 kHz / Fs
  75 Hz. Eminence Man O War: 80 Hz -- 5 kHz / Fs 91 Hz. Design targets
  the 80-5000 Hz guitar speaker passband with resonance at 80-120 Hz,
  box body at 200-400 Hz, cone breakup at 2-4 kHz, sharp rolloff above
  5 kHz, and fizz removal above 8 kHz.
- **Why not real IR.** BRAM budget is 6 tiles and must not increase.
  Even a short 128-tap IR at 48 kHz would need one BRAM tile and 128
  mulS10 taps (or a MAC accumulator pipeline), plus an IR loader and
  AXI DMA path. The pseudo-IR approach uses the existing 4-tap FIR,
  shift-add blending, and softClipK saturation to approximate the
  spectral shaping and speaker compression without any new resources.
- **Build result.** Clash VHDL regenerated; Vivado completed with
  `write_bitstream completed successfully` and `0 Errors`. Routed
  timing: WNS `-9.413 ns`, TNS `-10233.182 ns`, WHS `+0.051 ns`, THS
  `0.000 ns`; design summary failing endpoints `3219 / 60414`.
  Utilization: LUT `19956`, FF `22260`, BRAM `6`, DSP `83`.
- **WNS delta.** 0.000 ns vs D70 (-9.413). The incremental build
  reused D70 placement; P&R converged to the same timing.
- **D71.1 retune.** Grid-search optimization of fizz / presence / body
  fractions against user-supplied per-model target dB tables. Changes:
  M0 presence >>2 -> >>2+>>4 (31.25%), M1 presence >>3 -> 0, M1 fizz
  >>2 -> >>4, M2 fizz >>1 -> >>4, M1 body >>4 -> >>3, M2 body >>3 -> 0.
  Achievable response at Air Mid (1 kHz = 0 dB): M0 5k -1.3 / 8k -3.5 /
  12k -7.8; M1 5k -1.6 / 8k -4.3 / 12k -10.7; M2 5k -1.6 / 8k -4.3 /
  12k -11.1. 8 kHz and 12 kHz match targets within 0.6 dB. 5 kHz for
  M1/M2 is limited by the 4-tap FIR physics (~-1.5 dB max with
  all-positive coefficients at 48 kHz). 250 Hz model differentiation and
  2-3 kHz presence boost require IIR state (Pipeline.hs change,
  currently prohibited).
- **D71.2 retune.** Body darkening (extra body in FIR sum) fixes the
  16-20 kHz non-monotonic bump while maintaining model ordering at
  8 kHz. Air Mid response: M0 -4.4 / M1 -4.7 / M2 -5.1 at 8 kHz;
  all models monotonically decrease through 20 kHz.
- **Deployment record.** bit/hwh md5 after D71.2 are
  `9a739f904aef0955b7e59837a2c33d41` /
  `f28f08674d25c65a48cd240ae31a578a`; board copies md5-matched.
  `AudioLabOverlay(download=True)` programmed the PL, ADC HPF True.
  `diagnose_pmod_loopback.py` PASS: no QUANT! / STAIR!, CLIP_COUNT 0.
- **Acceptance gate.** Adopt only if the external-instrument bench
  confirms: all_off bypass is D69-clean, Cab0/1/2 model difference is
  clearly audible (Cab0 bright+light, Cab1 mid+chime, Cab2 thick+dark),
  high-gain fizz is reduced, low-end is not muddy, 5 kHz+ rolloff is
  sharper than D70, and CLIP_COUNT remains normal. D70 is the rollback
  baseline until bench result is reported.


## D72 - Wah effect on its own AXI GPIO (axi_gpio_wah @ 0x43D30000)

- **Decision.** A dedicated `axi_gpio_wah` IP at `0x43D30000` carries
  POSITION / Q / VOLUME / BIAS + enable for a resonant band-pass wah.
  The Clash side adds a new `wah_control` topEntity port and an SVF
  block between the Compressor output and the Overdrive input. Enable
  lives **inside this GPIO** (`ctrlD` bit 7), not on
  `gate_control.ctrlA` (same convention as the Compressor section,
  `DECISIONS.md` D14).
- **Why.**
  - The Wah needed five distinct knobs (POSITION / Q / VOLUME / BIAS /
    ENABLE). The two currently free bytes in the existing GPIO map
    (`axi_gpio_eq.ctrlD`, `axi_gpio_noise_suppressor.ctrlD`) are
    reserved for future EQ / NS features (`DECISIONS.md` D11), so
    repurposing them would violate D12 ("never repurpose a reserved
    byte for a different feature").
  - `gate_control.ctrlA` (the master flag byte) is already full and
    adding a Wah bit there would change the meaning of an `active`
    byte, which D12 forbids.
  - The Wah benefits from being able to flip its own enable without
    read-modify-write on a shared flag byte; keeping the enable inside
    its own GPIO makes the section fully self-contained.
- **Block-design boundary.** `hw/Pynq-Z2/block_design.tcl` is **not
  edited**. The new GPIO lands via a new `hw/Pynq-Z2/wah_integration.tcl`
  that is sourced from `create_project.tcl` after
  `pmod_i2s2_integration.tcl`, mirroring the additive pattern used
  by `hdmi_integration.tcl`, `encoder_integration.tcl`, and
  `pmod_i2s2_integration.tcl`. The integration script bumps
  `ps7_0_axi_periph/NUM_MI` from 19 to 20 to expose `M19_AXI` for the
  new GPIO, adds the IP at offset `0x43D30000` / range `0x10000`, and
  wires `axi_gpio_wah/gpio_io_o` to `clash_lowpass_fir_0/wah_control`.
- **Topology.** Chamberlin parallel-update state-variable filter
  inside `hw/ip/clash/src/AudioLab/Effects/Wah.hs`:

  ```
    high(n) = in - low(n-1) - qBand(n-1)
    band(n) = band(n-1) + fByte * high(n)
    low(n)  = low(n-1)  + fByte * band(n-1)
    wahOut  = band(n)
    final   = applyVolume(wahOut, volume_byte)
  ```

  Pipeline-level state registers: `wahPosSmooth`, `wahFByteR`,
  `wahQBandR`, `wahLow`, `wahBand`. `wahFByteR` (the `positionToFByte`
  product) and `wahQBandR` (the `q * oldBand` product) are
  pre-registered intermediates; without them the band/low update
  chain contained three DSP48E1 multiplies in series and WNS regressed
  from `-9.413 ns` (D71.2 baseline) to `-18.966 ns` on the first
  Vivado pass. Splitting `positionToFByte` and the q*band product into
  their own register stages restored each subsequent register update
  to one DSP + small adders.
- **Position smoothing.** `wahPosSmoothNext` runs
  `posSmooth + ((target - posSmooth) >> 4)` per audio frame with a
  1-step nudge so a single-byte step still converges. ~0.3 ms per tick
  at fs = 48 kHz; a 64-byte sweep settles in ~20 ms. Off-cycles snap
  to target so a re-enable starts from the visible pedal position.
- **Frequency / Q mapping.** `basePositionToFByte` is a 4-segment
  piecewise linear fit between the spec anchors (pos 0/64/128/192/255
  -> ~350 / 600 / 1000 / 1600 / 2400 Hz at fs = 48 kHz). `qCoefByte`
  maps the UI byte to a damping coefficient in `[16, 128] / 256`
  (~0.063..0.5) with a floor of 16 so the BPF cannot run away at
  maximum Q. `wahVolumeFactor` is a Q8 makeup factor in `[64, 256]`
  (byte 0 -> -12 dB, byte 128 -> ~-2.5 dB, byte 255 -> unity boost
  cap). All arithmetic is fixed-point; no Float / Double, no large
  table -- spec rules followed.
- **Trade-offs not taken.**
  - **No** copying of source code from commercial wah pedals
    (CryBaby GCB-95, Vox V846, Dunlop / Morley Maxon variants),
    schematic-exact coefficient tables, or GPL DSP code (`DECISIONS.md`
    D7 / D11 / D14). Algorithmic structure (resonant band-pass,
    position-driven centre frequency, Q damping, output makeup) is the
    only thing taken from references.
  - **No** large look-up table for position -> frequency. The
    piecewise linear table is 4 segments.
  - **No** FP02M / Arduino A0 wired-in source for POSITION (the
    `wah_source` field is `"manual"` today). The data structure is
    designed so flipping to `"pedal"` is a Python state change with
    no GPIO byte layout impact.
  - **No** C++ DSP prototype as a stepping stone (`DECISIONS.md` D13).
    Implementation went Python API + GUI reservation -> Clash stage
    -> new GPIO directly.
- **Pipeline placement.** Wah sits between `compMakeupPipe` (Compressor
  output) and `odDriveMulPipe` (Overdrive first stage). The chain order
  matches the spec request: Noise Gate -> Compressor -> Wah -> Overdrive
  -> Distortion -> RAT / Pedals -> Amp -> Cab -> EQ -> Reverb.
- **GUI placement.** The compact-v2 800x480 GUI inserts `"Wah"` into
  `EFFECTS` between `"Compressor"` and `"Overdrive"` so the visible
  chain order matches the Clash order. The new `EFFECT_KNOBS["Wah"]`
  has four knobs (POS / Q / VOL / BIAS) arranged in a 2x2 grid. When
  WAH is selected the FX panel renders a `SOURCE: MANUAL` strip
  (instead of a model dropdown) inline at the position where DIST /
  OD / AMP / CAB show their model chip. `AppState.wah_source` is
  persisted in the JSON state file.
- **Python API.** `AudioLabOverlay.set_wah_settings(position=, q=,
  volume=, bias=, enabled=, source=)` is the canonical setter; the
  position scale is dual-mode (0..100 percent -> 0..255 byte for GUI /
  encoder, 101..255 raw passes through for the FP02M future input).
  `set_guitar_effects(wah_enabled=, wah_position=, wah_q=, wah_volume=,
  wah_bias=)` is a convenience facade that delegates to
  `set_wah_settings` so chain-preset callers can flip the wah in the
  same call. The dedicated GPIO word is NOT part of
  `guitar_effect_control_words` -- the wah lives on its own AXI GPIO.
- **Encoder applier.** `EncoderEffectApplier` adds `EFFECT_WAH` to its
  effect dispatch and an `_apply_wah` path that reads
  `AppState.all_knob_values["Wah"]` + `effect_on[2]` and calls
  `overlay.set_wah_settings(...)`. Goes through the public setter
  only -- no raw GPIO writes (D37 rule preserved).
- **HDMI state mirror.** `GUI_EFFECTS` adds `"Wah"` and `GUI_EFFECT_KNOBS`
  gets a `"Wah"` row; `EFFECT_INDEX_BY_SELECTED_FX` adds `"WAH": 2`
  and shifts the other entries (Overdrive 2->3, Distortion 3->4, Amp
  Sim 4->5, Cab IR 5->6, EQ 6->7, Reverb 7->8). The kwarg-prefix
  router learns `("wah_", "WAH")`.
- **How to apply.**
  - When changing the wah voicing, edit the `wah*` block in
    `hw/ip/clash/src/AudioLab/Effects/Wah.hs`. Do not move or rename
    the block; `axi_gpio_wah` and the `wah_control` port are pinned
    by `wah_integration.tcl` and the deployed `.hwh`.
  - Reserved knobs (auto-wah envelope, vintage / modern model select,
    additional bias modes) should land on a new GPIO via a new ADR
    rather than steal bytes from existing GPIOs.
  - The Python `set_wah_settings(...)` API and the byte encoding in
    `control_maps.wah_word` are the source of truth; keep
    notebook / GUI / tests in lock-step.

- **Build / deploy record (after refactor).** Clash VHDL was
  regenerated; Vivado completed with `write_bitstream completed
  successfully` and `0 Errors`. Routed timing: WNS `-10.387 ns`,
  TNS `-12177.222 ns`, WHS `+0.052 ns`, THS `0.000 ns`; design
  summary failing endpoints `3877 / 61321`. Utilization: LUT `21023`
  (+1067 vs D71.2), FF `22691` (+431), BRAM `6` (unchanged), DSP `89`
  (+6 vs D71.2). New top-100 worst paths sit inside the existing DS-1
  distortion section (`ds1_7_reg[154]/C -> ARG__4__0__0_i_4_psdsp/D`);
  no Wah state register chain appears in the top-100. bit/hwh md5
  `eacc4f35bd81c3afcdbb808baa4c8d47` /
  `eaa888985c319841147d1ce73d6601b5`. Python `tests/test_overlay_controls.py`
  passes (22 new Wah tests added); the full `python3 -m unittest
  discover -s tests` count is 92 with the same 3 pre-existing failures
  + 1 pre-existing error as master (no Wah-introduced regressions).
- **Deploy + bench gate.** PYNQ-Z2 at 192.168.1.9 was unreachable
  (ping / ssh timeout) at deploy time, so the 5-site bit/hwh sync,
  `scripts/diagnose_pmod_loopback.py` smoke check, and external-
  instrument bench audition are deferred. D71.2
  (`9a739f904aef0955b7e59837a2c33d41` /
  `f28f08674d25c65a48cd240ae31a578a`, WNS `-9.413 ns`) is the rollback
  baseline until the deploy + bench cycle confirms acceptance.
  Acceptance criteria: (a) all_off bypass D69-clean, (b) Wah OFF
  bit-exact bypass on the cable-loop self-test, (c) Wah ON sweep
  audibly moves the BPF centre frequency, (d) Q 0/50/100 audibly
  changes peak width, (e) VOLUME 50 ~= unity / 100 boosted without
  breakup, (f) BIAS audibly shifts the sweep range,
  (g) `scripts/diagnose_pmod_loopback.py` PASS with no QUANT! /
  STAIR! and CLIP_COUNT 0.

- **Deploy + structural smoke result (D72).** `scripts/deploy_to_pynq.sh`
  pushed the build to all four PYNQ board copies; md5 matched local at
  every site. `AudioLabOverlay(download=True)` programmed the PL,
  ADC HPF reads True (R19 `0x23`), `hasattr(ovl, "axi_gpio_wah")` is
  True. Round-trip `set_wah_settings(enabled=True, position=128, q=60,
  volume=50, bias=55)` produced `word=0xc6809980` with the documented
  per-byte values (`position_byte=128`, `q_byte=153`, `volume_byte=128`,
  `bias_u7=70`, `enable_bias_byte=0xc6`). `set_wah_settings(enabled=False)`
  cleared the enable bit but preserved the other bytes
  (`word=0x46809980`). `scripts/diagnose_pmod_loopback.py` PASS across
  every phase (MUTE / TONE / LOOP / DSP / MUTE all `clip_d=0`; Phase 3
  MODE 0 FFT clean 1 kHz peak with mute at codec noise floor; Phase 5
  DSP-bypass MM2S sweep `uniq1k=1000 maxRun=1` everywhere; Phase B
  DSP all-off MM2S sweep `uniq1k` 996-1000 `maxRun=2` everywhere with
  no QUANT! / STAIR! flag). **Structural smoke: PASS.** External-
  instrument bench audition is still required for full acceptance.

## D73 - Wah Cry Baby retune + position API split + volume curve fix

- **Decision.** Refine the D72 Wah effect to be closer to a Cry Baby
  GCB-95 / 95Q character without touching the DSP topology, the
  axi_gpio_wah layout, or any other effect. Three independent changes
  ship together so we only pay one Vivado rebuild:
  1. **Sweep range retune.** `basePositionToFByte` anchors shift from
     `12 / 20 / 33 / 53 / 80` (the wider D72 ~350..2400 Hz mapping) to
     `15 / 24 / 37 / 53 / 73` (~450..2200 Hz at fs = 48 kHz). The toe
     end drops to 2200 Hz so the upper peak stays in the vocal /
     formant region rather than tipping into ice-picky territory; the
     heel end rises to 450 Hz so the low position is still warm but
     not muddy. Mid-position (pos 192) stays at 1600 Hz so existing
     `BIAS = 50` chain presets still land in roughly the same place.
  2. **Volume curve fix.** D72's `wahVolumeFactor = 64 + (volByte *
     192 >> 8)` produced factor 160 at byte 128 (~0.625x, -4 dB) --
     UI VOLUME=50 was NOT unity, contradicting the spec. D73 replaces
     it with a two-segment piecewise linear curve in an `Unsigned 10`
     factor: byte 0 -> 128 (0.5x, -6 dB taper), byte 128 (UI 50 %) ->
     256 (1.0x unity, the GUI anchor), byte 255 (UI 100 %) -> 510
     (~2.0x, +6 dB boost cap). `wahApplyFrame` switches from `mulU9`
     to a new `mulU10` helper (added to `AudioLab.FixedPoint`).
  3. **Position API split.** D72's `wah_position_byte(value)` used a
     magnitude-based scale detection (`value <= 100` -> percent,
     otherwise raw byte). That breaks the moment a real FP02M /
     Arduino A0 raw byte happens to land in 0..100. D73 splits the
     API into `wah_position_byte(percent)` (always percent) and
     `wah_position_raw_byte(byte)` (always raw); `wah_word`,
     `AudioLabOverlay.set_wah_settings`, and the `set_guitar_effects`
     facade learn `position=` / `position_raw=` as mutually exclusive
     keyword arguments and raise `ValueError` if both are supplied.
     `WAH_DEFAULTS` and `SAFE_BYPASS_DEFAULTS` gain a
     `position_raw: None` entry so the default path stays GUI percent.
- **Why.**
  - User asked for Cry Baby-style focused high end / aggressive,
    vocal-like peak, with a heel that is warm but not muddy and a toe
    that is bright without ice-pick. The D72 mapping landed too wide
    at both ends; the D73 anchors centre the sweep on the Cry Baby
    formant region.
  - User flagged that UI VOLUME=50 was not unity in D72; D73 fixes
    the spec mismatch and widens the top end up to +6 dB so 95Q
    "Volume Boost" style ON-gain compensation is reachable.
  - User flagged that the magnitude-based position API would break
    once FP02M is wired in; D73 separates the percent and raw paths
    so future Pedal input lands on `wah_position_raw` and the GUI
    keeps using `wah_position` cleanly.
- **Boundaries (intentionally NOT touched).**
  - Existing Cab / Compressor / Distortion / Amp / EQ / Reverb voicing
    is byte-exact preserved. `Pipeline.hs` only changes the import
    list (no new stage). `LowPassFir.hs` topEntity signature is
    unchanged.
  - No new GPIO. `axi_gpio_wah` layout, address, and ctrlA..ctrlD
    semantics are byte-exact preserved.
  - No `block_design.tcl` edit. `wah_integration.tcl` is unchanged.
  - DS-1 split / comp-cab-split-v2 are NOT re-introduced.
  - No new DSP48E1: the volume widening from `mulU9` to `mulU10`
    re-uses the existing DSP slice; the position anchor change is
    constants only.
- **Trade-offs not taken.**
  - No envelope-driven auto-wah (would need extra state + DSP).
  - No vintage / modern model selector (would need another byte in
    `axi_gpio_wah.ctrlD`, and bit 7 / 6:0 are already used for enable
    / BIAS).
  - No tone-shaping pre / post the SVF -- the band-pass is still the
    only filter stage in the wah block.
  - The volume cap stays at +6 dB. The user asked the spec allow up
    to +15 dB; D73 deliberately starts at the safer +6 dB because the
    fixed-point Sample range can only absorb 1 bit of overshoot before
    `satWide` starts clipping. A future `wah_boost_range` byte (e.g.
    in a yet-unused part of ctrlD) could widen this without changing
    the multiply width.
- **State reset on OFF (no new code, verified D72 already does it).**
  `wahLowNext`, `wahBandNext`, `wahFByteRNext`, `wahQBandRNext` all
  return 0 when they see a `Just f` with `wahOn=False`. Combined with
  `wahPosSmoothNext` snapping to the target on the same condition,
  an OFF -> ON transition starts from rest -- no filter ring carries
  over from a previous ON cycle.
- **Bypass language softened.** D72 docs claimed "bit-exact bypass
  when the flag is clear." That is misleading because the new
  pipeline registers (`wahPosSmooth`, `wahFByteR`, `wahQBandR`,
  `wahLow`, `wahBand`, `wahApplyPipe`) cost extra cycles vs the
  pre-D72 baseline even when the wah is off. D73 rewrites the
  Wah.hs comments and the DSP_EFFECT_CHAIN.md notes to say
  "value-preserving bypass with added pipeline latency" -- the
  output sample equals the input sample, but only after a
  latency-aligned re-index against the D71.2 reference.
- **How to apply.**
  - Future Cry Baby retunes (vintage / modern band-bias, narrower
    Q sweep, asymmetric heel / toe response) edit the constant tables
    in `Wah.hs` (`basePositionToFByte`, `qCoefByte`, `wahVolumeFactor`).
    Adding a new arithmetic op inside `wahBandNext` / `wahLowNext`
    must re-check WNS -- the D72 first pass regressed by ~9.5 ns
    when the chain accumulated three DSP48E1 in series, and the
    fix was the pipeline split into `wahFByteR` / `wahQBandR`.
  - The Python `set_wah_settings` API is the source of truth; keep
    notebook / GUI / encoder / tests in lock-step.

- **Build / deploy result.** Clash VHDL regenerated; Vivado completed
  with `write_bitstream completed successfully` and `0 Errors`.
  Routed timing: WNS `-10.910 ns`, TNS `-11052.431 ns`, WHS `+0.022 ns`,
  THS `0.000 ns`; failing endpoints `3397 / 61312`. Utilization: LUT
  `20920` (delta `-103` vs D72), FF `22672` (delta `-19`), BRAM `6`
  (unchanged), DSP `89` (**unchanged** -- the `mulU9 -> mulU10`
  widening re-used an existing DSP slice as planned). WNS delta vs
  D72 (-10.387 ns) is `-0.523 ns` -- inside the acceptance band. New
  top-100 worst paths sit inside the existing DS-1 distortion section
  (`ds1_7_reg[784]/C -> ARG__2__2__0_i_1_psdsp/D`); no Wah state
  register chain appears in the top-100, so the D72 pipeline split
  continues to hold with the D73 widened multiply. bit/hwh md5
  `d1343291184d8e3465f735bef8856d38` /
  `aad985fe57b0ff263efc8fc5e09c3c3e`. `scripts/deploy_to_pynq.sh`
  5-site sync md5-matched; `AudioLabOverlay(download=True)`
  programmed PL; ADC HPF True / R19 `0x23`; `set_wah_settings`
  round-trip exercised both paths (`position=50` -> byte 128,
  `volume_byte=128`; `position_raw=200` -> byte 200 with cached
  percent preserved at 50; `position=25 + enabled=False` -> byte 64
  with `position_raw=None` cleared) and the both-paths case raised
  `ValueError` as required. `scripts/diagnose_pmod_loopback.py`
  **VERDICT: PASS** (no bit-crusher / quantization signature in any
  phase). Python 92 tests run with the same 3 pre-existing failures
  + 1 pre-existing error as master; 8 new D73 tests added.
- **Acceptance gate.** External-instrument bench audition is still
  required for full acceptance. Criteria: (a) all_off bypass D72-clean
  (no new artefact vs D72); (b) Wah OFF value-preserving bypass on
  the cable-loop self-test (already passed by `diagnose_pmod_loopback`);
  (c) Wah ON sweep audibly lands inside the Cry Baby GCB-95 mechanical
  range (heel warm but not muddy, mid in the vocal formant region,
  toe focused but not ice-picky); (d) Q 0/50/100 audibly changes
  peak width with the high-Q peak vocal-like; (e) UI VOLUME=50
  audibly unity (no perceptible Wah ON/OFF level jump in mid-range
  picking); (f) UI VOLUME=100 audibly +6 dB without breakup; (g) BIAS
  0/50/100 audibly shifts the sweep range; (h) no pop / click on
  Wah OFF -> ON / ON -> OFF transitions.

- **Bench audition: PASS (2026-05-29).** External-instrument bench
  audition confirmed every D73 acceptance criterion:
  - all_off bypass D72-clean (no new artefact vs D72)
  - Wah OFF value-preserving bypass (already passed structurally by
    `diagnose_pmod_loopback`, confirmed audibly clean)
  - Wah ON sweep audibly lands inside the Cry Baby GCB-95 mechanical
    range: focused high end, warm-but-not-muddy heel, bright-but-not-
    painful toe
  - Q sweep produces a vocal-like peak at high Q
  - UI VOLUME=50 audibly unity (no Wah ON/OFF level jump)
  - UI VOLUME=100 audibly +6 dB without breakup
  - BIAS audibly shifts the sweep range
  - No pop / click on Wah OFF -> ON / ON -> OFF transitions
- **D73 is now the accepted deployed baseline.** D72 (`eacc4f35...` /
  `eaa88898...`, WNS `-10.387 ns`) is the immediate rollback
  baseline; D71.2 remains the deeper known-good rollback reference.
- **Deploy-time side note (not a D73 source change).** During the
  D73 structural smoke, repeated `AudioLabOverlay(download=True)`
  calls re-tripped the rgb2dvi v1.4 PLL 40 MHz VCO lower-bound
  failure documented in user-memory `project_rgb2dvi_pll_edge_at_40mhz`
  and the LCD went black mid-session. A physical cold power-cycle
  of the PYNQ-Z2 restored HDMI; the audio / DSP path was unaffected
  the whole time. Smoke procedure now treats `download=True` as a
  fuse: one call per session, all subsequent attaches use
  `download=False`. The rule is recorded as user-memory
  `feedback_deploy_smoke_avoid_repeated_download`.

## D74 - FP02M expression pedal -> Wah POSITION (software + docs; XADC rebuild deferred)

- **Decision.** Add the software + docs to drive Wah POSITION from a
  ZOOM FP02M TRS expression pedal on Arduino A0, reusing the D73
  `position_raw` byte API. Q / VOLUME / BIAS stay GUI / encoder driven.
  The Wah DSP voicing (D73 Cry Baby), the axi_gpio_wah layout, and every
  other effect are untouched. No timing/comp-cab-split-v2, no DS-1 split.
- **A0 read-path finding (load-bearing).** The deployed overlay has no
  XADC / sysmon IP. The Zynq PS-XADC IIO device (`iio:device0`, driver
  `xadc`) exposes only on-chip rails (vccint/vccaux/vccbram/vccpint/
  vccpaux/vccoddr/vrefp/vrefn + temp) -- no external VAUX, no VP/VN. On
  Zynq-7000 Arduino A0 (Y11) reaches the XADC only as VAUX1 routed
  through the PL. So Linux-IIO (option A) and the existing PYNQ XADC API
  (option B) are both dead on this overlay; reading A0 requires adding an
  AXI XADC Wizard (option C) via an additive `xadc_integration.tcl` +
  Vivado bit/hwh rebuild + timing review. Option D (external MCP3008 over
  Arduino SPI) is the last resort and not pursued.
- **Scope of this pass (approved 2026-05-29).** Ship the software layer
  + docs only; defer the XADC Wizard Vivado rebuild to a separate
  explicit approval. Landed: `audio_lab_pynq/fp02m.py` (calibration /
  IIO reader returning `unavailable` on this overlay / mock reader /
  position mapper / wah controller), `scripts/probe_fp02m_a0.py`,
  `scripts/calibrate_fp02m.py`, `scripts/run_fp02m_wah_test.py`, the GUI
  SOURCE=MANUAL/PEDAL switch + non-blocking pedal update loop in
  `scripts/run_encoder_hdmi_gui.py`, hardware-free unit tests, and the
  `docs/ai_context/FP02M_PEDAL_INTEGRATION.md` /
  `docs/ai_context/XADC_INTEGRATION_DESIGN.md` docs.
- **Deferred (NOT built).** `hw/Pynq-Z2/xadc_integration.tcl` is committed
  as a guarded PROPOSAL (hard-errors unless `XADC_INTEGRATION_APPROVED=1`)
  and is NOT sourced by `create_project.tcl`. No Vivado run, no bit/hwh
  change, no `block_design.tcl` edit. A0 = VAUX1, xadc_wiz proposed at
  `0x43D40000` (M20), clear of the fixed map. See `XADC_INTEGRATION_DESIGN.md`
  for the diff / timing risk before that rebuild is approved.
- **PEDAL-mode correctness rule.** When `wah_source == "pedal"` the
  encoder applier (`encoder_effect_apply.py::_apply_wah`) must NOT pass
  `position=` to `set_wah_settings` (that would clear the cached
  `position_raw`); the pedal controller is the only writer of
  `position_raw`. Q / VOL / BIAS are never overwritten by the pedal path.
- **Safety.** Pedal unconnected / A0 unreadable -> GUI boots MANUAL, no
  crash. PEDAL with no/invalid calibration -> refuse to map, stay MANUAL
  with a warning (no silent fake range). Repeated read errors in PEDAL ->
  auto fall back to MANUAL.

### D74 XADC Wizard build (approved 2026-05-29; built + deployed; pending bench)

- **Decision.** Activate the XADC Wizard so A0 is readable. `create_project.tcl`
  now sources `xadc_integration.tcl` after `wah_integration.tcl` and
  `add_files` `xadc_a0.xdc`. `block_design.tcl` is NOT edited and
  `clash_lowpass_fir_0` is NOT modified (no new Clash port) -- the DSP
  voicing is byte-identical. Additive only: `ps7_0_axi_periph` NUM_MI
  20 -> 21 (M20 = `xadc_wiz_a0 @ 0x43D40000`), VAUX1 enabled, the Vaux1
  analog interface exported and constrained to E17/D18.
- **A0 = VAUX1 = E17(VAUXP1)/D18(VAUXN1), bank 35** -- verified against the
  part (Y11/Y12 are bank-13 digital pins with NO `_AD` XADC capability, so
  the "arduino_a0 = Y11" board entry is the *digital* view only; the analog
  feed uses the dedicated VAUX1 pins). E17/D18 confirmed free (only
  B19/B20 = AD8/AD0 used, for encoder switches).
- **Read path is AXI MMIO, NOT IIO (load-bearing).** The PL `xadc_wiz` is a
  separate access path from the PS-XADC that backs the Linux IIO `xadc`
  device; the PL XADC is not exposed as an IIO channel (still internal
  rails only after the bit loads). So `Fp02mA0Reader` (IIO) stays
  unavailable and a new `Fp02mXadcMmioReader` reads `overlay.xadc_wiz_a0`
  register `0x244` (VAUX1; 12-bit in the top 12 bits). The probe /
  calibrate / runner / bench scripts use the MMIO reader on-board
  (`--mmio`); the runner auto-selects it when `overlay.xadc_wiz_a0` exists.
- **Vivado result.** `write_bitstream` PASS, 0 Errors. WNS `-11.361 ns`
  (delta `-0.451 ns` vs D73 `-10.910 ns`, inside the accepted band),
  TNS `-11083.667 ns`, WHS `+0.051 ns`, THS `0.000 ns`, failing endpoints
  `3565 / 61840`. Worst path `clash_lowpass_fir_0/U0/ds1_7_reg[784]/C ->
  ...psdsp/D` (DS-1 distortion, same section as D73); Wah is NOT the worst
  path and the XADC adds 0 critical paths. Util LUT `21123` (+203), FF
  `22863` (+191), BRAM `6` (unchanged), DSP `89` (unchanged). bit/hwh md5
  `dd3fc09994902abcf34f8819d054205b` / `ef094d0e1a6158a94fc75bb297adfa6b`.
- **Deploy + bench probe.** Deployed 5-site (board bit md5 matches).
  `AudioLabOverlay(download=True)` programmed the PL; ADC HPF True;
  `axi_gpio_wah` and `xadc_wiz_a0` both visible. MMIO sanity: TEMP 12-bit
  `2702` (~59 C), VCCINT `1395` (~1.02 V); VAUX1 raw `~8` with A0 floating
  (~0.006 V -- correct open-input read). `probe_fp02m_a0.py --mmio` returns
  raw values (not unavailable). The A0=GND / A0=3.3V / midpoint checks and
  the FP02M TRS measurement + connection are the user's physical next step.
- **bit/hwh NOT committed** until the bench audition passes (D74 gate):
  all_off bypass clean, Wah OFF clean, Wah ON pedal sweep audibly moves
  the centre frequency, no pop/click/noise, and the existing Cab /
  Compressor / Distortion / Amp voicing unchanged. D73 (`d1343291...` /
  `aad985fe...`) remains the committed rollback baseline (D73 bit backed
  up at `/tmp/d73_backup/`); the D74 build (`dd3fc099...`) is the deployed
  candidate held out of git until bench acceptance.

### D74 XADC bitstream REJECTED on audio (2026-05-30)

- **Outcome.** The D74 XADC build is **not adopted.** FP02M functional path
  works (A0 via MMIO, calibration, `position_raw` write), but bench audio
  showed a **bitcrusher-like distortion in the ADC -> DSP input path**:
  mute clean / tone clean / `dsp all_off` bitcrusher; no output with
  line-in unplugged. Continuous XADC conversion ruled out by the runtime
  CFR1 sequencer-stop test (`xadc_quiet_test.py`; no change in mute).
  Prime suspect = the D74 P&R/placement shift breaking the audio AXIS
  datapath (the D63 pattern), but the decisive D73-vs-D74 `dsp all_off`
  ear A/B was not completed.
- **Engineering note.** DMA bit-capture (`capture_adc_analyze.py`) was
  unreliable here -- re-confirms D65: the loopback/DMA self-test is not a
  substitute for the bench ear for subtle HF/bitcrusher noise.
- **Disposition.** bit/hwh never committed; D73 stays the committed
  baseline. The FP02M software/docs/diagnostic scripts are kept (they are
  bitstream-independent; `position_raw` is Python-side). A future XADC
  re-add must protect the audio AXIS placement (pblock/constraints) or use
  a different ADC route (external SPI ADC). Full write-up in
  `D74_XADC_NOISE_INVESTIGATION.md`.

## D75 - DSP clock-domain island: clash @ 50 MHz, WNS -10.387 -> -0.706 ns

Accepted 2026-05-31 (external-instrument bench: 完璧). Branch
`feature/dsp-multicycle`. Full design record in
`DSP_ISLAND_CLOCK_DESIGN.md`.

- **Problem.** `fxPipeline` (`clash_lowpass_fir_0`) outgrew 100 MHz: a
  45-logic-level CARRY4×36 arithmetic chain in the DS-1 distortion section,
  Data Path ~20.1 ns vs the 10 ns period (WNS -10.387 ns at D72). Every
  other block closes fine at 100 MHz; only the DSP fails.
- **Rejected first.** Stage-splitting the DS-1 chain (WNS unchanged,
  route-dominated) and Frame-width reduction (1067->731 bits, WNS slightly
  worse) do nothing -- logic reduction does not help a route-bound path.
  Global `FCLK0 = 50 MHz` improved WNS to -4.6 ns but **corrupted the
  I2S/Pmod CDCs** (continuous bypass buzz): lowering the whole fabric clock
  breaks the existing clock-domain crossings.
- **Solution (island).** Run **only the DSP at FCLK_CLK1 = 50 MHz**, keep
  everything else (i2s_to_stream / AXIS / DMA / GPIO / Pmod / HDMI) at
  **FCLK_CLK0 = 100 MHz** so the I2S/Pmod CDCs are byte-identical to D72.
  `hw/Pynq-Z2/island_integration.tcl` (additive, sourced after
  `wah_integration.tcl`; `block_design.tcl` NOT edited) enables FCLK1,
  adds `rst_island_50M`, inserts two `axis_clock_converter` (`cc_dsp_in`
  100->50, `cc_dsp_out` 50->100) around the DSP AXIS, and moves
  `clash_lowpass_fir_0/clk` + `aresetn` onto the 50 MHz domain.
- **Two required supporting changes.** (1) `paceCount` removed in
  `AudioLab/Pipeline.hs` (`acceptReady = readyOut`) -- the 16-cycle pace was
  the only frequency-dependent term in the AXIS handshake. (2)
  Control-word CDC synchroniser `syncCtrl` in `LowPassFir.hs` (two FFs +
  2-cycle stability filter) on all 12 control words -- without it, an
  effect/knob write makes the 50 MHz side latch a transient mixed value for
  one sample = **audible click on every switch**. Mandatory.
- **clock_groups.** `audio_lab.xdc` replaces the bclk-only `set_false_path`
  with `set_clock_groups -asynchronous` over all seven domains
  (clk_fpga_0 / clk_fpga_1 / clk 48 MHz Pmod / bclk / mclk 24 / audio_ext
  12.288 / pixel 40). Removes the spurious inter-clock paths -- notably the
  `rst_ps7_0_100M -> pmod_master` reset (`clk_fpga_0 -> audio_ext`) that
  was the -4.2 ns worst path. Known harmless `CRITICAL WARNING [Vivado
  12-4739]` (BD-generated clocks undefined at synth elaboration; applied at
  impl -- confirmed by the worst path moving inter->intra).
- **Result.** WNS **-0.706 ns** (worst now an intra-`clk_fpga_0` AXI-Lite
  GPIO write, harmless, always present under the DSP path), WHS +0.052 ns,
  THS 0; LUT 21286, FF 23968, BRAM 6. bit/hwh md5
  `4a0b3dae1e56574ad596dbd6a3f0c98f` / `347d3e553a8ca96733ee27e904a1d25f`.
  Deployed 5-site; `download=True` after power-cycle PASS; ADC HPF True;
  `axi_gpio_wah` present, `xadc_wiz_a0` absent. **Bench (Pmod mode 2
  ADC->DSP->DAC): all_off bypass clean, no click on effect/knob switching,
  pitch correct, every effect works, GUI + HDMI healthy -- 完璧.**
- **XADC dropped.** `create_project.tcl` xadc lines (xadc_a0.xdc add_files,
  xadc_integration.tcl source) are commented -- D74 XADC put a bitcrusher on
  the ADC path. The DSP voicing (Clash) is unchanged from D73 (Cry Baby
  Wah), so this is a pure clocking/CDC change, not a voicing change.
- **Rollback.** D73 (`d1343291` / `aad985fe`) and D72 (`eacc4f35` /
  `eaa88898`) are full-100 MHz builds recoverable from git history.

## D76 - FP02M expression pedal -> Wah POSITION: XADC re-add on the D75 island (accepted on bench)

Accepted 2026-05-31 (external-instrument bench). Branch
`feature/fp02m-xadc-island-readd`. Builds on D74 (FP02M software/docs) and
D75 (DSP clock-domain island).

- **Decision.** Re-enable the XADC Wizard so Arduino A0 (VAUX1) is readable
  for the FP02M pedal, this time on the D75 50 MHz DSP island. The only
  Vivado change is un-commenting the two `create_project.tcl` lines
  (`add_files xadc_a0.xdc` and `source xadc_integration.tcl`); the Clash
  DSP is NOT touched (voicing byte-identical to D73/D75) and the island
  (`cc_dsp_in`/`cc_dsp_out`, FCLK0=100/FCLK1=50, `set_clock_groups`,
  `paceCount` removal, `syncCtrl` CDC) is preserved. `xadc_integration.tcl`
  is sourced after `wah_integration.tcl` (NUM_MI 20 -> 21, M20 =
  `xadc_wiz_a0 @ 0x43D40000`) and before `island_integration.tcl`; the two
  are independent (island only touches clash / FCLK / axis_clock_converter).
  `block_design.tcl` is NOT edited.
- **D74 bitcrusher did NOT recur (the load-bearing result).** The D74 XADC
  rejection was a bitcrusher on the ADC->DSP input path; the cause was the
  D74 -11 ns / 100 MHz audio-AXIS P&R degradation, not the XADC itself. On
  the D75 island the 100 MHz `clk_fpga_0` fabric (the entire audio AXIS
  datapath) closes with **WNS +0.614 ns and 0 failing endpoints**; the only
  22 failing endpoints are intra-`clk_fpga_1` (50 MHz DSP island, the DS-1
  distortion arithmetic, where D75 already had slack). Overall routed WNS
  `-0.368 ns` (better than D75 `-0.706 ns`), WHS `+0.045 ns`, THS `0`.
  bit/hwh md5 `9fdecae0c7d7cf3c59422cec2b30368f` /
  `a9fd74082482aa1b074fc3c31ccd6283`. **Bench (Pmod mode 2 ADC->DSP->DAC):
  all_off bypass clean -- NO bitcrusher.**
- **Wah-only crossbar routing fix (Python, load-bearing).** The FP02M Wah
  path exposed a latent gap: the AXIS source crossbar
  (`_route_effect_chain`) only switches to `guitar_chain` (the clash DSP)
  when the `gate_word` low byte is non-zero, but the Wah enable lives on its
  own `axi_gpio_wah` ctrlD bit and never reaches `gate_word`. So a Wah-only
  state (every other effect off, the FP02M driving POSITION) left the
  crossbar on `passthrough` and bypassed the whole DSP -- the Wah included
  (clean sound, no wah). Fix in `AudioLabOverlay.py`: (1)
  `_route_effect_chain` treats an enabled Wah as "an effect is on", and (2)
  `set_wah_settings` re-routes the crossbar when (and only when) it toggles
  the Wah enable (not on the 100 Hz `position_raw` stream). Python-only, no
  bit rebuild. This was never caught before because D74's XADC bit was
  rejected on audio before the Wah-sweep audio test was completed.
- **Wah Q self-oscillation cap (Python).** At high Q the resonant band-pass
  self-oscillates near full POSITION (toe). Bench: Q byte 89 (old UI 35 %)
  clean at the toe extreme, byte 128 still howled, byte 166 (UI 65 %)
  howled hard. `control_maps.wah_q_byte` now caps the UI Q range at
  `WAH_Q_BYTE_MAX = 80` (UI keeps 0..100; only the top of the dial is
  tamed) -- below the proven-clean byte-89 point with margin. Bench: Q = 100
  + full toe no longer self-oscillates. The Clash Wah voicing is unchanged
  (this is purely the UI->byte map). `tests/test_overlay_controls.py`
  anchors updated.
- **Calibration (bench).** TRS candidate 1 (Tip->A0, Ring->3.3V,
  Sleeve->GND). FP02M A0 via `Fp02mXadcMmioReader` (overlay `xadc_wiz_a0`
  register `0x244` = VAUX1). heel raw ~8, toe raw ~2847, sweep span ~2999
  (no stuck), invert false, deadband 2, smoothing_alpha 0.25. Saved at
  `/root/.config/audio_lab/fp02m_calibration.json` (sudo HOME, on-board
  only, not in the repo).
- **GUI follow-ups (bench, Python-only).** (1) **SOURCE now cycles like a
  model.** The encoder-2 button toggle for Wah SOURCE (MANUAL/PEDAL) was not
  reliable/discoverable, so "Wah" joined `MODEL_EFFECTS` in
  `encoder_ui.py` and `_cycle_model_index` cycles `wah_source` manual/pedal
  -- encoder-1-hold + rotate flips SOURCE with the exact same gesture as an
  amp/cab/pedal model dropdown. The encoder-2 button toggle stays as a
  secondary path. (2) **PEDAL no longer shows UNAVAIL in the Pmod HDMI GUI.**
  `PmodI2S2HdmiGuiOneCell.ipynb` spawned the runner without `--wah-pedal`, so
  the FP02M controller was never created and `wah_pedal_available` stayed
  False; the notebook's `RUNNER_CMD` now includes `--wah-pedal` (the runner
  smart-attaches with `download=False`, so restart does not knock the rgb2dvi
  PLL). User bench: SOURCE cycles, PEDAL drives POSITION, no UNAVAIL.
- **Live-GUI latency fix (bench, "かなりいい"). Root cause: pynq IP-attr IPC.**
  The encoder/pedal UI felt very sluggish (both the on-screen value and the
  audio). Profiling on the board (`cProfile`) showed the cost was NOT MMIO
  (a raw `gpio.write` is ~0.03 ms) but **pynq's `Overlay.__getattr__`**, which
  runs `is_loaded()` -> `bitfile_name` -- a multiprocessing IPC to the PL
  server -- on EVERY `self.<ip>` access (~50 ms each on the PYNQ-Z2).
  `set_guitar_effects` touches ~12 IP handles = **~940 ms/call**;
  `set_wah_settings` ~2 = **~100 ms/call**. Fix: `AudioLabOverlay.__init__`
  now calls `_cache_ip_handles()`, which resolves every top-level IP once and
  stashes the handle in `self.__dict__` so later reads hit normal attribute
  lookup and never invoke `__getattr__`/IPC. Measured: `set_guitar_effects`
  941 -> **2.6 ms**, `set_wah_settings` 99 -> **0.5 ms**. Secondary GUI
  changes in `run_encoder_hdmi_gui.py`: (a) the HDMI render (~310 ms/frame on
  the ARM) moved onto a **daemon thread** so it no longer blocks the
  encoder/pedal/apply loop (PIL/numpy release the GIL during their C work, so
  audio applies slip through); (b) a **persistent `make_pynq_static_render_cache()`**
  is passed to every render -- glow off, text/gradient memoised, and the whole
  frame returned from cache when the AppState signature is unchanged (idle
  render 313 -> **0.5 ms**); (c) defaults `--poll-hz-active` 30 -> 60 and
  `--apply-interval-ms` 50 -> 20. Net: audio/pedal response ~instant, idle UI
  instant; a held continuous knob spin still repaints at ~6 fps (the ARM PIL
  compose cost) but the audio follows in ~20 ms. A LUT rewrite of the
  scanline/vignette kernels was tried and **reverted** -- numpy fancy-index
  gathers were slower than the float path on the Cortex-A9.
- **Wah pedal "C" taper (bench, "完璧"). Python-only.** The FP02M pedal sweep
  felt wrong with a linear position map. `Fp02mCalibration` gained a
  `position_curve` field (default `"c"`) and `Fp02mPositionMapper.raw_to_u8`
  applies `_apply_position_curve` so the pedal-travel fraction is shaped by a
  pot-style taper before scaling to the POSITION byte. `"c"` = anti-log /
  reverse-audio = `1 - (1 - x)**WAH_C_CURVE_GAMMA` (gamma 2.5): the centre
  frequency rises fast off the heel then fine-resolves toward the toe (heel/toe
  endpoints stay 0/255). `"linear"`/`"a"` also selectable; the field persists
  in the calibration JSON and a legacy JSON without it defaults to `"c"`, so
  the existing on-board calibration (raw 8..2847) picks up the curve with no
  re-cal. Scope: the FP02M pedal path only -- the GUI POS knob / encoder stay
  linear. The Clash Wah DSP is untouched (no bit rebuild).
- **Deploy.** bit/hwh `9fdecae0...` / `a9fd7408...` synced 5-site (md5
  match). `download=True` once after a cold power-cycle (memory
  `feedback_deploy_smoke_avoid_repeated_download`); further attaches use
  `download=False`. Smoke: `xadc_wiz_a0` present, ADC HPF True,
  `axi_gpio_wah` present, HDMI VTC present. New committed baseline,
  superseding D75.
- **Rollback.** D75 (`4a0b3dae` / `347d3e55`, no-XADC island) and D73
  (`d1343291` / `aad985fe`, full-100 MHz) recoverable from git history. To
  drop the XADC again, re-comment the two `create_project.tcl` lines and
  rebuild.

## D77 - Refactoring pass: control-maps word builders, Pmod-status helper, renderer split, defaults single-source (Python-only, byte-identical)

Done 2026-05-31. Branch `refactor/guitar-effect-control-words` (built on the
D76 doc-sync). A behaviour-preserving cleanup pass. **No bitstream rebuild,
no GPIO address/layout change, no Clash voicing change; the deployed bit
stays D76 (`9fdecae0` / `a9fd7408`).** Every byte that reaches the FPGA on
the live path is unchanged, locked by the `test_overlay_controls`
golden word-dict snapshots; the compact-v2 renderer output is pixel-identical
(md5 over 14 `AppState` variants). The Python test suite stays at the
pre-existing 3 failures + 1 error baseline.

- **#5 Pmod status single source.** New `audio_lab_pynq/pmod_i2s2_status.py`
  owns the `axi_pmod_i2s2_status` register map, the `MODE_INT` table,
  `sign24`, and the `find_status_mmio(overlay=None)` IP-discovery dance.
  `scripts/pmod_i2s2_mode.py` and `scripts/run_encoder_hdmi_gui.py` delegate
  to it (lazy `pynq` import keeps the board-only CLIs importable off-board).
  `scripts/test_pmod_i2s2.py` keeps its own semantically-named constants
  (HW-only validation, not worth the churn).
- **#4 compact-v2 renderer split.** Extracted `_draw_cv2_header` /
  `_draw_cv2_chain` / `_draw_cv2_corner_markers` / `_draw_cv2_encoder_status`
  from the 418-line `_render_frame_800x480_compact_v2` (now ~293 lines). The
  complex FX panel (model dropdown + per-effect knob grid + WAH SOURCE strip)
  stays inline.
- **#7 retired PCM scripts.** Moved `test_pcm1808_adc_to_pcm5102.py` /
  `test_pcm5102_dac_tone.py` / `test_pcm5102_dsp_output.py` to
  `scripts/legacy/` (the PCM1808/PCM5102 path was retired at D48) and
  documented them in the legacy README. Not staged by `deploy_to_pynq.sh`.
- **#2 word-builder consolidation + reverb layout fix.**
  `control_maps` gains `reverb_word` / `eq_word` / `rat_word` / `cab_word`;
  `guitar_effect_control_words` delegates to them (the reverb / EQ / RAT /
  cab GPIO words were packed inline before). **Reverb layout was verified
  against the Clash source** (`AudioLab.Effects.Reverb`): the feedback
  multiply is `mulU8(monoWet, ctrlA)`, tone reads `ctrlB`, mix reads
  `ctrlC`, and on/off is `flag5(fGate)`. So the hardware word is
  **ctrlA = DECAY, ctrlB = TONE, ctrlC = MIX, ctrlD unused, ENABLE on
  gate_control flag5** -- which is exactly what the live
  `set_guitar_effects` path (`_pack3(decay, tone, mix)` + gate flag5)
  already wrote. The legacy `AudioLabOverlay.reverb_control_word` packed an
  enable bit into ctrlA and shifted DECAY/TONE/MIX up one byte each -- a
  layout that did NOT match the Clash decode. It is only reached on the
  fallback path for an overlay WITHOUT `axi_gpio_gate` (the deployed bit
  always has the gate, so `set_reverb` delegates to `set_guitar_effects`),
  so this was a dead-path bug, not a live one; `reverb_control_word` now
  delegates to `control_maps.reverb_word`. `GPIO_CONTROL_MAP.md` reverb row
  corrected to match the Clash truth (it previously claimed ctrlA = enable).
- **#3 defaults single-source.** `guitar_effect_control_words` now sources
  every per-effect knob default from the `effect_defaults` dicts
  (`_DISTORTION_DEFAULTS` / `_OVERDRIVE_DEFAULTS` / `_RAT_DEFAULTS` /
  `_AMP_DEFAULTS` / `_CAB_DEFAULTS` / `_EQ_DEFAULTS` / `_REVERB_DEFAULTS`).
  This fixed a latent mismatch: the distortion signature defaults were
  `65/100/25` while `DISTORTION_DEFAULTS` (and the cached `_dist_state` the
  live path uses) is `50/35/20`. **No production audio impact** --
  `set_guitar_effects` always cache-merges the distortion bytes from
  `_dist_state` before calling the packer, and `set_reverb` discards the
  distortion word, so the old `65/100/25` only ever surfaced on a direct
  no-arg packer call. The 6 no-distortion-arg golden snapshots were updated
  (`distortion` `0x004080a6 -> 0x00332d80`) to reflect the value users
  actually get. `noise_gate_threshold` keeps a literal (legacy gate
  threshold, distinct from the NS threshold).
- **Assessed, not actioned.** #1 (byte-helper dedup) was already done -- the
  `AudioLabOverlay._percent_to_u8` / `_pack3` etc. already delegate to
  `control_maps`. #6 (shared script bring-up helper) had insufficient real
  duplication (3 divergent strategies) to justify migrating board-only
  scripts that cannot be validated off-board.
- **Tests.** New: 3 reverb-layout tests + a defaults==effect_defaults guard
  in `test_overlay_controls.py`.
- **Deploy.** Python-only; `deploy_to_pynq.sh` run (no `download=True`, PL
  not reprogrammed). On-board verified: `control_maps.reverb_word(30,65,20)
  == 0x0026a642`, `reverb_control_word` delegates, default distortion word
  `0x00332d80`, the new `control_maps` word builders present.

## D78 — 3 footswitches for FX toggle + preset stepping (axi_footswitch_input)

- **Decision (final).** Add three guitar-pedal 3PDT footswitches on the
  **Raspberry Pi header**, read by a new self-contained PL IP
  `axi_footswitch_input` at AXI-Lite base `0x43D50000` (M21). Roles / pins:
  `fsw0_i` = FX toggle = `U7` = `rpio_17` = GPIO17 = **RP pin 11**; `fsw1_i` =
  preset next = `C20` = `rpio_18` = GPIO18 = **RP pin 12**; `fsw2_i` = preset
  prev = `Y8` = `rpio_19` = GPIO19 = **RP pin 35**. GND = any RP GND pin
  (6/9/14/20/25/30/34/39). Physical pin numbers verified from the official
  PYNQ-Z2 master XDC schematic net names (`Sch=rpio_NN_r`, NN = BCM GPIO; see
  `project_pynqz2_rp_header_silk_not_package_pin` memory + FOOTSWITCH_INTEGRATION.md).
  (An interim PMOD-JA placement `JA1/JA2/JA7` = Y18/Y19/U18 was built and
  bench-validated, then moved to the RP header per user request.)
- **Audio-integrity fix (load-bearing).** Adding the footswitch AXI master
  (M21) perturbed the P&R of the 50 MHz DSP island and pushed the DS-1
  distortion CARRY4 arithmetic from the D76 baseline (-0.368 ns) to ~-0.75 ns,
  producing an **audible bitcrusher on the ADC->DSP->DAC path** (the D74-class
  artifact) -- confirmed by an A/B: rolling the board back to D76 made the
  noise vanish. Fix: enable post-place + post-route `phys_opt_design`
  (AggressiveExplore) on `impl_1` in `create_project.tcl`. That clawed the
  DS-1 island slack back to **-0.173 ns (better than D76)** with the 100 MHz
  audio fabric still clean (+0.683 ns, 0 failing); bench audio then verified
  clean. **Lesson:** an additive AXI master can degrade the DSP-island timing
  enough to bitcrush even when static timing looks fine and the pin choice is
  irrelevant; phys_opt recovers it. Accepted bit md5 `45e78763` (the RP-pin
  build); the no-phys_opt builds (`e610dc58` PMOD-JA, `199d25ea` RP) bitcrush
  and are rejected.
- **Why a new IP / bit rebuild.** Hands-free live control. There is no spare
  *input* path in the D76 bitstream (the encoder IP's 9 inputs are all
  encoder-owned, every effect GPIO is output), so reading new physical pins
  requires a bit rebuild regardless. (Interim PMOD-JA rationale, retained:
  the PMOD silk `JA1/JA2/JA7`
  names the exact pin and GND/3.3V sit on the connector. An earlier attempt
  used the RP spares (`raspberry_pi_tri_i_15/16/17` = `U7/C20/Y8`), but the
  RP 40-pin header's BCM "GPIOxx" silk does NOT match those package pins, and
  a bench test wiring to silk "GPIO17" hit a wrong (LED-affecting) net. PMOD
  JA is otherwise unused (encoders on RP `..._6..14`, PMOD JB = Pmod I2S2),
  so no conflict; `JA3/JA4` (`Y16/Y17` = RP HAT-ID I2C) are avoided.
- **Latching switch handling (load-bearing).** A true-bypass 3PDT is an
  *alternate-action* (latching) switch -- each stomp flips the contact, so
  the debounced logic level toggles 0<->1 per press. The IP therefore
  latches one `press_event` on *either* edge of the debounced level; the
  absolute level is irrelevant. This is the key difference from the encoder
  SW path (momentary active-low). Wiring: common -> GPIO, one throw -> GND,
  the other throw open with `set_property PULLUP true`. Never wire to 5V
  (D31).
- **Additive integration only.** `footswitch_integration.tcl` (modeled on
  `encoder_integration.tcl`) bumps `ps7_0_axi_periph` NUM_MI 21 -> 22, adds
  the module-reference cell `fsw_in_0`, wires AXI-Lite from M21 + the 3 ports,
  and maps `0x43D50000 / 0x10000`. Sourced from `create_project.tcl` AFTER
  `xadc_integration.tcl` and BEFORE `island_integration.tcl`. The IP lives on
  the 100 MHz fabric (FCLK_CLK0), NOT the 50 MHz DSP island, so D75/D76 are
  unaffected and `block_design.tcl` is not edited. Clash is unchanged, so the
  DSP voicing stays byte-identical -- no Clash/Vivado DSP regeneration.
- **FX-target binding.** FS1 toggles the effect bound in
  `AppState.footswitch_fx_target` (persisted). To rebind, select the desired
  effect in the GUI (encoder 0) and stomp FS1 5 times within 3 s; the burst
  rebinds to `selected_effect` and leaves the old target's on/off unchanged
  (5 is odd, the 4 prior toggles net back, the rebind press does not toggle).
  Single press = immediate toggle (a stomp must feel instant), so a
  deliberate rebind burst briefly flickers the old target -- accepted.
- **Translation discipline.** FX toggle rides
  `EncoderEffectApplier.apply_effect_on_off` (single-enable write -- preserves
  a curated preset voicing, same applier the encoder uses). Preset stepping
  calls `AudioLabOverlay.apply_chain_preset(name)` (the bench-tested notebook
  path) for the authoritative audio write, then mirrors the preset into
  `AppState` for the HDMI GUI via
  `footswitch_control.apply_chain_preset_to_state`. Preset cycle = all
  `CHAIN_PRESETS` in insertion order (wraps).
- **Software.** `audio_lab_pynq/footswitch_input.py` (driver, mirrors
  `encoder_input.py`), `audio_lab_pynq/footswitch_control.py`
  (`FootswitchController` + preset->state mirror), `AppState.footswitch_fx_target`
  (persisted, default Amp Sim=5), and a non-blocking footswitch poll in
  `scripts/run_encoder_hdmi_gui.py` (`--footswitch` default on,
  `--no-footswitch`, `--footswitch-debounce-ms`, `--footswitch-debug`) placed
  next to the FP02M pedal poll so every overlay write stays single-threaded.
- **Status (ACCEPTED 2026-06-01).** Built (bit `45e78763` with the phys_opt
  fix), deployed 5-site, and **bench-accepted by the user**: footswitches on
  RP pins 11/12/35 work (FS1 FX toggle, FS2/FS3 preset stepping) and the
  ADC->DSP->DAC audio is clean. 21 new offline tests pass (no regression vs
  the pre-existing 2-failure baseline). Merged to `main` (`feat(#D78)`
  813029b + merge aa4080f). **D78 (`45e78763`) is the new accepted deployed
  bitstream baseline, superseding D76** (`9fdecae0`, the rollback baseline).
  The two pre-phys_opt builds (`199d25ea` RP, `e610dc58` PMOD-JA) bitcrush
  and are rejected. Full reference: `docs/ai_context/FOOTSWITCH_INTEGRATION.md`.

## D79 — Overdrive realism: per-model clip hardness (item 4) + Klon clean-blend (item 5a)

- **Decision.** Two model-realism improvements to the dedicated Overdrive
  effect, merged together (item 5a builds on item 4; both are CENTAUR/Klon and
  per-model voicing work). From `MODEL_REALISM_GAP_ANALYSIS.md` /
  `MODEL_REALISM_IMPLEMENTATION_GUIDE.md`. Accepted bit md5 `f0cb0276` (hwh
  `5fa0b84e`).
- **Item 4 — per-model clip hardness.** The six Overdrive models now differ in
  clip *hardness* (compression slope = harmonic order), not only in knee level.
  `FixedPoint.asymSoftClipSoft/Med/Hard` are fixed-compile-time-shift siblings
  of `asymSoftClip` (slopes 1/8..1/2); `Overdrive.odClipHardness` selects one
  per model via a 4:1 result mux (TS9/JanRay/Klon soft, OD-1/BD-2 medium =
  legacy shape, OCD harder MOSFET knee). Constant shifts are wiring — no new
  DSP48, no barrel shifter, no register stage. Medium-class models stay
  byte-identical; bit-exact bypass preserved.
- **Item 5a — Klon/CENTAUR clean-blend.** Model 5 (CENTAUR) now mixes a parallel
  unclipped clean path with the clipped path (the Klon's defining mechanism);
  GAIN/DRIVE raises the clipped proportion. `overdriveDriveClipFrame` stashes
  the pre-clip clean sample in `fAcc3L` (unused by the OD tone stages, survives
  to the level stage); `overdriveLevelFrame` blends with a **two parallel
  `mulU8`** weighted sum (`odCleanBlend`: clipped weight rises with DRIVE, floor
  64, capped so a clean slice always remains). Other models keep `fAcc3L=0` /
  `wetForLevel = monoWet` → byte-identical.
- **Timing (load-bearing lesson).** Item 4 closes at island WNS **-0.173 ns**
  (= D78, no cost). Item 5a's blend lands at **-0.496 ns** / 32 fail (all
  intra-DS-1 CARRY4, audio fabric clean +0.532 / 0 fail) — worse than D78
  (-0.173) but **better than the bench-"perfect" D75 (-0.706)**, and phys_opt
  (D78) is already on. **A one-multiply LERP rewrite was built and REJECTED at
  -3.627 ns / 117 fail**: the serial subtract→multiply→shift→add chain
  lengthens the DS-1 path, whereas two *parallel* multiplies route better (same
  rule as Wah — never serialise island multiplies). The committed 5a is the
  2-mul parallel form.
- **Build env note.** The dev `clash` fails standalone (stray
  `clash-prelude-1.8.2` in the cabal store makes the package ambiguous); build
  with `CLASH_FLAGS="-package-id clash-prelude-1.8.1-043657e6... -isrc --vhdl"
  make Pynq-Z2`. `make clean` deletes the git-tracked `hw/ip/clash/vhdl/` +
  `hw/Pynq-Z2/bitstreams/`; restore with `git checkout --`.
- **GPIO / API.** None changed — re-voicing reuses existing OD knobs and the
  model select. Python golden tests unchanged (same 3F+1E pre-existing baseline
  as `main`, no regression).
- **Status.** Built, deployed 5-site (`f0cb0276`), loaded on the board, Pmod
  mode 2, **bench-accepted by the user** (all_off clean, no bitcrusher).
  **D79 (`f0cb0276`) is the new accepted deployed bitstream baseline,
  superseding D78** (`45e78763`, the rollback baseline). Items 5b (Fuzz/amp
  bias-sag) and 3 (biquad tone stacks) remain spec-only in the guide. Branches:
  `feature/realism-clip-hardness` (item 4) and `feature/realism-klon-clean-blend`
  (item 4+5a, merged here).

## D80 — Python-only real-hardware knob taper + preset polish

- **Decision.** Treat GUI / encoder / preset numbers as **physical knob
  positions**, and convert them to the existing linear overlay/GPIO percent API
  at the UI boundary. The low-level `AudioLabOverlay.set_guitar_effects()` and
  `set_distortion_settings()` contracts stay linear and byte-compatible; the
  new conversion lives in `audio_lab_pynq/knob_tapers.py`.
- **Taper shape.** Gain/drive-style controls use a conservative audio taper
  (`GAIN_TAPER_GAMMA = 1.45`), so noon is edge-of-breakup rather than already
  high gain. Tone-style controls use a mild centre-preserving table
  (`0 -> 0`, `25 -> 30`, `50 -> 50`, `75 -> 70`, `100 -> 100`). Level, mix,
  compressor makeup, and EQ values remain linear so the existing preset safety
  bands still mean what the tests and docs say.
- **Where it applies.**
  - `AudioLabOverlay.apply_chain_preset(name)` tapers a deep copy of
    `effect_presets.CHAIN_PRESETS` immediately before writing hardware.
    `get_chain_preset()` still returns the raw knob-position spec so GUI /
    footswitch mirroring stays user-facing.
  - `EncoderEffectApplier.apply_appstate()` and `GUI/audio_lab_gui_bridge.py`
    taper live knob writes before calling the overlay.
  - Direct API scripts that call low-level setters keep the old linear mapping.
- **Preset retune.** Distortion / chain preset DRIVE and Amp GAIN positions were
  raised where needed so their tapered hardware values land near the previously
  practical voicing while the displayed knob positions feel closer to real
  pedals. Distortion `level <= 35` and Compressor `makeup 45..60` contracts are
  unchanged.
- **Scope.** Python only. No Clash, VHDL, Tcl, XDC, `block_design.tcl`, bit, or
  hwh change. D79 remains the deployed bitstream baseline; no timing summary is
  required for D80.
- **Tests.** `python3 tests/test_overlay_controls.py`,
  `python3 tests/test_encoder_effect_apply.py`,
  `python3 tests/test_hdmi_gui_bridge.py`, and
  `python3 tests/test_footswitch_control.py` pass.

## D81 — Resonant tone stack (item 3 / R3): Tube Screamer ~720 Hz mid-hump biquad

- **Decision.** Land the first resonant-biquad tone shape (realism roadmap
  item 3 / R3) on a single high-value target: the Tube Screamer's signature
  ~720 Hz **mid hump**. A one-pole tilt (the only filter shape used so far)
  cannot make a resonant mid peak; a 2nd-order peaking biquad can. This proves
  the shared-biquad infrastructure before extending to Big Muff notch / amp
  family stacks.
- **Placement.** A new `tubeScreamerMidFrame` stage sits **pre-clip**, between
  the existing input HPF and the drive multiply (Pipeline: `tsHpfPipe ->
  tsMidPipe -> tsMulPipe`). Pre-clip emphasis is what makes the TS mid-focused:
  the boosted ~720 Hz band is driven harder into the clip than the rest of the
  spectrum. It is *added*, not a replacement — the dark post-LPF that tames
  fizz is unchanged.
- **Filter.** Direct-form-I peaking biquad, hand-designed target curve
  (f0 = 720 Hz, fs = 48 kHz, Q = 0.8, +6 dB) — NOT a schematic-derived table
  (D7/D45 policy). Unity at DC and Nyquist by construction, so the spectrum
  outside the hump is essentially unchanged (verified: DC -0.06 dB, peak
  +6.01 dB @ 720 Hz, Nyquist 0 dB, pole radius 0.959 = stable).
- **Fixed-point.** New `FixedPoint.mulS16` (Sample x Signed 16 -> Wide) and
  `satShift14`. A low normalised frequency makes b1/a1 ~= -1.91, whose DC gain
  depends on tiny differences — **Q8 (mulS10) rounding collapses the passband
  to 0.67x; Q14 holds it** (coeffs b0=17036 b1=-31323 b2=14422, a1=-31323
  a2=15075). The five multiplies are summed in **parallel** (adder tree), not a
  serial chain — the D79/Wah island-timing lesson.
- **State.** `x1/x2/y1/y2` are pipeline-level registers (the cab delay-tap +
  RAT prevIn/prevOut idiom), so idle `Nothing` cycles preserve filter memory.
  **Bit-exact bypass** when the pedal is off (output = input). No Frame slot,
  no GPIO, no API change — only the TS pedal voicing changes; all other
  pedals/models are byte-identical, and Python golden tests are unchanged.
- **Timing (built, deployed, bench-accepted).** bit md5
  `3a79745ffad8b72531a22587b5bcd3a1`, hwh `a9b582634489170c16c2876388546aa4`.
  Routed: island (`clk_fpga_1`) **WNS -0.193 ns** / 36 fail (all intra-DS-1
  CARRY4, no biquad path in the top set), audio fabric (`clk_fpga_0`)
  **+0.657 ns / 0 fail**, WHS +0.036, THS 0. DSP 95 (+6 ≈ the 5 biquad
  multiplies), BRAM 6, LUT 22032, FF 24594. **Better than D79** (island
  -0.496) and ~= D78 (-0.173) — the biquad added no meaningful timing cost.
  `phys_opt_design AggressiveExplore` on as of D78.
- **Bench.** Pmod mode 2 (ADC -> DSP -> DAC): all_off bypass clean (no
  bitcrusher), Tube Screamer mid hump audible / mid-focused drive, other
  pedals unchanged — **user-confirmed accepted**. D81 (`3a79745f`) is the new
  accepted bitstream baseline, superseding D79 (`f0cb0276`, rollback at
  `/tmp/d79_backup` and in git history).
- **Files.** `hw/ip/clash/src/AudioLab/FixedPoint.hs`,
  `hw/ip/clash/src/AudioLab/Effects/Distortion.hs`,
  `hw/ip/clash/src/AudioLab/Pipeline.hs`; regenerated `vhdl/LowPassFir`;
  `bitstreams/audio_lab.{bit,hwh}`. Branch
  `feature/realism-tone-stack-biquad`.

## D82 — Resonant tone stack (item 3 / R3): Big Muff ~700 Hz mid-scoop notch biquad (pipeline-split)

- **Decision.** Second R3 resonant biquad: the Big Muff's defining **mid-scoop
  notch**. A one-pole LPF (the existing `bigMuffToneFrame`) can only darken; a
  peaking biquad with negative gain carves the scoop. Single pedal, single
  biquad (no per-model mux yet).
- **Placement.** New stages between Big Muff clip2 and the tone LPF
  (`bigMuffClip2Pipe -> scoop -> bigMuffTonePipe`). Post-clip so the scoop is
  carved out of the saturated signal. Added, not a replacement; the dark tone
  LPF stays.
- **Filter.** Direct-form-I peaking biquad, hand-designed target (f0 = 700 Hz,
  fs = 48 kHz, Q = 0.8, **-10 dB** dip; NOT a schematic table, D7/D45). Q14
  coeffs (b0=15350 b1=-29618 b2=14393, a1=-29618 a2=13359) via the D81
  `mulS16`/`satShift14`. Verified: DC -0.00 dB, notch -10.00 dB @ 700 Hz,
  Nyquist 0 dB, pole radius 0.903 stable. No GPIO/API/Frame change; only Big
  Muff voicing changes, all other pedals byte-identical, Python golden tests
  unchanged.
- **Timing — pipeline split (load-bearing).** The single-stage 5-multiply form
  measured island WNS **-0.659 ns** (74 fail, biquad feedback path near-critical
  and pressuring the DS-1 P&R; `scoop` appeared 62x in the worst-100). An IIR
  feedback loop **cannot be naively pipelined** (it changes the transfer
  function), so the fix splits the biquad: a **feedforward** stage precomputes
  `b0*x + b1*x1 + b2*x2` into `fAcc3L` (no feedback, freely pipelined), and a
  **recursive** stage closes the loop with only `-a1*y1 - a2*y2` (two multiplies,
  shorter single-cycle feedback path). Math is identical (same coefficients /
  response). Result: island WNS **-0.534 ns** / 56 fail, TNS -17.195 (from
  -27.887), **`scoop` 0x in the worst-100** (biquad off the critical set; the
  worst path is pure DS-1). The residual -0.534 vs D81 -0.193 is the cost of
  +5 DSP placement pressure on the DS-1 path, not the biquad itself.
- **Built, deployed, bench-accepted.** bit md5
  `ee295544e2e2caf22d5a3904aea045a1`, hwh `e05afdb895ef7eda50f6204ac7d114eb`.
  Audio fabric (`clk_fpga_0`) **+0.656 ns / 0 fail**, WHS +0.023, THS 0. DSP
  100, BRAM 6. -0.534 is only -0.038 ns from D79's bench-clean -0.496 (well
  inside the accepted-clean band; D75 was clean at -0.706). Deployed 5-site
  (board md5 matched). Bench (Pmod mode 2): all_off clean / no bitcrusher,
  Big Muff mid scoop audible, other pedals unchanged -- user-confirmed
  accepted. **D82 (`ee295544`) is the new accepted bitstream baseline,
  superseding D81** (`3a79745f`, rollback in git history + `/tmp/d81_backup`).
- **Lesson.** A DF1 biquad in a tight feedback section recovers timing by
  precomputing the feedforward sum a stage earlier, NOT by splitting the
  feedback (which would break the IIR) and NOT by serialising the multiplies
  (the D79 LERP lesson). Reuse this split for the amp-stack biquads (item 3
  next phase).
- **Files.** `hw/ip/clash/src/AudioLab/Effects/Distortion.hs`,
  `hw/ip/clash/src/AudioLab/Pipeline.hs`; regenerated `vhdl/LowPassFir`;
  `bitstreams/audio_lab.{bit,hwh}`. Branch `feature/realism-bigmuff-notch`.

## D83 — Resonant tone stack (item 3 / R3): shared amp tone-stack biquad, Fender blackface mid scoop

- **Decision.** Third R3 biquad and the start of the **amp-stack** family work.
  The amp tone section is a 3-band difference EQ (`ampToneFilterFrame` /
  `ampToneBandFrame`) that can tilt bands but cannot make the resonant
  scoop/peak that *is* each amp family's identity. Add **ONE shared peaking
  biquad** in the amp tone path whose coefficients are **muxed by
  `ampModelIdxF`** -- do NOT instantiate a biquad per model (D58 lesson). This
  phase fills only the **Fender blackface mid scoop**; future phases add the
  AC30 / Marshall coefficients into the same mux (no new DSP).
- **Coefficients (this phase).** JC-120 (idx 0) and Twin Reverb (idx 1) get a
  hand-designed mid scoop (f0 = 400 Hz, Q = 0.7, -5 dB; NOT a schematic table,
  D7/D45; Q14 b0=16044 b1=-31169 b2=15169, a1=-31169 a2=14828; verified notch
  -5.00 dB @ 400 Hz, pole 0.951 stable, +0.2 dB DC error from Q14 rounding at
  this low f0 -- inaudible). Models 2-5 use **flat coefficients** (b0 = 2^14,
  rest 0) = exact unity passthrough, so AC30 / Rockerverb / JCM800 / TriAmp are
  **byte-identical**.
- **Placement / structure.** New stages between `ampStage2Pipe` and
  `ampToneFilterPipe`, operating on `monoWet` (the amp signal). Reuses the D82
  **feedforward/recursive split** (feedforward sum into `fAccL` one stage
  earlier, recursive stage closes the loop with two multiplies) so the
  single-cycle feedback path stays short. No GPIO/API/Frame change; Python
  golden tests unchanged.
- **Timing (built, deployed, bench-accepted).** bit md5
  `cef494cb409e9a323b70659827d6c49c`, hwh `82d2e14f21fb56b9bc62f247356a0d21`.
  Island (`clk_fpga_1`) **WNS -0.381 ns** / 52 fail (all DS-1; `scoop` 0x in
  the worst-100, biquad off the critical set via the split), audio fabric
  (`clk_fpga_0`) **+0.453 ns / 0 fail**, WHS +0.014, THS 0. DSP 105 (+5 over
  D82's 100), BRAM 6, LUT 22082, FF 24811. **Better than D82 (-0.534) despite
  +5 DSP** -- P&R + phys_opt landed favorably; the earlier worry that a third
  biquad would bust the budget did not hold. Deployed 5-site (board md5
  matched). Bench (Pmod mode 2): all_off clean / no bitcrusher, Twin + JC-120
  mid scoop audible, amps 2-5 unchanged, other effects unchanged --
  user-confirmed accepted. **D83 (`cef494cb`) is the new accepted bitstream
  baseline, superseding D82** (`ee295544`, rollback in git history +
  `/tmp/d82_backup`).
- **Next.** Fill AC30 chime (upper-mid peak) and JCM800/Marshall mid (mid peak)
  coefficients into the SAME `ampScoopFeedforwardCoeffs`/`ampScoopFeedbackCoeffs`
  mux -- coefficient-only, no new DSP, timing essentially unchanged.
- **Files.** `hw/ip/clash/src/AudioLab/Effects/Amp.hs`,
  `hw/ip/clash/src/AudioLab/Pipeline.hs`; regenerated `vhdl/LowPassFir`;
  `bitstreams/audio_lab.{bit,hwh}`. Branch `feature/realism-amp-fender-scoop`.

## D84 — Resonant tone stack (item 3 / R3): AC30 chime + JCM800 mid into the shared amp biquad

- **Decision.** Fill the remaining amp-family coefficients into the D83 shared
  amp tone-stack biquad mux. **Coefficient-only** -- no new biquad, no new
  structure; just two more cases in `ampScoopFeedforwardCoeffs` /
  `ampScoopFeedbackCoeffs`. This essentially completes item 3 (resonant tone
  stacks).
- **Coefficients (hand-designed targets, NOT schematic tables, D7/D45; Q14).**
  AC30 (idx 2) = Vox chime upper-mid peak f0=2200 Hz / Q=1.0 / **+4 dB**
  (b0=17355 b1=-28234 b2=12091, a1=-28234 a2=13062; verified +4.00 dB @
  2200 Hz, pole 0.893, DC 1.000 -- high f0 = excellent Q14 precision).
  JCM800 (idx 4) = Marshall mid peak f0=650 Hz / Q=0.8 / **+4 dB** (b0=16772
  b1=-31328 b2=14670, a1=-31328 a2=15057; +4.00 dB @ 650 Hz, pole 0.959, DC
  +0.08 dB -- inaudible). Rockerverb (idx 3) and TriAmp (idx 5) stay **flat**
  (unity, byte-identical) -- the gap analysis rated them already reasonable.
- **Timing (built, deployed, bench-accepted).** bit md5
  `dc030473688a456eae7239f6e5e55741`, hwh `d981ffc3fec170d620ecdb50cc2ed7da`.
  Island (`clk_fpga_1`) **WNS -0.472 ns** / 49 fail (all DS-1; `scoop` 0x in
  the worst-100), audio fabric (`clk_fpga_0`) **+0.582 ns / 0 fail**, WHS
  +0.011, THS 0. DSP 106 (+1 vs D83 -- the larger/more-varied mux constants
  shifted Vivado's DSP inference; coefficient-only otherwise), BRAM 6. -0.472
  is in the accepted-clean band (better than D79's bench-clean -0.496).
  Deployed 5-site (board md5 matched). Bench (Pmod mode 2): all_off clean / no
  bitcrusher, AC30 chime + JCM800 mid audible, Fender/Rockerverb/TriAmp + other
  effects unchanged -- user-confirmed accepted. **D84 (`dc030473`) is the new
  accepted bitstream baseline, superseding D83** (`cef494cb`, rollback in git
  history + `/tmp/d83_backup`).
- **item 3 status.** Resonant tone stacks now cover TS mid hump (D81), Big Muff
  notch (D82), and the Fender/Vox/Marshall amp families (D83/D84) -- the
  "samey models" gap is substantially closed. Remaining realism work: item 5b
  (Fuzz/amp dynamic sag), item 1 (cab IR), item 2 (oversampling).
- **Files.** `hw/ip/clash/src/AudioLab/Effects/Amp.hs`; regenerated
  `vhdl/LowPassFir`; `bitstreams/audio_lab.{bit,hwh}`. Branch
  `feature/realism-amp-vox-marshall`.

## D85 — Dynamic behaviour (item 5b / R2, part 1): Fuzz Face dynamic bias

- **Decision.** First **dynamic / level-dependent** DSP change (realism item
  5b, roadmap R2). Static waveshapers cannot do what makes a Ge Fuzz Face
  iconic: cleanup with playing level / guitar volume, and sputter under load.
  Add a playing-level envelope to the Fuzz Face and drift its clip knees with
  it. Per the roadmap rule "at most one new envelope path per phase," this
  phase is Fuzz Face only; **amp sag is part 2 (a later phase)**.
- **Envelope.** `fuzzFaceBiasEnvNext` is a peak-follower on the post-pre-gain
  ("boosted") level -- the same shape as the Compressor / NoiseSuppressor
  envelopes (instant attack, linear release `ffBiasReleaseStep = 4096` ≈ 43 ms
  at 48 kHz, **reset to 0 when the pedal is off**). Threaded as a pipeline
  register `ffBiasEnv` (feedforward into the clip, one-sample lag like the
  compressor gain).
- **Knee modulation.** `fuzzFaceClipFrame` now takes the envelope: `biasShift =
  min(env >> 4, 500_000)`, `kneeP = 2_100_000 - biasShift`, `kneeN =
  1_150_000 + (biasShift >> 1)`. Soft playing / rolled-back volume -> low env ->
  the base asymmetric Ge knees (cleaner, open); hard picking -> high env ->
  knees pull together (harder, more symmetric compression / sputter). Bounded
  (shift capped) and clamped (kneeP never collapses). **No multiply** (abs +
  shift + compare only) -> **no new DSP**.
- **Bit-exact bypass.** When the pedal is off the clip stage passes the sample
  through unchanged and the envelope holds 0, so OFF is bit-exact. Only the
  Fuzz Face voicing changes; all other pedals/models byte-identical, Python
  golden tests unchanged. No GPIO/API/Frame change.
- **Timing (built, deployed, bench-accepted).** bit md5
  `b2d8a41b0f8389ca2ec851a2d267a7e6`, hwh `e5efc8ca4241d99f3b2778ad9f7ba620`.
  Island (`clk_fpga_1`) **WNS -0.122 ns** / only **3 fail**, TNS -0.160 (the
  **best of the whole R3/R2 run** -- the DSP-free change added no DS-1
  placement pressure and the P&R nearly closed the island), audio fabric
  (`clk_fpga_0`) **+0.543 ns / 0 fail**, WHS +0.006, THS 0. DSP **106
  (unchanged** -- no multiply added), BRAM 6. Deployed 5-site (board md5
  matched). Bench (Pmod mode 2): all_off clean / no bitcrusher, Fuzz Face
  cleans up soft / sputters under hard picking with no zipper, other
  pedals/amps unchanged -- user-confirmed accepted. **D85 (`b2d8a41b`) is the
  new accepted bitstream baseline, superseding D84** (`dc030473`, rollback in
  git history + `/tmp/d84_backup`).
- **Pattern for reuse.** Envelope-modulated parameters (no new DSP) are timing
  cheap on this island. The amp-sag part 2 will reuse this pattern (a slower
  envelope after the second gain stage scaling the power/master gain down on
  loud passages); keep it bounded and reset-on-bypass.
- **Files.** `hw/ip/clash/src/AudioLab/Effects/Distortion.hs`,
  `hw/ip/clash/src/AudioLab/Pipeline.hs`; regenerated `vhdl/LowPassFir`;
  `bitstreams/audio_lab.{bit,hwh}`. Branch `feature/realism-fuzzface-bias`.

## D86 — Dynamic behaviour (item 5b / R2, part 2): power-amp sag

- **Decision.** Complete item 5b with **power-amp sag** -- loud passages pull
  the amp master gain down a touch and recover after the transient (tube
  power-supply sag). One new envelope path, per the roadmap rule.
- **Envelope.** `ampSagEnvNext` -- a slow peak-follower of the master-input
  level (`abs24 (monoWet f)` at `ampResPresencePipe`); instant attack, slow
  linear release `ampSagReleaseStep = 1024` (~170 ms recovery), reset to 0 when
  the amp is off. Threaded as pipeline register `ampSagEnv`.
- **Application (DSP-free).** `ampMasterFrame` already had a
  `mulU8 (monoWet f) level`; sag reuses it by lowering the level operand:
  `sagRaw = bits 22..17 of the envelope (0..63)`, `sagByte = min(sagRaw,
  level>>1)`, `effLevel = level - sagByte`. Bounded to **at most half the
  level** (no choke). **Disabled for JC-120 (idx 0)** -- solid-state, stiff
  supply, no sag. No new multiply -> **DSP unchanged (106)**.
- **Bit-exact bypass.** Amp off -> master passes through, env = 0; at low
  level sagByte = 0 so the amp is identical to D85. Only loud-passage amp
  behaviour changes; all pedals + JC-120 byte-identical; Python golden tests
  unchanged. No GPIO/API/Frame change.
- **Timing (built, deployed, bench-accepted).** bit md5
  `1ab991c7a406e8ec3ba72cdfa42eb347`, hwh `3e47884cff493c6d06068ec91cd512c6`.
  Island (`clk_fpga_1`) **WNS -0.397 ns** / 44 fail (all DS-1; `sag` 0x in the
  worst-100), audio fabric (`clk_fpga_0`) **+0.418 ns / 0 fail**, WHS +0.052,
  THS 0. DSP **106 (unchanged)**, BRAM 6. The -0.122 (D85) -> -0.397 swing is
  pure P&R run-to-run variance on the DS-1 path (DSP-free change), well inside
  the accepted-clean band. Deployed 5-site (board md5 matched). Bench (Pmod
  mode 2): all_off clean / no bitcrusher, tube amps sag + recover on loud
  chords with no pumping, JC-120 does not sag, other effects unchanged --
  user-confirmed accepted. **D86 (`1ab991c7`) is the new accepted bitstream
  baseline, superseding D85** (`b2d8a41b`, rollback in git history +
  `/tmp/d85_backup`). **item 5b (dynamic behaviour) complete.**
- **Files.** `hw/ip/clash/src/AudioLab/Effects/Amp.hs`,
  `hw/ip/clash/src/AudioLab/Pipeline.hs`; regenerated `vhdl/LowPassFir`;
  `bitstreams/audio_lab.{bit,hwh}`. Branch `feature/realism-amp-sag`.

## D87 — Cab IR (item 1 / R4, step A): 15-tap symmetric speaker-rolloff FIR

- **Decision.** First step toward a real cab IR. The cab's frequency response
  is fundamentally set by a 4-tap FIR; add a longer linear FIR to sharpen the
  >5 kHz rolloff (tame high-gain fizz, deepen model separation). To avoid
  regressing the carefully-tuned **accepted D71 nonlinear cab core**
  (cabProducts/Sat/Ir/LevelMix), the FIR is an **ADDITIVE post-stage** on the
  cab output, not a rewrite of the core. (The full 128-256-tap BRAM
  convolution is the planned **step B**, a separate phase.)
- **Filter.** 15-tap symmetric linear-phase FIR, per-model coefficients
  hand-designed from a magnitude target (lowpass + gentle presence,
  inverse-FFT; sum = 256 = unity DC; NOT a captured commercial IR, D7): open
  1x12 brightest (~-5.7 dB @ 8 kHz), british 2x12 mid (~-9.3 dB), closed 4x12
  darkest/sharpest (~-11.8 dB @ 8 kHz, -26 dB @ 12 kHz). Symmetric -> folds to
  8 multiplies; the folded pair `(a+b)*c` maps onto the DSP48 pre-adder.
  Bit-exact bypass when the cab is off. The AIR knob keeps its existing cab
  role (coeffs are not switched by AIR in this FIR).
- **Pipeline split (load-bearing).** A single-cycle 15-tap sum was too deep for
  the 50 MHz island: it measured **WNS -1.106 ns** with the FIR itself the
  critical path (`cabSpk` 96x in the worst-100). A FIR is **feedforward**, so it
  pipelines freely (unlike the D82 biquad feedback): split into
  `cabSpeakerFirProductsFrame` (all 8 products from ONE history snapshot ->
  three Wide partial sums in fAccL/fAcc2L/fAcc3L) + `cabSpeakerFirMixFrame`
  (combine + satShift8). That moved the FIR off the critical set (`cabSpk` 0x
  in the worst-100; DS-1 is the worst path again) and recovered WNS to
  **-0.476 ns**. The 14-deep output history is a `Vec 14 Sample` shift register
  (`cabSpeakerFirHistNext`, shifts on active frames).
- **Timing (built, deployed, bench-accepted).** bit md5
  `8a3754c1f8cef9864c1b5e61eee289aa`, hwh `a14e788ded059adf824ac70198c5cbff`.
  Island (`clk_fpga_1`) **WNS -0.476 ns** / 65 fail (all DS-1), audio fabric
  (`clk_fpga_0`) **+0.449 ns / 0 fail**, WHS +0.051, THS 0. DSP **122** (+16
  vs D86's 106), BRAM 6. In the accepted-clean band (≈ D82 -0.534 / D79
  -0.496). No GPIO/API/Frame change; Python golden tests unchanged. Deployed
  5-site (board md5 matched). Bench (Pmod mode 2): all_off clean / no
  bitcrusher, cab high-gain fizz reduced + model HF separation clearer, cab
  off + other effects unchanged -- user-confirmed accepted. **D87
  (`8a3754c1`) is the new accepted bitstream baseline, superseding D86**
  (`1ab991c7`, rollback in git history + `/tmp/d86_backup`).
- **Lesson / step B note.** Feedforward FIRs pipeline freely (split the
  product/sum across stages); only IIR feedback loops are constrained to one
  cycle. step B (the real 128-256-tap IR) needs the time-multiplexed MAC +
  BRAM + handshake gating -- a dedicated structural phase.
- **Files.** `hw/ip/clash/src/AudioLab/Effects/Cab.hs`,
  `hw/ip/clash/src/AudioLab/Pipeline.hs`; regenerated `vhdl/LowPassFir`;
  `bitstreams/audio_lab.{bit,hwh}`. Branch `feature/realism-cab-speaker-fir`.

## D88 — Oversampling (item 2 / R5): 4x oversampled hard clip on Metal MT-2

- **Decision.** First oversampled nonlinearity. A static 48 kHz hard clip
  folds its >Nyquist harmonics back as inharmonic "digital fizz"; run the
  Metal (MT-2) clip at **4x** and steeply decimate to push those products out
  before the fold. **Investigation first (offline):** DSP-free 2x gave only
  ~-2.8 dB; proper 2x plateaus at ~-5.8 dB (>48 kHz harmonics still fold);
  **4x reaches ~-12 dB** -- so 4x is the worthwhile rate. Metal was chosen as
  the worst aliaser; **DS-1 was excluded** (it is the island critical path).
- **Structure (DSP only in the decimation FIR).** Linear-interp upsample 4x
  (the signal is already band-limited, so linear interp's images are
  negligible -- offline-confirmed equal to a full anti-image FIR -- and the
  0 / 1/4 / 1/2 / 3/4 weights are shifts/adds, no multiply) -> hard clip the 4
  sub-samples -> **15-tap symmetric anti-alias decimation FIR** over the
  192 kHz clipped stream (`os` coeffs `[-2,-3,-4,5,29,68,104,118,...]`, Q9
  sum=512 = unity DC, -7.5 dB @ 24 kHz / -48 dB @ 48 kHz; folds to 8
  multiplies). Clipped sub-sample history = `Vec 12 Sample` pipeline register;
  `metalClipInPrev` = previous clip input for the interp.
- **Pipeline split (load-bearing).** The 15-tap FIR is feedforward, so it
  splits freely (D87 lesson): `metalClipProductsFrame` (current 4 clips +
  history -> 8 folded products into 3 Wide partial sums) +
  `metalClipMixFrame` (combine + satShift9). The folded pair `(a+b)*c` maps
  onto the DSP48 pre-adder. Bit-exact bypass when the pedal is off.
- **Timing (built, deployed, bench-accepted).** bit md5
  `d4c250be87400649b7b1ebf037fcf314`, hwh `701067551c7399e6f96c888b7851cc59`.
  Island (`clk_fpga_1`) **WNS -0.496 ns** / 81 fail -- the worst path is still
  DS-1 (`ds1_31_reg`, CARRY4=27), NOT the oversampler (its paths are
  near-critical but below DS-1); audio fabric (`clk_fpga_0`) **+0.385 ns / 0
  fail**, WHS +0.022, THS 0. DSP **123** (+1 vs D87), BRAM 6. -0.496 = D79's
  bench-clean baseline (well above the ~-0.7 bitcrusher boundary). No
  GPIO/API/Frame change; Python golden tests unchanged. Deployed 5-site (board
  md5 matched). Bench (Pmod mode 2): all_off clean / no bitcrusher, Metal
  high-string/high-fret alias fizz audibly reduced, voicing preserved, other
  pedals unchanged -- user-confirmed accepted. **D88 (`d4c250be`) is the new
  accepted bitstream baseline, superseding D87** (`8a3754c1`, rollback in git
  history + `/tmp/d87_backup`).
- **Next.** Extend the same 4x oversampler to other hard-clip aliasers (RAT
  next; Big Muff after) -- one model per phase (each adds DSP + island
  placement pressure). DS-1 remains excluded (critical path) unless explicitly
  approved.
- **Files.** `hw/ip/clash/src/AudioLab/Effects/Distortion.hs`,
  `hw/ip/clash/src/AudioLab/Pipeline.hs`; regenerated `vhdl/LowPassFir`;
  `bitstreams/audio_lab.{bit,hwh}`. Branch `feature/realism-metal-oversample2x`.

## D89 — DSP island clock 50 -> 40 MHz (headroom) + RAT 4x oversampling

- **Problem.** Adding a 2nd 4x oversampler (RAT, on top of Metal D88) at the
  50 MHz island blew the DS-1 path to **WNS -1.276 ns** -- not from DSP count
  (+1 only) but from routing/placement congestion near the DS-1 CARRY4
  arithmetic. The island had run out of headroom.
- **Decision (headroom lever).** **Lower the DSP island clock FCLK_CLK1 from
  50 MHz to 40 MHz** in `island_integration.tcl` (`PCW_FPGA1_PERIPHERAL_FREQMHZ
  50->40`, divisors `5/4 -> 5/5`, = 1000 MHz IO PLL / 5 / 5). This is the
  reliable headroom lever (NOT a DS-1 pipeline split -- that was already tried
  and failed in D75, route-bound). The island is the **only** consumer of
  FCLK_CLK1, runs 1 sample/cycle, and is frequency-independent (paceCount
  removed, D75), so 40 MHz still hugely exceeds the 48 kHz throughput need
  while giving the DS-1 path a **25 ns** (was 20 ns) budget. The two
  `axis_clock_converter`s bridge 100 <-> 40 exactly as they did 100 <-> 50.
  **Pitch is set by the I2S/Pmod sample clock, not this island clock, so it is
  unaffected** (bench-confirmed). Only `island_integration.tcl` changed;
  `block_design.tcl` untouched; the fabric stays 100 MHz (lowering the *fabric*
  is still forbidden -- it corrupts the I2S/Pmod CDCs).
- **Result -- first fully-timing-clean build since D72.** Island
  (`clk_fpga_1`, now 25 ns / 40 MHz) **WNS +1.846 ns, 0 failing endpoints**
  (the DS-1 path, negative since D72, is finally positive); audio fabric
  (`clk_fpga_0`) **+0.551 ns / 0 fail** (the overall worst path is now a PS7
  AXI clock, MET); WHS +0.024, THS 0. **Whole design meets timing.** This
  bundle also lands **RAT 4x oversampling** (the change that needed the
  headroom) and a refactor of the oversampler into shared helpers
  (`os4xSubSamples` / `os4xDecimProducts` / `os4xHistShift`) reused by Metal +
  RAT. DSP 124, BRAM 6.
- **bit/hwh** md5 `1e9eb9ac589e9647e699f6e2a16f27d5` /
  `ef17fe68e53af0ea8a8e6b6c77b859f7`. Deployed 5-site (board md5 matched).
  Bench (Pmod mode 2): all_off clean / no bitcrusher, **pitch correct**, all
  effects healthy with no switch click (the syncCtrl CDC works at 40 MHz),
  Metal + RAT alias fizz reduced -- user-confirmed accepted. No GPIO/API/Frame
  change; Python golden tests unchanged. **D89 (`1e9eb9ac`) is the new accepted
  bitstream baseline, superseding D88** (`d4c250be`, rollback in git history +
  `/tmp/d88_backup`; D88 is the 50 MHz-island rollback).
- **Headroom opened.** The island now has **+1.846 ns** of slack, so further
  oversamplers (Big Muff next; even DS-1 itself, previously excluded) and other
  DSP additions now fit. If a future build tightens up again, 33 MHz
  (1000/5/6) is the next step down.
- **Files.** `hw/Pynq-Z2/island_integration.tcl`,
  `hw/ip/clash/src/AudioLab/Effects/Distortion.hs`,
  `hw/ip/clash/src/AudioLab/Pipeline.hs`; regenerated `vhdl/LowPassFir`;
  `bitstreams/audio_lab.{bit,hwh}`. Branch `feature/realism-rat-oversample`.

## D90 — Oversampling (item 2 / R5): 4x oversampled Big Muff clip cascade

- **Decision.** Third oversampled clip: Big Muff. Its **two cascaded soft
  clips** (clip1 -> *208 -> clip2) generate fizz that aliases; run the whole
  cascade 4x and decimate. Same `os4x*` machinery as Metal/RAT, but the
  per-sub-sample nonlinearity is the soft-clip **cascade** (`bigMuffOsCascade`,
  knees 2.4M then 1.85M with the *208 inter-stage gain -- identical to the old
  two-stage clip1/clip2, so the voicing is preserved; only aliasing drops).
- **Cascade isolation (load-bearing).** Putting the cascade AND the decimation
  FIR in one products stage measured **WNS -6.244 ns** -- two multiplies
  (the *208 and the FIR pairMul) plus two soft clips **in series** in one
  combinational path. Fix: the deep cascade lives ONLY in the history-update
  path (`bigMuffClipHistNext` -> the `Vec 16` register, no FIR after it), and
  the products stage reads all 15 FIR taps **from the 16-deep history** (no
  cascade in the products path). This keeps the cascade multiply and the FIR
  multiply in SEPARATE register-to-register paths. The FIR output lags the
  cascade by one frame group (harmless latency). Recovered to **WNS -0.036 ns**.
- **Timing (built, deployed, bench-accepted).** bit md5
  `93e8b220f94749b39c66e14ed2c431c6`, hwh `13427a86e08dad9e7e39daf14547b05b`.
  Island (`clk_fpga_1`, 40 MHz) **WNS -0.036 ns** / 1 fail (worst path back to
  DS-1, NOT the oversampler), audio fabric (`clk_fpga_0`) **+0.434 ns / 0
  fail**, WHS +0.051, THS 0. DSP **128** (+4 vs D89), BRAM 6. -0.036 is
  essentially meeting timing (far above the ~-0.7 bitcrusher boundary). The 3rd
  oversampler used most of the D89 40 MHz headroom (+1.846 -> -0.036); a 4th
  (e.g. DS-1) would need 33 MHz. No GPIO/API/Frame change; Python golden tests
  unchanged. Deployed 5-site (board md5 matched). Bench (Pmod mode 2): all_off
  clean / no bitcrusher, Big Muff fizz reduced + voicing (sustain, D82
  mid-scoop) preserved, Metal/RAT/other effects + pitch unchanged --
  user-confirmed accepted. **D90 (`93e8b220`) is the new accepted bitstream
  baseline, superseding D89** (`1e9eb9ac`, rollback in git history +
  `/tmp/d89_backup`). **Metal (D88) + RAT (D89) + Big Muff (D90) -- all three
  hard/cascade-clip aliasers are now 4x oversampled.**
- **Files.** `hw/ip/clash/src/AudioLab/Effects/Distortion.hs`,
  `hw/ip/clash/src/AudioLab/Pipeline.hs`; regenerated `vhdl/LowPassFir`;
  `bitstreams/audio_lab.{bit,hwh}`. Branch `feature/realism-bigmuff-oversample`.

## D91 — RAT selectable in the encoder GUI (Python-only; `skip_rat=False` default + RAT-stage knob routing)

- **Problem.** RAT could not be selected from the encoder GUI's Distortion
  model list. Two layers blocked it, both gated by `skip_rat=True` (the entry-
  point default): `encoder_ui.py` skipped index 2 (RAT) when cycling
  `dist_model_idx`, and `encoder_effect_apply.py` forced `pedal_mask=0` for RAT.
  The two GUI entry points were also inconsistent -- `PmodI2S2HdmiGuiOneCell.ipynb`
  passed `run_encoder_hdmi_gui.py --skip-rat` explicitly, so RAT stayed hidden
  there even after other defaults changed.
- **Mechanism (already present).** The pedalboard RAT slot
  (`distortion_pedal_mask` bit 2) is a **DSP no-op**; the real RAT is the
  dedicated upstream stage. `AudioLabOverlay.set_guitar_effects` already forces
  `rat_on=True` whenever the rat pedal bit is in the mask -- so selecting RAT
  only needs the bit set, and the dedicated stage (4x-oversampled since D89)
  processes audio.
- **Fix (Python only, no bitstream change).**
  (1) `EncoderEffectApplier`: when RAT is the selected model, set
  `distortion_pedal_mask` bit 2 (auto-asserts `rat_on`) and **route the GUI
  Distortion knobs to the RAT stage** -- TONE -> `rat_filter`, LEVEL ->
  `rat_level`, DRIVE -> `rat_drive`, the 6th knob -> `rat_mix` (these pass
  through the existing knob taper, so FILTER/DRIVE are tapered like other
  tone/gain knobs). (2) Entry-point defaults flipped to **`skip_rat=False`**:
  `run_encoder_hdmi_gui.py` (`--include-rat` now default, `--skip-rat` still
  available), `EncoderGuiSmoke.ipynb` / `Pcm5102DspOutputCheck.ipynb`
  (`SKIP_RAT=False`), and `PmodI2S2HdmiGuiOneCell.ipynb` (spawns
  `--include-rat`). (3) The `EncoderEffectApplier` / `EncoderUiController`
  *constructor* defaults stay `skip_rat=True` (library-safe) -- only the entry
  points opt in. `encoder_ui.py`'s RAT-skip-while-cycling logic is unchanged
  and simply no longer triggers when `skip_rat=False`.
- **Scope / validation.** No Clash/VHDL/Tcl/bit/hwh change; deployed bitstream
  stays **D90** (`93e8b220`). `tests/test_encoder_effect_apply.py` pass
  (`test_include_rat_sets_bit_2` / `test_skip_rat_excludes_pedal_mask_bit`
  both still hold); offline check confirms RAT selection sets mask 0x04 and
  routes `rat_filter`/`rat_level`/`rat_drive`/`rat_mix`. Deployed Python-only
  (`scripts/deploy_to_pynq.sh`); **user-confirmed RAT now selectable + audible
  in the GUI.** `CLAUDE.md` encoder constraint + `ENCODER_GUI_CONTROL_SPEC.md`
  updated (the old "do not silently flip skip_rat" note is superseded -- this
  was an explicit, documented change).
- **Files.** `audio_lab_pynq/encoder_effect_apply.py`,
  `scripts/run_encoder_hdmi_gui.py`, `audio_lab_pynq/notebooks/`
  (`EncoderGuiSmoke.ipynb`, `PmodI2S2HdmiGuiOneCell.ipynb`,
  `Pcm5102DspOutputCheck.ipynb`), `CLAUDE.md`,
  `docs/ai_context/ENCODER_GUI_CONTROL_SPEC.md`. Branch
  `feature/rat-gui-and-stage-docs`.

## D92 — Dedicated-stage voicings: JC-120 clean / OD per-model tone biquad (TS9+BD-2) / Klon wet-path refine / AC30 sag

- **Scope.** Five model-realism changes from `DEDICATED_STAGE_CANDIDATES.md`,
  implemented as **shared-stage extensions / model-gated sub-paths**, NOT new
  full dedicated datapaths (the user asked for "dedicated stages" but accepted
  the recommended cheaper/timing-safe approach; a per-model always-on datapath
  is area- and DS-1-island-timing-prohibitive). All five ride existing GPIO
  bytes / model selectors -- **no new GPIO, no `block_design.tcl` change, no
  Python API change, no new control bit.**
- **1. JC-120 clean channel (Amp model 0).** The shared Amp stage ran two
  always-on asymmetric soft-clip stages (`ampWaveshapeFrame` +
  `ampSecondStageFrame`) for every model, colouring the JC-120's solid-state
  *clean* channel. For `idx == 0` both stages now route through a high-knee
  symmetric `softClipK ampJc120CleanKnee` (7_500_000, ~89 % FS) that only
  catches extreme peaks -- a clean channel with a safety ceiling, no waveshaper
  colour in the normal range. **No new DSP** (softClipK = compare+shift, like
  ampAsymClip). Every other amp model keeps `ampAsymClip` byte-for-byte.
- **2. Overdrive per-model pre-clip tone biquad (TS9 model 0 + BD-2 model 2).**
  The dedicated Overdrive effect shared one tone *tilt* across all six models; a
  one-pole tilt cannot make a resonant peak. Added **ONE shared peaking biquad**
  pre-clip (between `overdriveDriveBoostFrame` and `overdriveDriveClipFrame`),
  coefficients muxed by `overdriveModel`: TS9 = +6 dB @ 720 Hz Q0.8 (reuses the
  proven D81 Q14 coeffs), BD-2 = +3 dB @ 1500 Hz Q0.7 (bright upper-mid bite,
  hand-designed, DC/Nyquist unity verified). Every other model (1/3/4/5) stays
  **flat** (b0 = 2^14, rest 0 -> `satShift14(x*2^14) = x` exact passthrough =
  byte-identical). Pipeline-split like D82/D83 (feedforward sum into `fAccL` one
  stage earlier, recursive stage closes the loop with two muls). This is a
  **different** block from the distortion-pedalboard `tube_screamer` biquad
  (D81) -- that shapes the pedal-mask bit-1 pedal; this shapes the dedicated
  Overdrive model 0. **+5 DSP** (3 ff + 2 rec). Mid-emphasised band is driven
  harder into the clip -> mid-weighted saturation.
- **3. Klon / CENTAUR wet-path refine (Overdrive model 5).** D79 gave model 5 a
  parallel clean-blend; this refines the *wet* path to germanium character:
  knees lowered (`odKneeP` 3_100_000 -> 2_400_000, `odKneeN` 2_900_000 ->
  2_050_000, germanium low forward voltage = earlier clip + stronger even-
  harmonic asym) and `odClipHardness` 0 -> 1 (medium knee). `odCleanBlend` cap
  176 (was 191) so the clipped weight tops out at 240 and the **clean weight
  never drops below 15 (~6 %)** -- the Klon's defining always-present parallel
  clean path (the old cap let blend reach 255 at DRIVE=255, fully removing the
  clean signal). Constants only, **no new DSP**; only model 5 changes.
- **4. AC30 power-amp sag tuning (Amp model 2).** The D86 power-amp sag applied
  uniformly to all tube amps. AC30 is class-A with deeper cathode-bias sag, so
  for `idx == 2` the sag magnitude is scaled ~1.5x (`sagRaw0 + sagRaw0>>1`,
  shift+add) before the half-level cap. Every other model keeps `sagRaw0`
  byte-for-byte; JC-120 stays sag-disabled. **No new DSP.**
- **Build / timing (FULLY TIMING-CLEAN -- like D89).** `clash --vhdl` regen +
  Vivado: **whole design WNS +0.145 ns / WHS +0.016 / THS 0 -- meets timing**
  (post-route physopt skipped because WNS >= 0). **Island `clk_fpga_1`
  (40 MHz) WNS +0.155 ns / 0 fail; audio fabric `clk_fpga_0` (100 MHz) +0.417 /
  0 fail.** Worst MET path is the HDMI v_tc (harmless). DSP **133** (+5 vs D90's
  128, all from the OD biquad), BRAM 6 (unchanged), LUT 27281, FF 26735. The
  +5-DSP biquad did NOT blow the razor-thin D90 island (-0.036) -- the island
  came back POSITIVE (+0.155): the OD biquad is upstream of the DS-1 critical
  path and the JC-120 clean mux relieved some idx-0 clip pressure (plus P&R
  variance). No island clock drop to 33 MHz was needed.
- **Validation.** Clash 15-module typecheck clean; generated VHDL carries the
  new coeffs (BD-2 17093). Python golden tests unchanged (no byte-layout change:
  `tests/test_overlay_controls.py`, `tests/test_encoder_effect_apply.py` pass).
  bit/hwh md5 `5e6aebe4345f4c403fd7ba432e495ba6` /
  `61510d58c21fc264a958c4b5b1625367`. **Deployed 5-site (`scripts/deploy_to_pynq.sh`;
  board md5 matched `5e6aebe4` at repo / `audio_lab_pynq` package / site-packages
  / pynq-overlays registry / notebooks-dir). D92 is the new deployed bitstream
  baseline, superseding D90** (`93e8b220`, backed up at `/tmp/d90_backup`).
  Merged to main. The deploy syncs bit/hwh only (no `download=True`), so the FPGA
  reprograms on the next notebook/script load (first `download=True` of the
  session, per the once-per-session rule). **Bench-audio listening confirmation
  still pending** (Pmod mode 2 ADC->DSP->DAC: all_off clean / no bitcrusher,
  JC-120 truly clean, TS9 mid hump + BD-2 bite audible, Klon clean-blend grit,
  AC30 deeper sag, other models + pitch unchanged) -- the D74/D78 lesson is that
  static timing is necessary but not sufficient; roll back to D90 if the bench
  rejects.
- **Files.** `hw/ip/clash/src/AudioLab/Effects/Overdrive.hs` (knee/hardness/
  blend tables + `odMidFeedforwardCoeffs` / `odMidFeedbackCoeffs` +
  `overdriveMidFeedforwardFrame` / `overdriveMidRecursiveFrame`),
  `hw/ip/clash/src/AudioLab/Effects/Amp.hs` (`ampJc120CleanKnee` + clean mux in
  both clip stages, per-model AC30 sag), `hw/ip/clash/src/AudioLab/Pipeline.hs`
  (OD biquad 2 stages + `odMidX1/X2/Y1/Y2` state), regenerated Clash VHDL/IP.
  Branch `feature/dedicated-stage-voicings-jc120-od-amp`.

## D93 — "Digital sound" interim: anti-alias pre/de-emphasis around the amp clip stages

- **Goal.** First cheap, headroom-free step from `DIGITAL_SOUND_REDUCTION.md`
  against the "digital" complaint. The amp waveshaper (two cascaded asymmetric
  soft clips, on in nearly every patch) is NOT oversampled, so its HF content
  folds back as inharmonic alias = a broad always-present fizzy/metallic edge.
- **Method (shift-only, no new DSP).** Attenuate the highs going INTO the first
  amp clip (pre-emphasis) and restore them after the second clip (de-emphasis),
  so fewer high harmonics are generated above Nyquist -> less folds back. A
  one-pole lowpass (`prev + (x-prev)>>ampEmphShift`, the ampToneFilter idiom)
  gives the HF band `h = x - lp`; pre = `x - h>>ampEmphAmount`, de =
  `x + h>>ampEmphAmount`. NO multiply -> **DSP unchanged (133)**. `ampEmphShift`
  = 3 (corner ~ a few kHz), `ampEmphAmount` = 1 (half the HF band) are the
  bench-tunable voicing knobs. Two new pipeline stages (`ampPreEmphPipe`
  before `ampWaveshapeFrame`, `ampDeEmphPipe` after `ampSecondStageFrame`,
  feeding the D83 amp scoop biquad), each with a one-pole state register
  (`ampPreEmphLpPrev` / `ampDeEmphLpPrev`); lowpass state stashed in the
  reuse-safe `fEqLowL`. **Gated on amp-on (bit-exact bypass when the amp is
  off) AND skipped for JC-120 (idx 0)** so its D92 clean channel stays exact.
  NOT transparent -- a voiced interim until full 4x amp oversampling (needs the
  33 MHz headroom phase). A fraction of true oversampling's benefit for a
  fraction of the cost.
- **Build / timing (REGRESSION from D92, but in the historically bench-clean
  band).** The +491 LUT / +384 FF of the emphasis logic perturbed the island
  P&R and pushed an **existing** critical path -- the **Big Muff 4x oversampler
  cascade** (`bmClipInPrev -> bmClipHist`, NOT the new amp logic) -- to **island
  `clk_fpga_1` WNS -0.279 ns / 5 failing / TNS -0.978** (D92 was +0.155). Audio
  fabric `clk_fpga_0` +0.157 / 0 fail; WHS +0.051; THS 0; WPWS +2.845. DSP 133
  (unchanged, confirming 0 new DSP), BRAM 6, LUT 27772, FF 27119. **-0.279 sits
  squarely in the project's normal accepted band** (D82 -0.534, D83 -0.381, D84
  -0.472, D86 -0.397, D87 -0.476, D88 -0.496 were ALL negative and bench-clean;
  the ~-0.7 bitcrusher boundary is well clear) -- D92's +0.155 was the anomaly,
  not the norm. Same "added logic perturbs island P&R, pushes an existing
  critical path" phenomenon as D78 (footswitch) / D89; phys_opt
  (AggressiveExplore) already on.
- **Decision.** User chose to **deploy -0.279 as-is and bench** (rather than
  bundle the 33 MHz island drop or revert). bit/hwh md5
  `935cf5f3361149ed45ba61bb3e1740ed` / `616523cd323052e6d3ee3cfb3d119e3b`.
  **Deployed 5-site (board md5 matched `935cf5f3`). Bench-audio ACCEPTED
  (user-confirmed "合格", 2026-06-04): all_off clean / no bitcrusher despite the
  island -0.279, amp fizz reduced, JC-120 clean unchanged, pitch correct, other
  models not worse. D93 is the new accepted deployed bitstream baseline,
  superseding D92** (`5e6aebe4`, rollback at `/tmp/d92_backup`; D90 `93e8b220` at
  `/tmp/d90_backup`). Merged to main. Confirms the precedent: an island WNS of
  -0.279 is in the normal bench-clean band; D92's +0.155 was the anomaly, not a
  required floor.
- **Next cheap interim (queued):** the output "analog" HF shelf (item B in
  `DIGITAL_SOUND_REDUCTION.md`), kept separate for bench isolation.
- **Files.** `hw/ip/clash/src/AudioLab/Effects/Amp.hs` (`ampPreEmphFrame` /
  `ampDeEmphFrame` + `ampEmphShift` / `ampEmphAmount`),
  `hw/ip/clash/src/AudioLab/Pipeline.hs` (two emphasis stages + state, scoop
  repointed to `ampDeEmphPipe`), regenerated Clash VHDL/IP. Branch
  `feature/amp-clip-preemphasis-antialias`.

## D94 — DSP island 40 -> 33 MHz (headroom) + output-transformer emulation (digital-sound #9)

- **Two bundled changes, one bitstream.** (a) the **island headroom phase**
  (`island_integration.tcl` FCLK_CLK1 40 -> 33.33 MHz, divisor 1000/5/5 ->
  1000/5/6) and (b) **output-transformer emulation** (`DIGITAL_SOUND_REDUCTION.md`
  #9). The clock change is sonically transparent (pitch is set by the I2S/Pmod
  sample clock, not the island; D89's 50 -> 40 step bench-proved this), so the
  only audible variable to bench is the transformer -- bundling does not hurt
  bench isolation, and it keeps the island timing clean instead of stacking #9
  onto D93's -0.279.
- **Why 33 MHz.** D93 left the island at -0.279 ns (the amp emphasis perturbed
  P&R). #9 adds more island logic; stacking it at 40 MHz risked the ~-0.7
  bitcrusher boundary. 33 MHz (1000/5/6) gives the DS-1 CARRY4 path a **30 ns**
  budget (was 25) and ~690 cycles/sample -- the island is the only FCLK_CLK1
  consumer, 1 sample/cycle, frequency-independent (paceCount removed, D75), so
  this is the same safe kind of step as D75 50 / D89 40. Pre-stages the headroom
  for the future big items (amp 4x oversampling, cab IR step B).
- **Output transformer (shift-only, NO new DSP).** A real tube amp's output
  transformer iron saturates on low-frequency energy (bass / power chords push
  the core and compress/round, low-order harmonics) while highs pass ~linearly
  -- a "bloom and compress on loud lows" the clip -> tone -> cab chain missed
  entirely (transformer = power-amp iron; cab = speaker; both distinct, both
  were absent). `ampTransformerFrame` sits after the power-amp master, before
  the cab: split the low band with a one-pole lowpass (`prev + (x-prev)>>6`,
  ~120 Hz corner), soft-clip ONLY the low band (`softClipK 5_200_000`, compare+
  shift), recombine with the untouched high band. **Gated on amp-on (bit-exact
  bypass when off) AND skipped for JC-120 (idx 0, solid-state = no output
  transformer, same exclusion as the D86 sag).** Lowpass state in `ampXfmrLpPrev`,
  stashed in the reuse-safe `fEqLowL` (the cab's first stage re-inits
  `fEqLowL = 0`, so it never leaks). The HF bandwidth droop is left to the cab +
  D93 emphasis for now; this phase is just the LF core saturation. `ampTransformerLfShift`
  / `ampTransformerKnee` are the bench-tunable knobs.
- **Build / timing (FULLY CLEAN, big margin restored).** Island `clk_fpga_1`
  (33.334 MHz, 30 ns period) **WNS +3.150 ns / 0 fail** (was -0.279 at 40 MHz in
  D93); audio fabric `clk_fpga_0` +0.834 / 0 fail; **whole design WNS +0.834 /
  WHS +0.016 / THS 0 -- meets timing.** DSP **133 (unchanged -- transformer is
  shift-only, 0 new DSP)**, BRAM 6, LUT 27948, FF 27066. Clash 15-module
  typecheck clean. bit/hwh md5 `a1506fce1634a5a33e161fc2c7dbf1b6` /
  `fd797e7a407a30fd5136028faf7694d8`.
- **Status.** Deployed 5-site (board md5 matched `a1506fce`). **Bench-audio
  ACCEPTED (user-confirmed "合格", 2026-06-04): pitch correct (the 33 MHz step is
  transparent, as predicted), all_off clean / no bitcrusher, tube amps
  bloom/compress on loud low chords (transformer), JC-120 unchanged, highs +
  other effects healthy. D94 is the new accepted deployed bitstream baseline,
  superseding D93** (`935cf5f3`, rollback `/tmp/d93_backup`; D92/D90 also
  retained). Merged to main. **Confirms the 33 MHz island drop is safe and
  transparent** (third headroom step after D75 50 / D89 40), and the island now
  has +3.150 ns -- ample room for the next DSP items without a clock change.
- **Files.** `hw/Pynq-Z2/island_integration.tcl` (40 -> 33 MHz),
  `hw/ip/clash/src/AudioLab/Effects/Amp.hs` (`ampTransformerFrame` +
  `ampTransformerLfShift` / `ampTransformerKnee`),
  `hw/ip/clash/src/AudioLab/Pipeline.hs` (`ampXfmrPipe` stage + cab repointed),
  regenerated Clash VHDL/IP. Branch `feature/output-transformer-emulation-island33`.

## D95 — Waveshaper hysteresis / per-sample memory on the amp clips (digital-sound #10)

- **Goal.** `DIGITAL_SOUND_REDUCTION.md` #10. Real tube/diode/magnetic transfer
  curves are NOT memoryless -- the curve traced going up differs from coming down
  (path dependence / a loop). Every clip here is a static, memoryless function,
  which the ear reads as the "frozen / same every cycle" digital quality. This is
  DISTINCT from the D85/D86 envelope dynamics (those move a *parameter* slowly;
  hysteresis is a *per-sample* path dependence in the transfer curve itself).
- **Method (shift-only, NO new DSP).** `ampAsymClip` gains a `hyst` argument = a
  small signed fraction (`prevOut >> ampHystShift`, shift = 4 -> 1/16) of THAT
  clip stage's previous output, threaded as a pipeline register. It shifts the
  knees with signal history: `posKnee -= hyst`, `negKnee += hyst`. When the
  previous output was high-positive the positive knee lowers (clipper stays
  engaged -> sticky high) and the negative knee rises (harder to clip negative);
  symmetric for the negative direction -- a hysteresis loop. Applied to BOTH amp
  clip stages (`ampWaveshapeFrame` via `ampShapePrev`, `ampSecondStageFrame` via
  `ampStage2Prev`). **STABLE / no combinational loop** (hyst comes from a
  REGISTERED previous output, not the current one), and `|hyst|` stays a small
  fraction of the knee (~7-11 %). `hyst = 0` reproduces the pre-D95 memoryless
  clip bit-for-bit, so **JC-120 (idx 0, uses softClipK) and the amp-off bypass
  are byte-identical** (they never call ampAsymClip). `ampHystShift` is the
  bench-tunable subtlety knob (larger = subtler).
- **Build / timing (FULLY CLEAN, 33 MHz headroom absorbed it easily).** Island
  `clk_fpga_1` (33.334 MHz) **WNS +3.085 ns / 0 fail** (D94 was +3.150 -- the
  hysteresis cost almost nothing); audio fabric `clk_fpga_0` +0.663 / 0 fail;
  **whole design WNS +0.663 / WHS +0.025 / THS 0 -- meets timing.** DSP **133
  (unchanged -- shift-only, 0 new DSP)**, BRAM 6, LUT 28055 (+107 vs D94), FF
  ~27.1k. Clash 15-module typecheck clean. bit/hwh md5
  `27c008cac0604180869aaecfa1be167a` / `664e54c9c66fd4936a95c158c6aa210b`.
- **Status.** Deployed 5-site (board md5 matched `27c008ca`). **Bench-audio
  ACCEPTED (user-confirmed "合格", 2026-06-04): all_off clean / no bitcrusher,
  tube amps thicker/more alive under sustain + pick dynamics, JC-120 unchanged,
  pitch + other effects healthy. D95 is the new accepted deployed bitstream
  baseline, superseding D94** (`a1506fce`, rollback `/tmp/d94_backup`). Merged to
  main. Confirms registered-feedback hysteresis is stable + musical (no
  oscillation, as designed).
- **Files.** `hw/ip/clash/src/AudioLab/Effects/Amp.hs` (`ampAsymClip` + `hyst`,
  `ampHystShift` / `ampHystBias`, both clip frames take a `prevOut`),
  `hw/ip/clash/src/AudioLab/Pipeline.hs` (`ampShapePrev` / `ampStage2Prev`
  registers), regenerated Clash VHDL/IP. Branch `feature/amp-waveshaper-hysteresis`.

## D96 — Transformer HF bandwidth droop (#9 cont.) + cab-output micro-modulation (#11)

- **Two bundled digital-sound items, one bitstream** (user asked for #9 + #11
  together). Both subtle, gated, bench-tunable.
- **#9 continuation -- transformer HF bandwidth droop.** The D94 transformer did
  only LF core saturation; a real output transformer also cannot pass the top
  octave (limited bandwidth rounds the treble -- characteristic "iron"
  softness). `ampTransformerHfFrame` runs right after the LF saturation stage: a
  one-pole high-cut (`lp = prev + (x-prev)>>1`, ~3.8 kHz) takes the HF band
  `h = x - lp` and subtracts a fraction (`h >> 3`, ~-1.2 dB gentle shelf).
  Shift-only -> **0 new DSP**. Same amp-on + skip-JC-120 gate; one-pole state in
  `ampXfmrHfPrev` (stashed in reuse-safe `fEqLowL`, re-init by the cab).
  `ampTransformerHfShift` / `ampTransformerHfDroop` bench-tunable.
- **#11 -- cab-output micro-modulation.** A perfectly static spectrum is a
  "digital" tell; real speakers/air have constant tiny movement. A VERY small
  LFO-modulated fractional delay on the cab output adds organic micro-detune
  ("analog wobble") without an audible chorus. `cabModFrame`: a 64-deep delay
  line of the cab output (`cabModLine`), a 16-bit phase LFO (`cabModLfo`,
  step 3 = ~2.2 Hz), a triangle drives a Q4 fractional read position centered on
  tap 32 with +-3 samples (~1-2 cents) depth, linear-interpolated (one small
  multiply). **Gated on cab-on (flag7) so the all_off bypass is bit-exact** (the
  LFO + line still advance harmlessly when off). Pure modulated delay (vibrato),
  not a dry/wet blend; depth deliberately tiny. `cabModDepthQ4` / `cabModLfoStep`
  bench-tunable.
- **Build / timing (FULLY CLEAN, ample 33 MHz headroom).** Island `clk_fpga_1`
  (33.334 MHz) **WNS +3.233 ns / 0 fail**; audio fabric `clk_fpga_0` +1.006 / 0
  fail; **whole design WNS +1.006 / WHS +0.022 / THS 0 -- meets timing.** DSP
  **134 (+1 vs D95 -- the #11 linear-interp multiply, as predicted)**, BRAM 6
  (the 64-deep line synthesised as SRL/registers, not BRAM), LUT 29412 (+1357 --
  the delay line + dynamic `!!` mux + LFO/interp), FF ~31.9k. Clash 15-module
  typecheck clean. bit/hwh md5 `581bf6fc7813fff7c4a9a9cd0d6b41c2` /
  `22206436571735d8fc0a49edc64601a2`.
- **Status.** Deployed 5-site (board md5 matched `581bf6fc`). **Bench-audio
  ACCEPTED (user-confirmed "合格", 2026-06-04): all_off clean / no bitcrusher,
  amps rounder on top (HF droop), faint organic movement on cab'd patches (#11
  not chorus-y), JC-120 unchanged, pitch correct. D96 is the new accepted
  deployed bitstream baseline, superseding D95** (`27c008ca`, rollback
  `/tmp/d95_backup`). Merged to main.
- **Files.** `hw/ip/clash/src/AudioLab/Effects/Amp.hs` (`ampTransformerHfFrame` +
  shifts), `hw/ip/clash/src/AudioLab/Effects/Cab.hs` (`cabModFrame` /
  `cabModLfoNext` / `cabModDelayNext` + constants),
  `hw/ip/clash/src/AudioLab/Pipeline.hs` (`ampXfmrHfPipe` stage; `cabModLfo` /
  `cabModLine` / `cabModPipe` after the cab FIR), regenerated Clash VHDL/IP.
  Branch `feature/transformer-hf-droop-and-cab-micromod`.

## D97 — Transformer low-end resonance (#9 final) + multiband mid saturation (#12) + reverb diffusion (#13)

- **Three bundled digital-sound items, one bitstream** (user asked for #9 + #12 +
  #13 together). All additive, independently gated (#9/#12 on amp-on + JC-120
  excluded; #13 on reverb-on), conservative, bench-tunable. **Built but NOT
  deployed / NOT merged -- the user deferred verification + the final commit to
  the next day; this branch is a save point.**
- **#9 final -- transformer low-end resonance bump.** Completes the transformer
  (D94 LF saturation + D96 HF droop + now the LF resonance). A gentle ~110 Hz
  peaking biquad (`ampXfmrResFrame`, single-stage 5-mul -- the island has +3 ns
  margin so no D82/D83 split needed) on the transformer output, after the HF
  droop, before the cab. Hand-designed Q14 f0=110 Hz Q=0.8 +2.0 dB (verified
  +2.0 @ 110 / unity at 500 Hz+ / pole 0.984 stable); conservative to avoid
  sub-bass mud. amp-on + skip-JC-120 gate; x1/x2/y1/y2 pipeline state. **+5 DSP.**
- **#12 -- multiband (3-band) mid-focused saturation.** The "proper" version of
  the D93 single-band pre/de-emphasis: split low/mid/high with two one-pole
  lowpasses (~240 Hz, ~1.9 kHz), soft-clip ONLY the mid band (`softClipK
  4_000_000`, where the musical amp grind lives), pass low (transformer handles
  it) + high (stay clean, no fizz) through. Shift-only -> **0 new DSP.** Between
  the amp master and the transformer; amp-on + skip-JC-120 gate. Two one-pole
  states in the reuse-safe `fEqLowL` + `fEqHighLpL` (both verified free between
  the amp master and the cab: the cab re-inits `fEqLowL` and never touches
  `fEqHighLpL`, the EQ overwrites it downstream). `ampMidSatKnee` bench-tunable.
- **#13 -- reverb diffusion.** The reverb is a single comb (1024-sample BRAM) ->
  sparse/metallic tails. A Schroeder allpass diffuser (`reverbDiffuseFrame`,
  g=1/2 shift, 128-sample line ~2.7 ms) on the recirculating `monoFb` densifies
  the tail WITHOUT changing the decay (allpass = magnitude-flat) or the clean
  dry-mix path (`monoDry`, untouched). reverb-on (flag5) gate -> all_off bypass
  bit-exact; unconditionally stable for |g|<1 (no oscillation). Shift-only ->
  **0 new DSP** (the 128-line synthesises as SRL/registers, not BRAM). The line +
  the frame read the same registered delay + pre-diffusion `monoFb` so their
  allpass math is consistent; the extra pipeline stage lengthens the comb loop by
  1 sample (negligible) and `fAddr` rides through it unchanged.
- **Build / timing (FULLY CLEAN).** Island `clk_fpga_1` (33.334 MHz) **WNS +3.002
  ns / 0 fail**; audio fabric `clk_fpga_0` +0.930 / 0 fail; **whole design +0.930
  / WHS +0.019 / THS 0 -- meets timing.** DSP **139 (+5 vs D96 -- the #9 biquad;
  #12 + #13 are shift-only, 0 DSP as predicted)**, BRAM 6, LUT 29644 (+232), FF
  28088. Clash 15-module typecheck clean. bit/hwh md5
  `ad771d7c3c48e981dcd8acdd19c5c2b4` / `7bb6cd9cda6b5a6c5b8ba7996c2ea163`.
- **Status: deployed 5-site (board md5 matched `ad771d7c`). Bench-audio ACCEPTED
  (user-confirmed "合格", 2026-06-05): all_off clean / no bitcrusher, more low-end
  weight/bump on tube amps (#9), fuller mid grind on cranked amps (#12), denser
  reverb tail at the same decay (#13), JC-120 unchanged, pitch correct. D97 is
  the new accepted deployed bitstream baseline, superseding D96** (`581bf6fc`,
  rollback `/tmp/d96_backup`). Merged to main. The transformer (#9 LF sat + HF
  droop + LF resonance) is now complete; #10/#11/#12/#13 also done.
- **Files.** `hw/ip/clash/src/AudioLab/Effects/Amp.hs` (`ampXfmrResFrame`,
  `ampMultibandSatFrame` + constants), `hw/ip/clash/src/AudioLab/Effects/Reverb.hs`
  (`reverbDiffuseFrame` / `reverbDiffLineNext` / `reverbDiffuseY`),
  `hw/ip/clash/src/AudioLab/Pipeline.hs` (`ampMbSatPipe`, `ampXfmrResPipe` + x/y
  state, `reverbDiffLine` / `reverbDiffusePipe`), regenerated Clash VHDL/IP. Also
  added `docs/ai_context/LATENCY_REDUCTION.md` (latency investigation). Branch
  `feature/ds-9res-12multiband-13reverbdiffuse`.

## D98 — 96 kHz conversion (group delay halved + aliasing headroom; whole-chain re-voicing)

- **Goal (LATENCY_REDUCTION.md method 1, the only real latency lever + best
  anti-alias move).** Run the codec in **CS4344/CS5343 double-speed mode at
  96 kHz**: MCLK stays 12.288 MHz (= 128*fs, a valid double-speed ratio), BCLK
  goes MCLK/4 -> **MCLK/2** so LRCK = BCLK/64 = 96 kHz. Codec group delay (the
  dominant round-trip contributor) ~halves and the DSP aliasing headroom doubles.
  **Built + FULLY timing-clean; NOT deployed / NOT bench-verified** -- the codec
  96 kHz lock and all the re-voiced constants need a bench pass. Branch
  `feature/96khz-conversion`.
- **Hardware (`hw/ip/pmod_i2s2/src/pmod_i2s2_master.v`).** BCLK divider
  `bclk_int = ~mclk_phase[1]` (MCLK/4) -> `~mclk_phase[0]` (MCLK/2); the
  `bclk_fall_pre` / `bclk_rise_pre` pre-pulses now gate on `mclk_phase[0]`
  (one MCLK per BCLK half-period). dsp_bclk_o / dsp_lrck_o fan out the doubled
  clocks to `i2s_to_stream`; the mode-2 RIGHT-snapshot DAC path + D50 mono mirror
  are structurally unchanged (one-frame delay now ~10.4 us). **The riskiest
  bench item: the 2-FF SDOUT sync is now 1 BCLK, so the rx_shift status/loopback
  path may misalign 1 bit -- the live mode-2 DSP audio does NOT use rx_shift, so
  it should be fine, but verify on the bench.** The mode-0 test tone is now 2 kHz
  (cosmetic).
- **DSP island clock UNCHANGED** (FCLK_CLK1 33 MHz, 1 sample/cycle,
  frequency-independent -- paceCount removed at D75). At 96 kHz there are still
  ~347 island cycles per audio sample, far above the ~106-stage pipeline, so no
  clock/timing change is needed (pitch is set by the I2S/Pmod sample clock).
- **KEY finding: the 4x oversampler interp + 15-tap decimation FIRs are
  RATIO-based (fs-independent)** -- the decimation cutoff sits at fs_base/2 =
  fs_os/8 in both cases (normalised 0.125), so the SAME coeffs anti-alias at 96 k.
  Metal/RAT/Big Muff oversamplers need NO change. (This removed the biggest
  feared chunk of the re-voicing.)
- **Whole-chain re-voicing (preserve corner Hz / centre Hz / time-constant ms at
  2x fs).** Computed with a validated RBJ + bilinear helper (`/tmp/revoice96.py`,
  the RBJ formula reproduces every existing 48 k coeff exactly first):
  - **7 biquads recomputed (RBJ, fs=96k, Q14):** TS mid hump (720 Hz), Big Muff
    scoop (700 Hz), amp scoop x3 (Fender 400 Hz / AC30 2200 Hz / JCM800 650 Hz),
    output-transformer resonance (110 Hz), OD TS9 (720 Hz) + BD-2 (1500 Hz).
  - **shift-based one-poles +1 shift** (small-a bilinear = a/2): EQ, ampTone,
    ampResPresence, amp pre/de-emphasis, transformer LF (>>7) / HF (>>2),
    multiband (>>6 / >>3).
  - **onePoleU8 alphas (Q8) re-fit via a' = 1 - sqrt(1-a)** for the 11 distortion
    / RAT tone-HPF/LPF filters + ampPreLowpass (its base/darken tables rebuilt).
  - **HP one-pole coeffs widened >>8 -> >>9** (ampHighpass 253->509, ratHighpass
    255->511) so the ~90 / ~30 Hz HP corners hold at 96 k.
  - **time constants halved** (same ms): comp/NS/gate/fuzz/sag envelope release +
    smoothing steps, wah position smoothing; **wah SVF f-byte map halved** (same
    formant Hz, anchors 8/12/19/27/37, clamp [2,100]).
  - **time-based delay lines doubled** (same ms / decay / comb spacing): reverb
    comb `Index/Vec 1024 -> 2048` (Types.hs), reverb diffusion `Vec 128 -> 256`,
    cab micro-mod line `Vec 64 -> 128` (center/depth doubled, LFO step 3->2).
    **reverb tone-damping one-pole input weight halved** (per-sample LP on the
    comb output -> corner preserved).
  - **cab speaker FIR redesigned** for 96 k (15-tap windowed-sinc, -6 dB corner
    matched per model; gentler above the corner -> cab a touch brighter on
    british/closed, bench-tunable; less anti-fizz needed at 96 k anyway).
- **Build / timing (FULLY CLEAN, better island margin than D97).** Island
  `clk_fpga_1` (33.334 MHz) **WNS +3.141 / 0 fail** (D97 +3.002); audio fabric
  `clk_fpga_0` **+0.587 / 0 fail** (D97 +0.930); whole design +0.587 / WHS +0.018
  / THS 0. phys_opt skipped (WNS>=0). DSP **135** (D97 139, NO new multipliers --
  coefficient-only biquad changes), BRAM **6** (unchanged despite the doubled
  reverb), LUT 30740 (+~1100, doubled diffusion/cab-mod shift regs), FF 28830.
  Clash typecheck clean (only the standard integerToInt warning). bit/hwh md5
  `18df313f181bf972cb90b9dc2f21692a` / `8f7bb97945442d722c19ff44d0388904`.
- **Status: DEPLOYED 5-site (board md5 matched `18df313f` at all four board
  resolution sites) + bench-audio ACCEPTED (user-confirmed "合格", 2026-06-05).**
  The codec locks at 96 kHz double-speed, mode-2 audio plays at correct pitch,
  the re-voiced chain auditions clean (all_off clean, effects close to the D97
  voicing, no instability). **D98 (`18df313f`) is the new accepted deployed
  bitstream baseline, superseding D97** (`ad771d7c`, rollback `/tmp/d97_backup`).
  Merged to main. The re-voiced constants are first-pass principled values (each
  carries its old 48 k value in a comment); future bench fine-tuning of any
  single knob/corner is expected to be a constant-only tweak. **Reference: round
  trip group delay is now ~half the 48 k figure (codec-dominated); aliasing
  headroom doubled.**

## D99 — Behaviour-preserving DSP helper refactor (shared one-pole / envelope helpers; stale tree removed)

- **Pure refactor, NO audible change.** Deduplicates repeated DSP idioms into
  shared helpers in `AudioLab.FixedPoint`; the deployed audio is bit-identical to
  D98. New helpers: **`onePoleShift`** (the `prev + (x-prev)>>n` shift one-pole,
  was inlined at 12 sites: EQ low/highLp, amp tone low/highLp + res/presence +
  pre/de-emphasis + transformer LF/HF + multiband low/high), **`onePoleHighpass`**
  (amp + RAT input HP), and **`peakFollower`** (the 5 envelope followers
  `compEnvNext` / `nsEnvNext` / `gateEnvNext` / `fuzzFaceBiasEnvNext` /
  `ampSagEnvNext`, parameterised by enable predicate / level source / release
  formula). Also **removed the stale nested `hw/ip/clash/clash/` tree** (a
  pre-split copy of `LowPassFir.hs` behind a nix-shell Makefile -- a footgun that
  would silently build outdated logic; `BUILD_AND_DEPLOY.md` note corrected).
- **Equivalence proof.** Regenerated Clash VHDL diffed against the D98 output:
  `clash_lowpass_fir_types.vhdl` byte-identical; `clash_lowpass_fir.vhdl` differs
  ONLY in source-line comments, renamed intermediate signals, and one harmless
  CSE (`resize x` computed twice vs shared once -- same value). Same arithmetic
  -> identical samples. **Timing + utilisation identical to D98** (island WNS
  +3.141 / fabric +0.587 / WHS +0.018 / THS 0; DSP 135, BRAM 6, LUT 30740, FF
  28830). The bitstream md5 changed (`83a64ffc6415fe2a3bc2aed47b6b19f9`, hwh
  `8f7bb97945442d722c19ff44d0388904`) purely because renamed wires alter the
  synthesis input -- behaviour is unchanged.
- **Status: DEPLOYED 5-site (board md5 matched `83a64ffc` at all four resolution
  sites). Programmatic mode-2 smoke PASS: bclk/lrclk/sdout alive, frame delta
  288304/3 s ≈ 96.1 kHz, mode 2->3 control OK, bit loads clean** (CLIP_COUNT
  reflected a hot input level, not a DSP change; behaviour is bit-identical to the
  bench-accepted D98). **New deployed baseline `83a64ffc`, behaviourally ==
  D98**; rollback to D98 `18df313f` via `/tmp/d98_backup` (D97 `ad771d7c` at
  `/tmp/d97_backup`). Merged to main; branch `feature/refactor-dsp-helpers`.
- **Latent finding (NOT fixed here -- separate proposal).** `onePoleHighpass`
  documents that the amp/RAT input highpass feedback term is `prevOut * (coef >>
  shift)` and `coef >> shift == 0` at both call sites (Haskell binds `shiftR`
  tighter than `*`), so the intended one-pole HP pole has been a no-op for the
  whole project history -- the stage is effectively `x - prevIn` (a first
  difference: DC block + mild HF emphasis, not the intended ~90/30 Hz one-pole).
  Preserved bit-exact. A fix (enable the pole) changes the sound and needs a
  re-voice + bench, so it is deferred to its own phase.

## D100 — Enable the amp/RAT input-HP feedback pole (BUILT, bench-REJECTED, rolled back to D99)

- **Attempted the D99 latent fix and it was bench-REJECTED -- do NOT retry as-is.**
  Parenthesised `(prevOut * coef) >> shift` in `FixedPoint.onePoleHighpass` to
  enable the previously-dead pole: amp `509/512` -> ~90 Hz, RAT `511/512` -> ~30 Hz
  one-pole highpass. Built FULLY timing-clean (island `clk_fpga_1` WNS +2.754 / 0
  fail, fabric +0.592 / 0 fail, WHS +0.030, THS 0; DSP 137 (+2 constant-mults),
  LUT 31618 (+878), BRAM 6; bit/hwh md5 `369e38a16cd1460c31405774f7b0f426` /
  `076dddf7b438facc025e54ce9fdf4c76`). Deployed for bench; mode-2 smoke passed
  (~96.1 kHz, clocks alive).
- **Bench REJECTED (user: "低音が強調されすぎている" -- bass over-emphasised).** Root
  cause: the dead-pole stage was a first difference `x - prevIn`, whose magnitude
  `2*sin(pi*f/fs)` rolls lows off at 6 dB/oct (~-45 dB @ 90 Hz, ~-24 dB @ 1 kHz vs
  highs) -- i.e. it was a strong input low-cut that made the amp/RAT input THIN,
  and **the whole amp + RAT model lineup (knees/gains/tone, D68-D97) was voiced
  around that thin input.** Enabling the proper pole passes that low/mid back, so
  the amps bloom. The "dead pole" is **load-bearing accidental voicing**, not a
  free bug; a real fix would require re-voicing the entire amp/RAT chain for a
  full-range input (large, not currently worth it).
- **Rolled back to D99 (`83a64ffc`), the accepted deployed baseline** (5-site
  re-synced + verified; an interim SSH connection-reset truncated the notebooks-dir
  bit to 0 bytes, fixed by re-running the deploy). D100 source is preserved on
  branch `feature/fix-amp-rat-highpass-pole` (NOT merged). `onePoleHighpass` on
  main keeps the no-op-pole form, documented. See
  memory `project_amp_rat_hp_dead_pole` ("DON'T FIX").

## D101 — amp/RAT input-HP pole live at a higher corner (tighter lows, less fizz) [deployed, bench-ACCEPTED]

- **The successful follow-up to D100.** Keeps the pole LIVE (the parenthesised
  `(prevOut * coef) >> shift` in `FixedPoint.onePoleHighpass`) but raises the
  corner so the input low end is tightened toward what the amp/RAT voicing
  expects, instead of D100's 90/30 Hz which passed too much low end and bloomed:
  **amp `ampHighpassFrame` coef 502 -> ~298 Hz**, **RAT `ratHighpassFrame` coef
  505 -> ~209 Hz** (shift 9, pole a = coef/512). Still removes the dead-pole
  first-difference's +6 dB HF rise at Nyquist (HF gain 2/(1+a) ~ 1), so the
  anti-fizz benefit D100 aimed for is retained without the bass bloom. Each
  corner is a single bench-tunable constant (raise toward 509/511 for more lows,
  lower toward 498 for tighter).
- **Build FULLY timing-clean.** Island `clk_fpga_1` WNS **+2.670 / 0 fail**,
  fabric `clk_fpga_0` **+0.592 / 0 fail**, WHS +0.030, THS 0. DSP **137** (+2 vs
  D99 -- the two constant-multiplies for the now-live pole), LUT 31618, BRAM 6.
  bit/hwh md5 `9e09ff273b6095e0b138577c8fcca903` / (hwh from the IP repack).
- **Status: DEPLOYED 5-site (board md5 matched `9e09ff27` at all four resolution
  sites) + bench-ACCEPTED.** Mode-2 smoke passed (~96.1 kHz, clocks alive); the
  user auditioned and approved (tighter lows, no D100 bloom) and asked to merge.
  **D101 (`9e09ff27`) is the new accepted deployed baseline, superseding D99**
  (`83a64ffc`, rollback `/tmp/d99_backup`). Merged to main; branch
  `feature/amp-rat-hp-tighter`. (D98 `18df313f` / `/tmp/d98_backup`, D97
  `ad771d7c` / `/tmp/d97_backup` are older rollbacks.) This is the first time the
  amp/RAT input pole has actually been live -- it superseded the project-long
  dead-pole first-difference; future amp/RAT low-end tweaks are the coef 502/505.

## D102 — Refactor: sample-rate single source (A) + distortion-pedal stage kernels (C) [deployed, behaviour == D101]

- **Two refactors bundled, NO audible change** (the second of the "other
  refactorings" set, after the D99 helpers). Deployed audio is bit-identical to
  the bench-accepted D101.
- **A (Python, no bitstream impact).** New `audio_lab_pynq/constants.py`
  (`SAMPLE_RATE_HZ = 96000`, zero deps) is the single source of truth for the
  audio sample rate -- previously hardcoded as `96000`/`48000` literals in ~9
  files. `diagnostics.py` (`DEFAULT_SAMPLE_RATE_HZ`) + `AudioLabOverlay.py`
  (capture defaults) import it; the 7 board diagnostic scripts import it with a
  `try/except` fallback so off-board `--help` still works (the scripts defer
  their pynq import on purpose). The coefficient generator used for the 96 kHz
  re-voicing is committed as `tools/revoice.py` (was `/tmp/revoice96.py`).
- **C (Clash, behaviour-preserving).** Factor the repeated distortion-pedalboard
  stage forms into shared kernels in `Distortion.hs`: `pedalDriveGain base k
  drive` (the 6 mul/pre stages -- clean_boost/TS/metal/ds1/big_muff/fuzz_face)
  and `distLevelRaw f` (the 6 output-level stages). **Verified equivalent to
  D101**: regenerated VHDL diff = `clash_lowpass_fir_types.vhdl` byte-identical,
  and only the 6 gain lines differ (a redundant outer `resize` dropped +
  clean_boost's U11->U12 intermediate, both numerically identical -- no
  overflow); `distLevelRaw` produced ZERO logic diff. Same audio output.
- **Build / timing identical to D101.** Island `clk_fpga_1` WNS +2.670 / 0 fail,
  fabric +0.592 / 0 fail, WHS +0.030, THS 0; DSP 137, LUT 31618, BRAM 6. bit/hwh
  md5 `b18d147725d5dc323ecbe58bb75719da` / (hwh from the IP repack). The bit md5
  changed only from the resize/width tweaks; behaviour unchanged.
- **Status: DEPLOYED 5-site (board matched `b18d1477`), mode-2 smoke pass
  (~96.1 kHz, clocks alive), A verified on board (`SAMPLE_RATE_HZ` imports = 96000).
  Behaviourally == D101, so no re-bench.** New deployed baseline `b18d1477`
  (behaviour == D101 `9e09ff27`, rollback `/tmp/d101_backup`). Merged to main;
  branch `feature/refactor-constants-pedal-helpers`.

## D103 — Refactor B: shared biquad kernels (biquadFf / biquadRec / biquad5) [deployed, behaviour == D102]

- **Pure refactor, NO audible change** (B of the "other refactorings" set). The 5
  resonant tone biquads (TS mid hump, Big Muff scoop, amp scoop mux,
  output-transformer resonance, dedicated-OD mid) now share three kernels in
  `FixedPoint`: `biquadFf b0 b1 b2 x x1 x2` (feedforward sum), `biquadRec a1 a2 ff
  y1 y2` (`(ff - a1*y1 - a2*y2) >> 14`, a0-normalised RBJ a1/a2), and `biquad5 =
  biquadRec . biquadFf` (single-stage 5-mul). The Pipeline x1/x2/y1/y2 wiring +
  the D82 ff/rec timing split are UNCHANGED (the Pipeline `biquadStage`
  combinator -- B2 -- was deliberately deferred as higher-risk).
- **Behaviour proven == D102.** Regenerated VHDL: `clash_lowpass_fir_types.vhdl`
  byte-identical; ampScoop + odMid inline byte-identical; tubeScreamerMid /
  ampXfmrRes / bigMuff-rec differ ONLY by a sign-flipped y1 multiplier constant
  (the helper uses the a0-normalised negative-a1 convention; `-y1*(-c)` ==
  `+y1*c`, same value) plus a named `ff` intermediate + wire renames. Same audio.
- **Timing clean: island clk_fpga_1 WNS +2.800 / 0 fail, fabric +0.657 / 0 fail,
  WHS +0.009, THS 0.** Resource MAPPING shifted vs D102 (DSP 137 -> 139, FF 30902
  -> 28920, LUT 31618 -> 30807): restructuring the biquad as ff+rec let Vivado
  pack more of the arithmetic into DSP48 blocks (trading FF for DSP) -- a larger
  P&R delta than D99/D102 but behaviour-preserving (VHDL-diff proven). bit/hwh md5
  `98c6593e3ab5537a1e1f8b875cef2af3` / (IP repack).
- **Status: DEPLOYED 5-site (board matched `98c6593e`), mode-2 smoke pass
  (~96.1 kHz, clocks alive). User accepted merge on the VHDL-equivalence proof
  (no ear bench).** New deployed baseline `98c6593e` (behaviour == D102
  `b18d1477` == bench-accepted D101 `9e09ff27`); rollback D102 via
  `/tmp/d102_backup`. Merged to main; branch `feature/refactor-biquad-helpers`.
  Remaining refactor candidates: D (Pipeline tap combinators), E (folded FIR
  helper), F (module splits), B2 (Pipeline biquadStage).

## D104 — Refactor E (folded-FIR helper) + F (Distortion/Amp module splits) [deployed, behaviour == D103]

- **Two refactors, NO audible change** (E + F of the "other refactorings" set;
  deployed audio bit-identical to the bench-accepted-lineage D103).
- **E (FixedPoint.foldTap).** The symmetric folded-FIR tap pair `(a+b)*g` (the
  DSP48 pre-adder form) was copied as a local `pm`/`pairMul` in
  `os4xDecimProducts`, `bigMuffClipProductsFrame`, and
  `cabSpeakerFirProductsFrame`; now one shared kernel. Centre taps use the
  existing `mulS10`. Same arithmetic.
- **F (module splits, code move only).** `AudioLab/Effects/Distortion.hs` ->
  `Distortion/{Common,Legacy,Pedals,Rat}.hs`; `AudioLab/Effects/Amp.hs` ->
  `Amp/{Models,Clip,Tone}.hs`. Each parent is now a thin re-export shim, so
  `Pipeline.hs` imports are unchanged (the D26 GUI/hdmi-state split pattern).
  Clash inlines all modules into the topEntity, so module boundaries do not
  appear in the netlist -- F changes only the `-- src/...` source-path comments
  in the generated VHDL.
- **Behaviour proven == D103.** Regenerated VHDL: `clash_lowpass_fir_types.vhdl`
  byte-identical; in the data VHDL the numeric-constant multiset (317 distinct)
  and operation counts (shift_right 248, `*` 169, `+` 277, `-` 190) are
  IDENTICAL -- the only diffs are signal renames (E names the foldTap FIR
  intermediates) + the source-path comments (F). Same audio output.
- **Timing clean.** Island `clk_fpga_1` WNS +2.647 / 0 fail, fabric +0.613 / 0
  fail, WHS +0.012, THS 0. bit/hwh md5 `c807fb3ae7e725fa2fb48f44275b2c82` / (IP
  repack).
- **Status: DEPLOYED 5-site (board matched `c807fb3a`), mode-2 smoke pass
  (~96.1 kHz, clocks alive). Merged on the VHDL-equivalence proof (no ear
  bench), same as D102/D103.** New deployed baseline `c807fb3a` (behaviour ==
  D103 `98c6593e`); rollback D103 via `/tmp/d103_backup`. Merged to main; branch
  `feature/refactor-foldtap-modsplit`. Remaining refactor candidates: D (Pipeline
  tap combinators) and B2 (Pipeline biquadStage) -- both higher-risk Signal-level
  changes, deferred.

## D105 — Revert DSP refactors B/C/E/F to D101 (safe-bypass P&R artifact); keep A

- **D104 (and the D102-D104 refactor-bitstream lineage) distorted on SAFE-BYPASS
  (all effects off); user bench-confirmed; rolled back to D101 (`9e09ff27`,
  clean).** This is the **D58/D59/D60-class P&R-induced bypass artifact**: the
  refactors (A/B/C/E/F) only changed gated-off effect-stage internals -- never
  the bypass datapath -- and were VHDL-logic-equivalent (constant + operation
  multisets identical) with clean timing (+2.6 island / +0.6 fabric), yet the
  netlist-structure change perturbed Vivado P&R enough to corrupt the
  passthrough. Static timing + logic-equivalence are necessary but NOT
  sufficient; only an ear bench catches this.
- **Process failure acknowledged.** D102/D103/D104 were merged on VHDL-
  equivalence proofs WITHOUT an ear bench (the user opted to skip listening for
  the "behaviour-identical" refactors). The standing project rule -- always
  bench-audition a new bitstream regardless of equivalence/timing -- was the
  thing skipped. Going forward: any new bitstream gets all_off-clean +
  touched-models bench before it can become the deployed baseline.
- **Revert.** DSP source + Clash VHDL + bit/hwh restored to D101 (`9e09ff27`):
  FixedPoint drops `biquadFf`/`biquadRec`/`biquad5` (B) + `foldTap` (E);
  Distortion.hs back to monolithic, drops `pedalDriveGain`/`distLevelRaw` (C) +
  the `Distortion/{Common,Legacy,Pedals,Rat}.hs` split (F); Amp.hs back to
  monolithic, removes the `Amp/{Models,Clip,Tone}.hs` split (F) + restores inline
  biquads (B); Cab.hs / Overdrive.hs back to D101. Verified: the restored source
  recompiles to byte-identical D101 VHDL; board re-deployed 5-site to `9e09ff27`,
  **bypass confirmed clean by the user.**
- **KEPT A** (bit-independent, cannot affect audio): `audio_lab_pynq/constants.py`
  (`SAMPLE_RATE_HZ`) + its use in `diagnostics.py` / `AudioLabOverlay.py` / the 7
  diagnostic scripts, and `tools/revoice.py`.
- **Deployed baseline is D101 again** (`9e09ff27`, the amp/RAT input-HP pole at
  298/209 Hz, bench-accepted). The B/C/E/F source work survives in git history
  (feature branches + the D102-D104 merges) -- only to be revisited WITH a real
  ear bench. The 96 kHz conversion (D98) + the HP-pole fix (D101) remain the
  accepted audible state; D99/D102/D103/D104 were behaviour-preserving refactors,
  of which the bitstreams are now abandoned. `DECISIONS.md` D105.

## D106 — Amp 2-5 kHz presence restore: BUILT, bench-REJECTED (bypass artifact), rolled back to D101

- **Attempt to fix the 96 kHz amp "muffled / presence recessed" voicing** (user
  report on D101: Amp Sim + Cab, 2-5 kHz presence recessed). Root cause: the 96 k
  re-voicing's plain +1-shift on the shift one-poles UNDER-preserves the corner
  for larger-a stages (original shift 1/2), darkening amp 2-5 kHz. Fix used a new
  shift+add helper `onePoleShift2 n m` (a = 2^-n + 2^-m, NO multiply, NO DSP
  increase): transformer HF -> onePoleShift2 2 5 (~5.0 kHz) + droop 3->4; amp
  tone high crossover + multiband mid/high -> onePoleShift2 3 7 (~2.2 kHz).
- **Build clean** (island +2.352 / fabric +0.565, 0 fail; DSP 137 unchanged; bit
  `33362e61`), deployed for bench. **Bench REJECTED: distorts on SAFE-BYPASS** --
  the SAME D58/D60/D105 P&R artifact, AGAIN, from a tiny no-DSP shift+add change.
- **CRITICAL finding: only the original D101 bit (`9e09ff27`) is bypass-clean;
  every DSP-source rebuild since (D102/D103/D104 refactors + D106) reproduces the
  artifact.** This design sits on a P&R-artifact knife-edge; Vivado P&R is
  deterministic so there is no "re-roll." **Voicing can no longer be safely
  changed via a DSP rebuild -- it must be done in the Python/control layer (knob
  tapers / preset defaults / EQ) on the D101 bit, or via the amp TREBLE/PRESENCE/
  EQ knobs.**
- **Rolled back to D101** (`9e09ff27`, 5-site; board needed a power-cycle after it
  dropped off the network during the failed deploy, then auto-redeployed). D106
  source is on branch `feature/amp-presence-restore` (NOT merged). Deployed +
  source baseline remain D101 (with A's `constants.py` Python kept from D102).
  `DECISIONS.md` D106; memory `project_96khz_conversion_d98`.

## D107 — Deployed baseline rolled back to D98 (D101 HP-pole made amp muffled + too loud)

- **User bench on D101: amp muffled (2-5 kHz presence recessed) AND output too
  loud.** Root cause = the D101 amp/RAT input HP pole. D98's input stage was the
  dead-pole first difference (`x - prevIn`), which has a rising HF response
  (bright top) and cuts the lows (lower level); D101 replaced it with a proper
  one-pole HP that removed the HF rise (-> darker / muffled) and passed the lows
  the first difference had cut (-> louder). The D101 pole had been bench-accepted
  earlier in isolation, but in full amp+cab use it is wrong. User referenced D98.
- **D98 (`18df313f`) is both the wanted amp character AND the only confirmed
  bypass-clean bitstream.** Every rebuild after D98 (D99 helpers, D101 pole, D102/
  D103/D104 refactors, D106 presence) either reproduced the D58/D60 safe-bypass
  P&R artifact or changed the amp badly. So the safe AND correct move is to pin to
  D98 exactly (no rebuild).
- **Reconcile.** main DSP source + Clash VHDL + bit/hwh restored to D98 (commit
  `0e4350a`): FixedPoint / Amp / Distortion / Compressor / NoiseSuppressor / Eq
  reverted (drops the D99 onePoleShift/onePoleHighpass/peakFollower helpers + the
  D101 live HP pole; restores D98 inline forms + the dead-pole first-difference
  input HP). KEPT (bit-independent): A's `constants.py` + consumers +
  `tools/revoice.py`, and the D99 stale `hw/ip/clash/clash/` tree removal.
- **Deployed 5-site to D98 `18df313f`; user-confirmed amp muffle + level fixed,
  bypass clean. D98 is the final deployed baseline.** D99-D106 (refactors A-F,
  the HP pole, the presence fix) are abandoned as deployed bits; their source is
  in git history only. **Hard lesson reaffirmed (D58/D60/D105/D106): this design
  is on a P&R-artifact knife-edge -- do NOT rebuild the DSP for voicing; only the
  D98 bit is known clean. Voicing changes must be Python/control-layer or via the
  amp tone/presence/EQ knobs.** Note: the board dropped off the network twice
  during rollback deploys and needed power-cycles. `DECISIONS.md` D107.

## D108 — Tried D101 for amp bass, REVERTED (D101 bypass also muffled; only D98 bypass-clean)

- **User wanted more amp bass on D98.** Amp bass is structurally absent on D98:
  the amp input stage is a first difference (`x - prevIn`, the dead-pole HP) that
  removes the lows BEFORE the tone stack, so the BASS knob (+/-3 dB post-clip)
  cannot restore them. Amp bass is a BITSTREAM property -- not Python-tunable.
- **D108 switched the deployed bit to D101** (`9e09ff27`, whose live input HP pole
  passes lows >=298 Hz) + Python-only amp defaults to compensate D101's earlier
  muffle/loudness (compact_v2 TREB 20->50, PRES 70->78, MSTR 70->55;
  AMP_DEFAULTS bass/treble/presence up, master down). No rebuild.
- **Bench: D101's BYPASS is muffled** -- so D101's bit ALSO carries a (milder,
  tonal) bypass P&R artifact, not just D102/D104/D106's gross distortion.
  **ONLY the D98 bit (`18df313f`) is truly bypass-clean.**
- **Reverted D108** (git revert) -> back to D98 `18df313f` + original defaults,
  redeployed 5-site. **Conclusion: there is NO safe way to add amp bass on this
  design** -- D98's bit removes it, D101's bit muffles bypass, and any rebuilt
  "gentle-HP" bit breaks bypass (the established P&R knife-edge). The amp is
  bass-light on the only clean bit by design. Deployed baseline = D98.
  `DECISIONS.md` D108.

## D109 — Safe-bypass knife-edge ROOT-CAUSED and BOUNDED (untimed audio CDC) + amp HP dead-pole fixed

- **Root cause of the D58/D60/D102-D106 safe-bypass "knife-edge"**, found by
  opening the D98 routed DCP (no rebuild): the build IS deterministic (the
  earlier md5-diff scare was only the `.bit` header timestamp; config-frame
  bodies are byte-identical), timing is fully MET (setup WNS +0.587 / hold WHS
  +0.020), so the artifact is NOT a timing violation. `report_cdc` shows the
  **DSP-output -> DAC path `clk_fpga_0 -> clk` has 112x CDC-13 "1-bit CDC path
  on a non-FD primitive"**: `axis_switch_sink` register-slice -> `i2s_to_stream_0`
  `trueDualPortBlockRamWrapper` RAM WE/data, i.e. a distributed-RAM async FIFO
  with NO scoped CDC constraints, left untimed by `set_clock_groups
  -asynchronous`. Any DSP netlist change shifts global placement -> the untimed
  write routing stretches -> passthrough audio is corrupted with no STA symptom.
  D98's placement happens to keep it tight; D99+ don't. So D101's "muffle" and
  D102/104/106's "distortion" were THIS CDC artifact, not the DSP voicing.
- **Fix (`hw/Pynq-Z2/audio_lab.xdc`):** split the single `set_clock_groups
  -asynchronous` into two so `clk_fpga_0` and `clk` are no longer in the same
  async group (they become timed vs each other; all other domains stay mutually
  async exactly as before), then `set_max_delay -datapath_only 10.000` both
  directions clk_fpga_0<->clk to bound the FIFO write path and make it visible
  to timing analysis.
  (set_max_delay cannot override a set_clock_groups -asynchronous on the same
  pair, so the pair must be ungrouped first.) Post-build report_cdc shows the
  exception flipped to "Max Delay Datapath Only" and timing stays MET (WNS
  +0.564 / WHS +0.007); the reset paths into i2s_to_stream meet the bound too.
- **Bench: all_off / safe-bypass is CLEAN on a CHANGED DSP source** -- the first
  time ever. This proved that the CDC bound materially improved rebuild
  robustness for that placement. Later D136-D144 builds showed that it does
  **not** make every placement safe; every regenerated bit still requires a
  safe-bypass ear-bench. Deployed bit `a7f18ff9`.
- Also fixed the amp input-HP **dead-pole** (`Amp.hs ampHighpassFrame`): the old
  `prevOut * 509 `shiftR` 9` parsed as `prevOut * (509>>9)` = `prevOut * 0` (a
  pure first difference = differentiator = bright but NO bass). Parenthesised to
  a live pole, coef 508/512 (~120 Hz HP) so the amp finally passes lows.
  `DECISIONS.md` D109; root cause in memory
  `project_safebypass_knifeedge_cdc_rootcause.md`. Golden D98 placement saved at
  `/tmp/d98_routed.dcp`.

## D110-D112 — Amp full revoicing after D109 bounded the DSP CDC; bench-ACCEPTED `c1e3de50`

- **Why:** the entire D55-D97 amp voicing was tuned against the amp's bright
  *differentiator* input (the dead-pole bug). D109 fixed that input to a flat
  ~120 Hz HP, so the downstream high-cuts (post-clip LPF darken, transformer HF
  droop, treble trims) over-darkened and the many cascaded always-on soft-clips
  over-compressed -> "muffled + amp-sim squash" on the bench. With D109
  constraining the previously untimed crossing, the amp was re-voiced toward a
  real-amp balance and still gated by an ear-bench.
- **D110** (first pass): halved `ampModelDarken`, transformer HF droop 3->4,
  treble-trim halved. Not enough (still muffled).
- **D111** (open up the compression): raised the cascaded always-on soft-clip
  knees -- power 3.4M->6.0M, master 3.3M->5.5M, midsat 4.0M->6.5M, respres
  3.4M->5.5M, transformer 5.2M->6.5M; asym-clip base 4.9M/4.35M -> 5.5M/4.9M;
  pre/de-emph amount 1->2; `ampModelDarken`/treble-trim minimised. Direction
  accepted by ear ("方向性はいい") but JC-120 clean now overflowed (master knee
  too high let satShift7 hard-clip) and the top still lacked air.
- **D112** (final, ACCEPTED): master knee 5.5M->4.5M (protective ceiling, JC-120
  clean no longer overflows); **`ampPreLowpass` baseAlpha 80->140** (post-clip LPF
  ~6 kHz -> ~12 kHz = the main "air"/HF-ceiling lever); **`ampTrebleGain` full
  treble** (removed the 8..16 kHz top rolloff `x - x>>3 - x>>4` -> `x`); amp
  Python defaults voiced clean (compact_v2 GAIN52/BASS52/MID58/TREB62/PRES72/
  MSTR50; lower GAIN/MSTR keep JC-120 clean, the user raises GAIN for drive).
- Timing fully MET throughout (D109 CDC `set_max_delay` bound holds). Deployed
  5-site, bit `c1e3de50`. **Bench: all_off clean, amp natural/open with extended
  top, JC-120 clean, tube models de-muffled -- user-accepted (合格).** New
  deployed baseline. `DECISIONS.md` D110-D112; `TIMING_AND_FPGA_NOTES.md`.

## D113 — Amp model-identity constant retune; deployed, bench pending

- **Why:** after D112 fixed the broad "muffled / amp-sim squash" problem, the
  next user request was to move the amp constants closer to the real hardware
  character. This is intentionally a constant-only voicing pass in
  `hw/ip/clash/src/AudioLab/Effects/Amp.hs`: no new GPIO, no topology change, no
  new stage, no new multiplier/helper.
- **What changed:** per-model Drive deltas and second-stage bonus now spread the
  lineup harder: JC-120/Twin stay cleaner, AC30 breaks up earlier, Rockerverb is
  thicker/darker, JCM800 has more bite/presence, and TriAmp is tighter/stronger
  with more fizz control. The previously-flat amp scoop biquad slots are filled:
  Rockerverb gets a +3 dB low-mid push at 500 Hz; TriAmp gets a -3 dB modern
  scoop at 750 Hz. Small shared realism trims restore a little transformer bloom,
  subtle HF iron softness, and mid-dependent grind without returning to D97's
  boxiness.
- **Verification / deploy:** Clash VHDL generation PASS, IP repackage PASS, full
  Vivado build PASS. Routed timing fully MET: WNS `+0.743 ns`, TNS `0.000`, WHS
  `+0.018 ns`, THS `0.000`; route errors `0`; bus-skew reports all `MET`.
  bit/hwh md5: `ed76421fa7a5c68c5e9e79ddae5c4526` /
  `b4deef57b8ceb9cada033dae8ecdcd3a`. `scripts/deploy_to_pynq.sh` deployed to
  PYNQ-Z2 `192.168.1.9`; all six bit/hwh sites md5-matched. Post-deploy smoke:
  `AudioLabOverlay()` loaded, ADAU1761 ADC HPF `True`, input digital volume
  `(0, 0)`, `pmod_status` present, Pmod I2S2 `VERSION=0x00480001`,
  `MODE=2 (dsp)` readback, `sdout_alive/bclk_seen/lrclk_seen=1`. A post-clear
  1 s Pmod status read still reached `PEAK_ABS_LEFT/RIGHT=8388607` with
  `CLIP_COUNT=735` under the current input, so tone acceptance should start
  with the input level checked/lowered. **Not ear-bench accepted yet; D112
  (`c1e3de50`) remains the accepted baseline until D113 is bench-approved.**

## D114 — Non-amp effect constant retune; built clean, file-synced, PL smoke blocked

- **Why:** after D113's amp-identity pass, the follow-up request was to review
  the other effect constants. D114 deliberately stays constant-only and within
  existing stages: no new GPIO, no topology change, no new effect stage, no new
  helper/multiplier, and `block_design.tcl` untouched.
- **What changed:** `Overdrive.hs` spreads the six selectable OD references
  further without a mux/topology change: TS9/OD-1/OCD get slightly more drive
  and lower knees, Centaur gets cleaner headroom, Jan Ray remains flatter, and
  the existing OD mid-biquad slots are filled for OD-1/OCD/Centaur with modest
  96 kHz RBJ Q14 peaking coefficients. `Distortion.hs` keeps DS-1 unchanged
  because of the D63/D64 history, but makes Clean Boost cleaner, Tube Screamer
  slightly softer, Metal less brittle, and RAT more like a controlled hard clip.
  `Cab.hs` keeps the accepted 15-tap speaker FIR topology but darkens the
  British/Closed choices slightly and reduces the micro-modulation depth/rate.
  `Reverb.hs` leaves delay topology unchanged and only makes high-TONE damping a
  little less dark.
- **Verification:** Clash VHDL generation PASS, IP repackage PASS, full Vivado
  build PASS. Routed timing fully MET: WNS `+0.601 ns`, TNS `0.000`, WHS
  `+0.010 ns`, THS `0.000`; route errors `0`; bus-skew reports all `MET`
  (minimum slack `+7.989 ns`). bit/hwh md5:
  `31c768eb4788f31de21bd30977614361` /
  `e380ed637f145a6377e29e13c45a098d`.
- **Deploy status:** `scripts/deploy_to_pynq.sh` successfully file-synced to
  PYNQ-Z2 `192.168.1.9`, and all six board bit/hwh sites md5-matched. However,
  the subsequent `AudioLabOverlay()` PL-load smoke timed out and the board
  stopped responding to ping/SSH. Therefore D114 is **not confirmed loaded on
  the FPGA** and **not ear-bench accepted**. A pre-load Pmod helper readback
  still showed mode 2 and live I2S clocks, but that only proves the previously
  loaded PL was alive; it also showed input clipping (`PEAK_ABS_LEFT/RIGHT =
  8388607`, post-clear 1 s `CLIP_COUNT=776`). Power-cycle the board, load
  `AudioLabOverlay()` once, set Pmod I2S2 mode 2, and re-run smoke/ear bench
  before accepting D114. Historical status: D112 stayed accepted at that point;
  D113/D114 were superseded by later accepted baselines and are not current
  acceptance targets.

## D115 — Python overlay facade split is bitstream-independent

- **Decision.** Continue P1 as Python-only, compatibility-preserving slices:
  `audio_lab_pynq/control_maps.py` owns GPIO byte/word packing, and
  `audio_lab_pynq/overlay/register_writers.py` owns the shared register-write
  and cached-word update helpers. `AudioLabOverlay` remains the public facade;
  existing public APIs and private helper names stay in place as delegates.
- **Why.** `AudioLabOverlay.py` is the most-touched Python module, and the
  register packing/writing logic was the riskiest part to keep inline because
  many GUI, encoder, footswitch, notebook, and direct API paths share it.
  Moving byte layout into `control_maps.py` and write-side bookkeeping into an
  `overlay/` helper package makes future per-effect setter splits smaller while
  preserving the deployed GPIO contract.
- **Boundaries.** This is not a DSP change. No Clash/VHDL/Tcl/XDC/bit/hwh
  rebuild is required, no GPIO name/address/byte semantics change, and
  `block_design.tcl` remains untouched. The accepted bitstream baseline is
  unchanged: D112 (`c1e3de50`) remains bench-accepted; D113/D114 are still
  bench-pending.
- **Verification / deploy.** Local verification passed:
  `tests/test_overlay_controls.py` (`129 passed`) and adjacent
  GUI/encoder/footswitch control tests (`217 passed`). Deployed to PYNQ-Z2
  `192.168.1.9` with `scripts/deploy_to_pynq.sh`; import sanity passed and a
  board-side Python smoke confirmed `audio_lab_pynq.overlay.register_writers`
  imports, `overdrive_match=True`, and D55 amp `ctrlD=0x84`. No PL load was
  performed for this Python-only deploy.
- **How to apply.** Future P1 work should keep using this pattern: split one
  narrow helper/setter group at a time into `audio_lab_pynq/overlay/`, leave
  `AudioLabOverlay` as the compatibility facade, and prove byte output/write
  order with focused snapshot tests before deploy.

## D116 — Pedalboard RAT owns routing into the existing RAT stage

- **Decision.** The Distortion pedalboard's `rat` slot remains mapped onto the
  existing dedicated RAT stage (D8), but every RAT-selected control path must
  forward the shared Distortion knobs into the RAT GPIO: `DRIVE -> rat_drive`,
  `LEVEL -> rat_level`, `MIX -> rat_mix`, and generic brightening `TONE` maps
  through `control_maps.rat_filter_from_tone()` to RAT's inverse-direction
  `FILTER` (`TONE` high = brighter, RAT `FILTER` low). This is Python/control
  routing only; no DSP topology or GPIO layout changes.
- **Why.** Some GUI/bridge/preset paths previously set the RAT pedal bit and
  gate bit 4 but left the dedicated RAT word at defaults, so the visible
  Distortion knobs did not actually shape the RAT stage. Other paths sent
  generic `TONE` directly to RAT `FILTER`, making the control feel backwards.
- **Boundary.** Standalone `set_guitar_effects(rat_on=True, rat_filter=...)`
  keeps the real RAT FILTER direction and remains supported. The pedal-mask
  writer tracks whether it owns gate bit 4 so switching from pedalboard RAT to
  another distortion pedal clears the RAT bit, while an independently enabled
  standalone RAT is preserved.
- **Verification / deploy.** Python-only verification passed:
  `git diff --check`, `py_compile`, targeted pytest (`166 passed`), direct
  script tests, and board-side Python 3.6 smoke. Deployed to PYNQ-Z2
  `192.168.1.9` with `scripts/deploy_to_pynq.sh`; import sanity passed,
  notebooks synced, and no PL load was performed. Accepted bitstream baseline
  remains D112 (`c1e3de50`); D113/D114 are still bench-pending.

## D117 — RAT highpass dead-pole fixed and RAT identity retuned

- **Decision.** Fix the live RAT DSP stage in
  `hw/ip/clash/src/AudioLab/Effects/Distortion.hs` instead of adding a new
  pedal path. RAT keeps the existing dedicated stage, GPIO word, pedal-mask bit
  2, and gate bit 4. The highpass feedback term is now explicitly parenthesized
  as `((prevOut * 505) `shiftR` 9)`, making the intended `505/512` pole live at
  the 96 kHz sample rate. The retune is constant-only inside the RAT path:
  slightly stronger drive gain, lower/stronger clip threshold, a slightly more
  open post low-pass, and a wider FILTER alpha range so FILTER open is brighter
  while the dark end still closes hard.
- **Why.** The weak-RAT report was not just Python routing. The RAT highpass had
  the same precedence failure class as the older Amp dead-pole bug:
  `prevOut * 511 `shiftR` 9` parses as `prevOut * (511 `shiftR` 9)`, which is
  `prevOut * 0`. That made the stage an accidental first-difference rather than
  a proper input highpass and undermined the RAT's low-end behaviour. Fixing the
  pole changes sound and therefore requires a full bitstream/bench cycle.
- **Boundaries.** No `block_design.tcl`, integration Tcl, XDC, GPIO address,
  GPIO byte layout, topEntity port, effect order, or new effect stage changed.
  This is a Clash/VHDL DSP voicing change plus regenerated IP artifacts and a
  rebuilt bit/hwh.
- **Verification / deploy.** `make -C hw/ip/clash all` passed (Clash VHDL
  generation and IP repackage). Full Vivado rebuild passed:
  `write_bitstream completed successfully`, route errors `0`, timing fully MET
  with WNS `+0.644 ns`, TNS `0.000`, WHS `+0.008 ns`, THS `0.000`, WPWS
  `+2.845 ns`; bus-skew constraints all met with minimum slack `+8.042 ns`.
  bit/hwh md5: `6dc84eaf46d2b19df3f600474ef749b4` /
  `1d05499010986cbe659af779f75e31f1`. Deployed to PYNQ-Z2 `192.168.1.9`;
  board md5 matched for the repo bitstream copy and the PYNQ overlays registry.
  Programmatic smoke loaded the new PL, Pmod I2S2 tone mode ran at 96 kHz
  (`FRAME_COUNT +192270` over 2 s, clocks/SDOUT alive), and RAT MMIO smoke
  confirmed `rat_filter_from_tone(76)=24`, `pedal_mask=0x04`,
  `gate_word=0xB2800914`, `distortion_word=0x047A26C2`, and
  `rat_word=0xB27A263D`. Targeted Python tests still pass (`166 passed`).
- **Acceptance status.** D117 is built, deployed, and PL-smoked, but **not
  ear-bench accepted**. D112 (`c1e3de50`) remains the accepted baseline until
  the user confirms RAT tone and safe-bypass/audio quality on the bench.

## D118 — Amp de-muffle constant retune; deployed + PL-smoked, bench pending

- **Decision.** Keep the existing Amp Simulator topology and retune only
  constants in `hw/ip/clash/src/AudioLab/Effects/Amp.hs` after the user reported
  that the amp still felt muffled. This pass preserves the D113 model-identity
  spread but backs off the darker trims that masked D112's recovered top end:
  lower `ampModelDarken` and Drive-mode `ampPreLpfDriveDarken`, reduce
  Rockerverb's low-mid push to +1.5 dB @ 500 Hz, reduce TriAmp's modern scoop to
  -2 dB @ 750 Hz, cut Rockerverb/TriAmp treble trims, open the per-model
  presence trims, and soften the shared transformer/mid compression
  (`ampTransformerKnee=6_700_000`, `ampTransformerHfDroop=6`, transformer
  resonance +1 dB @ 110 Hz, `ampMidSatKnee=6_800_000`).
- **Why.** D112 was bench-accepted because it reopened the amp after the D109 HP
  pole and CDC fixes. D113 then improved model identity, but its darker Orange /
  modern high-gain trims and shared transformer/mid realism settings could
  accumulate into a blanket over the amp, especially before the cab. D118 keeps
  the useful per-model differences while restoring more pick attack, chime, and
  presence.
- **Boundaries.** No GPIO address/byte layout, `block_design.tcl`, integration
  Tcl, XDC, topEntity port, effect order, Python API, or new effect stage
  changed. This is a Clash/VHDL DSP voicing change plus regenerated IP artifacts
  and a rebuilt bit/hwh.
- **Verification / deploy.** `make -C hw/ip/clash all` passed (Clash VHDL
  generation and IP repackage). Full Vivado rebuild passed:
  `write_bitstream completed successfully`, route errors `0`, timing fully MET
  with WNS `+0.754 ns`, TNS `0.000`, WHS `+0.016 ns`, THS `0.000`, WPWS
  `+2.845 ns`; bus-skew constraints all met with minimum slack `+8.355 ns`.
  bit/hwh md5: `c85ada776aa04c2501f1d21fa7d8f406` /
  `04361bc813afdf5194b7b4774a7eecde`. Deployed to PYNQ-Z2 `192.168.1.9`;
  deploy import sanity and notebook sync passed. Programmatic smoke loaded the
  new PL and ran Pmod I2S2 mode 2 (`dsp`) for 2 s:
  `VERSION=0x00480001`, mode readback `2`, `sdout_alive/bclk_seen/lrclk_seen=1`,
  frame delta `+192271` (~96 kHz), and ADC samples observed.
- **Acceptance status.** D118 is built, deployed, and PL-smoked, but **not
  ear-bench accepted**. The smoke saw the current physical input hit full scale
  (`PEAK_ABS_LEFT/RIGHT=8388607`, `CLIP_COUNT=118`), so bench judgement should
  start by lowering/checking the input level or loopback state. D112
  (`c1e3de50`) remains the accepted baseline until the user confirms D118 safe
  bypass and amp tone on the bench.

## D119 — Disable Amp power-sag master modulation; built, file-synced, smoke blocked

- **Decision.** Disable the dynamic power-sag master-level modulation in
  `hw/ip/clash/src/AudioLab/Effects/Amp.hs`. `ampMasterFrame` now ignores the
  sag envelope and applies the stable `ctrlB` MASTER byte directly for every
  amp model, followed by the existing D112 `softClipK 4_500_000` protective
  ceiling.
- **Why.** The user reported Amp ON volume pumping, then clarified that JC-120
  does not exhibit it. That exactly matched the old implementation: the sag
  path reduced final master level for tube models but forced `sagByte=0` for
  `ampModelIdxF == 0` (JC-120). The symptom is level modulation, not model
  identity, so the narrow fix is to remove sag from the master gain rather than
  retune the amp constants again.
- **Boundaries.** No GPIO address/byte layout, `block_design.tcl`, integration
  Tcl, XDC, topEntity port, effect order, Python API, or new effect stage
  changed. This is a Clash/VHDL DSP behaviour change plus regenerated IP
  artifacts and a rebuilt bit/hwh. The historical `ampSagEnv` source path may
  remain in the source/pipeline, but it no longer changes Amp output level.
- **Verification / deploy.** `make -C hw/ip/clash all` passed (Clash VHDL
  generation and IP repackage). Full Vivado rebuild passed:
  `write_bitstream completed successfully`, route errors `0`, timing fully MET
  with WNS `+0.699 ns`, TNS `0.000`, WHS `+0.013 ns`, THS `0.000`, WPWS
  `+2.845 ns`; bus-skew constraints all met with minimum slack `+8.020 ns`.
  bit/hwh md5: `88c265cc925cef4673277c1b49a79a02` /
  `8999e51470e6f6662e5b00e66390781b`. `scripts/deploy_to_pynq.sh` completed to
  PYNQ-Z2 `192.168.1.9`; deploy import sanity and notebook sync passed.
- **Acceptance status.** D119 is **not confirmed loaded on the FPGA** and **not
  PL-smoked**. The attempted Pmod I2S2 mode-2 smoke produced no output for over
  2 minutes; after interrupt, the board was unreachable (`ssh: No route to
  host`, ping `Destination Host Unreachable`, ARP incomplete). Power-cycle or
  restore board networking, load `AudioLabOverlay()` once, run Pmod mode-2
  smoke, then bench safe-bypass plus tube-model Amp volume stability before
  acceptance. D112 (`c1e3de50`) remains the accepted baseline.

## D148 — JC-120 / Fender-Twin clean-headroom fix (playing-only 音割れ) (2026-06-20)

- **Decision.** Raise only the clean-headroom of the two clean-platform amps so
  they stop breaking up at a hot-but-realistic pick, without touching Drive,
  other models, GPIO, clocks, topology, `block_design.tcl`, the D109 constraints,
  or the D146 pblock. Three placement-safe constant/mux changes in
  `AudioLab/Effects/Amp/`: `ampPowerKnee 0` (JC-120) `6.8M -> 8.2M`,
  `ampPowerKnee 1` (Twin) `4.6M -> 6.8M` (Models.hs), and a new clean-mode-only
  per-model `ampCleanKneeBonus` (Twin idx 1 = `2.5M`, every other model 0) added
  into `ampAsymClip`'s pos/neg knees ONLY when `drive == False` (Clip.hs). No new
  multiply (softClipK / ampAsymClip stay compare + shift). Builds on the
  D146 pblock + D147 sag branch `feature/d147-sag-attack`; D147's sag slew is
  retained.
- **Why.** D147 bench: JC-120 and Fender/Twin Reverb audibly clip, other models
  fine. User confirmed the safe-bypass (all effects off) is CLEAN and the 音割れ
  is **playing-only** — so this is purely a voicing headroom limit, not the CDC
  knife-edge. New `tools/dsp_sim/clip_onset.py` swept clean input level per model
  and localized it: at `input_gain 18 / master 60`, JC-120 stayed clean only to
  ~0.18 FS (THD 7% @0.25), Twin to ~0.12-0.18 FS (THD 12% @0.18); the gain models
  break up early by design and the user does not mind. JC-120 is sag-exempt and
  byte-identical to D135, so this clip exists in the accepted baseline too — the
  user is now asking to fix it. Localization: raising Twin's power knee did NOT
  move its onset (crest stayed high = soft-harmonic), proving Twin clips at the
  `ampAsymClip` waveshaper, while JC's clip is the power/master soft knee — hence
  the two different levers.
- **Offline result.** `clip_onset.py` after the fix: JC-120 and Twin both stay
  clean to ~0.25 FS (JC THD 0->1% @0.25, Twin 0.1% @0.18 / 8% @0.25). Surgical:
  the knees only engage above ~0.18 FS, so normal levels are byte-identical and
  **the golden regression passes 20/20 with NO re-bless** (bypass still bit-exact,
  every model byte-identical at golden levels). `measure.py --check` 28/28;
  `dist_eval.py --check` 7/7 pedals + 6/6 clean amps (JC/Twin clean THD @0.12 still
  0%, AC30/Rockerverb/JCM800/TriAmp byte-identical 13/23/23/15);
  `dynamics_eval.py --check` 4/5 (same pre-existing D141 `crunch_rig` slow-sag
  trade-off, not this change); `chord_eval.py --check-only` 2/6 — identical to
  D147 (JC -34.7 / Twin -33.6 pass), so D147's chord improvement is preserved.
- **Build / static gate.** Clash/VHDL/IP regen (new constants confirmed in the
  generated VHDL: 8200000 x3, 6800000 x3, 2500000 x2) + clean Vivado build pass.
  Timing fully MET: WNS `+0.526 ns`, TNS `0`, WHS `+0.014 ns`, THS `0`,
  WPWS `+2.845`; route errors `0` (59999 nets routed). D109 CDC pair MET; the
  pblock self-check forward path has `+1.632 ns` slack against its 6 ns window
  (arrival ~4.37 ns, slightly better than the bench-clean D147 ~4.6 ns); reverse
  `+2.972 ns`. XDC max_delay is the canonical 10 ns (not the rejected 6 ns). Hard
  pblock intact: `SLICE_X100Y116:SLICE_X113Y137`, 112 assigned cells. bit/hwh md5
  `972d9ba6645dd966e6bdcb5bc3daf478` / `2b888ff1ec3168cd64e1b679bbbc71be`.
- **Deploy / smoke.** All four runtime bit copies md5-match; 15/15 Notebooks
  valid. One-load mode-2 smoke PASS: mode 2, `FRAME_COUNT +288366/3 s` (~96 kHz),
  sdout/bclk/lrclk alive, ADC HPF True, CLIP_COUNT 0 (input full-scale, engine
  health only). Board left in mode 3 mute.
- **Bench verdict / acceptance status.** **BENCH-ACCEPTED ("完璧").** JC-120 and
  Fender/Twin clean no longer break up at a hot pick, other amp models unchanged,
  safe bypass still clean. `--no-ff` merged into `main`; D148 is the new accepted /
  committed baseline (D146 hard pblock + D147 sag slew + D148 clean headroom),
  superseding D135. `baselines.json` updated (D148 accepted-current, D135
  accepted-superseded). Rollback to D135:
  `git checkout 765323b -- hw/Pynq-Z2/bitstreams/` + deploy.

## D147 — Re-test only the Amp sag-attack slew after output-CDC containment (2026-06-20)

- **Decision.** Resume roadmap item 4 with one isolated voicing variable. In
  `AudioLab/Effects/Amp/Tone.hs`, replace the tube Amp sag follower's instant
  attack with `ampSagAttackStep = 96`; keep `ampSagReleaseStep = 512`, Amp
  enable/reset/idle behaviour, and every other voicing constant unchanged. Do
  not reapply D144's clean-mode knee/power-headroom bundle. The shared
  Compressor / Noise Suppressor / Fuzz Face `peakFollower` is untouched.
- **Why.** D141/D144 localized the perceived chord detune to sag-envelope
  beat-frequency AM, but D144 combined sag slew with a second headroom change
  and was bench-rejected while the safe-bypass CDC placement was uncontrolled.
  D147 separates the sag hypothesis on the D146 pblock branch so its acoustic
  effect can be judged independently.
- **Offline result.** Exact fixed-point `chord_eval.py --check-only` moves
  clean major-chord IMD from D135
  JC/Twin/AC30/Rockerverb/JCM800/TriAmp
  `-34.7/-15.8/-11.5/-7.7/-8.5/-8.3 dB` to
  `-34.7/-33.6/-17.3/-10.0/-11.0/-10.5 dB`. Twin newly passes, but AC30 and
  the three high-gain clean models remain above their ceilings: **2/6 pass**.
  This is a partial improvement, not a complete chord fix. `--check-only` was
  added so the acceptance ceilings can run without the exhaustive survey.
  `measure.py --check` passes 28/28; `dist_eval.py --check` passes 7/7 pedals
  plus 6/6 clean amps; regression pytest passes 20/20 after re-blessing only
  the five tube-amp goldens (bypass and JC-120 unchanged).
  `dynamics_eval.py --check` remains 4/5: only the already-documented
  `crunch_rig` slow-sag trade-off fails (`peak -2.6 dBFS`, `rms -6.0 dBFS`,
  clips 0), because sag no longer acts as an accidental fast limiter.
- **Build / static gate.** Clash/VHDL/IP regeneration and a clean Vivado 2019.1
  build pass. Timing is fully met: WNS `+0.686 ns`, TNS `0`, WHS `+0.021 ns`,
  THS `0`, WPWS `+2.845 ns`; route errors `0`; bus-skew minimum `+8.153 ns`.
  D109 CDC remains timed at `clk_fpga_0 -> clk +1.395 ns` and reverse
  `+6.497 ns`. The hard pblock remains
  `SLICE_X100Y116:SLICE_X113Y137`, with 112 assigned objects and 111/125
  source/target primitives. Its physical fingerprint is `116c19a6`. bit/hwh
  md5: `03bdbc2ffa6962e8d86135ed2f69e367` /
  `969834614ef6d4e2551f16e983dc6ab3`; routed DCP md5
  `7ded4991635702a3333896e180eb34e0`.
- **Deploy / smoke.** All four runtime bit/hwh copies md5-match. Deploy import
  checks and all 15 Notebook JSON checks pass. One-load mode-2 smoke passes:
  required IPs and clocks alive, ADC HPF `True`, `R19=0x23`, and
  `FRAME_COUNT +288542/3 s`. Input was full-scale (`CLIP_COUNT +56`), so this
  proves engine health only. All-off/Wah-off, Twin Clean, and AC30 Clean
  listening windows were presented; every window returned to mode 3 mute.
- **Bench verdict / acceptance status.** **Partial fail; candidate only.** The
  user reports that JC-120 and Fender/Twin Reverb audibly clip, while the other
  Amp models sound good. This is not explained by the 0.15-FS offline check:
  JC-120 is byte-unchanged/sag-exempt and measures clean, while Twin passes the
  chord ceiling. The earlier board smoke input was full-scale, so the next
  investigation must reproduce JC/Twin at controlled input levels and measure
  where the level-dependent clipping begins before changing more voicing. Do
  not attribute the JC symptom to sag without evidence. The user did not give a
  separate all-off buzz verdict; D146's three-placement ear verdict is also
  unresolved, and four of six offline chord ceilings still fail. Do not update
  `baselines.json` or call D147 accepted. Board remains on D147 in mode 3 mute;
  D135 remains the accepted baseline.

## D146 — Hard-pblock the placement-sensitive axis_switch_sink -> i2s_to_stream CDC (2026-06-19)

- **Baseline release marker.** Before changing the FPGA implementation, create
  annotated local tag `v1.0.0` at `eead0bf` (accepted D135 audio plus D145
  deploy-root fix). The tag is a rollback/release marker only; no remote git
  operation was performed.
- **Decision.** Keep the D109 clock relationship and bidirectional
  `set_max_delay -datapath_only 10.000` constraints unchanged, and add a hard
  implementation-only pblock around both sides of the placement-sensitive
  output crossing. `audio_lab_cdc_pblock.xdc` creates
  `pblock_audio_output_cdc` at `SLICE_X100Y116:SLICE_X113Y137` with
  `IS_SOFT=false`. It selects the transfer-mux-0 `gen_AB_reg_slice` primitives
  under `axis_switch_sink` and the write-side true-dual-port distributed RAM
  wrapper under `i2s_to_stream`.
- **Cell identification.** The cell names and region came from a fresh,
  timing-clean D135 routed checkpoint, not the stale D144 checkpoint. The
  read-only `report_cdc_fifo_placement.tcl` helper found all 112 D109 CDC-13
  paths, 111 matching source primitives, and 125 matching target primitives.
  Vivado folds the target primitives to the RAM hierarchy root when assigning
  the pblock, so the implemented pblock reports 112 assigned objects (111
  source primitives plus one target hierarchy root). Reopening the final routed
  DCP reproduces those selection counts and the pblock region.
- **Project integration.** `create_project.tcl` adds the XDC to `constrs_1` as
  `USED_IN_SYNTHESIS=false`, `USED_IN_IMPLEMENTATION=true`, and
  `PROCESSING_ORDER=LATE`, then emits CDC and pblock membership reports after
  implementation. `rerun_impl_with_cdc_pblock.tcl` provides the bounded
  synth-reuse/fresh-place-and-route workflow used for this candidate. No DSP,
  generated Clash/VHDL IP, GPIO, address, clock, AXI topology, or
  `block_design.tcl` change is included.
- **Build result.** Fresh D135 before the pblock was timing-clean (WNS
  `+0.643 ns`, WHS `+0.018 ns`; CDC `+1.433` / `+7.081 ns`). The D146 fresh
  implementation completed with all constraints met: WNS `+0.571 ns`, TNS
  `0`, WHS `+0.018 ns`, THS `0`, WPWS `+2.845 ns`; 59999 nets fully routed,
  route errors `0`; bus-skew minimum slack `+8.126 ns`. The D109 CDC pair is
  `clk_fpga_0 -> clk +3.131 ns` / reverse `+6.670 ns`, and all 112 CDC-13
  entries retain `Max Delay Datapath Only`. bit/hwh md5 are
  `55d431d9488d039fb1bfd9e4963871c8` /
  `9e4075000ecd338e24a355df36db7e8c`; routed DCP md5 is
  `f71922a1d3ede0c05c3efed4e4c6d2dc`.
- **Deploy / smoke.** `scripts/deploy_to_pynq.sh` completed file sync, import
  sanity, overlay registry sync, and 15/15 Notebook JSON validation on
  `192.168.1.9`. The first Pmod mode-2 attempt coincided with the board becoming
  unreachable before readback. After a cold restart, all four checked board
  bit copies md5-matched `55d431d9`, then the one-load smoke passed: required
  IPs present, ADC HPF `True`, `R19=0x23`, mode 2 readback, I2S clocks/SDOUT
  alive, and `FRAME_COUNT +288550` over 3 s (~96.18 kHz). Final mode 3 mute
  readback passed. The input was full-scale (`CLIP_COUNT +59`), so this proves
  engine health only and is not tonal acceptance.
- **Strengthened acceptance gate (roadmap item 3).** A single clean bit is not
  enough. `rerun_impl_with_cdc_pblock.tcl` now accepts a label plus place/route
  directives, archives each routed DCP/bit/hwh without replacing the deployed
  candidate, and emits a timestamp-free `cdc_placement.tsv` over all 236
  selected source/target primitives. D146 is stable only after at least three
  genuinely distinct placement fingerprints all meet setup/hold, route,
  bus-skew, D109 CDC/report, programmatic mode-2 smoke, and user all-effects-off
  safe-bypass listening. A failed variant rejects the pblock dimensions or
  cell selection; it must not be explained away by choosing the one clean bit.
- **Multi-build result.** `Explore` produced the same CDC placement fingerprint
  as default (`f7bde6a4`) and does not count as an independent sample. Three
  distinct placements passed every static and programmatic gate:
  - A / `Default`: fingerprint `f7bde6a4`, bit `55d431d9`, WNS/WHS
    `+0.571/+0.018 ns`, CDC `+3.131/+6.670 ns`, bus-skew minimum `+8.126 ns`,
    mode-2 frames `+288550/3 s`, clips `59`.
  - C / `ExtraNetDelay_high`: fingerprint `5b5a0f95`, bit `2eee129f`, WNS/WHS
    `+0.486/+0.016 ns`, CDC `+1.942/+6.768 ns`, bus-skew minimum `+8.160 ns`,
    mode-2 frames `+288533/3 s`, clips `24`.
  - D / `AltSpreadLogic_high`: fingerprint `f16c704e`, bit `01859530`, WNS/WHS
    `+0.383/+0.024 ns`, CDC `+0.911/+5.946 ns`, bus-skew minimum `+8.252 ns`,
    mode-2 frames `+288318/3 s`, clips `27`.
  All have TNS/THS `0`, route errors `0`, the expected pblock/cell counts and
  D109 exceptions, exact-md5 deploy copies, ADC HPF `True`, `R19=0x23`, and
  final mode 3 readback. All-off/Wah-off listening windows were presented for
  A/C/D. The input was full-scale during programmatic smoke, so only the user's
  explicit buzz/no-buzz verdict can close the acoustic column.
- **Acceptance status.** **Built, deployed and PL-smoked; multi-build and bench
  verdict is pending.** D146 is not in `baselines.json`; D135 (`765323b`, bit
  `533d5869`) remains the accepted committed baseline. The board is left on
  D146-D in mode 3 mute; the local tracked bit is restored to D146-A. The
  pblock is a structural mitigation, not proof that the constant digital buzz
  is gone.

## D145 — Discover the configured Jupyter root and verify all deployed Notebooks (2026-06-19)

- **Problem.** The user reported that the Notebook was not visible. All 15
  source and board `.ipynb` files existed and parsed as JSON, but
  `scripts/deploy_to_pynq.sh` inferred the live root from
  `/proc/<jupyter-pid>/cwd`. On this board that CWD is `/home/xilinx` while
  NotebookApp explicitly sets
  `notebook_dir=/home/xilinx/jupyter_notebooks`. The old inference therefore
  created a misleading duplicate `/home/xilinx/audio_lab/` tree and did not
  prove that the browser-visible tree was the one just refreshed.
- **Decision.** Treat `sudo jupyter notebook list` as the authoritative runtime
  root source and parse the path after `::`. Use process CWD only as a fallback
  for older images where the list command is unavailable. Install to
  `PYNQ_NB_DIR` and additionally to the detected root only when they differ.
- **Deploy invariants.** After `install_notebooks(...)`, recursively restore
  ownership to `xilinx:xilinx`, require the deployed top-level `.ipynb` count
  to match the repository source count, and parse every file with Python's
  `json` module. A truncated or missing Notebook now fails the deploy instead
  of leaving a successful-looking summary.
- **User-visible path.** The deploy summary now points directly to
  `http://192.168.1.9:9090/tree/audio_lab` and
  `/tree/audio_lab/AudioLab.ipynb`, while retaining `/tree` as the server-root
  link.
- **Verification / boundary.** Re-deploy completed against PYNQ-Z2
  `192.168.1.9`: the runtime root resolved to
  `/home/xilinx/jupyter_notebooks`, exactly one canonical tree was refreshed,
  all **15/15** Notebooks parsed as JSON, and the tree is owned by
  `xilinx:xilinx`. This is deploy/documentation only; no DSP, bit/hwh, GPIO,
  XDC, topology, or `block_design.tcl` change. D135 remains the accepted
  deployed bitstream.

## D144 — Chord-detune sim fix narrowly reapplied on D135; bench-REJECTED, rolled back to D135 (2026-06-19)

- **Decision.** Re-fix the user-reported "和音で音程が変" problem with the
  smallest simulation-proven subset on top of the accepted D135 baseline, not by
  reviving the whole bench-rejected D136-D142 amp-clean line. The change is
  Clash DSP only in `Amp/Tone.hs`, `Amp/Models.hs`, and `Amp/Clip.hs`; no
  GPIO/topology/XDC/block-design/topEntity-port/Python API change.
- **Root cause / sim evidence.** `tools/dsp_sim/chord_eval.py` reproduced the
  issue on a clean major triad at 0.15 FS: bypass floor `-35.7 dB`, JC-120
  `-34.7 PASS`, but Twin `-15.8`, AC30 `-11.5`, Rockerverb `-7.7`, JCM800
  `-8.5`, TriAmp `-8.3` FAIL with spurious ~60/145/290 Hz components. This is
  the D141 root cause: instant-attack `ampSagEnvNext` tracks chord beat ripple
  and amplitude-modulates `ampMasterFrame`, so sidebands read as detuned chords.
- **DSP change.** (1) Reintroduced the D141-style sag attack slew:
  `ampSagAttackStep = 96`, release unchanged, gate behaviour unchanged. Sag-only
  fixed Twin (`-33.6`) but left high-gain clean chords above the bypass floor.
  (2) Added a narrow clean-mode headroom bonus: `ampCleanKneeBonus` raises the
  model-local clean waveshaper knees in `ampAsymClip`, and
  `ampCleanPowerBonus` raises clean-mode power/resonance/master `ampPowerKnee`
  thresholds. These bonuses are zero in Drive mode; the sag attack change still
  affects tube sag generally. NOT included: D136-D142 clean preamp gain slope,
  per-model output normalization, JC clean normalization, drive-saturation
  retunes, or any placement/XDC mitigation.
- **Offline verification.** Final chord sim at 0.15 FS: bypass `-35.7`, JC
  `-34.7`, Twin `-33.6`, AC30 `-32.5`, Rockerverb `-32.9`, JCM800 `-33.5`,
  TriAmp `-33.9` -- all near the bypass floor. `measure.py --check` **28/28**,
  `dist_eval.py --check` **7/7 pedals + 6/6 amps clean**, and
  `DSP_SIM_TESTS=1 pytest tests/test_dsp_sim_regression.py` **20 passed** after
  intentional golden re-bless. `dynamics_eval.py --check` remains **4/5** with
  the known D141 trade-off: `crunch_rig` is ~2 dB above the old RMS ceiling
  (peak `-2.6 dBFS`, clips `0`) because slow sag no longer acts as an incorrect
  fast limiter.
- **Build / deploy / smoke.** `make -C hw/ip/clash regen` and full clean Vivado
  rebuild passed. Timing fully MET: WNS `+0.658 ns`, TNS `0`, WHS `+0.017 ns`,
  THS `0`, WPWS `+2.845 ns`, route failed/unrouted `0`; D109 CDC pair
  `clk_fpga_0 -> clk +1.090 ns`, `clk -> clk_fpga_0 +6.721 ns`. bit/hwh md5
  `8bf2894a452ba21b4881246af0c71967` /
  `6f80e240bae78381135a774fdacca1ba`. Deployed to PYNQ-Z2 `192.168.1.9`;
  smoke OK: `AudioLabOverlay()` loads, ADC HPF `True`, `R19_ADC_CONTROL 0x23`,
  Pmod mode 2 `FRAME_COUNT +288360` over 3 s (~96 kHz), required IPs present.
  Pmod returned to `MODE=3` mute for safety. The smoke input hit full scale
  (`CLIP_COUNT 6`), so it is not a tonal acceptance sensor.
- **Acceptance status / rollback.** User bench rejected this candidate
  ("失敗") and requested rollback to D135. D144 is **bench-REJECTED, not merged,
  not in `docs/ai_context/baselines.json`, and must not be treated as
  accepted**. Rollback completed by restoring DSP Clash source, regenerated
  VHDL/IP, golden vectors, and bit/hwh from D135 commit `765323b`. Local and
  board bit/hwh are back to D135 md5
  `533d586901dc3669285a49c6d82bab9f` /
  `731517487c6218f0e181c2b74485d7a6`. Deployed to PYNQ-Z2 `192.168.1.9`;
  board copies under `/home/xilinx/Audio-Lab-PYNQ/`,
  `audio_lab_pynq/bitstreams/`, and `/home/xilinx/pynq/overlays/audio_lab/`
  md5-match D135. Rollback smoke OK: `AudioLabOverlay()` loads, ADC HPF `True`,
  `R19_ADC_CONTROL 0x23`, Pmod mode 2 `FRAME_COUNT +288368` over 3 s (~96 kHz),
  required IPs present; Pmod returned to `MODE=3` mute. D135 (`765323b`, bit
  `533d5869`) is again the live deployed and accepted committed baseline. If
  chord-detune work resumes, do not reapply D144 as-is; first address the
  safe-bypass CDC knife-edge / placement sensitivity, then re-bench.

## D143 — ROLLBACK to D135: the D136-D142 amp-clean line is the safe-bypass CDC knife-edge; chord_eval.py kept (2026-06-19)

- **Decision.** The whole `feature/amp-clean-headroom` amp-clean line (D136-D142:
  clean-channel headroom, Clean/Drive separation, Fender level + sustain, the
  D141 chord-IMD power-sag slew fix, the D142 cleaner-clean knee + clean<=drive
  level) is **BENCH-REJECTED and rolled back to D135** (`533d5869`, merge
  `765323b`). The amp Clash source (`Clip.hs` / `Models.hs` / `Tone.hs`),
  regenerated VHDL/IP, golden vectors, and bit/hwh are restored to D135.
  `tools/dsp_sim/chord_eval.py` (the chord-IMD / alias detector) + its README
  entry are KEPT (the user asked to retain the chord simulation).
- **Why (root cause CONFIRMED).** The D142 bench symptom was a constant DIGITAL
  BUZZ ("ジー/バリバリ"), prominent with the amp on but **present even at amp-OFF
  (all effects off = bypass)** and constant at idle = the textbook safe-bypass
  CDC knife-edge: the DSP-out -> DAC `i2s_to_stream` FIFO write (112x untimed
  CDC-13 LUTRAM paths, `clk_fpga_0 -> clk`) corrupted by this build's placement;
  the amp merely amplifies the already-corrupted passthrough. Confirmed by
  rollback: **D135 amp-OFF is CLEAN, the amp-on buzz "消えた".** So it is
  build-specific, not physical/baseline, and NOT the voicing -- the offline sim
  showed the D142 voicing was correct (`chord_eval.py` clean chord IMD at/near
  the bypass floor on every model; clean RMS <= drive on every model; `measure`
  28/28, `dist_eval` 7/7+6/6, `knobcheck` 0 flags).
- **Two placement mitigations BOTH FAILED on the bench.** (1) Re-place via
  `STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Explore` (reuse synth_1) -> Vivado converged
  to a BYTE-IDENTICAL placement (config-frame body `cmp` == identical, only the
  `.bit` timestamp differed) = useless. (2) Tightening the D109
  `set_max_delay -datapath_only` 10.000 -> 6.000 ns on clk_fpga_0<->clk DID
  change the placement (different body) and pulled the worst clk_fpga_0->clk
  arrival 6.817 -> 4.368 ns with timing fully MET (WNS +0.611 / WHS +0.019) --
  but the bench STILL BUZZED. So neither a blind re-place nor a tighter CDC bound
  clears the knife-edge for the D136-D142 cumulative footprint, and the CDC-slack
  number does NOT predict the buzz (D141 +1.438 was heard without a buzz report;
  D142 +3.183 buzzed; D143-tightcdc arrival 4.368 buzzed).
- **Boundaries.** `block_design.tcl` untouched; the D109 two-`set_clock_groups` +
  `set_max_delay` XDC structure restored to 10.000 (the 6.000 experiment +
  `rerun_impl_replace.tcl` / `rerun_impl_tightcdc.tcl` were reverted/removed,
  uncommitted). No GPIO / address / topEntity-port change. No remote git op.
- **Status.** D135 is the current accepted/deployed baseline again
  (`baselines.json` current_deployed `765323b`; D141 `8a811e3` / D142 `041a007`
  added as bench-rejected with live md5s in `BASELINES.md`). Board redeployed +
  reloaded to clean D135 (all sites md5 `533d5869`; Pmod mode 2, ADC HPF True).
- **Next robust attack on the knife-edge (none quick; each needs an ear-bench).**
  (a) pblock-LOCK the `i2s_to_stream` + `axis_switch_sink` FIFO cells to a fixed
  region so the crossing stays tight regardless of DSP changes (need the cell
  names from a routed DCP) -- RECOMMENDED; (b) incremental P&R seeded from a
  freshly-built clean D135 routed DCP (the old one is gone, so rebuild clean D135
  first); (c) bisect D136-D142 for the minimal-footprint change that stays
  bypass-clean (the smaller the footprint, the safer per
  `project_safebypass_knifeedge_cdc_rootcause`). Do NOT keep blindly re-placing.

## D142 — Cleaner clean chords + clean <= drive level; BUILT, bench-REJECTED (knife-edge buzz), ROLLED BACK to D135 (`041a007`)

- **Decision.** User bench on D141: chords improved ("改善した") but asked for a bit
  more: "クリーンチャンネルをもっとクリーンに / まだ少しだけ和音が変" (cleaner clean,
  chords still slightly off) and "ドライブよりクリーンのほうがやや大きい" (clean slightly
  louder than drive). Candidate on top of D141, NOT accepted. Accepted baseline
  remains D135 (`533d5869`, merge `765323b`).
- **Objective findings.** (1) Single-tone clean THD was ALREADY ~0% @0.20 FS on
  every model -> the "汚い/和音が変" is a CHORD effect: a chord's summed peak is
  higher than a single note and still grazed the clean waveshaper knees, leaving a
  small residual in-band IMD (~2 dB above the chord floor). (2) Clean-vs-drive RMS
  per model (synth pluck): only JC-120 had clean LOUDER than its own drive (+0.5 dB);
  every tube model was already clean < drive (-1.6..-4.5). Clean is also less
  compressed (peaky) so it READS louder than its RMS = the perceived "clean louder".
- **DSP changes (clean-mode only; Drive byte-identical).** (1) `ampCleanKneeBonus`
  +1.0M each non-JC (Twin 3.3M / AC30 3.4M / Rockerverb 3.8M / JCM800 4.0M / TriAmp
  3.0M): the clean waveshaper knees rise so chord peaks stay below them -> clean
  chord IMD drops to the bypass floor (Twin/Rockerverb/TriAmp) / near-floor
  (AC30/JCM800 keep a touch of authentic class-A early breakup). Because it only
  un-clips peaks that WERE clipping, the normal-pluck clean LEVEL is unchanged
  (no level side effect). (2) JC-120 clean output normalization x0.88 -> x0.75
  (`(e>>1)+(e>>2)`): clean now sits ~1.0 dB UNDER its own drive. JC uses the SS
  clean path (no knee bonus), so only its level moved.
- **Verification (offline).** Clean-vs-drive RMS now clean <= drive on EVERY model
  (c-d JC -1.0 / Twin -3.7 / AC30 -2.3 / Rockerverb -2.6 / JCM800 -1.6 / TriAmp
  -4.5); clean chord IMD at/near the bypass floor at BOTH 0.10 and 0.20 FS. Full
  `--check` suite + golden re-bless + Vivado build _PENDING_ (results below on
  completion).
- **Boundaries.** No IR convolution, no `block_design.tcl`, no GPIO / address /
  topEntity-port / AXI-topology change, no new multiplier (constant-table +
  shift-add), no remote git op. Clash/VHDL/IP/bit/hwh regenerated.
- **Verification (offline, complete).** `measure.py --check` **28/28** (clean EQ
  unchanged = knee raise did not move the tone), `dist_eval.py --check` **7/7
  pedals + 6/6 amps 0% THD @0.12 FS**, `dynamics_eval.py --check` **4/5** (the
  same D141 crunch_rig overage -- crunch is JCM800 DRIVE, untouched by this
  clean-only change), `knobcheck.py --all` **0 barely-audible flags**. Clean-vs-
  drive RMS clean <= drive on every model; clean chord IMD at/near floor at 0.10
  and 0.20 FS.
- **Build.** Safe Clash regen + full clean Vivado rebuild. Timing fully MET: WNS
  `+0.547 ns`, TNS `0.000`, WHS `+0.024 ns`, THS `0.000`, WPWS `+2.845`, 0
  failing endpoints, 0 unrouted nets, all constraints met. **D109 CDC pair
  `clk_fpga_0 -> clk +3.183 ns` / `clk -> clk_fpga_0 +6.744 ns` -- forward slack
  `+3.183` is COMFORTABLY above the risky band (D130 clean +1.251 / D128 hiss
  +1.327 / D141 +1.438): LOWER knife-edge risk than the (bench-clean) D141.**
  bit/hwh md5 `83b33415ce962b8bcadee63cc36fca0f` /
  `74c6f12b33a3cdcf7b93dd32eb35bd9a`.
- **Smoke / status.** _Deploy + programmatic smoke below._ **Bench acceptance
  pending; checks: (1) clean channel cleaner / chords no longer off; (2) clean no
  longer louder than drive; (3) safe bypass (comfortable +3.183 CDC margin).**
  Branch `feature/amp-clean-headroom`; do not merge to `main` / update
  `baselines.json` until accepted. Rollback to D135 with `git checkout 765323b --
  hw/Pynq-Z2/bitstreams/` + deploy.

## D141 — Chord-IMD fix: slew-limit the power-sag attack (chords no longer "detune"); built/deployed, bench IMPROVED but ROLLED BACK to D135 with the rest of the amp-clean line (D143, knife-edge) (`e29012a8`)

- **Decision.** User on D140: "音程自体が変になってる気がする。特に和音" (notes/chords
  sound detuned, esp. chords) -> "和音のシミュレーションを更に強化して" (strengthen the
  chord sim) -> chose option B (clean all clean channels to JC level). Built a
  chord-IMD detector (`tools/dsp_sim/chord_eval.py`, commit `ba72fa5`) and the
  objective root cause turned out to be MORE localized than the proposed
  normalization gain-staging: the power-SAG attack. Fixed there. Candidate, NOT
  accepted. Accepted baseline remains D135 (`533d5869`, merge `765323b`).
- **Root cause (objective).** `chord_eval.py`: a CLEAN major triad
  (82+104+123 Hz) showed in-band 3rd-order IMD 12-19 dB above the bypass floor on
  every NON-JC model (Twin -23.4 / AC30 -16.3 / Rockerverb -19 / JCM800 -20 /
  TriAmp -19; spurious at ~60 Hz = 2f1-f2 and ~145 Hz), level-dependent, while
  JC-120 sat at the -34.7 floor and was level-independent. Localized to the
  power-SAG: `ampSagEnvNext` was an INSTANT-attack peak follower, so on a chord
  the peak envelope ripples at the beat frequency (here 104-82 = 22 Hz) and the
  follower tracked that ripple -> the master `effLevel = level - sagByte` is
  amplitude-modulated at the beat -> sidebands at note±beat = audible "detuned
  chord". Confirmed by a sag-disable test: Twin clean major IMD -23.4 -> -34.5
  (= the JC floor). JC-120 (idx 0) is sag-exempt, hence already clean.
- **DSP change.** Slew-limit ONLY the sag ATTACK: `ampSagAttackStep = 96`
  (env rises <= 96/sample, ~tens of ms to build); release unchanged
  (`ampSagReleaseStep = 512`). The follower can no longer track the fast beat
  ripple, so the master is no longer AM'd -> clean-chord IMD drops to the JC-like
  floor on ALL models (JC -34.7 / Twin -34.7 / AC30 -34.1 / Rockerverb -33.5 /
  JCM800 -33.7 / TriAmp -33.7). The sag still reaches the same STEADY-STATE on a
  sustained loud passage, so bloom/sustain is preserved (`dist_eval` sustain
  BigMuff 2.04x / Metal 1.99x unchanged). One file: `Amp/Tone.hs`. No new
  multiply (compare + add/shift). JC-120 path unchanged.
- **Known trade-off (documented, accepted).** The instant attack was also
  incidentally PEAK-LIMITING. Slowing it lets the most aggressive rig
  (`dynamics_eval` crunch_rig = cranked JCM800 master 68 + OD-90 boost + cab) run
  ~2 dB hotter: rms -6.0 vs the -8.0 balance ceiling -> `dynamics_eval` 4/5. This
  is NOT clipping (peak -2.6 dBFS, clips 0) and is intrinsic to that extreme
  patch: established robust across a full attack sweep (96->1024 only moves
  crunch -6.0 -> -7.2, still over) AND a JCM800 power-knee trim test (3.3M->2.6M
  bought only +0.7 dB and dulled JCM800, so reverted). A real power-supply sag IS
  slow; the old fast sag was an incorrect fast-limiter that happened to mask this
  cranked patch. Accepted as a non-clipping balance overage on the worst-case
  config; normal patches (lower master, no OD stack) rarely engage the sag hard,
  so the level impact there is negligible.
- **Boundaries.** No IR convolution, no `block_design.tcl`, no GPIO / address /
  topEntity-port / AXI-topology change, no new multiplier (slew = compare +
  add/shift), no remote git op. Clash/VHDL/IP/bit/hwh regenerated.
- **Verification (offline).** `measure.py --check` 28/28, `dist_eval.py --check`
  7/7 pedals + 6/6 clean amps (0% THD @0.12 FS), `dynamics_eval.py --check` 4/5
  (crunch_rig overage above, by design), `knobcheck.py --all` only the known
  TREBLE tilt false positive. `chord_eval.py` clean-chord IMD now JC-like on all
  models. Golden re-bless changed amp_twin/ac30/rockerverb/jcm800/triamp (the sag
  is mode-independent so BOTH their clean and drive goldens move); amp_jc120
  (sag-exempt) + bypass + all pedal/cab/reverb goldens byte-identical (bypass
  bit-exact).
- **Build.** Safe Clash regen + full clean Vivado rebuild. Timing fully MET:
  WNS `+0.509 ns`, TNS `0.000`, WHS `+0.013 ns`, THS `0.000`, WPWS `+2.845`,
  0 failing endpoints, 0 unrouted nets, all user-specified constraints met.
  **⚠️ D109 CDC pair `clk_fpga_0 -> clk +1.438 ns` / `clk -> clk_fpga_0
  +6.507 ns` -- forward slack `+1.438` is in the historically-risky band
  (above D130 clean `+1.251` and D128 hiss `+1.327`, near D137 `+1.710`,
  tighter than D135 `+6.139` / D140 `+5.582`). Per
  `project_safebypass_knifeedge_cdc_rootcause` this number is a NON-MONOTONIC
  risk indicator, not a predictor -- could be clean or hiss -- so the
  safe-bypass ear-check is the decider.** bit/hwh md5
  `e29012a8935b19630653ae2eabde7949` / `c7763bd8e9f2dd384ef16073dcc3e9a8`.
- **Smoke / status.** _Deploy + programmatic smoke below._ **Bench acceptance
  pending; PRIORITY CHECK = safe bypass (all effects off) given the +1.438 CDC
  margin, plus the chord/detune fix on clean amps.** Branch
  `feature/amp-clean-headroom`; do not merge to `main` / update
  `baselines.json` until accepted. Rollback to D135 with
  `git checkout 765323b -- hw/Pynq-Z2/bitstreams/` + deploy.

## D140 — JC-120 output trim + dirty-sustain cleanup (clean tone untouched); deployed/smoked, bench pending (`495efbf7`)

- **Decision.** User on D139: amp better ("マシになった"), but JC output still too
  loud, the non-Fender cleans still a bit dirty, and the sustain is gritty -- and
  on reflection "クリーンはあまり修正をしなくてよかった" (the clean did not need heavy
  fixing). So: NO further clean-tone processing; fix only JC level + the dirty
  sustain. Deployed candidate, NOT accepted. Accepted baseline remains D135
  (`533d5869`, merge `765323b`).
- **DSP changes.** (1) Dirty sustain: D138 had LOWERED `ampCleanPowerBonus` so
  the power `softClipK` compresses to make sustain, but that clips the sustained
  tail = gritty. Raised the bonus back to the D137 values (clean power stage);
  the smooth power-SAG envelope (`ampSagEnvNext`, no harmonics) carries the
  sustain/bloom instead. (2) JC too loud: JC is solid-state and does not
  compress, so its peaks ride hot (clean peak 0.56 vs lineup ~0.30). Pulled JC's
  master normalization ~2 dB under the lineup (clean x1.16->x0.88 / drive
  x0.69->x0.50); its clean peaks compress to 0.43/0.45. Side benefit of (1) (no
  new clean processing -- just undoing D138's over-compression): the non-Fender
  clean THD @0.15 FS drops AC30 13->8 / JCM800 15->6 / Rockerverb 2->0. CLEAN
  tone otherwise untouched; Drive voicing unchanged; the other 5 models' levels
  unchanged (-15.0..-15.3, spread 0.3 dB; JC -17.6/-18.3 by design).
- **Boundaries.** No IR convolution, no `block_design.tcl`, no GPIO / address /
  topEntity-port / AXI-topology change, no new multiplier (constant-table +
  shift-add), no remote git op. Clash/VHDL/IP/bit/hwh regenerated.
- **Verification (offline).** `measure.py --check` 28/28, `dist_eval.py --check`
  7/7 pedals + 6/6 clean amps (JC/AC30/JCM800 0% THD @0.12 FS), `dynamics_eval.py
  --check` 5/5, `knobcheck.py --all` only the known TREBLE tilt false positive.
  Golden re-bless changed ONLY amp_jc120 (the JC level trim); bypass + Drive +
  Twin-clean + all pedal/cab/reverb goldens byte-identical (bypass bit-exact;
  the AC30/JCM/Rockerverb clean cleanup is clean-mode only and those goldens are
  drive).
- **Build.** Safe Clash regen + full clean Vivado rebuild. Timing fully MET:
  WNS `+1.005 ns` (best of the line), TNS 0, WHS `+0.028 ns`, THS 0, WPWS
  `+2.845`, route errors 0, all constraints met. **D109 CDC pair
  `clk_fpga_0 -> clk +5.582 ns` / `clk -> clk_fpga_0 +6.632 ns` -- forward slack
  +5.582 is very comfortable (near D135 +6.139): low safe-bypass knife-edge
  risk.** bit/hwh md5 `495efbf7ddb5debf182d73c73df4e6ac` /
  `9225bca3a066550d8394af0fc7ff00dd`. `scripts/deploy_to_pynq.sh` completed;
  board bit sites md5-match.
- **Smoke / status.** Pmod mode 2 smoke + ADC HPF check below. **Bench
  acceptance pending.** Branch `feature/amp-clean-headroom`; do not merge to
  `main` / update `baselines.json` until accepted. Rollback to D135 with
  `git checkout 765323b -- hw/Pynq-Z2/bitstreams/` + deploy.

## D139 — Clean breakup-at-hard-input fix + per-model volume normalization; superseded by D140 (`aa7cf3ed`)

- **Decision.** User: "アンプがめちゃくちゃ" + "ボリュームもまちまちすぎ"; asked to
  evaluate objectively in sim the axes not yet captured, and fix. Confirmed it is
  a VOICING problem, not the CDC hiss (D138 safe-bypass was clean). Builds on
  D136-D138. Deployed candidate, NOT accepted. Accepted baseline remains D135
  (`533d5869`, merge `765323b`).
- **New objective tool.** Added a broad **alias/THD-vs-input-level diagnostic**
  (1 kHz sine swept 0.08..0.40 FS; reports THD%, the `nonharmonic_dBFS` alias/
  harshness floor relative to the fundamental, and peak) -- the "unverbalized"
  axis the earlier fixed-0.15-FS THD metric missed.
- **Findings.** (1) CLEAN distorted hard at a realistic pick (0.25 FS: 21-38%
  THD + a rising alias floor) -- the preamp input-gain stage
  (`ampDriveMultiplyFrame`, gain `128 + ctrlA*9`, unity 128) amplifies x2.27 even
  at a low gain knob (ctrlA 18) and drives the 5-stage soft-clip cascade
  (waveshape -> 2nd-stage -> power -> resonance-mix -> master). (2) Per-model
  output level spread 3.5 dB clean / 3.4 dB drive, and the earlier ad-hoc JC
  -3.25 / Twin +3.5 master trims had become BACKWARDS after the gain changes.
- **DSP changes.** (a) Clean-mode preamp gain slope `9 -> 4` in
  `ampDriveMultiplyFrame` (a real amp's clean channel has less preamp gain; Drive
  keeps slope 9): clean now stays clean across the input range -- THD @0.15
  5-26% -> 0-15%, @0.25 21-38% -> 3-25%; alias floor at low input -39 -> -76..-97
  dB. (b) AC30/JCM800 clean knee bonus bumped (they have the lowest waveshaper
  knees). (c) Replaced the ad-hoc JC/Twin trims with a principled **per-model +
  per-mode output normalization** in `ampMasterFrame` (shift-add, NO new
  multiplier, saturating Unsigned-9): all six models land at -15.0..-15.4 dBFS
  (spread **0.3 dB**, was 3.5), and CLEAN == DRIVE level per model (no jump on
  channel switch -- the clean makeup also restores the ~3-5 dB the clean
  input-gain reduction removed). JC SS clean character and the Drive voicing
  where normalization is x1.0 are unchanged.
- **Boundaries.** No IR convolution, no `block_design.tcl`, no GPIO / address /
  topEntity-port / AXI-topology change, **no new multiplier** (gain slope is a
  constant on the existing `mulU12`; normalization is shift-add), no remote git
  op. Clash/VHDL/IP/bit/hwh regenerated.
- **Verification (offline).** `measure.py --check` 28/28 (tone curves measured
  below the clips, unaffected), `dist_eval.py --check` 7/7 pedals + **6/6 clean
  amps now 0-1% THD @0.12 FS** (AC30 6% -> 0%), `dynamics_eval.py --check` 5/5,
  `knobcheck.py --all` only the known TREBLE tilt-control false positive. Golden
  re-bless changed ONLY amp_jc120/twin/ac30/triamp (the configs whose clean
  gain or per-mode normalization changed); **bypass + jcm800/rockerverb-drive +
  all pedal/cab/reverb goldens byte-identical** (bypass bit-exact).
- **Build.** Safe Clash regen + full clean Vivado rebuild. Timing fully MET:
  WNS `+0.932 ns` (best of the recent line), TNS 0, WHS `+0.009 ns`, THS 0,
  WPWS `+2.845`, route errors 0, all constraints met. **D109 CDC pair
  `clk_fpga_0 -> clk +2.111 ns` / `clk -> clk_fpga_0 +7.271 ns` -- forward slack
  +2.111 is comfortably ABOVE the D130 clean (+1.251) and D128 hiss (+1.327)
  refs, and far better than D138 (+1.053): lower knife-edge risk.** bit/hwh md5
  `aa7cf3ed9663f973bfb65945063af50c` / `f79683004d0725934d075d50a713325b`.
  `scripts/deploy_to_pynq.sh` completed; board bit sites md5-match.
- **Smoke / status.** `test_pmod_i2s2.py --mode dsp` loaded the new bit; Pmod
  mode 2 ran 3 s `FRAME_COUNT +288361` (~96 kHz), sdout/bclk/lrclk alive, ADC
  samples observed. ADC HPF `True` via `download=False`; Pmod returned to
  `MODE=3` mute. **Bench acceptance pending.** PRIORITY checks: (1) safe bypass
  clean (CDC margin is comfortable so expected fine), (2) CLEAN stays clean on
  hard picking on every model, (3) volume consistent across models and across
  clean/drive. Branch `feature/amp-clean-headroom`; do not merge to `main` /
  update `baselines.json` until accepted. Rollback to D135 with
  `git checkout 765323b -- hw/Pynq-Z2/bitstreams/` + deploy.

## D138 — Twin/Fender output boost + restored tube power-amp sustain; superseded by D139 (`01e296cd`)

- **Decision.** User (going to sleep, "do maximum work") reported Fender (Twin)
  too quiet vs the lineup and tube-amp sustain hard to hear; asked to find the
  cause objectively in sim and fix. Builds on D137 (keeps its Clean/Drive
  separation + JC trim). Deployed candidate, NOT accepted. Accepted baseline
  remains D135 (`533d5869`, merge `765323b`).
- **Objective findings (sim, `level_sustain.py`).** (1) Twin output -17.1 dBFS
  Clean / -17.0 Drive = the quietest model by 2-5 dB (low makeup gain from
  char 78 + the 400 Hz scoop). (2) Tube CLEAN sustain only 1.35-1.51x: the
  D136/D137 clean-power bonus had raised the power / resonance-mix / master
  `softClipK` knees so high that the tube amps stopped compressing in Clean
  mode, removing the power-amp compression that sustains notes (the loud attack
  soft-clips, the decaying tail recovers -> tail blooms = audible sustain).
- **DSP changes.** (1) Twin (idx 1) ~+3.5 dB master boost in `ampMasterFrame`
  (x1.5 via a saturating Unsigned-9 add so a hot MASTER cannot wrap; the 4.6M
  master `softClipK` gently catches peaks so it stays clean); other models'
  master byte-for-byte unchanged. (2) `ampCleanPowerBonus` pulled back ~half on
  AC30/Rockerverb/JCM800/TriAmp (2_200_000/1_800_000/1_600_000 etc.) so the
  SOFT power `softClipK` compresses again = restored sustain/bloom, while the
  clean TONE is still held by the unchanged waveshaper clean bonus
  (`ampCleanKneeBonus`). JC-120 (SS) and all Drive-mode voicing unchanged.
- **Result (sim).** Twin -13.6/-13.5 (now level with the lineup: JC -14.8,
  JCM -14.8, Rockerverb -13.9). Tube clean sustain 1.56-1.61x (was 1.46-1.51).
  Clean THD @0.12 FS still clean: JC 0 / Twin 0 / AC30 6 / Rockerverb 10 /
  JCM800 6 / TriAmp 4 (all under ceilings). `measure.py --check` 28/28,
  `dist_eval.py --check` 7/7 pedals + 6/6 clean amps. Golden re-bless changed
  ONLY `amp_twin` (Twin clean boost); `bypass` + all other amp/pedal/cab/reverb
  goldens byte-identical -> Drive voicing + JC + bypass unchanged.
- **Boundaries.** No IR convolution, no `block_design.tcl`, no GPIO / address /
  topEntity-port / AXI-topology change, no new multiplier (boost is a saturating
  add, sustain is the existing softClipK), no remote git op. Clash/VHDL/IP/bit/
  hwh regenerated.
- **Build.** Safe Clash regen + full clean Vivado rebuild. Timing fully MET:
  WNS `+0.625 ns`, TNS `0.000`, WHS `+0.018 ns`, THS `0.000`, WPWS `+2.845`,
  route errors `0`, all constraints met. **⚠️ D109 CDC pair
  `clk_fpga_0 -> clk +1.053 ns` / `clk -> clk_fpga_0 +6.774 ns`.** The forward
  slack `+1.053` is the TIGHTEST in project history (D135 `+6.139` -> D137
  `+1.710` -> D138 `+1.053`), BELOW both the D130 clean reference (`+1.251`)
  and the D128 hiss reference (`+1.327`) -- the cumulative D137 drive-saturation
  logic + this build's placement eroded the margin. Per
  `project_safebypass_knifeedge_cdc_rootcause` the slack is a RISK INDICATOR,
  not a strict predictor (non-monotonic: D130 clean at +1.251, D128 hiss at
  +1.327), so it COULD be clean or COULD hiss -- **safe-bypass ear-check is the
  decider and this build is higher-risk than any shipped before.** bit/hwh md5
  `01e296cd53c9aa7fa9422a2c21cb7e22` / `8b1fba7377ab56f74782e92d8c225485`.
  `scripts/deploy_to_pynq.sh` completed; board bit sites md5-match.
- **Smoke / status.** `test_pmod_i2s2.py --mode dsp` loaded the new bit; Pmod
  mode 2 ran 3 s `FRAME_COUNT +288364` (~96 kHz), sdout/bclk/lrclk alive, ADC
  samples observed (programmatic smoke CANNOT detect the knife-edge hiss).
  ADC HPF `True` via `download=False`; Pmod returned to `MODE=3` mute.
  **Bench acceptance pending. PRIORITY CHECK = safe bypass (all effects off):
  if it hisses/buzzes, this build hit the knife-edge -- roll back to D135 with
  `git checkout 765323b -- hw/Pynq-Z2/bitstreams/` + `bash
  scripts/deploy_to_pynq.sh`, and the next attempt must shrink the DSP footprint
  (the drive-saturation logic) to recover CDC margin.** Branch
  `feature/amp-clean-headroom`; do not merge to `main` / update `baselines.json`
  until accepted.

## D137 — Clear Clean/Drive separation on all models + JC-120 output trim; superseded by D138 (`bed234ec`)

- **Decision.** After D136 was deployed the user bench-reported that (a) Clean
  and Drive sounded nearly identical across all models, and (b) JC-120 ran too
  loud. Offline confirmed: the gain models' Clean was still ~11-15% THD @0.15 FS
  (already breaking up, so the step to Drive was small), Drive was barely hotter
  (dTHD only +12..+26, dRMS ~0/negative), and JC-120 used an identical 7.5M knee
  in both modes (no Clean/Drive difference) while never compressing, so it ran
  +3..+6 dB louder than the rest. Treat as a deployed candidate, not accepted,
  until the user bench-listens Clean-vs-Drive on every model, JC level, and
  **safe bypass** (see the CDC note below). D136/accepted-baseline D135 remain
  the rollback targets.
- **DSP changes.** (1) Clean channel genuinely clean: `ampCleanKneeBonus` /
  `ampCleanPowerBonus` raised further (Clean / drive_mode 0 only). (2) Drive
  clearly hotter: per-model asym-clip drive-knee deltas (`ampDrivePosDelta` /
  `ampDriveNegDelta`) and `ampSecondStageDriveBonus` increased on every tube
  model. (3) JC-120: the single 7.5M clean knee became a mode-dependent SS knee
  `ampJc120Knee` (Clean 4.6M / Drive 3.2M) so JC has a real but still-cleanest
  Drive breakup, plus a model-0-only ~-3.25 dB master output trim
  (shift+subtract in `ampMasterFrame`) to level it with the lineup. Result
  (THD @0.15 FS): Clean JC 0 / Twin 1 / AC30 8 / Rockerverb 8 / JCM800 5 /
  TriAmp 3; Drive 17 / 15 / 31 / 35 / 38 / 26 -> dTHD +14..+33 (a clear,
  obvious Clean->Drive step on every model incl. JC). JC clean output pulled
  ~3 dB so it is no longer the loudest. Drive-mode-only paths keep Clean
  intact; bypass stays bit-exact (golden `bypass` unchanged).
- **Boundaries.** No IR convolution, no `block_design.tcl`, no GPIO / address /
  topEntity-port / AXI-topology change, no new multiplier (knees + trim are
  compare/shift/subtract), and no remote git op. Clash/VHDL/IP/bit/hwh
  regenerated because DSP behaviour changed.
- **Verification (offline).** `measure.py --check` 28/28 (tone curves are
  measured below the clip knees, so the bonuses are inert there -- intended),
  `dist_eval.py --check` 7/7 pedals + 6/6 clean amps (all <=1% THD @0.12 FS),
  `dynamics_eval.py --check` 5/5. Goldens re-blessed for the 5 amp configs
  (jc120/ac30/jcm800/rockerverb/triamp); `bypass` + Twin-clean + all pedals/cab/
  reverb goldens unchanged. `knobcheck.py --all` flagged only Amp TREBLE as
  "barely audible" -- a known false positive of the overall-RMS heuristic on a
  TILT control (TREBLE still tilts +0.9 dB @8 kHz vs -0.6 @200 Hz); the hotter
  Drive op-point compresses the top slightly. Not a dead knob.
- **Build / deploy.** Safe Clash regen (`make -C hw/ip/clash regen`) + full clean
  Vivado rebuild. Timing fully MET: WNS `+0.565 ns`, TNS `0.000`, WHS
  `+0.019 ns`, THS `0.000`, WPWS `+2.845`, route errors `0`, all constraints
  met. **D109 CDC pair `clk_fpga_0 -> clk +1.710 ns` / `clk -> clk_fpga_0
  +6.121 ns`.** The forward slack `+1.710` is in the historically-risky band:
  above the D130 CLEAN reference (`+1.251`) and the D128 HISS reference
  (`+1.327`), but much tighter than D135 (`+6.139`). Per
  `project_safebypass_knifeedge_cdc_rootcause` the number is a RISK INDICATOR,
  not a predictor -- **safe-bypass ear-check is the decider; if it hisses, roll
  back to D135 and rebuild smaller-footprint.** bit/hwh md5
  `bed234ecf49b44207f4c35b236c49f3e` / `7035137105683a09fee8b6c93da7ef2d`.
  `scripts/deploy_to_pynq.sh` completed; board bit sites md5-match.
- **Smoke / status.** `test_pmod_i2s2.py --mode dsp` loaded the new bit; Pmod
  mode 2 ran 3 s with `FRAME_COUNT +288374` (~96 kHz), `sdout_alive=1` /
  `bclk_seen=1` / `lrclk_seen=1`, ADC samples observed (smoke input clipped
  full-scale -- level artifact, as prior baselines). ADC HPF `True` via a
  `download=False` attach; Pmod returned to `MODE=3` mute. **Bench acceptance
  is pending; safe bypass is the priority check.** Branch
  `feature/amp-clean-headroom`; do not merge to `main` or update
  `baselines.json` until the user confirms. Rollback to D135 with
  `git checkout 765323b -- hw/Pynq-Z2/bitstreams/` + deploy.

## D136 — Amp clean-mode headroom (clean channel stays clean); superseded by D137 before bench (`9ffa7ff3`)

- **Decision.** User reported the amp distorted too much even on the Clean
  channel. Offline measurement confirmed it: only JC-120 (idx 0) had real clean
  headroom (its dedicated 7.5M symmetric knee); every other model ran the
  per-model `ampAsymClip` at full character intensity even in Clean mode plus
  was re-clipped by the shared power / resonance-mix / master `softClipK`
  ceilings (~3.3-3.4M), so "Clean" broke up at a realistic guitar level
  (clean-mode THD at 0.20 FS: Twin 17% / AC30 29% / Rockerverb 32% /
  JCM800 36% / TriAmp 23%). Treat as a deployed candidate, not an accepted
  baseline, until the user bench-listens the clean channel and safe bypass.
  Accepted baseline remains D135 (`533d5869`, merge `765323b`).
- **DSP changes (Clean-mode only; Drive byte-identical).** Two per-model
  Clean-mode-only headroom tables, both passing 0 in Drive mode so the Drive
  voicing and every drive-knee delta are unchanged: `ampCleanKneeBonus`
  (extra waveshaper clip-knee headroom on both clip stages, `Clip.hs`) and
  `ampCleanPowerBonus` (extra power / resonance-mix / master `softClipK`
  headroom, `Tone.hs`). Graded to the user's "preserve model character" choice:
  Twin near hi-fi clean, AC30 keeps some class-A early breakup, the high-gain
  Rockerverb/JCM800/TriAmp clean channels are usable-clean but break up when
  pushed. New clean THD at 0.20 FS: Twin 6 / AC30 22 / Rockerverb 22 /
  JCM800 25 / TriAmp 14; at 0.10 FS all <=2% except AC30 0%.
- **Boundaries.** No IR convolution, no `block_design.tcl`, no GPIO byte /
  address change, no topEntity port change, no AXI topology change, no new
  multiplier (knees are compare+shift), and no remote git operation.
  Clash/VHDL/IP/bit/hwh regenerated because DSP behaviour changed.
- **Verification (offline).** `measure.py --check` 28/28 (tone curves are
  measured at a linear level below the clip knees, so the bonus is inert there
  -- intended), `dist_eval.py --check` 7/7 pedals + 6/6 clean amps (clean THD
  at 0.12 FS now JC-120 0 / Twin 0 / AC30 4 / Rockerverb 8 / JCM800 2 /
  TriAmp 0), `dynamics_eval.py --check` 5/5, `knobcheck.py --all` no
  barely-audible flags. **Golden regression `DSP_SIM_TESTS=1 pytest
  tests/test_dsp_sim_regression.py` 20 passed with NO re-bless** -- the
  Drive-mode amp goldens (AC30/Rockerverb/JCM800/TriAmp are drive_mode 1) and
  the clean JC-120/Twin goldens are byte-for-byte unchanged at their test
  levels, which independently confirms Drive mode is byte-identical and bypass
  stays bit-exact. `git diff --check` clean.
- **Build / deploy.** Safe Clash regen via `make -C hw/ip/clash regen`
  (rm -rf vhdl/LowPassFir avoids the mtime trap; new constants present in
  VHDL), full clean Vivado rebuild (`make clean && make`). Timing fully MET:
  WNS `+0.597 ns`, TNS `0.000`, WHS `+0.007 ns`, THS `0.000`, WPWS `+2.845`,
  route errors `0`; all user-specified constraints met. D109 CDC pair
  `clk_fpga_0 -> clk +6.139 ns` / `clk -> clk_fpga_0 +5.966 ns` (comfortable,
  low safe-bypass knife-edge risk -- but still ear-bench per the rule).
  bit/hwh md5 `9ffa7ff3cb79bc0624bca9d6323b710a` /
  `2cd059a7ede5ce42227788995ee88601`. `scripts/deploy_to_pynq.sh` completed;
  all board bit sites md5-match local.
- **Smoke / status.** `test_pmod_i2s2.py --mode dsp` loaded the new bit;
  Pmod I2S2 mode 2 ran 3 s with `FRAME_COUNT +288365` (~96 kHz), STATUS
  `sdout_alive=1`/`bclk_seen=1`/`lrclk_seen=1`, ADC samples observed (smoke
  input clipped full-scale as in prior baselines -- a smoke-input level
  artifact, not a DSP issue). ADC HPF confirmed `True`, `R19_ADC_CONTROL ==
  0x23` via a `download=False` attach. Pmod returned to `MODE=3` mute.
  **Bench acceptance is pending.** Branch `feature/amp-clean-headroom`; do not
  merge to `main` or update `baselines.json`/`BASELINES.md` until the user
  confirms the ear-bench. Rollback to D135 with
  `git checkout 765323b -- hw/Pynq-Z2/bitstreams/` + deploy.

## D135 — Large non-IR realism (Fuzz Face mid-hump + amp/cab character); bench-ACCEPTED, merged (`533d5869`, merge `765323b`, current accepted baseline)

- **Decision.** User explicitly authorized a branch and all large real-amp /
  effect / cabinet changes except IR convolution. Bench ear-test PASSED; the
  user approved merging D135 to `main`. D135 is now the **current accepted /
  committed baseline** (merge commit `765323b`), superseding D134 (`f62f132`).
- **DSP changes.** Fuzz Face now has a broad 900 Hz mid-hump biquad in the
  Distortion pipeline, tighter asymmetric clip knees, and a more open tone LPF.
  AC30/JCM800 `ampScoop` voicings are stronger, Amp `MIDDLE` range is more
  audible, AC30/JCM800 get model-local presence boost, and AC30 gets slightly
  higher clean power headroom. Cab adds a non-IR body tap from the existing
  short-FIR accumulator so Open/British/Closed have more cabinet body without
  convolution. `tools/dsp_sim/targets.py` now expects the Fuzz Face mid peak;
  `golden_vectors.json` was re-blessed for intentional DSP changes.
- **Boundaries.** No IR convolution, no `block_design.tcl`, no GPIO byte /
  address change, no topEntity port change, no AXI topology change, and no
  remote git operation. Clash/VHDL/IP/bit/hwh were regenerated because DSP
  behaviour changed.
- **Verification.** Offline suite passed before build: `measure.py --check`
  28/28, `dist_eval.py --check` 7/7 pedals + 6/6 clean amps,
  `dynamics_eval.py --check` 5/5, and `knobcheck.py --all` had no
  barely-audible flags. Regression/tool tests passed:
  `DSP_SIM_TESTS=1 pytest tests/test_dsp_sim_regression.py` 20 passed,
  `pytest tests/test_dsp_sim_tools.py tests/test_overlay_controls.py` 136
  passed, plus `compileall` and `git diff --check`.
- **Build / deploy.** `make -C hw/ip` and full Vivado build passed. Final
  routed timing fully MET: WNS `+0.643 ns`, TNS `0.000`, WHS `+0.018 ns`,
  THS `0.000`, route errors `0`; bus-skew constraints met with minimum slack
  `+8.099 ns`. bit/hwh md5
  `533d586901dc3669285a49c6d82bab9f` /
  `731517487c6218f0e181c2b74485d7a6`.
  `scripts/deploy_to_pynq.sh` completed; board copies under
  `/home/xilinx/Audio-Lab-PYNQ/`, package `audio_lab_pynq/bitstreams/`, and
  `/home/xilinx/pynq/overlays/audio_lab/` md5-match local.
- **Smoke / status.** `AudioLabOverlay()` loaded the new bit, ADC HPF stayed
  `True`, `R19_ADC_CONTROL == 0x23`, and required IPs were present. The
  footswitch IP appears in HWH as `fsw_in_0/s_axi` at `0x43d50000`.
  Pmod I2S2 mode 2 smoke ran for 3 s with `FRAME_COUNT +288374` (~96 kHz),
  `CLIP_COUNT 0`, and ADC samples observed; Pmod was then returned to
  `MODE=3` mute. **Bench acceptance: PASSED — merged to `main` as `765323b`**
  (`--no-ff` merge of `feature/realism-large-non-ir`); `baselines.json`/
  `BASELINES.md` updated (D135 `accepted-current`, D134 `accepted-superseded`).
  Rollback to D134 with `git checkout f62f132 -- hw/Pynq-Z2/bitstreams/`
  + deploy.

## D134 — Sim-scale all-effect objective evaluation + knob-visibility fixes; bench-ACCEPTED, merged (`58b6ee84`, then-current accepted baseline)

- **Decision.** User asked to scale the simulation further, evaluate every
  effect with it, and fix every item that should be fixed. Treat this as an
  offline-objective filter plus a deployed candidate, not as an accepted
  sound baseline until the user's bench check passes.
- **Sim expansion.** `tools/dsp_sim/dynamics_eval.py --check` now evaluates
  Compressor, Noise Suppressor, Wah, Reverb, and representative chain safety.
  Shared metrics moved into `tools/dsp_sim/metrics.py`; `run_sim.py` handles
  short rendered inputs; `measure.py --config rat` now uses the dedicated RAT
  stage; `signals.py` adds a Noise Suppressor decay-floor stimulus; and
  `knobcheck.py --all` uses effect-appropriate windows/thresholds so dynamics
  controls are judged after the relevant envelope has time to move.
- **Survey result.** The scaled sweep found no remaining `<== barely audible>`
  knobs after fixing the only flagged areas: Amp `PRESENCE` / `RESONANCE`,
  Cab `AIR`, and Noise Suppressor `DECAY` / `DAMP`.
- **DSP fixes.** All fixes stay inside existing stages and existing control
  bytes. Amp presence/resonance shelf sum is louder by one shift in
  `Amp/Tone.hs`. Cab AIR uses low/mid/high coefficient buckets plus an
  AIR-dependent HF-residual term in `Cab.hs`; the default AIR=50 bucket keeps
  the D133 tone targets. Noise Suppressor closes deeper and DECAY spans wider
  by changing closed gain and close-step shifts in `NoiseSuppressor.hs`. No
  GPIO, address, `block_design.tcl`, XDC, topEntity port, effect order, or new
  pipeline stage changed.
- **Verification.** `measure.py --check` 28/28 PASS; `dist_eval.py --check`
  7/7 pedals + 6/6 clean amps PASS; `dynamics_eval.py --check` 5/5 PASS;
  `knobcheck.py --all` has no barely-audible flags; `pytest
  tests/test_dsp_sim_tools.py tests/test_overlay_controls.py` 136 passed;
  `DSP_SIM_TESTS=1 pytest tests/test_dsp_sim_regression.py` 20 passed after
  re-blessing the six intentional Amp vectors. `compileall` and
  `git diff --check` passed.
- **Build / deploy.** Clash/IP and full Vivado rebuild passed. Timing fully
  MET: WNS `+0.939 ns`, TNS `0.000`, WHS `+0.014 ns`, THS `0.000`, route
  errors `0`; D109 CDC pair `clk_fpga_0 -> clk +2.347 ns` /
  `clk -> clk_fpga_0 +6.527 ns`; bus-skew min slack `+8.384 ns`. bit/hwh md5
  `58b6ee84a2f0c360da97c86e5a971c85` /
  `c41a29b65de2b0debb6de8509468021a`. `scripts/deploy_to_pynq.sh` completed;
  all five PYNQ bit/hwh sites md5-match local.
- **Acceptance status.** Programmatic smoke loaded the new PL, confirmed
  required IPs, Pmod mode-2 frame cadence near 96 kHz, ADC HPF `True`, and
  `R19_ADC_CONTROL == 0x23`. The smoke input was full-scale/clipping
  (`PEAK_ABS_LEFT/RIGHT=8388607`, rising `CLIP_COUNT`), so that smoke was not
  itself clean audio acceptance; the board was left in Pmod `MODE=3` mute for
  safety. User then bench-ACCEPTED D134 ("合格"). Merged to main with
  `--no-ff` merge `f62f132`. D134 supersedes D133 (`21c0b5a`, bit
  `54f7f547...`); rollback to D133 with `git checkout 21c0b5a -- hw/Pynq-Z2/bitstreams/`
  + redeploy.

## D133 — Metal full saturation + clean-amp power headroom; bench-ACCEPTED, merged (`54f7f547`, then-current accepted baseline)

- **Decision.** Take on the two items D132 deferred as "new-stage". Both were
  achievable as placement-safe constant/mux (no new multiply/stage).
- **Clean power headroom ("クリーン用パワーヘッドルーム").** The power / resonance /
  master `softClipK` stages compressed at a shared ~3.3-3.4M knee, so even the
  CLEAN amps broke up at a hot input. New per-model `ampPowerKnee base idx`
  (Models.hs): JC-120 6.8M (SS, huge headroom; waveshape clean-knee already
  7.5M), Twin 4.6M, high-gain models keep `base` (byte-identical -- their power
  amp SHOULD compress). Offline JC-120 clean THD @0.20 FS 24.7% -> 4.6%.
- **Metal full saturation ("完全飽和").** os4x hard-clip floor 1.05M -> 600k
  (+ steeper slope) = the 4x-oversampled (anti-aliased) clip flattens nearly the
  whole waveform at every level (drive curve 18-21% THD from -36 to -6 dBFS);
  post-LPF base 15 -> 38 lets the 3rd/5th harmonic through (fizz -19.5 dB,
  sustain 1.99x, mid-boost @800 preserved). The 1 kHz-THD ceiling ~21% is the
  non-fizzy post-LPF cap; "完全飽和" = max density + max audible-without-fizz.
- **Verification.** measure --check 28/28, dist_eval 7/7 + 6/6 amps-clean;
  goldens re-blessed (dist_metal; bypass + amps bit-identical at golden levels).
  Timing MET (WNS `+0.639`, CDC pair `+1.415`/`+6.782`). bit/hwh
  `54f7f547d04f0e4d59011e4754f834ca` / `2fbc8a5ba528bb6e1d415e6339b64bdb`.
  Deployed; PL-smoke needed a cold power-cycle first (repeated `download=True`
  hazard) then PASSED 96.1 kHz. **Bench-ACCEPTED ("合格"); merged (`21c0b5a`).
  Supersedes D132/b3dcab00.** Rollback: `git checkout 55ef823 -- hw/Pynq-Z2/bitstreams/`.
- **Remaining new-stage (still open):** real-IR cab, Fuzz mid-hump, JCM800/Vox
  presence shelf.

## D132 — All-effects sim survey + comprehensive detectors + bass/HF/Metal/RESONANCE amp re-voicing; bench-ACCEPTED, merged (`b3dcab00`)

- **Decision.** User: effects still far from real hardware -> strengthen the
  offline sim, survey ALL effects, fix the gaps; then (ear-bench) fix こもり/
  高域不足 + クリーンでも歪む; then make the sim DETECT such issues + a 3-cycle
  sim->compare-to-target->fix loop.
- **Sim strengthened (`tools/dsp_sim`, no bitstream):** rig (amp->cab) chain
  measurement, HF-slope metric, amp/cab + all-model targets, distortion
  clip-character `dist_eval --check`, a MUFFLED/HARSH detector (amp-alone
  `hf=("range",lo,hi)`), a CLEAN-mode-distortion detector (per-amp clean-THD).
  The crest clip-type check was found CONFOUNDED by the post-LPF (Gibbs ring) ->
  demoted to informational (DS-1/TS were false positives, validated by the
  harmonic series -> NOT changed).
- **Amp re-voicing (placement-safe constants/shifts):** amp input HP was a DEAD
  first-difference again (the D101 live pole was lost in the D99 rollback) -- the
  低音不足 root; made LIVE shift-only ~150 Hz (rig low_vs_mid -22 -> -7..-9 dB).
  Metal drive doubled + clip floor (saturation). RESONANCE dead-knob (LPF corner
  ~30 -> ~120 Hz + mix). HF-restore for the こもり the bass fix caused (treble
  floor 110 + baseAlpha 102 + HF droop 6 -- un-muffle AND keep TREBLE/PRESENCE
  knob range). AC30 darken 6 (chime).
- **Verification.** 3-cycle convergence: 28/28 EQ + 7/7 distortion + 6/6
  amps-clean + reverb RT60 monotonic vs targets. Timing MET (WNS `+0.597`, CDC
  pair `+2.121`). bit/hwh `b3dcab00...` / `3db2d16f...`. **Bench-ACCEPTED ("合格");
  merged (`55ef823`).** KEY LIMIT: NO board-audio capture, so "vs real hardware"
  = vs the circuit-analysis `targets.py`; bypass bit-exact is the only board
  anchor. The ear-bench "clean distorts" was largely the full-scale board input
  (at 0.12 FS the amps measure clean) -- addressed by D133's headroom.
- See `REALISM_ALL_EFFECTS_SIM_SURVEY.md`.

## D131 — DIST realism low-end + saturation/sustain, plus distortion-eval tooling; bench-ACCEPTED, merged

- **Decision.** Improve the user-reported weak/similarity-poor Distortion
  pedals (DS-1 / Big Muff / Fuzz Face / Metal) using new offline metrics that
  capture axes the earlier single-sine THD/net-curve checks missed. This pass
  is constant/coeff-only inside the existing Distortion stages; no GPIO,
  topology, Tcl, XDC, block-design, topEntity port, or new pipeline stage was
  added.
- **Tooling.** `tools/dsp_sim/dist_eval.py` adds distortion-character metrics:
  input-level DRIVE/gain sweep (THD% + crest = saturation depth / cleanup),
  SUSTAIN hold-time ratio, and two-tone GRIT/IMD with >5 kHz fizz. `measure.py`
  gained `--absolute`, LOWvMID band balance, and a 40 Hz floor. `targets.py` +
  `measure.py --check` make the per-model real-hardware target checks
  repeatable; the D131 target suite passes 13/13.
- **Voicing changes.** Low-end: Metal and DS-1 highpasses had cut too much
  bass, so Metal's effective corner is lowered from the ~650 Hz region toward
  ~120 Hz and DS-1's 100 Hz body is restored; Big Muff's scoop center moves
  700 -> 1000 Hz. Saturation/sustain: the old sustain metric was wrong
  (decay-slope fit read ~1.00x on held-square-like clips), so it was replaced
  by hold time; Big Muff clip knees are lowered from 2.4M/1.85M to
  1.5M/1.25M and related Fuzz/Metal thresholds are tightened. Result:
  Big Muff sustain ~2.04x, Metal ~2.03x, Fuzz ~1.80x. Metal post-LPF alpha
  moves 8 -> 13 to keep the saturation edge after the darker MT-2 EQ pass.
- **Verification.** Built timing-clean: WNS `+0.631 ns`, WHS `+0.019 ns`,
  route errors `0`, D109 CDC pair `clk_fpga_0`<->`clk`
  `+3.353` / `+6.286`. bit/hwh md5
  `fdab62d5ef229ec64dc60fe9395cbf06` /
  `d852ec4e737460ad016b41f0a3f71de2`. Deployed, board md5 matched, PL smoke OK
  at ~96.1 kHz, goldens re-blessed (`distortion_ds1`, `dist_metal`).
- **Status.** Bench-ACCEPTED ("合格") and merged to main (`37114b9`,
  "Merge D131 DIST realism + distortion-eval tooling"). **D131 became the
  canonical deployed baseline at that point** and was later superseded by D135.
  Rollback from D131: restore D130
  bitstreams from merge commit `fffa2b1` (bit `33af82f1`) and redeploy.
- **Lesson.** A single-sine THD/net-curve can miss perceived distortion
  quality: sustain, absolute low-end, and IMD/fizz need their own metrics. A
  metric that mis-measures is worse than no metric, so `dist_eval.py` and
  `measure.py --check` are now part of the voicing filter before Vivado.
  Remaining new-stage realism candidates: full 60 dB+ gain staging, a Fuzz Face
  mid-hump biquad, and a JCM800/Vox presence shelf.

## D130 — Amp 2nd-pass EQ re-collation (JC-120 flat, AC30 sparkle, JCM800 top); bench-ACCEPTED, merged

- **Decision.** Re-collate the six Amp models against specific amp EQ curves
  after the D129 lesson that perceived similarity is dominated by model-specific
  EQ. Changes stay within existing tables (`ampScoop*`, `ampModelDarken`,
  `ampTrebleGain`); no new stage, GPIO, topology, Tcl, XDC, or topEntity change.
- **Changes.** JC-120's residual D122 `-2 dB @ 400 Hz` scoop is removed
  entirely: a real Roland Jazz Chorus is solid-state and full-range, so the
  `ampScoop` row is unity. AC30 top sparkle is restored by lowering
  `ampModelDarken` 17 -> 11 and treble trim 2 -> 1; chime remains centered near
  2.2 kHz. JCM800 stays fundamentally mid-forward via the existing 650 Hz
  tone-stack row; only a modest `ampModelDarken` 20 -> 16 extends the D127
  bright-cap. A separate 2-3 kHz presence shelf is deferred to a future
  new-stage phase.
- **Verification / caveat.** Timing-clean: WNS `+0.576 ns`, WHS `+0.008 ns`,
  route errors `0`. D109 CDC slack was tight (`clk_fpga_0`->`clk` `+1.251`),
  even tighter than the D128 aggressive build that hissed, but board bench
  confirmed safe-bypass was clean. The CDC slack number is an important warning
  signal, not a strict accept/reject proxy; ear-bench remains mandatory.
  bit/hwh md5 `33af82f131cfff260871599e5142ef59` /
  `52982140729b93e4416437078ea95785`.
- **Status.** Bench-ACCEPTED ("合格") and merged to main (`fffa2b1`), superseding
  D129. Rollback to D129 via `git checkout 837a482 --
  hw/Pynq-Z2/bitstreams/` (bit `4c3f13ee`) + redeploy.

## D129 — OD/DS/RAT EQ re-collation against specific pedals; bench-ACCEPTED, merged

- **Decision.** Re-check every OD / Distortion / RAT model against the specific
  real pedal, not a broad category label. This was triggered when the user
  correctly caught Metal sounding unlike a Boss MT-2. All changes reuse
  existing biquad/LPF muxes and constants; no new stage or topology change.
- **Changes.** Metal is flipped from the wrong deep scoop/bright top toward
  MT-2-like mid boost and dark top: shared scoop mux becomes a +5 dB @ 800 Hz
  mid boost for Metal, and post-LPF darkens (base 21 -> 8). Klon gains its
  signature ~1 kHz mid bump (+4 dB @ 1000 Hz in the OD mux). OD-1 mid focus
  rises +2.5 -> +4 dB @ 800 Hz. BD-2's baked-in 2.3 kHz lift is reduced
  +3.5 -> +1.5 dB so noon is closer to flat. JanRay gains +1.8 dB @ 350 Hz
  low-mid warmth. DS-1 scoop moves from -6 dB @ 1000 Hz to -8 dB @ 500 Hz with
  a softer input HPF. Fuzz Face tone LPF is darkened slightly; a full mid-hump
  remains deferred.
- **Verification.** Offline checks confirmed target curves (for example Metal
  +7.7 dB around 800 Hz with a dark top, Klon +3.2 dB around 800-1200 Hz);
  bypass bit-exact. Timing-clean: WNS `+0.623 ns`, WHS `+0.012 ns`,
  island `+2.304 ns`, D109 CDC pair `+5.990` / `+6.167`, route errors `0`.
  bit/hwh md5 `4c3f13ee72634151be276e2310490ed4` /
  `5b33645006f47a75a869df4d6b43d2db`.
- **Status.** Bench-ACCEPTED and merged to main (`837a482`), superseding D128.
  Rollback to D128 via `git checkout 4a8fb90 -- hw/Pynq-Z2/bitstreams/`
  (bit `956d6f00`) + redeploy.
- **Lesson.** Harmonic series / clipping type is necessary but not sufficient.
  For perceived "same pedal" identity, the model's EQ curve has to match the
  specific hardware.

## D128 — Amp PRESENCE effectiveness + Drive/Clean separation; aggressive first build rejected, moderate build accepted

- **Decision.** Improve Amp realism after offline vs real-hardware comparison
  and `knobcheck.py` flagged PRESENCE as barely audible. The accepted build is
  a moderate constant-only change in `Amp/Models.hs` and `Amp/Tone.hs`; no new
  stage, GPIO, topology, multiplier, Tcl, XDC, or topEntity change.
- **Accepted changes.** PRESENCE band contribution moves from `>>9` to `>>8`
  so the knob is audible and JCM800/AC30 regain 2-3 kHz sheen. JCM800 presence
  trim changes `>>4` -> `>>5`. Drive mode gets clearer separation by raising
  only the small `Unsigned 9` per-model `ampSecondStageDriveBonus`, so
  Rockerverb/TriAmp distort and JC-120/Twin remain clean/headroom-focused.
- **Rejected attempt.** A first aggressive build also changed larger knee-delta
  and darken tables and raised the second stage harder. It was timing-clean in
  headline numbers but bench-REJECTED for safe-bypass hiss. The D109 CDC pair
  had fallen to `+1.327 ns`, the tightest placement seen in the project, so the
  safe-bypass knife-edge reappeared under that marginal routing. The accepted
  retune reverted the large-field table changes and kept only the smaller
  second-stage bonus increase.
- **Verification.** Accepted build timing-clean: WNS `+0.908 ns`, WHS
  `+0.014 ns`, island `+2.290 ns`, D109 CDC pair `+4.038` / healthy reverse,
  route errors `0`; bypass bit-exact offline. bit/hwh md5
  `956d6f0049a350e354e0cf864f1f6745` /
  `7db188ef79480568a547d084ef4fba17`. Board PL smoke OK at ~96.0 kHz; goldens
  re-blessed for the four affected amp configs.
- **Status.** Bench-ACCEPTED ("合格") and merged to main (`4a8fb90`),
  superseding D126+D127. Rollback to D126+D127 via `git checkout d723df1 --
  hw/Pynq-Z2/bitstreams/` (bit `7f3ac394`) + redeploy.
- **Lesson.** Even constant changes can perturb the critical CDC placement if
  the touched table/logic footprint is too broad. Keep voicing rebuilds small,
  check the D109 CDC pair, and still use ear-bench as the final gate.

## D126 + D127 — Reference-alignment pass (OD-1/DS-1/RAT pedals + JCM800 amp); bench-ACCEPTED, merged

- **Decision.** Execute `REALISM_REFERENCE_ALIGNMENT_FINDINGS.md`: the user-supplied
  pedal/amp references (BD-2 pedalpcb + GPV, TS cushychicken, SD-1/DS-1 GPV,
  ChowCentaur, RAT cushychicken, Fender Bassman DAFx-16, Marshall JTM45/DDSP
  arxiv) were fetched, reduced to concrete circuit numbers, compared to the
  current Clash constants, and turned into measurement-backed candidates. User
  authorized "全部一気に" (all pedals) + "ampも" (amp too). All changes are
  coeff/mux/constant-only on EXISTING stages -- NO new pipeline stage, GPIO,
  topology, Tcl, XDC, block-design, or topEntity port.
- **D126 pedals (`1a93984`).** (1) **OD-1 (OD model 1)**: user chose OD-1 (not
  SD-1). OD-1's asymmetric clip (even harmonics) was ALREADY correct, so only a
  gentle mid focus was added -- `odMidFeedforwardCoeffs/odMidFeedbackCoeffs`
  model-1 row = +2.5 dB @ 850 Hz (was flat; far milder than TS9's +6 dB so OD-1
  stays distinct). Asym knees unchanged. (2) **DS-1 mid scoop**: the real DS-1
  has a ~3 dB 500 Hz-2 kHz scoop our DS-1 lacked (measured as a rising tilt).
  Widened the EXISTING Big Muff/Metal scoop biquad gate
  (`bigMuffScoopFeedforward/RecursiveFrame`) to include `ds1On` + a coeff mux:
  DS-1 = -6 dB @ 1000 Hz Q0.7 (the Big Muff/Metal -10 dB @ 700 Hz coeffs are
  byte-identical, so those models are unchanged). DS-1 runs upstream so its output
  reaches the stage as monoSample -- NO new biquad (the D121 metal-scoop pattern).
  -6 dB (not -3) because the DS-1's bright rising tilt buries a -3 dB notch; net
  dip ~-2.4 dB @ 1 kHz. (3) **RAT slew darkening**: `ratPostLowpassFrame` alpha is
  now drive-dependent (`106 - drive>>2`) so high GAIN rolls off the top, modeling
  the LM308 slew-rate limit (the real RAT is not a full-band square at high gain).
  8 kHz net -6.4/-11.6/-22.3 dB at drive 10/55/100; drive 0 byte-identical to D124.
  **BD-2 left untouched** (measured on-target; no over-tuning).
- **D127 amp (`06910c3`, kept a SEPARATE commit so it is revertable alone).**
  JCM800 (idx 4) Marshall bright-cap nudge: `ampModelDarken` 25->20 for a touch
  more top end (the JTM45/Marshall bright channel has a treble-boost bright cap
  our model lacked). One model, one constant; Drive-mode darken still controls
  high-gain fizz. sim JCM800 9 kHz net +9.8 dB (still darker than JC-120 = not
  fizzy), other amps unchanged. Cumulative on D126 (the board needs pedals + amp
  together since only one bit loads at a time).
- **Verification.** Each candidate sim-A/B'd in `tools/dsp_sim` before building;
  bypass bit-exact; Big Muff scoop confirmed byte-identical (coeff mux). Clash
  regen PASS (mtime trap avoided); Vivado PASS; route errors 0; timing fully MET
  (WNS +1.057 -- the coeff/mux changes cost ~nothing; island clk_fpga_1 +3.142;
  D109 CDC pair clk_fpga_0<->clk +2.017/+6.476). bit/hwh md5
  `7f3ac39491d05f0ed17971d8a79ea10d` / `418f8088847b45acef60a55919b8dae1`.
  Deployed; 2 board sites md5-matched; PL-smoke OK.
- **Status.** Bench-ACCEPTED ("全部合格"); merged to main (`--no-ff`,
  "Merge D126+D127"). **bit `7f3ac394` is the new canonical deployed baseline,
  superseding D125.** Branch `feature/od1-ds1scoop-rat-realism`. Rollback to D125
  via `git checkout 4b2236e -- hw/Pynq-Z2/bitstreams/` + redeploy; the amp alone
  is revertable via `git revert 06910c3`. Realism work order remaining: step 10
  Reverb (ear pass), step 11 preset loudness, step 13 final integrated bench.

## D125 — Compressor Dyna/Ross sustain (RATIO now effective); bench-ACCEPTED, merged

- **Decision.** Realism work order steps 7-11 survey (`REALISM_DYNAMICS_REVERB_MEASUREMENT.md`)
  on the D124 baseline: Wah on-target (POSITION sweep 466->2164 Hz, Q~3, smooth
  exponential taper), NS on-target (closes a decaying tail 1.48->0.84 s, no
  chatter), Reverb not measurable with the current offline harness (single
  impulse too weak, long-decay runs time out -> ear-domain), loudness deferred
  to last. The one offline-measurable issue was the Compressor: the RATIO knob
  was nearly inert (ratio 10..90 -> gain reduction only -0.1..-0.6 dB) and the
  compression was shallow (max ~2.6 dB) -- work order step 8's "RATIO の変化が
  分かりやすいか" failed. User chose a Dyna/Ross sustain identity.
- **Root cause.** `compTargetNext` computed
  `excessShifted = (excess>>12)+(excess>>14)` (~0.0003x), so the envelope excess
  mapped into a tiny `excessU12`; `reduction = excessU12*ratio/256` was therefore
  both small and barely ratio-sensitive.
- **Change.** `excessShifted = (excess>>10)+(excess>>11)` (~4.8x more sensitive).
  This is the static compression curve (envelope->reduction), NOT a time
  constant, so it is fs-independent. Only `Compressor.hs` changed; no GPIO/
  topology/stage/multiplier/Tcl/XDC/block-design/topEntity-port change.
- **Verification.** Offline A/B (th40/ra70): GR now -2.3/-8.3/-10.0 dB at
  -17/-11/-6 dBFS (was -0.5/-1.2/-2.6); threshold ~-23 dBFS preserved. RATIO
  sweep at -17 dBFS: -0.3..-3.1 dB (was -0.1..-0.6), wider at louder levels.
  Light presets stay light (ratio 25 -> -0.8 dB). bypass bit-exact. Clash regen
  PASS (mtime trap avoided); Vivado PASS; route errors 0; timing fully MET
  (WNS +0.698, TNS 0, WHS +0.009, THS 0; island clk_fpga_1 +2.851; D109 CDC pair
  clk_fpga_0<->clk +1.491/+6.466). bit/hwh md5
  `3382ed563e56777cb98afd260c8aea09` / `d73e51f33658efcf6a1d3327a892bf29`.
  Deployed; 2 board sites md5-matched; PL-smoke OK.
- **Status.** Bench-ACCEPTED; merged to main (`--no-ff`, "Merge D125").
  **D125 (`31f7b57`, bit `3382ed56`) is the new canonical deployed baseline,
  superseding D124.** Branch `feature/compressor-dyna-ross`. Rollback to D124 via
  `git checkout dbca714 -- hw/Pynq-Z2/bitstreams/` (bit `3367d0e3`) + redeploy.
  Remaining realism work: Reverb (ear pass), preset loudness (last), Amp
  reassessment (only if still limiting), final integrated board bench.

## D124 — RAT live-pole highpass fix (RAT now distorts); bench-ACCEPTED, merged

- **Decision.** Realism work order steps 5 (Overdrive) + 6 (Distortion/Fuzz).
  Measured all 6 OD + 7 Dist models offline (`tools/dsp_sim` harmonic_profile +
  net curve, `REALISM_OD_DIST_MEASUREMENT.md`). Everything measured on-target
  EXCEPT RAT, which produced THD 0.0% at every drive (55..127) -- it never
  distorted at all. OD: TS9/BD-2(D121)/OCD(D121) on-target, JanRay + Klon are
  intentionally low-gain/transparent (JanRay distorts 4.6/9.8/11.7% at drive
  70/90/max -- a working low-gain OD, NOT a bug), so per work order policy no
  on-target model was over-tuned.
- **Root cause.** `ratHighpassFrame` called `onePoleHighpass 511 9`; Haskell
  precedence makes `prevOut * coef \`shiftR\` shift` parse as
  `prevOut * (511 >> 9) = prevOut * 0`, so the feedback pole is dead and the
  stage is a first difference (x - prevIn). That attenuates 1 kHz ~24 dB
  (|H| = 2 sin(pi f / fs) ~ 0.065), so the signal reaching the drive + hard clip
  was tiny and never clipped. The dead-pole from memory
  `project_amp_rat_hp_dead_pole`.
- **Change.** Inline a LIVE one-pole highpass in `ratHighpassFrame` ONLY:
  `satWide (x - prevIn + (prevOut*507) >> 9)`, coef 507/512 = 0.9902 ~ 150 Hz.
  The shared `FixedPoint.onePoleHighpass` and its other intentionally-dead-pole
  callers (the amp HP, which the D101/D107 history shows must stay as-is) are
  untouched. Only `Rat.hs` changed; no GPIO/topology/stage/multiplier/Tcl/XDC/
  block-design/topEntity-port change.
- **Verification.** Offline A/B: RAT now THD 17/24/26% at drive 30/55/85,
  odd/even +77 (op-amp + diode hard clip), net peak moved 4138->720 Hz
  (mid-forward = target), FILTER works as a treble rolloff (tilt -5.3/-10.0/-39.3
  at FILTER 0/50/100), brightness preserved at FILTER 0, rms -28.4->-12.2 (in
  line with other dist pedals). bypass bit-exact. Clash regen PASS (mtime trap
  avoided, coef 507 in VHDL); full Vivado build PASS; route errors 0; timing
  fully MET (WNS +0.619, TNS 0, WHS +0.008, THS 0; island clk_fpga_1 +2.449;
  D109 CDC pair clk_fpga_0<->clk +5.683/+6.359). bit/hwh md5
  `3367d0e3f86fdb5d8b5d501be1c71995` / `3b24f3f2fa4e8aa2ffc1530e80c4484d`.
  Deployed to PYNQ-Z2 `192.168.1.9`; 2 board sites md5-matched; PL-smoke OK.
- **Status.** Bench-ACCEPTED; merged to main (`--no-ff`, "Merge D124").
  **D124 (`526f1e8`, bit `3367d0e3`) is the new canonical deployed baseline,
  superseding D123.** Branch `feature/rat-highpass-fix`. Rollback to D123 via
  `git checkout 62d0610 -- hw/Pynq-Z2/bitstreams/` (bit `7efd41ef`) + redeploy.
  NOTE (user): overall effect completeness still considered low -- realism steps
  7-11 (Wah/Comp/NS/Reverb/loudness) are next, and further voicing revisions are
  expected.

## D123 — Cab per-model presence biquad (model separation); bench-ACCEPTED, merged

- **Decision.** Realism work order (`REALISM_IMPROVEMENT_WORK_ORDER.md`) step 4
  (Cab), phase 3. Steps 1-3 first built the measurement scaffold with NO DSP
  change: reference presets (`REALISM_REFERENCE_PRESETS.md`), canonical inputs
  (`REALISM_MEASUREMENT_INPUTS.md` + `tools/dsp_sim/signals.py`), target metrics
  (`REALISM_TARGET_METRICS.md` + `tools/dsp_sim/harmonics.py`), and a `measure.py`
  `cab0/1/2` config so each cab model measures individually. The step-4
  measurement (`REALISM_CAB_MEASUREMENT.md`) found all three cabs peaked at the
  SAME 2806 Hz: the cone-breakup presence biquad
  (`cabPresenceFeedforwardFrame`/`cabPresenceRecursiveFrame`, added D121) used ONE
  shared coeff set for every model, so Open/British/Closed had no presence
  separation -- the work order's #1 Cab gap.
- **Change.** Make the presence biquad per-model (coeff-only mux in the EXISTING
  ff/rec frames, same D82/D83 split, exactly like the D122 ampScoop mux). RBJ
  peaking, 96 kHz, Q14: open 1x12 3400 Hz Q0.8 +3.0 dB (brighter/airier),
  british 2x12 2800 Hz Q1.0 +3.5 dB (UNCHANGED, mid-forward identity), closed
  4x12 2300 Hz Q1.2 +4.0 dB (lower/thicker honk). New helpers
  `cabPresenceFFCoeff` / `cabPresenceFBCoeff` (model = `ctrlC>>6`); b1==a1 for RBJ
  peaking so na1 = -b1. No new GPIO/topology/stage/multiplier/Tcl/XDC/
  block-design/topEntity-port change. Loudness unity / >5 kHz rolloff / Closed
  fizz are deliberately out of scope (one-aspect Cab pass; step 11 / later pass).
- **Verification.** Offline A/B (`tools/dsp_sim`, `measure.py cab0/1/2`): Closed
  peak moved 2806->2310 Hz, Open presence gentler/higher (pres 2-4k +2.9->+2.3),
  British unchanged; side effect Closed rolloff -3.6->-4.2 / fizz -5.9->-6.1
  toward target; bypass bit-exact. Clash regen PASS (mtime trap avoided: vhdl +
  component.xml M, new coeffs 30865/28637/17087/16837/12274/14834 in VHDL); full
  Vivado build PASS; route errors 0; timing fully MET (WNS +0.595, TNS 0,
  WHS +0.017, THS 0, WPWS +2.845; island clk_fpga_1 +2.677; D109 CDC pair
  clk_fpga_0<->clk +5.610/+6.508). In the accepted baseline band (D112 +0.564 /
  D122 +0.614). bit/hwh md5 `7efd41ef6d0b7a88ecd8c54217ad9c23` /
  `06611bce8a69b5409ff91ba54c531b76`. Deployed to PYNQ-Z2 `192.168.1.9`; 3 board
  sites md5-matched; PL-smoke OK (new bit loaded, ADC HPF True, GPIOs present).
- **Status.** Bench-ACCEPTED ("合格"); merged to main (`--no-ff`, "Merge D123").
  **D123 (`62d0610`, bit `7efd41ef`) is the new canonical deployed baseline,
  superseding D122.** Branch `feature/cab-presence-separation`. Rollback to D122
  via `git checkout 7c59f30 -- hw/Pynq-Z2/bitstreams/` (bit `1a295b8b`) + redeploy.

## D122 — Amp per-model voicing (JC-120 flatter, Rockerverb thick low-mid, TriAmp scoop); bench-ACCEPTED, merged

- **Decision.** Extend the D121 measurement-driven voicing to the amp models --
  the user explicitly authorized touching the amp ("amp も含めて全部寄せて"),
  which is the new explicit direction the rollback note required. Measured all 6
  amp models offline; most already match their targets via the D83/D84 per-model
  ampScoop biquad (AC30 chime +4 @ 2200 Hz, JCM800 mid +4 @ 650 Hz, Twin Fender
  scoop -5 @ 400 Hz). Three were off and were fixed via the EXISTING ampScoop
  biquad mux (coeff-only, NO new stage): (1) JC-120 (idx 0) shared Twin's
  -5 dB @ 400 Hz Fender scoop, but a real Roland Jazz Chorus is solid-state and
  FLAT -> softened to -2 dB @ 400 Hz, now distinct from Twin; (2) Rockerverb
  (idx 3) was flat -> +3 dB @ 300 Hz low-mid ("thick low-mid", on top of its
  darkest darken); (3) TriAmp (idx 5) was flat -> -6 dB @ 750 Hz modern scoop.
  Twin/AC30/JCM800 unchanged (already on target). The differentiator input-HP
  brightness and the power-sag are UNTOUCHED (both load-bearing / previously
  rejected to change).
- **Measurement finding.** The amp's cascaded always-on soft-clips partially
  re-fill EQ *scoops* (cuts survive worse than boosts through compression):
  JC-120-flatter and the Rockerverb boost measure clearly; the TriAmp scoop is
  subtle at the output (~-2 dB after compression) even at -6 dB pre-clip. Kept
  -6 dB; bench-confirmed audible.
- **Boundaries.** Clash/VHDL coeff-only change in `Amp/Tone.hs` + regenerated
  IP/bit/hwh. No new pipeline stage, no GPIO/Tcl/XDC/block-design/topEntity-port
  /effect-order/Python-API change.
- **Build / deploy / smoke.** `make -C hw/ip/clash regen` + full Vivado build,
  timing fully MET (WNS `+0.614 ns`, TNS `0`, WHS `+0.016 ns`, THS `0`,
  WPWS `+2.845`); island clk_fpga_1 `+2.633 ns`; route errors `0`. bit/hwh md5
  `1a295b8be4c19f3d39b0e46268b6e801` / `eb1f70122c23f0632f2a0f7007b4610f`.
  Deployed 3 board sites (md5-matched), PL-smoke OK (overlay loads, ADC HPF
  `True`). bypass bit-exact (golden 13/13 incl. new amp_rockerverb/amp_triamp +
  re-blessed amp_jc120; amp_jcm800 + all non-amp byte-identical = surgical).
- **Status.** Bench ACCEPTED ("合格"). Merged to main (`--no-ff`); bit
  `1a295b8b` is the new canonical deployed baseline, superseding D121. Branch
  `feature/amp-voicing`. Rollback: D121 via `git checkout d07c8e9 --
  hw/Pynq-Z2/bitstreams/` (bit `9a57c50a`), or D99 via `ea6bf94`, + redeploy.

## D121 — Off-target effect voicing (OD BD-2/OCD, Metal scoop, Cab presence); D99 amp untouched; bench provisionally accepted

- **Decision.** First voicing pass on the rolled-back D99 baseline that targets
  the NON-amp effects measured off vs their real-hardware references (via the new
  offline `tools/dsp_sim/measure.py` net-tone-curve harness), leaving the D99 amp
  byte-for-byte untouched (`Amp.hs` not edited). Four changes: (1) OD BD-2
  pre-clip biquad moved 1500->2300 Hz (+3 -> +3.5 dB) = brighter; (2) OD OCD given
  a NEW pre-clip biquad peak +4 dB @ 1300 Hz (was flat) = upper-mid honk;
  (3) Metal mid-scoop added by WIDENING the existing ~700 Hz bigMuff scoop-notch
  biquad's gate to `bigMuffOn || metalDistortionOn` -- metal runs upstream of that
  stage so its output already reaches it, NO new biquad; (4) Cab cone-breakup
  presence peak = a NEW peaking biquad +3.5 dB @ 2800 Hz on the speaker-FIR output
  (the 15-tap FIR is too short to resolve a 2.8 kHz peak at 96 kHz). RAT left
  alone (bright = correct RAT character; it was the borderline item).
- **Method (new, de-risks voicing).** Every change was designed + verified
  OFFLINE first with the DSP sim + `measure.py` (net tone curve vs bypass) BEFORE
  building -- targets hit: BD-2 peak->2310 Hz, OCD +3.7 @ 1290, Metal dip
  593-720 Hz, Cab +3.2 @ 2806. Golden regression 11/11 incl. the new
  od_bd2/od_ocd/dist_metal/cab vectors; bypass stays bit-exact (the knife-edge
  invariant survives the new cab pipeline stages). The RBJ designer reproduced
  every existing coeff exactly first, so the new coeffs are trustworthy.
- **Boundaries.** Clash/VHDL DSP behaviour change + 2 new cab biquad Pipeline
  stages + regenerated IP/bit/hwh. `Amp.hs` UNTOUCHED. No GPIO/Tcl/XDC/
  block-design/topEntity-port/effect-order/Python-API change.
- **Build / deploy / smoke.** `make -C hw/ip/clash regen` + full Vivado build
  passed, timing fully MET (WNS `+0.726 ns`, TNS `0`, WHS `+0.012 ns`, THS `0`,
  WPWS `+2.845`); island clk_fpga_1 `+3.309 ns` (the new cab biquad cost almost
  nothing); route errors `0`. bit/hwh md5
  `9a57c50ae405bce717648dc1585eaf4b` / `112be061b98ed16d5ff55eaa87fc3b85`.
  Deployed 3 board sites (all md5-matched), PL-smoke OK (overlay loads the new
  bit, ADC HPF `True`).
- **Status.** Bench ACCEPTED (the user confirmed "全部一旦おｋ", then asked to
  merge). **Merged to main (`--no-ff`); D121 (`9a57c50a`) is the new canonical
  deployed baseline, superseding D99.** Branch `feature/voicing-offtargets`.
  Rollback if a later issue surfaces: `git checkout ea6bf94 --
  hw/Pynq-Z2/bitstreams/` (D99 `83a64ffc`) + redeploy.

## D120 — Remove Amp dynamic power-sag + static master trim; bench-REJECTED -> deployed baseline ROLLED BACK to D99

- **Decision (attempt).** Follow-up to the rejected D119. Instead of D119's raw
  MASTER level (which ran louder/harsher and was rejected), `ampMasterFrame`
  removes the dynamic `ampSagEnv` modulation (no time-varying pumping) but
  subtracts a STATIC per-model level trim so the average loudness stays near
  D118: tube models `level >> 3` (~12.5 %), AC30 `>>3 + >>4` (~18.75 %), JC-120
  exempt (byte-identical). Literal shifts (constant-folded like the old D118 sag
  shifts). The user had picked this direction ("サグ全廃＋音量維持").
- **Boundaries.** Clash/VHDL DSP behaviour change only (Amp.hs `ampMasterFrame`
  + regenerated IP/bit/hwh). No GPIO/Tcl/XDC/block-design/topEntity/effect-order
  /Python-API change. The unused `ampSagEnv` register is DCE'd by Clash.
- **Build / deploy / smoke.** `make -C hw/ip/clash regen` + full Vivado build
  passed, timing fully MET (WNS `+0.712 ns`, TNS `0`, WHS `+0.005 ns`, THS `0`),
  route errors `0`; bit/hwh md5 `bd45ee197664260381d9fab64c32ade7` /
  `6b9ca6d3496d58c88314729a90037217`. Deployed 6-site to `192.168.1.9` (all
  md5 matched), PL-smoked (mode-2 dsp, `VERSION=0x00480001`, frame ~96.1 kHz,
  ADC alive).
- **Acceptance.** Bench-REJECTED ("ダメそう").
- **Rollback to D99.** The user asked to roll back "結構前" and chose **D99**.
  The whole post-D112 amp-retune line (D113/D117/D118 retunes, D119 sag-disable,
  D120 static-sag-trim) is abandoned. Restored bit/hwh + full Clash src + vhdl
  from commit `9651572` (D99, bit `83a64ffc6415fe2a3bc2aed47b6b19f9`, behaviour
  == D98 96 kHz amp -- none of the D110-D120 revoicing), deployed 6-site (all
  md5 `83a64ffc`), PL-smoked (~96.1 kHz, engine alive). **Deployed baseline is
  now D99 (`83a64ffc`).** Correct D99 hwh is `de9d0e48c564da870efd978a6d54e4e7`
  (the D99 entry / CURRENT_STATE mis-record it as `8f7bb979...`, which is D98's
  hwh copy-pasted; D99 == D98 block design so the AXI address map is identical
  and either hwh loads the bit correctly).
- **Lesson.** The amp "volume pumping" the user dislikes is the `ampSagEnv`
  power-sag (added D86/D94, active on tube models, JC-120 exempt). Both removing
  it (D119) and removing-the-dynamics-but-static-trimming it (D120) were
  bench-rejected. Do NOT re-attempt a sag change without a new explicit
  direction from the user. D120 source is kept uncommitted on branch
  `feature/amp-static-sag-d120`.
