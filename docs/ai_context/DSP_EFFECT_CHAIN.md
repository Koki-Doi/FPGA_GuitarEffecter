# DSP effect chain

The PL DSP pipeline is written in Clash/Haskell under
`hw/ip/clash/src/LowPassFir.hs` and `hw/ip/clash/src/AudioLab/`. The
`LowPassFir.hs` file name is historical -- it has long since stopped
being just an FIR -- and now intentionally stays as the thin
Vivado-visible top module. The split `AudioLab.*` modules hold the
types, fixed-point helpers, control-word helpers, AXIS helpers, effect
stage functions, and `fxPipeline`. Together these modules are the
**only** source of truth for DSP behaviour on the live PYNQ-Z2 build.

The May 8 behavior-preserving split changed module boundaries only:
no coefficients, arithmetic widths, pipeline order, enable behavior,
`Frame` shape, `topEntity` port, GPIO, Python API, Notebook UI, or
Chain Preset changed. The rebuilt bitstream matched the previous
deployed timing baseline (WNS = -8.022 ns, WHS = +0.052 ns) and was
deployed to PYNQ-Z2 at `192.168.1.9`; smoke testing confirmed the
existing chain presets and control API still work.

The May 9 internal mono DSP pass keeps the external AXI/I2S contract as
48-bit stereo but treats ADC Left as the only guitar source inside the
DSP chain. Right input is explicitly discarded to avoid unconnected-
channel noise, the active effect path runs on mono sample/state helpers,
and the final mono result is duplicated back to output Left/Right.
`topEntity`, `block_design.tcl`, GPIOs, Python API, Notebooks, and Chain
Presets remain unchanged. AXI TLAST is carried in `Frame.fLast` from
input to output; `fxPipeline` paces back-to-back DMA input so the fixed-
latency DSP core still produces exactly one output frame for each
accepted input frame even if S2MM ready drops briefly.

The earlier C++ DSP prototypes that lived under `src/effects/` were
removed (`DECISIONS.md` D13). They were not on the live PL path and
their continued presence risked steering future work into "implement
in C++ then port" loops, which this project does not do.

The live build also carries a "real-pedal voicing pass" and a later
recording-analysis-driven voicing pass of the existing stages
(`DECISIONS.md` D16 / D17); see
[`REAL_PEDAL_VOICING_TARGETS.md`](REAL_PEDAL_VOICING_TARGETS.md) for
the per-stage target style, current implementation, gap, plan, risk,
and listening points, and
[`AUDIO_RECORDING_ANALYSIS.md`](AUDIO_RECORDING_ANALYSIS.md) for the
measurement findings. These passes change constants and clip-helper
choice inside the existing register stages; they do not change the
pipeline shape, the GPIO inventory, or the `topEntity` ports.

The latest accepted baseline is **D75 (2026-05-31), the DSP clock-domain
island**: `clash_lowpass_fir_0` now runs at `FCLK_CLK1 = 50 MHz` while the
rest of the fabric stays at `FCLK_CLK0 = 100 MHz`, bridged by
`axis_clock_converter` (`cc_dsp_in` / `cc_dsp_out`) added in
`hw/Pynq-Z2/island_integration.tcl`. This closed the DSP timing (WNS
-10.387 -> -0.706 ns) without touching the I2S/Pmod CDCs. It also removed
the `paceCount` (AXIS pacing) from `fxPipeline`, added a `syncCtrl`
control-word CDC synchroniser in `LowPassFir.hs` (2-FF + stability on all
12 control words -- required so effect/knob switches do not click), and a
`set_clock_groups -asynchronous` in `audio_lab.xdc`. **The DSP voicing
(Clash effect math) is unchanged from D73** -- D75 is a pure clocking/CDC
change. Full record in `DSP_ISLAND_CLOCK_DESIGN.md` / `DECISIONS.md` D75.
Do not lower the whole fabric to 50 MHz (global-50 MHz corrupts the
I2S/Pmod CDCs = bypass buzz).

The previous DSP-voicing baseline is D68 (2026-05-25), the global
Amp / Distortion / Overdrive constants retune, with D71 (2026-05-27)
cabinet multi-band pseudo-IR and D73 (Cry Baby Wah) on top -- all carried
unchanged into D75. The fixed-scalar constant-table approach is
load-bearing: D58 / D59 / D60 / D61 v2 showed that adding DSP48
multipliers or new feedback state can perturb Vivado P&R enough to make
the safe-bypass path audibly noisy even when CLIP_COUNT and WNS look
acceptable.

## Core types

Core definitions now live in `AudioLab.Types`; the numeric helper
functions in the next section live in `AudioLab.FixedPoint`; byte /
flag helpers live in `AudioLab.Control`; AXIS pack/unpack and packet
helpers live in `AudioLab.Axis`; the stage functions live under
`AudioLab.Effects.*`; `fxPipeline` lives in `AudioLab.Pipeline`.

```haskell
type Sample = Signed 24    -- Audio samples, two's complement
type Wide   = Signed 48    -- Wide accumulator for products and sums
type Ctrl   = BitVector 32 -- One AXI GPIO word
```

