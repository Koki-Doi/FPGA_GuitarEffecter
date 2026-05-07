# Audio-Lab-PYNQ

PYNQ-Z2 と ADAU1761 オーディオコーデックを使って、Line-in の音声を FPGA 上で処理し、ヘッドホン/ライン出力へ返すためのオーディオDSP実験環境です。

現在の主な用途は、ギター/ライン音声向けのリアルタイムエフェクト処理です。Jupyter Notebook からエフェクトの ON/OFF と各パラメータを操作できます。

## 現在の機能

- PYNQ-Z2 用 Vivado オーバーレイ
- ADAU1761 コーデック初期化と Python からのレジスタ制御
- Line-in からのリアルタイム入力
- PYNQ-Z2 の実配線に合わせた LOUT/ROUT 出力経路
- Line-in -> headphone のパススルー
- 単体リバーブの操作
- 複数エフェクトを固定順で通すギターエフェクトチェーン
- pedal-mask 方式の Distortion Pedalboard (`clean_boost` /
  `tube_screamer` / `rat` / `ds1` / `big_muff` / `fuzz_face` /
  `metal` の **全 7 ペダル実装済**、bit 7 のみ将来 reserved)
- BOSS NS-2 / NS-1X 風 Noise Suppressor、stereo-linked feed-forward
  Compressor、実機ペダル風 voicing pass を反映した既存ステージ
- 13 種類の Chain Preset (Safe Bypass を含む) で 1 クリックでチェーン全体を切替
- DMA を使った入力/出力経路のデバッグ用ノートブック

## エフェクトチェーン

`GuitarEffectsChain.ipynb` および `GuitarPedalboardOneCell.ipynb` では、以下の順番でエフェクトを処理します。

```text
Noise Suppressor -> Compressor -> Overdrive -> Distortion Pedalboard -> RAT Distortion -> Amp Simulator -> Cab IR -> EQ -> Reverb
```

各エフェクトは個別に ON/OFF できます。

| エフェクト | パラメータ |
| --- | --- |
| Noise Suppressor | `THRESHOLD`, `DECAY`, `DAMP` |
| Compressor | `THRESHOLD`, `RATIO`, `RESPONSE`, `MAKEUP` |
| Overdrive | `TONE`, `LEVEL`, `DRIVE` |
| Distortion Pedalboard | `TONE`, `LEVEL`, `DRIVE`, `BIAS`, `TIGHT`, `MIX` + 7-bit pedal mask (`clean_boost` / `tube_screamer` / `rat` / `ds1` / `big_muff` / `fuzz_face` / `metal`、全 7 ペダル実装済) |
| RAT Distortion | `FILTER`, `LEVEL`, `DRIVE`, `MIX` |
| Amp Simulator | `GAIN`, `BASS`, `MIDDLE`, `TREBLE`, `PRESENCE`, `RESONANCE`, `MASTER`, `CHARACTER` |
| Cab IR | `MIX`, `LEVEL`, `MODEL`, `AIR` |
| EQ | `LOW`, `MID`, `HIGH` |
| Reverb | `Decay`, `tone`, `mix` |

すべて OFF の場合は、通常の `line_in -> passthrough -> headphone` に戻ります。いずれかのエフェクトを ON にすると、`line_in -> guitar_chain -> headphone` に切り替わります。

### Noise Suppressor (BOSS NS-2 / NS-1X 風)

旧 Noise Gate 段は **専用 AXI GPIO** (`axi_gpio_noise_suppressor` @ `0x43CC0000`) で制御する Noise Suppressor に置き換わっています。FPGA 側ではエンベロープ追従 + 平滑化されたゲインステージで構成されており、`gate_control` bit 0 (legacy `noise_gate_on`) が引き続き ON/OFF を制御します。

| 知能 | 範囲 | 内容 |
| --- | --- | --- |
| `THRESHOLD` | 0..100 | 検出エンベロープと比較する基準レベル。byte = `round(threshold * 255 / 1000)` (新スケール 100 ≡ 旧 10) |
| `DECAY` | 0..100 | 閉じる速さ。0 = タイト (~1.4 ms full close)、100 = サステイン保持 (~85 ms full close) |
| `DAMP` | 0..100 | 最大ノイズ抑制量。0 ≒ 50% closed gain (自然)、100 ≒ 0% (完全ミュート) |

