# Audio-Lab-PYNQ 技術詳細 (3/5) — UI・制御・ビルド/デプロイ

> [PORTFOLIO.md](../PORTFOLIO.md) の深掘り技術付録。HDMI GUI・ロータリーエンコーダ・フットスイッチ・Python 制御 API・IP レジスタマップ・ビルド/デプロイ/検証フローを扱う。

## 10. ハードウェア・ユーザーインターフェース

ソフトの GUI だけでなく、**物理操作系も自作の PL IP で統合**しているのが特徴です。

### 10.1 HDMI 5インチ LCD GUI
- FPGA から **VESA SVGA 800×600 @ 60 Hz / 40 MHz** で出力し、**800×480** のコンパクト UI を合成
  （可視行 0..479 が UI、480..599 は黒）
- レイアウトは `header` / `chain` / フルワイド `fx` の 3 パネル。選択中エフェクトのノブグリッドは
  ノブ数で適応（3→3×1、4→2×2、6→3×2、8→4×2）
- PEDAL / AMP / CAB はモデルドロップダウンチップをインライン描画
- 統合 `AudioLabOverlay` を 1 度だけロードして `hdmi_backend` を使用（`Overlay("base.bit")` 禁止、
  2 重オーバーレイ禁止）
- レンダラはテーマ別に `GUI/compact_v2/`（`knobs.py` / `state.py` / `layout.py` /
  `renderer.py` / `hit_test.py`）に分割

### 10.2 ロータリーエンコーダ ×3
- 専用 PL IP `axi_encoder_input`（`0x43D10000`）で 3 つのエンコーダを `STATUS` /
  `DELTA_PACKED` / `COUNT*` からデコード（PYNQ Python 3.6 安全、dataclass 不使用）
- GUI のノブ/エフェクト切替を**ライブ反映**（dirty-flag ループ、poll 30 Hz アクティブ /
  10 Hz アイドル、レンダ上限 20 fps、50 ms スロットル）
- エンコーダ 0 トグルは `button_state` 立ち上がり **OR** HW `short_press` ラッチ
  （poll 周期より短いタップを取りこぼさない）

### 10.3 フットスイッチ ×3
- `axi_footswitch_input`（`0x43D50000`）で FS1=FX トグル / FS2=プリセット次 / FS3=前

### 10.4 エクスプレッションペダル（ZOOM FP02M）
- Arduino A0 = **XADC VAUX1**（専用アナログピン E17/D18）を `xadc_wiz_a0`（`0x43D40000`）の
  レジスタ `0x244` から読み、Wah POSITION にマッピング
- キャリブレーション順序：heel（min raw）→ toe（max raw）→ sweep

### 10.5 入力 IP のレジスタマップ

自作の入力 IP は AXI-Lite スレーブとして以下のレジスタを公開します。バージョンレジスタで
**ビット不一致を検出**できるようにしてあります（誤ったビットで誤動作しない安全策）。

**`axi_encoder_input`（`0x43D10000`、EXPECTED_VERSION `0x00070001`）**

| オフセット | レジスタ | 内容 |
| --- | --- | --- |
| `0x00` | `STATUS` | rotate / short_press / long_press / sw_level フラグ（3 エンコーダ分、bit 8+i に short_press） |
| `0x04` | `DELTA_PACKED` | 3 つの signed int8 デルタ（enc0/1/2）をパック |
| `0x08`-`0x10` | `COUNT0/1/2` | 各エンコーダの絶対カウント |
| `0x14` | `BUTTON_STATE` | 押下状態 |
| `0x18` | `CONFIG` | debounce_ms / clear-on-read / sw_active_low（既定 `0x00010105` = debounce 5, clear-on-read, active-low） |
| `0x1C` | `CLEAR_EVENTS` | イベントラッチクリア |
| `0x20` | `VERSION` | IP バージョン |

**`axi_pmod_i2s2_status`（`0x43D20000`、EXPECTED_VERSION `0x00480001`）**

