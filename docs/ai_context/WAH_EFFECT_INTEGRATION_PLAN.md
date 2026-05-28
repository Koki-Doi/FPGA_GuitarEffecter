# Wah effect 統合計画 (提案)

ブランチ: `feature/wah-effect`

ユーザ仕様 (修正版) を実装するための統合計画。実装に着手する前に、
GPIO 割当 / Vivado 統合方式 / Clash 配置 / Python API / GUI / encoder /
テスト範囲を明確化し、ユーザの承認を得る。

## 1. 配置 (DSP chain)

```
Noise Gate -> Compressor -> Wah -> Overdrive -> Distortion ->
RAT -> Pedals -> Amp -> Cab -> EQ -> Reverb
```

Clash 上は `compMakeupPipe` の直後、`odDriveMulPipe` の直前に
`wah*Pipe` 群を挿入する。所有ファイル: 新規
`hw/ip/clash/src/AudioLab/Effects/Wah.hs`。

## 2. 制御 (5 パラメータ)

| パラメータ | 範囲 | 役割 |
| --- | --- | --- |
| `wah_enabled` | bool | 区間 ON/OFF |
| `wah_position` | 0..255 (UI 0..100%) | フィルタ中心周波数 (将来 FP02M 入力源) |
| `wah_q` | 0..255 (UI 0..100) | 共振度 / 山の鋭さ |
| `wah_volume` | 0..255 (UI 0..100, 50=unity) | ON 時の出力ブースト/減衰 |
| `wah_bias` | 0..255 (UI 0..100, 50=中心) | 周波数レンジの低/高シフト |

UI には `SOURCE: MANUAL` 表示も追加する (FP02M 対応は今回未実装、
データ構造のみ拡張可能にしておく)。

## 3. GPIO 割当 (新規)

現状の空き byte は `axi_gpio_eq.ctrlD` と
`axi_gpio_noise_suppressor.ctrlD` の 2 byte のみで、Wah が必要とする
4 byte + enable 1 bit には足りない。`GPIO_CONTROL_MAP.md` の規則
「reserved byte を別効果に転用しない」「flag byte に効果固有ビットを
増やさない」より、Compressor (D14) と同じく **専用 GPIO** を立てる。

| 項目 | 値 |
| --- | --- |
| GPIO 名 | `axi_gpio_wah` |
| アドレス | `0x43D30000` (Compressor `0x43CD0000` の次) |
| `ctrlA` | `wah_position` (u8) |
| `ctrlB` | `wah_q` (u8) |
| `ctrlC` | `wah_volume` (u8, 128 ≈ unity) |
| `ctrlD[6:0]` | `wah_bias` (u7) |
| `ctrlD[7]` | `wah_enabled` (Compressor と同じ慣習) |

enable を flag byte (`gate_control.ctrlA`) に置かないのは Compressor
D14 と同じ理由 (`ctrlA` 8 bit はすべて既存効果で埋まっている)。

## 4. Vivado 統合方式 (block_design.tcl は触らない)

HDMI / Encoder / Pmod_I2S2 と同じく、**新規** `wah_integration.tcl` を
作成し `create_project.tcl` から `block_design.tcl` の後に source する。
`block_design.tcl` 本体は編集しない。

`wah_integration.tcl` がやること:

1. `ps7_0_axi_periph/NUM_MI` を `18` -> `19` に bump (M18 を空ける)。
2. `axi_gpio_wah` を `create_bd_cell` で追加し、`ALL_OUTPUTS=1` /
   `GPIO_WIDTH=32` / `IS_DUAL=0` に設定。
3. `ps7_0_axi_periph/M18_AXI` -> `axi_gpio_wah/S_AXI` を接続。
4. `axi_gpio_wah/gpio_io_o` -> `clash_lowpass_fir_0/wah_control` を接続。
5. clk / aresetn を共通の `FCLK_CLK0` / `rst_ps7_0_100M` へ繋ぐ。
6. `create_bd_addr_seg` でアドレス `0x43D30000` を割り当てる。

