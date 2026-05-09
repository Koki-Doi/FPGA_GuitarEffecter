# Resume prompts

Short prompts the user can paste back to either Claude Code or Codex
after a rate-limit, context reset, or session restart. Each one is
self-contained and points the agent at the right docs instead of
asking it to re-discover the project from scratch.

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

## LowPassFir split refactor — local build complete, deploy pending

> `feature/split-lowpassfir-behavior-preserving` では
> `LowPassFir.hs` を挙動不変で `AudioLab.Types` / `FixedPoint` /
> `Control` / `Axis` / `Effects.*` / `Pipeline` に分割しました。
> `LowPassFir.hs` には Vivado-visible な `topEntity` と annotation だけを
> 残しています。DSP 係数、bit 幅、pipeline 順、`Frame` shape、
> `topEntity` port、`block_design.tcl`、GPIO、Python API、Notebook UI、
> Chain Preset は変更していません。Clash type check / VHDL生成、
> IP repackage、Vivado bit/hwh rebuild は完了し、timing は
> WNS=-8.022 ns / TNS=-13937.512 ns / WHS=+0.052 ns / THS=0.000 ns
> で前回 deploy baseline と同値です。local Python tests と Notebook
> JSON checks も pass 済み。`PYNQ_HOST=192.168.1.9` で deploy 済みで、
> smoke test では ADC HPF=True / R19=0x23 / delay_line gpio False /
> legacy axi_gpio_delay True / amp models / 指定 chain preset を確認済みです。

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

## Reserved-pedal implementation — shipped

> `ds1` (bit 3), `big_muff` (bit 4), `fuzz_face` (bit 5) は
> 専用 Clash ステージとして実装済み・deploy 済み。
> `LowPassFir.hs` の `ds1HpfFrame -> ds1MulFrame -> ds1ClipFrame ->
> ds1ToneFrame -> ds1LevelFrame`、`bigMuffPreFrame ->
> bigMuffClip1Frame -> bigMuffClip2Frame -> bigMuffToneFrame ->
> bigMuffLevelFrame`、`fuzzFacePreFrame -> fuzzFaceClipFrame ->
> fuzzFaceToneFrame -> fuzzFaceLevelFrame` が `fxPipeline` で
> `metalLevelPipe` の後ろに連結され、`distortionPedalsPipe =
> fuzzFaceLevelPipe`。各ペダルは独立 enable で OFF 時 bit-exact bypass。
> 新規 GPIO / `topEntity` ポート / `block_design.tcl` 変更なし。
> 実装当時の WNS / deploy 結果は `TIMING_AND_FPGA_NOTES.md` を参照。
> 8-way `model_select` mux 構造へは絶対に戻さないこと
> (`DECISIONS.md` D6 / D9)。voicing 微調整は `LowPassFir.hs` の
> 該当ブロックの定数 / clip helper だけを編集する形で行うこと
> (`REAL_PEDAL_VOICING_TARGETS.md` の運用と同じ)。
> 商用ペダル / GPL DSP のソースコードコピーは禁止。8th pedal slot
> (bit 7) は引き続き reserved。

## Tightening WNS

> 現状 deploy 済の WNS = -8.731 ns (audio-analysis voicing fixes
> ビルド) はベースライン同等で、運用上は動いていますが厳密には
> まだ負です。これを 0 へ寄せたい場合は、`LowPassFir.hs` の中で
> 残った深い組合せブロックを register で分け、必要なら cab タップ
> や reverb BRAM のアドレス経路を pipeline 化してください。1 段に
> 大きな `case` や 4 段以上の演算を詰めない方針は維持してください
> (`TIMING_AND_FPGA_NOTES.md` 参照)。

## Amp Simulator named models — deployed

