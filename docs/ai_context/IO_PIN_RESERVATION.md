# IO pin reservation (Phase 7A planning)

PYNQ-Z2 の **未使用 IO pin** を Phase 7 (外付け PCM1808 ADC、
PCM5102 DAC、ロータリーエンコーダー 3 個) のためにどう予約するかを
記録する。

**このドキュメントは予約 (reservation) であり、XDC への実ピン書込み
ではない**。`hw/Pynq-Z2/audio_lab.xdc` は Phase 7A の間は触らない
(`DECISIONS.md` D28)。実ピン番号は Phase 7B 以降に確定する。

関連:
- `docs/ai_context/EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md` (PCM1808 / PCM5102 設計)
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
| **PMOD JB** | 8 信号 + GND + 3.3V (clean 8-pin block) | **外付け I2S audio (PCM1808 + PCM5102)** |
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

## 3. 外付け audio (PCM1808 + PCM5102) ピン予約

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

### 4.1 信号一覧

3 個の rotary encoder (各 A / B / SW、push-switch 付):

| 論理名 | 方向 | 接続先 |
| --- | --- | --- |
| `ENC0_A` | FPGA in | encoder 0 channel A |
| `ENC0_B` | FPGA in | encoder 0 channel B |
| `ENC0_SW` | FPGA in | encoder 0 push switch |
| `ENC1_A` | FPGA in | encoder 1 channel A |
| `ENC1_B` | FPGA in | encoder 1 channel B |
| `ENC1_SW` | FPGA in | encoder 1 push switch |
| `ENC2_A` | FPGA in | encoder 2 channel A |
| `ENC2_B` | FPGA in | encoder 2 channel B |
| `ENC2_SW` | FPGA in | encoder 2 push switch |

= **9 GPIO 入力**

共通配線:
- GND common
- 3.3V common
- pull-up / pull-down は要検討:
  - 一般的に encoder は open-drain / open-collector ではないので、
    A / B は両側 pull-up (内部 or 外付け) で active-low
  - SW (push-switch) も pull-up + GND 短絡 (active-low) が一般的
  - PYNQ-Z2 PL pin は internal pull-up 設定可 (`PULLUP true`)、
    ただしハードウェア debounce 用に外付け RC があると安定する
- mechanical debounce **必須** (RC filter + PL 側 debounce counter)

### 4.2 配置方針

- ADC / DAC 予約 pin (PMOD JB / JA) **とは分離する**
- encoder は低速 GPIO (kHz オーダー) なので、ADC / DAC より優先度の低い pin に配置
- 第一候補: **Raspberry Pi header** (40 pin、GPIO 多数で 9 本確保しやすい)
- 第二候補: **Arduino digital header** (digital pin が多い)
- 将来のフットスイッチ / LED / preset switch 追加を考えて、
  **最低 2 ~ 4 本の spare を残す**
- PMOD JA / JB を encoder で潰さない (audio 側拡張に温存)

### 4.3 配置例 (Phase 7B で確定)

| 信号 | 配置候補ヘッダ | 備考 |
| --- | --- | --- |
| `ENC0_A` / `ENC0_B` / `ENC0_SW` | Raspberry Pi header GPIO group A | 隣接 3 pin にまとめる |
| `ENC1_A` / `ENC1_B` / `ENC1_SW` | Raspberry Pi header GPIO group B | 隣接 3 pin にまとめる |
| `ENC2_A` / `ENC2_B` / `ENC2_SW` | Raspberry Pi header GPIO group C | 隣接 3 pin にまとめる |
| `SPARE_GPIO0..3` | Raspberry Pi header or Arduino digital | 将来のフットスイッチ / LED |

実 Package Pin は Phase 7B で board file を参照して確定する。

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
EXT_AUDIO_MCLK    (out, PCM1808 SCKI)
EXT_AUDIO_BCLK    (out, PCM1808 BCK + PCM5102 BCK)
EXT_AUDIO_LRCLK   (out, PCM1808 LRCK + PCM5102 LCK)
EXT_ADC_DOUT      (in,  PCM1808 DOUT)
EXT_DAC_DIN       (out, PCM5102 DIN)
EXT_ADC_FMT       (optional out / strap)
EXT_ADC_MD0       (optional out / strap)
EXT_ADC_MD1       (optional out / strap)
EXT_DAC_XSMT      (optional out / pull-up)
EXT_CODEC_RESET_N (optional)
EXT_AUDIO_SPARE0..3
```

### 6.2 Encoder + spare GPIO (Phase 7F で実装)

```
ENC0_A, ENC0_B, ENC0_SW
ENC1_A, ENC1_B, ENC1_SW
ENC2_A, ENC2_B, ENC2_SW
SPARE_GPIO0..3 (将来のフットスイッチ / LED)
```

合計 9 + spare = **13 pin** 程度を Raspberry Pi header で予約する。

---

## 7. Phase 7A での状態

- 本ドキュメントは **論理予約のみ**
- `hw/Pynq-Z2/audio_lab.xdc` は **未変更**
- `hw/Pynq-Z2/block_design.tcl` は **未変更**
- bit / hwh は **未再生成**
- Phase 7B で実 Package Pin を確定し、XDC へ反映する
