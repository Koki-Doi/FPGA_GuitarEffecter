# Resume prompts

Short prompts the user can paste back to either Claude Code or Codex
after a rate-limit, context reset, or session restart. Each one is
self-contained and points the agent at the right docs instead of
asking it to re-discover the project from scratch.

## Current status (2026-06-21, overnight ABC: A merged; B no-fix; C/D155 built-not-deployed)

> **Accepted baseline on `main` AND on the board = D153** (bit `5c0086b0`). The
> overnight "ABC" batch:
> - **A (done, on `main` `98a4c93`)**: `deploy_to_pynq.sh` now md5-verifies every
>   board bit/hwh copy vs the repo with NO overlay download (catches the D153
>   0-byte corruption class), and the printed smoke is no-download by default with
>   a download-hazard warning. Tooling only.
> - **B/D154 (investigated, NOT shipped)**: reducing gain-amp chord IMD has no
>   safe blind lever -- drive-darken = zero rig effect (regenerated downstream);
>   the only effective levers (gain/level cut) change character/loudness + undo
>   D151 brightness; the real fix is multiband distortion (big). Deferred for
>   ear-in-loop.
> - **C/D155 (BUILT + COMMITTED on `feature/overnight-d154-d155`, NOT deployed)**:
>   cab speaker FIR 31->47 taps (low-risk Option-Y folded extension, NOT the
>   high-risk 128-tap BRAM B2). measure 28/28, only cab golden changed, bypass
>   bit-exact. Build WNS `+0.319`, **D109 CDC fwd `+0.989` = LOWEST of the arc =
>   elevated buzz risk**, pblock 112, DSP 206/220. bit `8d875cc8`. Left UNDEPLOYED
>   (board stays D153) because of the CDC flag + marginal/darker benefit + the
>   unattended download hazard. **To bench C: `git checkout <D155 commit> --
>   hw/Pynq-Z2/bitstreams/ && bash scripts/deploy_to_pynq.sh`, load once, then
>   ear-bench all-off bypass for buzz + judge the darker cab top; if bad stay on
>   D153 (`git checkout b86c88a -- hw/Pynq-Z2/bitstreams/`).**
> Read `CURRENT_STATE.md` + `DECISIONS.md` D155/D154 before continuing.

## Current status (2026-06-21, D153 JC/Twin 音割れ fix — BENCH-ACCEPTED, merged to main)

> **D153 is the new accepted committed baseline on `main`** (merge `b86c88a`,
> bit `5c0086b0` / hwh `5a373a38`), superseding D151 and carrying the D152
> chord-IMD cleanup. User bench: 合格. D153 decoupled the D152 regression:
> (1) restore `cabSpeakerKnee` to D151 (peak limiter back, fixes 音割れ); (2) keep
> the D152 early-stage cab headroom (body/presence knees) + presence pull-back
> (where the chord IMD is generated); (3) trim JC/Twin master ~-1.3 dB (shift-only)
> so the cab final clip is fed less = chord stays clean + output <= D151. measure
> 28/28, dist_eval 7/7+6/6, regression = only amp_jc120+amp_twin goldens
> (re-blessed), bypass bit-exact. Build MET WNS `+0.561`, D109 CDC fwd `+2.059`,
> pblock 112, DSP 183. `baselines.json` updated (D153 accepted-current, D151
> accepted-superseded). Rollback to D151: `git checkout 238ec53 --
> hw/Pynq-Z2/bitstreams/`. **OP NOTE: a post-deploy board hang (repeated
> download=True) + cold power-cycle zeroed all 15 board notebooks + some bit
> copies (unclean-poweroff); a re-deploy (no download) restored them. Minimise
> repeated download=True smokes.** Read `CURRENT_STATE.md` + `DECISIONS.md` D153
> before continuing.

## Current status (2026-06-21, D152 chord-HF/IMD fix — CANDIDATE superseded by D153)

> **D151 remains the accepted committed baseline on `main`** (amp HF brighten,
> bit `9f9e71a2`). **D152 is a built+deployed CANDIDATE on branch
> `feature/d152-chord-hf-imd`, pending bench.** User: JC/Twin chord top "汚い" +
> all amps large-chord top "ブツブツ". **CONFIRMED (numpy 1x-vs-4x): this is
> in-band IMD (chord sum/diff products in 2-8 kHz, <Nyquist), NOT aliasing -- 4x
> oversampling does NOTHING (the user's first choice would have been a big rebuild
> for zero gain; pre-checked in numpy before building).** D151's brightening
> amplified the pre-existing IMD. Fix (user-chosen, Cab.hs constant/coeff-only,
> no new DSP): (1) raise cab sat headroom (speaker/body/presence knees ~+1.5M);
> (2) pull the D151 cab presence-peak back +6.0/6.5/7.0->+4.5/5.0/5.5 dB (keeps
> most brightness). Clean amps' rig chord HF ~+4-5 dB cleaner, brightness mostly
> kept; gain amps ~unchanged (amp-side, partly intended). `measure --check` 28/28
> (no retarget), `dist_eval --check` 7/7+6/6, regression = only `cab` golden
> changed (re-blessed), bypass bit-exact. Build MET WNS `+0.506`; D109 CDC pair
> fwd `+5.337` (safest of the arc); pblock 112; DSP 181. bit/hwh `f2f77b45…` /
> `094ce742…`. Deployed (3 copies md5-match), mode-2 smoke PASS, board mute.
> **NEXT: user ear-bench.** If 合格 -> merge `feature/d152-chord-hf-imd` to `main`
> + update `baselines.json` (D152 accepted-current, D151 accepted-superseded). If
> rejected -> redeploy D151 (`git checkout 238ec53 -- hw/Pynq-Z2/bitstreams/`).
> Future chord-IMD work on the GAIN amps is NOT oversampling (proven) -- it needs
> amp headroom (trades loudness) or multiband distortion (big). Read
> `CURRENT_STATE.md` + `DECISIONS.md` D152 before continuing.

## Current status (2026-06-21, D151 amp HF brighten — BENCH-ACCEPTED, merged to main; D152 next)

> **D151 is the new accepted committed baseline on `main`** (merge `238ec53`,
> bit `9f9e71a2` / hwh `70c4e3f8`), superseding D150. User bench: "合格".
> **OPEN (D152): user reports JC-120 + Fender/Twin CHORD high-end is "汚い"
> (dirty/harsh), long-standing -- investigate next (chord_eval / a HF-band IMD
> view; likely the clean-amp 2-5 kHz chord intermod now more audible after the
> D151 brightening, or aliasing of the brightened top).** D151 was: amp-side
> levers barely move a RIG (TREBLE/PRESENCE + post-amp HF shelf each moved rig
> 2-4 kHz <1 dB; cab dominates), so the fix (placement-safe, no new DSP) was
> (1) a new shift-only post-amp HF shelf `ampHfShelfFrame` (corner ~1.9 kHz,
> +3.5 dB, before the cab, amp-on, skips JC-120) + (2) the per-model cab
> presence-peak biquad raised +3.0/+3.5/+4.0 -> +6.0/+6.5/+7.0 dB (D149 >5 kHz
> rolloff FIR untouched) = the real rig lever. Rig 2-4 kHz +2-3 dB. `measure
> --check` 28/28 (2 re-targets), `dist_eval --check` 7/7+6/6, regression = only
> the 5 tube-amp goldens + cab changed (re-blessed), bypass bit-exact. Build MET
> WNS `+0.451`; D109 CDC pair fwd `+1.697`; D146 pblock 112; DSP 181/220.
> Deployed (3 copies md5-match), mode-2 smoke PASS. Rollback to D150:
> `git checkout 112ae9a -- hw/Pynq-Z2/bitstreams/`. Read `CURRENT_STATE.md` +
> `DECISIONS.md` D151 before continuing.

## Current status (2026-06-21, D150 OD/DS chord-IMD fix — BENCH-ACCEPTED, merged to main)

> **D150 is the new accepted committed baseline on `main`** (merge `112ae9a`,
> bit `29f5fe01` / hwh `fbb69e36`), superseding D149. User bench: "合格"; the
> fwd-slack caveat (+1.009) did NOT manifest as a bypass buzz. The user
> reported "OD、DS の歪かたが変。特に和音". Sim先行 found the chord mud is IN-BAND
> intermodulation (oversampling proven useless via a numpy 1x-vs-4x test), and
> the gainy OD models (OD-1/BD-2/OCD/Klon) + DS-1 used ASYMMETRIC clip slopes →
> strong even-order sum/difference tones (the "detuned chord"). Fix = symmetrise
> the clip slope (new `FixedPoint.symSoftClipMed` pos>>2 neg>>2; `odClipHardness`
> 4=symSoftClipMed / OCD→3=asymSoftClipHard; `odKneeN` raised toward kneeP; DS-1
> clip `asymSoftClip`→`symSoftClipMed` knee 1.9M→2.15M). TS9/JanRay untouched.
> Placement-safe constants, no os4x, no new pipeline. Sim: chord IMD better at
> every level + even→odd shift; `measure --check` 28/28; `dist_eval --check`
> 7/7+6/6; regression = only od_ocd+distortion_ds1 goldens changed (re-blessed),
> bypass bit-exact. Build MET WNS `+0.522`/WHS `+0.012`; **D109 CDC pair fwd
> `+1.009`** (lower than D149's +1.416 — a RISK INDICATOR, ear-bench all-off
> bypass carefully; D146 pblock intact 112 cells); DSP 183/220. bit/hwh md5
> `29f5fe01…` / `fbb69e36…`. Deployed (4 copies md5-match), mode-2 smoke PASS
> (`+288369/3 s`), board mode 3 mute. **BENCH-ACCEPTED + merged to `main`
> (`112ae9a`); `baselines.json` updated (D150 accepted-current, D149
> accepted-superseded).** Rollback to D149: `git checkout 1468e93 --
> hw/Pynq-Z2/bitstreams/` + deploy. Read `CURRENT_STATE.md` + `DECISIONS.md`
> D150 before continuing.

## Current status (2026-06-20, D148 clean-headroom fix BENCH-ACCEPTED + merged to main)

