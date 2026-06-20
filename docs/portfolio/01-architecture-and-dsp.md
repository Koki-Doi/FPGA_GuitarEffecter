# Audio-Lab-PYNQ 技術詳細 (1/5) — アーキテクチャ & DSP 実装

> [PORTFOLIO.md](../PORTFOLIO.md) の深掘り技術付録。本書はシステム仕様・ハードウェア構成・クロックドメインアイランド・Clash DSP・エフェクトチェーンを扱う。

## 1. プロジェクト概要

**Audio-Lab-PYNQ**（別名 FPGA_GuitarEffecter）は、Xilinx **PYNQ-Z2** ボード上で
動作する**リアルタイム・マルチエフェクト・ギタープロセッサ**です。実機のギター
信号を Pmod I2S2 オーディオモジュールから取り込み、FPGA の PL（Programmable
Logic）上に実装した DSP チェーンで処理し、同モジュールの DAC から出力します。

一言で言えば、**「アンプ／ペダルの実機モデリングを、ソフトウェアではなく FPGA の
論理回路として走らせ、96 kHz・サブミリ秒レイテンシで動かす」**プロジェクトです。
処理は ARM コア上のソフトウェア DSP ループではなく、合成された専用ハードウェア
パイプラインで行われるため、サンプルごとの遅延が極小で、ジッタもありません。

さらに本プロジェクトは単なる音響処理に留まらず、

- **HDMI 5インチ LCD の GUI**
- **ロータリーエンコーダ ×3**
- **フットスイッチ ×3**
- **エクスプレッションペダル（ZOOM FP02M）**

までを**すべて自作の PL IP として統合**した、フルスタックな組み込みハード／
ソフト協調設計になっています。

現行の採用済みデプロイベースラインは **D148**（`96ef899`、D135 を supersede）
です。D121-D135 の測定駆動 voicing / sim 拡張に、D146 hard CDC pblock、D147 amp
sag-attack slew、D148 JC-120 / Fender-Twin clean-headroom fix を重ね、
timing / golden / PL smoke / bench を通した canonical baseline です。
D136-D142 と D144 は bench acceptance を通せず一旦 D135 へ rollback しましたが、
D146 の hard pblock で safe-bypass CDC を物理固定してから clean-headroom voicing
が land しました。

---

## 2. なぜ FPGA か — 設計思想

汎用 CPU/DSP ではなく FPGA を選んだ理由と、それが生む設計上の制約・利点：

| 観点 | 内容 |
| --- | --- |
| **レイテンシ** | パイプライン化された専用回路で 1 サンプル / 1 クロック処理。割り込みや OS スケジューリングに起因する遅延・ジッタがない。 |
| **決定論** | 全処理がクロック同期。サンプルあたりの処理時間は常に一定。 |
| **並列性** | 全エフェクト段が物理的に同時に存在し、パイプラインで流れる。CPU のような「逐次実行」ではない。 |
| **制約** | その代わり、深い組み合わせ論理は**タイミングクロージャ**という壁にぶつかる（→ 第 5 章のアイランド設計の動機）。回路規模・乗算器数（DSP48）も有限リソース。 |

この「並列で速いが、タイミングとリソースが厳しい」という FPGA 特有の性質が、
本プロジェクトの設計判断のほぼ全てを駆動しています。**新しいモデルを足すときに
回路トポロジや乗算器を増やさず、係数だけで音を作り分ける**（第 9 章）のも、
**DSP コアだけ別クロックに隔離する**（第 5 章）のも、すべてこの制約への回答です。

---

## 3. システム仕様

