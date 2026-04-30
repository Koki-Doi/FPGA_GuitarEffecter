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
Noise Gate -> Overdrive -> Distortion -> EQ -> Reverb
```

各エフェクトは個別に ON/OFF できます。

| エフェクト | パラメータ |
| --- | --- |
| Noise Gate | `THRESHOLD` |
| Overdrive | `TONE`, `LEVEL`, `DRIVE` |
| Distortion | `TONE`, `LEVEL`, `DISTORTION` |
| EQ | `LOW`, `MID`, `HIGH` |
| Reverb | `Decay`, `tone`, `mix` |

すべて OFF の場合は、通常の `line_in -> passthrough -> headphone` に戻ります。いずれかのエフェクトを ON にすると、`line_in -> guitar_chain -> headphone` に切り替わります。
Noise Gate はエンベロープ検出とフェード開閉を使い、しきい値付近で波形を直接切らないようにしています。

## ノートブック

| Notebook | 内容 |
| --- | --- |
| `GuitarEffectSwitcher.ipynb` | Noise Gate / Overdrive / Distortion / EQ / Reverb をON/OFFとプリセットで素早く切り替えるノートブック |
| `GuitarEffectsChain.ipynb` | Noise Gate / Overdrive / Distortion / EQ / Reverb を操作するメインノートブック |
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
| `axi_gpio_delay` | `0x43C80000` | 互換用。現在のチェーンでは未使用 |

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

- Vivado 実装時に timing violation が残ります。現在の主な違反は既存の `i2s_to_stream` / `bclk` 周辺のクロック制約に集中しており、今回追加したエフェクト制御GPIOやルート制御は PYNQ 上でロードとレジスタ書き込みを確認済みです。
- Reverb のバッファは、PYNQ-Z2 のリソースとタイミングを考慮して軽量化しています。長大な空間系ではなく、軽いリバーブ用途を想定しています。
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