> **D148 is the new accepted committed baseline** (`--no-ff` merged into `main`;
> carries the D146 hard pblock + D147 sag slew + the D148 clean headroom),
> superseding D135. It was the follow-up to the D147 JC/Fender partial fail. User confirmed safe bypass is
> CLEAN and the 音割れ is playing-only = a voicing headroom limit, not CDC. New
> `tools/dsp_sim/clip_onset.py` localized it: JC-120 broke up by ~0.18 FS and Twin
> by ~0.12-0.18 FS (gain models break early by design). Fix (placement-safe
> constants/mux, no new multiply): `ampPowerKnee` JC 6.8M->8.2M + Twin 4.6M->6.8M
> (Models.hs) and a clean-mode-only `ampCleanKneeBonus` (Twin 2.5M, others 0) in
> `ampAsymClip` (Clip.hs); both now stay clean to ~0.25 FS. Surgical: golden
> regression 20/20 with NO re-bless (bypass bit-exact, all models byte-identical
> at golden levels); `measure.py --check` 28/28; `dist_eval.py --check` 7/7 + 6/6;
> `dynamics_eval.py --check` 4/5 (pre-existing crunch_rig); `chord_eval
> --check-only` 2/6 = same as D147. Build MET: WNS `+0.526`, WHS `+0.014`, route
> errors `0`, D109 CDC pair MET (pblock self-check fwd `+1.632`), pblock intact
> (112 cells), XDC max_delay 10 ns. bit/hwh md5
> `972d9ba6645dd966e6bdcb5bc3daf478` / `2b888ff1ec3168cd64e1b679bbbc71be`. Four
> board bit copies md5-match, 15/15 Notebooks valid, mode-2 smoke PASS
> (`FRAME_COUNT +288366/3 s`), board in mode 3 mute. **BENCH-ACCEPTED ("完璧");
> merged to `main`, D148 = new accepted baseline.** `baselines.json` updated
> (D148 accepted-current, D135 accepted-superseded). Rollback to D135:
> `git checkout 765323b -- hw/Pynq-Z2/bitstreams/` + deploy. Read
> `CURRENT_STATE.md`, `DECISIONS.md` D148/D147/D146, and `tools/dsp_sim/README.md`
> (clip_onset.py) before continuing.

## Previous status (2026-06-20, D147 bench partial fail: JC/Fender clipping; superseded by D148)

> **D135 remains the accepted committed baseline.** D147 is the current board
> candidate on `feature/d147-sag-attack`, built on the unaccepted D146 hard
> pblock. It changes only the tube Amp sag attack to a 96-count/sample slew;
> release, clean headroom/knees, model levels, GPIO, clocks, topology,
> `block_design.tcl`, and D109 constraints are unchanged. It does not reapply
> the rejected D144 bundle. Exact sim improves every tube model but fully passes
> only Twin: JC/Twin/AC30/Rockerverb/JCM800/TriAmp clean-chord IMD is
> `-34.7/-33.6/-17.3/-10.0/-11.0/-10.5 dB`, or 2/6 pass. Static build passes
> at WNS/WHS `+0.686/+0.021 ns`, route errors `0`, bus-skew minimum `+8.153`,
> D109 CDC `+1.395/+6.497 ns`; pblock counts remain 112 assigned and 111/125
> source/target primitives. bit/hwh md5 are `03bdbc2ffa6962e8d86135ed2f69e367`
> / `969834614ef6d4e2551f16e983dc6ab3`. Exact-md5 deploy and smoke pass
> (`FRAME_COUNT +288542/3 s`, ADC HPF True, `R19=0x23`); the board is mode 3
> mute after all-off, Twin Clean, and AC30 Clean listening windows. **User bench
> verdict: JC-120 and Fender/Twin Reverb audibly clip; the other Amp models
> sound good.** The all-off buzz verdict was not separately reported. D147 is
> not accepted and `baselines.json` is unchanged. JC-120 is sag-exempt and its
> golden is unchanged, while Twin passes the 0.15-FS offline chord ceiling;
> therefore do not blindly retune sag. First reproduce JC/Twin at controlled
> input levels, compare their onset of clipping against D135, and localize the
> responsible gain/headroom stage. Board is D147 in mode 3 mute. Read
> `CURRENT_STATE.md`, `DECISIONS.md` D147/D146/D145,
> `TIMING_AND_FPGA_NOTES.md`, and `tools/dsp_sim/README.md` before continuing.

> **D135 remains the accepted committed baseline.** The accepted D135+D145
> repository state is marked by annotated local tag `v1.0.0` at `eead0bf`;
> the tag was not pushed. D146 is a structural candidate on branch
> `feature/d146-cdc-pblock`: implementation-only hard pblock
> `pblock_audio_output_cdc` at `SLICE_X100Y116:SLICE_X113Y137` locks the
> `axis_switch_sink` transfer-mux-0 register slice and `i2s_to_stream` write-side
> distributed-RAM wrapper. No DSP/GPIO/clock/`block_design.tcl` change and the
> D109 10 ns bidirectional max-delay bounds are unchanged. Build passed with WNS
> `+0.571`, WHS `+0.018`, route errors `0`, bus-skew min `+8.126`, CDC pair
> `+3.131` / `+6.670 ns`; bit/hwh md5 are
> `55d431d9488d039fb1bfd9e4963871c8` /
> `9e4075000ecd338e24a355df36db7e8c`. Deploy file sync and Notebook checks
> passed. The first smoke attempt lost board connectivity, but after cold
> restart all checked bit copies md5-matched and the one-load smoke passed:
> required IPs present, ADC HPF True / `R19=0x23`, mode 2, clocks/SDOUT alive,
> `FRAME_COUNT +288550/3 s`, then mode 3 mute readback. Input clipped full-scale
> (`CLIP_COUNT +59`), so this is not a tonal gate. Roadmap item 3 is active:
> build at least three distinct placement fingerprints using
> `rerun_impl_with_cdc_pblock.tcl`, and require every bit to pass timing/CDC,
> exact-md5 deploy, programmatic smoke, and user all-off safe-bypass listening.
> This is now complete except the user's acoustic verdict. A/default
> (`fp f7bde6a4`, bit `55d431d9`, WNS/WHS `+0.571/+0.018`, CDC
> `+3.131/+6.670`, frames `+288550`), C/`ExtraNetDelay_high`
> (`fp 5b5a0f95`, bit `2eee129f`, `+0.486/+0.016`, CDC `+1.942/+6.768`,
> frames `+288533`), and D/`AltSpreadLogic_high` (`fp f16c704e`, bit
> `01859530`, `+0.383/+0.024`, CDC `+0.911/+5.946`, frames `+288318`) are
> genuinely distinct and all passed static/programmatic gates. `Explore` was
> identical to A and excluded. A/C/D each had an all-off/Wah-off listening
> window and final mute; ask the user for buzz/no-buzz per variant. Board is D
> in mode 3 mute; local tracked bit is A. D146 is not accepted and not in
> `baselines.json` until all three ear verdicts pass.
>
> Historical context: D144
> (narrow D135-based chord-detune candidate: `ampSagAttackStep = 96` plus
> clean-mode `ampCleanKneeBonus` / `ampCleanPowerBonus`) was bench-rejected by
> the user ("失敗") and rolled back. D144 must not be treated as accepted and is
> not in `baselines.json`. The rollback restored DSP Clash source, regenerated
> VHDL/IP, golden vectors, and bit/hwh from D135 commit `765323b`. Local and
> board bit/hwh md5 are D135: bit `533d586901dc3669285a49c6d82bab9f`, hwh
> `731517487c6218f0e181c2b74485d7a6`. Board copies under
> `/home/xilinx/Audio-Lab-PYNQ/`, `audio_lab_pynq/bitstreams/`, and
> `/home/xilinx/pynq/overlays/audio_lab/` md5-match. Rollback smoke passed:
> `AudioLabOverlay()` loads, ADC HPF True, `R19_ADC_CONTROL 0x23`, Pmod mode 2
> `FRAME_COUNT +288368` over 3 s (~96 kHz), and Pmod was returned to
> `MODE=3` mute. D145 then fixed Notebook visibility in
> `scripts/deploy_to_pynq.sh`: Jupyter root is now discovered from
> `sudo jupyter notebook list`, not the daemon process CWD. The canonical board
> tree is `/home/xilinx/jupyter_notebooks/audio_lab/`; deploy verified all
> 15/15 `.ipynb` files as valid JSON, restored `xilinx:xilinx` ownership, and
> prints `http://192.168.1.9:9090/tree/audio_lab` plus the direct
> `AudioLab.ipynb` URL. If chord-detune work resumes, do not reapply D144 as-is;
> finish and bench D146 first. Read `CURRENT_STATE.md`, `DECISIONS.md` D143-D146,
> D109, `BASELINES.md`, and
> `TIMING_AND_FPGA_NOTES.md` first; run `git status --short` and
> `git diff --stat` before continuing.

## Previous accepted status (2026-06-17, after D135 large non-IR realism accepted merge)

> Accepted deployed bitstream baseline is **D135**: merge commit `765323b`,
> large non-IR realism (Fuzz Face 900 Hz mid-hump biquad + tighter clip knees +
> opened tone LPF; AC30/JCM800 stronger `ampScoop` + model-local presence; Amp
> `MIDDLE` more audible; AC30 clean headroom; Cab non-IR body tap). bit md5
> `533d586901dc3669285a49c6d82bab9f`, hwh md5
> `731517487c6218f0e181c2b74485d7a6`; timing fully MET (WNS `+0.643`,
> WHS `+0.018`, route errors `0`, bus-skew min slack `+8.099`). The offline
> suite passes: `measure.py --check` 28/28, `dist_eval.py --check` 7/7 pedals +
> 6/6 clean amps, `dynamics_eval.py --check` 5/5, `knobcheck.py --all` with no
> barely-audible flags, and the relevant pytest suites (regression 20, tools +
> overlay 136). It was deployed and the PYNQ bit/hwh board sites md5-match.
> Programmatic mode-2 smoke showed engine/frame cadence alive (~96 kHz,
> `FRAME_COUNT +288374`, `CLIP_COUNT 0`) and ADC HPF `True`; the board was left
> in Pmod `MODE=3` mute for safety. User then bench-ACCEPTED and approved the
> merge. D134 (`f62f132`, bit `58b6ee84...`) is the immediate rollback baseline.
> Read `CURRENT_STATE.md`,
> `DECISIONS.md` D109-D135, `BASELINES.md`, and `TIMING_AND_FPGA_NOTES.md`
> first; run `git status --short` and `git diff --stat` before continuing.

## FP02M expression pedal -> Wah POSITION (XADC re-add on the D75 island) — DONE (D76, 2026-05-31)