`GuitarPedalboardOneCell.ipynb` には NS-2 Style / NS-1X Natural / High Gain Tight / Sustain Friendly の 4 プリセットを用意しています。RNNoise / FFT / spectral 系処理は採用していません (PYNQ-Z2 PL リソース都合)。BOSS NS-2 / NS-1X は操作思想のみ参考にしており、回路やコードのコピーは行っていません。詳細は [`docs/ai_context/DECISIONS.md`](docs/ai_context/DECISIONS.md) D11、[`docs/ai_context/DSP_EFFECT_CHAIN.md`](docs/ai_context/DSP_EFFECT_CHAIN.md) Noise Suppressor 節を参照してください。

### Compressor (stereo-linked feed-forward peak)

Compressor 段は **専用 AXI GPIO** (`axi_gpio_compressor` @ `0x43CD0000`) で制御するステレオリンクの feed-forward peak compressor です。Noise Suppressor の後段、Overdrive の前段に配置され、ピッキングの粒を揃えてサステインを伸ばします。enable は専用 GPIO の `ctrlD` bit 7。

| 知能 | 範囲 | 内容 |
| --- | --- | --- |
| `THRESHOLD` | 0..100 | 圧縮を開始するエンベロープ・レベル (低いほど弱い入力から圧縮) |
| `RATIO` | 0..100 | 圧縮の強さ。0 ≒ ほぼ 1:1、100 ≒ 強いリミッター寄り |
| `RESPONSE` | 0..100 | attack/release をまとめた応答速度。0 = タイト、100 = 自然/サステイン重視 |
| `MAKEUP` | 0..100 | 圧縮後の補正ゲイン。50 ≒ unity、控えめに 0.75x..1.25x の Q8 マッピング (`MAKEUP` byte = u7 0..127、ctrlD bits[6:0]) |

`GuitarPedalboardOneCell.ipynb` には Comp Off / Light Sustain / Funk Tight / Lead Sustain / Limiter-ish の 5 プリセットを用意しています。本格的な attack/release 独立、knee、sidechain は今回入れていません。参考にした OSS (`harveyf2801/AudioFX-Compressor`、`bdejong/musicdsp`、`DanielRudrich/SimpleCompressor`、`chipaudette/OpenAudio_ArduinoLibrary`、`p-hlp/SMPLComp`、`Ashymad/bancom`) はパラメータ命名と設計思想のみ参照しており、ソースコードのコピーは行っていません。詳細は [`docs/ai_context/DECISIONS.md`](docs/ai_context/DECISIONS.md) D14、[`docs/ai_context/DSP_EFFECT_CHAIN.md`](docs/ai_context/DSP_EFFECT_CHAIN.md) Compressor 節を参照してください。

### Distortion Pedalboard (pedal-mask 方式、全 7 ペダル deployed)

`distortion_control.ctrlD[6:0]` の 7 bit pedal-enable mask で、ペダルを排他切替/スタックできます。section master は `gate_control.ctrlA` bit 2 (`distortion_on`)。各ペダルは独立 register-staged Clash ブロックで実装され、OFF 時 bit-exact bypass。bit 7 は将来 8 番目のペダル用に reserved。

| ペダル | bit | Clash ステージ概要 | 想定 voicing |
| --- | --- | --- | --- |
| `clean_boost` | 0 | 3 段: mul -> shift -> level + safety softClip | 透明系のクリーンブースト |
| `tube_screamer` | 1 | 5 段: HPF -> mul -> asym soft clip -> post LPF -> level | TS808 / TS9 風中域寄りオーバードライブ |
| `rat` | 2 | 既存 RAT ステージへ写像 (Python 側で `gate_control.ctrlA` bit 4 を立てる) | ProCo RAT 風ハードクリップ |
| `ds1` | 3 | 5 段: HPF -> mul -> asym soft clip (低 knee) -> post LPF -> level + safety | BOSS DS-1 風、明るくジャリっとしたエッジ |
| `big_muff` | 4 | 5 段: pre-gain -> 2 段カスケード soft clip -> tone LPF -> level + safety | Big Muff Pi 風、厚いサステイン感 |
| `fuzz_face` | 5 | 4 段: pre-gain -> 強い asym soft clip -> tone LPF -> level + safety | Fuzz Face 風、荒く非対称な breakup |
| `metal` | 6 | 5 段: tight HPF -> mul -> hard clip -> post LPF -> level | MT-2 風モダンハイゲイン |
| reserved | 7 | --- | 将来の 8 番目のペダル用 |

共有パラメータ:

