# Audio-Lab-PYNQ

PYNQ-Z2 と Digilent Pmod I2S2 (CS4344 DAC + CS5343 ADC) を使って、
Line-in の音声を FPGA 上で処理し、Pmod Line Out へ返すための
オーディオ DSP 実験環境です。ADAU1761 オンボード codec は現行 build でも
I2C 初期化 / ADC HPF health check / `sdata_o` debug visibility のために
残していますが、実際のデプロイ済み主音声経路は PMOD JB の Pmod I2S2
mode 2 (`ADC -> DSP -> DAC`) です。

現在の主な用途は、ギター/ライン音声向けのリアルタイムエフェクト処理です。Jupyter Notebook、HDMI 統合 GUI、3 個のロータリーエンコーダー、3 個の 3PDT footswitch、または `scripts/` 配下の CLI からエフェクトの ON/OFF と各パラメータを操作できます。

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
#     http://192.168.1.9:9090/notebooks/audio_lab/PmodI2S2EffectControlOneCell.ipynb

# 3b. HDMI GUI smoke (5 インチ 800x480 LCD)
#     http://192.168.1.9:9090/notebooks/audio_lab/HdmiGuiShow.ipynb

# 3c. ロータリーエンコーダー実操作 (notebook 不要)
ssh xilinx@192.168.1.9 '
  cd /home/xilinx/Audio-Lab-PYNQ &&
  sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
    python3 scripts/run_encoder_hdmi_gui.py --live-apply --skip-rat --pmod-mode dsp --wah-pedal
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

5 行とも同じ md5 が出れば OK。最新の accepted deployed build は
**D79 (Overdrive realism: per-model clip hardness + Klon/CENTAUR clean-blend)**
で、`.bit = f0cb0276f27187d72476a2e773dd9a6e`、
`.hwh = 5fa0b84e9fe852c68629c651f94e4a9d` です。rollback baseline は
D78 (`.bit = 45e78763...`、footswitch + phys_opt)、その下が
D76 (`.bit = 9fdecae0...`、FP02M XADC re-add on the D75 island)。

## システム要件 / Toolchain

| 項目 | 値 |
| --- | --- |
| Board | PYNQ-Z2 (Xilinx Zynq-7000, `xc7z020clg400-1`) + Digilent Pmod I2S2 on PMOD JB (active audio) + ADAU1761 codec (configured / debug) |
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
│   ├── knob_tapers.py          # GUI/encoder/preset physical knob taper mapping
│   ├── effect_defaults.py      # per-effect default kwargs
│   ├── effect_presets.py       # 13 chain presets (physical knob positions)
│   ├── diagnostics.py          # input/output diagnostics (Phase 1)
│   ├── encoder_input.py        # Phase 7F PL IP driver (EncoderInput, EncoderEvent)
│   ├── encoder_ui.py           # Phase 7G EncoderUiController (event -> AppState)
│   ├── encoder_effect_apply.py # Phase 7G+ EncoderEffectApplier (AppState -> overlay)
│   ├── footswitch_input.py     # D78 axi_footswitch_input driver
│   ├── footswitch_control.py   # D78 FS1 FX toggle + FS2/FS3 preset stepping
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
│   │   ├── footswitch_input/src/axi_footswitch_input.v  # D78 3PDT footswitch PL IP
│   │   ├── pmod_i2s2/src/            # Pmod I2S2 FPGA-master I2S + AXI status IP
│   │   └── fx_gain/                  # legacy HLS gain IP (instantiated, not stream-connected)
│   └── Pynq-Z2/
│       ├── audio_lab.xdc                       # pin / clock constraints
│       ├── block_design.tcl                    # Vivado BD (off-limits, see CLAUDE.md)
│       ├── create_project.tcl                  # batch entry, sources every *_integration.tcl
│       ├── hdmi_integration.tcl                # HDMI VDMA + VTC + rgb2dvi (Phase 4/6I)
│       ├── encoder_integration.tcl             # axi_encoder_input @ 0x43D10000 (Phase 7F)
│       ├── pmod_i2s2_integration.tcl           # Pmod I2S2 active audio path + status @ 0x43D20000
│       ├── footswitch_integration.tcl          # axi_footswitch_input @ 0x43D50000 (D78)
│       ├── audio_lab_pmod_i2s2.xdc             # PMOD JB pin constraints for Pmod I2S2
│       └── bitstreams/audio_lab.{bit,hwh}      # built artefacts (deploy 経路 #1)
├── scripts/
│   ├── deploy_to_pynq.sh                  # rsync + sudo install + 5-ヶ所 bit/hwh 同期
│   ├── audio_diagnostics.py               # capture/stats CLI
│   ├── run_encoder_hdmi_gui.py            # Phase 7G+ notebook-less encoder runtime
│   ├── test_pmod_i2s2.py                  # Pmod I2S2 tone/loopback/dsp/mute smoke
│   ├── pmod_i2s2_mode.py                  # Pmod I2S2 MODE / status helper
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
- Digilent Pmod I2S2 mode 2 (`ADC -> DSP -> DAC`) による PMOD JB
  Line-in / Line-out のリアルタイム入力・出力
- Pmod I2S2 status/control AXI slave (`pmod_status_0` @ `0x43D20000`) と
  mode `tone` / `loopback` / `dsp` / `mute`
- ADAU1761 I2C 初期化、ADC HPF default-on smoke、`sdata_o` debug output
  の維持
- 単体リバーブの操作
- 複数エフェクトを固定順で通すギターエフェクトチェーン
- pedal-mask 方式の Distortion Pedalboard (`clean_boost` /
  `tube_screamer` / `rat` / `ds1` / `big_muff` / `fuzz_face` /
  `metal` の **全 7 ペダル実装済**、bit 7 のみ将来 reserved)
- BOSS NS-2 / NS-1X 風 Noise Suppressor、stereo-linked feed-forward
  Compressor、実機ペダル風 voicing pass を反映した既存ステージ
- Overdrive 6 モデルは D79 で clip hardness がモデル別になり、
  CENTAUR/Klon は clean-blend を持つようになりました (GPIO/API 変更なし)
- Cry Baby GCB-95 風 resonant band-pass Wah (専用 `axi_gpio_wah`、D72/D73)。
  ZOOM FP02M expression pedal を Arduino A0 (XADC VAUX1) 経由で POSITION に
  マッピング可能 (`SOURCE=PEDAL`、D76)
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
- Raspberry Pi header 上の 3 個の 3PDT footswitch 入力 IP
  (`axi_footswitch_input` / `fsw_in_0/s_axi`, AXI base `0x43D50000`)。
  FS1 は bound effect の ON/OFF、FS2/FS3 は chain preset next/prev。
  3PDT は latching なので IP は両エッジで 1 press_event を latch します
  (`DECISIONS.md` D78)