| 項目 | 内容 |
| --- | --- |
| プラットフォーム | PYNQ-Z2（Zynq-7020 SoC：Artix-7 FPGA + Dual ARM Cortex-A9） |
| オーディオ I/O | Digilent Pmod I2S2（CS5343 ADC / CS4344 DAC、PMOD JB） |
| サンプルレート | **96 kHz**（24-bit、コーデック double-speed 動作、D98） |
| サンプル型 | `Sample = Signed 24`（2 の補数、内部処理はモノラル） |
| DSP 記述言語 | **Clash（関数型 HDL、Haskell）→ VHDL → Vivado 合成** |
| DSP クロック | 専用アイランド `FCLK_CLK1` = 33.33 MHz（50→40→33.33 と低速化、D94） |
| ファブリッククロック | `FCLK_CLK0` = 100 MHz（AXI / DMA / I2S / HDMI） |
| 制御層 | Python 3.6 / PYNQ（オーバーレイ API、MMIO / AXI-GPIO） |
| ユーザー操作 | HDMI 800×480 LCD GUI、ロータリーエンコーダ ×3、フットスイッチ ×3、エクスプレッションペダル |
| 合成環境 | Vivado 2019.1 |
| コーデック（補助） | ADAU1761（I2C 制御、ADC HPF 常時 ON、デバッグ可視化用） |

### 3.1 現行採用ビルド（D148）の実測値

| 項目 | 値 |
| --- | --- |
| 採用日 | 2026-06-20 |
| Git / bitstream | merge commit `96ef899`、bit md5 `972d9ba6645dd966e6bdcb5bc3daf478`、hwh md5 `2b888ff1ec3168cd64e1b679bbbc71be` |
| タイミング | WNS `+0.526 ns`、WHS `+0.014 ns`、route errors `0` |
| D109 CDC slack | `clk_fpga_0 -> clk = +1.632 ns`（pair MET） |
| 実機 smoke | board md5 match、PL smoke OK（Pmod I2S2 mode 2、~96 kHz、ADC HPF `True`） |
| bench 判定 | ユーザー bench で accepted（「完璧」）、その後 main へ `--no-ff` merge |
| ロールバック | D135 bitstreams を `765323b` から復元（bit md5 `533d586901dc3669285a49c6d82bab9f`）して deploy |

この表は「ポートフォリオ用に見栄えよく丸めた値」ではなく、D148 の Vivado routed timing /
deploy / smoke / bench の実記録からそのまま持ってきた値です。FPGA
プロジェクトでは、見た目の機能説明よりも **どの commit / bit / timing / bench 結果を現行値
として語っているか**を固定することが重要です。

---

## 4. ハードウェア・アーキテクチャ

### 4.1 オーディオ信号経路

```
ギター
  → Pmod I2S2 ADC (CS5343, JB10 SDOUT)
  → i2s_to_stream (I2S → AXI-Stream 化)
  → axis_data_fifo
  → cc_dsp_in  (axis_clock_converter, 100 MHz → 33.33 MHz)
  → clash_lowpass_fir_0  ★ Clash DSP パイプライン（全エフェクト）
  → cc_dsp_out (axis_clock_converter, 33.33 MHz → 100 MHz)
  → axis_switch_sink → i2s_to_stream
  → Pmod I2S2 DAC (CS4344) → アンプ／スピーカー
```

内部処理は**モノラル**で行います。`AudioLab.Axis.makeInput` が ADC Left を
モノラルソースにコピーして ADC Right を破棄し、出力段 `pipeData` が
`packChan mono mono` で L/R に複製します。これにより**ステレオ I/F を満たし
ながら DSP リソースを倍化させない**設計です。

### 4.2 Pmod I2S2 の動作モード

`pmod_i2s2_master.v`（FPGA マスター I2S エンジン）が以下を生成・選択：

- **クロック**：MCLK 12.288 MHz（=128fs）、BCLK 6.144 MHz（= MCLK/2、double-speed）、LRCK 96 kHz
- **モード**：`0=tone`（内部トーン）/ `1=loopback` / `2=dsp`（ADC→DSP→DAC、実運用）/ `3=mute`
- **モード 2 の工夫**：`i2s_to_stream` の LEFT 抽出バグと `i2sOut` セットアップレースを
  回避するため、IP の RIGHT スロットを `mode2_right_snapshot` で両 DAC チャネルに
  ミラーする（モノ RIGHT 出力、約 10.4 µs / 1 フレーム遅延、D50）。