| 知能 | 範囲 | 内容 |
| --- | --- | --- |
| `DRIVE` | 0..100 | 前段ゲイン量 |
| `TONE` | 0..100 | 出力 LPF (alpha マッピング) |
| `LEVEL` | 0..100 | 出力レベル (Q7) |
| `BIAS` | 0..100 | bias 用バイト (現状 ds1/big_muff/fuzz_face では未消費、将来予約) |
| `TIGHT` | 0..100 | 入力 HPF alpha (TS / metal / ds1 が消費) |
| `MIX` | 0..100 | wet/dry mix (現状予約) |

`set_distortion_pedal(name, exclusive=True)` / `set_distortion_pedals(**kwargs)` / `set_distortion_settings(...)` から操作します。商用ペダルの回路図 / コード / 係数表のコピーは行っていません。アルゴリズム形 (HPF -> drive -> clip -> post LPF -> level、softClip 系 helper の選択、安全 knee) のみが参照点です (`DECISIONS.md` D6 / D9)。

### 実機ペダル風 voicing pass (deployed)

各エフェクトを既存 GPIO のまま「実機っぽい音」に寄せる調整パスを実施しています。新規 GPIO / `topEntity` ポート / Clash ステージは追加せず、`LowPassFir.hs` の中の既存ステージの定数とクリップ関数だけを差し替えています。狙いと変更点の一覧は [`docs/ai_context/REAL_PEDAL_VOICING_TARGETS.md`](docs/ai_context/REAL_PEDAL_VOICING_TARGETS.md) を参照してください。代表的な変更:

- Overdrive: 対称 `softClip` → `asymSoftClip` (tube 風 even-harmonic 寄り)
- clean_boost: drive ceiling を ~5x → ~4x、安全 clip knee を 4.2M → 3.2M
- tube_screamer: 入力 HPF を強化、drive max を ~9x → ~7x、asym knee を低めに、post LPF を全体に暗く
- rat: hard clip floor を低くして高 DRIVE で荒く、post LPF / tone を全体に暗く
- metal: TIGHT による低域 cut を強化、drive max を ~22x → ~19x、post LPF を全体に暗く
- Compressor: 軽い soft-knee オフセットと reduction slope 調整で、アタックを潰しすぎずに粒を揃える
- Noise Suppressor: 閾値付近のヒステリシス (`closeT = threshold - threshold/4`) でチャタリング抑制
- Cab IR: 4-tap IR の係数 c0 を下げ c1/c2 を上げて高域を抑制 (line direct fizz が減る)
- Reverb: tone byte をスケール (`tone - tone/8`) して TONE=100 でも高域 damping を残す
- EQ: 出力 mix に `softClip` を追加 (3-band 全 boost で audible distortion を起こさないように)

商用ペダル / アンプ / GPL DSP のソースコード移植は行っていません (`DECISIONS.md` D7 / D11 / D14)。

### Amp/Cab real voicing pass (deployed)

歪みペダル後段の Amp Simulator / Cab IR を、generic guitar amp / cabinet inspired の軽量 DSP として実機寄りに再調整しました。新規 GPIO / `topEntity` ポート / `block_design.tcl` 変更はありません。商用アンプ回路、キャビネット IR、GPL DSP コードのコピーもありません。

- Amp: 入力 HPF を少し強め、input gain 上限を下げてペダル後段で再度 square 化しにくくしています。preamp / power / master の safety clip knee を下げ、presence / resonance は knob 最大でも暴れすぎないよう内部で上限を抑えています。
- Cab model 0: 1x12 open back style。軽め、低域控えめ、中域と AIR が残る clean / crunch 向け。
- Cab model 1: 2x12 combo style。バランス型。Tube Screamer Lead / RAT Rhythm 向けに高域を削りつつ抜けを残します。
- Cab model 2: 4x12 closed back style。遅延 tap 側を厚くし、Metal / Big Muff / Fuzz Face の line-direct fizz を最も強く抑えます。
- `air` は高域の戻し量として扱いますが、direct tap の戻りは capped なので `air=100` でも raw line には戻りません。
- Chain Presets は Basic Clean / Clean Sustain / Light Crunch に model 0 を薄く使い、Metal / Big Muff / Fuzz 系は model 2 寄りに調整しています。

### Amp Simulator named models (deployed)

Amp Simulator の `amp_character` を 4 つの named voicing にラベル付けしました。新規 GPIO / `topEntity` ポート / `block_design.tcl` 変更はありません。商用アンプ回路 / IR / 係数のコピーもありません — いずれも style/inspired のみです (`DECISIONS.md` D7 / D18)。