- 旧外付け **PCM5102 DAC / PCM1808 ADC** path は Phase 7C / 7E / 7D の
  履歴として repo に残していますが、現行 build では `create_project.tcl`
  から source されません。PMOD JB は Pmod I2S2 が専有します
  (`DECISIONS.md` D48)。
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
  `set_guitar_effects(**kwargs)`) のみを throttle 付きで呼び、raw
  GPIO 直書きは行いません。runner 既定は 20 ms、class 既定は 100 ms です。

### 配線 (3.3V 専用、5V 禁止)

Raspberry Pi header から 9 pin (`raspberry_pi_tri_i_6..14`):

| Encoder | CLK | DT | SW |
| --- | --- | --- | --- |
| ENC0 | `F19` | `V10` | `V8` |
| ENC1 | `W10` | `B20` | `W8` |
| ENC2 | `V6` | `Y6` | `B19` |

`+` は **PYNQ-Z2 3.3V rail のみ** に繋いでください。5V は基板上 pull-up
経由で `CLK` / `DT` / `SW` を 5V 化し、PL pin (LVCMOS33) を破損する恐れが
あります (`DECISIONS.md` D31)。PMOD JB は現行 Pmod I2S2 audio path が
専有し、PMOD JA は将来 I/O 予約のため encoder では使いません。

### 操作マッピング

| Encoder | Rotate | Push short | Push long |
| --- | --- | --- | --- |
| **Encoder 1** | `selected_effect` を変更 (GUI EFFECTS 9 項目を巡回) | 選択 effect の ON/OFF + live apply | Safe Bypass (全 ON/OFF、2 回目で復帰) + live apply |
| **Encoder 2** | `selected_knob` 変更 (`model_select_mode` 時は Distortion / Amp / Cab の model、Distortion では `skip_rat=True` の時 RAT を skip) | PEDAL / AMP / CAB は `model_select_mode` toggle、それ以外は `edit_mode` toggle | reserved (`model_select_mode` 解除) |
| **Encoder 3** | 選択 knob 値を ±`value_step` で増減 (live\_apply=True なら runner 既定 20 ms throttle で applier 呼び出し) | force apply (throttle bypass、`apply_pending` / `value_dirty` をクリア) | 選択 knob を `EFFECT_KNOBS` default に戻し apply |

GUI EFFECTS は `Noise Sup / Compressor / Wah / Overdrive / Distortion /
Amp Sim / Cab IR / EQ / Reverb` の 9 項目 (`GUI/compact_v2/knobs.py`)。
Wah 選択時は FX パネルに `SOURCE: MANUAL / PEDAL` strip を表示する (D72/D76)。RAT は
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
- `apply_interval_s` で連続回転中の AXI flooding を抑えます。
  `scripts/run_encoder_hdmi_gui.py` の既定は 20 ms、`EncoderEffectApplier`
  class 単体の既定は 100 ms です。encoder 3 short press は throttle を
  bypass します。
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
    python3 scripts/run_encoder_hdmi_gui.py --live-apply --skip-rat --pmod-mode dsp --wah-pedal
'
```

主な CLI flags (`scripts/run_encoder_hdmi_gui.py --help`):

| Flag | 既定 | 内容 |
| --- | --- | --- |
| `--live-apply` / `--no-live-apply` | `--live-apply` | encoder 3 rotate ごとに applier を呼ぶか |
| `--apply-interval-ms N` | `20` | live apply throttle 窓 (ms) |
| `--value-step N` | `5.0` | knob 値 step per encoder 3 detent (0..100 スケール) |
| `--skip-rat` / `--include-rat` | `--skip-rat` | RAT (Distortion pedal-mask bit 2) を encoder cycle と live apply から除外 |
| `--no-audio-apply` | off | overlay write を全てスキップ (GUI のみ動作) |
| `--dry-run` | off | overlay / HDMI / encoder bring-up を全てスキップ (off-board smoke) |
| `--pmod-mode dsp/tone/loopback/mute/keep` | `keep` | Pmod I2S2 MODE を runtime 起動時に設定。現行 audio 実操作は `--pmod-mode dsp` |
| `--wah-pedal` | off | FP02M A0 pedal controller を有効化し、Wah SOURCE=PEDAL 時に POSITION を `position_raw` へ流す |
| `--footswitch` / `--no-footswitch` | `--footswitch` | D78 footswitch polling。FS1=FX toggle、FS2=preset next、FS3=preset prev |
| `--footswitch-debounce-ms N` | IP default 5 | footswitch IP debounce window を上書き |
| `--poll-hz-active N` | `60.0` | event 受信中の poll 周期 |
| `--poll-hz-idle N` | `10.0` | idle 状態の poll 周期 |
| `--idle-threshold-s N` | `1.0` | idle と判定するまでの無 event 秒数 |
| `--max-render-fps N` | `20.0` | render 上限 (連続回転中も capped) |
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
Noise Suppressor -> Compressor -> Wah -> Overdrive -> Distortion Pedalboard -> RAT Distortion -> Amp Simulator -> Cab IR -> EQ -> Reverb
```

各エフェクトは個別に ON/OFF できます。

| エフェクト | パラメータ |
| --- | --- |
| Noise Suppressor | `THRESHOLD`, `DECAY`, `DAMP` |
| Compressor | `THRESHOLD`, `RATIO`, `RESPONSE`, `MAKEUP` |
| Wah | `POSITION`, `Q`, `VOLUME`, `BIAS` + `SOURCE` (`MANUAL` / `PEDAL`) — Cry Baby GCB-95 風 resonant band-pass (D72/D73)。`SOURCE=PEDAL` で ZOOM FP02M expression pedal (Arduino A0 = XADC VAUX1) が POSITION を駆動 (D76)、Q/VOLUME/BIAS は GUI / encoder 駆動のまま。専用 `axi_gpio_wah` @ `0x43D30000`。 |
| Overdrive | `TONE`, `LEVEL`, `DRIVE`, `MODEL` (`ts9` / `od1` / `bd2` / `jan_ray` / `ocd` / `centaur`) |
| Distortion Pedalboard | `TONE`, `LEVEL`, `DRIVE`, `BIAS`, `TIGHT`, `MIX` + 7-bit pedal mask (`clean_boost` / `tube_screamer` / `rat` / `ds1` / `big_muff` / `fuzz_face` / `metal`、全 7 ペダル実装済) |
| RAT Distortion | `FILTER`, `LEVEL`, `DRIVE`, `MIX` |
| Amp Simulator | `GAIN`, `BASS`, `MIDDLE`, `TREBLE`, `PRESENCE`, `RESONANCE`, `MASTER`, `DRV MODE` + 6 model selector (`JC-120` / `Twin Reverb` / `AC30` / `Rockerverb` / `JCM800` / `TriAmp Mk3`) |
| Cab IR | `MIX`, `LEVEL`, `MODEL`, `AIR` |
| EQ | `LOW`, `MID`, `HIGH` |
| Reverb | `Decay`, `tone`, `mix` |