- AXI ステータス/制御スレーブ `axi_pmod_i2s2_status` を `0x43D20000` に配置。

### 4.3 AXI メモリマップ（PL IP 一覧）

全エフェクトパラメータは `axi_gpio_*`（単一チャネル・32-bit・全出力）を通じて
Clash 側へ届きます。PS が 32-bit ワードを 1 つ書き、Clash 側が 4 バイトに分解：

| フィールド | ビット |
| --- | --- |
| `ctrlA` | `[7:0]` |
| `ctrlB` | `[15:8]` |
| `ctrlC` | `[23:16]` |
| `ctrlD` | `[31:24]` |

| IP / アドレス | 役割（ctrlA / ctrlB / ctrlC / ctrlD） |
| --- | --- |
| `axi_gpio_reverb` `0x43C30000` | decay / tone / mix / —（ENABLE は gate.ctrlA bit5） |
| `axi_gpio_gate` `0x43C40000` | エフェクト ON/OFF フラグ 8bit / gate閾値(legacy) / dist bias / dist mix |
| `axi_gpio_overdrive` `0x43C50000` | OD tone / OD level / OD drive / dist tight[7:3] + OD model[2:0] |
| `axi_gpio_distortion` `0x43C60000` | dist tone / dist level / dist drive / **ペダルマスク[6:0]**（bit7 予約） |
| `axi_gpio_eq` `0x43C70000` | low / mid / high / —（予約） |
| `axi_gpio_delay` `0x43C80000` | **RAT**：filter / level / drive / mix（IP 名は歴史的経緯で delay） |
| `axi_gpio_amp` `0x43C90000` | input gain / master / presence / resonance |
| `axi_gpio_amp_tone` `0x43CA0000` | bass / mid / treble / **ctrlD[7]=DRV MODE, [2:0]=amp model idx** |
| `axi_gpio_cab` `0x43CB0000` | mix / level / model(0/85/170) / air |
| `axi_gpio_noise_suppressor` `0x43CC0000` | threshold / decay / damp / —（予約） |
| `axi_gpio_compressor` `0x43CD0000` | threshold / ratio / response / **bit7=enable + makeup[6:0]** |
| `axi_gpio_wah` `0x43D30000` | position / Q / volume / **bit7=enable + bias[6:0]** |
| `axi_encoder_input` `0x43D10000` | ロータリーエンコーダ ×3（入力 IP） |
| `axi_pmod_i2s2_status` `0x43D20000` | Pmod I2S2 ステータス/制御 |
| `xadc_wiz_a0` `0x43D40000` | エクスプレッションペダル（A0=VAUX1）読み取り（read-only） |
| `axi_footswitch_input` `0x43D50000` | フットスイッチ ×3（入力 IP） |

> **AXI GPIO は出力専用**のため、Python 側の `get_*` はハードからの読み戻しでは
> なくキャッシュ値を返します。この台帳（名前/アドレス/ctrl 意味）は**固定の契約**
> として扱い、新エフェクトはまず予約ビット/バイトから割り当てます。

### 4.4 ブロックデザインの不可侵原則

中核の `hw/Pynq-Z2/block_design.tcl` は原則**編集禁止**。新 IP は加算式の
`*_integration.tcl`（`pmod_i2s2` → `wah` → `xadc` → `footswitch` → `island` の順で
`create_project.tcl` から source）で `NUM_MI` をバンプして追加します。これにより
**ベースのブロックデザインを壊さずに機能拡張**できる運用を確立しています。

---

## 5. クロックドメイン・アイランド設計

