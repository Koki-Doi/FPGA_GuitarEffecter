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
- DMA を使った入力/出力経路のデバッグ用ノートブック

## エフェクトチェーン

`GuitarEffectsChain.ipynb` では、以下の順番でエフェクトを処理します。

```text
Noise Gate -> Overdrive -> Distortion -> RAT Distortion -> Amp Simulator -> Cab IR -> EQ -> Reverb
```

各エフェクトは個別に ON/OFF できます。

| エフェクト | パラメータ |
| --- | --- |
| Noise Gate | `THRESHOLD` |
| Overdrive | `TONE`, `LEVEL`, `DRIVE` |
| Distortion | `TONE`, `LEVEL`, `DISTORTION` |
| RAT Distortion | `FILTER`, `LEVEL`, `DRIVE`, `MIX` |
| Amp Simulator | `GAIN`, `BASS`, `MIDDLE`, `TREBLE`, `PRESENCE`, `RESONANCE`, `MASTER`, `CHARACTER` |
| Cab IR | `MIX`, `LEVEL` |
| EQ | `LOW`, `MID`, `HIGH` |
| Reverb | `Decay`, `tone`, `mix` |

すべて OFF の場合は、通常の `line_in -> passthrough -> headphone` に戻ります。いずれかのエフェクトを ON にすると、`line_in -> guitar_chain -> headphone` に切り替わります。
Noise Gate はエンベロープ検出とフェード開閉を使い、しきい値付近で波形を直接切らないようにしています。

## C++ DSP プロトタイプ

`src/effects` には、後からリアルタイム処理へ組み込むための C++ DSP プロトタイプを独立クラスとして追加しています。

| クラス | 内容 |
| --- | --- |
| `RatStyleDistortion` | RAT-style Distortion の浮動小数点プロトタイプ |
| `SimpleAmpSimulator` | Pre Gain、非対称 waveshaper、簡易 tone stack、Presence、Resonance、Master を持つ軽量アンプシミュレーター |
| `CabIRSimulator` | 最大512 samplesの短いIRをリングバッファで直接畳み込みするキャビネットIRシミュレーター |

Notebook/FPGA 側では、これらの考え方をもとにした軽量固定小数点版を Clash で実装しています。RAT は既存互換名の `axi_gpio_delay` から制御し、Amp/Cab は `axi_gpio_amp`、`axi_gpio_amp_tone`、`axi_gpio_cab` から制御します。

信号処理は `Input HPF -> Pre Gain -> OpAmp bandwidth LPF -> hard clipping -> post LPF -> RAT-style FILTER LPF -> Level -> safety limiter` の軽量構成です。RAT の完全な回路シミュレーションではなく、PYNQ/Zynq-7000 で扱いやすいリアルタイム DSP 実装を優先しています。

| パラメータ | 範囲 | 内容 |
| --- | --- | --- |
| `drive` | `0.0` - `1.0` | 内部ゲインとクリップしきい値を変え、低めは荒めのオーバードライブ、高めはファズ寄りにします |
| `filter` | `0.0` - `1.0` | 値を上げるほど LPF cutoff を下げ、RAT の FILTER 風に暗くします |
| `level` | `0.0` - `1.5` | 出力レベル |
| `mix` | `0.0` - `1.0` | Dry/Wet |
| `enabled` | `true` / `false` | バイパス制御。初期値は `false` |

`SimpleAmpSimulator` は `Input HPF -> Preamp Gain -> Asymmetric Waveshaper -> Preamp LPF -> 3-band EQ -> Power Amp Saturation -> Resonance -> Presence -> Master -> safety limiter` の構成です。

`CabIRSimulator` は `Input -> IR Convolution -> Level -> Mix -> safety limiter` の構成です。IR は `setIR(const float* data, int length)` で設定し、先頭のほぼ無音部分をトリムします。IR未設定時、またはOFF時は安全にdryを返します。

### C++ エフェクトをそのまま移植できるか

C++で書いたエフェクトを、現在のFPGA音声チェーンへそのままコピーして動かすことはできません。このリポジトリのリアルタイム音声処理は `hw/ip/clash/src/LowPassFir.hs` の Clash/Haskell 記述からVHDLを生成し、PL側でサンプル単位に処理しています。一方、`src/effects/*.cpp` はCPU側で動く浮動小数点の参照実装です。

そのため移植は「C++コードを直接ビルドする」形ではなく、次のような作業になります。

