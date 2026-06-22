# Refactoring candidates

A living backlog of refactoring opportunities for Audio-Lab-PYNQ. Each entry is
behaviour-preserving (no intended audio/UX change) unless noted. Pick one per
branch, follow the verification protocol, merge `--no-ff`.

## Why this doc exists now

The DSP refactors B / C / E / F were implemented and merged at D102-D104, then
**reverted at D105** because they corrupted the safe-bypass (all_off) audio. At
the time that looked like an unfixable "P&R knife-edge" and the working rule
became *"do NOT rebuild the DSP for voicing or refactors -- only the D98 bit is
clean."*

**D109 found and bounded the real root cause** (an untimed DSP-output -> DAC
distributed-RAM CDC; `set_max_delay -datapath_only`, see `DECISIONS.md` D109).
D110-D135 demonstrated multiple clean rebuilds, but D136-D144 later proved the
crossing remains placement-sensitive even with timing MET. Refactors are not
forbidden, but any regenerated bit still needs the full safe-bypass ear-bench;
do not describe the crossing as placement-independent.

The B/C/E/F source still exists in git history and was proven VHDL-equivalent, so
re-applying is low-effort.

**2026-06-17 status:** **F, E, C, G, H, P4, I1 are DONE** and on `main`. The
byte-EQUIVALENT DSP refactors (F/E/C/G/H) were merged on the `tools/dsp_sim`
golden proof + the **F-pattern**: the source is refactored but the committed
`vhdl/bit` are LEFT at the accepted baseline (`54f7f547`) since they are
functionally identical -- so NO new bit is deployed and NO bench is needed for
the merge. The golden regression was extended to ALL 6 amp models + 7 dist
pedals first, so a per-model/per-pedal transcription error would be caught
(20/20 green throughout). The standing "never accept a DSP **bit** on an
equivalence proof alone" rule still holds for the NEXT build that regenerates the
bit from this source -- that build gets the usual timing/CDC check + ear-bench.
Remaining DSP: **B** (biquad kernels), **D/B2** (Pipeline combinators, deferred).
Remaining Python: **P3** (model-name table unification = a layering decision, not
a low-risk fold). **P1 / P2 done; their residuals are genuinely class-coupled.**

**2026-06-22: P1 tail + P2 DONE.** P1 = `apply_chain_preset` pure kwargs-builder
-> `overlay/chain_preset_apply.py` (orchestration residual is class-coupled).
P2 = renderer per-panel split + shared-cache holder (`_render_primitives.py` /
`_render_panels.py`; renderer 1048 -> 536 lines; 108-frame digest byte-identical).
**2026-06-22: J + K + M DONE.** M = HDMI mirror reporting group ->
`hdmi_state/summary.py` + `_amp_model_from_character` -> `hdmi_state/amps`
(mirror 1238 -> 1111 lines; full suite 360 passed; residual is class-coupled).
**2026-06-22: J + K DONE.** J = clip-family shift parametrization (`softClipShift`
+ 5 wrappers in `FixedPoint.hs`). K = split the 583-line `Distortion/Pedals.hs`
into 6 per-pedal modules + a 25-line re-export shim. Both golden 20/20
byte-identical, vhdl/bit LEFT at D155 (F-pattern, no bench for the merge). New
candidates L / M recorded.

**2026-06-22 current baseline:** D155 (`09c8a95`, bit `8d875cc8...`) = cab speaker
FIR 31->47 taps capping the D150-D155 voicing arc on top of D148 (JC/Twin
clean-headroom + D146 hard CDC pblock + D147 sag slew), superseding D153 (`b86c88a`). The D136-D142 line and D144 candidate were bench-rejected and rolled
back to D135 before the D146 pblock let the clean-headroom voicing land; future
DSP refactor builds must still treat the safe-bypass CDC as a live placement risk.

**(historical) 2026-06-13 status:** the DSP items were then blocked on a board
bench (PYNQ-Z2 offline, D119 rollback); superseded by the 2026-06-17 status.

