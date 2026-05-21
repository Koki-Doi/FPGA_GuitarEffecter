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
  remaining "PCM5102 sounds worse than desired" report. The current
  output path is still the ADAU DAC serial bitstream mirrored to
  PCM5102 (`i2s_to_stream_0/so`), PCM5102 SCK is correctly tied low
  for internal-SYSCLK mode, and the deployed mux selects ADAU input.
  The first non-physical improvement to implement next is therefore:
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

- **Decision (plan only).** Add Digilent **Pmod I2S2** (CS4344 24-bit
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
  - PCM5102 line out and PCM1808 line in currently live on two
    separate breakout boards with hand-routed jumper wires on PMOD JB;
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
- **Pmod I2S2 ADC is NOT wired into the AudioLab DSP chain.** The
  user requested NOT to implement a "mode 2 = ADC → DSP → DAC"
  path in this branch. `i2s_to_stream_0` / `stream_to_i2s_0` and
  the AXIS DSP loop continue to be fed by ADAU1761 ADC only, as in
  Phase 7D close-out.
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
