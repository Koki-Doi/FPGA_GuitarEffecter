# IO pin reservation and current ownership

PYNQ-Z2 の IO pin について、Phase 7 planning 時点の予約と、現行
deploy 済み build の実オーナーを記録する。現在の active audio は
Digilent Pmod I2S2 on PMOD JB、encoder は Raspberry Pi header
`raspberry_pi_tri_i_6..14`、HDMI は Phase 6I SVGA 800x600。

Phase 7A の **予約 (reservation)** 文言は履歴として残す。現行 build では
`hw/Pynq-Z2/audio_lab_pmod_i2s2.xdc` と `hw/Pynq-Z2/audio_lab.xdc` に
実ピン制約が入っている。

関連:
- `docs/ai_context/PMOD_I2S2_INTEGRATION_PLAN.md` (current Pmod I2S2 implementation)
- `docs/ai_context/EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md` (retired PCM1808 / PCM5102 history)
- `docs/ai_context/ENCODER_GUI_CONTROL_SPEC.md` (encoder 仕様)
- `docs/ai_context/GPIO_CONTROL_MAP.md` (既存 AXI GPIO 出力台帳。本ドキュメントとは別レイヤ)
- `hw/Pynq-Z2/audio_lab.xdc` (実際の pin 制約。Phase 7A の間は read-only)

---

## 1. 既存使用中の PYNQ-Z2 pin (read-only, do not move)

`hw/Pynq-Z2/audio_lab.xdc` の現状:

### ADAU1761 (onboard codec) — pin は固定

| 信号 | pin | role |
| --- | --- | --- |
| `mclk` | `U5` | master clock to ADAU1761 |
| `bclk` | `R18` | I2S BCLK |
| `lrclk` | `T17` | I2S LRCLK |
| `sdata_i` | `F17` | I2S DIN (ADC → FPGA) |
| `sdata_o` | `G18` | I2S DOUT (FPGA → DAC) |
| `codec_address[0]` | `M17` | ADAU1761 I2C address strap |
| `codec_address[1]` | `M18` | ADAU1761 I2C address strap |
| `IIC_1_scl_io` | `U9` | ADAU1761 I2C SCL |
| `IIC_1_sda_io` | `T9` | ADAU1761 I2C SDA |

### HDMI TX (PYNQ-Z2 HDMI OUT) — pin は固定

| 信号 | pin | role |
| --- | --- | --- |
| `hdmi_tx_clk_p` | `L16` | HDMI clock + |
| `hdmi_tx_clk_n` | `L17` | HDMI clock − |
| `hdmi_tx_data_p[0]` | `K17` | HDMI data0 + |
| `hdmi_tx_data_n[0]` | `K18` | HDMI data0 − |
| `hdmi_tx_data_p[1]` | `K19` | HDMI data1 + |
| `hdmi_tx_data_n[1]` | `J19` | HDMI data1 − |
| `hdmi_tx_data_p[2]` | `J18` | HDMI data2 + |
| `hdmi_tx_data_n[2]` | `H18` | HDMI data2 − |

これらは **絶対に動かさない**。Phase 7 の追加 IO は **これらを避ける**。

---

## 2. PYNQ-Z2 上の未使用ヘッダ (Phase 7 候補)

PYNQ-Z2 ボードには次の外部 IO ヘッダがあり、現状 `audio_lab.xdc` で
信号宣言されていない。**Phase 7 はこれらに新規信号を割り当てる**。

| ヘッダ | 概略 | 第一候補用途 (Phase 7) |
| --- | --- | --- |
| **PMOD JB** | 8 信号 + GND + 3.3V (clean 8-pin block) | **Current owner: Digilent Pmod I2S2 active audio** (`DECISIONS.md` D48 / D49 / D50) |
| **PMOD JA** | 8 信号 + GND + 3.3V | 追加 audio control (FMT / MD0 / MD1 / XSMT / RESET / spare) |
| **Raspberry Pi header** | 40-pin (GPIO 多数 + 3.3V + GND) | **ロータリーエンコーダー (低速 GPIO)** |
| **Arduino digital / analog header** | digital + analog | spare / 将来のフットスイッチ / LED |

ピン番号 (Package Pin) は PYNQ-Z2 board file
(`/home/doi20/board_files/XilinxBoardStore/boards/TUL/pynq-z2/1.0/`)
で参照する。本ドキュメントでは **論理信号名 / 用途 / ヘッダ** のみを
固定し、実 Package Pin は Phase 7B で確定する。

優先順位の理由:
- 外付け I2S audio は同期性が要るので、同じ PMOD にまとめる
- 高速 (3.072 MHz BCLK / 12.288 MHz MCLK) は PMOD で問題ない
- encoder は低速 GPIO で問題なく、Raspberry Pi header に分散できる
- Arduino header は最後に使う

---

## 3. Historical external audio (PCM1808 + PCM5102) pin reservation

This section is the retired Phase 7A/7D PCM5102 + PCM1808 reservation record.
Current PMOD JB ownership is the Pmod I2S2 assignment in section 3A. Do not use
the PCM rows below as current build instructions.

### 3.1 必須 5 pin (絶対に確保する)