このプロジェクトで最もエンジニアリング的に重い課題が**タイミングクロージャ**で
した。深い歪み（ディストーション）チェーンは長い組み合わせ論理パスになります。

### 5.1 問題

`fxPipeline` の DSP（`clash_lowpass_fir_0`）が成長し（Wah / Compressor / Noise
Suppressor / 6 ディストーションペダル / Amp / Cab / EQ / Reverb）、最悪パスが
100 MHz で**収束しなくなりました**：

- DS-1 ディストーション内の **45 論理段（CARRY4 × 36）** の算術チェーン
- データパス遅延 約 **20.1 ns** に対し、周期は **10 ns**
- 結果 **WNS = -10.387 ns**（大幅な違反）

設計の他の部分（AXI / DMA / I2S / Pmod / HDMI）は 100 MHz で問題なく収束。
**DSP だけ**がボトルネックでした。

### 5.2 効かなかった解法（記録された失敗）

| 試行 | 結果 |
| --- | --- |
| DS-1 チェーンのステージ分割 | WNS 不変（最悪パスは「Frame レジスタ → DSP」のルート支配で、クリップ深さではなかった） |
| Frame 幅削減（1067→731 bit） | わずかに悪化 |
| ファブリック全体を 50 MHz に | WNS は改善するが、**I2S/Pmod の CDC が壊れてバイパス音が連続的にバズる**（CDC は 100 MHz 前提で作られている） |

### 5.3 採用解 — DSP コアだけを隔離（D75）

`island_integration.tcl`（加算式、`block_design.tcl` 不編集）で：

1. **`FCLK_CLK1`** を PS で有効化（`FCLK_CLK0` は 100 MHz のまま）
2. 当該ドメイン用の **`rst_island_50M`**（`proc_sys_reset`）
3. DSP の前後に **`cc_dsp_in` / `cc_dsp_out`**（`axis_clock_converter`）を挿入し
   100↔33.33 MHz をブリッジ
4. `clash_lowpass_fir_0` のクロック/リセットを `FCLK_CLK1` に付け替え

```
            100 MHz ファブリック (FCLK_CLK0)                  33.33 MHz アイランド (FCLK_CLK1)
  ┌─────────────────────────────────────────────┐      ┌───────────────────────────────┐
  │ Pmod ADC → i2s_to_stream → axis_data_fifo    │      │                               │
  │                              │               │ 100→33│                               │
  │                              ▼          cc_dsp_in ───▶│  clash_lowpass_fir_0          │
  │                                              │      │  (全エフェクト DSP, 1smp/cyc) │
  │      Pmod DAC ◀ i2s_to_stream ◀ axis_switch ◀── cc_dsp_out ◀──────────────────────── │
  │                              ▲          33→100│      │                               │
  │ AXI / DMA / HDMI / GPIO ──────┘              │      │                               │
  └─────────────────────────────────────────────┘      └───────────────────────────────┘
       ↑ I2S/Pmod/HDMI の CDC は 100 MHz 前提で構築（不変）   ↑ DS-1 の深い算術チェーンに余裕
       │                                                      
   ★ clk_fpga_0 ↔ clk の DSP出力→DAC CDC だけは set_max_delay で拘束（D109、第 5.4 章）
```

**ファブリッククロックは不変なので、既存の I2S/Pmod/HDMI の CDC はバイト等価で
無傷**。アイランドだけを 50→40（D89、4x オーバーサンプラのため）→33.33 MHz（D94）と
段階的に下げて余裕を確保しました。

- アイランドは **1 サンプル / 1 サイクル**動作で**周波数非依存**（`paceCount` 削除）
- 96 kHz でも **約 347 アイランドサイクル / サンプル**の余裕があり、スループット要件を
  大きく上回る
- **ピッチは I2S/Pmod のサンプルクロックが決める**ため、アイランドクロックを下げても
  音程は変わらない（D98 で 96 kHz 化したときもアイランドは無変更）