これは `encoder_integration.tcl` とほぼ同型の差分。

## 5. Clash topEntity ポート追加

`hw/ip/clash/src/LowPassFir.hs` に `wah_control :: Signal AudioDomain (BitVector 32)` を追加し、`fxPipeline` に渡す。
`AudioLab.Pipeline` は `wahControl` を受け取り、新規 `Wah.hs` の段に
渡す。

### Wah.hs (DSP)

State Variable Filter / resonant band-pass を使う仕様どおり。
擬似コード (Wah.hs 内で 4..5 register stage に分割):

```
posSmooth' = posSmooth + ((posTarget - posSmooth) >>> 3)   -- zipper 対策
f          = posToF(posSmooth', bias)
qFb        = qToQfb(qByte)                                 -- 0..qMax 制限
high       = input - low - qFb * band         -- stage1
band'      = band + (f * high)                -- stage2
low'       = low + (f * band')                -- stage3
wahOut     = applyVolume(band', volumeByte)   -- stage4 (saturating mul)
```

- 全ステージで `Wide` を `softClipK` / `satWide` でクランプし、Q 最大
  時の発振を防ぐ。
- enable bit が clear なら `frameOr` パターンで bit-exact bypass。
- `Nothing` cycle では state を保持。
- position -> f / bias -> range シフトの mapping は piecewise table
  (Float / Double 禁止、大規模テーブル禁止)。
- 状態 (posSmooth, low, band) は pipeline-level register として持つ。

### Wah を挿入する位置

```
compMakeupPipe -> wahPositionSmoothPipe -> wahHighPipe -> wahBandPipe ->
  wahLowPipe -> wahApplyPipe -> odDriveMulPipe ...
```

## 6. Python 層

- `audio_lab_pynq/control_maps.py`:
  - `wah_position_byte(value)` (0..255)
  - `wah_q_byte(value)` (0..100 -> 0..255)
  - `wah_volume_byte(value)` (0..100 -> 0..255, 50 → 128)
  - `wah_bias_byte(value)` (0..100 -> 0..127, 50 → 64)
  - `wah_word(position, q, volume, bias, enabled)`

- `audio_lab_pynq/effect_defaults.py`: `WAH_DEFAULTS = {
  enabled: False, position: 0, q: 50, volume: 50, bias: 50,
  source: 'manual' }`

- `audio_lab_pynq/AudioLabOverlay.py`:
  - `axi_gpio_wah` 属性
  - `_cached_wah_word = 0`
  - `_wah_state = dict(WAH_DEFAULTS)`
  - `set_wah_settings(**kwargs)` / `get_wah_settings()`
  - `set_guitar_effects(...)` に `wah_*` kwargs を追加 (defaults 互換)
  - 既存 API 完全互換 (全 kwargs に default あり)

## 7. GUI (compact-v2 800x480)

- `GUI/compact_v2/knobs.py`:
  - `EFFECTS` リストに `"Wah"` を追加 (位置は Compressor と Overdrive
    の間)
  - `EFFECT_KNOBS["Wah"] = [("POS", 0), ("Q", 50), ("VOL", 50),
    ("BIAS", 50)]` (4 knobs → 2x2 grid)
- `GUI/compact_v2/state.py`:
  - `AppState.all_knob_values["Wah"]` を初期化
- `GUI/compact_v2/renderer.py`:
  - SOURCE 表示は最初は MANUAL 固定の小ラベルとして header / fx panel
    のどこかに描画 (Reverb の MIX 表示と同様のスタイル)
- `GUI/compact_v2/hit_test.py`:
  - Wah を選択中の knob hit test に追加
- `GUI/pynq_multi_fx_gui.py` は薄い shim なので変更最小限。

## 8. Encoder (live apply)