| 論理名 | 方向 | 接続先 | 配置候補 |
| --- | --- | --- | --- |
| `EXT_AUDIO_MCLK` | FPGA out | PCM1808 `SCKI` (+ optionally PCM5102 `SCK`) | PMOD JB |
| `EXT_AUDIO_BCLK` | FPGA out | PCM1808 `BCK` + PCM5102 `BCK` | PMOD JB |
| `EXT_AUDIO_LRCLK` | FPGA out | PCM1808 `LRCK` + PCM5102 `LCK` | PMOD JB |
| `EXT_ADC_DOUT` | FPGA **in** | PCM1808 `DOUT` | PMOD JB |
| `EXT_DAC_DIN` | FPGA out | PCM5102 `DIN` | PMOD JB |

PMOD JB に **5 信号** をまとめる。
JB は 8 信号あるので、3 本余る (`SPARE0`, `SPARE1`, `SPARE2`)。

### 3.2 推奨追加 (PMOD JA に分散)

| 論理名 | 方向 | 接続先 | 配置候補 |
| --- | --- | --- | --- |
| `EXT_ADC_FMT` | FPGA out **or** strap | PCM1808 `FMT` (LOW=I2S, HIGH=left-justified) | PMOD JA **or** module 上 jumper で固定推奨 |
| `EXT_ADC_MD0` | FPGA out **or** strap | PCM1808 `MD0` | PMOD JA **or** strap (slave モード固定推奨) |
| `EXT_ADC_MD1` | FPGA out **or** strap | PCM1808 `MD1` | PMOD JA **or** strap |
| `EXT_DAC_XSMT` | FPGA out **or** pull-up | PCM5102 `XSMT` (mute) | PMOD JA **or** pull-up で常時 unmute |
| `EXT_CODEC_RESET_N` | FPGA out | (もし module が露出していれば) reset / enable | PMOD JA |
| `EXT_AUDIO_SPARE0..3` | reserved | 将来用 (DAC FLT / DMP / FMT 等) | PMOD JA |

**方針**:
- mode pin (`FMT` / `MD0` / `MD1`) は **module 上の jumper / strap で固定** することを第一候補にする。FPGA 出力で動的制御する必要は通常ない。
- `XSMT` は **pull-up で常時 unmute** が最も簡単。pop noise を厳密にコントロールしたい場合のみ FPGA 出力にする。
- `RESET` は module が露出していなければ不要。

### 3.3 最小 / 推奨ピン数まとめ

| シナリオ | ピン数 |
| --- | --- |
| 最小 (mode pin を全部 strap、XSMT を pull-up) | **5 pin** (PMOD JB 単独で収まる) |
| 推奨 (mode pin の一部を FPGA 制御、spare 数本) | **10 ~ 14 pin** (PMOD JB + JA で収まる) |

### 3.4 配置原則

- 外付け ADC / DAC 用 5 pin は **同一 PMOD 内 (PMOD JB) にまとめる** (clock skew 最小化)
- 追加 control / strap pin は別 PMOD (PMOD JA) に分散させてよい
- 同一 PMOD 内では、`BCLK` と `LRCLK` を隣接 pin にしてスキューを最小化
- `MCLK` は他 clock と隣接させすぎない (cross-talk 注意)
- `EXT_ADC_DOUT` は input pin、それ以外は output pin
- 3.3V LVCMOS33 で全 pin を統一
- 5V 信号を PL pin に直接入れない (level shifter or 3.3V module 必須)

### 3.5 XDC への落とし込み方針 (Phase 7B 以降)

```tcl
# 例 (Phase 7A 時点では未確定)
# set_property PACKAGE_PIN <pin> [get_ports {ext_audio_mclk}]
# set_property IOSTANDARD LVCMOS33 [get_ports {ext_audio_mclk}]
# create_generated_clock -name ext_audio_mclk -source [...] [get_ports ext_audio_mclk]
# create_generated_clock -name ext_audio_bclk -source [get_pins ext_audio_mclk] -divide_by 4 [get_ports ext_audio_bclk]
# set_input_delay  -clock ext_audio_bclk <delay_min> [get_ports ext_adc_dout]
```

実値は Phase 7B で確定する。

---

## 4. ロータリーエンコーダー 3 個のピン予約

### 4.1 実モジュールのシルク (Phase 7B 確定)

実モジュールのシルクは **`CLK` / `DT` / `SW` / `+` / `GND`** の 5 pin
(`DECISIONS.md` D31)。

| シルク | 役割 | 内部 quadrature 対応 |
| --- | --- | --- |
| `CLK` | quadrature **A 相** (回転で GND open/close) | A |
| `DT`  | quadrature **B 相** (回転で GND open/close、CLK と 90 度位相差) | B |
| `SW`  | push switch (押下で GND 短絡、active-low) | switch |
| `+`   | 電源ピン (**原則 3.3V**。GPIO ではない) | power |
| `GND` | グランド (GPIO ではない) | ground |

**内部 docs / register / driver では `A` / `B` 表記も使う場合あり**:
- `A = CLK`
- `B = DT`

ただし**外部配線表 / XDC 候補 / 物理配線指示は CLK / DT / SW 表記を優先**する。

### 4.2 論理信号名 (FPGA 側)

