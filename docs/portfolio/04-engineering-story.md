# Audio-Lab-PYNQ 技術詳細 (4/5) — エンジニアリングの物語

> [PORTFOLIO.md](../PORTFOLIO.md) の深掘り技術付録。特出すべき成果・数値・技術スタック・開発の歩み・リアリズムロードマップ・設計上の課題と学び・HDMI 統合の道のりを扱う。

## 13. 特出すべきエンジニアリング成果

ポートフォリオとしてアピールできる技術的ハイライト：

1. **関数型 HDL（Clash/Haskell）による DSP 実装**
   C++ プロトタイプを廃し、Clash ソースを「DSP 挙動の唯一の真実」とする設計。挙動を
   保ったままのリファクタを型システムで保証し、生成 VHDL の論理等価性で検証できる。

2. **タイミング収束のためのクロックドメイン・アイランド設計**
   100 MHz で収束しなかった深い歪みチェーン（WNS -10.387 ns）を、DSP コアだけ低速ドメインに
   隔離して解決。CDC は `axis_clock_converter` で安全にブリッジし、ファブリックの既存 CDC を温存。

3. **「ナイフエッジ」バグの根本原因究明（CDC デバッグの白眉）**
   「DSP 再ビルドのたびにバイパス音が壊れる」謎を、**静的タイミング解析に現れない未タイミングの
   オーディオ CDC**（DSP 出力→DAC の分散 RAM 非同期 FIFO、112 個の CDC-13）と特定。ビルド済み
   DCP を開いて `report_cdc` で物理的に突き止め、`set_clock_groups` 分割 +
   `set_max_delay -datapath_only` で拘束（D109）。これで「再ビルド＝バイパス破壊」の呪いが解けた。

4. **offline DSP sim による音作りループの高速化**
   FPGA と同じ Clash `topEntity` 固定小数点パイプラインを host CPU 上で実行し、bypass invariant /
   golden regression / net tone-curve を Vivado 前に確認できるようにした。D121-D131 では
   frequency-shaping、harmonics、knobcheck、distortion-character、target-check を使い、
   build 前に狙いの周波数・sustain・low-end へ着地していることを確認。

5. **アンチエイリアス 4x オーバーサンプリング**
   ハードクリップ系を 4x オーバーサンプル + 15-tap デシメーション FIR で折り返し抑制。FIR は
   比率ベースで fs 非依存に設計したため 48→96 kHz 移行時に無変更で済んだ。

6. **96 kHz 化（レイテンシ削減）**
   コーデック double-speed（BCLK = MCLK/2）で 48→96 kHz 化し、fs 依存の全 DSP 定数を RBJ で
   再計算してコーナー周波数・時定数を保ったまま移行。

7. **係数チューニングによる多モデル・モデリング**
   トポロジ・乗算器を増やさず、per-model constants（drive delta / clip 膝 / 硬さ / バイカッド /
   クリーンブレンド）だけで Amp 6 / Overdrive 6 / Distortion 7 機種を作り分け。

8. **拡張容易なペダルマスク・アーキテクチャ**
   ディストーション部を 8way mux ではなくビットマスクで構成。各ペダルが独立段なので、
   ロールバックや新ペダル追加が局所的（予約ビットあり）。

9. **完全なハードウェア UI 統合**
   HDMI GUI + ロータリーエンコーダ + フットスイッチ + エクスプレッションペダルを自作 PL IP で
   実装し、Python の単一翻訳層（`EncoderEffectApplier`）に集約。

10. **堅牢なデプロイ運用**
   複数コピー先 md5 同期、プログラム的スモーク + 実機試聴ゲート、Clash VHDL 再生成の mtime トラップ
   回避など、再現性のあるビルド/デプロイ規律を確立。

---

## 14. 数値で見るプロジェクト

| 指標 | 値 |
| --- | --- |
| サンプルレート | 96 kHz / 24-bit |
| DSP アイランドクロック | 33.33 MHz（1 サンプル/サイクル、約 347 サイクル/サンプルの余裕） |
| ファブリッククロック | 100 MHz |
| タイミング改善（アイランド導入） | WNS -10.387 ns → -0.706 ns |
| 採用ベースライン（D131）の WNS | +0.631 ns（WHS +0.019 ns、route errors 0） |
| D131 D109 CDC slack | `clk_fpga_0 -> clk` +3.353 ns / `clk -> clk_fpga_0` +6.286 ns |
| エフェクト段数 | 9 ブロック（内部はさらに多段カスケード） |
| Amp モデル | 6 |
| Overdrive モデル | 6 |
| Distortion ペダル | 7（マスク方式、bit7 予約） |
| Cab IR | 3 プリセット、15-tap FIR |
| 4x オーバーサンプル段 | Metal / RAT / Big Muff |
| `set_guitar_effects` レイテンシ | 940 ms → 2.6 ms（IP ハンドルキャッシュ後） |
| HDMI 出力 | 800×600 @ 60 Hz（800×480 UI 合成） |
| 物理操作系 | エンコーダ ×3 / フットスイッチ ×3 / エクスプレッションペダル ×1 |