A `Frame` is the data record threaded down the pipeline. The physical
record still carries left/right-shaped fields for compatibility with the
split modules and generated IP, but the active guitar path is mono:
`AudioLab.Axis.makeInput` copies ADC Left into the mono helpers/dry
fields and discards ADC Right, and effect stages read/write via helpers
such as `monoSample`, `setMonoSample`, `monoDry`, `monoWet`, and the
mono EQ accumulator accessors. At output, `AudioLab.Axis.pipeData`
duplicates that mono sample to both channels with `packChan mono mono`.
`Frame.fLast` carries AXI TLAST independently of sample data. `Maybe
Frame` is the pipeline type; `Nothing` means a slot is idle.

## Numeric primitives

| Helper | Purpose |
| --- | --- |
| `mulU8 :: Sample -> Unsigned 8 -> Wide` | 24×8 signed-by-unsigned multiply, returns `Wide`. |
| `mulU9`, `mulU12` | 24×9 and 24×12 variants for headroom-sensitive products. |
| `mulS10` | 24×10 signed×signed, used by cab IR coefficients. |
| `satWide` | Saturating clamp from `Wide` back into `Sample`. |
| `satShift7/8/9/10/12` | `>> N` followed by `satWide`; how a stage returns to the 24-bit lane after a multiply. |
| `softClip` | Symmetric soft clip with a fixed knee at `4_194_304`. |
| `softClipK knee x` | Symmetric soft clip with a tunable knee. |
| `asymSoftClip kneeP kneeN x` | Different knees and slopes for + and − half. |
| `asymHardClip kneeP kneeN x` | Hard clamp with independent thresholds. |
| `hardClip x threshold` | Symmetric hard clip. |
| `onePoleU8 alpha prev x` | `alpha/256 · x + (256-alpha)/256 · prev`; one-pole IIR. |

The discipline is: **multiply** in `Wide`, **shift+sat** back into
`Sample`, then do further sample-domain work. Never feed an unsaturated
`Wide` into the next multiplication chain.

## Pipeline order

(Each arrow is at least one register.)

```
makeInput
  -- ADC Left becomes the mono source; ADC Right is discarded
  -> nsLevel -> nsApply                                 (noise suppressor envelope + apply, replaces the legacy hard gate)
  -> compLevel -> compApply -> compMakeup               (stereo-linked feed-forward peak compressor; bit-exact bypass when off)
  -> wah (posSmooth + fByteR + qBandR feed SVF low/band; band -> volume) -- D72 resonant band-pass; pre-distortion position; bit-exact bypass when off
  -> overdrive (drive mul -> boost -> clip -> tone -> level)
  -> legacy distortion (drive mul -> boost -> clip -> tone -> level)
  -> RAT (HPF -> drive -> opamp LPF -> hard clip -> post LPF -> tone -> level -> mix)
  -> clean_boost          (3 stages: mul -> shift -> level + softClip safety)
  -> tube_screamer        (5 stages: HPF -> mul -> asym soft clip -> post LPF -> level)
  -> metal_distortion     (5 stages: tight HPF -> mul -> hard clip -> post LPF -> level)
  -> amp simulator (HPF -> drive -> waveshape -> pre-LPF -> 2nd stage -> tone stack -> power -> resonance/presence -> master)
  -> cab IR (4-tap cabinet FIR + level/mix)
  -> EQ (3-band)
  -> reverb (BRAM tap + tone + feedback + mix)
  -> output AXIS register                               (mono duplicated to output L/R; TLAST propagated)
```

For DMA traffic, `fxPipeline` does not infer packet length or TLAST from
sample values. It accepts an input frame only when the output side and a
small clock-domain pace counter permit it, then produces one output frame
with the same `fLast` bit. This avoids dropping TLAST during short S2MM
backpressure on long back-to-back DMA packets.

## Noise Suppressor section

Replaces the legacy hard noise gate. Driven by the dedicated
`axi_gpio_noise_suppressor` GPIO carried in `fNs` (THRESHOLD / DECAY /
DAMP / mode bytes); enable still rides on `flag0(fGate)` (the existing
`noise_gate_on` bit) so `set_guitar_effects(noise_gate_on=...)` keeps
working. Bit-exact bypass when the flag is clear. RNNoise / FFT /
spectral methods were intentionally **not** adopted -- too heavy for
this PL budget.

Same shape as the legacy gate: one envelope-input register stage, two
feedback registers (envelope + smoothed gain), one apply register
stage. Wiring lives in `fxPipeline` as `nsLevelPipe -> nsEnv -> nsGain
-> nsPipe -> odDriveMulPipe`.

| Stage | What it does |
| --- | --- |
| `nsLevelPipe` (reuses `gateLevelFrame`) | `fWetL = max(\|L\|, \|R\|)` -- one register stage feeding the envelope follower. |
| `nsEnv` (`nsEnvNext` register feedback) | Peak follower. Attack-instantaneous; release ~ `env >> 8 + 1` per sample. Reset to 0 when the noise-suppressor enable is clear. |
| `nsGain` (`nsGainNext` register feedback) | Smoothed gain. Open is fast (`nsAttackStep = 512`, ~8 samples to unity). Close ramps toward `nsTargetGain` at `nsCloseStep` per sample, where `nsCloseStep = max(1, (255 - decay_byte) >> 2)`. Target is `gateUnity` when `env >= threshold`, otherwise `nsClosedGain damp = ((255 - damp_byte)^2) >> 5`. |
| `nsPipe` (`nsApplyFrame`) | Multiply each channel by the smoothed gain (`mulU12 x gain`) and saturate (`satShift12`). Bit-exact bypass when `flag0(fGate)` is clear. |

