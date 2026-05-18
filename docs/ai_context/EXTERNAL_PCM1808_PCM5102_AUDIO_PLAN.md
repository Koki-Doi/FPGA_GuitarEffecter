# External PCM1808 / PCM5102 audio path plan + Phase 7C/7E/7D close-out

このドキュメントは元々 **Phase 7A 設計フェーズ**として書かれた
(セクション 1 〜 8 がその名残)。Phase 7C / 7E / 7D を経て **PCM5102
DAC 並列出力は deployed**、**PCM1808 ADC mux は build-time 実装済 + JB
配線済だが deploy bit は ADAU フォールバック**まで進んでいる。最新
状況の要約はセクション 9 (実装計画兼進捗ログ) と
`docs/ai_context/CURRENT_STATE.md` 冒頭、決定事項は
`DECISIONS.md` D38 / D39 / D40 / D41 / D42 / D43 / D44 を参照する。

**Pmod I2S2 への発展計画 (Phase Pmod-0, planning only)**:
PCM1808 module は analog 前段 damage 仮説 (`DECISIONS.md` D43) で
事実上 retire 状態、PCM5102 line out は JB7 / JB8 隣接クロストーク
疑い (`DECISIONS.md` D44)。次の評価ステップは **Digilent Pmod I2S2**
(CS4344 stereo DAC + CS5343 stereo ADC on 1 PMOD board) を PMOD JB
に直挿しして外付け I2S I/O のリファレンスにする案で、`DECISIONS.md`
D45 にプランのみ記録、詳細は
`docs/ai_context/PMOD_I2S2_INTEGRATION_PLAN.md`。本ドキュメント (PCM5102
/ PCM1808 計画) と Pmod I2S2 plan は **共存**: Pmod I2S2 評価時には
PMOD JB を Pmod I2S2 専用にして既存 PCM5102 / PCM1808 ジャンパを物理
的に外す build variant 方針。

関連:
- `docs/ai_context/IO_PIN_RESERVATION.md` (ピン予約台帳、`Status` =
  `wired` の行が Phase 7C / 7D 反映済)
- `docs/ai_context/ENCODER_GUI_CONTROL_SPEC.md` (ロータリーエンコーダー仕様)
- `docs/ai_context/AUDIO_SIGNAL_PATH.md` (PCM5102 並列出力 + PCM1808
  build-time mux 入力の信号経路図)
- `docs/ai_context/CURRENT_STATE.md` / `DECISIONS.md` (D27 / D28 / D29 /
  D30、Phase 7C/7E/7D ぶんは D38 / D39 / D40 / D41 / D42 / D43 / D44)

---

## 1. 目的

PYNQ-Z2 ボード搭載の ADAU1761 codec に加えて、外付け I2S audio
モジュールを使う前提を整える。

- ADC: Youmile **PCM1808** (24-bit stereo, single-ended line-level)
- DAC: **PCM5102 / PCM5102A** (24-bit stereo, I2S input)

Phase 7A はピン予約 / 仕様設計のみ。**ADAU1761 経路は破壊しない**。
即置換も行わない。外付け I2S audio path は別パスとして追加 (後述
セクション 7)。

---

## 2. 使用予定デバイス

### 2.1 ADC: PCM1808

- 24-bit Σ-Δ stereo ADC
- single-ended analog input (line-level 想定)
- I2S 出力可
- master / slave モード選択可 (`MD0` / `MD1`)
- system clock (`SCKI`) 要供給 (PCM1808 は基本 SCKI 必須)
- `FMT` pin で I2S / left-justified を選択
- 信号: `BCK` / `LRCK` / `DOUT` / `SCKI` / `FMT` / `MD0` / `MD1`
- アナログ電源 / デジタル電源は基板ロットにより構成が異なる

### 2.2 DAC: PCM5102 / PCM5102A

- 24-bit Σ-Δ stereo DAC
- I2S 入力
- 信号: `DIN` / `BCK` / `LRCK`
- 内蔵 PLL を持つ系統 (PCM510x) は外部 MCLK なしでも動作可能
- module によっては `SCK` / `MCLK` ピンを露出
- `XSMT` (soft mute) を露出する module もある
- `FLT` (filter) / `DMP` (de-emphasis) / `FMT` (format) を露出する系統もある

