# Audio-Lab-PYNQ 技術詳細 (2/5) — 各エフェクト & モデリング技法

> [PORTFOLIO.md](../PORTFOLIO.md) の深掘り技術付録。各エフェクトの内部段構成・パラメータマッピング・モデルごとの差をつける係数チューニング・4x オーバーサンプリングを扱う。

## 8. 各エフェクト詳細

### 8.1 Noise Suppressor（ノイズサプレッサ）
- パラメータ：THRESHOLD / DECAY / DAMP
- 単純なハードゲートではなく **`nsLevel → nsApply` のエンベロープ追従**で滑らかに減衰
- GPIO `axi_gpio_noise_suppressor`（`0x43CC0000`）、閾値は `nsThresholdSample = asSigned9 ctrlA << 13`
- Compressor の前段に配置

### 8.2 Compressor（コンプレッサ）
- パラメータ：THRESHOLD / RATIO / RESPONSE / MAKEUP
- **ステレオリンク・フィードフォワード・ピークコンプレッサ**（`compLevel → compApply → compMakeup`）
- RESPONSE は attack/release の共有平滑時定数（0=最速、255≈128 サンプルで収束）
- ENABLE はこの GPIO 内（bit7）で完結。OFF 時はビット完全バイパス

### 8.3 Wah（ワウ）
- パラメータ：POSITION / Q / VOLUME / BIAS
- **State Variable Filter (SVF)** によるレゾナントバンドパス（D72、D73 で Cry Baby GCB-95 の
  スイープ範囲にリチューン）
- POSITION は GUI/エンコーダ（MANUAL）または **ZOOM FP02M エクスプレッションペダル**
  （PEDAL、A0=XADC VAUX1 経由）で駆動。GPIO レイアウトは変えずに `wah_position_raw` API で切替
- VOLUME カーブは 2 区間の区分線形（byte0→×0.5、byte128→×1.0 ユニティ、byte255→×2.0/+6 dB cap）
- 歪み前に配置（クラシックな pre-distortion wah）

### 8.4 Overdrive（オーバードライブ）
- パラメータ：TONE / LEVEL / DRIVE、**6 モデル選択**（`overdriveModel`、`ctrlD[2:0]`）
- 構成：`drive mul → boost → model pre-clip biquad → モデル別硬さクリップ → tone → level`
- モデル：Ibanez/TS9・BOSS/OD-1・BOSS/BD-2・Vemuram/Jan Ray・Fulltone/OCD・CENTAUR
- 詳細なモデル差は第 9 章

### 8.5 Distortion / Pedalboard（ディストーション・ペダルボード）
- パラメータ：TONE / LEVEL / DRIVE / BIAS / TIGHT / MIX
- **ペダルマスク方式**（`axi_gpio_distortion.ctrlD[6:0]`、bit7 予約）で各ペダルが**独立 Clash 段**：
  `clean_boost`(bit0) / `tube_screamer`(bit1) / `rat`(bit2) / `ds1`(bit3) /
  `big_muff`(bit4) / `fuzz_face`(bit5) / `metal`(bit6)
- 8way mux ではなくマスクにすることで**複数同時・局所的なロールバック/追加**が可能

### 8.6 RAT
- HPF → drive → オペアンプ LPF → ハードクリップ → post LPF → tone → level → mix の専用上流段
- 4x オーバーサンプリング（D89）で折り返し歪みを抑制
- GPIO は歴史的名称 `axi_gpio_delay`（`0x43C80000`）。ペダルマスク bit2 を立てると Python が
  自動的に `rat_on` を assert し、GUI の Distortion ノブを RAT 段（`rat_filter/level/drive/mix`）にルート

### 8.7 Amp Simulator（アンプシミュレータ）
- パラメータ：GAIN / BASS / MID / TREBLE / PRESENCE / RESONANCE / MASTER / **DRV MODE**（8 ノブ）
- **6 モデル**（JC-120 / Twin Reverb / AC30 / Rockerverb / JCM800 / TriAmp Mk3、`amp_model_idx` = `ctrlD[2:0]`）
- 多段カスケード：`HPF → drive → waveshape → pre-LPF → 2nd stage → tone stack → power → resonance/presence → master`
- DRV MODE（`ctrlD[7]`）は本物の DSP 分岐（Clean/Drive）。詳細は第 9 章

### 8.8 Cab IR（キャビネット・シミュレーション）
- パラメータ：MIX / LEVEL / MODEL / AIR
- **15-tap 対称 FIR**（D87、`mulS10` 係数）によるスピーカーロールオフ + D121 の
  cone-breakup presence biquad + 微小モジュレーション
- 3 種（1x12 OPEN BACK / 2x12 BRITISH / 4x12 CLOSED、`ctrlC` = 0/85/170 で量子化選択）