### Parameter mappings

| Knob | Python | byte (ctrl byte of fNs) | DSP effect |
| --- | --- | --- | --- |
| THRESHOLD | 0..100 | `ctrlA = round(threshold * 255 / 1000)` (so 100 -> 26) | scaled to `Sample` via `nsThresholdSample = asSigned9 ctrlA << 13`, identical scaling to the legacy gate threshold. |
| DECAY | 0..100 | `ctrlB = round(decay * 255 / 100)` | full-close range from ~1.4 ms (decay=0) to ~85 ms (decay=100). Linear ramp; integer step per sample. |
| DAMP | 0..100 | `ctrlC = round(damp * 255 / 100)` | closed gain ranges from ~50 % (damp=0) to 0 % (damp=100). Quadratic curve via `((255 - byte)^2) >> 5`. |
| mode | 0..255 raw | `ctrlD` | reserved; 0 today. Future use: NS-2 vs NS-1X mode, attack / hold knobs. |

The legacy noise-gate frame helpers (`gateLevelFrame`, `gateEnvNext`,
`gateOpenNext`, `gateGainNext`, `gateFrame`) are **kept as Haskell
source** so older bitstreams keep building, but no register in the
active pipeline references them; the synthesiser drops them.
`gate_control.ctrlB` is therefore unused in the new bitstream -- we
still mirror the threshold byte to it from Python for backward
compatibility with overlays that lack the new GPIO.

## Compressor section

Stereo-linked feed-forward peak compressor on its own
`axi_gpio_compressor` GPIO carried in `fComp` (THRESHOLD / RATIO /
RESPONSE bytes plus a packed enable+MAKEUP byte). Sits between the
noise suppressor and the overdrive: tightens picking and evens out
level before the gain stages. Enable lives on `fComp ctrlD` bit 7
(not on `gate_control.ctrlA` -- the flag byte was already full).
Bit-exact bypass when the enable bit is clear. RNNoise / FFT /
spectral / lookahead methods were intentionally **not** adopted --
too heavy for this PL budget.

Same shape as the noise suppressor (one envelope-input register
stage reusing `gateLevelFrame`, two feedback registers for
envelope + smoothed gain, one apply register stage, plus a separate
makeup multiply stage so each register holds a single multiply).
Wiring lives in `fxPipeline` as
`compLevelPipe -> compEnv -> compGain -> compApplyPipe -> compMakeupPipe`.

| Stage | What it does |
| --- | --- |
| `compLevelPipe` (reuses `gateLevelFrame`) | `fWetL = max(\|L\|, \|R\|)` -- one register stage feeding the envelope follower (stereo-linked sidechain). |
| `compEnv` (`compEnvNext` register feedback) | Peak follower. Attack-instantaneous; release ~ `env >> 8 + 1` per sample plus a response-controlled extra step (`max(1, ((255 - response_byte) >> 4) + ((255 - response_byte) >> 6))`). Reset to 0 when the compressor enable is clear. |
| `compGain` (`compGainNext` register feedback) | Smoothed gain. Both attack and release use a response-controlled step (`max(1, ((255 - response_byte) >> 3) + ((255 - response_byte) >> 5))`). Target is `gateUnity` when `env <= softThreshold`, otherwise `gateUnity - reduction`, where the audio-analysis pass uses `threshold = (byte << 13) * 7/8`, `softThreshold = threshold - threshold/8`, and `reduction = clamp(0, gateUnity, (((excess >> 12) + (excess >> 14)) * ratio_byte) >> 8)`. |
| `compApplyPipe` (`compApplyFrame`) | Multiply each channel by the smoothed gain (`mulU12 x gain`) and saturate (`satShift12`). Bit-exact bypass when the compressor is off. |
| `compMakeupPipe` (`compMakeupFrame`) | Q8 makeup multiply (`factor = 192 + makeup_u7` in `[192, 319]`, applied via `mulU9 + satShift8`). Bit-exact bypass when the compressor is off. |

### Parameter mappings

| Knob | Python | byte (ctrl byte of fComp) | DSP effect |
| --- | --- | --- | --- |
| THRESHOLD | 0..100 | `ctrlA = round(threshold * 255 / 100)` | scaled to `Sample` via `compThresholdSample = (asSigned9 ctrlA << 13) - ((asSigned9 ctrlA << 13) >> 3)`, so compression begins a little earlier on guitar-level material. |
| RATIO | 0..100 | `ctrlB = round(ratio * 255 / 100)` | linear gain-reduction factor: 0 = ~no compression, 255 = strong limiting. Reduction scales with both excess (`env - threshold`) and ratio_byte. |
| RESPONSE | 0..100 | `ctrlC = round(response * 255 / 100)` | shared attack/release smoothing time. 0 -> fastest; 255 -> slowest (~128 samples to converge). |
| MAKEUP | 0..100 | `ctrlD bits[6:0] = round(makeup * 127 / 100)` (clamped to 0..127) | Q8 makeup factor `192 + makeup_u7` (range 192..319, ~0.75x..1.25x). Conservative on purpose -- a Compressor preset cannot blow the rest of the chain into clipping. |
| enable | bool | `ctrlD bit 7` | section enable. Bit-exact bypass when clear. |