---

## 3. 実モジュールに対する注意 (must verify before wiring)

Amazon 等で売られている PCM1808 / PCM5102 モジュールは、
販売ページや基板ロットによってシルク / ジャンパ / 既定モード /
電源系統が異なる。**実装前に必ず以下を実物で確認する**。

PCM1808 module:
- module silkscreen pin labels (`SCK` vs `SCKI` vs `MCK` 表記揺れあり)
- `VCC` 許容電圧 (5V module / 3.3V module の両方が存在)
- I/O level (PYNQ-Z2 PL は 3.3V LVCMOS。**5V を直接 PL pin に入れない**)
- `MD0` / `MD1` の既定 strap (slave モード固定 strap か否か)
- `FMT` の既定 strap (I2S か left-justified か)
- `SCKI` ピンの実存と接続要否
- onboard regulator の有無
- analog input の AC 結合 / DC 結合 / 入力 impedance
- ギター直結を想定した入力バッファの有無 (基本なし)

PCM5102 module:
- module silkscreen pin labels (`DIN` / `BCK` / `LCK` / `SCK` / `XSMT` / `FLT` / `DMP` 等)
- `VCC` 許容電圧
- I/O level (3.3V tolerant か / 5V tolerant か)
- `SCK` (MCLK) ピンを露出しているか / GND 接続が既定か
- `XSMT` の既定状態 (mute / unmute pull)
- `FLT` / `DMP` / `FMT` の既定 strap
- onboard regulator の有無
- output が AC 結合か / DC 結合か
- output レベル / output impedance / headphone 直接駆動可否

これらが確認できる前に XDC / block_design は触らない。
Phase 7B のチェックリストとして再掲する。

---

## 4. 推奨クロック構成

**PYNQ-Z2 / FPGA 側を I2S clock master にする**。

理由:
- PCM1808 と PCM5102 を同じ `BCLK` / `LRCLK` で同期できる
- FPGA DSP pipeline の sample rate を固定しやすい (`AudioDomain` に整合)
- ADAU1761 経路 (既存) と比較しやすい
- Python / GUI 側から sample rate を変更しない前提にできる
- 既存 DSP は `48 kHz` 前提なので、外付けパスも 48 kHz 固定が妥当

Target audio format:
- sample rate: **48 kHz**
- word length: **24-bit**
- frame: stereo (L + R, 64-bit frame)
- `BCLK` = `64 * fs` = **3.072 MHz**
- `MCLK / SCKI` 候補:
  - `256 * fs` = **12.288 MHz** (推奨候補。最も一般的)
  - `384 * fs` = **18.432 MHz** (PCM1808 の高 SNR モード)
  - `512 * fs` = **24.576 MHz** (上限寄り)

Clock distribution:
- `EXT_AUDIO_MCLK` (FPGA out)
  - PCM1808 `SCKI` へ供給
  - PCM5102 `SCK` (MCLK) へ供給するかは module 仕様で決定
    (PCM5102 module 系は SCK を GND 落としで内部 PLL 駆動の構成が多い)
- `EXT_AUDIO_BCLK` (FPGA out)
  - PCM1808 `BCK` + PCM5102 `BCK` 同一ネット
- `EXT_AUDIO_LRCLK` (FPGA out)
  - PCM1808 `LRCK` + PCM5102 `LCK` 同一ネット
- `EXT_ADC_DOUT` (FPGA in)
  - PCM1808 `DOUT` → FPGA
- `EXT_DAC_DIN` (FPGA out)
  - FPGA → PCM5102 `DIN`

Mode recommendation:
- PCM1808:
  - **slave mode** 固定 (master は FPGA)
  - `FMT` = I2S 24-bit
  - `MD0` / `MD1` は slave モードに固定。可能なら **fixed strap** (基板上の pull / jumper)
  - `SCKI` = `12.288 MHz` (256fs) を第一候補とする
- PCM5102:
  - I2S 入力 3-wire (`BCK` / `LCK` / `DIN`)
  - `SCK` (MCLK) は module 仕様に従う (GND 落としで内蔵 PLL 駆動 / 12.288 MHz 駆動のどちらも可)
  - `XSMT` は有効状態 (unmute) に pull up または FPGA から制御
  - `FLT` / `DMP` / `FMT` は工場既定で良い場合は触らない