- 結果：WNS **-10.387 → -0.706 ns**、ライブ音声・GUI・HDMI すべて健全

### 5.4 「ナイフエッジ」バグ — 未タイミング CDC の根本究明（D109）

アイランド導入後も長らく悩まされたのが、**「DSP を再ビルドするたびに、エフェクトを
全部 OFF にしたバイパス音まで壊れる（safe-bypass が歪む）」**という不可解な現象でした。
ビルドは決定論的で、タイミングサマリ（setup/hold とも MET）には**一切現れません**。

D98 のルーティング済み DCP を**開いて `report_cdc` をかける**ことで原因を特定：

- DSP 出力 → DAC のパス `clk_fpga_0 → clk` が**分散 RAM の非同期 FIFO**
  （`axis_switch_sink` → `i2s_to_stream` の RAM、**112 個の CDC-13「非 FD プリミティブ上の
  1-bit CDC パス」**）
- これが `set_clock_groups -asynchronous` によって**未タイミングのまま放置**されていた
- どんなネットリスト変更でも配置が動き、未タイミングの書き込み配線が伸びると、
  **静的タイミング解析に一切現れずにバイパス経路が破壊**される

**修正（`audio_lab.xdc`、D109）**：

```tcl
# 単一の 7 ドメイン async グループを 2 つに分割し、
# clk_fpga_0 <-> clk の対だけは「タイミングする」状態に残す
set_clock_groups -asynchronous -group {clk_fpga_0}
set_clock_groups -asynchronous -group {clk}
# その対の分散 RAM 書き込みを上限拘束（配置に依らず）
set_max_delay -datapath_only 10.000 ...  ; # 両方向
```

これにより `report_cdc` の例外が "Max Delay Datapath Only" に変わり、タイミング
MET。**変更後の DSP ソースでバイパスがクリーンになったのは初めて**で、以降
「DSP の音作り再ビルドは安全」になりました（それまでの「D98 のビットだけがクリーン、
音作りで再ビルドするな」という呪いが解けた）。**ただし新ビットは必ず実機試聴する**運用は維持。

> このデバッグは、**「タイミングがグリーンでも、未タイミングの CDC は配置依存で
> 機能を壊す」**という FPGA 設計の落とし穴を突き止めた好例です。静的解析だけを信じず、
> `report_cdc` とビルド済み DCP の解析で物理的に原因を特定しました。

---

## 6. DSP 実装 — Clash / 関数型 HDL

DSP は **Clash**（Haskell ベースの関数型 HDL）で記述し、Clash → VHDL → Vivado の
流れで合成します。`hw/ip/clash/src/LowPassFir.hs`（薄い top module、名前は歴史的経緯）
と `hw/ip/clash/src/AudioLab/` 配下の分割モジュール群が、**ライブビルドの DSP 挙動の
唯一の真実（single source of truth）**です。C++ プロトタイプは廃止されています。

### 6.1 モジュール構成

| モジュール | 役割 |
| --- | --- |
| `AudioLab.Types` | コア型定義 |
| `AudioLab.FixedPoint` | 固定小数点の数値ヘルパー |
| `AudioLab.Control` | バイト / フラグ分解ヘルパー |
| `AudioLab.Axis` | AXIS パック/アンパック、パケットヘルパー |
| `AudioLab.Effects.*` | 各エフェクト段（Amp / Overdrive / Distortion / Cab / Reverb …） |
| `AudioLab.Pipeline` | `fxPipeline`（段の接続） |
| `tools/dsp_sim/Sim.hs` | Clash `topEntity` をホスト CPU 上で実行する offline DSP sim |
| `tools/dsp_sim/measure.py` | bypass 比の net tone-curve / peak / dip を測る解析ハーネス |

### 6.2 コア型

```haskell
type Sample = Signed 24    -- オーディオサンプル（2 の補数）
type Wide   = Signed 48    -- 積・和のための広いアキュムレータ
type Ctrl   = BitVector 32 -- AXI GPIO ワード 1 つ
```