| オフセット | レジスタ | 内容 |
| --- | --- | --- |
| `0x00` | `VERSION` | IP バージョン（`0x00480001`、上位が fs=0x48=72→96k 系を示す） |
| `0x04` | `STATUS` | sdout_alive / bclk_seen / lrclk_seen など生存フラグ |
| `0x08` / `0x0C` | `FRAME` / `NONZERO` | フレームカウント / 非ゼロ検出 |
| `0x10` | `SDOUT_XCOUNT` | ADC SDOUT トランジション数 |
| `0x14` | `CLIP` | クリップカウント（入力過大の検出） |
| `0x18` / `0x1C` | `LAST_LEFT` / `LAST_RIGHT` | 直近サンプル |
| `0x20` / `0x24` | `PEAK_L` / `PEAK_R` | ピーク絶対値（`8388607` = フルスケール = クリップ） |
| `0x28` | `MODE` | 動作モード（0 tone / 1 loopback / 2 dsp / 3 mute、2bit） |
| `0x2C` | `CLEAR` | 統計クリア |

スモークテストはこれらを読み、`VERSION` 一致・`MODE=2`・`sdout_alive/bclk_seen/lrclk_seen=1` を
確認してから音響判定に進みます。`PEAK_L/R == 8388607` かつ `CLIP` 増加は**入力レベル過大**の
サインで、音作り判定の前に入力を絞る指標になります。

---

## 11. 制御アーキテクチャ

エンコーダ駆動のオーバーレイ書き込みは**すべて単一の翻訳層**
`audio_lab_pynq/encoder_effect_apply.py::EncoderEffectApplier` を通します。

- コンパクト v2 の `AppState` → `AudioLabOverlay` 書き込みを唯一翻訳できるオブジェクト
- 呼ぶのは `set_noise_suppressor_settings` / `set_compressor_settings` /
  `set_guitar_effects(**kwargs)` のみ。**生 GPIO 書き込みなし**、ショートカットなし
- `set_guitar_effects` 自体も 6 つの private ヘルパー（`_require_effect_gpios` /
  `_merge_cached_*` / `_write_effect_gpios` / `_refresh_cached_words` /
  `_route_effect_chain`）に分割（挙動・戻り値はバイト等価）

**パフォーマンス**：`self.<ip>` アクセスは PL サーバ IPC（~50 ms）を伴うため、IP ハンドルを
`__init__` で `__dict__` にキャッシュ（D76）。`set_guitar_effects` は ~940 ms → ~2.6 ms に短縮。

### 11.1 `AudioLabOverlay` Python API の表層

`audio_lab_pynq.AudioLabOverlay` がオーバーレイをロードし、全エフェクトへの高レベル
アクセサを提供します。主要メソッド群：

```python
# 一括適用（チェーン全体）
set_guitar_effects(sink=XbarSink.headphone, **kwargs)   # 全 GPIO を 1 回で更新
set_reverb(enabled, reverb, tone, mix, sink)

# エフェクト個別
set_distortion_settings(drive, tone, level, bias, tight, mix)
set_distortion_pedal(name, enabled, exclusive)          # ペダルマスク操作
set_distortion_pedals(**kwargs)
set_overdrive_settings(enabled, drive, tone, level), set_overdrive_model(model)
set_amp_model(name, sink, **overrides)
set_noise_suppressor_settings(threshold, decay, damp)
set_compressor_settings(threshold, ratio, response, makeup)
set_wah_settings(position | position_raw, q, volume, bias, enabled)
set_input_digital_volume(left, right)

# モデル/プリセット照会（クラスメソッド）
get_amp_model_names() / get_amp_model_labels()
get_overdrive_model_names() / get_overdrive_model_labels()
get_chain_preset_names() / get_chain_preset(name)

# バイト合成ヘルパー（純関数）
amp_model_drive_byte(idx, mode) = ((mode & 1) << 7) | (idx & 0x07)
makeup_to_u7(value), wah_word(position, q, volume, bias, enabled), set_byte/get_byte
```

設計上の要点：