### Why a new GPIO

The compressor wanted five distinct knobs (threshold / ratio /
response / makeup / enable). `gate_control.ctrlA` (the master flag
byte) was already full, every existing `reserved` byte is held for
a different planned feature, and the compressor benefits from being
able to flip its own enable without read-modify-write on a shared
flag byte. So a new `axi_gpio_compressor` IP was added at
`0x43CD0000` and a new `compressor_control` port was added to the
Clash top entity. See `DECISIONS.md` D14.

## Wah section (D72; D73 Cry Baby retune)

Resonant band-pass wah on its own `axi_gpio_wah` GPIO at
`0x43D30000`, carried in `fWah` (POSITION / Q / VOLUME bytes + a
packed enable+BIAS byte). Sits between the Compressor and the
Overdrive (the classic pre-distortion wah position). Enable lives on
`fWah ctrlD` bit 7 (not on `gate_control.ctrlA` -- same convention as
the Compressor). **Value-preserving bypass with added pipeline
latency** when the flag is clear: `wahApplyFrame` returns the input
frame unchanged sample-for-sample, but the surrounding register
stages (`wahPosSmooth`, `wahFByteR`, `wahQBandR`, `wahLow`, `wahBand`,
`wahApplyPipe`) still cost a few extra pipeline cycles vs the pre-D72
baseline, so sample-by-sample diffs against the same wall-clock buffer
will NOT be bit-identical even with the wah disabled -- they are
identical after a latency-aligned re-index. Lives in
`hw/ip/clash/src/AudioLab/Effects/Wah.hs`.

Topology is a Chamberlin parallel-update state-variable filter:

```
high(n) = in - low(n-1) - qBand(n-1)
band(n) = band(n-1) + fByte * high(n)
low(n)  = low(n-1)  + fByte * band(n-1)
wahOut  = band(n)                                  (BPF output)
final   = applyVolume(wahOut, volume_byte)
```

The wiring lives in `fxPipeline` as `wahPosSmooth + wahFByteR +
wahQBandR -> wahLow + wahBand -> wahApplyPipe -> odDriveMulPipe`.

| Stage | What it does |
| --- | --- |
| `wahPosSmooth` (`wahPosSmoothNext` register feedback) | Pedal-position zipper smoother. `posSmooth' = posSmooth + ((target - posSmooth) >> 4)` per audio frame, with a 1-step nudge so single-byte targets still converge. ~0.3 ms per byte at 48 kHz. Snaps to target on off-cycles so re-enable is clean. |
| `wahFByteR` (`wahFByteRNext` register feedback) | Pre-registered `positionToFByte(posSmooth, biasByte)` so the band / low updates never see two multiplies in series. One DSP for the `base * biasSigned` product inside the helper. |
| `wahQBandR` (`wahQBandRNext` register feedback) | Pre-registered `satShift8(mulU8 oldBand qCoefByte)` so the high computation in the band update is mul-free. One DSP. |
| `wahLow` (`wahLowNext` register feedback) | SVF low state. Updates as `low + (oldBand * fByteR) >> 8`, saturating. One DSP. |
| `wahBand` (`wahBandNext` register feedback) | SVF band state and the BPF output. Computes `high = input - oldLow - qBandR` (no multiply, three adders), then `band + (high * fByteR) >> 8`, saturating. One DSP. |
| `wahApplyPipe` (`wahApplyFrame`) | Output stage. Applies a Q8 volume factor (`wahVolumeFactor` in `[64, 256]`) to `band` and saturates. Bit-exact bypass when `wahEnabled` is clear. |

### Parameter mappings

| Knob | Python | byte (ctrl byte of fWah) | DSP effect |
| --- | --- | --- | --- |
| POSITION | D73 split: 0..100 percent via `position=` (GUI / encoder path) OR raw 0..255 byte via `position_raw=` (FP02M future input path); the two arguments are mutually exclusive and `set_wah_settings` raises `ValueError` if both are supplied. | `ctrlA` = position byte | After `wahPosSmoothNext` smooths the byte, `basePositionToFByte` maps it through a 4-segment piecewise linear fit between the D73 Cry Baby anchors (`pos 0/64/128/192/255 -> ~450 / 700 / 1100 / 1600 / 2200 Hz` at `fs = 48 kHz`; f_byte anchors 15 / 24 / 37 / 53 / 73). All multiplications use `Unsigned 16` intermediates so the arithmetic does not wrap. |
| Q | 0..100 | `ctrlB = round(q * 255 / 100)` | `qCoefByte = 128 - (qByte >> 1)` with a floor of 16 so the BPF cannot run away. Higher UI Q -> lower damping coefficient -> sharper peak. |
| VOLUME | 0..100 | `ctrlC = round(volume * 255 / 100)` | D73 two-segment piecewise Q8 factor in `[128, ~510]`: byte 0 -> 128 (~0.5x, -6 dB taper), byte 128 (UI 50 %) -> 256 (1.0x unity), byte 255 (UI 100 %) -> 510 (~2.0x, +6 dB boost cap). Uses a `mulU10` saturating multiply (`Wide * Unsigned 11`) so even the +6 dB ceiling clips at `±Sample_max` rather than wrapping. |
| BIAS | 0..100 | `ctrlD[6:0] = round(bias * 127 / 100)` (u7 0..127, 64 = centred) | `biasSigned = bias_u7 - 64` (-64..+63). `positionToFByte` adds `(baseFByte * biasSigned) >> 6` to the base, then clamps to `[4, 200]`. Lower bias shifts the sweep down, higher bias shifts it up. |
| ENABLE | bool | `ctrlD[7]` | Section gate. Value-preserving bypass with added pipeline latency when clear (see top-of-section note for the latency caveat). |