| Model | `amp_character` | character band | 想定 voicing |
| --- | --- | --- | --- |
| `jc_clean` | 10 | 0..24 | Roland JC 系のクリーン inspired。明るく硬質、低歪み、空間系と相性が良い。 |
| `clean_combo` | 35 | 25..49 | Fender 系クリーンコンボ inspired。低〜中ゲイン、JC より少し丸い。 |
| `british_crunch` | 60 | 50..74 | Marshall / Vox 系クランチ inspired。中域寄りで TS / RAT / DS-1 と相性が良い。 |
| `high_gain_stack` | 85 | 75..100 | 4x12 stack / modern high-gain inspired。Metal / Big Muff / Fuzz 後段向け、5 kHz 以上の fizz を最も強く抑える。 |

DSP 側では `LowPassFir.hs` の `ampPreLowpassFrame` が `ampModelSel` ヘルパで character byte を 4 band に量子化し、post-clip pre-LPF の alpha を band ごとに `0 / 2 / 8 / 16` 段階で darken します。それ以外の amp ステージ (asym clip knee、second-stage gain、presence / resonance cap、power / master safety) は既存の連続 character カーブに従い、audio-analysis pass の高域抑制をそのまま維持しています。

Python 側は convenience API を追加 (`amp_character` の数値指定はそのまま動作):

```python
from audio_lab_pynq.AudioLabOverlay import AudioLabOverlay
ovl = AudioLabOverlay()

ovl.set_amp_model("british_crunch")          # amp_character=60 を書く
ovl.set_amp_model("high_gain_stack",
                  amp_master=70, amp_input_gain=40)  # 他の amp_* と組み合わせ可
print(AudioLabOverlay.get_amp_model_names())
print(AudioLabOverlay.amp_model_to_character("jc_clean"))  # -> 10
```

`GuitarPedalboardOneCell.ipynb` の Amp Simulator アコーディオンに「Amp Model」ドロップダウンを追加しました。選択するとその model の中央 character 値を Character スライダーに書き込むので、Chain Preset / Safe Bypass のロジックは何も変えていません。

### Recording-analysis voicing fixes (deployed)

録音解析で見えた AmpSim / Cabinet / Overdrive / Compressor の差分に
基づき、既存 `LowPassFir.hs` stage だけを再調整しました。新規 GPIO /
`topEntity` port / `block_design.tcl` 変更はありません。解析メモは
[`docs/ai_context/AUDIO_RECORDING_ANALYSIS.md`](docs/ai_context/AUDIO_RECORDING_ANALYSIS.md)
にあります。

- AmpSim: input gain ceiling をさらに下げ、pre-LPF / treble /
  presence / master safety を高域が痛くなりにくい方向へ調整。
- Cabinet: 4-tap `cabCoeff` を再調整し、model 0/1/2 の差を明確化。
  model 2 は DS-1 / Metal / Big Muff / Fuzz 後段向けに 5 kHz 以上の
  fizz を最も強く抑えます。
- Overdrive: drive mapping と asymmetric clip knee を見直し、Drive
  30..50 でもBypassとの差が出る軽いクランチへ寄せました。
- Compressor: effective threshold / soft knee / reduction slope /
  response を、既存プリセットで軽く効きが見える方向へ調整。makeup
  45..60 の安全契約は維持しています。
- Preset: DS-1 Crunch は Cab model 2 / capped air に寄せています。
- Build/deploy: bit/hwh を再生成して PYNQ-Z2 へ deploy 済みです。
  timing は `WNS = -8.731 ns` / `TNS = -13665.555 ns` /
  `WHS = +0.051 ns` / `THS = 0.000 ns`。ADC HPF default-on
  (`R19_ADC_CONTROL = 0x23`) も smoke test で確認済みです。

### 予約ペダルの実装 (deployed)

`distortion_control.ctrlD` で予約していた `ds1` (bit 3) / `big_muff` (bit 4) / `fuzz_face` (bit 5) を、既存ペダルと同じ pedal-mask 方式の独立ステージとして実装しました。詳細は上記の Distortion Pedalboard セクションを参照してください。新規 GPIO / `topEntity` ポート / `block_design.tcl` 変更はありません。`GuitarPedalboardOneCell.ipynb` の Distortion Pedalboard dropdown と Chain Preset (DS-1 Crunch / Big Muff Sustain / Vintage Fuzz が新規追加) から切り替えられます。8-way `model_select` mux 設計には戻していません (`DECISIONS.md` D6 / D9)。

## DSP 実装の正規パス

このリポジトリのリアルタイム DSP 実装は **Clash/Haskell 記述
`hw/ip/clash/src/LowPassFir.hs`** が唯一の正です。Clash から VHDL を
生成し、Vivado で bit / hwh をビルドして PL 側で動かしています。
Python 側 (`AudioLabOverlay.py`) は AXI GPIO への制御 word を書き出す
役割で、音そのものは PL で処理しています。

