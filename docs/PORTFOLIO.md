# Audio-Lab-PYNQ — リアルタイム・ギターエフェクター (FPGA / PYNQ-Z2)

**アンプ／ペダルの実機モデリングを、ソフトウェアではなく FPGA の論理回路として走らせ、
96 kHz・サブミリ秒レイテンシで動かす**リアルタイム・マルチエフェクト・ギタープロセッサ。
DSP は関数型 HDL（Clash/Haskell）で記述し、HDMI GUI・ロータリーエンコーダ・フットスイッチ・
エクスプレッションペダルまで自作 PL IP で統合した、フルスタックな組み込みハード／ソフト協調設計。

> 本ページはポートフォリオサイト向けの概要。実装値・係数・アルゴリズム・設計の物語は
> **[深掘り技術付録](#深掘り技術付録)**（全 5 部）を参照。

**現行の採用済みデプロイベースライン**は **D121**（merge commit `d07c8e9`、
bit md5 `9a57c50ae405bce717648dc1585eaf4b`）。D109 の CDC 修正で DSP 再ビルド時の
safe-bypass 破壊を根本解決したうえで、D99 の受け入れ済み Amp キャラクターはそのまま残し、
Overdrive / Distortion / Cab の実機から外れていた帯域だけを offline DSP sim で測定・補正した
ビルドです。Vivado routed timing は **WNS +0.726 ns / TNS 0 / WHS +0.012 ns**、実機 PL smoke と
ユーザー bench で合格しています。

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
  `topEntity` 固定小数点パイプラインをホスト CPU 上で実行。D121 では BD-2 / OCD / Metal / Cab の
  net tone-curve を Vivado 前に測定し、golden 11/11 と bypass bit-exact を確認してからビット化。
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
| 採用ベースライン（D121）の WNS | +0.726 ns（フルタイミング MET、TNS 0、route errors 0） |
| エフェクト | 9 ブロック（Amp 6 / OD 6 / Distortion 7 / Cab 3 機種） |
| D121 FPGA リソース | LUT 30,792 / FF 28,896 / BRAM tile 6 / DSP48E1 142 |
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

## 現状（2026-06-14）

採用済みデプロイベースラインは **D121**。D121 は、D120 で bench-reject された Amp sag 変更路線を
捨て、ユーザーが選んだ D99 系の Amp キャラクターへ戻したうえで、**Amp 以外の外れていた帯域だけ**
を測定駆動で補正したビットストリームです。

D121 の 4 つの音作り変更：

1. **BD-2**：pre-clip biquad を 1500 Hz から 2300 Hz へ移し、+3.5 dB の明るい上中域へ。
2. **OCD**：従来 flat だった pre-clip に +4 dB @ 1300 Hz の upper-mid honk を追加。
3. **Metal**：既存 Big Muff 用の約 700 Hz scoop-notch biquad の gate を
   `bigMuffOn || metalDistortionOn` に広げ、Metal の mid-scoop を新規段なしで実現。
4. **Cab**：15-tap speaker FIR だけでは解像できない cone-breakup presence を、
   FIR 後の +3.5 dB @ 2800 Hz peaking biquad で追加。

すべて `tools/dsp_sim/measure.py` で Vivado 前に確認し、BD-2 peak 2310 Hz、OCD +3.7 dB @ 1290 Hz、
Metal dip 593-720 Hz、Cab +3.2 dB @ 2806 Hz を確認済み。golden regression 11/11 と bypass
bit-exact も通過しています。D120 / D119 の Amp sag 変更は bench-reject 済みで、明示的な新方針が
ない限り再試行しません。最新の正確な状態は `docs/ai_context/CURRENT_STATE.md` /
`docs/ai_context/DECISIONS.md`（D109-D121）を参照。
