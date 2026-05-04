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

## Distortion pedal-mask is shipped — do not roll it back

> 歪みセクションは pedal-mask 方式 (commit `baa97ff` ほか) で実装済み・
> deploy済み・実機確認済みです。WNS は -7.801 ns まで戻っています。
> 8-way `model_select` 方式へ戻さないでください。新しいペダル / フィルタ
> を追加するときも、巨大 `case` ではなく独立 register-staged ブロックを
> 維持してください。詳細は `docs/ai_context/DISTORTION_REFACTOR_PLAN.md`
> と `DECISIONS.md` の D6 / D8 / D9 を確認してください。

## Implementing a reserved pedal (`ds1` / `big_muff` / `fuzz_face`)

> `ds1` / `big_muff` / `fuzz_face` は GPIO mask と Python API では予約
> 済みですが、Clash 側ステージはまだありません。実装する場合は
> `clean_boost` / `tube_screamer` / `metal` と同じ形 (HPF -> mul ->
> clip -> post LPF -> level の register-staged 連鎖) で書き、
> `fxPipeline` の `tube_screamer` と `metal` の間に挟んでください。
> Python API、GPIO レイアウト、notebook の予約警告は触らないように
> してください。bit/hwh 再生成のあと、Vivado timing を必ず確認し、
> 現行 deploy の WNS = -7.801 ns より大幅に悪化させないでください。
> 詳しくは `DISTORTION_REFACTOR_PLAN.md` の Phase C 節を読んでください。

## Tightening WNS

> 現状 deploy 済の WNS = -7.801 ns はベースライン同等で、運用上は
> 動いていますが厳密にはまだ負です。これを 0 へ寄せたい場合は、
> `LowPassFir.hs` の中で残った深い組合せブロックを register で分け、
> 必要なら cab タップや reverb BRAM のアドレス経路を pipeline 化
> してください。1 段に大きな `case` や 4 段以上の演算を詰めない
> 方針は維持してください (`TIMING_AND_FPGA_NOTES.md` 参照)。

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

## Notebook UI / preset polish (no bitstream rebuild)

> Notebook だけの編集は bit/hwh 再生成不要です。対象 Notebook:
> `GuitarPedalboardOneCell.ipynb` (1セル UI)、
> `GuitarEffectSwitcher.ipynb` (既存 UI + Distortion Pedalboard 追加部)、
> `DistortionModelsDebug.ipynb` (pedal API walkthrough)。
> Python API の変更は不要です。`LowPassFir.hs` / `AudioLabOverlay.py` /
> bit/hwh は触らずに、Notebook と必要なら `docs/ai_context/` を更新し、
> `bash scripts/deploy_to_pynq.sh` で配置してください。

## PYNQ deploy

> deploy は `PYNQ_HOST=192.168.1.8 bash scripts/deploy_to_pynq.sh` を
> 使ってください。実機 Python 実行は
> `sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 ...` を経由
> してください。Vivado 実装で WNS が現行 deploy(-7.801 ns)より明らかに
> 悪い bitstream は deploy しないでください。

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