過去にあった C++ DSP プロトタイプ (`src/effects/*.cpp`) は **削除済み**
です。現在のリアルタイム音声経路は使っておらず、新しいエフェクトを
追加する際の出発点としても用いません。新エフェクトの追加方針は
[`docs/ai_context/EFFECT_ADDING_GUIDE.md`](docs/ai_context/EFFECT_ADDING_GUIDE.md)
を参照してください。

ローカルの単体テストは次で実行できます (Python 制御層の挙動を検証
します)。

```sh
make tests
```

## ノートブック

| Notebook | 内容 |
| --- | --- |
| `GuitarPedalboardOneCell.ipynb` | 1セル UI のメインノートブック。Chain Preset dropdown (Safe Bypass / Basic Clean / Clean Sustain / Light Crunch / Tube Screamer Lead / RAT Rhythm / Metal Tight / Ambient Clean / Solo Boost / Noise Controlled High Gain / DS-1 Crunch / Big Muff Sustain / Vintage Fuzz) で実用音色をワンクリック適用、Distortion Pedalboard dropdown は全 7 ペダル選択可、加えて Compressor / Noise Suppressor / Overdrive / Amp / Cab IR / EQ / Reverb の個別操作 (Apply / Safe Bypass / Refresh / Show Current State) |
| `GuitarEffectSwitcher.ipynb` | Noise Gate / Overdrive / Distortion / RAT / Amp / Cab IR / EQ / Reverb をON/OFFとプリセットで素早く切り替えるノートブック (Distortion Pedalboard セクションに DS-1 / Big Muff Sustain / Fuzz Face プリセット cell 追加) |
| `DistortionModelsDebug.ipynb` | Distortion pedal-mask API のウォークスルー (pedal一覧 + bit position + 全 7 ペダル実装済の表示と排他切替) |
| `GuitarEffectsChain.ipynb` | Noise Gate / Overdrive / Distortion / RAT / Amp / Cab IR / EQ / Reverb を操作するメインノートブック |
| `InputDebug.ipynb` | Line-in のキャプチャ・統計・ADC HPF 切替によるノイズ三角測 |
| `LineInPassthroughOneCell.ipynb` | 1セルで Line-in をそのまま出力する確認用 |
| `LineInReverbOneCell.ipynb` | 1セルで軽いリバーブを有効化する確認用 |
| `PassthroughDebug.ipynb` | 入力、出力、コーデック、AXI Stream Switch の診断用 |
| `AudioLab.ipynb` | 元の Audio Lab 操作用ノートブック |

PYNQ 上では通常、次のURLから開きます。

```text
http://<PYNQのIPアドレス>:9090/notebooks/audio_lab/GuitarPedalboardOneCell.ipynb
```

この環境では以下に配置済みです。

```text
http://192.168.1.8:9090/notebooks/audio_lab/GuitarPedalboardOneCell.ipynb
```

## Python API

基本的な使い方です。`noise_gate_threshold` は新スケール 0..100 (100 ≡ 旧 10)。

```python
import audio_lab_pynq as aud

ol = aud.AudioLabOverlay()

# Noise Suppressor の細かい操作は専用APIを使います。
ol.set_noise_suppressor_settings(
    enabled=True,
    threshold=35,   # 0..100 (byte = round(threshold * 255 / 1000))
    decay=45,       # 0..100 (close ramp の遅さ)
    damp=80,        # 0..100 (最大ノイズ抑制量)
)

# 互換 API。set_guitar_effects(noise_gate_threshold=...) は新スケールで動作し、
# 専用 GPIO とレガシー gate_control.ctrlB の両方に同じ byte を書きます。
ol.set_guitar_effects(
    noise_gate_on=True,
    noise_gate_threshold=80,
    overdrive_on=True,
    overdrive_tone=65,
    overdrive_level=100,
    overdrive_drive=30,
    distortion_on=True,
    distortion_pedal_mask=(1 << 1),  # tube_screamer (use set_distortion_pedal()/set_distortion_pedals() in real code)
    distortion_tone=65,
    distortion_level=100,
    distortion=20,
    rat_on=True,
    rat_filter=35,
    rat_level=95,
    rat_drive=65,
    rat_mix=100,
    amp_on=True,
    amp_input_gain=35,
    amp_bass=50,
    amp_middle=50,
    amp_treble=50,
    amp_presence=45,
    amp_resonance=35,
    amp_master=80,
    amp_character=35,
    cab_on=True,
    cab_mix=100,
    cab_level=100,
    eq_on=True,
    eq_low=100,
    eq_mid=100,
    eq_high=100,
    reverb_on=True,
    reverb_decay=30,
    reverb_tone=65,
    reverb_mix=20,
)

# Distortion pedal-mask の操作は専用 API が読みやすい。
ol.set_distortion_pedal('tube_screamer', exclusive=True)
ol.set_distortion_settings(drive=45, tone=55, level=35, tight=60)
```