**現行 D131 bit/hwh**：`fdab62d5ef229ec64dc60fe9395cbf06` /
`d852ec4e737460ad016b41f0a3f71de2`。小さなプロトタイプではなく、HDMI / input IP /
Pmod I2S2 / full DSP chain を統合した状態で、Zynq-7020 に収まっています。**モデルを増やしても不要に DSP48 数を増やさない**
（固定スカラ・定数チューニング、共有バイカッド、既存段の gate 拡張）方針が、この限られた
リソース内で多モデル・多エフェクトを成立させている要です。

### 14.1 ワンクリック・チェーンプリセット（13 種）

GUI からチェーン全体を 1 クリックで切り替えられるプリセットを 13 種用意：

```
Safe Bypass / Basic Clean / Clean Sustain / Light Crunch / TS Lead /
RAT Rhythm / Metal Tight / Ambient Clean / Solo Boost /
Noise Controlled High Gain / DS-1 Crunch / Big Muff Sustain / Vintage Fuzz
```

各プリセットは全 GPIO ワード（NS / CMP / WAH / OD / DIST / RAT / AMP / CAB / EQ / RVB）の
組み合わせを定義し、`set_guitar_effects` で一括適用されます。

---

## 15. 技術スタック

| レイヤー | 技術 |
| --- | --- |
| DSP（PL 論理） | **Clash (Haskell)** → VHDL、固定小数点、RBJ バイカッド、SVF、FIR、4x オーバーサンプリング |
| DSP 検証 | `tools/dsp_sim`（Clash `topEntity` 実行）、bypass invariant、golden regression、`measure.py` net tone-curve |
| FPGA 合成 | **Vivado 2019.1**、ブロックデザイン（Tcl 管理、加算式 integration）、タイミングクロージャ、CDC 解析（`report_cdc`） |
| 制御層 | **Python 3.6**、PYNQ オーバーレイ API、MMIO / AXI-GPIO、IP ハンドルキャッシュ |
| UI | HDMI フレームバッファ合成（PIL）、ロータリーエンコーダ / フットスイッチ / XADC 入力 IP |
| ハードウェア | **PYNQ-Z2 (Zynq-7020)**、Pmod I2S2（CS5343/CS4344）、ADAU1761、ZOOM FP02M、5インチ LCD |

---

## 16. 開発の歩み（代表的なマイルストーン）

| 区切り | 内容 |
| --- | --- |
| 初期 | ADAU1761 コーデック + Clash DSP の基本チェーン確立 |
| D11 / D14 | ノイズサプレッサ / コンプレッサ専用 GPIO 追加 |
| D45 / D55 | Overdrive 6 モデル / Amp 6 モデルの係数モデリング |
| D72-D73 | Wah（SVF レゾナントバンドパス、Cry Baby リチューン） |
| D75 | **DSP クロックドメイン・アイランド**（タイミング解決の核心） |
| D76 | FP02M エクスプレッションペダル（XADC）+ IP ハンドルキャッシュ最適化 |
| D78 | フットスイッチ ×3 統合 |
| D79-D90 | リアリズムパス（トーンスタックバイカッド、動的バイアス/サグ、Cab FIR、4x オーバーサンプリング） |
| D89 / D94 | アイランドクロック 50→40→33.33 MHz（オーバーサンプラのヘッドルーム） |
| D98 | **96 kHz 化**（コーデック double-speed、全係数リボイス） |
| D109 | **safe-bypass ナイフエッジの根本究明＆修正**（未タイミング CDC） |
| D110-D112 | アンプ全面リボイス（当時 bench-accepted、後続の amp 路線評価の基準点） |
| D113-D118 | アンプ個性 / RAT / de-muffle 候補。build / smoke できたものもあるが formal baseline にはしない |
| D119-D120 | Amp sag disable / static trim を試行し、bench rejected。D99 系 Amp へ rollback |
| D121 | **offline sim 測定駆動の非 Amp リボイス**。D99 Amp を保持し、BD-2 / OCD / Metal / Cab を補正 |
| D122-D127 | Amp/Cab/RAT/Compressor/OD-1/DS-1/RAT の reference-alignment pass |
| D128-D130 | Amp PRESENCE / OD-DS-RAT / Amp 2nd-pass EQ re-collation |
| D131 | **現行 canonical baseline**。DIST low-end + saturation/sustain + `dist_eval.py` / `targets.py` |

---

## 17. リアリズム・ロードマップ（D81-D90）— 系統的な実機近似