`wah_source` (`AppState.wah_source`) is a Python-side bookkeeping field
(`"manual"` today, `"pedal"` once FP02M / Arduino A0 is wired). It
controls UI / runtime POSITION wiring; the GPIO byte layout is
unchanged in either mode.

### Why a new GPIO

The wah needed five distinct knobs (POSITION / Q / VOLUME / BIAS /
ENABLE). The two currently free bytes in the existing GPIO map
(`axi_gpio_eq.ctrlD`, `axi_gpio_noise_suppressor.ctrlD`) are reserved
for future EQ / NS features, so repurposing them would violate D12
("never repurpose a reserved byte for a different feature"); and
`gate_control.ctrlA` is full. So a new `axi_gpio_wah` IP was added at
`0x43D30000` and a new `wah_control` port was added to the Clash top
entity. The block design itself was not edited: a new
`hw/Pynq-Z2/wah_integration.tcl` is sourced from `create_project.tcl`
after `pmod_i2s2_integration.tcl`, mirroring the additive pattern used
by `hdmi_integration.tcl`, `encoder_integration.tcl`, and
`pmod_i2s2_integration.tcl`. See `DECISIONS.md` D72.

### Timing-friendly pipeline split

`positionToFByte` and the `q * oldBand` product live in their own
register stages (`wahFByteR`, `wahQBandR`). The first Vivado pass
inlined them inside the `wahBandNext` combinational block and the
worst path picked up three DSP48E1 multiplies in series, regressing
WNS from `-9.413 ns` (D71.2 baseline) to `-18.966 ns`. Splitting them
into separate registers brought the worst-stage combinational depth
back to one DSP + small adders. The 1-2 sample group delay this adds
is inaudible for a guitar wah.

## Overdrive section

Driven by the existing `axi_gpio_overdrive` GPIO. Enable remains
`gate_control.ctrlA` bit 1, and `ctrlA` / `ctrlB` / `ctrlC` remain
tone / level / drive. `ctrlD` is shared: the top five bits carry
Distortion `TIGHT`, and the bottom three bits carry `overdriveModel`
(`0..5` valid; `6/7` clamp/fallback on the Python side). This reuse is
safe because the Distortion consumers shift away the low model bits.

The six selectable models are implemented as constant lookup tables in
`AudioLab.Effects.Overdrive`, not as separate pipelines and not as a
wide 8-way mux of independent DSP blocks.

| Model idx | User label | Current coefficient intent |
| ---: | --- | --- |
| 0 | TS9 | mid-focused mild asym clip |
| 1 | OD-1 | simple early overdrive |
| 2 | BD-2 | D62 retune: `odDriveK=7`, knees `2_400_000 / 1_900_000`, safety `3_400_000` |
| 3 | Jan Ray | low-gain transparent style |
| 4 | OCD | wider drive ceiling |
| 5 | Centaur | polished low/mid gain |

The stage shape is unchanged from the previous selectable-OD build:

| Stage | Current shape |
| --- | --- |
| `overdriveDriveMultiplyFrame` | Q8 pre-gain is `256 + drive * odDriveK model`, selected by a small constant table. |
| `overdriveDriveBoostFrame` | Existing `satShift8` return to `Sample`. |
| `overdriveDriveClipFrame` | `asymSoftClip (odKneeP model) (odKneeN model)`. D62 only changes the BD-2 row. |
| `overdriveToneMultiplyFrame` -> `overdriveToneBlendFrame` | Existing one-pole tone blend; no GPIO topology change. |
| `overdriveLevelFrame` | Existing Q7 level multiply with per-model `odSafetyKnee`. |

## Legacy distortion section

Six register stages, gated by
`distortionLegacyOn = flag2(fGate) AND NOT anyDistPedalOn`:

1. `distortionDriveMultiplyFrame` — pre-gain `mulU12`, `gain = 256 + drive*8`.
2. `distortionDriveBoostFrame` — `satShift8` back to `Sample`.
3. `distortionDriveClipFrame` — `hardClip` with a drive-dependent threshold.
4. `distortionToneMultiplyFrame` — products with previous sample (1-pole tone blend).
5. `distortionToneBlendFrame` — sum + `satShift8`.
6. `distortionLevelFrame` — `mulU8` by level, `satShift7`.

