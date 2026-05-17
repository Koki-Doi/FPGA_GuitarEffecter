# Audio-Lab-PYNQ

PYNQ-Z2 と ADAU1761 オーディオコーデックを使って、Line-in の音声を FPGA 上で処理し、ヘッドホン/ライン出力へ返すためのオーディオDSP実験環境です。

現在の主な用途は、ギター/ライン音声向けのリアルタイムエフェクト処理です。Jupyter Notebook、HDMI 統合 GUI、3 個のロータリーエンコーダー、または `scripts/` 配下の CLI からエフェクトの ON/OFF と各パラメータを操作できます。

## 目次

- [現在の機能](#現在の機能)
- [クイックスタート](#クイックスタート)
- [システム要件 / Toolchain](#システム要件--toolchain)
- [リポジトリ構成](#リポジトリ構成)
- [HDMI GUI](#hdmi-gui)
- [Rotary Encoder GUI 操作 (Phase 7F / 7G / 7G+)](#rotary-encoder-gui-操作-phase-7f--7g--7g)
- [エフェクトチェーン](#エフェクトチェーン)
- [DSP 実装の正規パス](#dsp-実装の正規パス)
- [ノートブック](#ノートブック)
- [PYNQ-Z2 network](#pynq-z2-network)
- [Python API](#python-api)
- [Chain Presets](#chain-presets)
- [ハードウェア構成](#ハードウェア構成)
- [ビルド](#ビルド)
- [PYNQ への配置](#pynq-への配置)
- [動作確認](#動作確認)
- [テスト](#テスト)
- [既知の注意点](#既知の注意点)
- [ドキュメント (`docs/ai_context/`)](#ドキュメント-docsai_context)
- [参考にした実装](#参考にした実装)
- [ライセンス](#ライセンス)
- [新エフェクトの追加方針](#新エフェクトの追加方針)
- [Future Work](#future-work)
- [AI development context](#ai-development-context)

## クイックスタート

PYNQ-Z2 (`192.168.1.9`) が DHCP 固定割当済で SSH 鍵が通っている前提です。

```sh
# 1. ローカルでビルド (省略可、bit/hwh は同梱しています)
make Pynq-Z2

# 2. PYNQ へ deploy (bit/hwh + Python パッケージ + notebook を 5 ヶ所同期)
bash scripts/deploy_to_pynq.sh

# 3a. 1セル Notebook で実機エフェクト確認
#     http://192.168.1.9:9090/notebooks/audio_lab/GuitarPedalboardOneCell.ipynb

# 3b. HDMI GUI smoke (5 インチ 800x480 LCD)
#     http://192.168.1.9:9090/notebooks/audio_lab/HdmiGuiShow.ipynb

# 3c. ロータリーエンコーダー実操作 (notebook 不要)
ssh xilinx@192.168.1.9 '
  cd /home/xilinx/Audio-Lab-PYNQ &&
  sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
    python3 scripts/run_encoder_hdmi_gui.py --live-apply --skip-rat
'

# 4. ローカルユニットテスト (Python 制御層のみ、PYNQ 不要)
make tests
python3 -m unittest discover -s tests -v
```

`audio_lab.bit` の md5 同期確認は `scripts/deploy_to_pynq.sh` 後にも以下で
できます。

```sh
ssh xilinx@192.168.1.9 'md5sum \
  /home/xilinx/Audio-Lab-PYNQ/hw/Pynq-Z2/bitstreams/audio_lab.bit \
  /home/xilinx/Audio-Lab-PYNQ/audio_lab_pynq/bitstreams/audio_lab.bit \
  /usr/local/lib/python3.6/dist-packages/audio_lab_pynq/bitstreams/audio_lab.bit \
  /home/xilinx/jupyter_notebooks/audio_lab/bitstreams/audio_lab.bit \
  /usr/local/lib/python3.6/dist-packages/pynq/overlays/audio_lab/audio_lab.bit'
```

5 行とも同じ md5 が出れば OK (Phase 6I C2 build は
`81f4c149fac2e5b3fc6ed4421da60cdf`)。

## システム要件 / Toolchain

| 項目 | 値 |
| --- | --- |
| Board | PYNQ-Z2 (Xilinx Zynq-7000, `xc7z020clg400-1`) + ADAU1761 codec |
| Vivado | 2019.1 (bit / hwh 再生成と timing 解析) |
| Clash | 1.8.1 (`clash-prelude` のバージョンも揃える) |
| GHC | 8.10.7 |
| PYNQ image | 2020.1 系 (Python **3.6**、注: 3.7+ 限定機能は使わない) |
| HDMI 出力 | 5 インチ 800x480 LCD via HDMI、Phase 6I C2 で VESA SVGA `800x600 @ 60 Hz / 40 MHz` |
| Encoder hardware | 押し込みスイッチ付き rotary encoder 3 個 (`+` 3.3V 専用、5V 禁止) — Raspberry Pi header の `raspberry_pi_tri_i_6..14` 9 pin |
| 開発機 | x86 Linux + Vivado 2019.1 (bit / hwh ビルド)、もしくは bit 同梱で deploy のみ |

PYNQ 側 Python は **3.6** 固定です。`from __future__ import annotations`、
`dataclasses` の Python 3.7+ default、`typing.Literal` は encoder runtime path
で禁止 (`DECISIONS.md` D36)。

## リポジトリ構成

```text
Audio-Lab-PYNQ/
├── audio_lab_pynq/             # PYNQ side Python package
│   ├── AudioLabOverlay.py      # overlay loader, AXIS routing, GPIO writes
│   ├── AudioCodec.py           # ADAU1761 register driver, config
│   ├── AxisSwitch.py           # AXI Stream Switch helper
│   ├── control_maps.py         # GPIO ctrlA..D byte pack/unpack/clamp
│   ├── effect_defaults.py      # per-effect default kwargs
│   ├── effect_presets.py       # 13 chain presets (Safe Bypass etc.)
│   ├── diagnostics.py          # input/output diagnostics (Phase 1)
│   ├── encoder_input.py        # Phase 7F PL IP driver (EncoderInput, EncoderEvent)
│   ├── encoder_ui.py           # Phase 7G EncoderUiController (event -> AppState)
│   ├── encoder_effect_apply.py # Phase 7G+ EncoderEffectApplier (AppState -> overlay)
│   ├── hdmi_backend.py         # direct MMIO HDMI framebuffer (800x600)
│   ├── hdmi_effect_state_mirror.py # one-way mirror (notebook -> overlay -> HDMI)
│   ├── hdmi_state/             # per-effect split: pedals / amps / cabs / selected_fx /
│   │                           #                   knobs / resource_sampler / common
│   ├── notebooks/              # Jupyter notebooks installed onto the board
│   └── bitstreams/             # audio_lab.bit / audio_lab.hwh (deploy 経路 #2)
├── GUI/                        # GUI renderers + bridges
│   ├── compact_v2/             # split renderer: knobs / state / layout / renderer / hit_test
│   ├── pynq_multi_fx_gui.py    # thin re-export shim over GUI/compact_v2/
│   ├── audio_lab_gui_bridge.py # dry-run-first AppState -> overlay bridge (legacy)
│   └── fx_gui_state.json       # persisted compact-v2 AppState
├── hw/
│   ├── ip/
│   │   ├── clash/src/LowPassFir.hs   # the live DSP pipeline (source of truth)
│   │   ├── clash/src/AudioLab/       # split modules (effects / pipeline / helpers)
│   │   ├── clash/vhdl/LowPassFir/    # Clash-generated VHDL + packaged Vivado IP
│   │   ├── encoder_input/src/axi_encoder_input.v  # Phase 7F encoder PL IP
│   │   └── fx_gain/                  # legacy HLS gain IP (instantiated, not stream-connected)
│   └── Pynq-Z2/
│       ├── audio_lab.xdc                       # pin / clock constraints
│       ├── block_design.tcl                    # Vivado BD (off-limits, see CLAUDE.md)
│       ├── create_project.tcl                  # batch entry, sources every *_integration.tcl
│       ├── hdmi_integration.tcl                # HDMI VDMA + VTC + rgb2dvi (Phase 4/6I)
│       ├── encoder_integration.tcl             # axi_encoder_input @ 0x43D10000 (Phase 7F)
│       └── bitstreams/audio_lab.{bit,hwh}      # built artefacts (deploy 経路 #1)
├── scripts/
│   ├── deploy_to_pynq.sh                  # rsync + sudo install + 5-ヶ所 bit/hwh 同期
│   ├── audio_diagnostics.py               # capture/stats CLI
│   ├── run_encoder_hdmi_gui.py            # Phase 7G+ notebook-less encoder runtime
│   ├── test_encoder_input.py              # on-board encoder manual smoke
│   ├── test_hdmi_encoder_gui_control.py   # on-board encoder + GUI smoke
│   ├── test_hdmi_800x480_frame.py         # 1-frame HDMI smoke
│   └── ...                                # その他 HDMI / DSP diagnostics
├── tests/                                 # offline unit tests (Python 制御層)
│   ├── _pynq_mock.py                      # fake pynq for workstation tests
│   ├── test_overlay_controls.py           # legacy overlay API regression (79 asserts)
│   ├── test_encoder_input_decode.py       # 13 tests
│   ├── test_encoder_ui_controller.py      # 23 tests (Phase 7G + 7G+ 含む)
│   ├── test_encoder_effect_apply.py       # 11 tests (Phase 7G+)
│   ├── test_compact_v2_encoder_state.py   # 5 tests
│   ├── test_hdmi_*                        # 4 ファイル, 43 tests
│   └── Makefile                           # `make python` で test_overlay_controls.py のみ
├── docs/ai_context/                       # AI/作業者向け context (CURRENT_STATE / DECISIONS / 各 spec)
├── CLAUDE.md / AGENTS.md                  # 作業エージェント向け固定 README
└── README.md                              # この file
```

`hw/Pynq-Z2/block_design.tcl` はユーザの明示承認なしに編集禁止です
(`CLAUDE.md`、`DECISIONS.md` D2)。

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
- Amp Simulator の named model と高域 fizz-control pass
- ギター入力向けに、DSP内部は ADC Left 由来の mono source で処理し、
  AXI/I2S の外部 48-bit stereo I/O は維持
- 13 種類の Chain Preset (Safe Bypass を含む) で 1 クリックでチェーン全体を切替
- 統合 `audio_lab.bit` の HDMI framebuffer 出力。5インチ 800x480 LCD
  では Phase 6I (`DECISIONS.md` D25) の VESA SVGA `800x600 @ 60 Hz /
  40 MHz` 信号を使い、`800x600` framebuffer の左上 `800x480`
  (`x=0`, `y=0`) を compact-v2 GUI 領域、下 120 行は黒帯として運用
- Raspberry Pi header 上の 3 個の rotary encoder 入力 IP
  (`axi_encoder_input` / `enc_in_0`, AXI base `0x43D10000`) と Phase 7G+
  GUI-first live apply。詳細は
  [Rotary Encoder GUI 操作](#rotary-encoder-gui-操作-phase-7f--7g--7g)
  セクション
- DMA を使った入力/出力経路のデバッグ用ノートブック

## HDMI GUI

HDMI GUI は現在、AudioLab DSP と同じ `audio_lab.bit` に統合された
framebuffer 出力を使います。`AudioLabOverlay()` を 1 回だけロードし、
`Overlay("base.bit")` や `GUI/pynq_multi_fx_gui.py::run_pynq_hdmi()` は
使用しません。

Phase 5A の output mapping test で 5 インチ 800x480 LCD が
`1280x720` 全体の縮小表示ではなく左上 `800x480` を実用領域とすることを
確認し、Phase 6I (`DECISIONS.md` D25) では HDMI 信号自体を VESA SVGA
`800x600 @ 60 Hz / 40 MHz` に切り替えました。framebuffer は `800x600`
で、compact-v2 800x480 GUI は左上 `(0,0)` に配置し、下 120 行は黒のまま
にします。

最も簡単な動作確認は Jupyter から `HdmiGuiShow.ipynb` (Phase 6I で新設、
1 セル実行型) を開いてセルを 1 回走らせるだけです:

```text
http://192.168.1.9:9090/notebooks/audio_lab/HdmiGuiShow.ipynb
```

- `pynq.PL.bitfile_name` を見て `audio_lab.bit` が既にロード済みなら
  `AudioLabOverlay(download=False)` で attach し、rgb2dvi の MMCM
  PLL (Phase 6I の `40 MHz × M=20 = 800 MHz` で valid VCO 帯の下端) を
  揺さぶらない
- 未ロードなら通常の `AudioLabOverlay()` (default `download=True`) で
  fresh program
- どちらの場合も VTC `GEN_ACTSZ (0x60) = 0x02580320` (V=600 / H=800,
  SVGA) と VDMA error 無しを assert
- overlay 構築前に PL アドレスへ raw MMIO を出さない (FPGA blank 時
  に Jupyter kernel が落ちるため)

スクリプトで確認したい場合は次のコマンドです:

```sh
ssh xilinx@192.168.1.9 '
  cd /home/xilinx/Audio-Lab-PYNQ &&
  sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
    python3 scripts/test_hdmi_800x480_frame.py \
      --variant compact-v2 --placement manual \
      --offset-x 0 --offset-y 0 --hold-seconds 60
'
```

ライブアニメーションと CPU/RAM/FPS/VDMA error の常時モニタが欲しい場合は
`HdmiGui.ipynb` を使ってください (Phase 4 系から運用中、ipywidgets で
DIST / AMP / CAB の model dropdown 付き)。

現行 renderer と bridge は `GUI/` 配下にあります。旧 untracked
`HDMI/` 実験ツリーは現行 deploy / tests / runtime scripts から使われて
いないことを確認したため削除済みです。

## Rotary Encoder GUI 操作 (Phase 7F / 7G / 7G+)

押し込みスイッチ付き rotary encoder 3 個 (`CLK` / `DT` / `SW` / `+` /
`GND`) で HDMI GUI を notebook 無しに実操作するための一式が
**実装・deploy 済**です。

- **Phase 7F**: PL IP `axi_encoder_input` (`hw/ip/encoder_input/src/axi_encoder_input.v`)
  を `0x43D10000` に追加。2-stage sync + debounce + quadrature decode +
  signed delta + event latch。3 ch まとめて 1 IP。
- **Phase 7G**: Python driver (`audio_lab_pynq/encoder_input.py` +
  `encoder_ui.py`) と compact-v2 GUI focus state (`AppState` の
  `focus_effect_index` / `model_select_mode` / `value_dirty` /
  `apply_pending` / `last_encoder_event` 等)。
- **Phase 7G+**: `audio_lab_pynq/encoder_effect_apply.py::EncoderEffectApplier`
  を GUI-first の唯一の翻訳層として追加 (`DECISIONS.md` D37)。
  `AudioLabOverlay` の公開 setter
  (`set_noise_suppressor_settings` / `set_compressor_settings` /
  `set_guitar_effects(**kwargs)`) のみを 100 ms throttle で呼び、raw
  GPIO 直書きは行いません。

### 配線 (3.3V 専用、5V 禁止)

Raspberry Pi header から 9 pin (`raspberry_pi_tri_i_6..14`):

| Encoder | CLK | DT | SW |
| --- | --- | --- | --- |
| ENC0 | `F19` | `V10` | `V8` |
| ENC1 | `W10` | `B20` | `W8` |
| ENC2 | `V6` | `Y6` | `B19` |

`+` は **PYNQ-Z2 3.3V rail のみ** に繋いでください。5V は基板上 pull-up
経由で `CLK` / `DT` / `SW` を 5V 化し、PL pin (LVCMOS33) を破損する恐れが
あります (`DECISIONS.md` D31)。PMOD JA / JB は外付け PCM1808 / PCM5102
codec 予約のため encoder では使いません (`DECISIONS.md` D28 / D34)。

### 操作マッピング

| Encoder | Rotate | Push short | Push long |
| --- | --- | --- | --- |
| **Encoder 1** | `selected_effect` を変更 (GUI EFFECTS 8 項目を巡回) | 選択 effect の ON/OFF + live apply | Safe Bypass (全 ON/OFF、2 回目で復帰) + live apply |
| **Encoder 2** | `selected_knob` 変更 (`model_select_mode` 時は Distortion / Amp / Cab の model、Distortion では `skip_rat=True` の時 RAT を skip) | PEDAL / AMP / CAB は `model_select_mode` toggle、それ以外は `edit_mode` toggle | reserved (`model_select_mode` 解除) |
| **Encoder 3** | 選択 knob 値を ±`value_step` で増減 (live\_apply=True なら 100 ms throttle で applier 呼び出し) | force apply (throttle bypass、`apply_pending` / `value_dirty` をクリア) | 選択 knob を `EFFECT_KNOBS` default に戻し apply |

GUI EFFECTS は `Noise Sup / Compressor / Overdrive / Distortion / Amp Sim
/ Cab IR / EQ / Reverb` の 8 項目 (`GUI/compact_v2/knobs.py`)。RAT は
top-level EFFECTS ではなく **Distortion 内 pedal-mask bit 2** で、Phase 7G+
の encoder runtime からは既定で除外されています。

### `EncoderEffectApplier` の責務

`audio_lab_pynq/encoder_effect_apply.py` (Phase 7G+, `DECISIONS.md` D37)
が compact-v2 `AppState` と `AudioLabOverlay` の唯一の翻訳層です。

- 使う API は 3 つだけ: `set_noise_suppressor_settings(**)`,
  `set_compressor_settings(**)`, `set_guitar_effects(**kwargs)`。Distortion
  pedal 選択は `set_distortion_settings` ではなく
  `set_guitar_effects(distortion_pedal_mask=...)` を使い、cached 状態と
  整合させます。
- raw GPIO write、`set_distortion_pedal*` ショートカット、
  `HdmiEffectStateMirror.render()` 経由の二重描画は呼びません。
  HDMI render は dirty-flag loop が単独で所有します。
- `apply_interval_s` (既定 100 ms) で連続回転中の AXI flooding を抑え、
  encoder 3 short press は throttle を bypass します。
- 例外は `last_apply_ok=False` / `last_apply_message=<repr>` に保存し、
  loop は落としません。GUI bottom-right status strip と resource print に
  `LIVE` / `OK` / `ERR` / `RAT?` / `UNSUP` ラベルで反映されます。
- EQ knob は GUI `0..100` → overlay `0..200` (50 == unity) に変換。Cab
  `MODEL` knob は表示専用で、overlay へは `AppState.cab_model_idx` (0..2)
  を送ります。

### 実行: notebook (1 セル)

```text
http://192.168.1.9:9090/notebooks/audio_lab/EncoderGuiSmoke.ipynb
```

セル先頭の定数 (`LIVE_APPLY` / `APPLY_INTERVAL_MS` / `VALUE_STEP` /
`SKIP_RAT` / `NO_AUDIO_APPLY`) で挙動を切り替え可。`ResourceSampler` が
2 秒毎に `sys_cpu` / `proc_cpu` / `mem` / `rss` / `temp` / `poll Hz` /
`render fps` / `mode (idle|active)` / `last apply message` を print します。

### 実行: CLI (notebook 不要)

```sh
ssh xilinx@192.168.1.9 '
  cd /home/xilinx/Audio-Lab-PYNQ &&
  sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
    python3 scripts/run_encoder_hdmi_gui.py --live-apply --skip-rat
'
```

主な CLI flags (`scripts/run_encoder_hdmi_gui.py --help`):

| Flag | 既定 | 内容 |
| --- | --- | --- |
| `--live-apply` / `--no-live-apply` | `--live-apply` | encoder 3 rotate ごとに applier を呼ぶか |
| `--apply-interval-ms N` | `100` | live apply throttle 窓 (ms) |
| `--value-step N` | `5.0` | knob 値 step per encoder 3 detent (0..100 スケール) |
| `--skip-rat` / `--include-rat` | `--skip-rat` | RAT (Distortion pedal-mask bit 2) を encoder cycle と live apply から除外 |
| `--no-audio-apply` | off | overlay write を全てスキップ (GUI のみ動作) |
| `--dry-run` | off | overlay / HDMI / encoder bring-up を全てスキップ (off-board smoke) |
| `--poll-hz-active N` | `10.0` | event 受信中の poll 周期 |
| `--poll-hz-idle N` | `4.0` | idle 状態の poll 周期 |
| `--idle-threshold-s N` | `1.0` | idle と判定するまでの無 event 秒数 |
| `--max-render-fps N` | `5.0` | render 上限 (連続回転中も capped) |
| `--status-interval-s N` | `2.0` | resource print 周期 |
| `--reverse-encN` (N=0/1/2) | off | encoder N の回転方向反転 |
| `--swap-encN` (N=0/1/2) | off | encoder N の CLK/DT swap |
| `--debounce-ms N` | (IP default) | encoder debounce window (1..255) |

### 既知の制約

- RAT pedal-mask bit 2 は encoder 操作対象外 (`--include-rat` で解除可)。
  Clash stage と `HdmiEffectStateMirror.rat()` は手付かずで、notebook
  からの RAT 直接呼び出しは従来通り動作します。
- GUI 上に存在しない effect / parameter は encoder で操作しません。
  applier が `unsupported` として記録し、status strip に `UNSUP` 表示。
- Phase 7G+ runtime は HDMI render を dirty-flag loop で 1 箇所に集約
  しているため、`HdmiEffectStateMirror.render()` 経由の per-apply 再描画は
  encoder runtime からは呼びません (notebook 用途では残存)。

### 残作業 (D35)

物理 rotary encoder での音色変化対面確認 (Encoder 1/2/3 全ての rotate /
short / long を実操作で記録) は **未** です。`DECISIONS.md` D35 の条件を
満たすまで "encoder standalone operation completed" は claim しません。

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

| 項目 | 範囲 | 内容 |
| --- | --- | --- |
| `THRESHOLD` | 0..100 | 検出エンベロープと比較する基準レベル。byte = `round(threshold * 255 / 1000)` (新スケール 100 ≡ 旧 10) |
| `DECAY` | 0..100 | 閉じる速さ。0 = タイト (~1.4 ms full close)、100 = サステイン保持 (~85 ms full close) |
| `DAMP` | 0..100 | 最大ノイズ抑制量。0 ≒ 50% closed gain (自然)、100 ≒ 0% (完全ミュート) |

`GuitarPedalboardOneCell.ipynb` には NS-2 Style / NS-1X Natural / High Gain Tight / Sustain Friendly の 4 プリセットを用意しています。RNNoise / FFT / spectral 系処理は採用していません (PYNQ-Z2 PL リソース都合)。BOSS NS-2 / NS-1X は操作思想のみ参考にしており、回路やコードのコピーは行っていません。詳細は [`docs/ai_context/DECISIONS.md`](docs/ai_context/DECISIONS.md) D11、[`docs/ai_context/DSP_EFFECT_CHAIN.md`](docs/ai_context/DSP_EFFECT_CHAIN.md) Noise Suppressor 節を参照してください。

### Compressor (stereo-linked feed-forward peak)

Compressor 段は **専用 AXI GPIO** (`axi_gpio_compressor` @ `0x43CD0000`) で制御するステレオリンクの feed-forward peak compressor です。Noise Suppressor の後段、Overdrive の前段に配置され、ピッキングの粒を揃えてサステインを伸ばします。enable は専用 GPIO の `ctrlD` bit 7。

| 項目 | 範囲 | 内容 |
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

| 項目 | 範囲 | 内容 |
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

DSP 側では `LowPassFir.hs` の `ampPreLowpassFrame` が `ampModelSel` ヘルパで character byte を 4 band に量子化し、post-clip pre-LPF の alpha を band ごとに `0 / 4 / 12 / 24` 段階で darken します。さらに fizz-control pass で `ampTrebleGain` と presence 戻し量を model 別に少し cap し、`high_gain_stack` ほど 8..16 kHz の戻りを抑えるようにしました。`ampPowerFrame` / `ampResPresenceMixFrame` の safety `softClipK` knee も `3_500_000` から `3_400_000` へ少し下げています。新規 GPIO / `topEntity` port / `block_design.tcl` 変更はありません。

最新 Amp Simulator fizz-control build は bit/hwh 再生成と PYNQ-Z2 deploy 済みです。timing は `WNS = -8.022 ns` / `TNS = -13937.512 ns` / `WHS = +0.052 ns` / `THS = 0.000 ns` で、直前の audio-analysis build (`WNS = -8.731 ns`) から WNS が 0.709 ns 改善しています。Delay line 実装や `axi_gpio_delay_line` は含まれていません。

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
`hw/ip/clash/src/LowPassFir.hs` と `hw/ip/clash/src/AudioLab/` 配下の
module 群** が唯一の正です。Clash から VHDL を生成し、Vivado で
bit / hwh をビルドして PL 側で動かしています。
Python 側 (`AudioLabOverlay.py`) は AXI GPIO への制御 word を書き出す
役割で、音そのものは PL で処理しています。

2026-05-08 の LowPassFir split refactor で、挙動を変えずに
`LowPassFir.hs` を薄い top module (`topEntity` と外部 interface) にし、
型定義、固定小数点 helper、制御 word helper、AXIS helper、各 effect
stage、`fxPipeline` を `AudioLab.*` module に分離しました。DSP 係数、
bit 幅、pipeline 順、`topEntity` port、`block_design.tcl`、AXI GPIO、
Python API、Notebook UI、Chain Preset は変更していません。local
Clash/Vivado build は `WNS = -8.022 ns` / `TNS = -13937.512 ns` /
`WHS = +0.052 ns` / `THS = 0.000 ns` で、直前 deploy baseline から
WNS 差分 0.000 ns です。`PYNQ_HOST=192.168.1.9` で deploy 済みで、
実機 smoke test も通過しています。

2026-05-09 の internal mono DSP pass で、外部仕様はそのままに DSP
内部の主経路を mono sample 中心へ整理しました。AXI input は従来どおり
48-bit stereo (`Left 24-bit + Right 24-bit`) ですが、ギター入力では
ADC Left channel を mono source として採用し、Right channel は未接続
ノイズを避けるため破棄します。DSP の最終 mono result は AXI output の
Left/Right 両方へ複製します。`topEntity` interface、port 名/順序、
`block_design.tcl`、AXI GPIO、Python API、Notebook、Chain Preset は変更
していません。AXI Stream metadata は入力から出力へ保持し、TLAST は
入力 packet 終端をそのまま出力へ伝搬します。DMA 検証では Case A
(Left nonzero / Right different)、Case B (Left zero / Right large)、
Case C (Right inverted noise) の全てで timeout なし、skip 16 frame 以降
の output L/R 完全一致、Right input rejection を確認済みです。

過去にあった C++ DSP プロトタイプ (`src/effects/*.cpp`) は **削除済み**
です。現在のリアルタイム音声経路は使っておらず、新しいエフェクトを
追加する際の出発点としても用いません。新エフェクトの追加方針は
[`docs/ai_context/EFFECT_ADDING_GUIDE.md`](docs/ai_context/EFFECT_ADDING_GUIDE.md)
を参照してください。

ローカルの単体テストは [テスト](#テスト) セクションを参照してください。

## ノートブック

| Notebook | 内容 |
| --- | --- |
| `GuitarPedalboardOneCell.ipynb` | 1セル UI のメインノートブック。Chain Preset dropdown (Safe Bypass / Basic Clean / Clean Sustain / Light Crunch / Tube Screamer Lead / RAT Rhythm / Metal Tight / Ambient Clean / Solo Boost / Noise Controlled High Gain / DS-1 Crunch / Big Muff Sustain / Vintage Fuzz) で実用音色をワンクリック適用、Distortion Pedalboard dropdown は全 7 ペダル選択可、加えて Compressor / Noise Suppressor / Overdrive / Amp / Cab IR / EQ / Reverb の個別操作 (Apply / Safe Bypass / Refresh / Show Current State) |
| `EncoderGuiSmoke.ipynb` | Rotary encoder 3 個で HDMI GUI を実操作する 1 セル Notebook。`AudioLabOverlay()` を 1 回だけ attach、VTC `GEN_ACTSZ = 0x02580320` と encoder VERSION/CONFIG を assert、dirty-flag loop で `EncoderEffectApplier` 経由の live apply を実行 (Encoder1 rotate=effect / short=on-off / long=safe-bypass、Encoder2 rotate=param/model / short=mode toggle、Encoder3 rotate=value+throttled apply / short=force apply / long=reset knob)。`live_apply` / `apply_interval_ms` / `value_step` / `skip_rat` / `no_audio_apply` を notebook 先頭の定数で切替可。`ResourceSampler` が 2 秒毎に sys/proc CPU・mem・rss・temp・mode・poll Hz・render fps・last apply message を print。RAT (Distortion pedal-mask bit 2) は encoder 操作対象から除外 |
| `HdmiGuiShow.ipynb` | Phase 6I 新設の HDMI GUI 動作確認用 1 セルノートブック。`pynq.PL.bitfile_name` を見て `audio_lab.bit` が既にロード済みなら `download=False` で attach し rgb2dvi PLL を保護、未ロードなら `download=True` で fresh program。VTC `GEN_ACTSZ = 0x02580320` (SVGA 800x600) と VDMA error 無しを assert し、`render_frame_800x480_compact_v2` の 1 フレームを framebuffer `(0,0)` に書き出す。ipywidgets / live loop 無しで kernel 死亡を回避 |
| `HdmiGui.ipynb` | HDMI GUI のライブ動作ノートブック。CPU / RAM / FPS / VDMA error / current offset を毎秒モニタしつつ 5 fps で compact-v2 800x480 GUI を SVGA 800x600 framebuffer に流す。DIST / AMP / CAB の model dropdown 付き (HDMI GUI 側の MODEL 行表示のみ、DSP 側 model 切替は `GuitarPedalboardOneCell.ipynb` 側で行う)。`OFFSET_X` / `OFFSET_Y` で LCD 視認領域がずれているときの microadjust |
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
http://192.168.1.9:9090/notebooks/audio_lab/GuitarPedalboardOneCell.ipynb
```

## PYNQ-Z2 network

この環境の PYNQ-Z2 は、ルーターの DHCP 固定割当で固定 IP 運用します。
推奨予約は次の通りです。

```text
Device name : PYNQ-Z2
MAC address : 00:05:6B:02:CA:04
Reserved IP : 192.168.1.9
Jupyter     : http://192.168.1.9:9090/tree
SSH         : ssh xilinx@192.168.1.9
```

MAC / IP の確認には次を使います。

```sh
bash scripts/show_pynq_network_info.sh
```

DHCP 固定割当はリポジトリ側だけでは完了しません。ルーター管理画面で
実機 eth0 MAC と予約 IP を紐づけ、IP 重複がないことを確認してから
PYNQ-Z2 を再起動してください。PYNQ 側へ静的 IP を直接書く運用は、
今回は推奨しません。

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

通常は DHCP 固定割当した `192.168.1.9` を使い、deploy helper を実行します。
`PYNQ_HOST` を省略した場合も既定値は `192.168.1.9` です。

```sh
bash scripts/deploy_to_pynq.sh
# or
PYNQ_HOST=192.168.1.9 bash scripts/deploy_to_pynq.sh
```

到達不能な場合は、PYNQ-Z2 の電源、LAN ケーブル、ルーター DHCP 固定割当、
予約 MAC address、IP 重複を確認してください。

`scripts/deploy_to_pynq.sh` は PYNQ-Z2 上の **5 か所** すべての
`audio_lab.bit` / `audio_lab.hwh` を同期します:

1. `/home/xilinx/Audio-Lab-PYNQ/hw/Pynq-Z2/bitstreams/` (staging)
2. `/home/xilinx/Audio-Lab-PYNQ/audio_lab_pynq/bitstreams/`
3. `/usr/local/lib/python3.6/dist-packages/audio_lab_pynq/bitstreams/`
4. `/home/xilinx/jupyter_notebooks/audio_lab/bitstreams/`
   (`install_notebooks()` 経由)
5. `/usr/local/lib/python3.6/dist-packages/pynq/overlays/audio_lab/`
   (deploy script step 5.5 で `sudo cp`)

`AudioLabOverlay` は実行時の `PYTHONPATH` によって 1, 2, 3 のどれかから、
`pynq.Overlay("audio_lab")` (bare name) は 5 からロードするので、
1 か所でも古いと FPGA が古い bit のままになります
(`DECISIONS.md` D25, memory `pynq-site-packages-bit-cache`)。
deploy 後の同期確認は次で行えます:

```sh
ssh xilinx@192.168.1.9 'md5sum \
  /home/xilinx/Audio-Lab-PYNQ/hw/Pynq-Z2/bitstreams/audio_lab.bit \
  /home/xilinx/Audio-Lab-PYNQ/audio_lab_pynq/bitstreams/audio_lab.bit \
  /usr/local/lib/python3.6/dist-packages/audio_lab_pynq/bitstreams/audio_lab.bit \
  /home/xilinx/jupyter_notebooks/audio_lab/bitstreams/audio_lab.bit \
  /usr/local/lib/python3.6/dist-packages/pynq/overlays/audio_lab/audio_lab.bit'
```

5 行とも同じ md5 が出れば OK。Phase 6I C2 build の md5 は
`81f4c149fac2e5b3fc6ed4421da60cdf` (`.bit`) /
`b42e99bec9223b06c40d25ad36583765` (`.hwh`) です。

古い手動配置手順は以下に残していますが、通常運用では
`scripts/deploy_to_pynq.sh` を使ってください。

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

HDMI 統合版 (Phase 6I C2 SVGA 800x600) が正しくロードされているかは、
`v_tc_hdmi` の `GEN_ACTSZ (0x60)` を読むのが一番速いです:

```python
from pynq import MMIO
vtc = MMIO(int(ol.ip_dict["v_tc_hdmi"]["phys_addr"]), 0x1000)
actsz = vtc.read(0x60)
print(hex(actsz))               # -> 0x2580320
print("V_active =", (actsz >> 16) & 0x1FFF)  # -> 600
print("H_active =", actsz & 0x1FFF)          # -> 800
```

`0x02580320` 以外が返るときは bit copy のどれかが古いので、上記の
PYNQ への配置セクションの 5 か所 md5 同期コマンドを再実行してください。
読みに行く順序は **必ず `AudioLabOverlay()` の後** にしてください
(overlay 構築前の PL アドレス read は Jupyter kernel を kill します、
memory `pynq-mmio-before-overlay-kills-kernel`)。

## テスト

ローカル (PYNQ なし) で Python 制御層の挙動を検証する unit tests を
同梱しています。`pynq` パッケージは `tests/_pynq_mock.py` でモックする
ため、x86 Linux + Python 3 だけで実行できます。

```sh
# legacy: overlay control words のみ (1 ファイル、79 raw asserts)
make tests

# 全 unit tests (encoder + HDMI + overlay + state mirror)
python3 -m unittest discover -s tests -v

# 個別実行
python3 -m unittest -v \
  tests.test_encoder_input_decode \
  tests.test_encoder_ui_controller \
  tests.test_compact_v2_encoder_state \
  tests.test_encoder_effect_apply
```

| Suite | 件数 | 内容 |
| --- | ---: | --- |
| `test_overlay_controls` | 79 raw asserts | legacy overlay API (control words / GPIO mapping / safe defaults / chain presets) |
| `test_encoder_input_decode` | 13 | s8/s32 sign-extend、`DELTA_PACKED` unpack、`STATUS` decode、`configure()` round-trip、`clear_events()`、edge carry、short/long press、synthetic release |
| `test_encoder_ui_controller` | 23 | Encoder1/2/3 rotate/short/long の AppState 反映、`MirrorSpy` / `BridgeSpy` 経由 apply、Phase 7G+ の RAT skip / live apply throttle / applier on-off / safe-bypass / force-apply / knob reset / live\_apply 無効時 / applier 状態伝播 |
| `test_encoder_effect_apply` | 11 | dry-run isolation、3 overlay 経路、throttle、force、`skip_rat`/`include_rat`、unsupported 検出、safe-bypass、exception 捕捉 |
| `test_compact_v2_encoder_state` | 5 | Phase 7G + 7G+ AppState 既定値、JSON round-trip、renderer がデフォルトと live-apply フラグ付きで 800x480 frame を返す |
| `test_hdmi_gui_bridge` | 7 | `AudioLabGuiBridge` の AppState -> AudioLabOverlay 変換 |
| `test_hdmi_model_state_mapping` | 13 | pedal / amp / cab model index normalization |
| `test_hdmi_origin_mapping` | 8 | framebuffer 原点 / placement / offset の整合 |
| `test_hdmi_resource_monitor` | 15 | `/proc` ベース `ResourceSampler` の CPU / mem / temp parsing |
| `test_hdmi_selected_fx_state` | 8 | `mark_selected_fx` / `assert_selected_fx` / dropdown 可視判定 |

`make tests` は `tests/Makefile` 経由で `test_overlay_controls.py` のみを
実行します (歴史的経緯; C++ DSP 撤去 (`DECISIONS.md` D13) 以降は Python
制御層のみ対象)。encoder / HDMI 系を含めた regression は
`python3 -m unittest discover -s tests -v` を使ってください。

実機 (PYNQ 上) 向け smoke は別系統です:

| Script | 用途 |
| --- | --- |
| `scripts/test_encoder_input.py` | 実機 encoder 60 秒 manual rotate/press smoke (VERSION / CONFIG / COUNT 表示) |
| `scripts/test_hdmi_encoder_gui_control.py` | 実機 encoder + HDMI frame write smoke (scripted または `--use-real-encoder`) |
| `scripts/test_hdmi_800x480_frame.py` | 1-frame HDMI smoke (Phase 5C/6I 兼用) |
| `scripts/test_hdmi_render_bbox.py` | 800x480 compact-v2 bbox 比較 |
| `scripts/test_hdmi_selected_fx_switch.py` | SELECTED FX 切替時の dropdown 可視確認 |
| `scripts/test_hdmi_model_selection_ui.py` | model dropdown UI の表示確認 |
| `scripts/test_hdmi_realtime_pedalboard_controls.py` | realtime pedalboard controls の応答時間計測 |
| `scripts/test_hdmi_800x480_origin_guard.py` | framebuffer 左上 (0,0) origin guard |
| `scripts/audio_diagnostics.py` | capture / output zero / output sine 等の audio diagnostics CLI |

## 既知の注意点

- Vivado 実装時に setup timing violation が残ります。最新の deploy 済 bitstream (Phase 6I C2 SVGA 800x600 / 40 MHz HDMI 統合版、commit `5332b7e`) は `WNS = -8.096 ns` / `TNS = -6389.430 ns` / `WHS = +0.040 ns` / `THS = 0.000 ns` です (実機 deploy band は -6 ~ -9 ns 程度。この範囲内であれば実機では問題なく動作する確認済み)。ホールド (`WHS / THS`) は引き続き clean を維持しています。詳細は [`docs/ai_context/TIMING_AND_FPGA_NOTES.md`](docs/ai_context/TIMING_AND_FPGA_NOTES.md) を参照してください。
- HDMI 統合パスの rgb2dvi v1.4 (`kClkRange=3`) は固定 MMCM 乗算器 `M=20` を使うため、Phase 6I C2 の `40 MHz` pixel clock では PLL の VCO が valid 帯 (`800..1600 MHz`) の下端 `800 MHz` ちょうどに乗ります。**PYNQ-Z2 電源 ON 後の最初の `Overlay(..., download=True)` は安定して lock しますが、同一 Python session で 2 度目の `download=True` を呼ぶと PLL が再 lock せず LCD が白画面 / no signal になることがあります** (VDMA や VTC のレジスタは正常のままで気付きにくい)。`HdmiGuiShow.ipynb` は `pynq.PL.bitfile_name` を見て既ロードなら `download=False` で attach するため、同 session 内で何度でも安全に再実行できます。それでも白画面になったら PYNQ-Z2 を電源 cycle してセルを 1 回だけ実行し直してください。詳細は `DECISIONS.md` D25、memory `rgb2dvi-pll-edge-at-40mhz`。
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

## ドキュメント (`docs/ai_context/`)

作業者向け context は `docs/ai_context/` 配下にあります。AI エージェント
(Claude Code / Codex) 向けの読み順は
[`docs/ai_context/README.md`](docs/ai_context/README.md) と
[`CLAUDE.md`](CLAUDE.md) を参照してください。

| Doc | 内容 |
| --- | --- |
| [`PROJECT_CONTEXT.md`](docs/ai_context/PROJECT_CONTEXT.md) | プロジェクトの目的、toolchain、top-level layout、operational facts、key principles |
| [`CURRENT_STATE.md`](docs/ai_context/CURRENT_STATE.md) | 直近の load-bearing facts と phase 履歴 (chronological) |
| [`DECISIONS.md`](docs/ai_context/DECISIONS.md) | 重要決定の付番ログ (D1..D37、その時々の状況 / 決定 / 境界 / why を記録) |
| [`RESUME_PROMPTS.md`](docs/ai_context/RESUME_PROMPTS.md) / [`RESUME_PROMPTS_HISTORY.md`](docs/ai_context/RESUME_PROMPTS_HISTORY.md) | 作業中断後の再開プロンプト (current / 過去 phase) |
| [`EFFECT_ADDING_GUIDE.md`](docs/ai_context/EFFECT_ADDING_GUIDE.md) / [`EFFECT_STAGE_TEMPLATE.md`](docs/ai_context/EFFECT_STAGE_TEMPLATE.md) | 新エフェクト追加の判断フローと spec テンプレ |
| [`DSP_EFFECT_CHAIN.md`](docs/ai_context/DSP_EFFECT_CHAIN.md) | Clash 側エフェクトチェーンの実装メモ |
| [`DISTORTION_REFACTOR_PLAN.md`](docs/ai_context/DISTORTION_REFACTOR_PLAN.md) | Distortion pedal-mask 設計の経緯 |
| [`REAL_PEDAL_VOICING_TARGETS.md`](docs/ai_context/REAL_PEDAL_VOICING_TARGETS.md) | 実機ペダル風 voicing pass の目標と変更点 |
| [`AUDIO_RECORDING_ANALYSIS.md`](docs/ai_context/AUDIO_RECORDING_ANALYSIS.md) | 録音解析で見えた AmpSim / Cabinet / Overdrive / Compressor の差分メモ |
| [`AUDIO_SIGNAL_PATH.md`](docs/ai_context/AUDIO_SIGNAL_PATH.md) | line-in -> AXIS -> DSP -> codec の signal path |
| [`GPIO_CONTROL_MAP.md`](docs/ai_context/GPIO_CONTROL_MAP.md) | 全 AXI GPIO の byte / bit 契約 (effect output ledger) |
| [`TIMING_AND_FPGA_NOTES.md`](docs/ai_context/TIMING_AND_FPGA_NOTES.md) | Vivado timing baseline (WNS / TNS / WHS / THS) と reject ライン |
| [`BUILD_AND_DEPLOY.md`](docs/ai_context/BUILD_AND_DEPLOY.md) | bit / hwh ビルド + 5 ヶ所同期の手順 |
| [`PYNQ_RUNTIME.md`](docs/ai_context/PYNQ_RUNTIME.md) | PYNQ 上の Python 3.6 ランタイム情報 |
| [`HDMI_GUI_INTEGRATION_PLAN.md`](docs/ai_context/HDMI_GUI_INTEGRATION_PLAN.md) (+ `docs/ai_context/history/hdmi_phases/`) | HDMI GUI integration の経緯 (Phase 4 ~ 6I C2 SVGA 800x600) |
| [`HDMI_BLOCK_DESIGN_TCL_PATCH_PLAN.md`](docs/ai_context/HDMI_BLOCK_DESIGN_TCL_PATCH_PLAN.md) | HDMI integration tcl の差分ガイド |
| [`ENCODER_GUI_CONTROL_SPEC.md`](docs/ai_context/ENCODER_GUI_CONTROL_SPEC.md) | encoder + GUI 操作仕様 (Phase 7A / 7B planning から 7G+ live apply まで) |
| [`ENCODER_INPUT_IMPLEMENTATION.md`](docs/ai_context/ENCODER_INPUT_IMPLEMENTATION.md) | encoder PL IP + Python driver + standalone runtime + tests + risks |
| [`ENCODER_INPUT_MAP.md`](docs/ai_context/ENCODER_INPUT_MAP.md) | encoder PL IP の AXI register / address / CONFIG bit 表 |
| [`EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md`](docs/ai_context/EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md) | 外付け codec 計画 (Phase 7、planning 段階) |
| [`IO_PIN_RESERVATION.md`](docs/ai_context/IO_PIN_RESERVATION.md) | PMOD / RPi header / Arduino header の pin 予約 |

## Future Work

- 外付け **PCM1808** (24-bit stereo ADC) と **PCM5102 / PCM5102A**
  (I2S DAC) を別 I2S path として追加し、ADAU1761 と切替可能にする計画
  (Phase 7、planning 段階)。詳細は
  [`docs/ai_context/EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md`](docs/ai_context/EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md)
  / [`docs/ai_context/IO_PIN_RESERVATION.md`](docs/ai_context/IO_PIN_RESERVATION.md)、
  `DECISIONS.md` D27 ~ D29。Phase 7A 時点では XDC / `block_design.tcl`
  / bit / hwh は **未変更**。
- 物理 rotary encoder での 3 ch すべての rotate / short / long の対面
  smoke。`scripts/run_encoder_hdmi_gui.py` と `EncoderGuiSmoke.ipynb` で
  音色変化を確認し、必要なら `--reverse-encN` / `--swap-encN` /
  `--debounce-ms` の最終設定を docs に記録する (`DECISIONS.md` D35)。
- HDMI GUI と encoder runtime をまたいだ更新では、GUI 表示 / live apply /
  resource monitor が全て同期しているかを 1 ファイルで read-modify-write
  できるよう、`EncoderEffectApplier` と `HdmiEffectStateMirror` の状態
  集約 helper を検討 (現在は applier の `status_snapshot()` と mirror の
  `summary()` が別々)。

なお Phase 7F (PL encoder IP) / Phase 7G (Python + GUI focus state) /
Phase 7G+ (GUI-first live apply、`EncoderEffectApplier` 経由) は
**実装・deploy 済**で、Future Work からは外しています。詳細は
[Rotary Encoder GUI 操作](#rotary-encoder-gui-操作-phase-7f--7g--7g)
セクションと `DECISIONS.md` D30 ~ D37 を参照してください。

## AI development context

Claude Code / Codex 向けの作業コンテキストは
[`docs/ai_context/README.md`](docs/ai_context/README.md) にまとめています。