## Verification protocol (every DSP refactor)

A behaviour-preserving Clash refactor still changes the bit md5 (renamed wires
alter synthesis input), so prove equivalence structurally **and** by ear:

1. Regenerate VHDL (`rm -rf hw/ip/clash/vhdl/LowPassFir` first to dodge the mtime
   trap, then `make CLASH_FLAGS="-isrc -package-id clash-prelude-1.8.1-043657e6...
   --vhdl"`; verify `git status` shows the VHDL changed).
2. Diff the regenerated VHDL ignoring `-- src/` comment lines: expect only renamed
   signals + harmless CSE/resize; `clash_lowpass_fir_types.vhdl` byte-identical;
   numeric-constant multiset + operation counts (`shift_right` / `*` / `+` / `-`)
   IDENTICAL.
3. Build, check timing MET (and that the D109 CDC exception is still
   "Max Delay Datapath Only" in `report_cdc`).
4. **Ear-bench (non-negotiable, the D105 lesson): all_off MUST be clean**, plus a
   few effects on. The CDC is bounded now, but always confirm by ear before
   accepting a bit -- never merge a DSP bit on an equivalence/timing proof alone.

One refactor per feature branch; merge `--no-ff` into `main`.

## A. DSP / Clash (unblocked by D109)

| ID | What | Files | Value | Logic risk | Status / ref |
| --- | --- | --- | --- | --- | --- |
| **F** | Split the monoliths: `Amp.hs` (722 lines) -> `Amp/{Models,Clip,Tone}.hs`, `Distortion.hs` (714) -> `Distortion/{Common,Legacy,Pedals,Rat}.hs`, each with a re-export shim so Pipeline imports are unchanged (the D26 GUI pattern). Pure code-move (Clash inlines to the topEntity). | `Effects/Amp.hs`, `Effects/Distortion.hs` | **High** (these two files dominate the DSP tree and are the most-edited) | **Low** (code move only) | **DONE 2026-06-14** (merge `1602148`). Re-applied on the **D99 source** (4b37295 was only the structure guide -- its content carried reverted D101/B/C logic). `Amp.hs`->`Amp/{Models,Clip,Tone}.hs`, `Distortion.hs`->`Distortion/{Common,Legacy,Pedals,Rat}.hs` + shims. **Proven byte-equivalent OFFLINE** via the new `tools/dsp_sim` golden regression (bypass-exact + amp/dist/od configs, hashes unchanged) -- no bench needed to confirm equivalence (the capability that de-risked this vs the D102-D105 era). vhdl/bit left at D99 (functionally identical); a Vivado build + one ear-bench produces/confirms the deployable bit. |
| **B** | Shared biquad kernels `biquadFf` / `biquadRec` / `biquad5` in `FixedPoint`, dedup the 5 resonant tone biquads (TS mid hump, Big Muff scoop, amp scoop mux, transformer resonance, OD mid). Pipeline x1/x2/y1/y2 wiring + D82 ff/rec split unchanged. | `FixedPoint.hs` + biquad sites | Med | Low (VHDL-proven == D102; note Vivado may repack DSP48: D103 saw DSP 137->139) | Reverted at D105; re-apply from `fed6cdd`. |
| **C** | Distortion pedal-stage kernels `pedalDriveGain` / `distLevelRaw`, dedup the 6 pedal drive-mul + 6 level stages. | `Effects/Distortion.hs` | Med | Low (VHDL-proven == D101) | **DONE 2026-06-17**. `Distortion/Common.{pedalDriveGain,distLevelRaw}` dedup 5 drive-mul + 6 level stages (Clean Boost's lone Unsigned-11 gain left inline); byte-EQUIVALENT (golden all 7 pedals). |
| **E** | `FixedPoint.foldTap` shared symmetric folded-FIR tap `(a+b)*g`, used by os4x decimation / Big Muff clip / cab speaker FIR. | `FixedPoint.hs` + FIR sites | Med | Low (VHDL-proven == D103) | **DONE 2026-06-17** (merge `refactor/top5`). Shared `FixedPoint.foldTap` in os4x decim / Big Muff / cab FIR; byte-EQUIVALENT (golden 20/20, F-pattern -- vhdl/bit at 54f7f547). |
| **G (new)** | Consolidate the per-model amp voicing tables. After F the split files have **12** parallel `case idx of` tables (Models.hs 7: `ampCharForModel`, `ampModelDarken`, `ampPreLpfDriveDarken`, `ampSecondStageDriveBonus`, `ampDrivePosDelta`, `ampDriveNegDelta`, **`ampPowerKnee`** [D133]; Tone.hs 5: scoop ff/fb coeffs, treble `modelTrim`, presence `presenceTrim`). A single per-model record / `Vec 6` would make adding a model or voicing ONE place instead of twelve. | `Effects/Amp/{Models,Tone}.hs` | **High** (realism passes D122/D128/D130/D132/D133 each edited several of these in lockstep -- the most-churned DSP data) | **Med** (changes data layout -> verify the constant multiset unchanged via the golden regression) | **DONE 2026-06-17** (the 6 Models.hs scalar tables -> one `AmpModel` record + thin projections; byte-EQUIVALENT, golden all 6 amp models). Remaining: the Tone.hs scoop/treble/presence tables + the base-parameterised `ampPowerKnee` were left (separate module / non-scalar). |
| **H (new)** | **Remove the now-dead `FixedPoint.onePoleHighpass`** (or rename to `firstDifference`). FOOTGUN: `prevOut * coef \`shiftR\` shift` parses as `prevOut * (coef>>shift)`, which is **0** for every shipped coef (`509>>9`), so the "one-pole" silently degenerated to a bare `x - prevIn` first difference. Both live callers (amp HP D132, RAT HP D124) had to INLINE an explicit `(prevOut*coef)>>shift` for a real pole, so `onePoleHighpass` now has **ZERO call sites** (verified). Dead code that also misled the docs/memory ("amp HP live at 298 Hz" when it was the dead first difference). | `FixedPoint.hs` | Med (kills a latent bug + a recurring stale-doc source) | **Very low** (no callers; golden bypass/amp/dist hashes unchanged) | **DONE 2026-06-17** (removed; zero callers confirmed; golden unchanged). If a future stage wants a dead first-difference, write `satWide (resize x - resize prevIn)` inline. |
| **J (new)** | **Clip-family shift parametrization.** `asymSoftClip` / `asymSoftClipSoft` / `asymSoftClipMed` / `asymSoftClipHard` / `symSoftClipMed` were FIVE copy-pasted bodies differing ONLY in the two `shiftR` constants (pos>>N neg>>M); D150 added the 5th (sym). Replace with one `softClipShift posSh negSh kneeP kneeN x` and make the five thin point-free wrappers (`asymSoftClip = softClipShift 2 3` ...). Constant shifts inline -> identical fixed wiring; names/signatures unchanged so every caller (Overdrive `odClipHardness` mux, Pedals, etc.) is untouched. | `FixedPoint.hs` | Med-High (the most-edited distortion kernel; D150 had to add a near-duplicate) | **Low** (semantic identity is exact integer arithmetic; golden proves it; F-pattern) | **DONE 2026-06-22** (`refactor/j-clip-family`). 5 bodies -> 1 `softClipShift` + 5 wrappers; golden regression byte-identical (bypass/amp/dist/od); vhdl/bit LEFT at D155 (F-pattern). |
| **K (new)** | Split `Distortion/Pedals.hs` (583 lines -- the LARGEST Clash source after the F split) into one module per pedal behind a re-export shim (F / D26 pattern). | `Effects/Distortion/Pedals.hs` | Med | **Low** (pure code-move; golden) | **DONE 2026-06-22** (`refactor/k-split-pedals`). `Pedals.hs` 583 -> 25-line shim; `Pedals/{CleanBoost,TubeScreamer,Metal,Ds1,BigMuff,FuzzFace}.hs` (40-181 lines each). No cross-pedal dep (all via Common/FixedPoint/Control/Types); BigMuff hosts the shared mid-scoop biquad Metal/DS-1 drive. golden 20/20 byte-identical, vhdl/bit LEFT at D155 (F-pattern). |
| **L (new, low priority)** | The cab speaker-rolloff FIR products (D155) hand-unroll 24 `mulS16 (hist!!i) (c!!j)` across 6 Wide Frame fields with a `Vec 46` history. A `fold` / `zipWith` over the coeff Vec is possible but Clash unrolls statically anyway, and this is a just-shipped D155 hot path -- **risk > value**. Record only; do not touch without a voicing reason. | `Effects/Cab.hs` | Low | Med (hot path, just shipped) | Deferred (record only). |
| **D** (deferred) | Pipeline tap combinators for the repetitive `x1/x2/y1/y2` biquad-state and one-pole-state register threading in `Pipeline.hs` (521 lines, ~210 state/biquad refs). | `Pipeline.hs` | Med | **High** (Signal-level / register-timing; risk of perturbing the timing-tight island) | Deferred since D104. Attempt only with careful timing review. |
| **B2** (deferred) | Pipeline `biquadStage` combinator wrapping the ff/rec split + state. | `Pipeline.hs` | Med | High (same as D) | Deferred since D104. |

## B. Python (no bitstream, no bench -- low risk)

| ID | What | Files | Value | Notes |
| --- | --- | --- | --- | --- |
| **P1** | `AudioLabOverlay.py` is the largest module. Progress: GPIO word builders are centralized in `control_maps.py`; the register-write helpers for distortion / overdrive / noise suppressor / compressor / wah / full-chain writes are split into `audio_lab_pynq/overlay/register_writers.py` (delegates, D115); and the overdrive / pedal / amp **model name->index resolvers** are split into `audio_lab_pynq/overlay/model_lookup.py` (delegates, 2026-06-13 -- class methods keep their `cls`-based constant resolution so subclass/override semantics + byte output are identical; full suite unchanged + behaviour spot-checked). **Done (T7, 2026-06-13):** the per-effect public setter/getter groups (noise-suppressor / compressor / wah / distortion / overdrive `set_*`/`get_*_settings`, the distortion pedal-mask helpers, `get_overdrive_model`, `get_current_pedalboard_state`) are extracted into `audio_lab_pynq/overlay/effect_settings.py` (ovl-taking functions; class keeps thin delegates; GPIO byte output byte-for-byte identical, full suite green at each of 3 increments). `AudioLabOverlay.py` 1688 -> 1453 lines. **Orchestration tail (2026-06-22):** `apply_chain_preset`'s one cleanly-separable piece -- the PURE construction of the big `set_guitar_effects(**kwargs)` dict from a (tapered, model-pinned) preset spec -- was extracted to `overlay/chain_preset_apply.build_guitar_effects_kwargs(spec, pinned)` (no `self`, no writes; byte output pinned by `test_overlay_controls`). The **residual is genuinely class-coupled** and is left in place: `apply_chain_preset`'s `set_compressor_settings` / `set_noise_suppressor_settings` / `set_distortion_*` calls with `hasattr` GPIO guards mutate overlay state in sequence, and `set_guitar_effects` is already 6-helper-split -- extracting either further would just thread `self` around with no readability gain (same conclusion as refactor M). `AudioLabOverlay.py` 1461 -> 1421 lines. Full suite 360 passed. | `audio_lab_pynq/AudioLabOverlay.py`, `audio_lab_pynq/overlay/` | High (most-touched API) | Keep the public method surface + snapshot-test byte output identical. Stateful setters were done one-effect-per-increment leaning on `tests/test_overlay_controls.py`. |
| **P2** | `GUI/compact_v2/renderer.py` (1225 -> 1048 lines) -> split the per-panel render functions (header / chain / fx grid) into `renderer/` modules behind the existing re-export shim. **DONE 2026-06-22** (`refactor/p2-renderer-panels`): the shared-cache holder + primitives went to `_render_primitives.py` (307 lines; `set_active_render_cache()` save/restore replaces the cross-module `global` rebind), and the per-panel draw functions to `_render_panels.py` (274 lines; panels -> primitives, renderer -> both = no circular import). `renderer.py` 1048 -> 536 lines, re-exports everything (incl. `_ACTIVE_RENDER_CACHE` for the `__init__` / GUI-shim surface). Verified byte-identical via a 108-frame render-snapshot digest (states x themes x variants x cache on/off) `f23864c5` + full suite 360 passed; an on-LCD confirm is still recommended before relying on it on hardware. **Progress (2026-06-13):** the three side-effect-free leaves are now extracted into `_render_compat.py` / `_render_fonts.py` / `_render_cache.py` (re-imported by `renderer.py`, so `from compact_v2.renderer import X` is unchanged); render-equivalence verified byte-identical over 60 frames (states x variants x themes). | `GUI/compact_v2/renderer.py` | Med | **NOT a pure code-move (corrected 2026-06-13; the P2 split handles it via the `_render_primitives` shared-cache holder).** The module-level `_ACTIVE_RENDER_CACHE` global is *read* by the draw primitives (`draw_text` / `draw_smooth_text` / `vertical_gradient` / `_pynq_static_mode`) and *written* (`global ... = cache`) by the two frame builders; split them across modules and the `global` rebind stops being shared. A clean split therefore needs a tiny shared-cache holder (accessor get/set) OR must keep every global-touching function in one submodule. Truly side-effect-free leaves that ARE pure moves: `_RandomStateCompat`/`_rng`, `RenderCache`+`make_pynq_static_render_cache`+the `state_*_signature` helpers, and the font cache (`_base_font`/`_smooth_font`/`_measure`). Also: the renderer only runs on the board HDMI path (Pillow 5.1 / NumPy 1.16 compat shims) -- correctness is only pixel-snapshot-verifiable off-board, so bench it on the 5-inch LCD after any split. |
| **P3** | Fold remaining duplicated scale/range constants into the single source (extends A). | `control_maps.py`, `effect_presets.py`, `effect_defaults.py`, `constants.py` | Low (re-scoped 2026-06-13) | After A there is little in-package scale/range duplication left to fold. NB `SAFE_BYPASS_DEFAULTS` deliberately differs from the per-effect default dicts (it zeroes drive/decay/gain for a silent panic) -- do NOT "dedup" it against them. The real remaining duplication is the **model-name tables** (`ts9`/`jc_120`/... ) copied across `GUI/compact_v2/knobs.py` <-> `effect_defaults.py` <-> `audio_lab_pynq/hdmi_state/{pedals,amps,overdrives}.py` <-> `effect_presets.py`; unifying those couples the GUI, package, and hdmi_state layers (which are intentionally separable) so it is a layering decision, **not** a low-risk fold. |
| **M (new)** | `audio_lab_pynq/hdmi_effect_state_mirror.py` was **1238 lines** (the second-largest Python module) even after the per-effect split under `hdmi_state/`. Move the cleanly-separable parts to `hdmi_state/` with the class keeping thin delegates. | `audio_lab_pynq/hdmi_effect_state_mirror.py`, `audio_lab_pynq/hdmi_state/` | Med | **DONE 2026-06-22** (`refactor/m-hdmi-summary`). The read-only reporting group (`get_state_summary` / `resource_summary` / `summary` / `summary_json` + the SELECTED FX history printers, ~145 lines) -> new `hdmi_state/summary.py` as `mirror`-taking functions; the D55 `_amp_model_from_character` (pure) -> `hdmi_state/amps.amp_model_from_character`. Class keeps thin delegates. Mirror 1238 -> 1111 lines; full suite 360 passed / 2 skipped, byte-for-byte behaviour preserved (no bitstream / bench). **Residual is genuinely class-coupled** (the `_apply_*_state` / `_sync_*` / `render` orchestration mutate several instance attrs + overlay/renderer in lockstep -- delegate-extracting them would just pass `self` around with no readability gain), so the audit stops here. |
| **P4 (new)** | **De-duplicate the `tools/dsp_sim` harness** -- it grew a lot during the 2026-06 realism survey and now has (a) THREE config-builders that pack the 12 control words: `measure.build_config`, `run_sim.build_words`, `knobcheck.build_words` (the last is wholly separate), and (b) analysis helpers copied/spread across files: `hf_slope` is duplicated in `targets._hf_slope` (copied to dodge a circular import), and `band_balance` / `harmonic_profile` / `tone_levels` / the FFT-peak helpers live in `measure.py` + `harmonics.py` and are imported ad-hoc. Pull the config-building into a shared `dsp_sim/simcore.py` and the spectral/metric helpers into `dsp_sim/metrics.py`, so `measure`/`dist_eval`/`harmonics`/`knobcheck`/`reverb`/`targets` import one source. | `tools/dsp_sim/*.py` | Med (the harness is now the main realism-iteration tool; the 3 builders drift) | **Low** (host Python, no bitstream; verify each tool's output is byte-identical -- `measure --batch`, `--check`, and the opt-in golden regression already pin it). | **DONE 2026-06-17** (metrics.py = hf_slope/band_balance/BANDS_HZ; killed the targets._hf_slope copy; measure --check 28/28 unchanged). The 3 config-builders were LEFT -- on review they are different abstractions (by-name effect / preset / per-knob), not duplicates. |

## C. Build / infra

| ID | What | Value | Notes |
| --- | --- | --- | --- |
| **I1** | ~~The clash regen mtime trap (editing an imported `AudioLab/*.hs` does NOT make `vhdl/LowPassFir` rebuild because the Makefile rule only depends on `src/LowPassFir.hs`). Add the `AudioLab/**.hs` files as prerequisites, or a `regen` phony that always `rm -rf vhdl/LowPassFir` first, and bake in the `-package-id` so the bare `make` works.~~ **DONE** (verified 2026-06-13). `hw/ip/clash/Makefile` now sets `AUDIO_LAB_SRCS := $(shell find ./src/AudioLab -name '*.hs')`, lists it as a prerequisite of the `vhdl/%` rule, provides a `regen` phony (`rm -rf $(VHDLS); $(MAKE) all`), and bakes `-package-id` into `CLASH_FLAGS` so a bare `make` works. The mtime-trap memory still applies if anyone hand-`rm`s `component.xml` alone -- use `make regen` to be safe. | High (this has silently shipped stale logic before -- memory `project_clash_vhdl_regen_mtime_trap`) | `hw/ip/clash/Makefile`. |

## Suggested sequencing

0. **H** (remove the dead `onePoleHighpass`) -- standalone, ~zero risk (no
   callers), do anytime; kills a footgun that has already misled the docs twice.
1. **F** (split Amp/Distortion) -- biggest readability win, lowest risk, source ready. **DONE**.
2. **C** then **B** then **E** (kernel dedups) on top of the split files.
3. **G** (per-model voicing record) once the amp file is split -- now the
   highest-value DSP refactor (12 lockstep-edited tables; every realism pass
   touches several).
4. **P1 / P2 / P4** Python splits in parallel (no bench needed -- but see the P2
   shared-global caveat; P4 = `tools/dsp_sim` dedup, verify byte-identical tool output).
5. ~~**I1** Makefile fix~~ -- **DONE** (2026-06-13).
6. **D / B2** (Pipeline Signal-level) last, only with a timing-summary review.

Every DSP item (A-section + G) goes through the verification protocol above; the
Python/infra items just need their existing tests + a smoke.
