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

## Phase 7B — PCM1808 / PCM5102 module verification + pin candidate docs

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

## Phase 7C — PCM5102 DAC 出力 prototype (XDC 反映の最初の段階)

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