`Frame` がパイプラインを流れるデータレコード。L/R 形の物理フィールドは互換性のため
残しつつ、実経路は `monoSample` / `monoDry` / `monoWet` などのモノヘルパーで読み書き。
`Frame.fLast` が AXI TLAST をサンプルデータと独立に運びます。`Maybe Frame` がパイプ型
（`Nothing` = 空きスロット）。

### 6.3 数値プリミティブと固定小数点の規律

| ヘルパー | 用途 |
| --- | --- |
| `mulU8 :: Sample -> Unsigned 8 -> Wide` | 24×8 符号付き×符号なし乗算 → `Wide` |
| `mulU9` / `mulU12` | ヘッドルーム重視の 24×9 / 24×12 |
| `mulS10` | 24×10 符号付き×符号付き（Cab IR 係数用） |
| `satWide` | `Wide` → `Sample` の飽和クランプ |
| `satShift7/8/9/10/12` | `>> N` のあと `satWide`（乗算後に 24-bit レーンへ戻す） |
| `softClip` | 固定膝 `4_194_304` の対称ソフトクリップ |
| `softClipK knee x` | 膝可変の対称ソフトクリップ |
| `asymSoftClip kneeP kneeN x` | ± で異なる膝・傾きの非対称ソフトクリップ |
| `asymSoftClipSoft/Med/Hard` | モデル別クリップ硬さ用のコンパイル時シフト兄弟（D79） |
| `asymHardClip` / `hardClip` | 独立しきい値のハードクランプ |
| `onePoleU8 alpha prev x` | `alpha/256·x + (256-alpha)/256·prev`（一次 IIR） |

**規律**：乗算は `Wide` で行い、`shift + sat` で `Sample` に戻し、その後にサンプル領域の
処理を続ける。**未飽和の `Wide` を次の乗算チェーンに渡さない。** この一貫したルールが、
オーバーフローと意図しない歪みを防ぎつつ、合成可能なビット幅を制御しています。

### 6.4 offline DSP sim — Vivado 前に音作りを測る

D121 から、音作りの変更は Vivado を走らせる前に `tools/dsp_sim` で測定する運用に寄せています。
これは Python で書いた近似 DSP ではなく、**Clash の `topEntity` 固定小数点パイプラインを
ホスト CPU 上でそのまま実行する**検証経路です。

主な役割は 3 つです。

| 役割 | 内容 |
| --- | --- |
| bypass invariant | 全エフェクト OFF 時に入力と出力が sample-exact に一致することを確認する |
| golden regression | 代表設定（OD / Distortion / Cab など）の出力が、意図しない変更でズレないことを確認する |
| net tone-curve / target check | `measure.py` で「effect ON / bypass」の周波数応答差を測り、ピーク / ディップ / 帯域の位置を確認する。D131 では `--absolute` / `--check` / `targets.py` も使用 |
| distortion character | `dist_eval.py` で THD だけでは見えない input-level sweep、sustain hold-time、two-tone IMD/fizz を見る |

D121 では、この sim を使って最初に以下を Vivado 前に確定しました。

| 対象 | 狙い | offline 測定結果 |
| --- | --- | --- |
| BD-2 | pre-clip biquad を 1500 Hz から 2300 Hz へ移動し、明るい上中域へ | peak 約 2310 Hz |
| OCD | flat だった pre-clip に +4 dB @ 1300 Hz の upper-mid honk を追加 | +3.7 dB @ 1290 Hz |
| Metal | 既存 Big Muff scoop-notch を Metal にも掛け、中域を抉る | dip 593-720 Hz |
| Cab | 15-tap FIR だけでは出しにくい cone-breakup presence を FIR 後に追加 | +3.2 dB @ 2806 Hz |