> Amp Simulator に 4 つの named voicing (`jc_clean` / `clean_combo` /
> `british_crunch` / `high_gain_stack`) を追加しました。新エフェクト
> ではなく、既存 `amp_character` byte に意味付けする convenience レイヤ
> です。`LowPassFir.hs` には `ampModelSel :: Unsigned 8 -> Unsigned 2`
> ヘルパを追加し、`ampPreLowpassFrame` の baseAlpha (`128 + ch>>2`) から
> band 別に高域を darken します。初回 named-model build は
> `0/2/8/16` でしたが、後続の fizz-control pass で `0/4/12/24` に
> 更新済みです (high-gain stack ほど強く)。他の amp ステージは既存連続
> カーブのまま。商用アンプ回路 /
> IR / 係数のコピーなし、GPL DSP コードのコピーなし。
> Python: `audio_lab_pynq.effect_defaults.AMP_MODELS = {jc_clean: 10,
> clean_combo: 35, british_crunch: 60, high_gain_stack: 85}`。
> `AudioLabOverlay.set_amp_model(name, **overrides)` は
> `set_guitar_effects(amp_character=AMP_MODELS[name], ...)` への薄い
> ラッパーで、`amp_character` 数値指定はそのまま動作。
> `GuitarPedalboardOneCell.ipynb` の Amp Simulator アコーディオンに
> Amp Model dropdown を追加 (Character スライダーは残す)。
> 新規 GPIO / `topEntity` port / `block_design.tcl` 変更なし。
> 8-way `model_select` / 巨大 case 構造には戻していません
> (`DECISIONS.md` D6 / D18)。bit/hwh rebuild と PYNQ deploy 済み。
> timing 結果は `TIMING_AND_FPGA_NOTES.md` を参照。

## Amp Simulator fizz-control pass — deployed

> Amp Simulator の高域 fizz 対策は `feature/amp-sim-fizz-control` で
> 実装済み・deploy 済みです。対象は DSP 内部の Amp Sim 高域だけで、
> 入力→バイパス差、codec/I2S/hardware 経路、ノイズ床、解析ツール、
> test signal 生成、Cab Sim 大規模再設計は対象外です。
> `LowPassFir.hs` では既存 Amp stage のみを retune:
> `ampPreLowpassFrame` の per-model darken を `0/2/8/16` から
> `0/4/12/24` へ、`ampTrebleGain character treble` で高域戻しを
> model 別 trim (`0/2/5/9`) 付きに、`ampResPresenceProductsFrame` で
> presence trim (`0`, `p>>5`, `p>>4`, `p>>3`) を追加、`ampPowerFrame` /
> `ampResPresenceMixFrame` の `softClipK` knee を `3_500_000` から
> `3_400_000` へ変更。新規 GPIO / `topEntity` port /
> `block_design.tcl` 変更なし、Delay line 実装なし、
> `axi_gpio_delay_line` なし、legacy `axi_gpio_delay` は維持。
> Compressor / Noise Suppressor / Reverb / Delay / Distortion /
> Overdrive / Cab IR は触っていません。
> timing は WNS=-8.022 ns、TNS=-13937.512 ns、WHS=+0.052 ns、
> THS=0.000 ns。前回 audio-analysis baseline WNS=-8.731 ns から
> +0.709 ns 改善。PYNQ smoke test で ADC HPF=True / R19=0x23 /
> delay_line gpio False / legacy axi_gpio_delay True / 4 amp model /
> 指定 chain preset を確認済み。商用 amp 回路/IR/係数や GPL code は
> コピーしていません。詳細は `DECISIONS.md` D20 と
> `TIMING_AND_FPGA_NOTES.md` を参照。

## Audio-analysis voicing fixes — deployed

> 録音解析に基づく voicing fixes は
> `feature/audio-analysis-voicing-fixes` で実装済み・deploy 済みです。
> 新エフェクト追加ではなく、`LowPassFir.hs` の既存 stage だけを調整
> しています。主な変更は Compressor (`compThresholdSample`,
> `compEnvNext`, `compTargetGain`, `compGainNext`)、Overdrive
> (`overdriveDriveMultiplyFrame`, `overdriveDriveClipFrame`,
> `overdriveLevelFrame`)、Amp (`ampDriveMultiplyFrame`,
> `ampPreLowpassFrame`, `ampToneProductsFrame` / `ampTrebleGain`,
> `ampPowerFrame`, `ampResPresenceProductsFrame` /
> `ampResPresenceMixFrame`, `ampMasterFrame`)、Cab (`cabCoeff`)。
> `cabLevelMixFrame` は timing のため既存 `softClip` のままです。
> DS-1 Crunch preset は Cab model 2 / capped air に寄せました。
> 新規 GPIO / `topEntity` port / `block_design.tcl` 変更なし、Python API
> / Notebook UI 変更なし。bit/hwh rebuild と PYNQ deploy 済み。
> timing は WNS=-8.731 ns、TNS=-13665.555 ns、WHS=+0.051 ns、
> THS=0.000 ns。ADC HPF=True / `R19_ADC_CONTROL=0x23`、preset smoke
> test pass。商用 IR / 回路 / GPL DSP コードはコピーしていません。
> 根拠は `AUDIO_RECORDING_ANALYSIS.md`、決定は `DECISIONS.md` D17。