### 8.9 EQ（3 バンド）
- LOW / MID / HIGH、`50` がユニティ（GUI 0..100 → overlay 0..200、50=±0 dB）

### 8.10 Reverb（リバーブ）
- パラメータ：DECAY / TONE / MIX
- **BRAM ディレイライン**（feedback = `mulU8(monoWet, ctrlA)`）+ トーンダンピング + 拡散構造（D97）
- ENABLE は `gate_control.ctrlA` flag bit5 に乗る

### 8.11 各エフェクトの内部レジスタ段構成

各エフェクトは「1 段 1 機能の小さなレジスタステージの連鎖」として実装されています
（**各矢印が最低 1 レジスタ** ＝ パイプライン化）。これがタイミング収束とモジュール性の
両立を支えています：

| エフェクト | 内部段（順） |
| --- | --- |
| Noise Sup | `nsLevelPipe → nsEnv → nsGain → nsPipe` |
| Compressor | `compLevelPipe → compEnv → compGain → compApplyPipe → compMakeupPipe` |
| Wah | `wahPosSmooth → wahFByteR → wahQBandR → wahLow + wahBand → wahApplyPipe`（SVF） |
| Overdrive | `driveMul → driveBoost → modelClip(asymSoftClip) → toneMul → toneBlend → level`（model 5 は cleanBlend） |
| RAT | `ratHighpass → ratDriveMul → ratDriveBoost → ratOpAmpLowpass → ratClip → ratPostLowpass → ratTone → ratLevel → ratMix`（8 段） |
| clean_boost | `cleanBoostMul → cleanBoostShift → cleanBoostLevel`（+ softClip safety） |
| tube_screamer | `tsHpf → tsMul → tsClip(asym) → tsPostLpf → tsLevel` |
| metal | `metalHpf(tight) → metalMul → metalClip(4x hard) → metalPostLpf → metalLevel → shared scoop-notch` |
| ds1 | `ds1Hpf → ds1Mul → ds1Clip(asym, 低い膝) → ds1Tone → ds1Level` |
| big_muff | `bigMuffPre → bigMuffClip(4x cascade) → shared scoop-notch → bigMuffTone → bigMuffLevel` |
| fuzz_face | `fuzzFacePre → fuzzFaceClip(強い非対称) → fuzzFaceTone → fuzzFaceLevel` |
| Amp | `ampHighpass → ampDriveMul/Boost → ampWaveshape(asymClip) → ampPreLowpass → ampSecondStage → ampToneStack(B/M/T) → ampPower → ampResPresence → ampMaster`（9 段） |
| Cab | `cabProducts(4×mulS10) → cabSat → cabIr → cabLevelMix → 15-tap speaker FIR → cone-breakup presence biquad → micro-mod` |
| Reverb | `BRAM tap → tone → feedback → mix` |

ペダル段のフィルタ状態（HPF / post-LPF）は Frame ではなく `fxPipeline` のレジスタ
（例：`tsHpfLpPrevL`, `metalPostLpPrevR`）に保持され、OFF のペダルはサンプルに一切
触れません（ビット完全バイパス）。RAT の 8 段構成が「新ペダル追加のテンプレート」です。

### 8.12 パラメータマッピングの規律（PS → Clash）

Python 側の `0..100`（UI 値）を Clash が読む `0..255` バイトに写す変換は、各パラメータごとに
**意図を持った非線形マッピング**になっています。代表例：

| パラメータ | UI → byte | Clash 側の意味 |
| --- | --- | --- |
| NS THRESHOLD | `ctrlA = round(thr × 255/1000)`（100→26） | `nsThresholdSample = asSigned9 ctrlA << 13` |
| NS DECAY | `ctrlB = round(decay × 255/100)` | 全閉まで 約 1.4 ms（0）〜85 ms（100）の線形ランプ |
| NS DAMP | `ctrlC = round(damp × 255/100)` | 閉ゲイン 約 50%（0）〜0%（100）、`((255-byte)²)>>5` の 2 次カーブ |
| CMP THRESHOLD | `ctrlA = round(thr × 255/100)` | `(ctrlA<<13) − ((ctrlA<<13)>>3)`（ギターレベルで少し早めに効く） |
| CMP MAKEUP | `ctrlD[6:0] = round(mk × 127/100)` | Q8 factor `192 + makeup_u7`（約 0.75×〜1.25×、わざと控えめ） |
| WAH POSITION | `ctrlA` = position byte | `basePositionToFByte` で 4 区間区分線形（pos 0/64/128/192/255 → 約 450/700/1100/1600/2200 Hz、SVF f-byte は 96 kHz で 8/12/19/27/37） |
| WAH Q | `ctrlB = round(q × 255/100)` | `qCoefByte = 128 − (qByte>>1)`（下限 16、暴走防止） |
| WAH VOLUME | `ctrlC = round(vol × 255/100)` | 区分線形 Q8 `[128, 510]`（byte128=ユニティ、byte255=+6 dB cap）、`mulU10` 飽和乗算 |