全エフェクトを OFF にしてパススルーへ戻す例です。

```python
ol.set_noise_suppressor_settings(enabled=False)
ol.clear_distortion_pedals()
ol.set_guitar_effects(
    noise_gate_on=False,
    overdrive_on=False,
    distortion_on=False,
    rat_on=False,
    amp_on=False,
    cab_on=False,
    eq_on=False,
    reverb_on=False,
)
```

単体リバーブの互換APIも残しています。

```python
ol.set_reverb(enabled=True, reverb=35, tone=70, mix=25)
```

## Chain Presets

`GuitarPedalboardOneCell.ipynb` の Chain Preset dropdown から、エフェクトチェーン全体を 1 クリックで実用音色に切り替えられます。Compressor の makeup は 45..60、Distortion の level は <=35 に抑えてあるので、プリセット切替で意図せず爆音になることはありません。

| Preset | 用途 |
| --- | --- |
| Safe Bypass | 全エフェクトOFF。完全パススルー。 |
| Basic Clean | Compressor 軽め + mild Amp + 1x12 Cab + 薄い Reverb。クリーンの基本形。 |
| Clean Sustain | Light Sustain Compressor + mild Amp + 1x12 Cab + 薄い Reverb。クリーンのサステイン強調。 |
| Light Crunch | 軽 Compressor + Overdrive 弱め + Amp + 1x12 Cab。クランチ。 |
| Tube Screamer Lead | Lead Sustain Compressor + Tube Screamer + Amp/Cab。リード。 |
| RAT Rhythm | 中 Compressor + RAT + Amp/Cab。リズム。 |
| Metal Tight | High-Gain Tight NS + Funk Tight Compressor + Metal + 4x12 Cab。ハイゲイン刻み。 |
| Ambient Clean | Light Sustain Compressor + 1x12 Cab + 深い Reverb + EQ で低域整理。 |
| Solo Boost | Lead Sustain Compressor + Tube Screamer + Amp/Cab。ソロ用。 |
| Noise Controlled High Gain | 強 NS + 軽 Compressor + Metal。ノイズ管理しつつ高歪み。 |
| DS-1 Crunch | 中 Compressor + 軽 NS + DS-1 + Amp/Cab。明るめのクランチ。 |
| Big Muff Sustain | 中 Compressor + 中 NS + Big Muff + 4x12 Cab。サステイン重視のファズ。 |
| Vintage Fuzz | 中 Compressor + 軽 NS + Fuzz Face + 4x12寄りCab。荒めのヴィンテージファズ。 |

Python からも同じ API で適用できます。

```python
ovl.apply_chain_preset("Tube Screamer Lead")
print(ovl.get_chain_preset_names())
print(ovl.get_current_pedalboard_state())
```

## ハードウェア構成

主な信号経路は以下です。

```text
ADAU1761 Line-in
  -> i2s_to_stream
  -> axis_switch_source
  -> passthrough / guitar_chain / DMA
  -> axis_switch_sink
  -> i2s_to_stream
  -> ADAU1761 output
```

PYNQ-Z2 の出力は、ヘッドホン表記の経路だけでは無音になる場合があったため、実際に音が出た LOUT/ROUT 側のコーデック設定を使っています。

エフェクト制御用 AXI GPIO は以下の通りです。

| IP | アドレス | 用途 |
| --- | --- | --- |
| `axi_gpio_reverb` | `0x43C30000` | Reverb |
| `axi_gpio_gate` | `0x43C40000` | ON/OFF フラグ (legacy `noise_gate_threshold` byte ミラー含む) |
| `axi_gpio_overdrive` | `0x43C50000` | Overdrive (+ distortion section の `tight`) |
| `axi_gpio_distortion` | `0x43C60000` | Distortion (tone/level/drive + pedal mask) |
| `axi_gpio_eq` | `0x43C70000` | EQ |
| `axi_gpio_delay` | `0x43C80000` | RAT Distortion。既存ポート名の互換性のため `delay` 名を維持 |
| `axi_gpio_amp` | `0x43C90000` | Amp Simulator の gain/master/presence/resonance |
| `axi_gpio_amp_tone` | `0x43CA0000` | Amp Simulator の bass/middle/treble/character |
| `axi_gpio_cab` | `0x43CB0000` | Cab IR の mix/level/model/air |
| `axi_gpio_noise_suppressor` | `0x43CC0000` | Noise Suppressor の THRESHOLD / DECAY / DAMP / mode |
| `axi_gpio_compressor` | `0x43CD0000` | Compressor の THRESHOLD / RATIO / RESPONSE / enable+MAKEUP |