1. C++版のDSP構成、パラメータ範囲、安全処理を確認する
2. PLで扱える固定小数点、ビット幅、パイプライン段数に置き換える
3. `AudioLabOverlay.py` と block design にAXI GPIO制御を追加する
4. ClashでVHDLを再生成し、Vivadoでbit/hwhを作り直す
5. notebookから制御できるようにUIとAPIを更新する

今回の Amp/Cab もこの方針で、C++版は読みやすいDSP参照実装、FPGA版はPYNQ-Z2で扱いやすい軽量固定小数点近似として実装しています。C++をそのままARM側で実行する構成も理論上は可能ですが、現在のline-inリアルタイム経路はPL側にあるため、既存構造を保つならClashへの再実装が必要です。

ローカルの単体テストは次で実行できます。

```sh
make tests
```

## ノートブック

| Notebook | 内容 |
| --- | --- |
| `GuitarEffectSwitcher.ipynb` | Noise Gate / Overdrive / Distortion / RAT / Amp / Cab IR / EQ / Reverb をON/OFFとプリセットで素早く切り替えるノートブック |
| `GuitarEffectsChain.ipynb` | Noise Gate / Overdrive / Distortion / RAT / Amp / Cab IR / EQ / Reverb を操作するメインノートブック |
| `LineInPassthroughOneCell.ipynb` | 1セルで Line-in をそのまま出力する確認用 |
| `LineInReverbOneCell.ipynb` | 1セルで軽いリバーブを有効化する確認用 |
| `PassthroughDebug.ipynb` | 入力、出力、コーデック、AXI Stream Switch の診断用 |
| `AudioLab.ipynb` | 元の Audio Lab 操作用ノートブック |

PYNQ 上では通常、次のURLから開きます。

```text
http://<PYNQのIPアドレス>:9090/notebooks/audio_lab/GuitarEffectsChain.ipynb
```

この環境では以下に配置済みです。

```text
http://192.168.1.8:9090/notebooks/audio_lab/GuitarEffectsChain.ipynb
```

## Python API

基本的な使い方です。

```python
import audio_lab_pynq as aud

ol = aud.AudioLabOverlay()

ol.set_guitar_effects(
    noise_gate_on=True,
    noise_gate_threshold=8,
    overdrive_on=True,
    overdrive_tone=65,
    overdrive_level=100,
    overdrive_drive=30,
    distortion_on=True,
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
```

全エフェクトを OFF にしてパススルーへ戻す例です。

```python
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
| `axi_gpio_gate` | `0x43C40000` | ON/OFF フラグと Noise Gate |
| `axi_gpio_overdrive` | `0x43C50000` | Overdrive |
| `axi_gpio_distortion` | `0x43C60000` | Distortion |
| `axi_gpio_eq` | `0x43C70000` | EQ |
| `axi_gpio_delay` | `0x43C80000` | RAT Distortion。既存ポート名の互換性のため `delay` 名を維持 |
| `axi_gpio_amp` | `0x43C90000` | Amp Simulator の gain/master/presence/resonance |
| `axi_gpio_amp_tone` | `0x43CA0000` | Amp Simulator の bass/middle/treble/character |
| `axi_gpio_cab` | `0x43CB0000` | Cab IR の mix/level |

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

- Vivado 実装時に timing violation が残ります。現在のbitstreamは生成できていますが、直近の routed timing summary では `WNS=-12.231ns`、`TNS=-6173.318ns` です。Amp/Cab を含むエフェクト段を増やしたため、次の改善では Clash 側のパイプライン分割と演算段の整理が必要です。
- Reverb のバッファは、PYNQ-Z2 のリソースとタイミングを考慮して軽量化しています。長大な空間系ではなく、軽いリバーブ用途を想定しています。
- PL側の Amp/Cab は、C++版をそのまま合成したものではなく、固定小数点向けに簡略化した近似実装です。Cab IR も現時点では短い固定タップ近似で、WAV IRローダーや長いIR畳み込みは未実装です。
- 出力ジャックは環境によってコーデックの経路設定が効き方に差があります。このリポジトリでは、実機で音が出た LOUT/ROUT 経路を標準にしています。
- 音量を上げすぎると大音量になります。Notebook の初期値から少しずつ調整してください。

## 参考にした実装

エフェクト設計の参考として、以下のプロジェクトを参照しました。

- https://github.com/marcoalkema/cpp-guitar_effects
- https://github.com/maximoskp/cppAudioFX
- https://github.com/rerdavies/ToobAmp
- https://github.com/sudip-mondal-2002/Amplitron

## ライセンス

元リポジトリのライセンスは WTFPL です。詳細は `LICENSE` を確認してください。