THRESHOLD のように「ギターの実信号レベルで自然に効く」よう係数に意図的なバイアス
（`>>3` 減算）を入れる、Q のように発振しないよう下限を設ける、といった**実用上のチューニング**が
随所に入っています。

### 8.13 信号生成系エフェクトの内部実装（EQ / Reverb / Compressor / Wah）

歪み系以外の 4 エフェクトも、すべて**乗算を最小化したレジスタ段**で実装されています。

**EQ（3 バンド、`Eq.hs`）** — Linkwitz 風の一次クロスオーバーを「差分」で作ります（乗算ゼロで
帯域分割）：

```haskell
low    = prevLow    + (x - prevLow)    >> 6   -- 低域（一次 LPF）
highLp = prevHighLp + (x - prevHighLp) >> 3   -- 高域クロスオーバー点
mid    = highLp - low                          -- 中域＝差分
high   = x      - highLp                        -- 高域＝差分
-- 各バンドを mulU8(band, ctrl) でゲイン → 加算 → softClip
```

96 kHz では交差周波数を保つためシフトを +1（`>>5/>>2 → >>6/>>3`）。`128/128/128`（ニュートラル）は
ビット完全一致でバイパスされ、最大ブースト時はハードに叩かず**ソフト飽和**します。

**Reverb（`Reverb.hs`）** — **1024 サンプルの BRAM コムフィルタ**（D98 で 2048 に倍化）を核に：

```haskell
feedback   = (monoDry >> 1) + (fAcc3L >> 8)      -- ドライ + 拡散後のリサーキュレート
toneScaled = (tone - tone>>3) >> 1               -- TONE による一次 LPF ダンピング（96 kHz 現行値）
mixed      = satShift8(mulU8(dry, invMix) + mulU8(wet, mix))
```

単一コムは尾が金属的（"boingy"）になるため、**Schroeder オールパス・ディフューザ**を
フィードバックパスに追加（D97）してエコー密度を上げています（ディレイ長を伸ばさずに拡散度↑）。
BRAM はリバーブ専用の 6 ブロックのみ。

**Compressor（`Compressor.hs`）** — ノイズサプレッサと**同じ段数**（envelope 入力 + 2 フィードバック
レジスタ + apply + makeup）で実装した**ピークフォロワ型**：

```haskell
unitySample         = 4_095                      -- ユニティゲインの基準（Q12 系）
compThresholdSample = base - (base >> 3)         -- ギターレベルで少し早めに効くようバイアス
-- env はピーク追従（attack 瞬時 / release は response で可変）、
-- gain は env と threshold/ratio から平滑して算出
```

**Wah（`Wah.hs`）** — **Chamberlin State Variable Filter**。SVF の差分方程式そのもの：

```haskell
high(n) = in        - low(n-1) - qBandR(n-1)     -- 乗算なし
band(n) = band(n-1) + fByteR(n-1) * high(n)      -- BPF 出力
low(n)  = low(n-1)  + fByteR(n-1) * band(n-1)
wahOut  = band(n)
```

`positionToFByte` と `q*band` 積を 1 段早く `wahFByteR` / `wahQBandR` にプリレジスタ化することで、
band/low 更新が 2 乗算を直列に見ないようにしています（タイミング対策）。SVF の f 係数は
`≈ 2·sin(π·f0/fs)` なので、96 kHz では同じフォルマント Hz を保つため f-byte を半分にしています。

---

## 9. モデルごとの差をつける方法（モデリング技法）

本プロジェクトの中核的な工夫が**「同じトポロジで、定数だけを変えて実機の個性を
出し分ける」**手法です。新モデル追加時に回路・乗算器・GPIO を増やさず、
**係数チューニング**だけで差を作るため、FPGA リソースを節約しつつ多モデル化できます。
モデルラベルは "inspired-by" であり、商用回路の複製ではありません。

### 9.1 Overdrive のモデル差（`Overdrive.hs`）

固定構成 `mul → boost → clip → toneMul → toneBlend → level` の中で、**per-model
constants のみ**を切り替えます：