> **完了。** XADC を D75 island 上で再有効化 (`create_project.tcl` の2行を
> un-comment、Clash/island 無変更)。rebuild WNS `-0.368 ns` (100 MHz audio
> fabric は +0.614 ns / 失敗0、bitcrusher 再発せず)。bit/hwh md5
> `9fdecae0...` / `a9fd7408...` を 5-site deploy。bench PASS: all_off bypass
> クリーン、FP02M sweep span ~2999、ペダル→Wah POSITION 追従、Q=100+toe で
> 発振なし。**bench で見つけた Python 修正2件** (bit 再ビルド不要): (1)
> Wah-only クロスバールーティング (`_route_effect_chain` が Wah enable を
> gate に含めず passthrough で DSP をバイパスしていた)、(2) Wah Q 発振キャップ
> (`WAH_Q_BYTE_MAX = 80`)。詳細は `DECISIONS.md` D76 /
> `FP02M_PEDAL_INTEGRATION.md` section 11。以下は当時の手順 (履歴参照用):
>
> D75 の DSP island baseline (main, bit `4a0b3dae`) の上に、FP02M
> エクスプレッションペダル → Wah POSITION を実装してください。FP02M は
> 実機 Arduino A0 に **直接接続済み (3.3V 電源、電圧安全、wiper 直結)**。
> リポジトリ全体を再調査せず、まず `CLAUDE.md`、
> `docs/ai_context/CURRENT_STATE.md`、`DECISIONS.md` (D74 + D75)、
> `FP02M_PEDAL_INTEGRATION.md`、`XADC_INTEGRATION_DESIGN.md`、
> `DSP_ISLAND_CLOCK_DESIGN.md` を読んでください。
>
> 状況: ソフト層 (`audio_lab_pynq/fp02m.py` + `scripts/probe_fp02m_a0.py` /
> `calibrate_fp02m.py` / `run_fp02m_wah_test.py` + GUI SOURCE=PEDAL +
> `run_encoder_hdmi_gui.py --wah-pedal`) は D74 で完成・コミット済み。
> **ソフトは原則変更不要**。唯一の作業は A0 (VAUX1) を読む XADC Wizard の
> 再追加で、`hw/Pynq-Z2/create_project.tcl` の XADC 2行 (`add_files ...
> xadc_a0.xdc` と `source ./xadc_integration.tcl`) が今コメントアウト
> されているので再有効化します。D74 で XADC は audio bitcrusher で却下
> されましたが、原因は当時の WNS -11ns / 100MHz のタイトな audio AXIS
> datapath の P&R 劣化で、**ペダル接続とは無関係** (D74調査 + ユーザー確認)。
> **D75 で DSP は50MHz島・WNS -0.7ns と余裕があるので bitcrusher 再発しない
> 見込み** — これが唯一の関門。
>
> 手順:
> 1. `create_project.tcl` の XADC 2行を再有効化 (Clash/DSP は無変更=island維持)。
> 2. `cd hw/Pynq-Z2 && make clean && make` (~15分)。WNS確認、hwh に
>    `xadc_wiz_a0` が出ること、island (`cc_dsp_in`/`cc_dsp_out`,
>    FCLK0=100/FCLK1=50, `set_clock_groups`) が維持されることを確認。
> 3. `bash scripts/deploy_to_pynq.sh` で5サイト同期 (md5一致確認)。
> 4. **PYNQ を cold power-cycle した後 `download=True` を1回だけ**
>    (`feedback_deploy_smoke_avoid_repeated_download` 厳守、同一セッション
>    2回目はハングし cold power-cycle でしか回復しない)。smoke で
>    `xadc_wiz_a0` present / ADC HPF True / `axi_gpio_wah` present を確認。
> 5. **audio bench で bitcrusher が出ないか確認 (D74 却下基準、all_off
>    bypass がクリーンか、Pmod mode 2 ADC->DSP->DAC)** — 最重要関門。
>    クリーンなら続行。bitcrusher なら XADC配置の Pblock 保護 か 外部SPI
>    ADC (MCP3008) を提案してユーザーに報告し、勝手に進めない。
> 6. `sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3
>    scripts/calibrate_fp02m.py` でキャリブレーション (FP02M 実測 raw
>    16..4068 が D74 実績) → `~/.config/audio_lab/fp02m_calibration.json`。
> 7. `scripts/run_fp02m_wah_test.py --mmio` または GUI
>    `run_encoder_hdmi_gui.py --pmod-mode dsp --wah-pedal --live-apply
>    --skip-rat` で、ペダルを踏むと SOURCE=PEDAL の POS bar が追従し、Wah ON
>    で sweep が聞こえること、Q/VOL/BIAS は独立、no pop/click を実機確認。
> 8. 全PASS なら commit + main マージ (D76 として `DECISIONS.md` /
>    `CURRENT_STATE.md` / `TIMING_AND_FPGA_NOTES.md` /
>    `FP02M_PEDAL_INTEGRATION.md` を更新)。
>
> 制約: `download=True` は1セッション1回。`block_design.tcl` 本体は編集
> しない (XADC は `xadc_integration.tcl` の additive)。D75 island の
> `paceCount` 削除 / `syncCtrl` 制御word CDC / `set_clock_groups` は維持・
> 復活させない。`git push` / `pull` / `fetch` 禁止。ADC HPF デフォルトON維持。

## General resume

> 前回の作業は途中停止しました。リポジトリ全体を再調査しないでください。
> まず `AGENTS.md` または `CLAUDE.md` を読み、続けて
> `docs/ai_context/PROJECT_CONTEXT.md`、`CURRENT_STATE.md`、
> `DECISIONS.md` を読んでください。
> 次に `git status --short` と `git diff --stat` を確認してください。
> 未commit差分は破棄せず、現在の差分から作業を再開してください。
> `git push` / `git pull` / `git fetch` は禁止です。
> ADC HPF デフォルトON 設定を壊さないでください。
> `hw/Pynq-Z2/block_design.tcl` は変更しないでください。
> GPIO 設計は固定 (`DECISIONS.md` D12)、既存 GPIO 名 / address /
> ctrlA-D 割り当てを再配置しないでください。
> C++ DSP プロトタイプは削除済み (`DECISIONS.md` D13)。
> 新エフェクト追加では C++ → 移植の手順に戻らず、Python API / UI
> 予約 → Clash ステージ追加で進めてください。

## HDMI GUI integration — implemented, one-overlay only

> HDMI GUI統合は Phase 4 で `audio_lab.bit` に実装済みです。
> まず `AGENTS.md`、`docs/ai_context/PROJECT_CONTEXT.md`、
> `CURRENT_STATE.md`、`DECISIONS.md` を読み、続けて
> `docs/ai_context/HDMI_GUI_INTEGRATION_PLAN.md` を読んでください。
> 現在の live path は `AudioLabOverlay()` を1回だけloadし、
> `audio_lab_pynq.hdmi_backend.AudioLabHdmiBackend` で統合 HDMI
> framebuffer を扱います。`GUI/pynq_multi_fx_gui.py` は今は
> `GUI/compact_v2/` への re-export shim (`DECISIONS.md` D26)。
> renderer / palette / hit_test / AppState / 旧 `run_pynq_hdmi()` を
> 触る場合は `GUI/compact_v2/{renderer, layout, hit_test, state}.py`
> 側を編集してください。 `run_pynq_hdmi()` 自体は D24 で削除済みなので、
> live AudioLab では使いません。同様に
> `audio_lab_pynq/hdmi_effect_state_mirror.py` は
> `audio_lab_pynq/hdmi_state/` へ分割済み (constant / helper /
> ResourceSampler は subpackage 側、`HdmiEffectStateMirror` class は
> shim 側)。5-inch LCD の標準は Phase 6I C2 SVGA 800x600
> HDMI timing です (`DECISIONS.md` D25)。compact-v2 `800x480` を
> `placement=manual`, `offset_x=0`, `offset_y=0` で `800x600`
> framebuffer の左上に置き、下 120 行は黒のままにします。 Phase 6H の native
> 800x480 / 40 MHz timing は LCD が白画面で受理しなかったため不採用。 最も簡単な動作確認は `audio_lab_pynq/notebooks/HdmiGuiShow.ipynb`
> の 1 セル実行 (smart-attach で kernel 死亡と PLL 飛ばしを回避)。次作業を始める前に
> `git status --short` と `git diff --stat` を確認してください。
> `base.bit` をロードしないでください。`AudioLabOverlay()` の後に別
> `Overlay()` をロードしないでください。`hw/Pynq-Z2/block_design.tcl`、
> Clash/DSP、bitstream、deploy はユーザの明示承認なしに変更しないで
> ください。
> `git push` / `git pull` / `git fetch` は禁止です。

## HDMI GUI — VESA SVGA 800x600 baseline (Phase 6I)

> 統合 HDMI 経路は VESA SVGA `800x600 @ 60 Hz`、pixel clock
> `40.000 MHz`、H total `1056` (`fp 40, sync 128, bp 88`)、V total
> `628` (`fp 1, sync 4, bp 23`)、`rgb2dvi_hdmi.kClkRange=3` です
> (`DECISIONS.md` D25)。framebuffer は
> `audio_lab_pynq/hdmi_backend.py` の
> `DEFAULT_WIDTH=800, DEFAULT_HEIGHT=600` で取り、compact-v2 UI は
> framebuffer `(0,0)` に置きます (visible 上 480 行が UI、下 120 行
> は黒)。720p `1280x720` には戻さないでください。`800x480 native /
> 40 MHz` は Phase 6H で LCD が白画面になった失敗 candidate で、
> 再試行しないでください。
>
> `hw/Pynq-Z2/hdmi_integration.tcl` の v_tc 設定を触る場合の
> gotcha:
> - `CONFIG.VIDEO_MODE {Custom}` と `CONFIG.GEN_VIDEO_FORMAT {RGB}`
>   を 先に `set_property -dict` で適用してください。さもないと
>   `GEN_HACTIVE_SIZE` / `GEN_VACTIVE_SIZE` / `GEN_HSYNC_*` などの
>   per-field 値は `1280x720p` preset によって disabled になり、
>   silently 無視されます。
> - `CONFIG.GEN_F0_VBLANK_HSTART` と `CONFIG.GEN_F0_VBLANK_HEND` は
>   常に `HDMI_ACTIVE_W` を明示設定してください。
> - `CONFIG.GEN_CHROMA_PARITY` は v_tc 6.1 に存在しません。
>
> Deploy / rollback では bit / hwh を **5 か所** 全部同期して
> ください:
> - `/home/xilinx/Audio-Lab-PYNQ/hw/Pynq-Z2/bitstreams/`
> - `/home/xilinx/Audio-Lab-PYNQ/audio_lab_pynq/bitstreams/`
> - `/usr/local/lib/python3.6/dist-packages/audio_lab_pynq/bitstreams/`
> - `/home/xilinx/jupyter_notebooks/audio_lab/bitstreams/`
> - `/home/xilinx/pynq/overlays/audio_lab/`
>   (= `/usr/local/lib/python3.6/dist-packages/pynq/overlays/audio_lab/`)
>
> `bash scripts/deploy_to_pynq.sh` は 5 か所すべてを 1 回で同期
> します。`AudioLabOverlay` は `PYTHONPATH` が解決した
> `audio_lab_pynq` パッケージ直下の bit を読み、`pynq.Overlay(
> "audio_lab")` (bare name) は overlays registry を読みます。
> 1 か所でも古いと、別の copy が新しくても FPGA は古い bit のまま
> になります。配置確認は `v_tc_hdmi GEN_ACTSZ (0x60) == 0x02580320`
> (V=600, H=800) を `AudioLabOverlay()` 構築 **後** に mmio で
> 読んで判定してください (構築前の PL read は kernel を kill
> します、memory `pynq-mmio-before-overlay-kills-kernel`)。