すべて OFF の場合は、Pmod I2S2 mode 2 の `ADC -> DSP bit-bypass -> DAC`
としてサンプル等価の安全なバイパスに戻ります。いずれかのエフェクトを
ON にすると同じ Pmod mode 2 経路の中で `guitar_chain` が有効になります。

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

### Overdrive (six selectable models)

Compressor の後段、Distortion Pedalboard / RAT の前段に配置された
constant-coefficient table 方式の selectable Overdrive です。
`axi_gpio_overdrive` (`0x43C50000`) で制御し、enable は
**`gate_control.ctrlA` bit 1** (`overdrive_on`)。OFF 時は bit-exact
bypass です。

`ctrlA` / `ctrlB` / `ctrlC` は従来通り `TONE` / `LEVEL` / `DRIVE`。
`ctrlD` は上位 5 bit が Distortion `TIGHT`、下位 3 bit が
`overdrive_model` で共有されます。Python 側は read-modify-write で
両方を保持します (`GPIO_CONTROL_MAP.md`)。

| Model idx | Name | Main coefficient intent |
| ---: | --- | --- |
| 0 | TS9 | mid-focused mild asym clip |
| 1 | OD-1 | simple early overdrive |
| 2 | BD-2 | D62 retuned early breakup; `odDriveK=7`, knees `2_400_000 / 1_900_000`, safety `3_400_000` |
| 3 | Jan Ray | low-gain transparent style |
| 4 | OCD | wider drive ceiling |
| 5 | Centaur | Klon-style smooth clip + D79 parallel clean-blend |

信号フローは既存 stage のままです:

```text
overdriveDriveMultiplyFrame
  -> overdriveDriveBoostFrame
  -> overdriveDriveClipFrame
  -> overdriveToneMultiplyFrame -> overdriveToneBlendFrame
  -> overdriveLevelFrame
```

D62 は BD-2 model idx 2 の係数だけを変更した accepted build でした。
D79 ではさらに全 6 モデルの clip hardness がモデル別になり、
model idx 5 (CENTAUR/Klon) だけ parallel clean-blend を持ちます。
GPIO / Python API / `block_design.tcl` は変えていません。詳細は
[`docs/ai_context/DSP_EFFECT_CHAIN.md`](docs/ai_context/DSP_EFFECT_CHAIN.md)
Overdrive section と
[`docs/ai_context/TIMING_AND_FPGA_NOTES.md`](docs/ai_context/TIMING_AND_FPGA_NOTES.md)
D79 / D62 行を参照してください。

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

### RAT Distortion (独立ステージ、`axi_gpio_delay` 経由)

ProCo RAT 風のハードクリップ系ディストーションです。Distortion
Pedalboard の `rat` ペダル (bit 2) からも呼べますが、RAT 自体は**独立した
8 段ステージ** (`ratHighpass -> ratDriveMul -> ratDriveBoost ->
ratOpAmpLowpass -> ratClip -> ratPostLowpass -> ratTone -> ratLevel ->
ratMix`) を持っており、専用 GPIO `axi_gpio_delay` (`0x43C80000`) で制御
します。

> **GPIO 名の歴史的注意**: `axi_gpio_delay` という名前は **rename 禁止**
> です (`DECISIONS.md` D12、`GPIO_CONTROL_MAP.md` rule 1)。元々
> delay 用に作られたが現在の live Clash stage は RAT を駆動しており、
> `block_design.tcl` / hwh / Python attribute が全てこの名前を参照して
> います。rename には Vivado 再合成 (= 既定で off-limits) が必要です。