- **GPIO 出力専用**のため `get_*` はキャッシュ値を返す。`set_guitar_effects` は内部で
  `_merge_cached_distortion_state` / `_merge_cached_noise_suppressor_state` でキャッシュを
  マージしてから `_write_effect_gpios` → `_refresh_cached_words` → `_route_effect_chain` と進む
- ペダルマスク bit2（RAT）を立てると `_route_effect_chain` が自動的に `gate_control` bit4 を
  立て、上流の本物 RAT 段を engage する（GUI の Distortion ノブも RAT にルート）
- `set_wah_settings` は `position` と `position_raw` の同時指定で `ValueError`（MANUAL と PEDAL の
  排他）
- 「PL ロード前の `pynq.MMIO` 読みはカーネルを殺す」ため、ビット確認は `pynq.PL.bitfile_name` を使う

---

## 12. ビルド・デプロイ・検証フロー

```
Clash ソース (LowPassFir.hs / AudioLab/Effects/*.hs)  ← DSP の唯一の真実
   → Clash で VHDL 生成（rm -rf vhdl/ で mtime トラップ回避、git status M を確認）
   → IP リパッケージ
   → Vivado でビットストリーム生成 (.bit / .hwh)
   → タイミングサマリ確認（WNS が前回ベースラインより著しく悪化したら不採用）
   → scripts/deploy_to_pynq.sh で実機へ（5 サイトの bit/hwh を md5 同期）
   → プログラム的スモークテスト（ADC HPF, Pmod VERSION/MODE, I2S クロック生存）
   → 実機試聴（ear-bench）で「合格」したらベースライン昇格
```

- **5 サイト同期**：bit/hwh はリポジトリ / `dist-packages/audio_lab_pynq` /
  `jupyter_notebooks/audio_lab` / `pynq/overlays/audio_lab` など複数の場所にコピーが
  存在し、デプロイ時に全箇所を md5 一致させる（一箇所だけ古いと別ビットがロードされる罠）
- **検証規律**：DSP に関わる変更は**必ず実機試聴で承認**してから採用済みベースラインに
  昇格。論理等価性 + タイミング MET だけでマージしない（D102-D106 でその過信が
  バイパス破壊を招いた教訓）
- **HDMI の注意**：Phase 6I の rgb2dvi PLL が VCO 下限（40 MHz）に居るため、同一セッションでの
  2 度目の `download=True` は PLL を外しうる。VTC GEN_ACTSZ を見て一致なら `download=False` で attach

### 12.1 実際のビルドコマンド

```bash
# Clash → VHDL → IP リパッケージ（hw/ip 配下）
make ip                      # = make -C hw/ip （clash + create_ip.tcl）

# Vivado でビットストリーム生成（hw/Pynq-Z2 配下）
make -C hw/Pynq-Z2           # vivado -mode batch -source create_project.tcl

# テスト
make python_tests            # = make -C tests python（pytest）

# 実機へデプロイ（5 サイト同期 + スモーク）
bash scripts/deploy_to_pynq.sh
```

`create_project.tcl` は `block_design.tcl`（ベース、編集禁止）を読んだあと、加算式の
integration スクリプトを **pmod → wah → xadc → footswitch → island** の順で source し、
各々が `ps7_0_axi_periph/NUM_MI` をバンプして新 IP を追加します。デプロイは `rsync` で
ステージし、ボード上の bit/hwh を **リポジトリ / `dist-packages/audio_lab_pynq` /
`jupyter_notebooks/audio_lab` / `pynq/overlays/audio_lab`** など全コピー場所に配って
md5 一致を取ります（一箇所でも古いと別ビットがロードされる罠への対策）。

> **落とし穴（実際に踏んだ）**：`make ip` は `component.xml` を rm すると `vhdl/` ディレクトリの
> mtime が上がり、**Clash VHDL 再生成を黙ってスキップ**することがある（＝「再ビルドした」つもりの
> ビットが古いロジックのまま）。対策は `rm -rf vhdl/LowPassFir` してから `git status` で
> `M`（変更）を目視確認すること。

---