## ビルド

Vivado が入った x86 Linux 環境で実行します。PYNQ-Z2 ボード上では Vivado が動かないため、通常はPC側でビルドします。

```sh
git clone https://github.com/cramsay/Audio-Lab-PYNQ
cd Audio-Lab-PYNQ
BOARD=Pynq-Z2 make
```

ビットストリームだけを作る場合は次を実行します。

```sh
make Pynq-Z2
```

生成物は以下に出力されます。

```text
hw/Pynq-Z2/bitstreams/audio_lab.bit
hw/Pynq-Z2/bitstreams/audio_lab.hwh
```

## PYNQ への配置

PYNQ 側の Python パッケージと Jupyter Notebook に、生成したファイルを配置します。

```sh
scp hw/Pynq-Z2/bitstreams/audio_lab.bit xilinx@<PYNQ_IP>:/home/xilinx/
scp hw/Pynq-Z2/bitstreams/audio_lab.hwh xilinx@<PYNQ_IP>:/home/xilinx/
scp audio_lab_pynq/AudioLabOverlay.py xilinx@<PYNQ_IP>:/home/xilinx/
scp audio_lab_pynq/AudioCodec.py xilinx@<PYNQ_IP>:/home/xilinx/
scp audio_lab_pynq/notebooks/GuitarEffectSwitcher.ipynb xilinx@<PYNQ_IP>:/home/xilinx/
scp audio_lab_pynq/notebooks/GuitarEffectsChain.ipynb xilinx@<PYNQ_IP>:/home/xilinx/
```

PYNQ 側で配置します。

```sh
sudo mkdir -p /usr/local/lib/python3.6/dist-packages/audio_lab_pynq/bitstreams
sudo cp /home/xilinx/audio_lab.bit /usr/local/lib/python3.6/dist-packages/audio_lab_pynq/bitstreams/audio_lab.bit
sudo cp /home/xilinx/audio_lab.hwh /usr/local/lib/python3.6/dist-packages/audio_lab_pynq/bitstreams/audio_lab.hwh
sudo cp /home/xilinx/AudioLabOverlay.py /usr/local/lib/python3.6/dist-packages/audio_lab_pynq/AudioLabOverlay.py
sudo cp /home/xilinx/AudioCodec.py /usr/local/lib/python3.6/dist-packages/audio_lab_pynq/AudioCodec.py

mkdir -p /home/xilinx/jupyter_notebooks/audio_lab/bitstreams
cp /home/xilinx/audio_lab.bit /home/xilinx/jupyter_notebooks/audio_lab/bitstreams/audio_lab.bit
cp /home/xilinx/audio_lab.hwh /home/xilinx/jupyter_notebooks/audio_lab/bitstreams/audio_lab.hwh
cp /home/xilinx/GuitarEffectSwitcher.ipynb /home/xilinx/jupyter_notebooks/audio_lab/GuitarEffectSwitcher.ipynb
cp /home/xilinx/GuitarEffectsChain.ipynb /home/xilinx/jupyter_notebooks/audio_lab/GuitarEffectsChain.ipynb
```

パッケージ経由でノートブックを再配置する場合は、PYNQ 側で次の関数も使えます。

```python
import audio_lab_pynq
audio_lab_pynq.install_notebooks()
```

## 動作確認

PYNQ 上では Overlay のロードに root 権限が必要な環境があります。その場合は `sudo python3` で確認します。

```sh
sudo python3
```

```python
import audio_lab_pynq as aud

ol = aud.AudioLabOverlay()
print(sorted(k for k in ol.ip_dict.keys() if "axi_gpio" in k))

words = ol.set_guitar_effects(
    noise_gate_on=True,
    overdrive_on=True,
    distortion_on=True,
    rat_on=True,
    amp_on=True,
    cab_on=True,
    eq_on=True,
    reverb_on=True,
)
print({k: hex(v) for k, v in words.items()})
print(hex(ol.axis_switch_source.read(0x40)), hex(ol.axis_switch_source.read(0x44)))
print(hex(ol.axis_switch_sink.read(0x40)), hex(ol.axis_switch_sink.read(0x44)))
```