enable は **`gate_control.ctrlA` bit 4** (`rat_on`)。OFF 時は bit-exact
bypass。RAT は Distortion Pedalboard の pedal-mask に **含まれない**
独立 enable (`Python 側で `set_distortion_pedal('rat')` を呼ぶと
`gate_control.ctrlA` bit 4 が立ち、pedal-mask 排他切替の対象になります)。

| ctrl | パラメータ | 範囲 | DSP での使われ方 |
| --- | --- | --- | --- |
| `ctrlA` | `FILTER` | 0..100 | RAT 入力 HPF + opamp-style LPF の cutoff (`ratHighpass`, `ratOpAmpLowpass`) |
| `ctrlB` | `LEVEL` | 0..100 | 出力 Q7 multiply (`ratLevel`) |
| `ctrlC` | `DRIVE` | 0..100 | pre-gain (`ratDriveMul` + `ratDriveBoost`) — Tube Screamer より深く食わせる |
| `ctrlD` | `MIX` | 0..100 | wet/dry mix (`ratMix`) |

信号フロー (`fxPipeline` 内、8 register stage):

```text
ratHighpass     -- 入力 HPF (低域カット、ピックの粒立ち)
  -> ratDriveMul    -- pre-gain multiply
  -> ratDriveBoost  -- satShift8 で Sample に戻す
  -> ratOpAmpLowpass-- opamp 風 LPF (帯域制限)
  -> ratClip        -- ハードクリップ (FILTER で knee 連動)
  -> ratPostLowpass -- post-clip smoothing
  -> ratTone        -- TONE 1-pole blend
  -> ratLevel       -- Q7 level multiply
  -> ratMix         -- wet/dry mix
```

実機ペダル風 voicing pass で hard clip floor を低く、post LPF / tone を
全体に暗くしています。`DRIVE = 50..70` + `LEVEL = 80..100` で典型的な
RAT サウンド。`MIX < 100` で dry を混ぜると刻みでも芯が残ります。

**注意 (Phase 7G+)**: `EncoderEffectApplier` は既定で `skip_rat=True`、
encoder runtime からは RAT を選べません。Notebook の
`set_distortion_pedal('rat')` や `HdmiEffectStateMirror.rat()` 直接呼び出しは
従来通り動作します ([Rotary Encoder GUI 操作](#rotary-encoder-gui-操作-phase-7f--7g--7g)
参照)。

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

### Amp Simulator (six models + Clean/Drive)

Distortion 群の後段に置かれた軽量 Amp 模擬です。D55 で legacy
4-model `amp_character` band 方式を退役し、D58.2 で Drive-mode の
fixed-scalar retake を採用しました。商用アンプ回路 / IR / 係数のコピーは
なく、inspired-by の軽量 DSP です (`DECISIONS.md` D53 / D54 / D55 /
D58.2)。

GPIO は **2 つ並び**:

| GPIO | Address | ctrlA | ctrlB | ctrlC | ctrlD |
| --- | --- | --- | --- | --- | --- |
| `axi_gpio_amp` | `0x43C90000` | `input_gain` | `master` | `presence` | `resonance` |
| `axi_gpio_amp_tone` | `0x43CA0000` | `bass` | `middle` | `treble` | `bit7=ampDriveMode`, `bits2:0=ampModelIdx` |

enable は **`gate_control.ctrlA` bit 6** (`amp_on`)。OFF 時は bit-exact
bypass。`axi_gpio_amp_tone.ctrlD[6:3]` は reserved、model idx 6/7 は
Clash 側で JC-120 fallback です。

| Model idx | GUI label | Internal style |
| ---: | --- | --- |
| 0 | `JC-120` | bright clean |
| 1 | `Twin Reverb` | round clean combo |
| 2 | `AC30` | chime / crunch |
| 3 | `Rockerverb` | thicker mid-gain |
| 4 | `JCM800` | focused rock stack |
| 5 | `TriAmp Mk3` | modern high-gain |

`DRV MODE` は Clean/Drive の実 DSP branch です。Drive mode では
`ampDrivePosDelta` / `ampDriveNegDelta` の per-model fixed scalars で
asym clip knee を縮め、`ampPreLpfDriveDarken` と
`ampSecondStageDriveBonus` を加えます。D58 の `ch * factor` 方式は
DSP48E1 を増やして safe-bypass path の高域ノイズを誘発したため rejected、
D58.2 の fixed-scalar 方式が current baseline です。

信号フロー (`fxPipeline` 内):

```text
ampHighpassFrame
  -> ampDriveMultiplyFrame
  -> ampDriveBoostFrame
  -> ampWaveshapeFrame
  -> ampPreLowpassFrame
  -> ampSecondStageMultiplyFrame -> ampSecondStageFrame
  -> ampToneFilterFrame -> ampToneMixFrame
  -> ampPowerFrame
  -> ampResPresenceProductsFrame -> ampResPresenceMixFrame
  -> ampMasterFrame
```

Python 側は `set_amp_model("jcm800", drive_mode=True, ...)` と
`set_guitar_effects(amp_model=4, amp_drive_mode=True, ...)` の両方を
受け付けます。旧 `amp_character` percent kwarg は互換入力として残りますが、
UI / HDMI / encoder の現行表現は model idx + drive mode です。

### Cab IR (4-tap FIR + air variants)

Amp Simulator の直後に置かれる軽量 cabinet 模擬で、`axi_gpio_cab`
(`0x43CB0000`) で制御します。enable は **`gate_control.ctrlA` bit 7**
(`cab_on`)。OFF 時は bit-exact bypass。長い IR loader や WAV IR 畳み込み
は未実装で、4-tap FIR を 3 model × 3 air variant の係数テーブルから引いて
runtime で選んでいます。

| ctrl | パラメータ | 範囲 | 内容 |
| --- | --- | --- | --- |
| `ctrlA` | `MIX` | 0..100 | wet / dry mix。`0` = raw、`100` = 完全 cabinet shape |
| `ctrlB` | `LEVEL` | 0..100 | 出力 Q7 multiply、post-Cab `softClip` で safety |
| `ctrlC` | `MODEL` | 0/85/170 (3 step) | 3 preset IR の選択。Python は `cab_model = 0/1/2` を `* 85` で書く |
| `ctrlD` | `AIR` | 0..100 | 高域 air の戻し量。direct tap は capped (`air=100` でも raw line には戻らない) |

Model 別 voicing (recording-analysis pass で再調整、`cabCoeff` table から):

| `cab_model` | 想定 | 4-tap voicing |
| --- | --- | --- |
| 0 | 1x12 open back inspired | 軽め、低域控えめ、中域 + AIR が残る。Clean / Crunch 向け |
| 1 | 2x12 combo inspired | バランス型、高域少し控えめ。Tube Screamer Lead / RAT Rhythm 向け |
| 2 | 4x12 closed back inspired | 直接 tap 弱、delayed body tap 強。Metal / Big Muff / Fuzz Face で 5 kHz 以上の line-direct fizz を最強に抑える |

信号フロー (`fxPipeline` 内、4-tap FIR を 3 register stage に分割):

```text
cabProductsFrame   -- 4-tap × 4 product 計算
  -> cabIrFrame      -- 加算 + satShift で Sample に戻す
  -> cabLevelMixFrame -- LEVEL multiply + MIX blend + softClip
```

`cab_model` の量子化は `ctrlC = 0 / 85 / 170` で固定 (`GPIO_CONTROL_MAP.md`
の "do not treat as a free byte" 注記)。`AIR` は `cab_model` × 3 variant の
中で最も明るい variant を選んでも direct tap の戻りは cap されており、
`AIR=100` でも raw line direct tone には戻りません。詳細は
[`docs/ai_context/DSP_EFFECT_CHAIN.md`](docs/ai_context/DSP_EFFECT_CHAIN.md)
Cab IR section を参照してください。

### EQ (3-band post-cab)

Cab IR の後段、Reverb の前段に置かれた 3-band 後段 EQ です。
`axi_gpio_eq` (`0x43C70000`) で制御。enable は **`gate_control.ctrlA`
bit 0** ではなく **bit 3** (`eq_on`)。OFF 時は bit-exact bypass。

| ctrl | パラメータ | 範囲 | 内容 |
| --- | --- | --- | --- |
| `ctrlA` | `LOW` | 0..200 (GUI は 0..100、50 == unity) | 低域 gain (Q7、`_level_to_q7`)。`100` で unity |
| `ctrlB` | `MID` | 0..200 (GUI は 0..100、50 == unity) | 中域 gain |
| `ctrlC` | `HIGH` | 0..200 (GUI は 0..100、50 == unity) | 高域 gain |
| `ctrlD` | -- | -- | **未使用、将来予約** (planned EQ Q / mid-freq / character 等。`GPIO_CONTROL_MAP.md` で他用途への repurpose 禁止) |

> **EQ knob のスケール変換**: AudioLabOverlay の `set_guitar_effects` は
> `eq_low` / `eq_mid` / `eq_high` を **0..200 (100 = unity)** で受けますが、
> GUI / encoder 側は 0..100 で扱っています (50 = unity)。
> `EncoderEffectApplier` は GUI 0..100 → overlay 0..200 を automatic
> conversion (`* 2`) します ([Rotary Encoder GUI 操作](#rotary-encoder-gui-操作-phase-7f--7g--7g)
> の `EncoderEffectApplier の責務` 節参照)。

3 band は固定の crossover で、frequency / Q は GUI からは触れません。
実機ペダル風 voicing pass で出力 mix に `softClip` を追加し、3 band 全
boost (`LOW=MID=HIGH=200`) でも audible distortion を起こさないように
しています。詳細は [`docs/ai_context/DSP_EFFECT_CHAIN.md`](docs/ai_context/DSP_EFFECT_CHAIN.md)
EQ section を参照してください。

### Reverb (BRAM tap + tone + feedback + mix)

チェーン最終段の軽量 reverb です。`axi_gpio_reverb` (`0x43C30000`) で
制御。enable は **`axi_gpio_reverb.ctrlA` 低 byte** で、`gate_control.ctrlA`
bit 5 にも mirror されます (`GPIO_CONTROL_MAP.md`)。OFF 時は bit-exact
bypass。

| ctrl | パラメータ | 範囲 | 内容 |
| --- | --- | --- | --- |
| `ctrlA` | enable (低 byte) | 0..1 | reverb 単独 enable (gate と二重管理) |
| `ctrlB` | `DECAY` | 0..100 | tap feedback 量、~長さ感 |
| `ctrlC` | `TONE` | 0..100 | feedback path の tone。byte は `tone - tone/8` にスケールされて TONE=100 でも高域 damping が残る (voicing pass) |
| `ctrlD` | `MIX` | 0..100 | wet/dry mix |

実装は PYNQ-Z2 BRAM を使った短めの delay tap + feedback + tone LPF + wet/dry
mix で、長大な空間系 (plate / convolution) ではなく軽いリバーブ用途を
想定しています (BRAM 量とタイミングの都合)。

Python からは単独 API も残っています:

```python
ovl.set_reverb(enabled=True, reverb=35, tone=70, mix=25)
```

`set_guitar_effects(reverb_on=, reverb_decay=, reverb_tone=, reverb_mix=)` も
同じ word を書きます。

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

### DSP クロックドメイン島 (D75, 2026-05-31)

エフェクト(Wah / Compressor / Noise Suppressor / 6 種の distortion pedal /
Amp / Cab / EQ / Reverb)を盛り続けた結果、DSP
(`fxPipeline` / `clash_lowpass_fir_0`)が 100 MHz で timing を閉じられなく
なりました。worst path は DS-1 distortion 内の **45 論理段・CARRY4×36 の
算術チェーン**で、Data Path 約 `20.1 ns` に対しクロック周期は `10 ns`
(routed WNS `-10.387 ns` @ D72)。一方、他の block(AXI / DMA /
`i2s_to_stream` / Pmod / HDMI)は 100 MHz で問題なく閉じており、ボトル
ネックは DSP だけでした。

**解決策:DSP だけを 50 MHz の別クロック「島 (island)」にする。**

```
              FCLK_CLK0 = 100 MHz (fabric, 据え置き)
  PS ─┬─ AXI-Lite GPIO / AXI-DMA / i2s_to_stream / Pmod / HDMI(VDMA,v_tc) ...
      │
      │     ┌──────────── DSP island : FCLK_CLK1 = 50 MHz ────────────┐
  axis_data_fifo ─► cc_dsp_in ─► clash_lowpass_fir_0 ─► cc_dsp_out ─► axis_switch_sink
      │   (100 MHz)  (100→50)     (50 MHz / fxPipeline)   (50→100)      (100 MHz)
      │             ▲ axis_clock_converter            axis_clock_converter ▲
      └─ rst_island_50M が 50 MHz 側の proc_sys_reset。mclk(24)/Pmod(12.288)/
         pixel(40)を作る MMCM 群は FCLK_CLK0 入力のまま不変。
```

- `clash_lowpass_fir_0` だけ `FCLK_CLK1 = 50 MHz`(PS の FCLK1 を 1000 MHz
  IO PLL ÷5 ÷4 で生成)。これで DSP 各段は `20 ns` の budget を得て閉じます。
- それ以外の fabric は `FCLK_CLK0 = 100 MHz` のまま。**既存の I2S/Pmod
  クロックドメイン跨ぎ (CDC) を一切変えない**のが最重要点です。
- DSP の AXI-Stream 入出力は `axis_clock_converter`(`cc_dsp_in` が 100→50、
  `cc_dsp_out` が 50→100)で 2 ドメインを安全に橋渡しします。
- 以上は `hw/Pynq-Z2/island_integration.tcl`(additive。`hdmi/encoder/pmod/
  wah_integration.tcl` と同じく `create_project.tcl` から source、
  `block_design.tcl` 本体は非編集)が構築します。

**なぜ fabric 全体を 50 MHz にしないのか:** 最初に試した「全系 50 MHz」は
WNS を `-4.6 ns` まで改善しましたが、I2S/Pmod の CDC(100 MHz 前提で
成立していた位相関係)が壊れ、**bypass で常時ザラザラ**になりました。
クロックを下げてよいのは DSP 島の内側だけ、という切り分けが肝です。

**島に伴う 3 つの必須変更(いずれも load-bearing):**

1. **`paceCount` 除去**(`AudioLab/Pipeline.hs`、`acceptReady = readyOut`)。
   16 サイクルの pace は DMA バーストを 100 MHz で間引くためのもので、AXIS
   handshake 内で唯一クロック周波数に依存する項でした。50 MHz では frame
   受付間隔が倍になり不整合の元になるため、純粋な `readyOut` フロー制御に
   します。
2. **制御 word の CDC 同期**(`LowPassFir.hs` の `syncCtrl`)。12 本の
   32-bit 制御 word は 100 MHz GPIO ドメインから 50 MHz DSP へ跨ぎます。
   同期なしだと effect/knob を変えた瞬間に複数 bit が同時遷移し、50 MHz
   側が遷移途中の中間値を 1 サンプルだけ取り込んで **切替時にプチノイズ**
   が出ます(bypass は固定値なので無音、鳴るのは切替の瞬間だけ)。
   `syncCtrl` は 2-FF(metastability 対策)+ 2 サイクル安定検出(値が
   安定するまで採用しない)で、制御 word が準静的なことを利用して中間値を
   弾きます。**これが無いと bypass はクリーンでも切替で鳴ります。**
3. **`set_clock_groups -asynchronous`**(`audio_lab.xdc`)。7 つの独立
   クロック(`clk_fpga_0` 100 / `clk_fpga_1` 50 / `clk` 48 MHz Pmod /
   `bclk` 3 MHz I2S / mclk 24 / audio_ext 12.288 / pixel 40)を非同期
   グループとして宣言し、STA が無関係な inter-clock パスを検証しない
   ようにします(各跨ぎは `i2s_to_stream` / `axi_pmod_i2s2_status` slave /
   `axis_clock_converter` で同期化済み)。これで
   `rst_ps7_0_100M → pmod_master` の非同期リセットパス
   (`clk_fpga_0 → audio_ext`、それまでの `-4.2 ns` worst path)が除外され、
   WNS が `-0.706 ns` になりました。

**結果:**

| | D72 / D73 (100 MHz) | D75 (island) |
| --- | --- | --- |
| routed WNS | `-10.387` / `-10.910 ns` | **`-0.706 ns`** |
| WHS / THS | `+0.02` / `0` | `+0.052` / `0` |
| LUT / FF / BRAM | ~20.9k / ~22.7k / 6 | `21286` / `23968` / `6` |
| bit / hwh md5 | `eacc4f35` / … | `4a0b3dae` / `347d3e55` |

残る worst path は `clk_fpga_0` 内の AXI-Lite GPIO 書き込み(`-0.706 ns`)
で、稀なアクセス・100 MHz・typical silicon で閉じるため実害はありません
(D72 でも DSP の影に存在していました)。DSP の音色(Clash の係数)は
**D73 から完全に不変**で、D75 はクロック/CDC のみの変更です。実機 bench
(Pmod mode 2 = ADC→DSP→DAC)で all_off bypass クリーン / effect・knob
切替ノイズなし / 音程正常(サンプルレート維持) / 全 effect・GUI・HDMI
健全を確認しました。

現行の D79 build はこの D75 island を保持したまま、D76 XADC re-add、
D78 footswitch + phys_opt、D79 Overdrive realism を重ねています。D79 の
routed WNS は `-0.496 ns`、100 MHz audio fabric は `+0.532 ns / 0 fail`、
実機 bench で all_off bypass clean / no bitcrusher を確認済みです。

回り道として、**DS-1 段分割**と **Frame 幅削減(1067→731 bit)**も試し
ましたが、worst path が配線支配のためどちらも WNS を改善しませんでした
(この知見も `TIMING_AND_FPGA_NOTES.md` に記録)。

**ビルド時の既知の警告:** `set_clock_groups` の各 `get_clocks` に対して
`CRITICAL WARNING [Vivado 12-4739] No valid object(s) found` が出ますが
無害です。block-design 生成クロック(PS/MMCM)は top-level synth の
elaboration 時点では未定義のため bind できず、impl 時に再評価されて適用
されます(worst path が inter-clock → intra-clock に移ったことで適用を
確認済み)。消すには制約を implementation スコープ専用の xdc に分ける
必要があります。

**ロールバック:** D73 (`d1343291` / `aad985fe`) と D72 (`eacc4f35` /
`eaa88898`) は island の無い全系 100 MHz build で、git 履歴から復元
できます(bit/hwh を 5 サイトへ戻して power-cycle)。詳細設計は
`docs/ai_context/DSP_ISLAND_CLOCK_DESIGN.md`、決定記録は `DECISIONS.md`
D75、タイミング履歴は `TIMING_AND_FPGA_NOTES.md`。

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
| `PmodI2S2EffectControlOneCell.ipynb` | 現行 Pmod I2S2 mode 2 (`ADC -> DSP -> DAC`) の主確認用 1 セル UI。`AudioLabOverlay()` をロードし、`pmod_status_0` の `MODE=2` を設定して全エフェクトと mode 0/1/2/3 ボタン、status counter を操作 |
| `PmodI2S2HdmiGuiOneCell.ipynb` | HDMI GUI + rotary encoder / footswitch runtime を Pmod I2S2 mode 2 で起動する 1 セル Notebook。`scripts/run_encoder_hdmi_gui.py --live-apply --skip-rat --pmod-mode dsp --wah-pedal` を sudo subprocess として起動し、停止時は mute (`MODE=3`) |
| `GuitarPedalboardOneCell.ipynb` | 1セル UI のメインノートブック。Chain Preset dropdown (Safe Bypass / Basic Clean / Clean Sustain / Light Crunch / Tube Screamer Lead / RAT Rhythm / Metal Tight / Ambient Clean / Solo Boost / Noise Controlled High Gain / DS-1 Crunch / Big Muff Sustain / Vintage Fuzz) で実用音色をワンクリック適用、Distortion Pedalboard dropdown は全 7 ペダル選択可、加えて Compressor / Noise Suppressor / Overdrive / Amp / Cab IR / EQ / Reverb の個別操作 (Apply / Safe Bypass / Refresh / Show Current State) |
| `EncoderGuiSmoke.ipynb` | Rotary encoder 3 個で HDMI GUI を実操作する 1 セル Notebook。`AudioLabOverlay()` を 1 回だけ attach、VTC `GEN_ACTSZ = 0x02580320` と encoder VERSION/CONFIG を assert、dirty-flag loop で `EncoderEffectApplier` 経由の live apply を実行 (Encoder1 rotate=effect / short=on-off / long=safe-bypass、Encoder2 rotate=param/model / short=mode toggle、Encoder3 rotate=value+throttled apply / short=force apply / long=reset knob)。`live_apply` / `apply_interval_ms` / `value_step` / `skip_rat` / `no_audio_apply` を notebook 先頭の定数で切替可。`ResourceSampler` が 2 秒毎に sys/proc CPU・mem・rss・temp・mode・poll Hz・render fps・last apply message を print。RAT (Distortion pedal-mask bit 2) は encoder 操作対象から除外 |
| `HdmiGuiShow.ipynb` | Phase 6I 新設の HDMI GUI 動作確認用 1 セルノートブック。`pynq.PL.bitfile_name` を見て `audio_lab.bit` が既にロード済みなら `download=False` で attach し rgb2dvi PLL を保護、未ロードなら `download=True` で fresh program。VTC `GEN_ACTSZ = 0x02580320` (SVGA 800x600) と VDMA error 無しを assert し、`render_frame_800x480_compact_v2` の 1 フレームを framebuffer `(0,0)` に書き出す。ipywidgets / live loop 無しで kernel 死亡を回避 |
| `HdmiGui.ipynb` | HDMI GUI のライブ動作ノートブック。CPU / RAM / FPS / VDMA error / current offset を毎秒モニタしつつ 5 fps で compact-v2 800x480 GUI を SVGA 800x600 framebuffer に流す。DIST / AMP / CAB の model dropdown 付き (HDMI GUI 側の MODEL 行表示のみ、DSP 側 model 切替は `GuitarPedalboardOneCell.ipynb` 側で行う)。`OFFSET_X` / `OFFSET_Y` で LCD 視認領域がずれているときの microadjust |
| `GuitarEffectSwitcher.ipynb` | Noise Gate / Overdrive / Distortion / RAT / Amp / Cab IR / EQ / Reverb をON/OFFとプリセットで素早く切り替えるノートブック (Distortion Pedalboard セクションに DS-1 / Big Muff Sustain / Fuzz Face プリセット cell 追加) |
| `DistortionModelsDebug.ipynb` | Distortion pedal-mask API のウォークスルー (pedal一覧 + bit position + 全 7 ペダル実装済の表示と排他切替) |
| `GuitarEffectsChain.ipynb` | Noise Gate / Overdrive / Distortion / RAT / Amp / Cab IR / EQ / Reverb を操作するメインノートブック |
| `InputDebug.ipynb` | legacy ADAU / DMA capture 系のキャプチャ・統計・ADC HPF 切替によるノイズ診断 |
| `LineInPassthroughOneCell.ipynb` | legacy ADAU line-in path 向けの 1セル passthrough 確認用 |
| `LineInReverbOneCell.ipynb` | 1セルで軽いリバーブを有効化する確認用 |
| `PassthroughDebug.ipynb` | 入力、出力、コーデック、AXI Stream Switch の診断用 |
| `AudioLab.ipynb` | 元の Audio Lab 操作用ノートブック |

PYNQ 上では通常、次のURLから開きます。

```text
http://<PYNQのIPアドレス>:9090/notebooks/audio_lab/PmodI2S2EffectControlOneCell.ipynb
```

この環境では以下に配置済みです。

```text
http://192.168.1.9:9090/notebooks/audio_lab/PmodI2S2EffectControlOneCell.ipynb
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
    amp_model=2,          # AC30
    amp_drive_mode=False,
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

`GuitarPedalboardOneCell.ipynb` の Chain Preset dropdown から、エフェクトチェーン全体を 1 クリックで実用音色に切り替えられます。D80 から preset 値は「物理ノブ位置」として扱い、`audio_lab_pynq/knob_tapers.py` が gain/drive と tone 系だけを実機寄りの taper に変換してから既存の線形 overlay API へ渡します。Compressor の makeup は 45..60、Distortion の level は <=35 に抑えてあるので、プリセット切替で意図せず爆音になることはありません。

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
Pmod I2S2 CS5343 Line In (JB10 SDOUT, FPGA-master clocks)
  -> pmod_i2s2_master / i2s_to_stream
  -> axis_switch_source
  -> passthrough / guitar_chain / DMA
  -> axis_switch_sink
  -> i2s_to_stream
  -> pmod_i2s2_master mode2_right_snapshot
  -> Pmod I2S2 CS4344 Line Out
```

Pmod I2S2 mode 2 は D50 の workaround として DSP/IP の RIGHT slot を
左右 DAC slot に複製する mono output です。ADAU1761 の I2C 初期化と
ADC HPF smoke は維持していますが、ADAU `bclk` / `lrclk` / `sdata_i`
top-level port は現行 Pmod build では内部 load を持ちません。`i2s_to_stream_0/so`
は ADAU `sdata_o` G18 にも debug visibility として出ます。

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
| `axi_gpio_amp_tone` | `0x43CA0000` | Amp Simulator の bass/middle/treble + `ampDriveMode` / `ampModelIdx` |
| `axi_gpio_cab` | `0x43CB0000` | Cab IR の mix/level/model/air |
| `axi_gpio_noise_suppressor` | `0x43CC0000` | Noise Suppressor の THRESHOLD / DECAY / DAMP / mode |
| `axi_gpio_compressor` | `0x43CD0000` | Compressor の THRESHOLD / RATIO / RESPONSE / enable+MAKEUP |
| `pmod_status_0` | `0x43D20000` | Pmod I2S2 status counters + mode `tone` / `loopback` / `dsp` / `mute` |

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

5 行とも同じ md5 が出れば OK。最新の accepted deployed build (D79) の md5 は
`f0cb0276f27187d72476a2e773dd9a6e` (`.bit`) /
`5fa0b84e9fe852c68629c651f94e4a9d` (`.hwh`) です。

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
| `scripts/test_pmod_i2s2.py --mode tone/loopback/dsp/mute` | Pmod I2S2 mode 0/1/2/3 の実機 smoke。loopback / dsp は safety confirmation flag 必須 |
| `scripts/pmod_i2s2_mode.py --read/--mode/--clear` | `pmod_status_0` の MODE / CLEAR / status register を既ロード overlay に attach して操作 |
| `scripts/pmod_i2s2_capture_probe.py` | Pmod ADC SDOUT / peak / frame counter の rolling probe |
| `scripts/test_encoder_input.py` | 実機 encoder 60 秒 manual rotate/press smoke (VERSION / CONFIG / COUNT 表示) |
| `audio_lab_pynq/footswitch_input.py` / `footswitch_control.py` | D78 footswitch driver + controller (FS1 FX toggle、FS2/FS3 preset step) |
| `scripts/test_hdmi_encoder_gui_control.py` | 実機 encoder + HDMI frame write smoke (scripted または `--use-real-encoder`) |
| `scripts/test_hdmi_800x480_frame.py` | 1-frame HDMI smoke (Phase 5C/6I 兼用) |
| `scripts/test_hdmi_render_bbox.py` | 800x480 compact-v2 bbox 比較 |
| `scripts/test_hdmi_selected_fx_switch.py` | SELECTED FX 切替時の dropdown 可視確認 |
| `scripts/test_hdmi_model_selection_ui.py` | model dropdown UI の表示確認 |
| `scripts/test_hdmi_realtime_pedalboard_controls.py` | realtime pedalboard controls の応答時間計測 |
| `scripts/test_hdmi_800x480_origin_guard.py` | framebuffer 左上 (0,0) origin guard |
| `scripts/audio_diagnostics.py` | capture / output zero / output sine 等の audio diagnostics CLI |

## 既知の注意点

- Vivado 実装時に setup timing violation が残ります。最新の deploy 済
  bitstream は D79 Overdrive realism build で、
  `WNS = -0.496 ns`、100 MHz audio fabric は `+0.532 ns / 0 fail` です。
  ホールドは引き続き clean です。D58 / D59 / D60 / D61 / D63 / D64 /
  D74 / D78 の rejected / noisy attempts で分かった通り、WNS だけでなく
  safe-bypass の実音確認も deploy gate です。
  詳細は [`docs/ai_context/TIMING_AND_FPGA_NOTES.md`](docs/ai_context/TIMING_AND_FPGA_NOTES.md)
  を参照してください。
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
| [`DECISIONS.md`](docs/ai_context/DECISIONS.md) | 重要決定の付番ログ (D1..D79、その時々の状況 / 決定 / 境界 / why を記録) |
| [`RESUME_PROMPTS.md`](docs/ai_context/RESUME_PROMPTS.md) / [`RESUME_PROMPTS_HISTORY.md`](docs/ai_context/RESUME_PROMPTS_HISTORY.md) | 作業中断後の再開プロンプト (current / 過去 phase) |
| [`EFFECT_ADDING_GUIDE.md`](docs/ai_context/EFFECT_ADDING_GUIDE.md) / [`EFFECT_STAGE_TEMPLATE.md`](docs/ai_context/EFFECT_STAGE_TEMPLATE.md) | 新エフェクト追加の判断フローと spec テンプレ |
| [`DSP_EFFECT_CHAIN.md`](docs/ai_context/DSP_EFFECT_CHAIN.md) | Clash 側エフェクトチェーンの実装メモ |
| [`DISTORTION_REFACTOR_PLAN.md`](docs/ai_context/DISTORTION_REFACTOR_PLAN.md) | Distortion pedal-mask 設計の経緯 |
| [`REAL_PEDAL_VOICING_TARGETS.md`](docs/ai_context/REAL_PEDAL_VOICING_TARGETS.md) | 実機ペダル風 voicing pass の目標と変更点 |
| [`REAL_HARDWARE_FIDELITY_ROADMAP.md`](docs/ai_context/REAL_HARDWARE_FIDELITY_ROADMAP.md) | 実機ペダル / amp / cab にさらに寄せるための測定-first roadmap と段階的な実装案 |
| [`AUDIO_RECORDING_ANALYSIS.md`](docs/ai_context/AUDIO_RECORDING_ANALYSIS.md) | 録音解析で見えた AmpSim / Cabinet / Overdrive / Compressor の差分メモ |
| [`AUDIO_SIGNAL_PATH.md`](docs/ai_context/AUDIO_SIGNAL_PATH.md) | Pmod I2S2 mode 2 -> AXIS -> DSP -> Pmod DAC の signal path |
| [`GPIO_CONTROL_MAP.md`](docs/ai_context/GPIO_CONTROL_MAP.md) | 全 AXI GPIO の byte / bit 契約 (effect output ledger) |
| [`TIMING_AND_FPGA_NOTES.md`](docs/ai_context/TIMING_AND_FPGA_NOTES.md) | Vivado timing baseline (WNS / TNS / WHS / THS) と reject ライン |
| [`BUILD_AND_DEPLOY.md`](docs/ai_context/BUILD_AND_DEPLOY.md) | bit / hwh ビルド + 5 ヶ所同期の手順 |
| [`PYNQ_RUNTIME.md`](docs/ai_context/PYNQ_RUNTIME.md) | PYNQ 上の Python 3.6 ランタイム情報 |
| [`HDMI_GUI_INTEGRATION_PLAN.md`](docs/ai_context/HDMI_GUI_INTEGRATION_PLAN.md) (+ `docs/ai_context/history/hdmi_phases/`) | HDMI GUI integration の経緯 (Phase 4 ~ 6I C2 SVGA 800x600) |
| [`HDMI_BLOCK_DESIGN_TCL_PATCH_PLAN.md`](docs/ai_context/HDMI_BLOCK_DESIGN_TCL_PATCH_PLAN.md) | HDMI integration tcl の差分ガイド |
| [`ENCODER_GUI_CONTROL_SPEC.md`](docs/ai_context/ENCODER_GUI_CONTROL_SPEC.md) | encoder + GUI 操作仕様 (Phase 7A / 7B planning から 7G+ live apply まで) |
| [`ENCODER_INPUT_IMPLEMENTATION.md`](docs/ai_context/ENCODER_INPUT_IMPLEMENTATION.md) | encoder PL IP + Python driver + standalone runtime + tests + risks |
| [`ENCODER_INPUT_MAP.md`](docs/ai_context/ENCODER_INPUT_MAP.md) | encoder PL IP の AXI register / address / CONFIG bit 表 |
| [`PMOD_I2S2_INTEGRATION_PLAN.md`](docs/ai_context/PMOD_I2S2_INTEGRATION_PLAN.md) | 現行 Pmod I2S2 PMOD JB active audio path と元計画の履歴 |
| [`EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md`](docs/ai_context/EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md) | 旧 PCM5102 / PCM1808 path の履歴。現行 build では retired / archival |
| [`IO_PIN_RESERVATION.md`](docs/ai_context/IO_PIN_RESERVATION.md) | PMOD / RPi header / Arduino header の pin 台帳。PMOD JB は現行 Pmod I2S2 専用 |

## Future Work

- **Pmod I2S2 mode 2 の継続 QA**。現行の主音声経路は Pmod I2S2
  `ADC -> DSP -> DAC` です。安全な確認手順は外部 source -> Pmod Line In、
  Pmod Line Out -> monitor、on-module direct loopback jumper なし。
  `scripts/test_pmod_i2s2.py --mode dsp --confirm-dsp` と
  `scripts/pmod_i2s2_mode.py --read` を使い、`FRAME_COUNT`、`CLIP_COUNT`、
  peak counters、実音 safe-bypass を合わせて見る。
- **Pmod I2S2 mode 2 mono workaround の将来改善**。D50 の現行仕様では
  `mode2_right_snapshot` が RIGHT slot を左右 DAC slot に複製します。
  `i2s_to_stream` LEFT extraction と `i2sOut` setup race を根本修正する
  まではこの mono RIGHT output を current spec として扱います。
- **96 kHz / alternate sample-rate work**。Pmod I2S2 は将来 96 kHz
  実験余地がありますが、現行は 48 kHz / 24-bit / 32-bit slot /
  I2S Philips 固定です。変更時は Pmod master、I2S IP、Clash timing、
  HDMI/encoder runtime に影響がないかを別 phase で検証します。
- **旧 PCM5102 / PCM1808 path は archival**。Phase 7C / 7E / 7D の
  Tcl/XDC/RTL は履歴確認用に残していますが、現行 build では retired です。
  再投入する場合は Pmod I2S2 からの明示的な切替 phase と full rebuild /
  timing / bench-audio review が必要です。
- **物理 rotary encoder での 3 ch すべての rotate / short / long の対面
  smoke**。`scripts/run_encoder_hdmi_gui.py` と `EncoderGuiSmoke.ipynb`
  で音色変化を確認し、必要なら `--reverse-encN` / `--swap-encN` /
  `--debounce-ms` の最終設定を docs に記録する (`DECISIONS.md` D35)。
- **HDMI GUI と encoder runtime をまたいだ更新では、GUI 表示 / live
  apply / resource monitor が全て同期しているかを 1 ファイルで
  read-modify-write できるよう、`EncoderEffectApplier` と
  `HdmiEffectStateMirror` の状態集約 helper を検討** (現在は applier の
  `status_snapshot()` と mirror の `summary()` が別々)。

なお Phase 7F (PL encoder IP) / Phase 7G (Python + GUI focus state) /
Phase 7G+ (GUI-first live apply、`EncoderEffectApplier` 経由) は
**実装・deploy 済**で、Future Work からは外しています。詳細は
[Rotary Encoder GUI 操作](#rotary-encoder-gui-操作-phase-7f--7g--7g)
セクションと `DECISIONS.md` D30 ~ D37 を参照してください。

外付け codec 関連は Phase 7C / 7E / 7D の PCM5102 / PCM1808 履歴を経て、
D48 / D49 / D50 で Pmod I2S2 path に置き換わりました。PMOD JB の
現行 pin owner は `audio_lab_pmod_i2s2.xdc` と
`pmod_i2s2_integration.tcl` です。古い PCM5102 / PCM1808 の記述は
[`EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md`](docs/ai_context/EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md)
と履歴 docs の中だけで扱ってください。

## AI development context

Claude Code / Codex 向けの作業コンテキストは
[`docs/ai_context/README.md`](docs/ai_context/README.md) にまとめています。
