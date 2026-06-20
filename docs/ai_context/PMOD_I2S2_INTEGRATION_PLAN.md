# Pmod I2S2 integration record (current deployed path)

このドキュメントは、Digilent Pmod I2S2 (CS4344 DAC + CS5343 ADC) の
PMOD JB audio path について、最初の Phase Pmod-0 設計メモと、その後の
実装・deploy 済み仕様をまとめる。

## Current deployed status (D48 / D49 / D50, active through D148)

Pmod I2S2 は現行デプロイ済み build の **active audio path** です。
`hw/Pynq-Z2/create_project.tcl` は `pmod_i2s2_integration.tcl` を
無条件に source し、PMOD JB は `audio_lab_pmod_i2s2.xdc` の
8 pin (`JB1..JB4`, `JB7..JB10`) が専有します。PCM5102 / PCM1808 の
Tcl/XDC/RTL は repo に archival reference として残っていますが、
現行 build では source されません。

Current implementation:

- `hw/ip/pmod_i2s2/src/pmod_i2s2_master.v`: FPGA-master I2S engine。
  MCLK 12.288 MHz、**BCLK 6.144 MHz、LRCK 96 kHz (D98 codec double-speed;
  D97 までは 3.072 MHz / 48 kHz)**、24-bit / 32-bit slot / I2S Philips。
- `hw/ip/pmod_i2s2/src/axi_pmod_i2s2_status.v`: AXI status/control slave
  at `0x43D20000`, VERSION `0x00480001`。
- Runtime modes: `0 = tone`, `1 = loopback`, `2 = dsp`, `3 = mute`.
- Mode 2 (D49) routes Pmod CS5343 ADC SDOUT into `i2s_to_stream_0/si`,
  drives `i2s_to_stream_0/bclk` / `/lrclk` from the Pmod-generated clocks,
  sends `i2s_to_stream_0/so` to Pmod CS4344 DAC, and keeps ADAU
  `sdata_o` G18 as debug visibility.
- Mode 2 output is intentionally mono RIGHT-to-both-channels (D50):
  `mode2_right_snapshot` mirrors the IP RIGHT slot into both DAC slots to
  work around the `i2s_to_stream` LEFT extraction bug and `i2sOut` setup
  race.
- Runtime entries:
  `audio_lab_pynq/notebooks/PmodI2S2EffectControlOneCell.ipynb`,
  `audio_lab_pynq/notebooks/PmodI2S2HdmiGuiOneCell.ipynb`,
  `scripts/test_pmod_i2s2.py`, `scripts/pmod_i2s2_mode.py`,
  `scripts/pmod_i2s2_capture_probe.py`.
- Latest accepted deployed bitstream baseline is D148 (merge `96ef899`):
  overall WNS `+0.526 ns`, WHS `+0.014 ns`, bit/hwh md5
  `972d9ba6645dd966e6bdcb5bc3daf478` /
  `731517487c6218f0e181c2b74485d7a6`. The Pmod I2S2 RTL / Tcl / XDC
  path itself remains the D48-D50 design, with D98 changing its dividers to
  96 kHz and later decisions changing the downstream Clash DSP voicing.

The original Phase Pmod-0 planning text remains below as history. Any
sections that say "planning only" or "do not change RTL/XDC/Tcl" describe
that earlier docs-only phase, not the current repository state.

関連:
- `docs/ai_context/CURRENT_STATE.md` (current D148 / Pmod mode 2 state)
- `docs/ai_context/EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md` (retired PCM5102 / PCM1808 history)
- `docs/ai_context/IO_PIN_RESERVATION.md` (PMOD / RPi / Arduino header の pin 予約台帳)
- `docs/ai_context/AUDIO_SIGNAL_PATH.md` (内部 AXIS DSP 経路と外付け codec 接続点)
- `docs/ai_context/TIMING_AND_FPGA_NOTES.md` (deploy band と WNS baseline)
- `docs/ai_context/DECISIONS.md` (D45 / D48 / D49 / D50 / D75-D145)

---

## 1. Original purpose (historical Phase Pmod-0)

Digilent **Pmod I2S2** (CS4344 24-bit stereo DAC + CS5343 24-bit stereo
ADC、両方 I2S 入出力、共通 MCLK) を AudioLab 外付け I/O の **安定基準
リファレンス** として導入する。目的は次の 3 つ:

1. PCM5102 line out / PCM1808 line in を別個に配線した現状の代わりに、
   **DAC と ADC が同じ基板上に同じクロック系で並ぶ** 構成で外付け I2S
   I/O の信号品質を再評価する。
2. PCM1808 module の `--capture-adc` が pure 0 を返す問題
   (`DECISIONS.md` D43、analog 前段 damage 仮説) と切り離した
   **独立評価チャンネル** を確保し、PCM1808 を再投入する前に「外付け
   I2S I/O 自体が AudioLab DSP と整合的に動くか」を確認する。
3. PMOD JB 隣接ピン (JB7 PCM5102 DIN / JB8 PCM1808 SCKI) のクロス
   トーク疑い (Phase 7D close-out user 報告) を、別配線 / 別基板の
   I/O で切り分ける。

Pmod I2S2 は **既存 ADAU1761 / PCM5102 / PCM1808 の即置換ではない**。
ADAU1761 経路と Phase 7E PCM5102 ADAU-mirror 経路は維持し、Pmod I2S2
を「もう一系統の外付け I/O」として並べて評価する (`DECISIONS.md` D27
の方針と整合)。

---

## 2. Historical baseline before Pmod I2S2 (2026-05-18, Phase 7D close-out)

- `audio_lab.bit` (commit `f502373` 系) deploy 済。
- 入力 path: ADAU1761 ADC -> `pcm1808_input_select` mux
  (`CONFIG.CONST_VAL {0}` 固定、`DECISIONS.md` D43) -> `i2s_to_stream_0/si`
  -> AXIS DSP -> `i2s_to_stream_0/so`。
- 出力 path: `i2s_to_stream_0/so` を ADAU1761 DAC (`sdata_o` G18) と
  PCM5102 DAC (`pcm5102_audio_out` -> PMOD JB7 V16) に並列ミラー
  (`DECISIONS.md` D39)。