XDC への落とし込み (Phase 7B 以降):
- すべて `IOSTANDARD LVCMOS33`
- `BCLK` / `LRCLK` / `MCLK` は generated clock として宣言する
- `BCLK` / `LRCLK` / `MCLK` 間は `create_generated_clock` で同期関係を明示
- `EXT_ADC_DOUT` は input delay 制約が必要 (PCM1808 の DOUT 遅延仕様参照)

---

## 5. PCM1808 アナログ入力の注意 (guitar 直結は NG)

PCM1808 module **そのものはギター入力の前段ではない**。
ギターを直接 PCM1808 アナログ入力に挿してはいけない。

理由:
- PCM1808 の入力は line-level single-ended (典型 2 Vpp 程度)
- ギターのピックアップは高インピーダンス源 (passive pickup で
  数百 kΩ ~ 数 MΩ 入力推奨)
- PCM1808 module の入力 impedance は数十 kΩ クラスが多く、
  passive pickup を直結するとハイ落ち / レベル不足 / S/N 悪化

ギターを入れる場合に必要な analog front-end:
1. **input buffer** (JFET / op-amp、入力 impedance 500 kΩ ~ 1 MΩ)
2. **AC coupling** (DC blocking cap)
3. **biasing** to PCM1808 入力 common-mode (典型 VCOM ~ 2.4 V)
4. **gain control** (line-level まで持ち上げる: 約 +20 dB)
5. **anti-alias low-pass filter** (`fs/2 = 24 kHz` 以下で十分減衰)
6. **clipping protection** (双方向 diode clamp、TVS 等)

Phase 7C / 7D ではまず以下で検証する:
- function generator / 別 audio interface の line-out を PCM1808 へ
- PCM1808 → FPGA loopback (sample が正しく取れるかだけを確認)
- ギター直結は Phase 7E 以降の analog front-end 設計に分ける

---

## 6. PCM5102 アナログ出力の注意

PCM5102 module の出力は **line out** として扱う。

注意点:
- headphone を直接大音量で駆動する前提にしない (基板により
  output buffer 構成が違う。低 impedance ヘッドホンを直接駆動できる
  保証はない)
- 必要に応じて headphone amp / output buffer を追加する
- ギターアンプ入力へ入れる場合は:
  - レベル調整 (PCM5102 line out → アンプ input)
  - DC 結合 / AC 結合の確認
  - 保護抵抗 / TVS clamp
- power-on / power-off の pop noise:
  - `XSMT` をデジタル制御して mute → unmute シーケンスを取る
  - PCM5102 内蔵の pop reduction も併用
- analog GND / digital GND / power supply noise:
  - PYNQ-Z2 の 3.3V / 5V から取る場合、digital noise が乗りやすい
  - 必要なら別 LDO + LC filter で audio 用電源を分離

---

## 7. 既存 ADAU1761 経路との関係

Phase 7 では PCM1808 / PCM5102 は **既存 ADAU1761 の即置換ではない**。
まず **外付け I2S audio path を別系統として追加** する設計にする。

選択肢:
- **A.** ADAU1761 path を維持しつつ、外付け PCM1808 / PCM5102 を別 I2S path として追加
- **B.** ADAU1761 path を停止して外付け PCM1808 / PCM5102 に切替
- **C.** compile-time parameter で A / B を選ぶ
- **D.** runtime 切替 (Python から選択)

**Phase 7B では A または C を推奨**。

理由:
- 既存動作 (ADAU1761 path) を壊さずに ext path を比較できる
- 既存テスト / 既存 GUI / 既存 notebook が無回帰
- rollback が容易 (XDC / block_design 変更を bypass しても ADAU1761 が動く)
- 音質 / ノイズフロア / latency を ADAU1761 vs 外付けで比較できる
- GPIO / DSP / Python API への影響を分離できる

設計指針:
- Clash 内 DSP block は **入出力 codec に対して透過** にする
  (現状の `topEntity` の audio 入出力 streaming I/F を増やすか、
  block_design 上で AXIS switch を追加するか)