## Noise Suppressor work — branch in progress / shipped

> Noise Suppressor は専用 GPIO `axi_gpio_noise_suppressor` (`0x43CC0000`)
> 経由で THRESHOLD / DECAY / DAMP / mode を持ち、Clash 側で envelope +
> smoothed-gain 段に置き換え済み (`fxPipeline` の `nsLevelPipe ->
> nsEnv -> nsGain -> nsPipe`)。enable は引き続き `gate_control` bit 0
> (legacy `noise_gate_on`)。Python API は
> `set_noise_suppressor_settings(threshold=, decay=, damp=, enabled=,
> mode=)` / `get_noise_suppressor_settings()`、threshold byte は
> `round(threshold * 255 / 1000)` (新スケール: 100 ≡ 旧 10)。
> `set_guitar_effects(noise_gate_threshold=...)` も新スケール。互換
> として legacy `gate_control.ctrlB` にも同じ byte を書く (新ビットで
> は dead)。RNNoise / FFT / spectral 系は採用していない。BOSS NS-2 /
> NS-1X は思想のみ参考、コードコピーなし。詳しくは
> `docs/ai_context/DECISIONS.md` D11 / `DSP_EFFECT_CHAIN.md` Noise
> Suppressor 節 / `GPIO_CONTROL_MAP.md` Noise Suppressor 節を参照。
> 既存 distortion pedal-mask 実装と
> `GuitarPedalboardOneCell.ipynb` の他セクションは触らないでください。

## Compressor work — branch in progress / shipped

> Compressor は専用 GPIO `axi_gpio_compressor` (`0x43CD0000`) 経由で
> THRESHOLD / RATIO / RESPONSE / enable+MAKEUP を持ち、Clash 側で
> stereo-linked feed-forward peak compressor 段
> (`fxPipeline` の `compLevelPipe -> compEnv -> compGain ->
> compApplyPipe -> compMakeupPipe`) を Noise Suppressor の直後・
> Overdrive の直前に追加済みです。enable は専用 GPIO の `ctrlD` bit 7
> に置き、`gate_control.ctrlA` のフラグ byte は触っていません
> (`DECISIONS.md` D14)。Python API は
> `set_compressor_settings(threshold=, ratio=, response=, makeup=,
> enabled=)` / `get_compressor_settings()`、makeup byte は
> `round(makeup * 127 / 100)` で `[0, 127]` の Q7。Notebook
> (`GuitarPedalboardOneCell.ipynb`) には Comp Off / Light Sustain /
> Funk Tight / Lead Sustain / Limiter-ish の 5 プリセットを追加済み
> です。参考にした OSS (`harveyf2801/AudioFX-Compressor`、
> `bdejong/musicdsp`、`DanielRudrich/SimpleCompressor`、
> `chipaudette/OpenAudio_ArduinoLibrary`、`p-hlp/SMPLComp` (GPL)、
> `Ashymad/bancom` (GPL)) はパラメータ命名と設計思想のみ参照しており、
> ソースコードのコピーは行っていません。詳しくは `DECISIONS.md` D14、
> `DSP_EFFECT_CHAIN.md` Compressor 節、`GPIO_CONTROL_MAP.md` Compressor
> 節を参照。Noise Suppressor、Distortion Pedalboard、`set_guitar_effects`
> の互換 API は壊さないでください。

## Chain presets work — Python / notebook only, no bitstream rebuild