- PCM5102 SCK = 1'b0 (JB1 W14、内部 SYSCLK、`DECISIONS.md` D40 / D42)。
- PCM1808 SCKI = 12.288 MHz on JB8 W16 (`clk_wiz_audio_ext/clk_out1` 直結、
  `DECISIONS.md` D42)。`CONFIG.CONST_VAL {0}` の deploy bit でも JB8 は
  鳴っており、JB7 / JB8 隣接によるクロストーク疑いが残る (`DECISIONS.md`
  D44 follow-up 候補 #1: mux=ADAU 時の SCKI 0 固定)。
- I2S frame: 24-bit MSB-first / 32-bit slot / I2S Philips (`hw/ip/clash/src/I2S.hs`
  の `vecFromSamples` 参照)。48 kHz LRCLK / 3.072 MHz BCLK / 12.288 MHz
  MCLK は ADAU PLL 由来 (BCK / LRCK) と `clk_wiz_audio_ext` (MCLK) の
  独立 PLL ペアで構成され、PCM510x / PCM1808 のような外部 SCK 同期型
  codec では async-clocks の問題が出る前科がある (`DECISIONS.md` D40 / D41)。
- WNS baseline: `-7.931 ns` (Phase 7D close-out)。

---

## 3. Why Pmod I2S2

- **同一基板 / 共通クロック / 業界標準 Cirrus codec**: CS4344 DAC と
  CS5343 ADC は同じ Pmod 上に同じ MCLK / BCLK / LRCLK で並び、外部
  ジャンパ配線の不確実性を最小化する。
- **既存 12.288 MHz 系と互換**: `clk_wiz_audio_ext` の 12.288 MHz は
  Pmod I2S2 の 256fs MCLK としてそのまま使える (48 kHz × 256 = 12.288
  MHz)。
- **DAC / ADC を 1 module に集約できる**: PCM5102 + PCM1808 を別々に
  配線する現状の 2 module 構成と比べ、PMOD JB 1 本で I/O が完結する
  ので、JB7 / JB8 隣接クロストーク疑いを物理的に切り分けやすい。
- **Digilent 公式 PMOD 規格に準拠**: PMOD コネクタ 12-pin に合うので、
  外付けジャンパ線 / ブレッドボード経路を排除できる。
- **96 kHz: 実装済み (D98)**: CS4344 / CS5343 のダブルスピードモード
  (MCLK/LRCK = 128) で 96 kHz 化。BCLK = MCLK/2、MCLK は 12.288 MHz 維持。
  DSP の fs 依存定数は全段再ボイシング済み。詳細は `DECISIONS.md` D98 /
  `LATENCY_REDUCTION.md`。(当初は別フェーズ扱いだったが完了。)

---

## 4. Original Phase Pmod-0 non-goals (historical)

Phase Pmod-0 / planning-only の時点では以下を **やらない**としていた。
現在は D48 / D49 / D50 で RTL / XDC / Tcl / bit/hwh / Python runtime /
Notebook まで実装・deploy 済みであり、この節は当時の境界記録である。

- RTL / XDC / Tcl / Vivado build / bit/hwh 再生成 / deploy。
- Python ライブラリ / Notebook / GUI / encoder runtime 変更。
- HDMI timing (Phase 6I C2 SVGA 800x600 @ 40 MHz, `DECISIONS.md` D25)
  変更。
- encoder PL IP / RPi header pin 割当変更 (`DECISIONS.md` D32 / D34)。
- PMOD JA 使用 (encoder と外付け codec 予約のまま温存、
  `DECISIONS.md` D28 / D34)。
- PCM1808 再有効化 / `CONFIG.CONST_VAL {0}` -> `{1}` 切替
  (`DECISIONS.md` D43、ハードウェア診断完了まで凍結)。
- PCM5102 SCK を MCLK に戻すこと (`DECISIONS.md` D40 / D42、JB1 は
  構造的に常時 0)。
- ADAU1761 経路の即置換 (`DECISIONS.md` D27)。
- ~~96 kHz 実装 (Phase Pmod-5 別 branch)~~ **完了 (D98, branch
  `feature/96khz-conversion`)。**
- ギター直結を Pmod I2S2 line in に許可する (`DECISIONS.md` D27、Hi-Z
  buffer / preamp が必要)。

---

## 5. Hardware assumptions

### 5.1 Digilent Pmod I2S2 ボード

- 搭載: Cirrus Logic **CS4344** (24-bit stereo DAC) + **CS5343**
  (24-bit stereo ADC)。両方 single-end line-level audio I/O。
- 入出力端子: 3.5 mm stereo audio jack ×2 (LINE IN / LINE OUT)。
- インターフェース: PMOD 12-pin Type 2A (互換)、3.3V LVCMOS。
- I2S 信号は **DAC 側 / ADC 側で論理的に独立** だが、同じ MCLK / BCLK
  / LRCLK を共有する想定。
- FPGA master / codec slave 構成 (FPGA から MCLK / BCLK / LRCLK を
  生成、ADC SDOUT は FPGA 入力)。

**要公式確認** (Digilent reference manual / schematic、納品時に開封 + 実機
シルク + マニュアル URL で確定すること、ここでは仮置きしない):
- PMOD ピン 12-pin の正確な signal 配置 (`MCLK / BCLK / LRCLK / SDIN
  (TX) / SDOUT (RX)` の物理 pin 番号)
- TX / RX で MCLK が共通か個別か
- 電源 (3.3V のみで動作するか、5V を要求する load かどうか)
- input impedance / output impedance / level 仕様
- pull-up / pull-down strap の有無
- 出力 jack の AC coupling / DC coupling
- 内部 LDO の有無

### 5.2 PYNQ-Z2 PMOD JB

- 8 信号 pin (JB1..JB4, JB7..JB10) + GND (JB11) + 3.3V (JB12)。
- すべて `LVCMOS33`、PYNQ-Z2 board file 由来。
- 他ヘッダと共有していない (`IO_PIN_RESERVATION.md` 4.6)。
- 現状 audio 専用に使われている (上記 section 2 参照)。

### 5.3 接続方針 (要点)

- Pmod I2S2 評価時は **既存 PCM5102 / PCM1808 配線を物理的に外す**。
  PMOD JB を Pmod I2S2 module 1 個だけに繋ぐ。これは「複数 module で
  PMOD JB を共有しない」原則 (`DECISIONS.md` D45 案、section 12 参照)。
- 長いジャンパ線 / ブレッドボード経由を避け、PMOD I2S2 module を
  PYNQ-Z2 の PMOD JB 雌コネクタへ直接挿す。
- Pmod I2S2 ボード自身が PMOD 規格準拠なので、追加配線は不要。
- GND は PMOD JB11、電源は PMOD JB12 (3.3V)。

---

## 6. Official specification — confirmation status

Pmod I2S2 公式 reference manual を 2026-05-18 に確認済。PMOD pin 配置
は section 10 で確定。残り項目は実機納品後 / Phase Pmod-1 開始前に
公式 reference manual + CS4344 / CS5343 datasheet で埋める。

| 項目 | 期待値 / 確定値 | 確認方法 | Status |
| --- | --- | --- | --- |
| Pmod I2S2 PMOD pin 配置 (D/A side: Pin 1=MCLK, Pin 2=LRCK, Pin 3=SCLK/BCLK, Pin 4=SDIN) | section 10 表参照 | Digilent Pmod I2S2 reference manual | **confirmed (2026-05-18)** |
| Pmod I2S2 PMOD pin 配置 (A/D side: Pin 7=MCLK, Pin 8=LRCK, Pin 9=SCLK/BCLK, Pin 10=SDOUT) | section 10 表参照 | 同上 | **confirmed (2026-05-18)** |
| MCLK の D/A side / A/D side 別 pin 提供 | D/A と A/D は別 pin、FPGA 内部で同 source から fanout する | 同上 | **confirmed (2026-05-18)** |
| 電源 / GND pin (Pin 5/11 = GND, Pin 6/12 = VCC = 3.3V) | section 10 表参照 | 同上 + PYNQ-Z2 board file | **confirmed (2026-05-18)** |
| MCLK 周波数 (最小 / 最大) | 256fs = 12.288 MHz at 48 kHz が標準 | CS4344 / CS5343 datasheet | 要確認 (datasheet) |
| BCLK / LRCLK polarity, I2S Philips vs left-justified | I2S Philips, MSB delayed by 1 BCLK | datasheet + Digilent サンプル設計 | 要確認 (datasheet) |
| supply voltage | 3.3V single | reference manual | **confirmed (2026-05-18)** |
| supply current | < 100 mA 想定 | datasheet | 要確認 (実測 + datasheet typ/max) |
| line-in input impedance | ~10..50 kΩ (CS5343 typ) | CS5343 datasheet | 要確認 (datasheet) |
| line-in input level | typ 1 Vrms line level | CS5343 datasheet | 要確認 (datasheet) |
| line-out output level | typ 1 Vrms line level | CS4344 datasheet | 要確認 (datasheet) |
| pull-up / strap | unknown, requires inspection | 実機 silkscreen + reference manual | 要確認 (実機納品後) |
| analog coupling | AC coupling onboard 想定 | reference manual | 要確認 (reference manual) |

`confirmed` 項目は section 10 の mapping 表に反映済。`要確認` 項目は
納品後の実機 + datasheet で section 15 open questions と合わせて埋める。

---

## 7. Initial 48 kHz audio format (D97 まで; D98 で 96 kHz 化)

Phase Pmod-1 から Phase Pmod-4 までの初期仕様 (下表は D97 までの 48 kHz。
**D98 で 96 kHz / BCLK 6.144 MHz に変更**, MCLK は 12.288 MHz 維持):

| 項目 | 値 |
| --- | --- |
| Sample rate | **48 kHz** |
| Bit depth | **24-bit signed** |
| Slot width | **32 bit / channel** |
| Frame | **stereo (L+R, 64-bit frame)** |
| LRCLK | 48 kHz、L=low / R=high の I2S Philips 規約 |
| BCLK | 3.072 MHz (64 × 48 kHz) |
| MCLK | 12.288 MHz (256 × 48 kHz) |
| Format | I2S Philips, MSB-first, 1 BCLK delay after LRCLK edge |
| Master | **FPGA** (Pmod I2S2 codec は slave 受け) |

この仕様は `hw/ip/clash/src/I2S.hs` の既存 `i2sIn` / `i2sOut` / `vecFromSamples`
と完全に整合する (24-bit MSB-first / 32-bit slot / 1-cycle delay)。
追加 SRC や CDC は不要。

クロックソース:
- MCLK: 既存 `clk_wiz_audio_ext` (`100 MHz -> 12.288 MHz exact`) を再利用
  可能。Phase Pmod-1 では新規 MMCM を追加しない。
- BCLK / LRCLK: ADAU1761 PLL 由来の `bclk` (R18) / `lrclk` (T17) 入力
  port を再利用すると ADAU 経路に依存することになるので、Pmod I2S2 を
  FPGA master 構成にする場合は **FPGA 側で BCLK / LRCLK を生成**
  するのが望ましい (`clk_wiz_audio_ext` 12.288 MHz → /4 で 3.072 MHz
  BCLK、/256 で 48 kHz LRCLK)。これは Phase Pmod-1 の実装課題。
  詳細クロック木は実装フェーズで確定する。

---

## 8. Historical Phase Pmod-5 96 kHz plan (implemented differently at D98)

This section preserves the pre-D98 plan. The deployed D98+ implementation uses
96 kHz with **MCLK still 12.288 MHz** (128fs double-speed) and BCLK 6.144 MHz;
the planned 24.576 MHz MCLK below was not adopted.

| 項目 | 値 |
| --- | --- |
| Sample rate | 96 kHz |
| LRCLK | 96 kHz |
| BCLK | 6.144 MHz |
| MCLK | 24.576 MHz |
| Frame | stereo (L+R, 64-bit frame) |
| Bit depth | 24-bit signed |
| Slot width | 32 bit / channel |
| Format | I2S Philips |

96 kHz 化の影響範囲 (やる時に対応):
- `clk_wiz_audio_ext` の `CLKOUT1_REQUESTED_OUT_FREQ` を 12.288 → 24.576 MHz
  に変更 (Vivado IP wizard で 24.576 MHz exact は VCO 設定で生成可能)。
- ADAU1761 codec の I2C 初期化を 96 kHz mode に変更 (現状 48 kHz 固定で、
  これを動かすと既存 ADAU 経路が回帰)。Phase Pmod-5 では ADAU1761 を
  **48 kHz のまま固定し**、Pmod I2S2 だけ 96 kHz で走らせる選択肢が現実的。
  ADAU と Pmod I2S2 で sample rate が異なる場合、AXIS chain は 1 系統
  しか持っていないので、build-time mux で「どちらの fs を AXIS chain に
  渡すか」を決める必要がある。
- DSP 係数の見直し:
  - `delay` / `reverb` の tap 長 (sample 数で書かれているので、実時間
    50% 短くなる → BRAM tap 数を 2 倍にする必要)。
  - `compressor` / `noise suppressor` の attack / release 時定数
    (sample 数なので、実時間 50% 短くなる)。
  - `tone` / `EQ` の 1-pole IIR `α` (係数を 96 kHz 用に再計算)。
  - Cab IR 4-tap 係数 (96 kHz では高域 weight が変わるので再 voicing)。
  - Amp Simulator の `softClipK` / 安全 knee は連続関数なので変更不要。
- AXI GPIO の byte 範囲 (0..100) は変更不要。
- HDMI / encoder は影響なし。
- timing review 必須 (DSP の `clk_fpga_0` 100 MHz は変えないので組合せ
  深さは同じ、ただし sample rate 倍化で連続サンプル間の cycle budget が
  半分になる → register stage を増やす必要が出る可能性)。

This gate was completed at D98. Current work must use the deployed 96 kHz
constants and must not revive the 24.576 MHz planning assumption.

---

## 9. Mono DSP policy

DSP 本体 (`hw/ip/clash/src/LowPassFir.hs` の `fxPipeline` 以下) は
**mono 処理を維持**する (`DECISIONS.md` D22)。Pmod I2S2 でも mono を
そのまま使う:

- **入力**: Pmod I2S2 ADC L channel のみを DSP に渡す。R channel は
  破棄する (現状の `i2s_to_stream_0` 経由で ADAU と同じ取り扱い)。
- **出力**: DSP 出力 (processed_mono) を Pmod I2S2 DAC の L / R 両方に
  duplicate する (現状の `i2s_to_stream_0/so` が 24-bit L + 24-bit R を
  同じ値で詰めている、Phase 7E 構成と同一)。
- **理由**:
  - 既存 DSP chain の `fxPipeline` は mono 前提で voicing 済
    (`DECISIONS.md` D22)。
  - 24-bit DSP のリソース予算がそもそも tight (`TIMING_AND_FPGA_NOTES.md`
    の WNS `-7.931 ns`)。
  - guitar effect は mono が業界標準。
- stereo 化したい時は **別 phase で discussion**。Phase Pmod 範囲では
  やらない。

---

## 10. Confirmed PMOD JB mapping

Pmod I2S2 公式 reference manual で確認済み (2026-05-18)。Pmod 12-pin
の D/A 側 (Pin 1..4) と A/D 側 (Pin 7..10) は **物理的に別 pin**
として PMOD コネクタ上に出ており、それぞれ独立した MCLK / LRCK /
SCLK / SDIN(or SDOUT) を持つ。FPGA 側ではこれを **1 系統の 12.288 MHz
MCLK + 48 kHz LRCK + 3.072 MHz BCLK を内部で生成して 2 系統に
fanout (複製) 出力**する。SDIN (DAC data, FPGA → Pmod) と SDOUT
(ADC data, Pmod → FPGA) は **唯一の独立 / 反対方向 data 信号**。

凡例:
- `wired-pcm` = historical Phase 7D PCM5102 / PCM1808 構成で物理的に
  配線されていた機能。現行 build では PMOD JB は Pmod I2S2 が専有する。
- `confirmed` = 公式 Pmod I2S2 reference manual で確定済。
- `confirmed (board file)` = PYNQ-Z2 TUL board file 由来。

| Pmod I2S2 Pin | Pmod I2S2 signal | Direction (FPGA view) | PYNQ PMOD JB pin | Package pin | Existing usage (Phase 7D deploy) | Notes | Confirmation status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Pin 1 | **D/A MCLK** | out | JB1 | W14 | `ext_audio_mclk_o = 1'b0` (PCM5102 SCK 構造的 GND、D40/D42) | 12.288 MHz (256 fs at 48 kHz)、Pmod I2S2 評価では JB1 を 12.288 MHz に **戻す**。`pcm5102_audio_out` を build から外す前提。 | confirmed |
| Pin 2 | **D/A LRCK** | out | JB2 | Y14 | `ext_audio_bclk_o = ADAU bclk` | 48 kHz (FPGA-master 生成)、internal LRCK net の fanout #1 | confirmed |
| Pin 3 | **D/A SCLK / BCLK** | out | JB3 | T11 | `ext_audio_lrclk_o = ADAU lrclk` | 3.072 MHz (FPGA-master 生成)、internal BCLK net の fanout #1 | confirmed |
| Pin 4 | **D/A SDIN** | out | JB4 | T10 | `ext_adc_dout_i` (PCM1808 DOUT 入力、D41) | DAC へ流す 24-bit I2S Philips data。既存方向 in → out に変わる、PCM1808 wiring を物理的に外す前提。 | confirmed |
| Pin 5 | GND | gnd | JB11 | (PMOD JB GND) | GND | 共通 GND | confirmed (board file) |
| Pin 6 | VCC | power | JB12 | (PMOD JB VCC) | 3.3V supply | Pmod I2S2 module 電源 | confirmed (board file) |
| Pin 7 | **A/D MCLK** | out | JB7 | V16 | `ext_dac_din_o` (PCM5102 DIN 出力、D39) | 12.288 MHz、internal MCLK net の fanout #2 (D/A MCLK と同位相 / 同周波数)、既存方向 out → out (意味だけ変わる) | confirmed |
| Pin 8 | **A/D LRCK** | out | JB8 | W16 | `ext_pcm1808_sckie_o` (PCM1808 SCKI 出力、D42) | 48 kHz、internal LRCK net の fanout #2、既存 SCKI 12.288 MHz から **意味が変わる** | confirmed |
| Pin 9 | **A/D SCLK / BCLK** | out | JB9 | V12 | spare | 3.072 MHz、internal BCLK net の fanout #2、現状空き | confirmed |
| Pin 10 | **A/D SDOUT** | **in** | JB10 | W13 | spare | ADC から FPGA への 24-bit I2S Philips data。Pmod I2S2 経由の **唯一の input**、現状空き | confirmed |
| Pin 11 | GND | gnd | (PMOD JB GND) | (PMOD JB GND) | GND | 共通 GND (Pin 5 と共有) | confirmed (board file) |
| Pin 12 | VCC | power | (PMOD JB VCC) | (PMOD JB VCC) | 3.3V supply | Pmod I2S2 module 電源 (Pin 6 と共有) | confirmed (board file) |

**FPGA 内部クロック木 (Phase Pmod-1 RTL 実装方針)**:
- MCLK ソース: 既存 `clk_wiz_audio_ext` (100 MHz → 12.288 MHz exact、
  Phase 7C で投入済)。新規 MMCM 追加なし。
- internal `mclk_int` (12.288 MHz) → JB1 と JB7 へ fanout (D/A MCLK と
  A/D MCLK は同位相同周波数で並列駆動)。
- internal `bclk_int` (3.072 MHz, `mclk_int / 4`) → JB3 と JB9 へ fanout。
- internal `lrck_int` (48 kHz, `bclk_int / 64`) → JB2 と JB8 へ fanout。
- `dac_sdin` (FPGA out, 24-bit I2S Philips MSB-first / 32-bit slot) → JB4 のみ。
- `adc_sdout` (FPGA in, 同 frame format) → JB10 のみ。

これにより D/A 側と A/D 側が **bit-true 同期** で動くことが保証される
(独立 PLL のような async-clocks 問題は構造的に発生しない、`DECISIONS.md`
D40 / D41 の教訓を継承)。

**重要 (Phase Pmod-1 開始前にやること)**:
- Pmod I2S2 module を PMOD JB に挿す前に、既存 PCM5102 / PCM1808
  配線 (ジャンパ線) を **物理的に外す**。
- pcm5102_audio_out / pcm1808_adc_integration の Tcl 出力ポートが
  まだ XDC / block design に残っている状態で Pmod I2S2 module を
  挿すと、JB1 が 0 駆動、JB2 / JB3 / JB7 / JB8 が ADAU PLL 由来の
  クロックや PCM1808 SCKI を流すので、Pmod I2S2 module の I/O
  仕様と矛盾する可能性が高い。新規 build variant では既存 pcm5102 /
  pcm1808 integration tcl を **source から外す** ことが必要。

---

## 11. Phase plan

各 phase は独立 commit / 独立 git branch で進める。Pmod-1 〜 Pmod-4 は
ADAU1761 経路を **維持** したまま並行追加する build variant 想定。
Pmod-5 は別 branch でしか着手しない。

### Phase Pmod-0: Planning only (本フェーズ)

- 目的: 仕様 / 接続方針 / 実装フェーズ / 検証手順 / pin mapping の整理。
- 変更対象: docs のみ (この PMOD_I2S2_INTEGRATION_PLAN.md + 既存 docs
  への最小追記)。
- 禁止: RTL / XDC / Tcl / Vivado / bit/hwh / Python runtime / Notebook 変更。
- 合格条件: PMOD_I2S2_INTEGRATION_PLAN.md が commit され、納品後に再開
  する agent が `git log` だけで context を取り戻せること。
- 実機確認: なし (まだ module が手元にない)。
- rollback: docs revert で済む。

### Phase Pmod-1: Pmod I2S2 DAC-only tone

- 目的: Pmod I2S2 module の物理配線 / 電源 / DAC clocks (MCLK / BCLK /
  LRCLK) / DAC SDIN を確認し、line out から 1 kHz tone を実機で鳴らす。
- 変更対象 (実装フェーズ、Pmod-0 では着手しない):
  - 新規 `hw/Pynq-Z2/pmod_i2s2_integration.tcl` (Phase 7C
    `pcm5102_dac_integration.tcl` の構造を踏襲)。
  - 新規 `hw/ip/pmod_i2s2_dac_tone/src/pmod_i2s2_dac_tone.v` (Phase 7C
    `pcm5102_dac_tone.v` 相当の I2S master、24-bit / 32-bit slot /
    1 kHz quarter-scale sine)。`clk_wiz_audio_ext` 12.288 MHz を MCLK
    として使い、内部で BCLK = MCLK/4、LRCLK = BCLK/64 を生成。
  - `hw/Pynq-Z2/audio_lab.xdc` に Pmod I2S2 用 pin を追加 (4 〜 8 pin、
    section 10 確定後)。
  - 既存 `pcm5102_dac_integration.tcl` / `pcm1808_adc_integration.tcl` を
    `create_project.tcl` から **source から外す** (build variant 切替)。
- 既存 PCM5102 / PCM1808 配線 (物理ジャンパ) は **外して** から挿す。
- DSP 経路 (`LowPassFir.hs` / `i2s_to_stream_0` / AXIS chain) は触らない。
- HDMI / encoder integration tcl は触らない。
- 禁止:
  - 既存 ADAU1761 経路に手を入れる。
  - PCM5102 SCK を MCLK に戻す。
  - PCM1808 を再有効化する (`CONFIG.CONST_VAL {0}` → `{1}` 凍結維持、
    `DECISIONS.md` D43)。
  - 96 kHz 化、stereo DSP 化、Notebook 経路変更。
  - PMOD JA を使う。
- 合格条件:
  - Vivado build PASS (`write_bitstream completed successfully`)。
  - 最終 routed WNS が `-7.931 ns` (Phase 7D close-out) 比で大幅悪化
    していない (`TIMING_AND_FPGA_NOTES.md` deploy band 内)。
  - PYNQ-Z2 deploy 成功 (5 か所 bit/hwh 同期、`v_tc_hdmi GEN_ACTSZ` 維持)。
  - Pmod I2S2 line out に headphone / audio interface input を繋いで
    1 kHz tone が clean に聞こえる。
- 実機確認内容:
  - オシロ / logic analyzer で MCLK 12.288 MHz、BCLK 3.072 MHz、LRCLK
    48 kHz、SDIN が I2S Philips 24-bit MSB-first を打っていることを確認。
  - line out レベル (typ 1 Vrms 程度) を測定。
  - 30 秒 hold で audible glitch / drop / DC offset が無いこと。
- rollback 条件:
  - WNS が `-9.5 ns` 以下に悪化したら deploy 中止 (`TIMING_AND_FPGA_NOTES.md`
    deploy gate)。
  - tone が出ない場合は: PMOD pin mapping を section 6 確認項目に戻して
    再検証、それでも駄目なら Pmod-1 を pause して PMOD I2S2 module 自体
    の故障を疑う (`scripts/test_pmod_i2s2_dac_tone.py` (新規) で全 IP
    存在を `ip_dict` で確認)。

### Phase Pmod-2: Pmod I2S2 ADC-to-DAC loopback (no DSP)

- 目的: Pmod I2S2 ADC SDOUT を FPGA に入れ、そのまま Pmod I2S2 DAC SDIN
  に流す物理 loopback。DSP は通さない。
- 変更対象 (実装フェーズ):
  - `pmod_i2s2_integration.tcl` の RTL を ADC 入力 + DAC 出力対応に拡張。
  - `axi_dma_0` / `i2s_to_stream_0` / Clash DSP は **触らない** (DSP 経路
    へ feed しない)。
  - ADC 側 RTL: FPGA-master mode で MCLK / BCLK / LRCLK を生成 + ADC
    SDOUT を I2S deserializer で読み取り (24-bit MSB-first / 32-bit slot)。
  - DAC 側 RTL: ADC で読んだ stereo 24-bit を I2S serializer に詰めて
    DAC SDIN に出力。L / R はそのまま pass-through。
- 既存 ADAU1761 経路は維持 (`DECISIONS.md` D27)。
- DSP / AXIS chain は触らない。
- 禁止: Pmod-1 と同じ。
- 合格条件:
  - Vivado build / deploy PASS、timing deploy band 内。
  - Pmod I2S2 line in に function generator (sin 1 kHz / 200 Hz / 5 kHz)
    を入れて、Pmod I2S2 line out で同じ波形が出ることを oscilloscope /
    別 audio interface で確認。
  - finger-touch test: 入力 GND short で line out が silent、入力に手で
    触れると 50 / 60 Hz hum が出ることを確認 (= 入力 chain が live)。
- 実機確認内容:
  - L only に signal を入れた時 L out only が動くこと (R が silent)、
    逆も同様 (= channel cross が無い)。
  - 30 秒連続 1 kHz hold で audible jitter / drift が無いこと。
  - delay (round-trip latency) を簡易測定 (typ 1〜2 ms 想定)。
- rollback 条件: 入力 silent / output noise だらけ / channel mix が
  おかしい場合は physical wiring を再確認、それでも駄目なら Pmod-1
  時点で見落とした pin mapping mistake の疑い。

### Phase Pmod-3: Pmod I2S2 ADC -> existing DSP -> Pmod I2S2 DAC

- 目的: Pmod I2S2 を既存 mono DSP chain に接続して effect が音に反映
  されることを確認。
- 変更対象 (実装フェーズ):
  - Pmod I2S2 ADC 出力 (stereo 24-bit) を `i2s_to_stream_0/si` の代替
    入力として接続する mux を追加 (PCM1808 と類似の build-time `xlconstant`
    で source 切替、AXI runtime 切替は後回し)。または **standalone build
    variant** として Pmod I2S2 専用 bit を別に置く (Pmod-1 / Pmod-2 と
    同じ方針)。
  - DSP 出力 `i2s_to_stream_0/so` を Pmod I2S2 DAC SDIN に流す。
  - ADAU1761 ADC / ADAU1761 DAC / PCM5102 / PCM1808 経路は **触らない**
    (build variant で source / sink を切替)。
- 既存 mono DSP (section 9) を維持: ADC L only → DSP → DAC L/R duplicate。
- HDMI / encoder / GPIO_CONTROL_MAP / `LowPassFir.hs` / `topEntity` は
  触らない。
- 禁止: Pmod-1 / Pmod-2 と同じ + raw GPIO 直書き / encoder runtime 改変。
- 合格条件:
  - Vivado build / deploy PASS、timing deploy band 内。
  - Pmod I2S2 line in にギターを (Hi-Z buffer 経由で) 入れ、Notebook
    `GuitarPedalboardOneCell.ipynb` から effect を ON にすると Pmod I2S2
    line out の音色が変わる。
  - Safe Bypass で bit-exact (ADAU mirror と同じ contract)。
- 実機確認内容:
  - Distortion ON / OFF、Overdrive ON / OFF、Reverb ON / OFF、Noise
    Suppressor ON / OFF が聞いて分かる。
  - encoder GUI live apply (D37) で knob を動かすと音が変わる
    (`run_encoder_hdmi_gui.py --live-apply`)。
- rollback 条件: effect が反映されない / DSP が pass-through から動か
  ない場合は AXIS source 切替の bug、build variant を Pmod-2 に戻す。

### Phase Pmod-4: A/B comparison (ADAU vs PCM5102 vs Pmod I2S2)

- 目的: 同じ DSP 設定で 3 経路の出力を聞き比べ + 計測し、Pmod I2S2 が
  reference として使えるか判定する。
- 変更対象 (実装フェーズ): build variant を切替えるだけ。新規 RTL なし。
  - ADAU variant: 現状の `f502373` 系 deploy bit (mux=ADAU, ADAU DAC out)。
  - PCM5102 variant: 同じ bit (PCM5102 line out で聴く)。
  - Pmod I2S2 variant: Pmod-3 で作った bit。
- 既存 path は触らない (variant 切替のみ)。
- 合格条件:
  - 3 variant で **同一の effect 設定 / 同一の入力 signal** に対して、
    line out 出力の subjective audio quality と objective (FFT スペクトル
    / THD+N / SNR) を比較したログが残る。
  - どれを reference にするかの判定が docs に残る (Phase Pmod-4 result
    section を `CURRENT_STATE.md` に追加)。
- 実機確認内容: A/B/X blind test (可能なら別人 と)、ノイズフロア計測、
  THD+N at 1 kHz / 0 dBFS-3 dB を別 audio interface で計測。
- rollback 条件: Pmod I2S2 が他より明らかに悪い場合は Pmod-5 に進まず、
  PCM5102 (D39 / D40) を継続 reference にする。

### Phase Pmod-5: optional 96 kHz experiment (別 branch)

- 目的: Pmod I2S2 が 48 kHz で安定したことを前提に、96 kHz 化の影響を
  評価する。
- 変更対象: 別 branch (`feature/pmod-i2s2-96khz` 想定)。`main` には
  merge しない。
- 既存 ADAU1761 経路は **48 kHz のまま固定**。Pmod I2S2 だけ 96 kHz で
  走らせる。
- 最初は Safe Bypass のみで音が通るところを確認する。DSP 係数の
  96 kHz 補正は別フェーズ。
- 禁止:
  - ADAU1761 sample rate を変更する。
  - `LowPassFir.hs` の係数を 96 kHz 用に再 voicing する (これは Pmod-5
    成功後の別フェーズで扱う)。
  - HDMI / encoder / GPIO_CONTROL_MAP / Phase 6I HDMI timing を変える。
- 合格条件: Pmod I2S2 line in -> Safe Bypass -> Pmod I2S2 line out が
  96 kHz で clean に通る (passthrough audio が DSP 通過後の null
  test と一致する程度)。
- rollback 条件: 96 kHz で audio が破綻 / WNS が `-9.5 ns` を超える
  / 動作が不安定な場合は branch を放棄し 48 kHz に戻る。

---

## 12. Test plan (per phase, summary)

各 phase で実機 smoke を **off-line + on-board** の両方で持つ。

| Phase | Off-line test (workstation) | On-board test (PYNQ-Z2) | Audio test |
| --- | --- | --- | --- |
| Pmod-0 | docs lint / git diff check | none | none |
| Pmod-1 | RTL synth / Vivado build local | overlay load, ADC HPF True, `ip_dict` に `pmod_i2s2_*` 確認 | Pmod I2S2 line out で 1 kHz tone |
| Pmod-2 | 同上 | overlay load, RTL deserializer + serializer の logic dump | line in -> line out passthrough |
| Pmod-3 | unit test (DSP は変えないので回帰 0) | overlay load + encoder smoke + HDMI smoke | line in -> effect on -> line out |
| Pmod-4 | none | variant 切替時の md5 cross-check | A/B/X subjective + FFT / THD+N |
| Pmod-5 | RTL synth + timing review (96 kHz, 別 branch) | overlay load | Safe Bypass passthrough only |

すべての phase で以下を毎回確認:
- `ADC HPF True` / `R19_ADC_CONTROL = 0x23` (ADAU1761 codec 健在、
  `DECISIONS.md` D1)。
- HDMI VTC `GEN_ACTSZ = 0x02580320` (Phase 6I C2 SVGA 800x600 維持、
  `DECISIONS.md` D25)。
- encoder `VERSION = 0x00070001` / `CONFIG = 0x00010105` (encoder PL
  IP 健在、`DECISIONS.md` D32 / D36)。
- VDMA error bit 全 false。
- Safe Bypass で audio が通る。

---

## 13. Risk list

| Risk | Mitigation |
| --- | --- |
| **R1: Pmod I2S2 公式 pinout を未確認のまま実装に入る** | section 6 「要公式確認」項目を Phase Pmod-1 開始前 checklist として埋める。埋まらないまま実装に入らない。 |
| **R2: 既存 PCM5102 / PCM1808 ジャンパが残ったまま Pmod I2S2 を挿す** | section 14 納品後 checklist に「既存ジャンパを物理的に外す」を必須項目として置く。Pmod-1 の build variant では `pcm5102_dac_integration.tcl` / `pcm1808_adc_integration.tcl` を `create_project.tcl` から source から外す。 |
| **R3: ADAU1761 経路を壊す** | Pmod-1 〜 Pmod-4 は ADAU1761 入力 / DSP / ADAU DAC 出力ポートを **一切触らない**。build variant で ADC source / DAC sink を切替えるだけ。 |
| **R4: 96 kHz 化で DSP 係数が音楽的に破綻する** | Phase Pmod-5 は別 branch、Safe Bypass のみで音が通る確認まで。係数 voicing は別フェーズ。 |
| **R5: WNS regression** | Pmod-1 で `-7.931 ns` 比 `0.5 ns` 程度悪化までは許容、`-9.5 ns` を超えたら deploy 中止 (`TIMING_AND_FPGA_NOTES.md` deploy gate)。 |
| **R6: HDMI / encoder への影響** | Pmod I2S2 integration tcl は HDMI / encoder integration tcl と address / pin が衝突しないように切り分け、`0x43CE0000` / `0x43CF0000` / `0x43D10000` / `0x43D00000` を避ける (`DECISIONS.md` D32)。AXI-Lite slave 不要なら GPIO 追加もしない。 |
| **R7: GND / 電源ノイズ** | Pmod I2S2 は PMOD JB の 3.3V から取る (typ < 100 mA、要 datasheet 確認)。LDO / supply 分離が必要な場合は別 phase。 |
| **R8: 入力 impedance / level でギター直結を試して壊す** | section 6.1 + `EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md` section 5 で「Pmod I2S2 line in にギターを直結しない」を docs として明示。Hi-Z buffer が必要。 |
| **R9: TX / RX clock の sync を取り違える** | section 6 で TX / RX MCLK 共有 / 独立を Pmod I2S2 reference manual で確認。共有なら 1 系統で 5 pin、独立なら 7 pin になり mapping が変わる。 |
| **R10: PMOD JB ribbon cable のクロストーク** | Pmod I2S2 module は PMOD コネクタに直挿しなので、PCM5102 / PCM1808 で問題になっていた長いジャンパ ribbon (`DECISIONS.md` D44 JB7/JB8 隣接問題) は構造的に発生しにくい。それでも Phase Pmod-2 の loopback で line in -> line out null test を取れば検出できる。 |

---

## 14. Rollback plan

| 何が起きたら | どこに戻す | 操作 |
| --- | --- | --- |
| Pmod-1 で tone が出ない / WNS 大幅悪化 | Phase 7D close-out (`f502373`) | build variant を切替て `pcm5102_dac_integration.tcl` + `pcm1808_adc_integration.tcl` 入りの旧 bit を deploy。物理 wiring も PCM5102 / PCM1808 に戻す。 |
| Pmod-2 で loopback が動かない | Phase Pmod-1 | Pmod I2S2 DAC-only tone が出ることだけ確認した状態に戻す。ADC 側 RTL を切り離す。 |
| Pmod-3 で effect が反映されない | Phase Pmod-2 | DSP feed を切り離して loopback bit に戻す。AXIS source 切替の bug を疑う。 |
| Pmod-4 の A/B で Pmod I2S2 が明らかに悪い | Phase Pmod-3 / Phase 7D | ADAU + PCM5102 reference を継続採用。Pmod I2S2 は debug 用に残す。Pmod-5 へは進まない。 |
| Pmod-5 で 96 kHz が破綻 | 48 kHz Pmod-3 bit | branch を放棄 (`git branch -D feature/pmod-i2s2-96khz`)、48 kHz 路線に戻る。 |
| ADAU1761 を破壊した (`R19 != 0x23`、`ADC HPF False`、I2C 反応なし) | Phase 7D close-out (`f502373`) + `pcm5102_dac_integration.tcl` / `pcm1808_adc_integration.tcl` を `create_project.tcl` に戻す | これは設計レベルの rollback、`block_design.tcl` を触らない範囲で復旧する。Vivado build + 5 か所 sync。 |
| HDMI が出なくなった (VTC `GEN_ACTSZ != 0x02580320` / LCD 白画面) | Phase 6I C2 bit | rgb2dvi PLL kick out なら power cycle、tcl 改変なら `f502373` revert。`hdmi_integration.tcl` は触っていない前提なので通常起きないはず。 |
| encoder が反応しなくなった (`VERSION != 0x00070001`) | Phase 7G+ bit | `encoder_integration.tcl` は触っていない前提。`hwh` の差分を確認、`f502373` に revert。 |

---

## 15. Open questions

公式 reference manual で 2026-05-18 に確定済の項目:
- **(resolved)** Pmod I2S2 の正確な PMOD pin 配置 (D/A side Pin 1..4、
  A/D side Pin 7..10) — section 10 表に反映。
- **(resolved)** D/A side と A/D side は **物理的に別 pin** で MCLK /
  LRCK / SCLK / data を提供する。FPGA 側は同 source から fanout 出力。
- **(resolved)** Pin 5/11 = GND、Pin 6/12 = VCC (3.3V single supply)。

Phase Pmod-1 開始前に **CS4344 / CS5343 datasheet + 実機** で埋める
残質問:

1. supply current の typ / max (PMOD JB12 3.3V rail で賄えるか、別電源
   が要るか)。
2. line in / line out の AC coupling / DC coupling、impedance、level
   (CS4344 / CS5343 datasheet)。
3. CS4344 / CS5343 の動作 mode (master / slave、I2S / left-justified、
   bit depth 16/24)。Pmod I2S2 module 上 strap で固定されているか、
   FPGA から制御するか。**前提**: FPGA-master / codec-slave / I2S Philips
   / 24-bit MSB-first / 32-bit slot (`hw/ip/clash/src/I2S.hs` と互換)。
4. 96 kHz / 192 kHz 動作可否 (datasheet 上で OK でも Pmod I2S2 onboard
   の strap / LDO が制限している可能性)。Phase Pmod-5 で確認。
5. line out が headphone を直接駆動できるか、line out -> guitar amp 入力
   想定で安全か。
6. 既存 `clk_wiz_audio_ext` (12.288 MHz exact) を Pmod I2S2 MCLK に
   そのまま使えるか (CS4344 / CS5343 は 256fs / 384fs / 512fs を許容する
   想定、要 datasheet 確認)。
7. Pmod I2S2 module を PMOD JB に挿した時の **電源シーケンス**: FPGA
   configuration 完了前に 3.3V が立ち上がっても codec が壊れないか。
8. Pmod I2S2 が DAC と ADC で独立 mute / reset pin を露出しているか、
   XSMT 相当 (`DECISIONS.md` D38 PCM5102 で議論された pop-noise 対策)
   が必要か。Pmod I2S2 reference manual では 12-pin 全部が clock / data
   / power / GND で占められているので **module 上 strap で固定** されて
   いる可能性が高い (要 reference manual 再確認)。

---

## 16. Next prompt for implementation (納品後、Phase Pmod-1 開始用)

**今は実行しない**。Pmod I2S2 module が手元に届いて section 6 / 15 の
公式確認項目が埋まったら、別セッションで以下のプロンプトを Claude
/ Codex に渡す:

> 作業対象は `/home/doi20/Desktop/Audio-Lab-PYNQ`。
>
> Phase Pmod-1 (Pmod I2S2 DAC-only tone) を開始する。前提は
> `docs/ai_context/PMOD_I2S2_INTEGRATION_PLAN.md` (Pmod-0 で commit 済)
> 全文。特に section 6 (要公式確認項目) / section 10 (PMOD JB mapping) /
> section 11 Phase Pmod-1 の合格条件を満たすこと。
>
> 物理前提:
> - Pmod I2S2 module を **PMOD JB** に直挿し済。
> - 既存 PCM5102 / PCM1808 のジャンパ配線は **物理的に外して** ある。
> - PMOD JA / Raspberry Pi header / Arduino header には触らない。
>
> やること:
> 1. `docs/ai_context/PMOD_I2S2_INTEGRATION_PLAN.md` section 6 の `要確認`
>    残項目 (supply current / line in/out impedance & level / CS4344 /
>    CS5343 strap mode / pop-noise 対策) を CS4344 / CS5343 datasheet と
>    実機で埋めたことを冒頭で確認する。**section 10 (PMOD JB mapping)
>    は公式 reference manual で確定済 (2026-05-18) なので変更しない**。
> 2. 新規 `hw/Pynq-Z2/pmod_i2s2_integration.tcl` を Phase 7C
>    `pcm5102_dac_integration.tcl` の構造で作る。`create_project.tcl`
>    から source。新規 MMCM は追加せず、既存 `clk_wiz_audio_ext`
>    (12.288 MHz exact) を再利用。
> 3. 新規 `hw/ip/pmod_i2s2_dac_tone/src/pmod_i2s2_dac_tone.v` を Phase 7C
>    `pcm5102_dac_tone.v` の構造で作る。24-bit / 32-bit slot /
>    1 kHz quarter-scale sine、I2S Philips。BCLK = MCLK / 4、LRCK =
>    BCLK / 64。FPGA 内部で 1 系統の MCLK / LRCK / BCLK を生成し、
>    JB1+JB7 (MCLK)、JB2+JB8 (LRCK)、JB3+JB9 (BCLK) に **fanout** して
>    出力する (section 10 内部クロック木参照)。
> 4. `hw/Pynq-Z2/audio_lab.xdc` に Pmod I2S2 用 8 pin (JB1/JB2/JB3/JB4 +
>    JB7/JB8/JB9/JB10) を追加 (section 10 の確定 mapping)。`LVCMOS33`、
>    no PULLUP。JB10 のみ input。
> 5. `create_project.tcl` から既存 `pcm5102_dac_integration.tcl` /
>    `pcm1808_adc_integration.tcl` を **source から外す** (build variant
>    切替)。これらの tcl 自体は削除しない (rollback / variant 戻し
>    のため repo に残す)。
> 6. Vivado build + 5 か所 sync deploy + smoke
>    (`scripts/test_pmod_i2s2_dac_tone.py` 新規作成、`scripts/test_pcm5102_dac_tone.py`
>    と同じ shape)。
> 7. PYNQ-Z2 で `AudioLabOverlay()` load PASS、ADC HPF True、HDMI VTC
>    `GEN_ACTSZ` 維持、encoder `VERSION` 維持、Pmod I2S2 line out で
>    1 kHz tone が clean に出ることを確認。
>
> 禁止:
> - `LowPassFir.hs` / `topEntity` / `block_design.tcl` 変更。
> - HDMI / encoder integration tcl 変更。
> - 既存 ADAU1761 経路の即置換。
> - PCM5102 SCK を MCLK に戻す (`DECISIONS.md` D40 / D42)。
> - PCM1808 `CONFIG.CONST_VAL` を `{1}` に戻す (`DECISIONS.md` D43)。
> - 96 kHz 化、stereo DSP 化。
> - PMOD JA 使用、Raspberry Pi header / Arduino header 改変。
> - raw GPIO 直書き、encoder runtime 改変。
> - `git push` / `git pull` / `git fetch`。
> - `git reset --hard`、未 commit 差分破棄。
>
> Phase Pmod-1 完了後、`PMOD_I2S2_INTEGRATION_PLAN.md` の Phase Pmod-1
> 節に「deploy result + WNS + smoke 結果」を追記し、Phase Pmod-2 への
> 移行可否を判定する。

---

## 17. Phase Pmod-1 / Pmod-2 / Pmod-3 implementation status (2026-05-19, branch `feature/pmod-i2s2-bringup`, `DECISIONS.md` D48)

Pmod I2S2 module 到着済 + PMOD JB に直挿し済 + Line Out ↔ Line In
ループバック済。**PMOD JB は Pmod I2S2 専用**、PCM5102 / PCM1808
bring-up path は retired (D48)。`create_project.tcl` は env var なしで
常に Pmod I2S2 build を行う:
- `add_files audio_lab.xdc` + `audio_lab_pmod_i2s2.xdc`
- `add_files` pmod_i2s2 RTL (`pmod_i2s2_master.v`,
  `axi_pmod_i2s2_status.v`)
- `source pmod_i2s2_integration.tcl`
- PCM5102 / PCM1808 の RTL / tcl / `audio_lab_pcm.xdc` は repo に
  archival として残すが build に投入しない。

### 17.1 実装したファイル

- **RTL**: `hw/ip/pmod_i2s2/src/pmod_i2s2_master.v`
  + `hw/ip/pmod_i2s2/src/axi_pmod_i2s2_status.v`
  (両方 `default_nettype none`、self-contained、Xilinx IP 依存なし)。
- **Tcl 統合**: `hw/Pynq-Z2/pmod_i2s2_integration.tcl` を新規追加し、
  `hw/Pynq-Z2/create_project.tcl` から **無条件に** source する。
  PCM5102 / PCM1808 integration tcl は `create_project.tcl` から
  外した (ファイル自体は repo に残す)。
- **XDC**: `hw/Pynq-Z2/audio_lab_pmod_i2s2.xdc` (新規) に Pmod I2S2
  用 8 pin (JB1/JB2/JB3/JB4/JB7/JB8/JB9/JB10) の LVCMOS33 制約を
  まとめた。`hw/Pynq-Z2/audio_lab.xdc` は ADAU1761 + HDMI + encoder
  だけを残し、PMOD JB 行は archival の `audio_lab_pcm.xdc` (新規、
  loaded しない) に移した (D48 first attempt で試した `if` guard 方式は
  Vivado 2019.1 で silent drop されるため不採用、memory
  `vivado-xdc-if-not-supported`)。
- **Python smoke**: `scripts/test_pmod_i2s2.py`
  + `scripts/pmod_i2s2_capture_probe.py`。両方 `pmod_status` を
  `pynq.MMIO(phys_addr, 0x10000)` で開く (DefaultHierarchy 経由は
  `.read()` が dispatch しないため不採用)。

### 17.2 確定 pin map (section 10 と同一、再掲)

| Pmod I2S2 J1 Pin | 信号 | Direction | PMOD JB | Package pin | LVCMOS33 |
| --- | --- | --- | --- | --- | --- |
| 1  | D/A MCLK   | out | JB1  | W14 | yes |
| 2  | D/A LRCK   | out | JB2  | Y14 | yes |
| 3  | D/A SCLK   | out | JB3  | T11 | yes |
| 4  | D/A SDIN   | out | JB4  | T10 | yes |
| 5  | GND        | -   | JB11 | -   | - |
| 6  | VCC (3.3V) | -   | JB12 | -   | - |
| 7  | A/D MCLK   | out | JB7  | V16 | yes |
| 8  | A/D LRCK   | out | JB8  | W16 | yes |
| 9  | A/D SCLK   | out | JB9  | V12 | yes |
| 10 | A/D SDOUT  | **in** | JB10 | W13 | yes |
| 11 | GND        | -   | (JB GND) | - | - |
| 12 | VCC (3.3V) | -   | (JB VCC) | - | - |

### 17.3 内部クロック木

```
clk_wiz_audio_ext.clk_out1 (12.288 MHz, exact)
        |
        +--> pmod_i2s2_master.clk_12m288_i
               |
               +--> ext_pmod_i2s2_da_mclk_o  (JB1, fanout #1)
               +--> ext_pmod_i2s2_ad_mclk_o  (JB7, fanout #2)
               |
        BCLK = MCLK / 4 = 3.072 MHz (internal `bclk_int`)
               +--> ext_pmod_i2s2_da_sclk_o  (JB3)
               +--> ext_pmod_i2s2_ad_sclk_o  (JB9)
               |
        LRCK = BCLK / 64 = 48 kHz (internal `lrck_int`)
               +--> ext_pmod_i2s2_da_lrck_o  (JB2)
               +--> ext_pmod_i2s2_ad_lrck_o  (JB8)
```

D/A 側 と A/D 側は同じ source からの fanout なので **bit-true 同期**。
独立 PLL が並ぶ Phase 7D の構成 (D40 / D41 async-clocks 問題) は
構造的に発生しない。

### 17.4 I2S frame

- LRCK low = LEFT, high = RIGHT.
- I2S Philips: data MSB は LRCK transition の 1 BCLK 後に出る。
- 24-bit data MSB-first、32-bit slot per channel、8-bit zero pad LSBs。
- DAC TX (CS4344) と ADC RX (CS5343) で同じ frame format。

### 17.5 AXI-Lite status block

- Address: `0x43D20000 / 0x10000` (encoder `0x43D10000` の次)。
- ps7_0_axi_periph M18 (NUM_MI 18 → 19)。
- Register map: `DECISIONS.md` D48 + axi_pmod_i2s2_status.v ヘッダ参照。
- 全 status は MCLK domain で生成し、AXI clock domain (100 MHz) へ
  2-FF synchronizer で渡す。`cfg_mode` は level signal で master 内
  でも 2-FF 同期する。`cfg_clear` は toggle bit + edge-detect で
  clock-period mismatch に robust。

### 17.5b One-cell notebook for mode 2 (2026-05-20)

`audio_lab_pynq/notebooks/PmodI2S2EffectControlOneCell.ipynb` (1
code cell, 0 markdown cells) is the live Jupyter UI for the
Pmod I2S2 mode-2 path. The cell loads `AudioLabOverlay`, finds the
`pmod_status_0` MMIO, writes `cfg_mode = 2` (DSP) at startup, and
builds an `ipywidgets` panel with:

- Top buttons: `Load/Reload overlay`, `Apply effects`,
  `All effects off`, `Safe clean (mode 2)`, `Panic / mute (mode 3)`,
  `Clear status counters`, `Refresh status`.
- Mode buttons: `Mode 0: tone`, `Mode 2: DSP` (active default),
  `Mode 3: mute`, `Mode 1: ADC->DAC loopback` (requires the
  `confirm loopback` checkbox to commit).
- Status panel: VERSION / STATUS / MODE register / FRAME_COUNT /
  NONZERO_COUNT / SDOUT_XCOUNT / CLIP_COUNT / LAST_LEFT/RIGHT /
  PEAK_ABS_LEFT/RIGHT in raw + dBFS.
- An Accordion with eight panels, one per effect: Noise Suppressor,
  Compressor (`set_compressor_settings`), Overdrive (model
  dropdown from `OVERDRIVE_MODEL_LABELS`), Distortion (pedal
  dropdown from `DISTORTION_PEDALS_IMPLEMENTED`), Amp Sim (model
  dropdown from `AMP_MODELS`, 0..100 sliders), Cab IR (model 0/1/2),
  EQ (low/mid/high 0..200, unity = 100), Reverb (decay/tone/mix).

The notebook is **deploy-via** `scripts/deploy_to_pynq.sh`
(`install_notebooks` already copies everything under
`audio_lab_pynq/notebooks/` to `/home/xilinx/jupyter_notebooks/audio_lab/`,
so no per-notebook plumbing was needed). No RTL / Tcl / XDC / bit /
hwh change; existing notebooks are not edited.

### 17.6 Build flow (no variant)

- `create_project.tcl` は **無条件に** Pmod I2S2 build を行う:
  - `add_files audio_lab.xdc` + `audio_lab_pmod_i2s2.xdc`
  - `add_files` pmod_i2s2 RTL
  - `source pmod_i2s2_integration.tcl`
- PCM5102 / PCM1808 path は retire 済。再導入したい場合は
  `create_project.tcl` を編集して `add_files` `audio_lab_pcm.xdc` +
  PCM RTL、`source pcm5102_dac_integration.tcl` +
  `pcm1808_adc_integration.tcl` を戻し、同時に Pmod I2S2 部を
  外す (PMOD JB pin が衝突するため)。

### 17.7 実機手順 (Pmod-1 + Pmod-2 同時)

1. **物理配線**: 既存 PCM5102 / PCM1808 のジャンパ線 / module を
   PMOD JB から物理的に外す。Pmod I2S2 module を PMOD JB に直挿し
   (Pin 1 が JB1 / W14 側になる向き)。電源は 3.3V (JB12) のみ。
   5V には絶対繋がない。
2. **Line Out ↔ Line In アナログ接続**: Pmod I2S2 の Line Out
   3.5 mm ジャックを Line In 3.5 mm ジャックに stereo ケーブルで
   ループバック接続済 (user 前提)。これは Phase Pmod-2 の ADC probe
   smoke を 1 回の deploy で済ませるための物理 loopback。
3. **Vivado build** (env var なし、Pmod I2S2 が build default):
   ```
   cd hw/Pynq-Z2
   source /home/doi20/vivado/Vivado/2019.1/settings64.sh
   vivado -mode batch -notrace -nojournal \
       -log vivado.log -source create_project.tcl
   ```
4. **timing review**: `audio_lab/audio_lab.runs/impl_1/block_design_wrapper_timing_summary_routed.rpt`
   を読み、WNS が Phase 7D close-out baseline `-7.931 ns` 比で
   `-9.5 ns` を超えていないことを確認 (`TIMING_AND_FPGA_NOTES.md`
   deploy gate)。
5. **deploy**: `PYNQ_HOST=192.168.1.9 bash scripts/deploy_to_pynq.sh`。
   5 か所 bit/hwh sync。
6. **on-board smoke**:
   ```
   ssh xilinx@192.168.1.9 '
     cd /home/xilinx/Audio-Lab-PYNQ &&
     sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
         scripts/test_pmod_i2s2.py --duration 5
   '
   ```
7. **ADC probe**:
   ```
   ssh xilinx@192.168.1.9 '
     cd /home/xilinx/Audio-Lab-PYNQ &&
     sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
         scripts/pmod_i2s2_capture_probe.py --duration 10 --interval 0.5
   '
   ```
   期待: Line Out → Line In 接続中なら peak_abs_left/right が
   非ゼロで増加。Line In のケーブルを抜くと peak が下がる。
8. **ADC → DAC direct loopback (任意 / Phase Pmod-3)**:
   ```
   ssh xilinx@192.168.1.9 '
     cd /home/xilinx/Audio-Lab-PYNQ &&
     sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 \
         scripts/test_pmod_i2s2.py --mode 1 --duration 5
   '
   ```
   注意: Line Out ↔ Line In が物理接続されたまま `--mode 1` を
   走らせると自己フィードバックする可能性がある。最初は外部音源
   (スマートフォン等) を Line In に入れて Line Out から音が戻る
   ことを確認するのが安全。

### 17.8 結果欄 (build / deploy / smoke 後に埋める)

- Vivado bit/hwh: `???` (timestamp / md5)
- WNS routed: `??? ns` / `???`
- critical warnings: `???`
- PYNQ overlay load: `??? ms` / `???`
- ADAU1761 R19: `0x???` (`0x23` 期待)
- HDMI VTC GEN_ACTSZ: `0x???` (`0x02580320` 期待)
- encoder VERSION: `0x???` (`0x00070001` 期待)
- pmod_status VERSION: `0x???` (`0x00480001` 期待)
- DAC tone audible: `???`
- ADC probe pass (frame_count rising + peak_abs > 0): `???`
- ADC → DAC direct loopback (mode=1, 外部音源): `???`

### 17.9 Rollback

| 状況 | 対応 |
| --- | --- |
| Vivado build PASS、timing NG (WNS < -9.5 ns) | 新しい bit を deploy しない。`audio_lab.baseline.bit/.hwh` をそのまま使う。 |
| Vivado build PASS、deploy 成功、smoke FAIL | `audio_lab.baseline.bit/.hwh` を 5 か所に書き戻し、reboot。`git checkout main` で source code も Phase 7D close-out に戻す。 |
| Vivado build NG | `git checkout main` で Phase 7D close-out source に戻し再 build。失敗箇所を `git log` で trace。 |
| Pmod I2S2 module 故障疑い | branch を main へ戻し、PCM5102 / PCM1808 ジャンパを物理的に挿し直し、Phase 7D close-out bit を deploy。 |

## 18. Phase Pmod-clean-fix implementation status (2026-05-20, branch `feature/pmod-i2s2-dsp-clean-fix`, `DECISIONS.md` D50)

### 18.1 動機

D49 で mode 2 (Pmod ADC → AudioLab DSP → Pmod DAC) は **frame_count
+1.44M / 30 s, CLIP_COUNT=0** で動いていたが、ユーザー耳確認で
「エフェクト全 OFF でも mode 1 (直 echo) と比べて少し歪んで聞こえる」
という報告があった。mode 1 (Pmod 内部直 echo) は同じハードウェアで
クリーン耳確認済みなので、原因は **mode 2 path 内部** に限定された。

### 18.2 切り分け (`scripts/diagnose_pmod_i2s2_dma_capture.py`)

`feature/pmod-i2s2-dsp-clean-fix` ブランチに切って、AXIS passthrough
の中身を DMA で直接覗くスクリプトを追加:

- mode 2 は AXIS で `passthrough` ルートが選ばれる
  (`_route_effect_chain` で全 flag=0 のとき)。passthrough は
  `axis_switch_source/M00 → axis_switch_sink/S00` で Clash 経由しない。
- `route(line_in, passthrough, dma)` で DMA S2MM に切り替えると、
  同じ `i2s_to_stream_0/axis_li_tdata` を numpy で取れる。

結果 (同じ外部音源 -6..-10 dBFS、mode 2 と mode 1 両方で):

| 項目 | Pmod-master deserializer | DMA (i2s_to_stream 経由) |
| --- | --- | --- |
| RIGHT peak | `4,300,727` (`-5.8 dBFS`) | **`4,300,727` (delta=0)** |
| LEFT peak | `4,249,702` (`-5.9 dBFS`) | **`8,388,152` (`-0.02 dBFS`)** |
| LEFT mean | ~0 | **`-341,868` (大きな負 DC オフセット)** |
| LEFT bit prevalence (bit 16..21) | 通常 ~26-27% | **半分 (12-13%)** |
| LEFT bit prevalence (bit 12..15, 22, 23) | 通常 ~26-27% | 通常 ~26-27% |

RIGHT は Pmod-master と完全一致、LEFT は IP が壊れているのが確定。
mode 1 でも DMA を取ると同じパターンになる (= IP の不具合は
audio mode と無関係、IP 内部の固有バグ)。

加えて、`i2s_to_stream/so` の更新タイミング (= BCLK rising edge) が
DAC sampling edge と同じで setup margin がゼロのため、DAC が **古い
bit** を latch する 1-BCLK shift も同時に起きる可能性がある (Pmod
master mode 0/1 の serializer は BCLK falling edge で出力するため
DAC への setup time は約 162 ns で安全)。

### 18.3 修正方針 (`hw/ip/pmod_i2s2/src/pmod_i2s2_master.v`)

**目標:** IP には触らず、`pmod_i2s2_master.v` だけで mode 2 を
clean にする (D50)。

実装:

```verilog
reg [31:0] mode2_right_snapshot;
always @(posedge clk_12m288_i) begin
    if (!resetn_i) begin
        mode2_right_snapshot <= 32'd0;
    end else if (bclk_fall_pre && bit_idx[5]) begin
        // bclk_fall_pre = mclk_phase==01. この時点で dsp_dac_sdin_i
        // は IP の post-rising 値 (1 MCLK 経過した安定値)。
        // bit_idx[5]=1 は RIGHT slot。
        mode2_right_snapshot[bit_idx[4:0]] <= dsp_dac_sdin_i;
    end
end

always @(*) begin
    case (cfg_mode)
        2'd0:    din_mux_r = din_internal_r;
        2'd1:    din_mux_r = din_internal_r;
        2'd2:    din_mux_r = mode2_right_snapshot[bit_idx[4:0]];
        default: din_mux_r = 1'b0;
    endcase
end
```

挙動:
- RIGHT slot (bit_idx 32..63) で `mode2_right_snapshot[0..31]` を
  順次更新。各 `slot_idx` 位置に IP の意図する RIGHT bit が入る。
- LEFT slot (bit_idx 0..31) で同じバッファを LEFT slot の `slot_idx`
  で読み出す。前フレームの RIGHT slot bit が再生される。
- 結果として両耳とも **前フレームの RIGHT slot bits** = チェーンの
  RIGHT 出力 = モノラル。frame 遅延 ≈ 21 us で人間には知覚不能。

副作用:
- mode 2 はステレオを失う (両耳とも RIGHT)。スタジオ品質には不向き
  だが、ギターエフェクト用途は元々モノなので影響なし。
- mode 0 / 1 / 3 は完全に未変更 (case 文の他のブランチを触っていない)。
- Clash チェーンは引き続き broken LEFT を入力として処理するが、
  出力 LEFT は DAC に届かないので問題なし。

### 18.4 Build / Deploy

- Vivado bit/hwh rebuild PASS (~21 分):
  - WNS = `-7.985 ns` (D49 baseline `-8.521 ns` から `+0.536 ns` 改善)
  - WHS = `+0.050 ns`, THS = `0 ns` (hold OK)
  - Inside historical `-7..-9 ns` deploy band
- `bash scripts/deploy_to_pynq.sh` PASS (5 か所同期、overlay 再ロード OK)。

### 18.5 Smoke 結果 (deploy 後、PYNQ-Z2 で実行)

- **mode 1 regression (5 s)**: PASS。MODE=1、frame_count
  +240,269 / 5s (48 kHz lock)、CLIP_COUNT=0、peak_abs_left/right
  ~ -6 dBFS。ユーザー耳: クリーン (mode 2 修正で mode 1 を壊して
  いないことを確認)。
- **mode 2 clean (15 s, `diagnose_pmod_i2s2_dsp_clean.py`)**:
  MODE=2、frame delta +720,720 / 15s、CLIP_COUNT=0、peak_abs ~ -13 dBFS。
  **ユーザー耳確認: 「mode 1 と同じくクリーン」**。修正前と同じ
  入力レベルで歪みが消えた。
- **mode 2 + Overdrive A/B (`--ab-overdrive` 6s 区間 ×3)**:
  Phase A clean → Phase B Overdrive ON (歪み加算) → Phase C OFF
  (clean に戻る)。**ユーザー耳確認: 「ON で歪んで、OFF でクリーンに
  戻った」**。DSP チェーンが期待通り反応する。
- **mode 3 mute**: PASS。MODE=3、DAC silent。

### 18.6 Rollback

| 状況 | 対応 |
| --- | --- |
| `feature/pmod-i2s2-dsp-clean-fix` の bit/hwh で予期しない動作 | `git checkout main` で D49 状態に戻し再 deploy。mode 2 は元の (歪んだ) 挙動に戻る。 |
| `pmod_i2s2_master.v` の修正だけ取り消したい | `git diff main -- hw/ip/pmod_i2s2/src/pmod_i2s2_master.v` で差分確認、`mode2_right_snapshot` 関連を削除し mux を `dsp_dac_sdin_i` に戻す + 再 build。 |
| mode 2 を完全に避けたい | runtime で `MODE=1` (loopback) または `MODE=3` (mute) に書く。RTL 変更不要。 |

### 18.7 既知の制限・残課題

- **mode 2 はモノラル**: ステレオ録音を mode 2 で通すと両耳とも
  チェーンの RIGHT 出力になる。ステレオが必要ならば `i2s_to_stream`
  IP 自体の修正が必要 (今回は scope 外)。
- **DSP チェーンの中の LEFT サンプルは壊れたまま**: IP が壊れた
  LEFT を chain に渡しているので chain 内部状態 (フィードバック・
  フィルタ・エンベロープ等) は broken LEFT を入力として動く。chain
  の RIGHT 出力に LEFT が混ざる stage (例: 将来導入するステレオ
  reverb の cross-feed) があると影響が出る可能性がある。現状の
  guitar effects はモノ前提なので問題なし。
- **IP 自体の bug fix は未対応**: `i2s_to_stream` の Clash auto-
  generated VHDL の LEFT 抽出ロジックは構文的には samplesFromVec
  と等価に見えるが measurement で broken なため、CDC / BRAM
  timing 側の問題と推測。深い調査は別セッションで扱う。