- どちらの codec を使うかは block_design + Python API の責務
- DSP 本体 (`LowPassFir.hs`) は変更しない (`DECISIONS.md` D27)

Phase 7E まで A / C を維持し、外付けパスが完全に動いてから D / B の
検討を始める。Phase 7A 時点で B を選ぶ理由はない。

---

## 8. ピン予約サマリ

詳細は `docs/ai_context/IO_PIN_RESERVATION.md` を参照。

最低必要 (Mode pin を strap で固定する場合):
- `EXT_AUDIO_MCLK` (FPGA out)
- `EXT_AUDIO_BCLK` (FPGA out)
- `EXT_AUDIO_LRCLK` (FPGA out)
- `EXT_ADC_DOUT` (FPGA in)
- `EXT_DAC_DIN` (FPGA out)
= **5 pin**

推奨予約 (mode/strap を FPGA 制御または spare まで含める):
- 上記 5 pin
- `EXT_ADC_FMT` / `EXT_ADC_MD0` / `EXT_ADC_MD1` (PCM1808 mode、可能なら strap)
- `EXT_DAC_XSMT` (PCM5102 mute、可能なら strap または FPGA 出力)
- `EXT_CODEC_RESET_N` (module が露出するなら)
- `EXT_AUDIO_SPARE0..3` (将来の追加 codec 制御)
= 10 ~ 14 pin

方針:
- 外付け ADC / DAC ピンは同一 PMOD / 隣接ピン群にまとめる
- ロータリーエンコーダー用 GPIO は **後回し** (本ドキュメントは
  ADC/DAC を優先する旨を明記)
- 3.3V LVCMOS33 前提
- 5V 信号を PL pin に直接入れない
- 既存 ADAU1761 / HDMI / I2C pin と衝突しない

候補コネクタの優先順位 (PYNQ-Z2 上の未使用ヘッダ):
1. **PMOD JB** (clean 8-pin block、PYNQ-Z2 上位置で配線しやすい) → 外付け I2S audio をまとめて配置
2. **PMOD JA** (もう一つの clean 8-pin block) → 追加 control pin / spare
3. **Raspberry Pi header** (40-pin、GPIO 多数) → encoder 等の低速 GPIO
4. **Arduino digital / analog header** → spare / 将来のフットスイッチ

詳細ピン番号は Phase 7B で確定する (Phase 7A では確定しない)。

---

## 9. 段階的実装計画 (Phase 7A ~ 7H)

### Phase 7A (本フェーズ): planning only
- PCM1808 / PCM5102 module plan
- external audio pin reservation (this doc + IO_PIN_RESERVATION.md)
- rotary encoder pin reservation
- encoder GUI control spec
- **NO** XDC / block_design / bit / hwh change
- **NO** Vivado build

### Phase 7B: module verification + XDC candidate
- 実モジュール silkscreen / strap / 電源を確認
- 候補コネクタ + 候補ピン番号を確定
- XDC 候補 (まだ commit しない / または承認後に commit)
- 外付け I2S interface module の Clash / VHDL 側設計初稿
- DSP 置換はしない

### Phase 7C: PCM5102 DAC 出力の loopback prototype — **LANDED (DAC-only, free-running)**
- PCM5102 DAC を先に動かす — **済**
- FPGA / PS path から sine / sweep を生成して PCM5102 へ送る — **PL 内で 1 kHz 正弦を free-running 生成 (`pcm5102_dac_tone`, DECISIONS.md D38)**
- BCLK / LRCK / DIN をオシロ / logic analyzer で確認 — **手作業残**
- DAC アナログ出力を計測 (line out → audio interface input) — **手作業残**
- 新規物: RTL `hw/ip/pcm5102_dac_tone/src/pcm5102_dac_tone.v`、新 MMCM
  `clk_wiz_audio_ext` (100 MHz → 12.288 MHz exact)、tcl
  `hw/Pynq-Z2/pcm5102_dac_integration.tcl`、XDC 4 pin、smoke
  `scripts/test_pcm5102_dac_tone.py`。AXI-Lite なし。GPIO_CONTROL_MAP
  契約変更なし。ADAU1761 / HDMI / encoder すべて未変更。bit/hwh 再生成 +
  deploy 済 (smoke PASS)。