| 関数 | 役割 |
| --- | --- |
| `odDriveK :: Unsigned 3 -> Unsigned 11` | モデル別ゲイン上限係数。`driveGain = 256 + (drive * k)`。例：Jan Ray `k=2`（DRIVE=255 で約 1〜2.99x）、OCD `k=7`（約 1〜7.97x） |
| `odKneeP` / `odKneeN :: Unsigned 3 -> Sample` | ± 半周期の独立クリップ膝。`kneeN < kneeP` で偶数次倍音（非対称）を付与 |
| `odClipHardness` → `asymSoftClipSoft/Med/Hard` | **クリップ硬さ（倍音次数）をモデル固有に**。0=最も柔→3=最も硬。コンパイル時シフトのみ |
| `odSafetyKnee` | 出力安全膝（ホットな LEVEL でも破綻しない上限） |
| `odCleanBlend`（model 5 = CENTAUR/Klon のみ） | **並列クリーンブレンド**。クリップ経路にクリーン経路を 2 つの `mulU8` でミックスし、Klon 特有の「歪んでいるのに芯がクリーン」を再現 |

pre-clip には 1 個だけ共有の RBJ peaking biquad を置き、モデル番号で係数を mux します。
TS9 は 720 Hz の mid hump、OD-1 は 800 Hz mid focus、BD-2 は D129 で控えめな
2300 Hz upper-mid、JanRay は 350 Hz low-mid warmth、OCD は 1300 Hz upper-mid honk、
Klon は 1000 Hz mid bump を持ちます。モデルごとに
バイカッドを複製せず、1 つの段を係数だけで使い分けています。

**実際の per-model 定数（`Overdrive.hs` より抜粋）** — 同じ `asymSoftClip` 構成のまま、
この数値の組だけで 6 機種を弾き分けています：

| model | `odDriveK`<br>(ゲイン上限) | `odKneeP`<br>(+側膝) | `odKneeN`<br>(−側膝) | `odSafetyKnee` | `odClipHardness` | キャラクター |
| --- | --- | --- | --- | --- | --- | --- |
| 0 TS9 | 4 | 2,950,000 | 2,850,000 | 3,350,000 | 0 (最柔) | オペアンプ・ソフト、ほぼ対称、+6 dB @ 720 Hz mid hump |
| 1 OD-1 | 5 | 2,550,000 | 1,750,000 | 3,050,000 | 1 | 早く粗く、強い非対称 |
| 2 BD-2 | 7 | 2,400,000 | 1,900,000 | 3,400,000 | 1 | 偶数次最大（P/N gap 500k）、D129 で +1.5 dB @ 2300 Hz |
| 3 Jan Ray | 2 | 3,600,000 | 3,450,000 | 3,700,000 | 0 | トランスペアレント、D129 で +1.8 dB @ 350 Hz |
| 4 OCD | 7 | 2,450,000 | 2,150,000 | 3,750,000 | 2 | MOSFET 風 hard-leaning、D121 で +4 dB @ 1300 Hz |
| 5 CENTAUR | 4 | 2,400,000 | 2,050,000 | 3,650,000 | 1 | ゲルマ wet + クリーンブレンド、D129 で +4 dB @ 1000 Hz |

`driveGain = 256 + (drive × k)` なので、DRIVE=255 で Jan Ray (k=2) は約 1〜2.99×、OCD (k=7) は
約 1〜7.97× に達します。`kneeN < kneeP` の差分（例：OD-1 は 800k、BD-2 は 500k）が偶数次倍音
（チューブ的な 2 次）の量を決めます。

### 9.2 Amp Simulator のモデル差（`Amp.hs`）

| 関数 | 役割 |
| --- | --- |
| `ampModelIdxF` / `ampDriveModeF` | `fAmpTone` の `[26:24]` からモデル idx、`[31]` から Clean/Drive を抽出 |
| `ampDrivePosDelta` / `ampDriveNegDelta :: Unsigned 3 -> Signed 25` | モデル別の ± ドライブデルタ（ブレイクアップ点を機種ごとにずらす） |
| `ampSecondStageDriveBonus :: Unsigned 3 -> Unsigned 9` | 2 段目ゲインのモデル別ボーナス |
| `ampAsymClip modelIdx intensity drive hyst x` | モデル別の非対称ソフトクリップ（膝 + ヒステリシス。`ampHystBias = prevOut >> 4`） |
| `ampJc120CleanKnee = 7_500_000` | JC-120 クリーンが satShift7 でオーバーフローしないための保護膝 |
| `ampModelDarken` / `ampPreLpfDriveDarken` | モデル別 HF 暗化（pre-LPF の暗さ） |
| 共有トーンスタック・バイカッド | RBJ 設計の Q14 固定小数点。JC-120 は flat、Twin は 400 Hz Fender-style scoop、AC30 は 2200 Hz chime、Rockerverb は 300 Hz low-mid push、JCM800 は 650 Hz mid、TriAmp は 750 Hz modern scoop |
| `ampPreEmph` / `ampDeEmph` | プリ/ディエンファシス（`ampEmphShift=4`、`ampEmphAmount=1`）で帯域を制御 |