D81 以降は「実機らしさ」を**項目ごとに 1 つずつ追加し、その都度実機試聴でゲート**する
系統的なリアリズム改善を行いました。各リビジョンは独立ビット・独立 md5・独立ロールバック
ポイントを持ち、**1 つでも試聴で落ちたら即ロールバック**できる規律です。

| # | 追加内容 | 手法 | 島 WNS |
| --- | --- | --- | --- |
| D81 | TS9 約 720 Hz ミッドハンプ | プリクリップ・ピーキングバイカッド（5 乗算を並列和） | -0.193 ns |
| D82 | Big Muff 約 700 Hz ミッドスクープ | 負ゲイン・ピーキングバイカッド（**pipeline-split**） | -0.534 ns |
| D83 | Fender ブラックフェイス・ミッドスクープ | 共有アンプトーンスタック・バイカッド（モデル別 mux） | -0.381 ns |
| D84 | AC30 チャイム + JCM800 ミッド | 上記 mux の係数追加のみ | -0.472 ns |
| D85 | Fuzz Face 動的バイアス | 演奏レベル追従エンベロープで膝を動かす（**乗算なし**） | -0.122 ns |
| D86 | パワーアンプ・サグ | master レベルを遅いピークフォロワで下げる（**DSP フリー**） | -0.397 ns |
| D87 | キャブ・スピーカー FIR | 15-tap 対称線形位相 FIR（**pipeline-split**） | -0.476 ns |
| D88 | Metal MT-2 の 4x オーバーサンプル | 線形補間 + サブサンプルクリップ + デシメーション FIR | -0.496 ns |
| D89 | RAT の 4x オーバーサンプル + **島 50→40 MHz** | os4x 共有ヘルパー化、島クロック低速化でヘッドルーム確保 | **+1.846 ns** |
| D90 | Big Muff の 4x オーバーサンプル | 2 段カスケードを履歴更新パスに隔離 | -0.036 ns |

D89 は **D72 以来初めて設計全体がタイミング MET**（失敗エンドポイント 0）になった節目です。
これらを通じて得た**再利用可能な設計原則**が次章の「学び」です。

## 18. 設計上の課題と学び（Challenges & Lessons Learned）

ポートフォリオとして最も価値があるのは、**ハマった問題とそこから得た一般化可能な教訓**です。

### 18.1 「フィードフォワードは分割自由、IIR フィードバックは分割不可」
深い演算を 1 サイクルに詰めるとタイミングが落ちます。**FIR（フィードフォワード）は自由に
パイプライン分割**できる一方、**IIR バイカッドのフィードバックループは素朴に分割できません**。
D82 ではフィードフォワード和 `b0·x+b1·x1+b2·x2` を 1 段早く `fAcc3L` に先計算し、再帰段は
`−a1·y1−a2·y2` だけでループを閉じる——**数学的に同一だが、フィードバックパスを短くした**ことで
バイカッドをクリティカルセットから外し、-0.659 → -0.534 ns に回復させました。

### 18.2 「並列乗算は直列 LERP に勝つ（この島では）」
D79 の Klon クリーンブレンドで、1 乗算の直列 LERP 書き換えは **-3.627 ns / 117 fail** と大破。
2 つの並列 `mulU8` のほうが **-0.496 ns** と遥かに良くルーティングされました。Vivado の P&R は
直列依存より並列構造を好む——「乗算器を惜しんで直列化」は逆効果になり得る、という教訓です。

### 18.3 「エンベロープ変調パラメータはタイミングが安い」
D85（Fuzz Face 動的バイアス）/ D86（サグ）は**新規乗算ゼロ**（abs + shift + compare のみ）で
動的な実機挙動を足せました。DS-1 のクリティカルパスに配置圧をかけないため、D85 は島全体で
わずか 3 fail と R3/R2 中の最良 WNS。**「動的さ＝高コスト」ではない**ことの好例です。

### 18.4 「論理等価 + タイミング MET でもバイパスは壊れる」（最重要）
D58 / D102-D106 で、**ゲートオフのエフェクト内部しか触らない・VHDL 論理等価・タイミングクリーン**
なリファクタが、それでも all_off バイパスを歪ませました。原因は**未タイミングのオーディオ CDC**
（第 5.4 章）で、ネットリスト変更が配置を動かし、静的解析に現れずにバイパスを破壊していたのです。
**教訓：等価性証明やタイミング MET だけでマージしてはいけない。必ず実機試聴（all_off クリーン）で
ゲートする。** この根本原因（112 個の CDC-13）を D109 で `set_max_delay` で拘束し、ようやく
「再ビルド＝バイパス破壊」の呪いが解けました。

### 18.5 offline sim は「耳の代替」ではなく「Vivado 前の絞り込み」

