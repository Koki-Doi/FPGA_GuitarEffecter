# Audio-Lab-PYNQ — リアルタイム・ギターエフェクター (FPGA / PYNQ-Z2)

**アンプ／ペダルの実機モデリングを、ソフトウェアではなく FPGA の論理回路として走らせ、
96 kHz・サブミリ秒レイテンシで動かす**リアルタイム・マルチエフェクト・ギタープロセッサ。
DSP は関数型 HDL（Clash/Haskell）で記述し、HDMI GUI・ロータリーエンコーダ・フットスイッチ・
エクスプレッションペダルまで自作 PL IP で統合した、フルスタックな組み込みハード／ソフト協調設計。

> 本ページはポートフォリオサイト向けの概要。実装値・係数・アルゴリズム・設計の物語は
> **[深掘り技術付録](#深掘り技術付録)**（全 5 部）を参照。

**現行の採用済みデプロイベースライン**は **D155**（merge commit `09c8a95`、
bit md5 `8d875cc8a0154a86673ab22e5b142d27`、hwh md5
`e0469cf593e97d582c14bb09ea98d3d3`）。cab speaker FIR を 31→47 タップに拡張した
Option-Y 折返し拡張で、real-4x12 寄りの >5 kHz ロールオフを鋭く（open -14.9 /
british -22.0 / closed -28.9 dB/oct）しつつ、presence biquad が 2-4 kHz ピークを
保つビルドです（高リスクな 128-tap BRAM "B2" は不採用）。Vivado routed timing は
**WNS +0.319 ns / WHS +0.013 ns**、D109 CDC fwd +0.989（bench-clean）、DSP
206/220、bypass bit-exact、実機 PL smoke とユーザー bench で合格しています。
これは **2026-06 の D150–D155 voicing アーク**の締めくくりです（全て sim 先行
`tools/dsp_sim`・placement-safe）: D150 OD/DS の和音 IMD を対称クリップで修正、
D151 amp の高音増強（post-amp HF シェルフ + cab presence。rig の高域は cab が
支配し amp の TREBLE/PRESENCE はほぼ効かないと実測で判明）、D152/D153 和音高音の
"汚い/ブツブツ"（帯域内 IMD・オーバーサンプリング無効を実証）を cab ヘッドルーム +
presence 戻し→出力ホット化分の `cabSpeakerKnee` peak-limit 復帰 + JC/Twin -1.3 dB
トリム（音割れ修正）、D154 ゲイン機の和音 IMD はマルチバンド含め非改善＝未出荷、
D155 が cab 47-tap。直前の accepted は D153（`b86c88a`）、その前は D148
（`96ef899`、JC/Twin clean-headroom + D146 hard CDC pblock + D147 amp sag-attack
slew、D135 `765323b` を supersede）。D136-D142 / D144 は timing-clean でも
safe-bypass の bench を通せず一旦 D135 へ rollback、D146 hard pblock で
audio-output CDC を物理固定してから以降の voicing が land しました。

---

## 一目でわかる構成

```
 ┌──────────┐   ┌──────────────────────────────────────────────┐   ┌──────────┐
 │  ギター   │──▶│            PYNQ-Z2  (Zynq-7020)               │──▶│ アンプ/  │
 └──────────┘   │                                              │   │ スピーカー│
   Pmod I2S2    │  PL (FPGA)                  PS (ARM Cortex-A9)│   └──────────┘
   CS5343 ADC   │  ┌────────────────────┐    ┌────────────────┐│      Pmod I2S2
                │  │ Clash DSP チェーン  │◀──▶│ Python / PYNQ  ││      CS4344 DAC
                │  │ (33.33MHz アイランド)│    │ AudioLabOverlay││
                │  └────────────────────┘    └────────────────┘│
                │  HDMI 800×480 GUI / encoder×3 / footswitch×3  │
                └──────────────────────────────────────────────┘
```

### 信号チェーン（全 OFF 時はビット完全一致のバイパス）

```
IN → Noise Sup → Compressor → Wah → Overdrive → Distortion(7ペダル)
   → RAT → Amp Sim(6機種) → Cab IR(3種) → EQ → Reverb → OUT
```

---

## このプロジェクトの見どころ

- **関数型 HDL（Clash）による DSP** — Clash ソースを「DSP 挙動の唯一の真実」とし、挙動を保った
  リファクタを型システムで保証、生成 VHDL の論理等価性で検証。
- **クロックドメイン・アイランド設計** — 100 MHz で収束しなかった深い歪みチェーン（WNS
  -10.387 ns）を、DSP コアだけ低速ドメインに隔離して解決。CDC は `axis_clock_converter` で
  安全にブリッジし、既存ファブリックの CDC を温存。
- **「ナイフエッジ」バグの根本究明** — 「DSP 再ビルドのたびにバイパス音が壊れる」謎を、静的
  タイミング解析に現れない**未タイミングのオーディオ CDC**（112 個の CDC-13）と特定。ビルド済み
  DCP を `report_cdc` で解析し、`set_clock_groups` 分割 + `set_max_delay` で拘束（D109）。
- **係数チューニングによる多モデル・モデリング** — トポロジ・乗算器を増やさず、per-model 定数
  だけで Amp 6 / Overdrive 6 / Distortion 7 機種を作り分け（DSP48 数を増やさない）。
- **アンチエイリアス 4x オーバーサンプリング** — ハードクリップ系を 4x + 15-tap デシメーション FIR
  で折り返し抑制。FIR は比率ベース（fs 非依存）で 48→96 kHz 移行時に無変更。
- **offline DSP sim による音作りの高速化** — `tools/dsp_sim` で FPGA と同じ Clash
  `topEntity` 固定小数点パイプラインをホスト CPU 上で実行。D121-D131 では net tone-curve、
  harmonic、knobcheck、distortion-character 評価を Vivado 前に確認してからビット化。
- **完全なハードウェア UI 統合** — HDMI GUI + エンコーダ + フットスイッチ + ペダルを自作 PL IP で
  実装し、Python の単一翻訳層に集約。

### 設計から得た一般化可能な教訓（詳細は付録 4/5）

1. **フィードフォワード（FIR）は分割自由、IIR フィードバックは分割不可** — D82 でフィードバック
   パスを短縮して -0.659→-0.534 ns に回復。
2. **並列乗算は直列 LERP に勝つ（この島では）** — D79 で直列 -3.627 ns vs 並列 -0.496 ns。
3. **エンベロープ変調パラメータはタイミングが安い** — D85/D86 を新規乗算ゼロで実装。
4. **論理等価 + タイミング MET でもバイパスは壊れる** — 必ず実機試聴でゲートする（最重要）。
5. **演算子優先順位の罠** — 一文字の優先順位が数十リビジョンのアンプ voicing の前提を歪めていた。

---

## 数値で見るプロジェクト

| 指標 | 値 |
| --- | --- |
| サンプルレート | 96 kHz / 24-bit |
| DSP アイランドクロック | 33.33 MHz（1 サンプル/サイクル、約 347 サイクル/サンプルの余裕） |
| タイミング改善（アイランド導入） | WNS -10.387 ns → -0.706 ns |
| 採用ベースライン（D155）の WNS | +0.319 ns（フルタイミング MET、WHS +0.013 ns、route errors 0、D109 CDC fwd +0.989） |
| エフェクト | 9 ブロック（Amp 6 / OD 6 / Distortion 7 / Cab 3 機種） |
| 現行 bit / hwh | `8d875cc8a0154a86673ab22e5b142d27` / `e0469cf593e97d582c14bb09ea98d3d3` |
| `set_guitar_effects` レイテンシ | 940 ms → 2.6 ms（IP ハンドルキャッシュ後） |
| 物理操作系 | エンコーダ ×3 / フットスイッチ ×3 / エクスプレッションペダル ×1 |

---

## 技術スタック

| レイヤー | 技術 |
| --- | --- |
| DSP（PL 論理） | **Clash (Haskell)** → VHDL、固定小数点、RBJ バイカッド、SVF、FIR、4x オーバーサンプリング |
| DSP 検証 | `tools/dsp_sim`（Clash `topEntity` 実行）、`measure.py` net tone-curve、golden / bypass invariant |
| FPGA 合成 | **Vivado 2019.1**、ブロックデザイン（Tcl 加算式）、タイミングクロージャ、CDC 解析 |
| 制御層 | **Python 3.6**、PYNQ オーバーレイ API、MMIO / AXI-GPIO |
| UI | HDMI フレームバッファ合成（PIL）、エンコーダ / フットスイッチ / XADC 入力 IP |
| ハードウェア | **PYNQ-Z2 (Zynq-7020)**、Pmod I2S2（CS5343/CS4344）、ADAU1761、ZOOM FP02M、5インチ LCD |

---

## 深掘り技術付録

実装値・係数テーブル・アルゴリズム断片・レジスタマップ・設計の物語は以下に分割：

| 部 | 内容 |
| --- | --- |
| **[1/5 アーキテクチャ & DSP 実装](portfolio/01-architecture-and-dsp.md)** | システム仕様・AXI メモリマップ・クロックドメインアイランド（図解）・ナイフエッジ CDC 究明・Clash 型/数値プリミティブ・エフェクトチェーン |
| **[2/5 各エフェクト & モデリング技法](portfolio/02-effects-and-modeling.md)** | 各エフェクトの内部レジスタ段・パラメータマッピング式・EQ/Reverb/Comp/Wah 内部実装・OD/Amp/Cab/Distortion の per-model 係数テーブル・4x オーバーサンプリングの実装 |
| **[3/5 UI・制御・ビルド/デプロイ](portfolio/03-ui-control-build.md)** | HDMI GUI・エンコーダ/フットスイッチ/ペダル・IP レジスタマップ・`AudioLabOverlay` Python API・ビルド実コマンド・複数コピー先同期・検証規律 |
| **[4/5 エンジニアリングの物語](portfolio/04-engineering-story.md)** | 特出すべき成果・開発の歩み・リアリズムロードマップ（D81-D90）・設計上の課題と学び・HDMI 統合の道のり |
| **[5/5 リファレンス](portfolio/05-reference.md)** | リポジトリ構成・用語集・現状 |

> プロジェクト内部の設計・決定の一次情報は `docs/ai_context/`（`PROJECT_CONTEXT.md` /
> `DSP_EFFECT_CHAIN.md` / `DECISIONS.md` / `TIMING_AND_FPGA_NOTES.md` など）。

---

## 現状（2026-06-22）

採用済みデプロイベースラインは **D155**（`09c8a95`、D153 を supersede）。D121 の
非 Amp 測定駆動 pass、D131 distortion tooling、D134/D135 全 effect 評価・character
強化、D146-D148 の hard CDC pblock + sag slew + clean-headroom、そして 2026-06 の
**D150-D155 voicing アーク**までを段階的に実装・bench-ACCEPTED したビットストリームです。

主な音作り / 安定化変更：

1. **D121-D124**：BD-2 / OCD / Metal / Cab / RAT の測定駆動補正。
2. **D125**：Compressor RATIO を Dyna/Ross sustain 方向へ修正。
3. **D126-D130**：OD-1 / DS-1 / RAT / Amp / Klon / Metal などを実機リファレンスの EQ へ再照合。
4. **D131**：DS-1 / Big Muff / Fuzz Face / Metal の low-end、saturation、sustain を改善し、
   `dist_eval.py` / `targets.py` で distortion-character を自動評価。
5. **D134-D135**：全 effect / knob の objective check を拡張し、Fuzz Face
   mid-hump、Amp MIDDLE / AC30 / JCM800、Cab body を改善。
6. **D146-D149**：safe-bypass CDC を hard pblock（`SLICE_X100Y116:SLICE_X113Y137`）で
   物理固定し、amp sag-attack slew・JC/Twin clean-headroom fix・cab real-IR 31-tap
   rolloff FIR を land。
7. **D150-D155（2026-06 voicing アーク）**：D150 OD/DS の和音 IMD（非対称クリップの
   偶数次差音）を対称クリップで修正、D151 amp の高音増強（post-amp HF シェルフ + cab
   presence。rig の高域は cab が支配し amp の TREBLE/PRESENCE はほぼ効かないと実測で判明）、
   D152/D153 和音高音の "汚い/ブツブツ"（帯域内 IMD・オーバーサンプリング無効と実証）を
   cab ヘッドルーム + presence 戻し → 出力ホット化分の `cabSpeakerKnee` peak-limit 復帰 +
   JC/Twin -1.3 dB トリム（音割れ修正）、D154 ゲイン機の和音 IMD はマルチバンド含め
   非改善＝未出荷、D155 cab speaker FIR を 31→47 タップへ拡張（real-4x12 寄りロールオフ）。

すべて offline sim / golden / bypass invariant で Vivado 前に絞り込み、Vivado timing、
deploy、programmatic smoke、ユーザー bench を通過したものだけを採用しています。D120 / D119 の
Amp sag 変更、D136-D142 / D144 chord-detune、D152 の単独（音割れ）、D154 マルチバンドは
いずれも bench-reject または非改善で未採用です（sim 先行で安価に絞り込む規律）。
最新の正確な状態は `docs/ai_context/CURRENT_STATE.md` /
`docs/ai_context/DECISIONS.md`（D109-D155）を参照。
