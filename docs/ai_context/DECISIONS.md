# Design decisions (ADR-style)

Each entry is a decision that earlier work made and that future work
should not silently revisit. New decisions go at the bottom; old ones do
not get removed even when superseded — they get updated.

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

- **Decision.** The Amp Simulator section ships four named voicings —
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
  - The `amp_character` numeric API stays public; `set_amp_model` is
    a thin wrapper around `set_guitar_effects(amp_character=...)`.
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
  overlay. For the current 5-inch 800x480 HDMI LCD, the adopted default
  visible viewport is the top-left `x=0,y=0,w=800,h=480` region inside
  the fixed 1280x720 HDMI framebuffer.
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

- **Boundaries.** Native 800x480 HDMI timing remains a Phase 5B candidate,
  but it is not required for correct placement now. Any native-timing
  trial is a separate Vivado rebuild / timing-review / bit-hwh deploy
  decision. The old untracked `HDMI/` experiment tree was removed after
  confirming current deploy, tests, and runtime scripts use `GUI/` plus
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
  - throttle (`apply_interval_s`、既定 100 ms) で連続回転中の AXI flood を
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