| 論理名 | 方向 | 接続先 (module pin) |
| --- | --- | --- |
| `ENC0_CLK` | FPGA in | encoder 0 `CLK` (A 相) |
| `ENC0_DT`  | FPGA in | encoder 0 `DT`  (B 相) |
| `ENC0_SW`  | FPGA in | encoder 0 `SW`  (push switch) |
| `ENC1_CLK` | FPGA in | encoder 1 `CLK` (A 相) |
| `ENC1_DT`  | FPGA in | encoder 1 `DT`  (B 相) |
| `ENC1_SW`  | FPGA in | encoder 1 `SW`  (push switch) |
| `ENC2_CLK` | FPGA in | encoder 2 `CLK` (A 相) |
| `ENC2_DT`  | FPGA in | encoder 2 `DT`  (B 相) |
| `ENC2_SW`  | FPGA in | encoder 2 `SW`  (push switch) |
| `ENC_3V3`  | power   | 全 encoder の `+` (PYNQ-Z2 **3.3V** rail のみ) |
| `ENC_GND`  | ground  | 全 encoder の `GND` (PYNQ-Z2 GND) |

= **9 GPIO 入力 + 1 電源 + 1 GND**。電源 / GND は PL GPIO として数えない。

### 4.3 電源ピン (`+`) と pull-up についての警告 (重要)

- `+` は **必ず 3.3V** に接続する。**5V に接続してはいけない** (`DECISIONS.md` D31)。
- 多くのロータリーエンコーダーモジュールは基板上に `CLK` / `DT` / `SW` の
  pull-up 抵抗を持ち、それは **`+` ピンに繋がっている**。
- もし `+` を 5V にしてしまうと、pull-up 経由で **`CLK` / `DT` / `SW` が 5V 化** し、
  PYNQ-Z2 PL pin (3.3V LVCMOS33 only) を**直撃**する。最悪の場合 PL pin が壊れる。
- したがって、`+` を 5V 化する選択肢は存在しない。安全に動作確認できる最初の
  電源は **3.3V のみ**。
- 3.3V で pull-up が弱い / 不安定 / レベルが浮く場合は、外付け pull-up
  (例: 10 kΩ → 3.3V) または PL 側 `set_property PULLUP true` で補強する。
- mechanical bounce 対策は **必須** (PL 側 debounce counter + 必要に応じて
  RC filter)。`ENCODER_GUI_CONTROL_SPEC.md` section 1 / 4 を参照。

### 4.4 確認方針 (Phase 7B 実モジュール確認)

実モジュールが手元に揃ったら、以下を実機 / テスター / オシロで確認する:

- `+` から `CLK` / `DT` / `SW` のいずれかへ pull-up 抵抗があるか (抵抗値 R)
- `+` の許容入力電圧範囲 (商品ページ / モジュール仕様)
- 回転時に `CLK` / `DT` が `GND` へ落ちるか (open contact)
- 押下時に `SW` が `GND` へ落ちるか (active-low)
- 1 回転あたりの detent 数
- 1 detent あたりの quadrature edge 数 (典型 4 edge)
- 内部 RC が無いタイプならば外付け debounce 検討

### 4.5 配置方針

- ADC / DAC 予約 pin (PMOD JB / JA) **とは分離する**
- encoder は低速 GPIO (kHz オーダー) なので、ADC / DAC より優先度の低い pin に配置
- 第一候補: **Raspberry Pi header** (40 pin、GPIO 多数で 9 本確保しやすい)
- 第二候補: **Arduino digital header** (digital pin が多い)
- 将来のフットスイッチ / LED / preset switch 追加を考えて、
  **最低 2 ~ 4 本の spare を残す**
- PMOD JA / JB を encoder で潰さない (audio 側拡張に温存)

### 4.6 重要 — PYNQ-Z2 board 上の **PMOD JA ⇄ Raspberry Pi 共有ピン**

PYNQ-Z2 の board file (`part0_pins.xml`、TUL board v1.0) を確認した結果、
**PMOD JA の 8 信号ピンは Raspberry Pi header GPIO の一部と物理的に
同じ FPGA package pin** にマップされている (TUL 設計上の共有):

| PMOD JA pin | Package | 共有先 (raspberry_pi_tri_i_*) |
| --- | --- | --- |
| `JA1`  | `Y18` | `raspberry_pi_tri_i_2` |
| `JA2`  | `Y19` | `raspberry_pi_tri_i_3` |
| `JA3`  | `Y16` | `respberry_sd_i` (RPi-side I2C 用) |
| `JA4`  | `Y17` | `respberry_sc_i` (RPi-side I2C 用) |
| `JA7`  | `U18` | `raspberry_pi_tri_i_4` |
| `JA8`  | `U19` | `raspberry_pi_tri_i_5` |
| `JA9`  | `W18` | `raspberry_pi_tri_i_0` |
| `JA10` | `W19` | `raspberry_pi_tri_i_1` |

意味:
- **PMOD JA を audio control / strap に使う pin は、同時に RPi GPIO として
  encoder には使えない**。逆も同じ。
- encoder を RPi header に置く場合、**`raspberry_pi_tri_i_6` 以降** (= JA と
  共有しない 19 pin: `F19, V10, V8, W10, B20, W8, V6, Y6, B19, U7, C20, Y8,
  A20, Y9, U8, W6, Y7, F20, W9`) を選ぶ。