トランスの**ブルーム（低域の膨らみ）**、HF の**鉄芯ソフトネス（ドループ）**、ミッド依存の
グラインドなどを共有の微小トリムで付与し、D97 の「箱っぽさ」に戻らないよう調整しています。
DRV MODE は per-model knee delta + 負側の強シフト + per-model pre-LPF darken +
per-model 2nd-stage gain bonus + treble/presence trims からなる**本物の DSP 分岐**です。

**実際の per-model 定数（`Amp.hs` より抜粋）** — 6 機種が「どれだけ早く歪み、どれだけ暗く、
どれだけ 2 段目で押すか」をこの数値の組で表現しています：

| model | `ampCharForModel`<br>(キャラ) | `ampModelDarken`<br>(暗化) | `ampDrivePosDelta`<br>(Drive 膝デルタ+) | `ampSecondStageDriveBonus`<br>(2段目ボーナス) | キャラクター |
| --- | --- | --- | --- | --- | --- |
| 0 JC-120 | 18 | 6 | 16,200 | 22 | 高ヘッドルーム SS クリーン |
| 1 Twin Reverb | 78 | 12 | 85,800 | 33 | グラッシーなチューブクリーン |
| 2 AC30 | 166 | 11 | 232,400 | 47 | 早めのチャイム・ブレイクアップ |
| 3 Rockerverb | 208 | 31 | 374,400 | 85 | 太く暗い EL34 サチュレーション |
| 4 JCM800 | 220 | 16 | 462,000 | 80 | 噛みつくクラシックロック |
| 5 TriAmp Mk3 | 246 | 39 | 615,000 | 116 | タイトなモダンハイゲイン |

`ampCharForModel` が 18→246 と単調に上がることでクリーン〜ハイゲインの「強度バンド」を作り、
`ampModelDarken` / `ampDrivePosDelta` / `ampSecondStageDriveBonus` がその中で各機種の
個性（暗さ・歪み出し・押し）を微分化します。D58 の比例 `ch × factor` 案は乗算器を 4 つ増やし
（DSP48E1 83→87）、その P&R シフトがバイパス経路にノイズを乗せたため**却下**され、
**固定スカラ形（DSP48 数を D55/D68 と同じ 83 に維持）**を採用した経緯があります（リソースと
バイパス健全性の両立）。

**アンプの 9 段カスケード（段ごとの役割）** — 1 つのアンプが何をしているかの内訳：

| 段 | 処理内容 |
| --- | --- |
| `ampHighpassFrame` | 1 次 HPF 形。D109 で dead-pole 優先順位バグを修正済みで、現行は live high-pass として動作 |
| `ampDriveMultiply / Boost` | Q7 プリアンプゲイン。天井 約 19×（キャブ前のライン直の fizz を抑えるためタイト化） |
| `ampWaveshape → ampAsymClip idx intensity drive x` | 1 段目非対称ソフトクリップ。`intensity = ampCharForModel idx`（18〜246）が膝の中心、Drive 時は per-model delta が膝をさらに縮める。負側 post-knee シフトは Clean `>>3` → Drive `>>2` |
| `ampPreLowpassFrame` | post-clip 一次平滑。`baseAlpha = 80+(char>>2)`（96 kHz）、`ampModelDarken`（Clean）+ `ampPreLpfDriveDarken`（Drive）で機種別に暗化 |
| `ampSecondStage` | 2 段目ゲイン/クリップ。gain = `112+(ctrlA>>3)+(char>>2)` + `ampSecondStageDriveBonus`（Drive）。クリップは `intensity = char>>1`（半分、1 段目より柔らかく＝D57 アンチパターン回避） |
| `ampToneStack`（B/M/T） | 3 バンドトーンスタック近似。treble は per-model `ampTrebleGain`（2〜4 kHz の bite は残し 8〜16 kHz の fizz は戻さない） |
| `ampPowerFrame` | `softClipK 3_400_000` のパワー段セーフティ |
| `ampResPresence` | resonance は内部で `×3/4` cap、presence は `×5/8` から per-model trim を引いて `softClipK 3_400_000` |
| `ampSagEnv` | JC-120 以外の tube model で master 前の power-sag envelope を生成（AC30 は深め）。D119/D120 の sag 無効化/静的 trim は bench-reject 済み |
| `ampMasterFrame` | sag を差し引いた master 乗算 + `softClipK 3_300_000`（MASTER が Cab/EQ/Reverb をハードクリップに叩き込まない保護） |