### Phase 7D: PCM1808 ADC 入力の loopback prototype — **LANDED w/ mux=ADAU fallback; PCM1808 hardware diagnosis pending**
- line-level signal を PCM1808 へ入れる — 試した。スマホ line out 接続
  でも PCM1808 `capture-adc` は pure 0 (DECISIONS.md D43)。
- I2S DOUT を FPGA で取り込み、PS へ転送 — **済**。新規 2:1 wire mux
  `hw/ip/pcm1808_adc_input/src/pcm1808_input_select.v` を ADAU `sdata_i`
  port と新規 `ext_adc_dout_i` port (JB4/T10) の間に挿入し、出力を既存
  `i2s_to_stream_0/si` へ接続。AXIS / DSP / 出力側 (`i2s_to_stream_0/so`
  -> ADAU `sdata_o` / PMOD JB7 PCM5102 DIN) は完全未変更。
  build-time `CONFIG.CONST_VAL` で source 切替: 1=PCM1808, 0=ADAU。
  `DECISIONS.md` D41。
- sample alignment / endian / bit depth 確認 — strap は I2S Philips
  24-bit slave (MD0=MD1=GND, FMT=GND) に統一済み。PCM1808 が pure 0
  しか吐かないので alignment 検証は実機 ADC が動いてから。
- ADAU1761 入力と同条件で比較 — **可能**(`CONFIG.CONST_VAL {0}` rebuild
  で Phase 7E ADAU-mirror 状態に瞬時に戻れる)。
- 新規物 (Phase 7D series):
  - RTL `pcm1808_input_select.v`(2:1 mux)
  - RTL change: `pcm5102_audio_out.v` の `ext_audio_mclk_o = 1'b0` を維持
    (D40 SCK-low を構造的に守る、D42)
  - 新規 top-level port `ext_pcm1808_sckie_o` on **JB8 / W16**
    (`clk_wiz_audio_ext/clk_out1` 直結、D42)
  - integration tcl `hw/Pynq-Z2/pcm1808_adc_integration.tcl`
  - XDC `ext_adc_dout_i T10` + `ext_pcm1808_sckie_o W16`
  - smoke `scripts/test_pcm1808_adc_to_pcm5102.py`、`--inject-sine` /
    `--capture-adc` diagnostic flags を追加(D43)
- **デプロイ状態 (Phase 7D close-out)**: `CONST_VAL=0` (mux=ADAU)。
  ADAU Line In -> AudioLab DSP -> PCM5102 line out 動作確認済。HDMI
  / encoder GUI 健在。PCM1808 module 自体は alive (clock 受信、I2S
  frame 刻んでいる) だが analog-to-digital が機能していない。最有力
  仮説は以前の 3.3V VCC 誤接続による chip / analog 前段 damage
  (D43)。
- **JB1 12.288 MHz クロストーク問題 (D42)**: Phase 7D 初回試行で
  JB1 を 12.288 MHz 駆動した結果、PCM5102 SCK との物理クロストーク
  で D40 async-clocks ノイズが再発。対策として PCM1808 SCKI を
  JB8 / W16 に専用ピンとして分離し、JB1 は RTL レベルで constant 0
  を維持。
- 未対応:
  - **PCM1808未使用時のJB8 SCKI停止**。現行 deploy bit は
    `CONFIG.CONST_VAL=0` でADAU入力を選んでいるが、`ext_pcm1808_sckie_o`
    はPCM1808再投入用に12.288 MHzを出し続ける。JB8 / W16 はPCM5102
    DINのJB7 / V16と隣接するため、PCM5102音質改善の次段階では
    mux=ADAU buildのときだけJB8を0固定するvariant / optionを追加する
    (D44)。Vivado rebuild + timing reviewが必要。
  - **PCM5102 debug output mode**。processed audio / digital silence /
    `-18 dBFS` 1 kHz tone / rampを切替できる診断モードを追加し、
    DSP起因、I2S/serializer起因、アナログ出力・後段起因を分ける
    (D44)。実装は次段階で、今回のdocs更新では行わない。
  - PCM1808 module 交換 or hardware 修理 / 再診断
  - 交換後 `CONFIG.CONST_VAL {1}` rebuild で PCM1808 路復活
  - runtime ADC source switching (AXI GPIO 化、後回し)
  - PCM1808 用の Hi-Z guitar buffer / analog front-end
  - FPGA-as-I2S-master 構成 (PCM1808 SCKI/BCK/LRCK 同期問題が
    後で出た場合)
  - ADAU -> PCM5102 経路に残る軽微なノイズ (Phase 7D close-out で
    user が言及、JB7/JB8 隣接配線のクロストーク疑い、別途調査)