- PMOD JB は PYNQ-Z2 上で他ヘッダと共有していないので audio 用に
  独立して使える。

---

## 3A. Pmod I2S2 current PMOD JB assignment (official pinout confirmed 2026-05-18, deployed D48+)

Digilent **Pmod I2S2** (CS4344 stereo DAC + CS5343 stereo ADC) は
PMOD JB の現行 active audio module。`audio_lab_pmod_i2s2.xdc` が
8 pin を制約し、`pmod_i2s2_integration.tcl` が D/A side と A/D side を
同一 FPGA-master clock tree から fanout する。Pmod I2S2 の PMOD pin
配置は公式 reference manual で **2026-05-18 に確定** 済。

| Pmod I2S2 Pin | Pmod I2S2 signal | PMOD JB pin | Package pin | 既存使用 (Phase 7D deploy) | Pmod I2S2 評価時の役割 | Confirmation |
| --- | --- | --- | --- | --- | --- | --- |
| Pin 1 | **D/A MCLK** | JB1 | W14 | `ext_audio_mclk_o = 1'b0` (PCM5102 SCK 構造的 GND、D40/D42) | DAC MCLK 12.288 MHz out — JB1 を 12.288 MHz に **戻す**、`pcm5102_audio_out` を build から外す前提 | **confirmed** |
| Pin 2 | **D/A LRCK** | JB2 | Y14 | `ext_audio_bclk_o = ADAU bclk` | DAC LRCK 48 kHz out (FPGA-master 生成、internal LRCK fanout) | **confirmed** |
| Pin 3 | **D/A SCLK / BCLK** | JB3 | T11 | `ext_audio_lrclk_o = ADAU lrclk` | DAC BCLK 3.072 MHz out (FPGA-master 生成、internal BCLK fanout) | **confirmed** |
| Pin 4 | **D/A SDIN** | JB4 | T10 | `ext_adc_dout_i` (PCM1808 DOUT 入力、D41) | DAC data 24-bit I2S Philips out — 既存方向 in → out に変わる | **confirmed** |
| Pin 5 | GND | (PMOD JB GND) | (PMOD JB GND) | GND | GND (共通) | **confirmed** |
| Pin 6 | VCC | (PMOD JB VCC) | (PMOD JB VCC) | 3.3V | 3.3V (Pmod I2S2 module 電源) | **confirmed** |
| Pin 7 | **A/D MCLK** | JB7 | V16 | `ext_dac_din_o` (PCM5102 DIN 出力、D39) | ADC MCLK 12.288 MHz out (internal MCLK fanout、D/A MCLK と同位相 / 同周波数) | **confirmed** |
| Pin 8 | **A/D LRCK** | JB8 | W16 | `ext_pcm1808_sckie_o` (PCM1808 SCKI 出力、D42) | ADC LRCK 48 kHz out (internal LRCK fanout) — 既存 SCKI 12.288 MHz から意味が変わる | **confirmed** |
| Pin 9 | **A/D SCLK / BCLK** | JB9 | V12 | spare | ADC BCLK 3.072 MHz out (internal BCLK fanout) | **confirmed** |
| Pin 10 | **A/D SDOUT** | JB10 | W13 | spare | ADC data 24-bit I2S Philips **in** — Pmod I2S2 経由の唯一の input | **confirmed** |
| Pin 11 | GND | (PMOD JB GND) | (PMOD JB GND) | GND | GND (Pin 5 と共有) | **confirmed** |
| Pin 12 | VCC | (PMOD JB VCC) | (PMOD JB VCC) | 3.3V | 3.3V (Pin 6 と共有) | **confirmed** |

前提:
- Pmod I2S2 評価時には既存 PCM5102 / PCM1808 のジャンパ配線を物理的
  に **外す**。PMOD JB を Pmod I2S2 module 1 個だけに専有させる。
- D/A 側 (Pin 1..4) と A/D 側 (Pin 7..10) は **物理的に別 pin** だが、
  FPGA 内部では 1 系統の `mclk_int` / `lrck_int` / `bclk_int` を fanout
  して D/A 側 (JB1/JB2/JB3) と A/D 側 (JB7/JB8/JB9) に並列出力する
  方針 (`PMOD_I2S2_INTEGRATION_PLAN.md` section 10 内部クロック木)。
  bit-true 同期になり、PCM5102 / PCM1808 で発生した async-clocks
  問題 (D40 / D41) は構造的に発生しない。
- Phase Pmod-1 では 48 kHz / 24-bit / 32-bit slot / stereo I2S Philips
  で開始する。96 kHz は Phase Pmod-5 (別 branch、後回し)。
