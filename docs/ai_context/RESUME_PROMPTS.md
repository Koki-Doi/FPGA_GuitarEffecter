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
> # mode 2: ADC -> AudioLab DSP -> DAC (D49). The --confirm-dsp flag is
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

## Phase Pmod-0 — Pmod I2S2 integration planning (docs only, module not yet delivered)

> Digilent Pmod I2S2 (CS4344 stereo DAC + CS5343 stereo ADC) を購入済、
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

## Phase 7C / 7E / 7D — External PCM5102 / PCM1808 audio path (deployed; D44 follow-up plan only)

> 外付け PCM5102 DAC + PCM1808 ADC は **Phase 7C / 7E / 7D で実装・
> deploy 済**。PCM5102 は AudioLab DSP 出力の並列ライン
> (`i2s_to_stream_0/so` をそのままミラー) として動作中、PCM1808 は
> build-time 2:1 wire mux + JB8 SCKI まで実装済だが deploy bit は
> `CONFIG.CONST_VAL {0}` (mux=ADAU フォールバック) で出荷中。詳細は
> `docs/ai_context/AUDIO_SIGNAL_PATH.md` の "External PCM1808 /
> PCM5102 paths" 節、`EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md`
> section 9、`DECISIONS.md` D38 / D39 / D40 / D41 / D42 / D43 / D44。
>
> 触ってはいけないこと:
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

## Phase D55 — Replace Amp Sim model set with six researched amp voicings (current)

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

## Phase D53 — Amp Sim model-only character + binary DRV MODE (current)

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

## Phase 7G+ — GUI-first encoder live apply (current)

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
>   encoder3 rotate は live\_apply=True のとき 100 ms throttle で
>   `apply_appstate` を呼ぶ。
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