The `NOT anyDistPedalOn` part is what lets the user-facing
`exclusive=True` semantics actually exclude the legacy stage when
a pedal-mask bit is set. The legacy stage is otherwise unchanged
and the original `distortion=` / `distortion_tone` / `distortion_level`
API still drives it as before.

## Pedal-mask distortion section

Independent register-staged blocks. Each is enabled only when both
`flag2(fGate)` AND its bit in `distortion_control.ctrlD` are set.
When off, every stage is bit-exact bypass.

| Pedal | Frame functions (in order) |
| --- | --- |
| `clean_boost` (bit 0) | `cleanBoostMulFrame` -> `cleanBoostShiftFrame` -> `cleanBoostLevelFrame` |
| `tube_screamer` (bit 1) | `tubeScreamerHpfFrame` -> `tubeScreamerMulFrame` -> `tubeScreamerClipFrame` -> `tubeScreamerPostLpfFrame` -> `tubeScreamerLevelFrame` |
| `rat` (bit 2) | (no new stage — handled by the existing RAT block; Python flips `gate_control` bit 4 to engage it) |
| `metal` (bit 6) | `metalHpfFrame` -> `metalMulFrame` -> `metalClipFrame` -> `metalPostLpfFrame` -> `metalLevelFrame` |
| `ds1` (bit 3) | `ds1HpfFrame` -> `ds1MulFrame` -> `ds1ClipFrame` -> `ds1ToneFrame` -> `ds1LevelFrame` (BOSS DS-1 style: HPF, drive, asym soft clip with low knees, post LPF, level+safety) |
| `big_muff` (bit 4) | `bigMuffPreFrame` -> `bigMuffClip1Frame` -> `bigMuffClip2Frame` -> `bigMuffToneFrame` -> `bigMuffLevelFrame` (Big Muff Pi style: pre-gain, two cascaded soft clips, tone LPF, level+safety) |
| `fuzz_face` (bit 5) | `fuzzFacePreFrame` -> `fuzzFaceClipFrame` -> `fuzzFaceToneFrame` -> `fuzzFaceLevelFrame` (Fuzz Face style: pre-gain, strong asym soft clip, tone LPF, level+safety) |

The pipeline order in `fxPipeline` is:
`cleanBoost* -> tubeScreamer* -> metal* -> ds1* -> bigMuff* -> fuzzFace*`,
with `distortionPedalsPipe = fuzzFaceLevelPipe`. Each pedal section
is independently enabled, so off-pedals never touch the sample.

Per-channel filter state for the HPFs and post-LPFs lives in
pipeline-level registers wired up in `fxPipeline` (e.g.
`tsHpfLpPrevL`, `metalPostLpPrevR`). Frame fields `fEqLowL/R` and
`fEqHighLpL/R` are used as transient carriers between adjacent
stages and are reset by the EQ block downstream, so reusing them
inside the pedal stages is safe.

## Existing RAT section (for reference)

Eight register stages with intermediate state held outside the frame:
`ratHighpass -> ratDriveMul -> ratDriveBoost -> ratOpAmpLowpass ->
ratClip -> ratPostLowpass -> ratTone -> ratLevel -> ratMix`. This is the
template for any new "pedal" we add: a small chain of single-purpose
register stages that each do one thing.

## Amp Simulator section

Driven by the existing `axi_gpio_amp` and `axi_gpio_amp_tone` GPIOs:
`input_gain` / `master` / `presence` / `resonance` on `axi_gpio_amp`,
and B/M/T plus a packed `ctrlD` byte on `axi_gpio_amp_tone`. Since
**D55** the `ctrlD` byte is no longer a continuous `character`
percent: it is a two-field bit-pack
`ctrlD[7] = ampDriveMode` (0 = Clean, 1 = Drive),
`ctrlD[6:3] = 0` reserved,
`ctrlD[2:0] = ampModelIdx` (3-bit, 0..5 valid; 6/7 reserved -> Clash
falls back to JC-120 for safety). The Python writer is
`AudioLabOverlay.amp_model_drive_byte(amp_model_idx, amp_drive_mode)
= ((mode & 1) << 7) | (idx & 0x07)` with
`AMP_MODEL_IDX_MASK = 0x07` and `AMP_MODEL_IDX_MAX = 5`. The legacy
`ampModelSel :: Unsigned 8 -> Unsigned 2` four-band quantiser is
retired; the six per-model voicing tables below take its place. Enable
remains `gate_control.ctrlA` bit 6. Amp / Cab / audio-analysis /
named-model / fizz-control / D55 six-pack / D58.2 Balanced Drive
passes changed constants and small per-model tables inside the
existing stages only -- no register stage, GPIO, or `topEntity` port
was added.

Per-model voicing tables (`docs/ai_context/AMP_MODEL_RESEARCH_D55.md`
section 6 carries the original per-model rationale; values here are
the current deployed D69+ Amp Drive Mode values, unchanged since D69):