- 本予約は **Phase Pmod-0 docs のみ**だったが、Phase Pmod-1 (2026-05-19、
  branch `feature/pmod-i2s2-bringup`、`DECISIONS.md` D48) で
  実装が入った。**Pmod I2S2 は PMOD JB の唯一の外付け audio
  module**。`hw/Pynq-Z2/audio_lab_pmod_i2s2.xdc` に Pmod I2S2 用の
  8 pin 制約 (LVCMOS33) を置き、`hw/Pynq-Z2/audio_lab.xdc` は ADAU +
  HDMI + encoder の universal 制約のみを残す。Pmod I2S2 の
  `pmod_i2s2_integration.tcl` は `create_project.tcl` から無条件に
  source される (env var 切替なし)。PCM5102 / PCM1808 用の
  `audio_lab_pcm.xdc` / `pcm5102_dac_integration.tcl` /
  `pcm1808_adc_integration.tcl` / PCM5102 / PCM1808 RTL は repo に
  archival で残るが build に入らない。
  `hw/Pynq-Z2/block_design.tcl` は依然として未編集。

---

## 4A. Historical candidate package pins, Phase 7B draft

下記の表は Phase 7B 当時の **候補** (`candidate`) 記録である。
現行 PMOD JB の実オーナーは section 3A の Pmod I2S2 であり、
PCM5102 / PCM1808 行は active build instructions ではない。

凡例:
- **IOSTANDARD**: 全 `LVCMOS33` 固定 (PYNQ-Z2 PL bank は 3.3V)
- **Status**: `reserved` = 物理共有 / 既存使用、`candidate` = 推奨第一候補、
  `needs physical verification` = 実モジュール / 配線確認待ち、
  `do not use` = 衝突あり禁止

### 4A.1 外付け audio (PMOD JB) — 推奨第一候補

| Logical signal | External module pin | Direction | Connector | Board pin | Package pin | IOSTANDARD | Pull plan | Notes | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `ext_audio_mclk_o`  | none (historical PCM5102 `SCK`) | out | PMOD JB | `JB1`  | `W14` | LVCMOS33 | none | **Phase 7D historical**: constant 0, PCM5102 `SCK` tied to GND / Low (D40 / D42). Current Pmod I2S2 uses this package pin as D/A MCLK; see section 3A. | **historical** |
| `ext_audio_bclk_o`  | PCM5102 `BCK` (+ later PCM1808 `BCK`)  | out | PMOD JB | `JB2`  | `Y14` | LVCMOS33 | none | Phase 7D historical; current Pmod I2S2 uses this pin as D/A LRCK. | **historical** |
| `ext_audio_lrclk_o` | PCM5102 `LCK` (+ later PCM1808 `LRCK`) | out | PMOD JB | `JB3`  | `T11` | LVCMOS33 | none | Phase 7D historical; current Pmod I2S2 uses this pin as D/A SCLK/BCLK. | **historical** |
| `ext_adc_dout_i`    | PCM1808 `DOUT`                         | **in** | PMOD JB | `JB4`  | `T10` | LVCMOS33 | none | Phase 7D historical; current Pmod I2S2 uses this pin as D/A SDIN output. | **historical** |
| `ext_dac_din_o`     | PCM5102 `DIN`                          | out | PMOD JB | `JB7`  | `V16` | LVCMOS33 | none | Phase 7D historical; current Pmod I2S2 uses this pin as A/D MCLK. | **historical** |
| `ext_pcm1808_sckie_o` | PCM1808 `SCKI` | out | PMOD JB | `JB8`  | `W16` | LVCMOS33 | none | Phase 7D historical; current Pmod I2S2 uses this pin as A/D LRCK. | **historical** |
| `EXT_AUDIO_SPARE_JB9`  | (将来用) | -- | PMOD JB | `JB9`  | `V12` | LVCMOS33 | -- | Phase 7B draft spare; current Pmod I2S2 uses this pin as A/D SCLK/BCLK. | **historical** |
| `EXT_AUDIO_SPARE_JB10` | (将来用) | -- | PMOD JB | `JB10` | `W13` | LVCMOS33 | -- | Phase 7B draft spare; current Pmod I2S2 uses this pin as A/D SDOUT input. | **historical** |
| (PMOD JB VCC) | `+3.3V` (PMOD power) | power | PMOD JB | `JB12` (PMOD VCC) | -- | -- | -- | module 側 VCC が 3.3V 受けの場合のみ | needs physical verification |
| (PMOD JB GND) | `GND` | ground | PMOD JB | `JB11` (PMOD GND) | -- | -- | -- | common GND | needs physical verification |

備考: PMOD JB は PYNQ-Z2 上で他ヘッダと共有していないため、**audio 専用に
独立確保**できる。PCM1808 / PCM5102 module の VCC が 5V 専用なら別 5V
rail を使い、I/O level を 3.3V に保つ仕様の module を選ぶ (実モジュール
確認、`EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md` section 3)。

### 4A.2 外付け audio 追加 control (PMOD JA) — 必要時のみ

PMOD JA を audio control / strap に使う場合は、**RPi header の同じ番号の
GPIO を encoder に使ってはいけない** (4.6 節の共有マップ参照)。可能なら
module 上の strap / jumper で固定して、PMOD JA を完全に空けるのが望ましい。