## PYNQ-Z2 DHCP reservation / deploy

> PYNQ-Z2 はルーター DHCP 固定割当で `192.168.1.9` に固定して運用します。
> 実機 eth0 MAC は `00:05:6B:02:CA:04`、Jupyter は
> `http://192.168.1.9:9090/tree`、SSH は `ssh xilinx@192.168.1.9`。
> ルーター管理画面で Device name `PYNQ-Z2`、MAC
> `00:05:6B:02:CA:04`、Reserved IP `192.168.1.9` を登録し、PYNQ を
> 再起動してください。確認は
> `bash scripts/show_pynq_network_info.sh` と
> `ssh xilinx@192.168.1.9 'hostname; ip -br addr'`。
> deploy は通常 `bash scripts/deploy_to_pynq.sh` でよく、必要なら
> `PYNQ_HOST=192.168.1.9 bash scripts/deploy_to_pynq.sh` と明示します。
> 到達不能なら電源、LAN、DHCP固定割当、予約MAC、IP重複を確認してください。

## PYNQ deploy

> deploy は `PYNQ_HOST=192.168.1.9 bash scripts/deploy_to_pynq.sh` を
> 使ってください。実機 Python 実行は
> `sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 ...` を経由
> してください。現行 accepted baseline は D148 (`972d9ba6`、merge
> `96ef899`) です。D135 (`533d5869`、merge `765323b`) は immediate
> rollback baseline です。safe-bypass で
> 高域ノイズが出る bitstream、または
> `TIMING_AND_FPGA_NOTES.md` の D109 CDC 制約を壊した bitstream は
> deploy/accept しないでください。

## Adding a new effect

> 新しいエフェクトを追加するときは、まず
> `docs/ai_context/EFFECT_ADDING_GUIDE.md` の判断フローを読んでくださ
> い。GPIO 設計は固定なので、まず `GPIO_CONTROL_MAP.md` の `reserved`
> 領域 (例: `axi_gpio_distortion.ctrlD[3..5,7]`、
> `axi_gpio_noise_suppressor.ctrlD`、`axi_gpio_eq.ctrlD`) で済ませら
> れるかを確認してください。新規 `axi_gpio_*` 追加は最後の手段で、
> ユーザの明示承認が必要です (`DECISIONS.md` D2 / D11 / D12)。
> Python 側のヘルパは `audio_lab_pynq/control_maps.py` に集約されてい
> ます (pack_u8x4 / set_byte / percent_to_u8 など)。defaults と presets
> は `audio_lab_pynq/effect_defaults.py` /
> `audio_lab_pynq/effect_presets.py`。新エフェクトの仕様は
> `EFFECT_STAGE_TEMPLATE.md` を埋めて記録してください。

## Distortion pedal-mask is shipped — do not roll it back

> 歪みセクションは pedal-mask 方式 (commit `baa97ff` ほか) で実装済み・
> deploy済み・実機確認済みです。全 7 ペダル (`clean_boost` /
> `tube_screamer` / `rat` / `ds1` / `big_muff` / `fuzz_face` /
> `metal`) に Clash ステージが揃っており、bit 7 のみ reserved です。
> 8-way `model_select` 方式へ戻さないでください。新しいペダル / フィルタ
> を追加するときも、巨大 `case` ではなく独立 register-staged ブロックを
> 維持してください。詳細は `docs/ai_context/DISTORTION_REFACTOR_PLAN.md`
> と `DECISIONS.md` の D6 / D8 / D9 を確認してください。

## Tightening WNS

> 現行 accepted D148 build は timing-clean です (overall WNS `+0.526 ns`,
> TNS `0`, WHS `+0.014 ns`, route errors `0`)。
> DSP island は D94 以降 33.33 MHz、fabric は
> 100 MHz のままです。さらに DSP を増やす場合も、`LowPassFir.hs` /
> `AudioLab/` の深い組合せブロックを register で分け、1 段に大きな
> `case` や 4 段以上の演算を詰めない方針は維持してください
> (`TIMING_AND_FPGA_NOTES.md` 参照)。ただし D58-D64 と D109 の反省として、
> WNS 改善だけでは不十分です。safe-bypass と touched model の実音確認も
> acceptance gate です。

## Codec / input debug

> 入力ノイズや DC offset を疑う場合は、`AUDIO_SIGNAL_PATH.md` の
> triage を上から確認してください。ADC HPF は既定 ON
> (`R19_ADC_CONTROL == 0x23`) です。`InputDebug.ipynb` で HPF を
> toggle した直後の peak_abs は IIR 整定中の過渡なので、
> `settling_ms=400` と `discard_initial_frames=2400` を使ってください。

## Documentation update

> `docs/ai_context/` は実装と一緒に更新してください。仕様や運用が
> 変わったら、関連 Markdown を更新するコミットを別に切ってください。
> 触ってよいファイルは `AGENTS.md` / `CLAUDE.md` / `docs/` 配下のみ。
> 実装ファイルや bitstream を巻き込まないでください。

## Historical Phase 7B — PCM1808 / PCM5102 module verification + pin candidate docs

> **履歴プロンプトです。現行 PMOD JB audio は Pmod I2S2 です。**
> Phase 7A / 7B は planning only。実 XDC / block_design / bit / hwh は
> Phase 7C 以降。まず以下を読んでください:
> `docs/ai_context/EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md` (section 11
> = Phase 7B チェックリスト)、`docs/ai_context/IO_PIN_RESERVATION.md`
> (section 4 / 4A = candidate package pin 表)、
> `docs/ai_context/ENCODER_GUI_CONTROL_SPEC.md` (section 7 = encoder
> module 物理確認)、`docs/ai_context/CURRENT_STATE.md` の Phase 7A /
> 7B 節、`DECISIONS.md` D27 ~ D32。
>
> Phase 7B の作業:
> 1. **実モジュール物理確認** (`EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md`
>    section 11.1 / 11.2 と `ENCODER_GUI_CONTROL_SPEC.md` section 7):
>    PCM1808 / PCM5102 / rotary encoder の silkscreen、VCC、I/O
>    level、strap、pull-up を実物 / テスター / 商品ページで埋める。
> 2. **候補 package pin の docs 化** — 既に `IO_PIN_RESERVATION.md`
>    section 4A に PMOD JB (audio 必須) / PMOD JA (audio control) /
>    Raspberry Pi header (encoder + spare、JA と共有しない pin 群) /
>    Arduino header (将来予備) の候補表を作成済み。実モジュール
>    結果で `Status` を更新する。
> 3. 重要: PYNQ-Z2 上で **PMOD JA pin は RPi header GPIO の一部と
>    物理共有** (`IO_PIN_RESERVATION.md` 4.6)。encoder には
>    `raspberry_pi_tri_i_6..24` (= `F19, V10, V8, W10, B20, W8, V6,
>    Y6, B19, U7, C20, Y8, A20, Y9, U8, W6, Y7, F20, W9`) を使う。
> 4. encoder module の `+` ピンを **3.3V に繋ぐ**。5V 禁止
>    (`DECISIONS.md` D31)。pull-up が `+` 経由なら 5V 化で PL pin
>    破損のリスク。
> 5. encoder IP の AXI base address は **TBD** (`DECISIONS.md` D32)。
>    `0x43CE0000` (`axi_vdma_hdmi`) と `0x43CF0000` (`v_tc_hdmi`) は
>    禁止。Phase 7F で確定。
>
> 禁止: `hw/Pynq-Z2/audio_lab.xdc` 変更、`block_design.tcl` 変更、
> `hdmi_integration.tcl` 変更、bit / hwh 再生成、Vivado build、
> ADAU1761 即置換、`git push` / `git pull` / `git fetch`。

## Historical Phase 7C — PCM5102 DAC 出力 prototype (XDC 反映の最初の段階)

> **履歴プロンプトです。現行 build では PCM5102 / PCM1808 path は retired
> で、PMOD JB は Pmod I2S2 が専有します。**
> 前提: Phase 7B のモジュール確認 (`EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md`
> section 11.1 / 11.2) が埋まっていること。
>
> Phase 7C の作業:
> 1. `hw/Pynq-Z2/audio_lab.xdc` に PMOD JB の audio 5 pin を追加
>    (`IO_PIN_RESERVATION.md` section 4A.1 の `W14 / Y14 / T11 /
>    T10 / V16`)。`LVCMOS33`、`create_generated_clock` 含む。
> 2. PS 側または既存 DSP path 経由で I2S sine / sweep を PCM5102 へ送る
>    HDL / Clash プロトタイプ。DSP 本体は変更しない。
> 3. オシロ / ロジアナで `JB2 (BCK = 3.072 MHz)` / `JB3 (LRCK = 48 kHz)` /
>    `JB7 (DIN)` を観測。
> 4. PCM5102 line out を別 audio interface input に取り込んで波形 / SNR
>    測定。
> 5. ADAU1761 path は維持 (`DECISIONS.md` D27)。`audio_lab.bit` の
>    HDMI / DSP / GPIO map は変更しない。
> 6. bit / hwh rebuild + timing summary を確認、deploy band を逸脱しない
>    こと。
>
> 禁止: ADAU1761 即置換、HDMI baseline (SVGA 800x600 @ 40 MHz) 変更、
> DSP / Clash / GPIO map 変更、`git push` / `git pull` / `git fetch`。

## Phase Pmod-clean-fix — mode 2 RIGHT-to-LEFT mirror (branch `feature/pmod-i2s2-dsp-clean-fix`, `DECISIONS.md` D50)