> Chain presets (Safe Bypass / Basic Clean / Clean Sustain / Light
> Crunch / Tube Screamer Lead / RAT Rhythm / Metal Tight / Ambient
> Clean / Solo Boost / Noise Controlled High Gain) は
> `audio_lab_pynq/effect_presets.py` の `CHAIN_PRESETS` に定義され、
> `AudioLabOverlay.apply_chain_preset(name)` /
> `get_chain_preset_names()` / `get_chain_preset(name)` /
> `get_current_pedalboard_state()` から駆動します。新規 GPIO や
> Clash 段は追加しておらず、既存セクションの set_*_settings /
> set_guitar_effects を組み合わせて適用するだけです。bit/hwh は
> 触らない / Vivado / Clash は実行しない (`DECISIONS.md` D15)。
> プリセット追加時の安全契約: Compressor `makeup` は 45..60、
> Distortion `level` <= 35、Safe Bypass は全 section enabled=False
> + reverb.mix=0。これらは `tests/test_overlay_controls.py` で
> 強制されているので、勝手に緩めないでください。Notebook 側
> (`GuitarPedalboardOneCell.ipynb`) は Chain Preset dropdown + Apply
> Chain Preset / Show Current State ボタンを持っており、原則 2 セル
> 構成。既存 Compressor / Noise Suppressor / Distortion UI は
> 触らないこと。

## Real-pedal voicing pass — deployed

> 既存エフェクトを実機ペダル/アンプ/キャビネットの voicing に寄せる
> 調整パスを実施済みです。新規 GPIO / 新規 `topEntity` ポート /
> 新規 Clash ステージは追加していません (`DECISIONS.md` D16)。
> `LowPassFir.hs` の中の既存ステージの定数とクリップ関数だけを差し
> 替えています。狙いと変更箇所の一覧は
> `docs/ai_context/REAL_PEDAL_VOICING_TARGETS.md` を参照してください。
> 主な変更:
> - Overdrive: `softClip` -> `asymSoftClip` (kneeP=3.3M / kneeN=2.9M)
> - clean_boost: drive ceiling ~5x -> ~4x、安全 clip knee 4.2M -> 3.2M
> - tube_screamer: 入力 HPF alpha 範囲を 3..18 に拡大、drive ~9x -> ~7x、
>   asym knee を `2_900_000 / 2_500_000` に下げ、post LPF を `64..191`
> - rat: hard clip floor を `2_500_000` に、`ratPostLowpassFrame`
>   alpha 192 -> 176、tone alpha base 224 -> 200
> - metal: HPF alpha 範囲を 6..37 に拡大、drive ~22x -> ~19x、
>   clip floor 1.2M -> 1.5M、post LPF を `48..175`
> - Compressor: soft-knee オフセット (`threshold - threshold/4`)、
>   reduction slope を `excess >> 12` に
> - Noise Suppressor: 閾値ヒステリシス (`closeT = threshold -
>   threshold/4` + 現 gain register の中点比較) でチャタリング抑制
> - Cab IR: 4-tap 係数の c0 を低めに、c1/c2 を高めに rebalance
> - Reverb: tone byte をスケール (`tone - tone>>3`、最大 224)
> - EQ: 出力 mix に `softClip` を追加 (3-band 全 boost で過大歪みを起こさない)
>
> ビルド結果: WNS = -6.405 ns (前回 Compressor build の -7.516 ns
> より +1.111 ns 改善)、TNS = -8806.714 ns、WHS = +0.052 ns、
> THS = 0.000 ns。`R19_ADC_CONTROL = 0x23` 維持、ADC HPF default-on
> 維持、10 chain preset すべて smoke-test pass。商用ペダル/アンプの
> 回路コピーや GPL DSP コードの移植は行っていません。

## Amp/Cab real-voicing pass — deployed