### Phase 7E: DSP path への組込み — **LANDED (output side, ADAU-mirror pass-through)**
- block_design 上で AXIS switch / mux を入れて
  ADAU1761 path / 外付け path を切替可能にする
  (compile-time または runtime) — **却下**。AXIS switch / mux は
  入れず、ADAU1761 I2S DAC interface (`bclk` 入力 port / `lrclk`
  入力 port / `i2s_to_stream_0/so`) を **trivial pass-through**
  (`pcm5102_audio_out.v`) で PMOD JB の 4 pin にミラーする方式に
  変更。PCM5102 は ADAU と完全に同じ I2S を受けるので CDC / FIFO /
  SRC 一切なし。両 DAC parallel 出力で A/B 比較容易。
  `DECISIONS.md` D39。
- DSP 本体は変更しない — **済**(`LowPassFir.hs` / `topEntity` /
  AXIS path 全て未変更)
- timing summary 確認 (WNS 悪化に注意) — **済**。
  WNS `-8.724 ns`(Phase 7C `-8.410 ns` から `+0.314 ns` 悪化、
  historical `-7..-9 ns` band 内)、WHS `+0.051 ns`、THS `0.000 ns`、
  `bclk` domain WNS `+320.751 ns` (PCM5102 が新たに tap する domain は
  完全クリーン)。Utilization は Phase 7C と同等。
- 実機 audio 比較 — **手作業残**(ADAU DAC line out vs PCM5102 line out
  の聞き比べ / 計測は user 側)
- 新規物: RTL `hw/ip/pcm5102_audio_out/src/pcm5102_audio_out.v`、
  smoke `scripts/test_pcm5102_dsp_output.py`、integration tcl は
  `hw/Pynq-Z2/pcm5102_dac_integration.tcl` を 7C → 7E に
  書き換え。bit/hwh 再生成 + deploy 済 (smoke PASS、ADC HPF True、
  全 IP 健在)。
- 未着手: PCM1808 ADC (Phase 7D)、runtime DAC switching、XSMT 制御、
  pop-noise suppression、AXIS-side broadcaster (現状不要)。

### Phase 7F: encoder input IP
- ロータリーエンコーダー decode IP の Clash / HDL 実装
- XDC update (encoder ピン)
- AXI register map 確定
- bit / hwh build

### Phase 7G: Python encoder driver + GUI focus state
- `audio_lab_pynq/encoder_ui.py` 等の Python driver
- AppState への focus / edit state 追加
- compact_v2 renderer に focus 表示追加
- notebook なしで全機能を制御できる prototype

### Phase 7H: enclosure / front panel integration
- enclosure 設計
- front panel 配線 (encoder / jack / power)
- grounding / noise レビュー
- 最終 audio 計測

---

## 10. 禁止事項 (Phase 7A / 7B の間)

- XDC 変更 (`hw/Pynq-Z2/audio_lab.xdc`)
- block_design 変更 (`hw/Pynq-Z2/block_design.tcl`)
- HDMI tcl 変更 (`hw/Pynq-Z2/hdmi_integration.tcl`)
- bit / hwh 再生成 (`hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}`)
- DSP / Clash 変更 (`hw/ip/clash/src/LowPassFir.hs`)
- 既存 GPIO control map 変更
- HDMI timing (`SVGA 800x600 @ 40 MHz`) 変更
- ADAU1761 経路の即置換
- `GUI/pynq_multi_fx_gui.py` / `audio_lab_pynq/hdmi_effect_state_mirror.py`
  shim の巨大化 (実装本体は `GUI/compact_v2/` / `audio_lab_pynq/hdmi_state/`)
- encoder 用 AXI IP の base address を **HDMI VDMA range** に置く
  (`0x43CE0000` / `0x43CF0000` 禁止、`DECISIONS.md` D32)