> Pmod I2S2 の mode 2 (ADC → AudioLab DSP → DAC) は D49 で deploy 済だが、
> ユーザー耳確認で「エフェクト全 OFF でも mode 1 と比べて少し歪んで聞こえる」
> 問題が出ていた。D50 は `hw/ip/pmod_i2s2/src/pmod_i2s2_master.v` に
> 32-bit `mode2_right_snapshot` バッファを追加し、`i2s_to_stream` IP の
> RIGHT スロットビットを `bclk_fall_pre`+`bit_idx[5]==1` で snapshot、
> mode 2 では LEFT/RIGHT 両スロットを同じバッファ位置 (slot_idx) で
> 再生する。両耳とも previous-frame RIGHT slot = モノラル、~21 us 遅延、
> 耳には知覚不能。IP の 2 つのバグ ((1) i2sIn の LEFT 抽出が Pmod-master
> deserializer と一致しない、(2) i2sOut が BCLK rising edge で `so` を
> 更新するため DAC が古いビットを latch する 1-BCLK shift) を一度に
> 回避する。`block_design.tcl` / `pmod_i2s2_integration.tcl` / GPIO map /
> Clash / topEntity / HDMI / encoder / notebooks / compact-v2 GUI は
> 一切触っていない。
>
> WNS routed = `-7.985 ns` (D49 `-8.521 ns` から `+0.536 ns` 改善)。
> WHS `+0.050 ns`、THS `0 ns`。Inside `-7..-9 ns` deploy band。
>
> Smoke (deploy 後):
> - mode 1 regression: `scripts/test_pmod_i2s2.py --mode loopback
>   --confirm-loopback --clear --duration 5` → MODE=1、CLIP_COUNT=0、
>   48 kHz lock。耳: clean (mode 2 修正で破壊していない確認)。
> - mode 2 clean: `scripts/diagnose_pmod_i2s2_dsp_clean.py --duration 15`
>   → MODE=2、frame +720,720、CLIP_COUNT=0。**ユーザー耳: mode 1 と
>   同じくクリーン**。
> - mode 2 + Overdrive A/B: `scripts/diagnose_pmod_i2s2_dsp_clean.py
>   --ab-overdrive --duration 6` → Phase A clean → Phase B OD ON
>   (歪み) → Phase C OFF (clean)。**ユーザー耳: ON で歪んで、OFF で
>   クリーンに戻った**。
> - mode 3 mute: PASS。
>
> 既知の制限 / 残課題:
> - mode 2 はモノラル (両耳とも chain RIGHT 出力)。
> - DSP chain は引き続き broken LEFT を入力として処理するが、出力
>   LEFT は DAC に届かない。stereo cross-feed が必要な将来の effect
>   stage では再考が必要。
> - `i2s_to_stream` IP 自体の bug fix は未対応 (今回 scope 外)。
>
> 詳細: `docs/ai_context/PMOD_I2S2_INTEGRATION_PLAN.md` section 18、
> `docs/ai_context/DECISIONS.md` D50、`docs/ai_context/AUDIO_SIGNAL_PATH.md`
> Pmod I2S2 mode 2 段落、`docs/ai_context/TIMING_AND_FPGA_NOTES.md` の
> May 20 D50 行。診断スクリプト:
> `scripts/diagnose_pmod_i2s2_dsp_clean.py`、
> `scripts/diagnose_pmod_i2s2_dma_capture.py`、
> `scripts/diagnose_pmod_i2s2_dma_mode1.py`。

## Phase Pmod-1/2/3 — Pmod I2S2 bring-up (branch `feature/pmod-i2s2-bringup`, `DECISIONS.md` D48)

> Pmod I2S2 module は手元にあり、PMOD JB へ直挿し済。Pmod I2S2 の Line
> Out ↔ Line In は 3.5 mm ステレオケーブルで物理的に loopback 接続済。
> 既存 PCM5102 / PCM1808 のジャンパ配線は外してある前提。
>
> 実装は branch `feature/pmod-i2s2-bringup` にあり、PMOD JB は **Pmod
> I2S2 専用**。PCM5102 / PCM1808 path は retire 済 (`DECISIONS.md` D48):
> - RTL: `hw/ip/pmod_i2s2/src/pmod_i2s2_master.v` (FPGA-master I2S engine、
>   1 kHz sine TX + ADC RX、cfg_mode=0 で TX tone+ADC probe、cfg_mode=1
>   で ADC→DAC loopback)、`hw/ip/pmod_i2s2/src/axi_pmod_i2s2_status.v`
>   (AXI-Lite slave at `0x43D20000`)。
> - 統合: `hw/Pynq-Z2/pmod_i2s2_integration.tcl` を
>   `hw/Pynq-Z2/create_project.tcl` から **無条件に** source。
>   `pcm5102_dac_integration.tcl` / `pcm1808_adc_integration.tcl` は
>   source しない (ファイルは repo に archival で残るが build に
>   投入しない)。
> - XDC: `hw/Pynq-Z2/audio_lab_pmod_i2s2.xdc` (新規) が Pmod I2S2 の
>   8 pin (JB1..JB4 + JB7..JB10) LVCMOS33 制約。`audio_lab.xdc` は
>   ADAU + HDMI + encoder の universal 制約のみ。`audio_lab_pcm.xdc`
>   は archival で load しない。
> - smoke: `scripts/test_pmod_i2s2.py` + `scripts/pmod_i2s2_capture_probe.py`。
>   `pynq.MMIO(phys_addr, 0x10000)` で `pmod_status` を直接開く。
> - live UI: `audio_lab_pynq/notebooks/PmodI2S2EffectControlOneCell.ipynb`
>   (D49 follow-up): 1 セル ipywidgets で mode 2 を default 起動し、
>   全 effect + mode buttons (0/1/2/3) + status panel + Safe clean
>   / Panic mute を提供。`bash scripts/deploy_to_pynq.sh` で配置済、
>   `http://192.168.1.9:9090/tree/audio_lab/PmodI2S2EffectControlOneCell.ipynb`
>   で開いて「Run all」で one-shot。
> - HDMI GUI + encoder live UI:
>   `audio_lab_pynq/notebooks/PmodI2S2HdmiGuiOneCell.ipynb` (D51 follow
>   up). 1 セルで `scripts/run_encoder_hdmi_gui.py --live-apply
>   --skip-rat --pmod-mode dsp` を sudo subprocess として起動し、
>   HDMI GUI + ロータリーエンコーダーで Pmod I2S2 mode-2 audio path
>   を操作する。Stop / Panic-Mute は runner を SIGTERM (runner が
>   shutdown 時に MODE=3 を書く)。Set DSP / Refresh は
>   `scripts/pmod_i2s2_mode.py --mode dsp` / `--read` を subprocess
>   で呼び出す (overlay 再 download なし、codec 再 init なし)。
>   `http://192.168.1.9:9090/tree/audio_lab/PmodI2S2HdmiGuiOneCell.ipynb`
>   で開いて「Run all」で one-shot。
>
> Build + deploy + smoke 手順 (env var は不要):
> ```
> cd hw/Pynq-Z2
> source /home/doi20/vivado/Vivado/2019.1/settings64.sh
> vivado -mode batch -notrace -nojournal \
>     -log vivado.log -source create_project.tcl
> cd ../..
> PYNQ_HOST=192.168.1.9 bash scripts/deploy_to_pynq.sh
>
> # mode 0: internal 1 kHz tone + ADC probe (Line Out -> Line In OK)
> ssh xilinx@192.168.1.9 '
>   cd /home/xilinx/Audio-Lab-PYNQ &&
>   sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
>       scripts/test_pmod_i2s2.py --duration 5 --mode tone --clear
> '
>
> # mode 1: ADC -> DAC direct loopback (NO DSP). The --confirm-loopback
> # flag is REQUIRED; the script refuses mode 1 without it and falls
> # back to mode 0. Disconnect the Line Out <-> Line In jumper first or
> # keep the audio source level minimal to avoid feedback.
> ssh xilinx@192.168.1.9 '
>   cd /home/xilinx/Audio-Lab-PYNQ &&
>   sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
>       scripts/test_pmod_i2s2.py --duration 3 --mode loopback \
>       --confirm-loopback --clear
> '
>
> # mode 2: ADC -> AudioLab DSP -> DAC (D49 + D50 mono RIGHT mirror). The --confirm-dsp flag is
> # REQUIRED; without it the script falls back to mode 0. The DSP chain
> # (Overdrive / Distortion / Compressor / Amp / Cab / Reverb / EQ) is
> # in the audio loop -- disconnect the on-module Line Out <-> Line In
> # jumper before engaging mode 2 and put a real audio source on Line In.
> ssh xilinx@192.168.1.9 '
>   cd /home/xilinx/Audio-Lab-PYNQ &&
>   sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
>       scripts/test_pmod_i2s2.py --duration 3 --mode dsp \
>       --confirm-dsp --clear
> '
>
> # mode 3: mute -- writes 0 to DAC SDIN. Useful while debugging.
>
> # Optional: rolling status counter view
> ssh xilinx@192.168.1.9 '
>   cd /home/xilinx/Audio-Lab-PYNQ &&
>   sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
>       scripts/pmod_i2s2_capture_probe.py --duration 10 --interval 0.5
> '
> ```
>
> 合格判定:
> - Vivado bit/hwh 生成完了 + WNS が `-9.5 ns` を超えない
>   (`TIMING_AND_FPGA_NOTES.md` deploy gate)。
> - PYNQ で `AudioLabOverlay()` load PASS、ADC HPF True、HDMI VTC
>   `GEN_ACTSZ=0x02580320` 維持、encoder VERSION 0x00070001 維持、
>   `pmod_status` VERSION 0x00480001。
> - `test_pmod_i2s2.py` で frame_count 増加 + Line Out → Line In
>   loopback 接続中なら peak_abs_left/right > 0。
> - 任意: `--mode 1` で ADC → DAC 直 loopback (外部音源推奨、自己
>   フィードバック注意)。
>
> 触ってはいけないこと:
> - `hw/Pynq-Z2/block_design.tcl` 直接編集、GPIO_CONTROL_MAP 変更、
>   LowPassFir.hs / topEntity / Clash DSP pipeline 変更。
> - HDMI integration (`hdmi_integration.tcl`)、encoder PL IP
>   (`encoder_integration.tcl`)、compact-v2 GUI、Notebook、
>   encoder runtime、ADAU1761 codec init。
> - 96 kHz 化、stereo DSP 化、PMOD JA / Raspberry Pi header /
>   Arduino header の追加割当。
> - PCM5102 / PCM1808 path の再 enable (D48 で retire 済)。
> - `git push` / `git pull` / `git fetch`。
>
> mode 2 = ADC → DSP → DAC は D49 (branch
> `feature/pmod-i2s2-dsp-path`) で実装済。`pmod_i2s2_integration.tcl`
> が `bclk_1` / `lrclk_1` / `sdata_i_1` を retarget し、
> `i2s_to_stream_0` を Pmod クロックドメインで動かす。AXIS chain と
> 既存 effect GPIO は触っていない。Overdrive ON で peak_abs が ~14k
> から ~46k に上がるのを bench で確認済。
>
> Rollback: `git checkout main` で Phase 7D close-out 構成に戻す。
> 過去 bit を物理 PYNQ に戻したい場合は `git show
> 78ef562:hw/Pynq-Z2/bitstreams/audio_lab.bit > /tmp/old.bit` で
> 取り出して 5 か所に sync。

## Historical Phase Pmod-0 — Pmod I2S2 integration planning (docs only, module not yet delivered)