重要なのは、offline sim は **Vivado / routed timing / PYNQ smoke / bench listening の代替ではない**
という点です。33.33 MHz の DSP island と 96 kHz の音声サンプル間には妥当なサンプル投入間隔
（idle gap）が必要で、PLL / CDC / I2S / board-level の問題は sim では分かりません。したがって
D131 でも同じく、sim → Clash VHDL regeneration → Vivado bit/hwh rebuild → timing summary →
deploy → PL smoke → user bench の順で受け入れています。

---

## 7. エフェクトチェーン全体像

信号は以下の固定順で 1 本のパイプラインを流れます（各矢印は最低 1 レジスタ）。
各エフェクトは個別に ON/OFF でき、OFF 時は**ビット完全一致のバイパス**を保証します。

```
makeInput (ADC Left → mono)
  → Noise Suppressor   (エンベロープ追従ゲート)
  → Compressor         (ステレオリンク・フィードフォワード・ピークコンプ)
  → Wah                (SVF レゾナントバンドパス、歪み前)
  → Overdrive          (drive → boost → モデル別クリップ → tone → level、Klon clean-blend)
  → Distortion(legacy) (drive → boost → clip → tone → level)
  → RAT                (HPF → drive → opamp LPF → hard clip → post LPF → tone → level → mix)
  → clean_boost        (mul → shift → level + softClip safety)
  → tube_screamer      (HPF → mul → asym soft clip → post LPF → level)
  → metal_distortion   (tight HPF → mul → hard clip → post LPF → level)
  → Amp Simulator      (HPF → drive → waveshape → pre-LPF → 2nd stage → tone stack → power → resonance/presence → master)
  → Cab IR             (15-tap speaker FIR + level/mix)
  → EQ                 (3-band)
  → Reverb             (BRAM tap + tone + feedback + mix)
  → 出力 AXIS レジスタ  (mono を L/R に複製、TLAST 伝播)
```

GUI 上の並びは **NS / CMP / WAH / OD / DIST / AMP / CAB / EQ / RVB** の 9 ブロック。
DMA トラフィックでは `fxPipeline` がサンプル値から TLAST を推定せず、`fLast` ビットを
そのまま伝播することで S2MM の短パケット落ちを防ぎます。

### 7.1 D121-D131 がチェーン上で変えた場所

D121 は「全体を作り替えた」ビルドではなく、D120 までの amp 変更が bench で rejected
だったため、当初は **Amp 段を D99 系の accepted character のまま保持**して非 Amp 帯域を
最小変更で補正しました。その後 D122-D131 で、測定に基づく低リスクな Amp / OD / Distortion /
Compressor の補正を段階的に積んでいます。

```
Overdrive
  ├─ BD-2: pre-clip biquad 1500 Hz → 2300 Hz, +3.5 dB
  └─ OCD : new pre-clip biquad +4 dB @ 1300 Hz

Distortion / Pedalboard
  └─ Metal: Big Muff 用 scoop-notch biquad の gate を
            bigMuffOn || metalDistortionOn に拡張

Amp Simulator
  ├─ D122/D128/D130: ampScoop / presence / drive separation / EQ re-collation
  └─ D119/D120 の sag removal/static trim は rejected、現行では sag active

Cab IR
  └─ D121/D123: speaker FIR 後に cone-breakup presence biquad、D123 で model 別へ

Compressor
  └─ D125: RATIO 感度を Dyna/Ross sustain 方向へ修正
```

Metal の mid-scoop は新しいバイカッド段を足していません。既に Big Muff 用に存在していた
約 700 Hz の scoop-notch を、Metal の出力にも通るよう gate 条件だけ広げています。Cab の
presence は逆に、15-tap FIR のタップ長だけでは 2.8 kHz の狭いピークを十分に表現しにくい
ため、FIR 後に peaking biquad を足しています。このように **既存段の再利用で済むところは
再利用し、必要なところだけ段を増やす**のが D121-D131 の設計方針です。

---