| Logical signal | External module pin | Direction | Connector | Board pin | Package pin | IOSTANDARD | Pull plan | Notes | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `EXT_ADC_FMT`       | PCM1808 `FMT`   | out / strap | PMOD JA | `JA1`  | `Y18` | LVCMOS33 | strap LOW for I2S | module jumper があれば**そちらを優先** | candidate (prefer strap) |
| `EXT_ADC_MD0`       | PCM1808 `MD0`   | out / strap | PMOD JA | `JA2`  | `Y19` | LVCMOS33 | strap slave-mode | module jumper を優先 | candidate (prefer strap) |
| `EXT_ADC_MD1`       | PCM1808 `MD1`   | out / strap | PMOD JA | `JA3`  | `Y16` | LVCMOS33 | strap slave-mode | module jumper を優先 | candidate (prefer strap) |
| `EXT_DAC_XSMT`      | PCM5102 `XSMT`  | out / pull  | PMOD JA | `JA4`  | `Y17` | LVCMOS33 | pull-up to 3.3V (unmute) | FPGA 駆動が必要な場合のみ | candidate (prefer pull-up) |
| `EXT_CODEC_RESET_N` | (module reset)  | out         | PMOD JA | `JA7`  | `U18` | LVCMOS33 | none | module が露出している場合のみ | candidate |
| `EXT_AUDIO_SPARE_JA8`  | (将来用) | -- | PMOD JA | `JA8`  | `U19` | LVCMOS33 | -- | spare | candidate |
| `EXT_AUDIO_SPARE_JA9`  | (将来用) | -- | PMOD JA | `JA9`  | `W18` | LVCMOS33 | -- | spare | candidate |
| `EXT_AUDIO_SPARE_JA10` | (将来用) | -- | PMOD JA | `JA10` | `W19` | LVCMOS33 | -- | spare | candidate |

注意: 上の表で PMOD JA を使うと、`raspberry_pi_tri_i_{0,1,2,3,4,5}` および
`respberry_sd_i` / `respberry_sc_i` が同時に使えなくなる (共有 pin)。
encoder を RPi header に置くなら、encoder には **`raspberry_pi_tri_i_6..24`** を
選ぶ (4.6 節)。

### 4A.3 Rotary encoder (Raspberry Pi header, JA と共有しない pin 群)

PYNQ-Z2 の RPi header のうち、**JA と共有しない 19 pin** を encoder に
使う。隣接 3 pin にまとめて配線しやすくする。

| Logical signal | External module pin | Direction | Connector | Board pin (RPi pin index) | Package pin | IOSTANDARD | Pull plan | Notes | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `ENC0_CLK` | encoder 0 `CLK` | in | RPi header | `raspberry_pi_tri_i_6`  | `F19` | LVCMOS33 | module pull-up to 3.3V + optional internal `PULLUP true` | A 相 | candidate / needs physical verification |
| `ENC0_DT`  | encoder 0 `DT`  | in | RPi header | `raspberry_pi_tri_i_7`  | `V10` | LVCMOS33 | 同上 | B 相 | candidate / needs physical verification |
| `ENC0_SW`  | encoder 0 `SW`  | in | RPi header | `raspberry_pi_tri_i_8`  | `V8`  | LVCMOS33 | 同上 | push, active-low | candidate / needs physical verification |
| `ENC1_CLK` | encoder 1 `CLK` | in | RPi header | `raspberry_pi_tri_i_9`  | `W10` | LVCMOS33 | 同上 | A 相 | candidate / needs physical verification |
| `ENC1_DT`  | encoder 1 `DT`  | in | RPi header | `raspberry_pi_tri_i_10` | `B20` | LVCMOS33 | 同上 | B 相 | candidate / needs physical verification |
| `ENC1_SW`  | encoder 1 `SW`  | in | RPi header | `raspberry_pi_tri_i_11` | `W8`  | LVCMOS33 | 同上 | push, active-low | candidate / needs physical verification |
| `ENC2_CLK` | encoder 2 `CLK` | in | RPi header | `raspberry_pi_tri_i_12` | `V6`  | LVCMOS33 | 同上 | A 相 | candidate / needs physical verification |
| `ENC2_DT`  | encoder 2 `DT`  | in | RPi header | `raspberry_pi_tri_i_13` | `Y6`  | LVCMOS33 | 同上 | B 相 | candidate / needs physical verification |
| `ENC2_SW`  | encoder 2 `SW`  | in | RPi header | `raspberry_pi_tri_i_14` | `B19` | LVCMOS33 | 同上 | push, active-low | candidate / needs physical verification |
| `ENC_3V3`  | 全 encoder `+`   | power  | RPi header | RPi pin 1 or 17 (3V3) | -- | -- | -- | **必ず 3.3V**。5V 禁止 (`DECISIONS.md` D31) | reserved |
| `ENC_GND`  | 全 encoder `GND` | ground | RPi header | RPi GND pins (複数) | -- | -- | -- | 共通 GND | reserved |
| `SPARE_GPIO0` | -- | in/out | RPi header | `raspberry_pi_tri_i_15` | `U7`  | LVCMOS33 | -- | 将来のフットスイッチ / LED | candidate |
| `SPARE_GPIO1` | -- | in/out | RPi header | `raspberry_pi_tri_i_16` | `C20` | LVCMOS33 | -- | spare | candidate |
| `SPARE_GPIO2` | -- | in/out | RPi header | `raspberry_pi_tri_i_17` | `Y8`  | LVCMOS33 | -- | spare | candidate |
| `SPARE_GPIO3` | -- | in/out | RPi header | `raspberry_pi_tri_i_18` | `A20` | LVCMOS33 | -- | spare | candidate |