> 1 つの「アンプ」が、実機の **プリアンプ → 段間 → トーンスタック → パワー段 → トランス/プレゼンス
> → マスター**という構造をそのままレジスタ段で写し取っていることが分かります。各段の `softClipK`
> 保護膝（3.3M〜3.4M）が、ホットなノブ設定でも下流を破綻させない「安全弁」として効いています。

### 9.3 Distortion ペダルのモデル差（`Distortion.hs` ほか）

各ペダルを**独立 Clash 段**として実装し、回路的に固有の処理を持たせます：

- **DS-1**：非対称ソフトクリップの膝チューニング（D63/D64 の経緯から、過度な再調整は避ける）
- **Big Muff**：多段クリップカスケード + D131 時点では約 1000 Hz のミッドスクープ・ノッチ + **4x オーバーサンプル**（D90）
- **Fuzz Face**：レベル依存の**動的バイアス**（入力レベルで膝が動く、D85）
- **Metal (MT-2)**：タイト HPF + ハードクリップ + **4x オーバーサンプル**（D88）
- **RAT**：オペアンプ LPF + ハードクリップ + **4x オーバーサンプル**（D89）
- **Tube Screamer**：約 720 Hz のミッドハンプ・バイカッド（D81、`mulS16 y2 15715` の再帰係数）

**各ペダルの実定数（`Distortion.hs` より抜粋）** — どれも `mul → clip → tone → level` の小チェーンで、
**プリゲイン係数・クリップ膝・トーン α・セーフティ膝**の組で性格を分けています：

| ペダル | プリゲイン `gain =` | クリップ膝（P / N） | トーン α | セーフティ膝 | 性格 |
| --- | --- | --- | --- | --- | --- |
| clean_boost | `256 + drive×2` | softClip safety のみ | — | 4,050,000 | 透明なブースト（例外ピークのみ抑制） |
| tube_screamer | `256 + drive×5` | 2,900,000 / 2,750,000（柔・ほぼ対称） | `30 + tone>>2` | softClip | DS-1 より滑らか |
| ds1 | `256 + drive×9` | 1,900,000 / 1,900,000（低い膝・硬め） | `59 + tone>>1` | 3,000,000 | ダイオードペア風ハード寄り |
| big_muff | `448 + drive×11` | 2 段カスケード 1,500,000 → ×208 → 1,250,000 | `25 + tone>>2` | softClipK | D131 で sustain/saturation 強化、厚いファズ + ミッドスクープ |
| metal | `768 + drive×13` | hardClip（閾値 `2,500,000 − drive×6,000`、下限 1,250,000） | post-LPF `13 + tone>>2` | softClip | MT-2 風の中域ブースト + 暗い高域、D131 で saturation edge を維持 |
| legacy dist | `256 + amount×9` | hardClip（閾値 `8,388,607 − amount×28,000`、下限 1,600,000） | one-pole blend | — | レガシー汎用 |

`drive` の係数（×2 / ×5 / ×9 / ×11 / ×12）が「どれだけ押すか」、クリップ膝が「どこで・どれだけ硬く
歪むか」を決めます。HPF/post-LPF の α も TIGHT ノブ（`distTight >> 4/5`）で動き、ペダルごとに低域の
締まりが変わります。

**Big Muff / DS-1 / Metal の共有 EQ 段**は一点もの：一次 LPF では「暗くする」ことしかできず**ミッドを抉れ
ない**ため、飽和後の信号に**負ゲインのピーキング・バイカッド**（`bigMuffScoopFeedforward` +
`bigMuffScoopRecursive`）を掛けます。D131 時点では pedal によって係数を mux し、Big Muff は
約 1000 Hz の scoop、DS-1 は約 500 Hz の shallow scoop、Metal は MT-2 風の +5 dB @ 800 Hz
boost として同じ段を使い分けています。

### 9.4 Cab IR のモデル差（`Cab.hs`）

15-tap FIR の**係数セットをキャビネット × AIR 量で切り替え**ます（`cabCoeff model air index`、
`Signed 10` 係数を `mulS10` で畳み込み）。例えば OPEN BACK の低 AIR では先頭タップが
`72, 116, 48, 20, …` のように中域を持ち上げ、British / Closed では暗めの係数に切り替わります。
加えてモデル別のスピーカー/ボディ共振/プレゼンスの膝も持ちます：

| cab | `cabSpeakerKnee` | `cabBodyResKnee` | `cabPresenceKnee` |
| --- | --- | --- | --- |
| 0 OPEN BACK | 5,600,000 | 2,400,000 | 3,600,000 |
| 1 BRITISH | 4,000,000 | 1,600,000 | 3,000,000 |
| 2 CLOSED | 2,800,000 | 1,200,000 | 2,400,000 |