> **履歴プロンプトです。現行 Pmod I2S2 path は D48 / D49 / D50 で
> 実装・deploy 済みです。** Digilent Pmod I2S2 (CS4344 stereo DAC + CS5343 stereo ADC) を購入済、
> 納品前の **設計フェーズ専用** プラン docs が
> `docs/ai_context/PMOD_I2S2_INTEGRATION_PLAN.md` (Phase Pmod-0 commit)
> 全文 + `DECISIONS.md` D45 にまとまっている。
>
> やってよいこと:
> - docs (上記 plan + CURRENT_STATE / EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN
>   / IO_PIN_RESERVATION / DECISIONS / RESUME_PROMPTS) の修正のみ。
> - Pmod I2S2 公式 reference manual / CS4344 / CS5343 datasheet を
>   参照して section 6 / section 15 の `要確認` 残項目を埋めること。
>   **PMOD JB pin mapping は 2026-05-18 に公式 reference manual で
>   確定済**: Pin 1..4 = D/A MCLK/LRCK/SCLK/SDIN on JB1/JB2/JB3/JB4
>   (`W14 / Y14 / T11 / T10`)、Pin 7..10 = A/D MCLK/LRCK/SCLK/SDOUT
>   on JB7/JB8/JB9/JB10 (`V16 / W16 / V12 / W13`)、Pin 5/11 = GND、
>   Pin 6/12 = VCC 3.3V。再変更しない。
>
> 触ってはいけないこと (Phase Pmod-0 範囲):
> - RTL / XDC / Tcl / Vivado build / bit / hwh / deploy。
> - Python runtime / Notebook / GUI / encoder runtime。
> - HDMI timing (`DECISIONS.md` D25)、encoder pin (`DECISIONS.md` D32 /
>   D34)、PMOD JA、Raspberry Pi header、Arduino header。
> - PCM1808 再有効化 (`CONFIG.CONST_VAL {0}` → `{1}` 凍結維持、
>   `DECISIONS.md` D43)。
> - PCM5102 SCK を MCLK に戻す (`DECISIONS.md` D40 / D42)。
> - ADAU1761 即置換 (`DECISIONS.md` D27)。
> - 96 kHz 化、stereo DSP 化。
> - `git push` / `git pull` / `git fetch`。
>
> Phase Pmod-1 開始トリガー (納品 + checklist):
> 1. Pmod I2S2 module が物理的に手元にある。
> 2. `PMOD_I2S2_INTEGRATION_PLAN.md` section 6 / section 15 の `要確認`
>    残項目 (supply current / line in/out impedance & level / CS4344 /
>    CS5343 strap mode / pop-noise 対策) を CS4344 / CS5343 datasheet
>    + 実機で埋めた。PMOD JB pin mapping (section 10) は 2026-05-18
>    に公式 reference manual で確定済なので再変更不要。
> 3. 既存 PCM5102 / PCM1808 のジャンパ配線を PMOD JB から **物理的に
>    外した**。
> 4. PYNQ-Z2 が boot して `AudioLabOverlay()` が ADC HPF True を返す
>    (Phase 7D close-out bit の健全性確認)。
>
> 全部揃ったら Phase Pmod-1 を別セッションで開始する。Phase Pmod-1 用の
> プロンプトは `PMOD_I2S2_INTEGRATION_PLAN.md` section 16 にある。

## Historical Phase 7C / 7E / 7D — External PCM5102 / PCM1808 audio path (retired)

> **履歴プロンプトです。現行 PMOD JB audio は D48 / D49 / D50 の Pmod
> I2S2 mode 2 (`ADC -> AudioLab DSP -> DAC`) で、PCM5102 / PCM1808 path
> は retired / archival です。**
>
> 外付け PCM5102 DAC + PCM1808 ADC は **Phase 7C / 7E / 7D 当時に実装・
> deploy 済**。PCM5102 は AudioLab DSP 出力の並列ライン
> (`i2s_to_stream_0/so` をそのままミラー) として動作中、PCM1808 は
> build-time 2:1 wire mux + JB8 SCKI まで実装済だが deploy bit は
> `CONFIG.CONST_VAL {0}` (mux=ADAU フォールバック) で出荷中だった。詳細は
> `docs/ai_context/AUDIO_SIGNAL_PATH.md` の "External PCM1808 /
> PCM5102 paths" 節、`EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md`
> section 9、`DECISIONS.md` D38 / D39 / D40 / D41 / D42 / D43 / D44。
>
> 触ってはいけないこと:
> - 現行 build で PCM5102 / PCM1808 path を再 enable する (D48 で retired。
>   Pmod I2S2 と PMOD JB pin が衝突する)。
> - `pcm5102_audio_out.v` の `assign ext_audio_mclk_o = 1'b0;` を外す
>   (D40 / D42、PCM5102 SCK を低位レベル固定する RTL 側保証)。
> - `pcm5102_dac_tone` を再 instantiate する (D39、Phase 7E で
>   `pcm5102_audio_out` に置換済、tone module はデバッグ用に repo に
>   残しているだけ)。
> - `CONFIG.CONST_VAL {0}` を勝手に `{1}` に戻す (D43、PCM1808 ハードウェア
>   診断が完了するまで mux=ADAU 固定)。
> - PCM1808 SCKI を JB1 に戻す (D42、JB1 は構造的に常時 0)。
> - 外付け codec 関連で AXI-Lite slave 追加 / 新 GPIO / `GPIO_CONTROL_MAP`
>   更新 / `topEntity` / `LowPassFir.hs` を触る。
>
> D44 follow-up plan (まだ実装なし):
> 1. mux=ADAU build の時 `ext_pcm1808_sckie_o` を 0 固定にする
>    (`pcm1808_adc_integration.tcl` で build-time `CONST_VAL` に応じて
>    `clk_wiz_audio_ext/clk_out1` か `xlconstant 0` を選ぶ)。Vivado
>    rebuild + timing review が必要。PCM1808 復活時は SCKI 復元を
>    忘れない。
> 2. PCM5102 output に debug mode (`processed audio` / digital silence /
>    `-18 dBFS` 1 kHz tone / ramp) を追加 (`pcm5102_audio_out.v` 付近に
>    小規模 selector を入れる)。LowPassFir には触らない。
> 3. JB1 を "live 12.288 MHz" として説明している残り documents / comments
>    を D42 の現実 (JB1 = 0 固定 / PCM5102 SCK = GND / PCM1808 SCKI = JB8)
>    に揃える。
>
> PCM1808 module 入手 / 修理して再投入する場合は
> `hw/Pynq-Z2/pcm1808_adc_integration.tcl` の `CONFIG.CONST_VAL {0}` を
> `{1}` に戻し、bit/hwh rebuild + deploy、
> `scripts/test_pcm1808_adc_to_pcm5102.py --capture-adc` で `min/max/
> mean/RMS/peak_dBFS` を確認。pure 0 が続く場合は chip / analog 前段の
> 故障 (D43 仮説)。
>
> 禁止: `git push` / `git pull` / `git fetch`、HDMI baseline 変更、
> encoder PL IP 変更、ADAU1761 即置換。

## Phase 7F/7G — Rotary encoder PL IP + Python driver + HDMI GUI (deployed; full physical smoke still open)

> Phase 7F (PL) と Phase 7G (PS) を `feature/rotary-encoder-hdmi-gui-control`
> branch で一括実装済み (`DECISIONS.md` D30 / D31 / D32 / D33 / D34 / D35)。
> local `audio_lab.bit` / `audio_lab.hwh` は更新済み
> (`hw/Pynq-Z2/bitstreams/`)。PYNQ-Z2 (`192.168.1.9`) への deploy と
> overlay/IP/HDMI/codec smoke は実施済み。詳細は
> `docs/ai_context/ENCODER_INPUT_IMPLEMENTATION.md` と
> `docs/ai_context/ENCODER_INPUT_MAP.md`。
>
> やってあること:
> - PL: `hw/ip/encoder_input/src/axi_encoder_input.v` (AXI-Lite
>   + 3 ch quadrature + debounce + delta + event)、
>   `hw/Pynq-Z2/encoder_integration.tcl`、`audio_lab.xdc` の 9 pin
>   追加、`create_project.tcl` への source 追加。
> - PS: `audio_lab_pynq/encoder_input.py`、`audio_lab_pynq/encoder_ui.py`、
>   `GUI/compact_v2/state.py` / `renderer.py` の focus state、
>   standalone `scripts/run_encoder_hdmi_gui.py`、smoke
>   `scripts/test_encoder_input.py` / `scripts/test_hdmi_encoder_gui_control.py`、
>   `audio_lab_pynq/notebooks/EncoderGuiSmoke.ipynb`、
>   オフライン unit tests (30 件)。
> - PYNQ Python 3.6 compatibility: `from __future__ import annotations`,
>   `dataclasses`, `typing.Literal` を encoder runtime path から除去。
>   `EncoderInput.from_overlay()` は PYNQ runtime key `enc_in_0/s_axi`
>   を発見し、bare `enc_in_0` hierarchy object を MMIO と誤認しない
>   (`DECISIONS.md` D36)。
> - Deploy helper: `scripts/deploy_to_pynq.sh` は `GUI/compact_v2` を
>   含めるため `GUI/` を recursive rsync する。`GUI/README.md` と
>   `GUI/fx_gui_state.json` は除外したまま。
> - Vivado build3:
>   `/tmp/fpga_guitar_effecter_backup/phase7f7g_vivado_build3.log`。
>   `write_bitstream completed successfully`。Final routed timing:
>   WNS `-8.395 ns`, TNS `-6609.224 ns`, WHS `+0.052 ns`,
>   THS `0.000 ns`。Utilization: LUT `19095`, Registers `21259`,
>   BRAM Tile `9`, DSP `83`。
> - HWH: `enc_in_0` / `axi_encoder_input` at `0x43D10000..0x43D1FFFF`。
>   HDMI `axi_vdma_hdmi=0x43CE0000` / `v_tc_hdmi=0x43CF0000` and
>   existing effect GPIO addresses are unchanged.
> - PYNQ smoke result: `AudioLabOverlay()` loads, ADC HPF `True`,
>   `R19=0x23`, encoder `ip_dict` key `enc_in_0/s_axi`,
>   `VERSION=0x00070001`, `CONFIG=0x00010105`, HDMI VDMA/VTC present,
>   VTC `GEN_ACTSZ=0x02580320`.
> - On-board HDMI synthetic smoke passed with
>   `scripts/test_hdmi_encoder_gui_control.py` and `vdma_dmasr=0x00011000`.
> - On-board real GUI loop started/stopped with
>   `scripts/run_encoder_hdmi_gui.py --fps 2 --hold-seconds 10`;
>   VDMA/VTC stayed normal and encoder 1/2 rotate events were observed.
>
> 残作業:
> 1. Low-level 60 s smoke は VERSION / CONFIG / idle read まで PASS したが、
>    その run では rotate / SW event は 0 件だった。Jupyter
>    `EncoderGuiSmoke.ipynb` または SSH で、ユーザが実際に 3 encoder
>    すべてを回して `ENC0/1/2` rotate、short_press、long_press、
>    release、チャタリングを確認する。
> 2. 方向が逆なら `reverse_direction`、CLK/DT が物理的に逆なら
>    `clk_dt_swap`、チャタリングが目立つなら `debounce_ms` を Notebook
>    または script 引数で調整し、最終設定を docs に記録する。
> 3. Full standalone operation は `DECISIONS.md` D35 の条件を満たすまで
>    成功扱いにしない。現在確認済みなのは deploy / IP presence /
>    register read / synthetic HDMI GUI / real HDMI loop partial
>    (encoder 1/2 rotate observed) まで。
>
> 禁止: PMOD JB / PMOD JA に encoder pin を割り当てる (`DECISIONS.md`
> D28 / D34 違反、PCM1808 / PCM5102 予約)、PS polling で raw CLK/DT/SW
> を読む (`DECISIONS.md` D30 違反)、encoder bit を `axi_gpio_*` に
> 混ぜる (`DECISIONS.md` D33 違反)、`+` を 5V に繋ぐ (`DECISIONS.md`
> D31 違反 / PL pin 破損リスク)、ADAU1761 / HDMI / DSP 経路の改変、
> `git push` / `git pull` / `git fetch`。