- `git push` / `git pull` / `git fetch`

---

## 11. Phase 7B 実モジュール確認チェックリスト

実モジュール (Amazon / 共立 / aitendo 等で購入する PCM1808 / PCM5102
基板) を入手した時点で、Phase 7C (DAC 出力 prototype) 開始前に必ず
以下を埋める。

### 11.1 PCM1808 module verification

電源 / レベル:
- [ ] 基板シルク上の `VCC` ピン名と許容電圧
- [ ] 同じく `GND`
- [ ] `VCC = 3.3V` で動作するか (Youmile module は典型 3.3V or 5V 両対応)
- [ ] `VCC = 5V` の場合、デジタル `DOUT` / 入力 `SCKI` / `BCK` / `LRCK` /
  `FMT` / `MD0` / `MD1` の I/O level (3.3V tolerant か / 5V のままか)
- [ ] onboard regulator の有無 (3.3V LDO が module に載っているか)

I2S / control:
- [ ] `SCK` / `SCKI` / `MCK` / `MCLK` 表記揺れの実シルク確認
- [ ] `SCKI` 接続が必須か (PCM1808 は典型 `SCKI` 必須、内蔵 PLL なし)
- [ ] `BCK` / `BCLK` シルク
- [ ] `LRCK` / `LCK` / `WS` シルク
- [ ] `DOUT` シルクと出力 level
- [ ] `FMT` の基板上 strap / jumper (LOW=I2S 推奨)
- [ ] `MD0` / `MD1` の基板上 strap / jumper (slave-mode 固定推奨)
- [ ] FPGA から `FMT` / `MD0` / `MD1` を制御する必要があるか
      (strap で固定できれば PMOD JA を空けられる)

アナログ入力:
- [ ] analog input が AC coupling 済み (DC blocking cap onboard) か
- [ ] analog input impedance (典型 数十 kΩ)
- [ ] line-level 専用であること再確認
- [ ] **ギター直結は不可** (`EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md`
      section 5、analog front-end は Phase 7E 以降)

### 11.2 PCM5102 module verification

電源 / レベル:
- [ ] 基板シルク上の `VCC` / `GND`
- [ ] 許容電圧 (PCM5102A 系は典型 3.3V、module by module で 5V 入力可も
      あり)
- [ ] デジタル I/O level (3.3V tolerant か)
- [ ] onboard regulator の有無

I2S / control:
- [ ] `DIN` / `BCK` / `LCK` (`LRCK` / `WS`) のシルク
- [ ] `SCK` / `MCLK` ピンの実存と既定 (GND 落とし内蔵 PLL or 外部 MCLK)
- [ ] 3-wire I2S (`BCK` / `LCK` / `DIN` のみ) で動く構成か
- [ ] `XSMT` の露出有無、既定状態 (pull-up unmute or pull-down mute)
- [ ] `FLT` / `DMP` / `FMT` の露出有無と既定 strap

アナログ出力:
- [ ] output が AC coupled (output cap onboard) か
- [ ] output レベル (line out 想定) / impedance
- [ ] **headphone 直接駆動を前提にしない** (`EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md`
      section 6、必要なら output buffer / headphone amp 追加)
- [ ] pop noise 対策 (XSMT デジタル制御 / mute シーケンス)

### 11.3 Phase 7B pin candidate plan (cross-reference)

候補 package pin は `IO_PIN_RESERVATION.md` section 4A の表に集約済み。
Phase 7B 時点では:
- PMOD JB に audio 必須 5 pin + spare 3 pin を割当 (`candidate`)
- PMOD JA は audio 追加 control / strap (`candidate`、可能なら module
  strap で固定して PMOD JA を空ける方を優先)
- Raspberry Pi header の **JA と共有しない pin 群**
  (`raspberry_pi_tri_i_6..24` = `F19, V10, V8, W10, B20, W8, V6, Y6,
  B19, U7, C20, Y8, A20, Y9, U8, W6, Y7, F20, W9`) を encoder + spare に
  割当 (`candidate / needs physical verification`)
- 実 module 確認後、Phase 7C で `audio_lab.xdc` に DAC 用 pin から順に
  実装。Phase 7B の本ドキュメントでは XDC を **書かない**。

