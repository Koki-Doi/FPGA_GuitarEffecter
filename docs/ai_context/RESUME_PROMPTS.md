# Resume prompts

Short prompts the user can paste back to either Claude Code or Codex
after a rate-limit, context reset, or session restart. Each one is
self-contained and points the agent at the right docs instead of asking
it to re-discover the project from scratch.

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

## Distortion refactor resume

> 前回、`model_select` で歪みモデルを切り替える設計を実装しましたが、
> Vivado timing が大きく悪化しました(WNS = -15.067 ns)。
> ビットストリームは生成済みですが、deploy せずに停止しています。
>
> 次は `model_select` 方式を廃止して、独立ペダルステージ方式に移行
> してください。仕様は `docs/ai_context/DISTORTION_REFACTOR_PLAN.md`
> を参照してください。`gate_control` bit2 が distortion section
> master、`distortion_control.ctrlD` のbit0..6 が各ペダル enable
> mask です。
>
> 既存の `overdrive` / 既存 `distortion` / 既存 `RAT` 段は壊さない
> でください。`block_design.tcl` を変更せず、ADC HPF デフォルトON を
> 維持してください。`git push` / `git pull` / `git fetch` は禁止
> です。GPL系参考コードを直接コピーしないでください。

## PYNQ deploy resume

> PYNQ-Z2 実機への deploy 手順は
> `docs/ai_context/BUILD_AND_DEPLOY.md` と
> `docs/ai_context/PYNQ_RUNTIME.md` を読んでください。
>
> 配置は `PYNQ_HOST=192.168.1.8 bash scripts/deploy_to_pynq.sh` を
> 使ってください。実機 Python 実行は
> `sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 ...` を
> 経由してください。
>
> Vivado 実装で WNS が以前のベースラインより大幅に悪い bitstream は
> deploy しないでください。

## Codec / input debug resume

> 入力ノイズや DC offset を疑う場合は、まず
> `docs/ai_context/AUDIO_SIGNAL_PATH.md` の triage チェックリストを
> 上から順に確認してください。
>
> 既に ADC HPF はデフォルトON です(`R19_ADC_CONTROL == 0x23`)。
> `InputDebug.ipynb` を再生する場合、HPF を toggle した直後の
> peak_abs は IIR 整定中の過渡なので、`settling_ms=400` と
> `discard_initial_frames=2400` を使ってください。

## Documentation update resume

> `docs/ai_context/` に AI 共有ドキュメントが置いてあります。
> 仕様や運用が変わったら、ソースコードと一緒に該当ドキュメントも
> 更新してください。
>
> ドキュメントだけの修正コミットの場合、touch するファイルは
> `AGENTS.md` / `CLAUDE.md` / `docs/` 配下のみにしてください。
> 実装ファイルや bitstream を巻き込まないでください。
