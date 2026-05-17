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
> してください。Vivado 実装で WNS が現行 deploy(-8.096 ns)より明らかに
> 悪い bitstream は deploy しないでください。

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

> 現状 deploy 済の WNS = -8.096 ns (Phase 6I C2 SVGA 800x600 HDMI
> ビルド) はベースライン同等で、運用上は動いていますが厳密には
> まだ負です。これを 0 へ寄せたい場合は、`LowPassFir.hs` の中で
> 残った深い組合せブロックを register で分け、必要なら cab タップ
> や reverb BRAM のアドレス経路を pipeline 化してください。1 段に
> 大きな `case` や 4 段以上の演算を詰めない方針は維持してください
> (`TIMING_AND_FPGA_NOTES.md` 参照)。

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

## Phase 7B — PCM1808 / PCM5102 module verification + XDC candidate

> Phase 7A は planning only で終了済みです (`DECISIONS.md` D27 ~
> D30、commit はこの prompt 時点では未定)。Phase 7B はまず以下を読んで
> ください: `docs/ai_context/EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md`、
> `docs/ai_context/IO_PIN_RESERVATION.md`、`docs/ai_context/CURRENT_STATE.md`
> の Phase 7A 節。
>
> Phase 7B の作業:
> 1. 実モジュール (Youmile PCM1808 / 汎用 PCM5102) を物理確認し、
>    silkscreen ピン名 / VCC / I/O level / `MD0` / `MD1` / `FMT` /
>    `SCKI` の有無 / `XSMT` / `FLT` / `DMP` / onboard regulator の
>    有無 / analog 結合方式を `EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md`
>    section 3 のチェックリストで埋める。
> 2. `IO_PIN_RESERVATION.md` の論理予約 (PMOD JB に audio 5 + spare、
>    PMOD JA に control / strap、Raspberry Pi header に encoder) を
>    PYNQ-Z2 board file (`/home/doi20/board_files/XilinxBoardStore/
>    boards/TUL/pynq-z2/1.0/`) で実 Package Pin に解決する。
> 3. XDC 候補を作成 (まだ commit しない)。ADAU1761 既存 pin
>    (`U5 / M17 / M18 / U9 / T9 / F17 / G18 / R18 / T17`) と HDMI
>    pin (`L16 / L17 / K17 / K18 / K19 / J19 / J18 / H18`) に衝突
>    しないこと。
> 4. 外付け I2S interface module (Clash or HDL) の初稿設計。DSP
>    本体 (`LowPassFir.hs`) は変更しない。
>
> 禁止: ADAU1761 即置換、ギター直結を前提にした analog front-end
> 省略、`block_design.tcl` 変更 (Phase 7B 時点では未承認)、bit / hwh
> 再生成、`git push` / `git pull` / `git fetch`。

## Phase 7F — Rotary encoder PL IP + XDC

> Phase 7F に入る前に `docs/ai_context/ENCODER_GUI_CONTROL_SPEC.md`
> を必ず読んでください (`DECISIONS.md` D30)。
>
> Phase 7F の作業:
> 1. encoder decode IP (2-stage sync + debounce + quadrature FSM +
>    delta / count / event / CONFIG / CLEAR_EVENTS、register map は
>    `ENCODER_GUI_CONTROL_SPEC.md` section 4) を Clash or HDL で実装。
> 2. AXI-Lite slave で接続。base 候補 `0x43CE0000` (既存
>    `axi_gpio_*` `0x43C30000..0x43CD0000` と衝突しないこと)。
> 3. `block_design.tcl` 修正 (ユーザ承認後): `NUM_MI` 増、address
>    segment 追加、encoder IP 配線。
> 4. `audio_lab.xdc` に encoder pin 追加 (Raspberry Pi header 候補)、
>    `PULLUP true` 設定。
> 5. bit / hwh build。WNS が `TIMING_AND_FPGA_NOTES.md` の最新
>    deploy band (-8.731 ns 近辺) を大きく悪化させないこと。
> 6. 簡単な debug script で raw delta / event が出るか確認。
>
> 禁止: PS polling で A / B / SW を直接読む実装 (`DECISIONS.md` D30
> 違反)、既存 `axi_gpio_*` に encoder bit を混ぜる、ADAU1761 / HDMI
> 経路の改変、`git push` / `git pull` / `git fetch`。

## Phase 7G — Python encoder driver + GUI focus state

> 前提: Phase 7F で encoder IP が deploy 済 (`audio_lab.bit` に
> encoder IP が含まれている) こと。
>
> Phase 7G の作業:
> 1. `audio_lab_pynq/encoder_input.py` (low-level driver) と
>    `audio_lab_pynq/encoder_ui.py` (high-level controller) を
>    `ENCODER_GUI_CONTROL_SPEC.md` section 3 の API 案に沿って実装。
> 2. `GUI/compact_v2/state.py` に focus state (`focus_effect_index` /
>    `focus_param_index` / `edit_mode` / `model_select_mode` /
>    `last_encoder_event` / `value_dirty` / `apply_pending` /
>    `last_control_source`) を追加。`AppState` の既存 field
>    (`all_knob_values` 等) は破壊しない。
> 3. `GUI/compact_v2/renderer.py` に focus 表示 / dirty 表示 /
>    press feedback / `last_control_source` 表示を追加。
> 4. `audio_lab_pynq/notebooks/HdmiGui.ipynb` を encoder 駆動でも
>    notebook 駆動でも動くように更新。1 つの loop で
>    `EncoderUiController.poll()` → `apply_to_state()` →
>    `apply_to_overlay()` を回す。
> 5. notebook なしで全機能操作できる prototype を確認。
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