残り `raspberry_pi_tri_i_19..24` (`Y9, U8, W6, Y7, F20, W9`) も将来用に空けておく。

### 4A.4 共有 / 禁止 pin (Phase 7B 時点で encoder には使わない)

| Pin / range | 共有 / 既存使用 | 理由 |
| --- | --- | --- |
| `raspberry_pi_tri_i_0..5` | PMOD JA (`JA9 / JA10 / JA1 / JA2 / JA7 / JA8`) と物理共有 | PMOD JA を audio control に使うため、encoder には割当てない | reserved (PMOD JA) |
| `respberry_sd_i` (Y16) / `respberry_sc_i` (Y17) | PMOD JA (`JA3 / JA4`) と物理共有 | 同上 | reserved (PMOD JA) |
| HDMI TX (`L16 / L17 / K17 / K18 / K19 / J19 / J18 / H18`) | HDMI 経路 | HDMI を壊さない | do not use |
| HDMI RX (`N18 / P19 / V20 / T20 / N20 / W20 / U20 / P20`) | HDMI RX | 将来用に予約 (encoder には使わない) | do not use |
| HDMI HPD / DDC / CEC (`R19, T19, U14, U15, G15`) | HDMI 制御 | encoder には使わない | do not use |
| ADAU1761 (`U5, M17, M18, U9, T9, F17, G18, R18, T17`) | onboard codec | 既存 audio 経路を壊さない | do not use |
| BTN / LED / SW / RGB LED 群 | board 既定 | Phase 7G で encoder と併用検討、Phase 7B では touch しない | do not use (Phase 7B) |

### 4A.5 Arduino header — analog / spare (Phase 7G 以降)

| Logical signal | Connector | Board pin | Package pin | IOSTANDARD | Notes | Status |
| --- | --- | --- | --- | --- | --- | --- |
| (footswitch / LED / spare) | Arduino digital | `arduino_a0_a13_tri_i_0..13` | `T14, U12, U13, V13, V15, T15, R16, U17, V17, V18, T16, R17, P18, N17` | LVCMOS33 | Phase 7G 以降の拡張用 | reserved |
| A0 / FP02M pedal | Arduino analog | `arduino_a0` header signal / `Vaux1_v_p,n` | header digital view `Y11`; XADC analog pins `E17,D18` | analog VAUX1 | D76 accepted: `xadc_wiz_a0 @ 0x43D40000` reads FP02M Wah POSITION via AXI MMIO。`Y11` は board entry の digital view で、XDC は `E17/D18` を使う | in use |
| (analog spare) | Arduino analog | `arduino_a1..a5` | `W11, V11, T5, U10, U5` | analog VAUX | 将来 XADC 用途 | reserved |

---

## 5. ピン衝突回避方針

### 5.1 既存使用済み pin (絶対に避ける)

- ADAU1761: `U5, M17, M18, U9, T9, F17, G18, R18, T17`
- HDMI: `L16, L17, K17, K18, K19, J19, J18, H18`

### 5.2 PYNQ-Z2 board 上の bank / 電圧

- すべての user IO は **3.3V LVCMOS33** で統一
- bank 電源は PYNQ-Z2 既定 (3.3V) のまま変更しない
- **5V 信号を PL pin に直接接続しない** (level shifter 必須)

### 5.3 BTN / SW / LED の扱い

- PYNQ-Z2 onboard BTN / SW / LED の pin は board file に定義あり
- Phase 7A 時点では使わない (encoder で代替するため)
- ただし、debug / status 用に LED を 1 ~ 2 本使う案は Phase 7G で検討

### 5.4 disallow リスト

以下の pin は Phase 7 でも touch しない:
- ADAU1761 経路 (前述)
- HDMI 経路 (前述)
- PS DDR / PS I/O 関連 (board fixed)
- HDMI hot-plug / I2C (board file 由来)
- HDMI RX 系統 (将来用なので予約しない)

---

## 6. 予約信号一覧 (まとめ)

### 6.1 外付け audio (Phase 7B ~ 7E で実装)

```
EXT_AUDIO_MCLK    (out, constant 0 on JB1; do not wire to PCM5102 SCK)
EXT_AUDIO_BCLK    (out, PCM1808 BCK + PCM5102 BCK)
EXT_AUDIO_LRCLK   (out, PCM1808 LRCK + PCM5102 LCK)
EXT_ADC_DOUT      (in,  PCM1808 DOUT)
EXT_DAC_DIN       (out, PCM5102 DIN)
EXT_PCM1808_SCKI  (out, PCM1808 SCKI on JB8 when PCM1808 clock is enabled)
EXT_ADC_FMT       (optional out / strap)
EXT_ADC_MD0       (optional out / strap)
EXT_ADC_MD1       (optional out / strap)
EXT_DAC_XSMT      (optional out / pull-up)
EXT_CODEC_RESET_N (optional)
EXT_AUDIO_SPARE0..3
```

### 6.2 Encoder + spare GPIO (Phase 7F で実装)