| idx | model        | modelDarken | trebleTrim | presenceTrim | drivePosDelta | driveNegDelta | preLpfDriveDarken | secondStageDriveBonus |
| --- | ------------ | ----------- | ---------- | ------------ | ------------- | ------------- | ----------------- | --------------------- |
| 0   | JC-120       | 0           | 0          | 0            | `16_200`      | `13_500`      | 6                 | 22                    |
| 1   | Twin Reverb  | 3           | 2          | `byte >> 5`  | `85_800`      | `74_100`      | 8                 | 30                    |
| 2   | AC30         | 3           | 2          | `byte >> 6`  | `232_400`     | `199_200`     | 12                | 42                    |
| 3   | Rockerverb   | 18          | 9          | `byte >> 3`  | `374_400`     | `322_400`     | 20                | 62                    |
| 4   | JCM800       | 10          | 8          | `byte >> 4`  | `462_000`     | `407_000`     | 20                | 74                    |
| 5   | TriAmp Mk3   | 26          | 14         | `byte >> 3`  | `615_000`     | `541_200`     | 30                | 88                    |

`ampDrivePosDelta` / `ampDriveNegDelta` are per-model fixed scalars
(`Unsigned 3 -> Signed 25`, **not** runtime `ch * factor` -- the
abandoned D58 `ch * factor` form added four DSP48E1 slices and caused
a P&R shift that introduced an audible high-frequency saturation noise
on the ADC -> DAC bypass path). The D69 values are the requested
Drive-mode factors evaluated against each model's current
`ampCharForModel` value (`18 / 78 / 166 / 208 / 220 / 246`) so no new
multiplier is introduced.

| Stage | What it does |
| --- | --- |
| `ampHighpassFrame` | First-order HPF using the existing input/output state registers. Feedback coefficient is `253/256` (tightened from the prior `254/256` path). |
| `ampDriveMultiplyFrame` / `ampDriveBoostFrame` | Q7-style preamp gain. Ceiling is ~19x (tightened from ~21x in the audio-analysis pass) so Amp-only and post-pedal use do not create line-direct fizz before the cabinet stage. |
| `ampWaveshapeFrame` -> `ampAsymClip idx intensity drive x` | First-stage asymmetric soft clip. `intensity = ampCharForModel idx` (`18 / 78 / 166 / 208 / 220 / 246`) sets the per-model knee centre; the per-model `ampDrivePosDelta` / `ampDriveNegDelta` shrink the knees further only in Drive mode. The shift on the negative-side post-knee tightens from `>> 3` (Clean) to `>> 2` (Drive) -- the same D54 real-DSP-branch behaviour. |
| `ampPreLowpassFrame` | One-pole post-clip smoothing. `baseAlpha = 128 + (ampCharForModel idx >> 2)` (range `132..189` over the six voicings), biased down by `ampModelDarken idx` (per-model Clean baseline, `0..26`); in Drive mode `ampPreLpfDriveDarken idx` (`6..30`) stacks on top so the harder clip's extra harmonics are absorbed instead of leaking out as fizz. |
| `ampSecondStageMultiplyFrame` / `ampSecondStageFrame` | Second gain/clip stage. Gain = `112 + (ctrlA >> 3) + (ampCharForModel idx >> 2)` plus `ampSecondStageDriveBonus idx` (`22..88`) in Drive mode. The clip stage re-uses `ampAsymClip` with `intensity = ampCharForModel idx >> 1` (half-intensity, softer than the first stage) -- explicitly *not* full-intensity (the D57 anti-pattern). |
| `ampToneFilterFrame` -> `ampToneBandFrame` -> `ampToneProductsFrame` -> `ampToneMixFrame` | Three-band B/M/T tone-stack approximation. Treble uses `ampTrebleGain idx treble`, a per-model trim (`0 / 2 / 2 / 9 / 8 / 14` from `modelTrim` table) so treble at 100 keeps 2..4 kHz bite without restoring 8..16 kHz fizz. |
| `ampPowerFrame` | `softClipK 3_400_000` power-stage safety. |
| `ampResPresenceProductsFrame` / `ampResPresenceMixFrame` | Resonance remains internally capped (`resonance * 3/4`). Presence starts from `presence * 5/8` and subtracts a per-model `presenceTrim` (`0`, `byte >> 6`, `byte >> 5`, `byte >> 4`, `byte >> 4`, `byte >> 3`) before the mix, then runs through `softClipK 3_400_000`. |
| `ampMasterFrame` | Master multiply followed by `softClipK 3_300_000` so MASTER cannot slam the Cab/EQ/Reverb stages into hard clip. |

## Cab IR section

Driven by the existing `axi_gpio_cab` GPIO. `ctrlA = mix`,
`ctrlB = level`, `ctrlC = model`, `ctrlD = air`; those byte meanings
are unchanged. Enable remains `gate_control.ctrlA` bit 7. The live
stage is still the existing 4-tap FIR split over `cabProductsFrame`,
`cabIrFrame`, and `cabLevelMixFrame`; no long IR loader and no extra
AXI GPIO were added.

The D71 speaker-character pass extends D70 with a multi-band
pseudo-IR blend: presence / cone breakup via `softClipK` on the
early component, HF fizz suppression via `input - mainSat` residual
subtraction, per-model mid-body emphasis, wider speaker-compression
knee spread, and retuned FIR coefficients with stronger Nyquist
rejection. No new `mulS10` / `mulU8` / register / Pipeline.hs change;
one `softClipK` added (LUT-only, no DSP48).