`audio_lab_pynq/encoder_effect_apply.py::EncoderEffectApplier` に Wah
対応を追加:

- AppState の Wah knob 値 (POS / Q / VOL / BIAS) を
  `set_wah_settings(...)` 呼び出しに変換する `_apply_wah()`
- enable / disable は AppState の `effect_on["Wah"]` を反映
- 既存制約どおり raw GPIO write は禁止。`set_wah_settings` のみ使う。
- 既存 throttle (50 ms) と短押し latch ロジックは変更しない。

`audio_lab_pynq/encoder_ui.py` の effect 選択リストにも Wah が並ぶ
ようにする。

## 9. HDMI state mirror

`audio_lab_pynq/hdmi_state/` 配下にも Wah 用の per-effect ファイル
(label / knob 名 / category) を追加する必要があれば最低限の更新を
行う (現在の構造で chain order だけ知ればよい場合は触らない)。

## 10. テスト

- `tests/test_overlay_controls.py`:
  - `set_guitar_effects` 既存 kwargs 後方互換性
  - `wah_enabled=False` がデフォルト
  - all_off bypass の word 値が崩れない
  - position 0/64/128/192/255, q 0/50/100, volume 0/50/100, bias
    0/50/100 が正しく pack される
- 新規 `tests/test_wah_pack.py` (snapshot test)
- AppState の Wah knob round-trip
- encoder applier の Wah live-apply round-trip

DSP テストは Clash モジュール側で `clashi` REPL での簡易シミュレーション
(impulse / sine / DC) で実施可能だが、本格的な周波数応答は実機 +
オシロ / FFT で確認する。

## 11. ビルド / デプロイ

1. Clash regen (`clash --vhdl`)
2. IP repackage
3. Vivado batch build (`bash hw/Pynq-Z2/...`)
4. timing 確認: WNS が D71.2 ベースライン (-9.413 ns) から有意に悪化
   していない (Cab.hs と独立な追加なので大きな悪化は想定外だが、
   register stage 追加で多少の WNS 改善 / 悪化が起きうる)
5. 5 箇所 bit/hwh sync
6. `scripts/deploy_to_pynq.sh`
7. `scripts/diagnose_pmod_loopback.py` で all_off bypass の QUANT/STAIR
   が出ないことを確認
8. 実機: bench audition (all_off / Wah OFF / Wah ON sweep)

## 12. 影響しないもの (boundary)

- `hw/Pynq-Z2/block_design.tcl` は触らない。
- 既存 GPIO のアドレス / 名前 / `ctrlA..ctrlD` semantics は変更しない。
- 既存 Clash 効果 (NS / Compressor / OD / Dist / Pedals / Amp / Cab /
  EQ / Reverb) のロジックは変更しない。
- Pmod_I2S2 RTL / HDMI / Encoder の RTL も変更しない。
- 既存 notebook / chain preset は default で `wah_enabled=False` なら
  動作不変。

## 13. ロールバック

何か想定外があれば、`feature/wah-effect` ブランチを master に
merge せず破棄するだけで戻せる。bit/hwh の master 復旧は
`git checkout master -- hw/Pynq-Z2/bitstreams/` + 5 箇所 sync で OK。

## 14. ユーザに確認したいこと

1. 専用 GPIO `axi_gpio_wah @ 0x43D30000` の新設 (= `block_design.tcl`
   は触らないが、新規 `wah_integration.tcl` を `create_project.tcl`
   から source する形) を進めて良いか。
2. このスコープ全部 (Clash + Vivado build + Python + GUI + encoder
   + tests + deploy) を一気にやるか、Python + GUI reservation
   (no-op Clash, wah_enabled=False default) のみ先行して、Vivado build
   と Clash 実装を後続フェーズに分けるか。
3. `EFFECTS` リスト中の Wah の挿入位置は Compressor と Overdrive の間
   で確定して良いか (chain 順と一致)。