```
ENC0_CLK, ENC0_DT, ENC0_SW
ENC1_CLK, ENC1_DT, ENC1_SW
ENC2_CLK, ENC2_DT, ENC2_SW
ENC_3V3   (3.3V power, NOT GPIO)
ENC_GND   (GND, NOT GPIO)
SPARE_GPIO0..3 (将来のフットスイッチ / LED)
```

合計 9 GPIO + 電源 / GND + spare = Raspberry Pi header の **JA と
共有しない pin 群** (`raspberry_pi_tri_i_6..18` 程度) で予約する。
`+` は **3.3V 専用** (5V 禁止、`DECISIONS.md` D31)。

---

## 7. Phase 7B での状態 (historical)

- 当時の本ドキュメントは **論理予約 + 候補 package pin 表** (`Status` は
  `candidate` / `needs physical verification` / `reserved` のいずれか)
- `hw/Pynq-Z2/audio_lab.xdc` は **未変更**
- `hw/Pynq-Z2/block_design.tcl` は **未変更**
- bit / hwh は **未再生成**
- 実モジュール (PCM1808 / PCM5102 / rotary encoder) の物理確認が
  終わったら Phase 7C で XDC へ反映する計画だった (確認項目は
  `EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md` section 11 と
  本ドキュメント section 4.4)
- encoder 用 AXI IP の base address は **TBD** (Phase 7F で確定)。
  `0x43CE0000` (`axi_vdma_hdmi`) と `0x43CF0000` (`v_tc_hdmi`) は
  **禁止** (`DECISIONS.md` D32)

## 8. Current deployed state after Phase 7F/7G and D48+ (encoder + Pmod I2S2)

- `hw/Pynq-Z2/audio_lab.xdc` に encoder 9 pin を追加済み:
  `F19 / V10 / V8` (`ENC0_CLK / DT / SW`),
  `W10 / B20 / W8` (`ENC1_*`),
  `V6 / Y6 / B19` (`ENC2_*`)。すべて `LVCMOS33`。
  `PULLUP` は付けていない (典型 module は基板上 pull-up あり、必要なら
  `set_property PULLUP true` または外付け 10 kΩ で補強)。
- PMOD JB は **Pmod I2S2 active audio path として配線済み / 制約済み**。
  `audio_lab_pmod_i2s2.xdc` が `JB1..JB4 / JB7..JB10` を Pmod I2S2
  D/A + A/D side に割り当てる。PCM5102 / PCM1808 予約は retired /
  archival。
- encoder PL IP `axi_encoder_input` は base address **`0x43D10000`** に
  確定 (`DECISIONS.md` D32 の禁止リスト = `0x43CE0000` / `0x43CF0000` /
  `0x43D00000` を回避)。
- block_design.tcl は変更なし。`hw/Pynq-Z2/encoder_integration.tcl` を
  追加し、`hdmi_integration.tcl` と同じパターンで `create_project.tcl`
  から source する。
- Pmod I2S2 status/control slave `pmod_status_0` は base address
  **`0x43D20000`**。MODE 0/1/2/3 (`tone` / `loopback` / `dsp` / `mute`)
  を `scripts/pmod_i2s2_mode.py` と
  `scripts/test_pmod_i2s2.py` から操作する。
- `hw/Pynq-Z2/block_design.tcl` は変更なし。Pmod I2S2 追加・reroute は
  `hw/Pynq-Z2/pmod_i2s2_integration.tcl` で行う。
- **Footswitch (D78, deployed, audio clean):** 3 個の 3PDT footswitch を
  **Raspberry Pi ヘッダ**に配置。**物理ピンは公式 PYNQ-Z2 master XDC の
  schematic net 名 (`Sch=rpio_NN_r`, NN = BCM GPIO) で確定:**
  `fsw0_i`=FX=`U7`=`rpio_17`=GPIO17=**RP pin 11**,
  `fsw1_i`=next=`C20`=`rpio_18`=GPIO18=**RP pin 12**,
  `fsw2_i`=prev=`Y8`=`rpio_19`=GPIO19=**RP pin 35**。GND は RP の
  6/9/14/20/25/30/34/39 のいずれか。すべて `LVCMOS33` + `PULLUP true`
  (3PDT は common→RP信号pin / 一方 throw→GND / 他方 open)。RP 40pin の BCM
  "GPIOxx" シルク / v1.0 マニュアルは誤り易いので物理ピン位置で数えること
  (確認は loaded bit で `FootswitchInput.read_levels()`)。新 IP
  `axi_footswitch_input` は base `0x43D50000` (M21)、
  `footswitch_integration.tcl`、NUM_MI 21→22、`block_design.tcl` 不編集、
  DSP island 不変。**ビットクラッシャー対策**: AXI マスタ追加で 50MHz DSP島
  の DS-1 演算タイミングが悪化し ADC→DSP→DAC にビットクラッシャーが出たため、
  `create_project.tcl` の impl_1 に post-place/post-route `phys_opt_design`
  (AggressiveExplore) を追加し島 WNS を -0.173ns (D76 超え) に回復、音声クリーン
  確認。accepted bit `45e78763`。中間で PMOD JA (Y18/Y19/U18) 版も bench 済だが
  RP へ移行。詳細は `FOOTSWITCH_INTEGRATION.md` / `DECISIONS.md` D78 /
  [[project_pynqz2_rp_header_silk_not_package_pin]]。