### 11.4 Phase 7B 接続案 / 現行配線 (PMOD JB ↔ external module)

Phase 7B当初案ではJB1を外付けMCLK候補としていたが、Phase 7D follow-up
(D42)で現行配線は下記に更新済み。PCM5102 SCKは必ずGND / Lowで使い、
JB1は外部SCK用途に戻さない。

現行最小構成 (mode pin はすべて module strap、XSMT pull-up):

```
PYNQ-Z2 PMOD JB                            External module
================                           =============================
JB1  (W14)  EXT_AUDIO_MCLK   = constant 0  (unused; do not wire to PCM5102 SCK)
JB2  (Y14)  EXT_AUDIO_BCLK   ──────────►   PCM1808 BCK + PCM5102 BCK
JB3  (T11)  EXT_AUDIO_LRCLK  ──────────►   PCM1808 LRCK + PCM5102 LCK
JB4  (T10)  EXT_ADC_DOUT     ◄──────────   PCM1808 DOUT
JB7  (V16)  EXT_DAC_DIN      ──────────►   PCM5102 DIN
JB8  (W16)  EXT_PCM1808_SCKI ──────────►   PCM1808 SCKI (12.288 MHz when enabled)
JB11 (GND)                   ───────────   PCM1808 GND + PCM5102 GND
JB12 (3V3)  *only if module accepts 3.3V on VCC*
                             ───────────   (else use external 5V supply, common GND)
```

PCM1808 strap (基板上で固定):
- `FMT = LOW`   (I2S 24-bit)
- `MD0 / MD1 = slave mode`

PCM5102 strap:
- `XSMT = HIGH` (unmute, pull-up to 3.3V)
- `FLT` / `DMP` / `FMT` は工場既定で問題なければ未接続
- `SCK` は **GND / Low固定**。`EXT_AUDIO_MCLK` / JB1 / JB8へ戻さない
  (D40 / D42)。PCM5102はinternal-SYSCLK modeで使う。

PMOD JA を使う場合 (module strap が無いとき):
- `JA1` (Y18): `EXT_ADC_FMT`
- `JA2` (Y19): `EXT_ADC_MD0`
- `JA3` (Y16): `EXT_ADC_MD1`
- `JA4` (Y17): `EXT_DAC_XSMT` (これを使うときは pull-up より優先)
- `JA7` (U18): `EXT_CODEC_RESET_N` (module 露出している場合)
- 注意: 上記 5 pin は RPi header の `raspberry_pi_tri_i_0..5` /
  `respberry_sd_i` / `respberry_sc_i` と物理共有 (`IO_PIN_RESERVATION.md`
  section 4.6)。encoder には別 RPi pin (`raspberry_pi_tri_i_6..`) を使う。

### 11.5 Phase 7C / 7D / 7E 検証計画 (再掲、precise)

- **Phase 7C (DAC 先)**:
  1. `audio_lab.xdc` に PMOD JB の 5 pin を追加 (Phase 7C の冒頭)
  2. PS 側または既存 DSP path 経由で I2S sine / sweep を PCM5102 へ送る
  3. オシロ / ロジアナで `JB2 (BCK)` / `JB3 (LRCK)` / `JB7 (DIN)` を観測
  4. PCM5102 line out を別 audio interface input に入れて測定
  5. ADAU1761 path は維持 (Phase 7E まで触らない)

- **Phase 7D (ADC 次)**:
  1. line-level 信号 (function generator / 別 audio I/F line out) を
     PCM1808 analog input に入れる
  2. `JB4 (DOUT)` を FPGA に取り込み、PS にバッファする
  3. sample alignment / endian / bit depth を確認
  4. ADAU1761 入力と同じ条件で比較 (S/N、レベル)

- **Phase 7E (DSP path 組込み)**:
  1. block_design で AXIS switch / mux を入れ、ADAU1761 / 外付け path を
     切替可能にする (compile-time または runtime)
  2. DSP 本体 (`LowPassFir.hs`) は変更しない
  3. WNS が `TIMING_AND_FPGA_NOTES.md` の最新 deploy band を大きく
     悪化させないこと
  4. 実機 audio 比較 (ADAU1761 vs 外付け)