AIR ノブは 3 段（`<86 / <171 / それ以上`）に量子化され、各段で別の FIR タップ列を選ぶことで
「マイクをスピーカーに近づける／離す」ニュアンスを表現します。

**各キャビの DSP シェイプ（IR 畳み込みなしで実機特性を近似）** — BRAM の長い IR を持たず、
短い early/body 係数、15-tap speaker-rolloff FIR、D121 の cone-breakup presence biquad、
プレゼンス `softClipK`、fizz 残差減算、ボディ強調で「ギタースピーカーは 5 kHz 以上で
ロールオフしつつ、2〜4 kHz に切り込む presence peak を持つ」特性を再現しています：

| cab | 直接/ボディ比 | Nyquist 抑圧 | プレゼンス | fizz 減算 | ボディ強調 | 参照スピーカー |
| --- | --- | --- | --- | --- | --- | --- |
| 0 OPEN BACK | 2.76:1（直接優勢） | -16 | `softClipK(3.6M)` 25% | 12.5% | 0% | Fender 系 |
| 1 BRITISH | 1.24:1（バランス） | -24 | `softClipK(3.0M)` 12.5% | 25% | 6.25% | Vox 系（Celestion V30） |
| 2 CLOSED | 0.42:1（ボディ優勢） | -44 | `softClipK(2.4M)` 12.5% | 50% | 12.5% | Marshall/Mesa 系 |

`mix=0` がドライ（生）、`mix=100` が完全キャブシェイプ。`cabProducts` は 4 つの `mulS10` 積を
「early（直接成分）」と「body（胴鳴り）」に分け、body は `softClipK(cabBodyResKnee)` を通して
胴の共振を、presence は `softClipK(cabPresenceKnee)` を通してコーン・プレゼンスを付与します。
その後段で 15-tap FIR がスピーカーの高域ロールオフを作り、D121 の `cabPresence*Frame` が
FIR だけでは分解能不足だった 2.8 kHz 付近の cone-breakup peak を足します。**BRAM も IR
ローダも使わず、LUT/DSP 内で完結**しているのがこの方式の利点です。

### 9.5 D121: 測定駆動の非 Amp リボイス

D121 は「全部の音を派手に作り替えた」ビルドではありません。D119/D120 の Amp sag 変更が
bench で rejected されたため、D99 系の Amp キャラクターを温存し、**Amp 以外の実機との差が
測定で見えた場所だけ**を直しています。すべて `tools/dsp_sim/measure.py` で bypass 比の
net tone-curve を測ってから Vivado に進めました。

| 対象 | 変更 | 実装上の意味 | offline 測定 |
| --- | --- | --- | --- |
| OD BD-2 | pre-clip biquad を 1500 Hz → 2300 Hz、+3.5 dB | クリップ前に上中域を押し、BD-2 の明るい bite を出す | peak 約 2310 Hz |
| OD OCD | 新規 pre-clip biquad +4 dB @ 1300 Hz | 以前 flat だった OCD に upper-mid honk を追加 | +3.7 dB @ 1290 Hz |
| Metal | Big Muff 用 ~700 Hz scoop-notch の gate を `bigMuffOn || metalDistortionOn` に拡張 | 既存 biquad を再利用し、Metal の missing mid-scoop を新規段なしで実現 | dip 593-720 Hz |
| Cab | speaker FIR 後に +3.5 dB @ 2800 Hz peaking biquad | 15-tap FIR では解像しにくい cone-breakup presence を専用段で補う | +3.2 dB @ 2806 Hz |

この変更で新たに増えた有意な構造は Cab の presence biquad だけです。Metal は既存 Big Muff
scoop-notch を通す gate 条件の拡張で済ませ、Overdrive は既にあった「共有 pre-clip biquad +
係数 mux」の表に BD-2/OCD の係数を追加/変更しています。D121 の golden regression は 11/11、
all-off bypass は sample-exact、Vivado routed timing は WNS `+0.726 ns` / TNS `0` / WHS
`+0.012 ns` / route errors `0` で通過し、PL smoke と bench も通っています。

### 9.6 Amp baseline と rejected sag line

Amp Simulator はこのプロジェクトで最も bench の影響が大きいブロックです。D110-D112 では、
当時の D109 CDC 修正後の文脈で Amp を大きく開け直し、一度 bench-accepted されました。しかし
その後の D113-D120 の amp identity / de-muffle / sag-disable / static-trim 路線は、最終的に
ユーザー bench で「音量・質感が違う」と rejected され、D120 で D99 系へ rollback されました。

その後、D122 / D128 / D130 で Amp は再び **既存 table / coeff の範囲だけ**を使って
bench-accepted な realism pass を重ねています。D119/D120 の sag removal / static trim は
今も rejected のままですが、現行 D135 の Amp source は D99/D121 untouched ではありません。
ポートフォリオで Amp を語るときは、次のように分けるのが正確です。