D121 で導入した `tools/dsp_sim` は、音作りの候補を Vivado 前に大きく絞れるようにしました。
D121 の BD-2 / OCD / Metal / Cab 変更に加え、D131 では `dist_eval.py` / `targets.py` によって
low-end、sustain、IMD/fizz、target PASS/FAIL まで Vivado 前に確認しています。これにより、
30〜40 分級の Vivado build を「試し打ち」に使わずに済みます。

ただし sim は DSP island の論理だけを動かします。Pmod I2S2、CDC、routing、PLL、実アンプでの
弾き心地は見えません。したがって正しい使い方は、**sim で候補を落とし、Vivado / smoke / bench
で採用を決める**ことです。D121-D131 が通ったのは、この分担を守ったからです。

### 18.6 negative bench result も設計データとして残す

D119/D120 の Amp sag 路線は、timing-clean / deploy / smoke の一部を通っても bench で rejected
されました。これは失敗として消すのではなく、**「この方向はユーザーの実機では違う」**という
設計データです。結果として D121 は Amp を触らず、D99 系の accepted character を保ったまま
非 Amp の外れだけを直す方針から再開し、その後 D122/D128/D130 のような table/coeff 限定の
Amp pass だけを bench-accepted line として採用しました。

FPGA の音作りでは「作れる」ことと「採用できる」ことは別です。特に sag / master / envelope の
ように弾いたときの音量感へ直結する機能は、数値で良さそうに見えても演奏感で落ちます。rejected
branch を履歴として明示することで、同じ方向を無自覚に繰り返すリスクを減らしています。

### 18.7 演算子優先順位の罠（dead-pole バグ、履歴上の重要例）
アンプ入力 HP の `prevOut * 509 \`shiftR\` 9` が `prevOut * (509>>9) == prevOut * 0` と解釈され、
**極が死んで単なる 1 次差分**になっていました（明るいが低域が出ない）。括弧で `(prevOut*509)>>9`
と修正してライブな極（約 120 Hz）に。**一文字の優先順位が、何十リビジョンものアンプ voicing の
前提を歪めていた**——D110-D112 の全面リボイスの引き金になった、履歴上の重要な debugging example
です。D121 当時は D99 系 Amp character を保持していたため、この節は「現行 D131 Amp がこうなっている」
という説明ではなく、設計判断の履歴として読むのが正確です。

### 18.8 その他の実地で踏んだ罠
- **mtime トラップ**：`make ip` が Clash VHDL 再生成を黙ってスキップ（§12.1）
- **MMIO before overlay**：オーバーレイロード前の `pynq.MMIO` 読みは `/dev/mem` をハングさせ
  カーネルを殺す。ビット確認は `pynq.PL.bitfile_name` を使う
- **複数コピー先同期漏れ**：ボード上のビットコピーが一箇所古いと、意図せず別ビットがロードされる
- **HDMI の二重 download**：同一セッションで 2 度目の `download=True` は rgb2dvi PLL を外し LCD が
  白画面化。冷間電源再投入でのみ復帰

## 19. HDMI 統合の道のり

5 インチ LCD への HDMI 出力は、**実機の LCD が timing に厳しく、何度も白画面**に阻まれた難所でした。

| フェーズ | 内容・結末 |
| --- | --- |
| Phase 2D-4 | HDMI ブリッジを実オーバーレイで検証、Vivado 統合のドラフト |
| Phase 5A-5C | 出力側の白画面を診断し、ユーザー確認済みの 800×480 左上ビューポートを確定 |
| Phase 6F-6G | 右シフト再発を bbox 検出器 + 実 UI 視覚診断で修正、x 原点を `x=0` に確定 |
| Phase 6H | **ネイティブ 800×480 @ 40 MHz timing を試行 → 実 LCD が白画面で拒否（却下）** |
| **Phase 6I** | **VESA SVGA 800×600 @ 60 Hz / 40 MHz** を採用し、800×480 GUI をフレームバッファ `(0,0)` に合成（行 480-599 は黒）。**成功・現行ベースライン** |

**得られた知見**：

- `v_tc` IP は `VIDEO_MODE {Custom}` を**先行する `set_property` パスで**設定しないと `GEN_*`
  timing 値を無視する（プリセットの 1280×720 のまま）
- rgb2dvi v1.4 の PLL は 40 MHz 画素クロックで VCO 下限（800 MHz）に居て、電源投入後はロックするが
  再 download でロックを外しうる → 「既に正しい」を VTC GEN_ACTSZ で検出し `download=False` で attach
- HDMI のカラーチャネル順：生の `backend.start(arr)` では R=255 が緑に化ける。compose の
  `placement="manual"` 経路を使うと正しい色になる
- デプロイ後に白画面なら**電源再投入 → Notebook セル 1 回**で PLL が確実に再ロックする