エフェクトON時の期待値です。

```text
axis_switch_source M00 = 0x80000000
axis_switch_source M01 = 0x0
axis_switch_sink   M00 = 0x1
axis_switch_sink   M01 = 0x80000000
```

全OFF時はパススルーに戻ります。

```text
axis_switch_source M00 = 0x0
axis_switch_source M01 = 0x80000000
axis_switch_sink   M00 = 0x0
axis_switch_sink   M01 = 0x80000000
```

## 既知の注意点

- Vivado 実装時に setup timing violation が残ります。最新の deploy 済 bitstream (audio-analysis voicing fixes 版) は `WNS = -8.731 ns` / `TNS = -13665.555 ns` / `WHS = +0.051 ns` / `THS = 0.000 ns` です (実機 deploy band は -6 ~ -9 ns 程度。この範囲内であれば実機では問題なく動作する確認済み)。ホールド (`WHS / THS`) は引き続き clean を維持しています。詳細は [`docs/ai_context/TIMING_AND_FPGA_NOTES.md`](docs/ai_context/TIMING_AND_FPGA_NOTES.md) を参照してください。
- Reverb のバッファは、PYNQ-Z2 のリソースとタイミングを考慮して軽量化しています。長大な空間系ではなく、軽いリバーブ用途を想定しています。
- PL側の Amp/Cab は、C++版をそのまま合成したものではなく、固定小数点向けに簡略化した近似実装です。Cab IR は現時点では短い固定タッププリセット近似で、Notebookから `MODEL` と `AIR` を選べます。WAV IRローダーや長いIR畳み込みは未実装です。
- 出力ジャックは環境によってコーデックの経路設定が効き方に差があります。このリポジトリでは、実機で音が出た LOUT/ROUT 経路を標準にしています。
- 音量を上げすぎると大音量になります。Notebook の初期値から少しずつ調整してください。

## 参考にした実装

エフェクト設計の参考として、以下のプロジェクトを参照しました。アルゴリズム構造のみ参考にしており、ソースコードのコピーは行っていません (本リポジトリは WTFPL、上流の中には GPL があるため)。

- https://github.com/marcoalkema/cpp-guitar_effects
- https://github.com/maximoskp/cppAudioFX
- https://github.com/rerdavies/ToobAmp
- https://github.com/sudip-mondal-2002/Amplitron

Noise Suppressor の操作思想は BOSS NS-2 / NS-1X を参考にしています。回路やコードはコピーしていません。RNNoise / `noise-suppression-for-voice` / `libspecbleach` などの spectral 系手法は PYNQ-Z2 の PL リソースに対して重すぎるため採用していません。

Distortion Pedalboard の voicing 名は商用ペダルから借りていますが (DS-1 = BOSS DS-1、Big Muff = Electro-Harmonix Big Muff Pi、Fuzz Face = Dallas Arbiter / Dunlop Fuzz Face、Tube Screamer = Ibanez TS808 / TS9、RAT = ProCo RAT、Metal = BOSS MT-2 風)、いずれも操作感とアルゴリズム形 (HPF -> drive -> clip -> post LPF -> level、softClip 系 helper の選択、安全 knee) のみが参照点です。回路図 / コード / 係数表のコピーは行っていません (`DECISIONS.md` D7 / D9)。

## ライセンス

元リポジトリのライセンスは WTFPL です。詳細は `LICENSE` を確認してください。

## 新エフェクトの追加方針

GPIO 設計は固定されています ([`docs/ai_context/DECISIONS.md`](docs/ai_context/DECISIONS.md)
D12)。新しいエフェクトを追加するときは、まず
[`docs/ai_context/EFFECT_ADDING_GUIDE.md`](docs/ai_context/EFFECT_ADDING_GUIDE.md)
の判断フローを読み、既存 GPIO の `reserved` ビット / バイトを使えないか
確認してください。新規 `axi_gpio_*` IP の追加は最後の手段で、
`block_design.tcl` 変更とユーザの明示承認が必要です。仕様メモ用の
テンプレートは
[`docs/ai_context/EFFECT_STAGE_TEMPLATE.md`](docs/ai_context/EFFECT_STAGE_TEMPLATE.md)
にあります。

## AI development context

Claude Code / Codex 向けの作業コンテキストは
[`docs/ai_context/README.md`](docs/ai_context/README.md) にまとめています。