| 系譜 | 状態 | 扱い |
| --- | --- | --- |
| D99 / D121 Amp | D120 rollback 後の accepted character。D121 では Amp source untouched | D121 初期 voicing line の土台 |
| D110-D112 | D109 後の Amp full revoicing として一度 accepted | 重要な engineering episode / 履歴 |
| D113-D118 | amp identity / de-muffle 候補。build / smoke 済みのものもあるが formal acceptance なし | 現行値として語らない |
| D119 | dynamic sag master modulation disable | bench rejected |
| D120 | sag 全廃 + static master trim | bench rejected、D99 へ rollback |
| D122 / D128 / D130 / D135 | 既存 ampScoop / presence / drive bonus / darken / treble trim / MIDDLE / power-headroom の measured retune | 現行 D135 Amp の accepted line |

この履歴から得た教訓は単純です。Amp のような envelope / sag / master level が絡むブロックは、
timing-clean や offline 測定だけでは合格にできません。**音量の揺れ・弾いたときのコンプレッション・
実アンプらしさは最終的に bench listening で決まる**ため、rejected された sag 路線は、明示的な
新方針なしに再試行しない扱いにしています。

### 9.7 4x オーバーサンプリング（アンチエイリアス）

ハードクリップ系（Metal / RAT / Big Muff）は折り返し歪みが出やすいため、
**線形補間アップサンプル → サブサンプルごとにクリップ → 15-tap デシメーション FIR**
（共有 `os4x*` ヘルパー）で処理します。FIR はフィードフォワードなので自由にパイプライン化
できますが、IIR バイカッドはフィードバックを跨いで分割しません（D90 の教訓：
「並列乗算はこのアイランド上で直列に勝つ」「深いカスケードは FIR 乗算と直列にせず
レジスタ更新パスに隔離する」）。

**実装（`Distortion.hs` の共有ヘルパー）**：

```haskell
-- ① 4x アップサンプル：現サンプル x1 と次サンプル xn の間を線形補間
os4xInterp x1 xn = (x1, p1, p2, p3)
  where p1 = (3*x1 + xn)/4   -- 1/4 点
        p2 = (x1 + xn)/2     -- 1/2 点
        p3 = (x1 + 3*xn)/4   -- 3/4 点

-- ② 各サブサンプルを個別にクリップ（ここで高調波が 4x 帯域に展開）
os4xSubSamples thr x1 xn = (hardClip p0 thr, hardClip p1 thr, ...)

-- ③ 15-tap 対称デシメーション FIR で 4x→1x、折り返し成分を除去
os4xDecimProducts q0 q1 q2 q3 hist = (s0, s1, s2)   -- 係数例 104 / 118 ...
os4xHistShift   q0 q1 q2 q3 hist = q3 +>> q2 +>> q1 +>> q0 +>> hist  -- 履歴更新
```

- Big Muff は単純な 1 段クリップではなく **`bigMuffOsCascade`**（D131-D135 は
  `softClipK 1,500,000` → ×208 → `softClipK 1,250,000` の 2 段カスケード）を
  各サブサンプルに適用し、`Vec 16 Sample` の履歴を
  `os4xHistShift` で回します
- Metal の閾値は `metalClipThreshold = 3,300,000 − drive×6,000`（下限 1,450,000）と動的
- デシメーション FIR は**比率ベース（カットオフ＝fs_os/8、正規化 0.125）なので fs 非依存**。
  48→96 kHz 移行で無変更だった（リボイスの最大の塊を回避）

> **ポイント**：これらの差はすべて「固定トポロジ内の定数 + 段の有効/無効」で実現し、
> 新トポロジ・新乗算器・新 GPIO を増やしません。係数は実機リファレンスを参照し、
> RBJ バイカッド設計や非対称クリップ膝の手計算で求めています。

### 9.8 96 kHz への係数リボイス

D98 で 48→96 kHz 化した際、**fs 依存の全 DSP 定数を再計算**しました：

- 7 つのバイカッドを fs=96k で RBJ 再計算（旧 48k 係数を完全再現できる検証スクリプトで担保）
- 一次フィルタのシフトを +1、`onePoleU8` の alpha を `a' = 1 - sqrt(1-a)` で再フィット
- HP 係数 `>>8 → >>9`、エンベロープ/LFO 時定数を半分、リバーブ/拡散/キャブモジュレーションの
  ディレイ長を倍
- **4x オーバーサンプラの補間 + デシメーション FIR は比率ベース（fs 非依存）なので無変更**
  ＝ 移行コストの最大の塊を回避

各定数は旧 48k 値をコメントとして併記し、回帰を追えるようにしています。

---