| Model | Target | DSP shape |
| --- | --- | --- |
| 0 | 1x12 open back (Fender-like) | Strong direct (c0+c1 = 188, c2+c3 = 68), ratio 2.76:1. Sum 256, Nyquist -16 at air 0. Presence `softClipK(3.6M)` 25% mix. Fizz sub 12.5%. Body emphasis 0%. Speaker knee 5.6M. Body resonance `<<5`. |
| 1 | 2x12 combo (Vox-like) | Balanced (c0+c1 = 144, c2+c3 = 116), ratio 1.24:1. Sum 260, Nyquist -24 at air 0. Presence `softClipK(3.0M)` 12.5%. Fizz sub 25%. Body emphasis 6.25%. Speaker knee 4.0M. Body resonance `<<6`. |
| 2 | 4x12 closed back (Marshall/Mesa-like) | Heavy body (c0+c1 = 78, c2+c3 = 186), ratio 0.42:1. Sum 264, Nyquist -44 at air 0. Presence `softClipK(2.4M)` 12.5%. Fizz sub 50%. Body emphasis 12.5%. Speaker knee 2.8M. Body resonance `<<7`. |

`air` still selects three variants per model (0=off-axis / 1=balanced
/ 2=on-axis). `mix=0` remains dry/raw, `mix=100` fully cab-shaped.

Speaker target references: Celestion Vintage 30 70 Hz -- 5 kHz /
Fs 75 Hz; Eminence Man O War 80 Hz -- 5 kHz / Fs 91 Hz. Guitar
speakers roll off sharply above 5 kHz; the cab's FIR + fizz
subtraction approximates this without IR convolution or BRAM.

`cabProductsFrame` computes 4 `mulS10` products (unchanged count)
split into "early" (fAccL) and "body" (fAcc2L). Body resonance
routes through `satShift8` -> `softClipK(cabBodyResKnee)` ->
`resize << N` into fAcc3L. Presence routes through `satShift8` ->
`softClipK(cabPresenceKnee)` -> per-model shift into fEqLowL
(transient carrier, overwritten by EQ downstream).

`cabIrFrame` blends: mainSat (FIR sum of all 3 accumulators) +
presenceS (from fEqLowL) + bodyAdd (per-model extra body) - fizzSub
(per-model fraction of `input - mainSat` residual). The fizz
subtraction creates an effective transfer function
`H_eff(f) = H(f) + fraction * (H(f) - 1)` that deepens the FIR's
HF rejection without new multipliers (model 2 gets a near-null at
~12 kHz).

`cabLevelMixFrame` applies per-model `softClipK(cabSpeakerKnee)`
with wider spread (5.6M / 4.0M / 2.8M) for more differentiated
speaker compression.

## Adding a new effect

When adding a stage:

- Each new register stage should carry **one operation**: a multiply, a
  saturation/shift, an add, or a clip. Do not pile a multiply *and* a
  case-of-N *and* a clip inside one combinational block.
- Use the existing `Frame` accumulator fields (`fAccL/R`, `fAcc2L/R`,
  `fAcc3L/R`, `fEqLowL/R`, `fEqHighLpL/R`) for transient state — the
  distortion section can reuse them because EQ/amp stages overwrite
  them later.
- Per-channel filter state that must persist across samples lives in
  pipeline-level registers (see how `ratHpInPrevL` etc. are built up
  with `register 0 (frameOr ... <$> reg <*> pipe)`).
- When the enable bit is clear, the stage **must** preserve `fL` / `fR`
  bit-exactly. The pattern is `f { fL = if on then new else fL f }`.
- Wrap-around is forbidden. Every combinational path that produces a
  `Wide` value must end in `satWide`, `satShiftN`, or one of the
  `*Clip` functions before re-entering the `Sample` lane.

## Chain preset orchestration (Python only)

`audio_lab_pynq.effect_presets.CHAIN_PRESETS` defines named voicings
that combine every section into one state. They are applied through
`AudioLabOverlay.apply_chain_preset(name)` which orchestrates the
existing per-section setters (`set_compressor_settings`,
`set_noise_suppressor_settings`, `set_distortion_pedal` /
`set_distortion_settings`, `set_guitar_effects`). No new GPIO, no
new Clash stage -- the DSP pipeline is unchanged. See
[`DECISIONS.md`](DECISIONS.md) D15.

Per-preset safety contract (enforced by `tests/test_overlay_controls.py`):

- Compressor `makeup` stays in 45..60.
- Distortion `level` is capped at 35.
- `Safe Bypass` has every section `enabled=False` and `reverb.mix=0`.

## What to avoid

- A single function that contains a `case modelSelect of …` with eight
  arms each producing a different multiply, filter, or clip. The
  synthesiser has to build all eight in parallel and mux at the end —
  the combinational depth and the fanout both grow, and timing
  collapses. The previous attempt at a unified model selector regressed
  WNS by roughly 7 ns.
- Reusing the same accumulator field within a stage for different
  purposes. The synthesiser will tolerate it, but it makes future edits
  brittle.
- Long chains of unsaturated arithmetic. Always saturate before letting
  a value leave a register stage.