## Phase D58.2 — Balanced Amp Drive Mode saturation, fixed-scalar retake (historical)

> 続きを始める前に `git status --short` と
> `git log -8 --oneline --decorate --graph` を実行し、
> `main` (merge `7ba801f` "Merge feature/amp-drive-mode-balanced-gain-v2
> into main") か `feature/amp-drive-mode-balanced-gain-v2`
> (`f9b8759` "Add balanced amp drive mode saturation (fixed-scalar
> retake)") にいることを確認してください。
>
> 構成 (実装済 / deploy 済 / 耳確認済):
> - D55 の 6-model 構造 (`JC-120 / Twin Reverb / AC30 / Rockerverb /
>   JCM800 / TriAmp Mk3`) と `ctrlD[7] = ampDriveMode` /
>   `ctrlD[6:3] = 0` / `ctrlD[2:0] = ampModelIdx` の bit-pack、
>   `softClipK 3_300_000 / 3_400_000` safety、second-stage
>   `intensity = ampCharForModel idx >> 1` (half intensity) は **完全に
>   D55 と同一**。
> - `Amp.hs` の Drive 係数だけを D55 から再調整:
>     - `ampDrivePosDelta` (`Unsigned 3 -> Signed 25`): `13_000 /
>       58_000 / 130_000 / 210_000 / 264_000 / 336_000`
>     - `ampDriveNegDelta` (`Unsigned 3 -> Signed 25`): `11_000 /
>       50_000 / 113_000 / 180_000 / 231_000 / 300_000`
>     - `ampSecondStageDriveBonus`: `14 / 18 / 28 / 42 / 48 / 56`
>     - `ampPreLpfDriveDarken`: `5 / 7 / 10 / 16 / 16 / 24`
>   `ampAsymClip` の signature は **D55 と同じ** (`Unsigned 3 ->
>   Unsigned 8 -> Bool -> Sample -> Sample`)、Drive delta 引数は
>   `modelIdx` のみ (D58 の `ch` 追加引数 は採用しない)。
> - **重要な失敗教訓: D58 (`feature/amp-drive-mode-balanced-gain`,
>   `797467c`) は `ch * factor` 比例型 Drive delta で DSP 数を
>   83 → 87 に増やし、Vivado P&R が ADC→DAC bypass 経路に高音域
>   飽和ノイズを乗せた (Amp OFF / 全 effect_on=False でも audible)。
>   D58.2 は fixed scalar で DSP 数を 83 (D55 と同一) に戻して
>   regression を回避**。
> - bit/hwh sha `93f31348...` / `25991dc0...` を 5-site sync で
>   PYNQ-Z2 192.168.1.9 に deploy 済 (`hw/Pynq-Z2/bitstreams/`,
>   repo `audio_lab_pynq/bitstreams/`, site-packages
>   `audio_lab_pynq/bitstreams/`, `pynq/overlays/audio_lab/`,
>   `jupyter_notebooks/audio_lab/bitstreams/`)。
> - timing: WNS `-8.495 ns` (D55 比 -0.264 ns、deploy 帯内)、
>   WHS `+0.051 ns`、THS `0 ns`、DSP `83 / 220 (37.73 %)`。
> - smoke: ADC HPF True、6 model ctrlD readback OK、Pmod mode
>   0/1/2/3 readback OK、safe bypass + mode-2 DSP 3 s CLIP_COUNT = 0、
>   TriAmp Mk3 + Drive 3 s CLIP_COUNT = 0、GUI 起動例外無し。
>   **耳確認 PASS** ("D58 のような高音域飽和ノイズは消えた")。
>
> やってよい変更: Python / GUI / Notebook / docs / tests / 必要なら
> 最小の Clash DSP 追修正 + Vivado 再ビルド + deploy + 実機 smoke。
> 禁止: D58 の `ch * factor` Drive delta を復活させる (DSP+4 →
> bypass 経路 P&R regression)、D57 の `ampInputDriveGainBonus` /
> pre-clip push / second clip stage full intensity / `ch * 5000+`
> 多項係数を採用する、新規 AXI GPIO、`block_design.tcl` 変更、
> `axi_gpio_amp_tone` address 変更、`amp_character` 連続ノブの
> UI 復活、Clean/Drive 分岐の削除、モデル差を音量差だけで作ること、
> HDMI / encoder / Pmod I2S2 path 改変、
> `git push` / `git pull` / `git fetch`。
>
> 失敗時の rollback: PYNQ bit/hwh を D55 (`8df39b06...` /
> `9fb470c7...`) に 5-site sync で戻すだけで audio がクリーン状態に
> 戻る (Vivado 再ビルド不要)。`git show 314b7c6:hw/Pynq-Z2/
> bitstreams/audio_lab.bit > /tmp/d55.bit` で抽出可能。

## Phase D55 — Replace Amp Sim model set with six researched amp voicings (superseded by D58.2)

> 続きを始める前に `git status --short` と
> `git log -8 --oneline --decorate --graph` を実行し、
> `feature/replace-amp-models-six-pack-researched` (または merge 後の main)
> で `hw/ip/clash/src/AudioLab/Effects/Amp.hs` の `ampModelIdxF` が
> `Unsigned 3` (slice `d26 d24`) になっていることを確認してください。
>
> 構成 (実装済):
> - 旧 D52 4 モデル (`jc_clean / clean_combo / british_crunch /
>   high_gain_stack`) は退役。新 D55 6 モデル:
>     `0 = JC-120` / `1 = Twin Reverb` / `2 = AC30` /
>     `3 = Rockerverb` / `4 = JCM800` / `5 = TriAmp Mk3`
>   各モデルの音響特徴・DSP 係数根拠は
>   `docs/ai_context/AMP_MODEL_RESEARCH_D55.md` を参照。
> - `axi_gpio_amp_tone.ctrlD` の model field は 2-bit から 3-bit に拡張:
>     `ctrlD[7] = ampDriveMode` (0=Clean, 1=Drive),
>     `ctrlD[6:3] = 0` reserved,
>     `ctrlD[2:0] = ampModelIdx` (0..5 valid; 6..7 は Clash 側で
>     0 = JC-120 にフォールバック (clip_count 暴走防止))。
> - Python: `AudioLabOverlay.amp_model_drive_byte(idx, drive)` で
>   `AMP_MODEL_IDX_MASK = 0x07`, `AMP_MODEL_IDX_MAX = 5`。
>   `amp_character_byte_for_model` は同義エイリアス。
> - Clash: `Amp.hs` に 6 モデル分の voicing 係数テーブル
>   (`ampModelDarken`, `ampPreLpfDriveDarken`,
>   `ampSecondStageDriveBonus`, `ampDrivePosDelta`,
>   `ampDriveNegDelta`, `ampTrebleGain` 6-entry case,
>   `presenceTrim` 6-entry case)。`ampAsymClip` シグネチャは
>   `Unsigned 3 -> Unsigned 8 -> Bool -> Sample -> Sample` (model
>   idx を取って per-model knee delta を引く)。`softClipK
>   3_300_000 / 3_400_000` safety stage は据置。
> - Compact-v2 GUI / HDMI mirror / encoder runtime / 3 notebooks
>   (`PmodI2S2EffectControlOneCell.ipynb`,
>   `GuitarPedalboardOneCell.ipynb`, `HdmiGuiShow.ipynb`) 更新。
>   旧 snake_case helper (`mirror.jc_clean()` 等) は alias として残置 →
>   `jc_clean -> jc_120`, `clean_combo -> twin_reverb`,
>   `british_crunch -> ac30`, `high_gain_stack -> jcm800`。
> - tests: `python3 tests/test_overlay_controls.py` PASS,
>   `python3 -m unittest -v tests.test_encoder_*
>   tests.test_overdrive_model_select tests.test_hdmi_selected_fx_state`
>   PASS (90 + 3 件 D55 ケース追加)。`tests.test_hdmi_origin_mapping`
>   の import error は pre-existing。
>
> やってよい変更: Python / GUI / Notebook / docs / tests / 必要なら
> 最小の Clash DSP 追修正 + Vivado 再ビルド + deploy + 実機 smoke。
> 禁止: 新規 AXI GPIO、`block_design.tcl` 変更、`axi_gpio_amp_tone`
> address 変更、`amp_character` 連続ノブの UI 復活、D54 Clean/Drive
> 分岐の削除、モデル差を音量差だけで作ること、HDMI / encoder /
> Pmod I2S2 path 改変、`git push` / `git pull` / `git fetch`。

## Phase D54 — Amp Sim Clean/Drive becomes a real Clash DSP branch (superseded by D55)

> 続きを始める前に `git status --short` と
> `git log -8 --oneline --decorate --graph` を実行し、
> `feature/amp-clean-drive-dsp-mode` (または merge 後の main) で
> `hw/ip/clash/src/AudioLab/Effects/Amp.hs` に `ampModelIdxF` /
> `ampDriveModeF` / `ampCharForModel` があることを確認してください。
>
> 構成 (実装済):
> - `axi_gpio_amp_tone.ctrlD` は D54 で bit-pack:
>   `ctrlD[7] = ampDriveMode` (0=Clean, 1=Drive),
>   `ctrlD[6:2] = 0` reserved,
>   `ctrlD[1:0] = ampModelIdx` (0..3 = jc_clean / clean_combo /
>   british_crunch / high_gain_stack)。
> - Python: `AudioLabOverlay.amp_model_drive_byte(amp_model_idx,
>   amp_drive_mode) = ((mode & 1) << 7) | (idx & 0x03)`。
>   D53 名 `amp_character_byte_for_model` は同義のエイリアスとして
>   残置。D53 の in-band `+30` シフトは廃止 (`AMP_DRIVE_MODE_OFFSET = 0`)。
> - Clash: `Amp.hs` が `ctrlD` を bit-decode し、`ampAsymClip
>   intensity drive x` が Drive モードで knee を `ch * 2_000 /
>   ch * 1_800` だけ追加で縮め、負側の post-knee shift を `>> 3 → >> 2`
>   に切替。`ampPreLowpassFrame` が `-12` alpha 追加、
>   `ampSecondStageMultiplyFrame` が `+24` gain bonus 追加。
>   `softClipK 3_300_000 / 3_400_000` の safety stage は据置で
>   clip_count の暴走を防止。
> - `ampModelSel :: Unsigned 8 -> Unsigned 2` は廃止 (model idx が
>   ctrlD[1:0] から直接得られるため不要)。
> - Compact-v2 GUI / encoder runtime / HDMI mirror / D53 Notebook UI
>   は D53 のまま (`amp_model_idx + amp_drive_mode` を渡す)。
> - Clash → VHDL → IP package → Vivado batch build → bit/hwh 5 箇所
>   sync → deploy_to_pynq.sh まで完了。
> - Tests: 87 + 5 件 PASS (`tests.test_overlay_controls` に D54
>   ケース追加; D53 の in-band-shift ケースは置換);
>   pre-existing `tests.test_hdmi_origin_mapping` は無関係。
>
> やってよい変更: Python / GUI / Notebook / docs / tests / 必要なら
> 最小の Clash DSP 追修正 + Vivado 再ビルド。
> 禁止: 新規 AXI GPIO、`block_design.tcl` 変更、`axi_gpio_amp_tone`
> address 変更、`amp_character` の UI 復活、Drive モードを音量差だけ
> で再実装、HDMI / encoder / Pmod I2S2 path 改変、
> `git push` / `git pull` / `git fetch`。

## Phase D53 — Amp Sim model-only character + binary DRV MODE (historical)

> 続きを始める前に `git status --short` と
> `git log -8 --oneline --decorate --graph` を実行し、
> `feature/amp-model-only-drive-mode` (または merge 後の main) で
> `audio_lab_pynq/AudioLabOverlay.py` の `AMP_MODEL_CHARACTER_BYTES`
> と `amp_character_byte_for_model` が存在することを確認してください。
>
> 構成 (実装済):
> - Amp Sim の 8 個目ノブは連続 `CHAR` から 0/1 の `DRV MODE` に置換
>   (`GUI/compact_v2/knobs.py` 7-th slot, `BINARY_KNOBS` 集合の
>   `("Amp Sim", 7)`)。character byte は `amp_model_idx` のみから
>   決まり (`AMP_MODEL_CHARACTER_BYTES = (26, 89, 153, 216)`)、
>   `amp_drive_mode=1` のときバンド内で `+30` シフト
>   (`AMP_DRIVE_MODE_OFFSET`)。`amp_drive_mode=0` は D52 以前と
>   byte-for-byte 同一なので bitstream / Vivado / Clash 変更なし。
> - `set_guitar_effects(amp_model_idx=…, amp_drive_mode=0|1)` を
>   受け取り、`amp_model_idx is not None` のときは
>   `amp_character` percent kwarg より優先する。
>   `amp_character` は chain preset / 旧 Notebook 経路の
>   フォールバックとして残置。
> - `AppState.amp_drive_mode` (0/1) を永続フィールドとして追加。
>   `set_knob` は `("Amp Sim", 7)` を binary clamp し、レガシー
>   state.json (slot 7 に連続 CHAR 値) は >=50% で 1 に snap して
>   AppState を migrate する。
> - Encoder 2 は binary knob で delta 符号 → 0/1 toggle、live apply
>   を強制発火 (value\_step 累積なし)。continuous knob は従来通り。
> - HDMI GUI renderer は binary knob の値表示を 0/1 に、bar segment を
>   value=1 で全点灯に切替 (`GUI/compact_v2/renderer.py`)。
> - `EncoderEffectApplier.apply_appstate` は `amp_model_idx` +
>   `amp_drive_mode` を forward。`amp_character` は forward しない。
> - `HdmiEffectStateMirror._apply_guitar_effects_state` は
>   `amp_drive_mode` を AppState と slot 7 へ mirror。
> - Notebook: `PmodI2S2EffectControlOneCell.ipynb` /
>   `GuitarPedalboardOneCell.ipynb` の AMP セクションから連続
>   Character slider を削除し、`DRV MODE` Dropdown (0/1) を追加。
>   `safe_clean` / `panic_mute` / `all_effects_off` は
>   `amp_drive_mode = 0` を維持。
> - Tests: 87 PASS (`test_encoder_input_decode` + `test_encoder_ui_controller`
>   + `test_compact_v2_encoder_state` + `test_encoder_effect_apply`
>   + `test_overdrive_model_select`); `tests/test_overlay_controls.py`
>   PASS (新規 D53 ケース含む); pre-existing
>   `tests.test_hdmi_origin_mapping` の import error は本パスとは無関係。
>
> やってよい変更: Python / GUI / Notebook / docs / tests のみ。
> 禁止: bit / hwh / XDC / RTL / block\_design / create\_project /
> `LowPassFir.hs` の D53 非関連改変、Vivado build、新規 AXI GPIO、
> `axi_gpio_amp_tone` の address 変更、`amp_character` を UI に
> 再露出すること、`AMP_DRIVE_MODE_OFFSET` を変更して既存バンドを
> 越境させること、`git push` / `git pull` / `git fetch`。

## Phase 7G+ — GUI-first encoder live apply (current runtime pattern)

> 続きを始める前に `git status --short` と
> `git log -8 --oneline --decorate --graph` を実行し、
> `feature/encoder-gui-real-effect-control` (または merge 後の main) で
> `audio_lab_pynq/encoder_effect_apply.py` が存在することを確認してください。
>
> 構成 (実装済):
> - `EncoderEffectApplier` (Phase 7G+ 新規) が AppState →
>   `AudioLabOverlay` public API の唯一の経路。
>   `set_noise_suppressor_settings` / `set_compressor_settings` /
>   `set_guitar_effects(**kwargs)` のみ呼ぶ。raw GPIO 書き込みなし。
> - `EncoderUiController` に `applier=` / `live_apply=` / `skip_rat=`
>   を追加。encoder3 short press は throttle を bypass して force apply、
>   encoder3 rotate は live\_apply=True のとき throttled
>   `apply_appstate` を呼ぶ。現行 runner 既定は 20 ms
>   (`--apply-interval-ms 20`)。`EncoderEffectApplier` class 単体の
>   fallback default は 100 ms。
> - RAT (`distortion_pedal_mask` bit 2) は `skip_rat=True` (default) で
>   encoder cycle / live apply の対象から除外。Clash / Notebook mirror は
>   手付かず。
> - `scripts/run_encoder_hdmi_gui.py` は dirty-flag loop + applier 構成。
>   CLI に `--live-apply` / `--no-live-apply` /
>   `--apply-interval-ms` / `--value-step` / `--skip-rat` /
>   `--include-rat` / `--no-audio-apply` / `--dry-run` /
>   `--poll-hz-active` / `--poll-hz-idle` / `--idle-threshold-s` /
>   `--max-render-fps` / `--status-interval-s` を追加。
> - `audio_lab_pynq/notebooks/EncoderGuiSmoke.ipynb` は 1 セル維持で、
>   GUI 操作 + resource print + live apply に置き換え済 (raw register
>   dump や synthetic AppState テストは削除)。
> - GUI 表示: `AppState.live_apply` / `last_apply_ok` /
>   `last_apply_message` / `last_unsupported_label` を追加。renderer の
>   bottom-right status strip は `LIVE` / `OK` / `ERR` / `RAT?` /
>   `UNSUP` を `last_control_source == "encoder"` の時に表示。
>   `state_semistatic_signature` も拡張済 (cache がスタックしない)。
> - Tests: `tests/test_encoder_effect_apply.py` (11)、
>   `tests/test_encoder_ui_controller.py` (23)、
>   `tests/test_compact_v2_encoder_state.py` (5)、
>   `tests/test_encoder_input_decode.py` (13) = 52 件 PASS。
>
> やってよい変更: Python / GUI / Notebook / docs のみ。
> 禁止: bit / hwh / XDC / RTL / block\_design / create\_project /
> encoder\_integration / hdmi\_integration の変更、Vivado build、
> PMOD JA/JB pin assign、raw GPIO write、`base.bit` ロード、
> `AudioLabOverlay` 後の別 Overlay ロード、RAT を encoder 操作対象に
> 戻すこと、`EncoderGuiSmoke.ipynb` を複数セル化すること、
> `git push` / `git pull` / `git fetch`。

## Phase 7G — Python encoder driver + GUI focus state (superseded by deployed Phase 7F/7G block above)

> 旧 Phase 7G prompt の実装項目は `c7a8680` と follow-up deploy smoke
> で完了済み。現在使う実機確認 surface は
> `audio_lab_pynq/notebooks/EncoderGuiSmoke.ipynb`、
> `scripts/test_encoder_input.py`、
> `scripts/test_hdmi_encoder_gui_control.py`、
> `scripts/run_encoder_hdmi_gui.py`。
>
> 次に必要なのは新規 driver 実装ではなく、3 encoder すべての
> rotate / short / long / release を実操作で記録し、
> reverse/swap/debounce の最終設定を docs に反映すること。
>
> 禁止: `GUI/pynq_multi_fx_gui.py` shim の巨大化 (`DECISIONS.md`
> D26)、`audio_lab_pynq/hdmi_effect_state_mirror.py` shim の巨大化、
> HDMI baseline (SVGA 800x600 @ 40 MHz) 変更、ADAU1761 経路の改変、
> `git push` / `git pull` / `git fetch`。

## Older phase prompts (history)

Per-phase resume prompts for the HDMI GUI Phase 1 -- Phase 6H arc
and for each DSP / Notebook deploy (LowPassFir split, reserved-pedal
implementation, Amp Simulator named models, Amp Simulator fizz-control
pass, audio-analysis voicing fixes, Noise Suppressor work, Compressor
work, Chain presets work, real-pedal voicing pass, Amp/Cab
real-voicing pass, Notebook UI / preset polish, internal mono DSP
pipeline) live in
[`RESUME_PROMPTS_HISTORY.md`](RESUME_PROMPTS_HISTORY.md). They are
kept verbatim for the case where a future agent is asked to revisit
or extend one of those efforts; they are **not** required reading
for a generic resume.