> Amp Simulator / Cab IR の実機寄せ voicing pass は
> `feature/amp-cab-real-voicing` で実装済み・deploy 済みです。
> 新規 GPIO / 新規 `topEntity` ポート / 新規 Clash register stage /
> `block_design.tcl` 変更はありません。GPIO 名 / address / ctrlA-D
> 割り当ても変更なし。`LowPassFir.hs` では `ampHighpassFrame`、
> `ampDriveMultiplyFrame`、`ampAsymClip`、`ampPreLowpassFrame`、
> `ampSecondStageMultiplyFrame`、`ampPowerFrame`、
> `ampResPresenceProductsFrame` / `ampResPresenceMixFrame`、
> `ampMasterFrame`、`cabCoeff` を既存 stage 内で retune しています。
> Cab model 0 = 1x12 open back、model 1 = 2x12 combo、model 2 =
> 4x12 closed back。`air` は capped high return で、raw line には戻り
> ません。Chain Presets は Basic Clean / Clean Sustain / Light Crunch
> を model 0 寄り、Metal / Big Muff / Fuzz を model 2 寄りに調整済み。
> build 結果: WNS=-7.917 ns、TNS=-13100.457 ns、WHS=+0.051 ns、
> THS=0.000 ns。PYNQ deploy と preset smoke test pass、ADC HPF=True /
> `R19_ADC_CONTROL=0x23`。商用アンプ回路 / commercial cab IR /
> GPL DSP コードはコピーしていません。次に Amp/Cab を触る場合も
> `GPIO_CONTROL_MAP.md` と `DECISIONS.md` D17 を読んでから、既存
> stage 内の定数変更に留めてください。

## Notebook UI / preset polish (no bitstream rebuild)

> Notebook だけの編集は bit/hwh 再生成不要です。対象 Notebook:
> `GuitarPedalboardOneCell.ipynb` (1セル UI)、
> `GuitarEffectSwitcher.ipynb` (既存 UI + Distortion Pedalboard 追加部)、
> `DistortionModelsDebug.ipynb` (pedal API walkthrough)。
> Python API の変更は不要です。`LowPassFir.hs` / `AudioLabOverlay.py` /
> bit/hwh は触らずに、Notebook と必要なら `docs/ai_context/` を更新し、
> `bash scripts/deploy_to_pynq.sh` で配置してください。

## PYNQ deploy

> deploy は `PYNQ_HOST=192.168.1.9 bash scripts/deploy_to_pynq.sh` を
> 使ってください。実機 Python 実行は
> `sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 ...` を経由
> してください。Vivado 実装で WNS が現行 deploy(-8.155 ns)より明らかに
> 悪い bitstream は deploy しないでください。

## Internal mono DSP pipeline — deployed

> `feature/internal-mono-dsp-pipeline` で、外部 AXI/I2S 48-bit stereo
> I/O と `topEntity` interface は維持したまま、DSP内部の主経路を
> ADC Left 由来の mono source に整理済みです。Right input は未接続
> ノイズ回避のため破棄し、最終 mono result を output L/R に複製します。
> `block_design.tcl`、GPIO、Python API、Notebook、Chain Preset は変更
> していません。TLAST は `Frame.fLast` で入力から出力へ伝搬し、
> `AudioLab.Pipeline` は DMA backpressure で出力 frame/TLAST を落とさない
> よう accepted input を clock-domain pace します。
>
> Build/deploy: local tests、Notebook JSON、Clash/VHDL、IP repackage、
> Vivado bit/hwh、deploy、normal PYNQ smoke は pass。Timing:
> WNS=-8.155 ns、TNS=-6492.876 ns、WHS=+0.052 ns、THS=0.000 ns。
> Utilization: Slice LUTs 15473、Slice Registers 14914、BRAM Tile 7、
> DSPs 83。DMA確認は PYNQ reboot 後に 1 overlay load / 1 composite DMA
> packet で Case A (Left nonzero / Right different)、Case B (Left zero /
> Right large)、Case C (Right inverted noise) を実施し、timeoutなし。
> send/recv DMASR はどちらも `0x00001002`、skip_frames=16 以降の
> output L/R は完全一致、Right input rejection も確認済み。
>
> 次に触る場合は、内部 mono 方針と AXI TLAST 伝搬を壊さないこと。
> DMA timeout が再発した場合は、まず `AudioLab.Axis` /
> `AudioLab.Pipeline` の AXI metadata と accepted-frame pacing を確認して
> ください。DSP係数や effect voicing の変更と混ぜないでください。

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
