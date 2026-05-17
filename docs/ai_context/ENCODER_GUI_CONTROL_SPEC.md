# Encoder + GUI control spec (Phase 7A planning)

3 個のロータリーエンコーダー (各 A / B / SW、押しスイッチ付) で
HDMI GUI 全機能を notebook なしに操作するための仕様。

**Phase 7A の時点では実装しない**。アーキテクチャ / 操作仕様 /
Python driver 案 / 将来の AXI IP register map 案を記録するのみ。

関連:
- `docs/ai_context/IO_PIN_RESERVATION.md` (encoder ピン予約)
- `docs/ai_context/EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md` (外付け audio 設計)
- `docs/ai_context/CURRENT_STATE.md` / `DECISIONS.md` (D30)
- 既存 GUI: `GUI/compact_v2/` (renderer / state / hit_test)
- 既存 state mirror: `audio_lab_pynq/hdmi_state/`

---

## 1. 推奨入力アーキテクチャ

```
Encoder pins (A / B / SW)
  ↓
[2-stage synchronizer]        ← PL fabric
  ↓
[debounce counter]            ← PL fabric
  ↓
[quadrature decoder FSM]      ← PL fabric
  ↓
[delta accumulator + event latch] ← PL fabric
  ↓
[AXI-Lite or AXI GPIO input register]
  ↓
[Python driver: encoder_ui.py]   ← PS side
  ↓
[AppState / HdmiEffectStateMirror]
  ↓
[HDMI GUI update + DSP / overlay control]
```

### 比較

| 案 | 概要 | 評価 |
| --- | --- | --- |
| **A.** Python polling で A / B / SW を直接読む | PS から GPIO 読みでチャタリング / quadrature 判定 | **NG**. polling 周期が遅すぎて取りこぼし。debounce も不安定。CPU 負荷も増える。 |
| **B.** AXI GPIO input で A / B / SW 生値を読む | A / B / SW を AXI GPIO input にして PS で raw 読み | A よりはマシだが、debounce / quadrature 判定が PS 側のままで、依然取りこぼしと CPU 負荷の問題。 |
| **C.** PL 側で debounce + quadrature decode + delta / event 化 | PS は delta + event のみ読む | **推奨**. PL fabric が小さくて済み、PS は安定した delta を見るだけ。 |

### 結論: **C を採用** (`DECISIONS.md` D30)

理由:
- Python / Jupyter polling は確実に取りこぼす (encoder の典型回転速度
  は数百 pulse/s 以上、PS polling は数十 Hz 程度しか出ない)
- debounce を PS でやるとボタン応答が遅れる + ノイズで誤動作
- PL fabric は 2-stage sync + debounce counter + 4-state FSM 程度で
  encoder 1 個あたり ~ 数十 LUT で済む
- PS 側 (Python) は周期的に delta / event レジスタを read するだけで良い
- GUI 更新周期 (30 ~ 60 Hz) と入力検出周期 (PL clock、~ MHz) を完全分離できる
- 既存 DSP 経路 (Clash) と干渉しない (別の小さな HDL モジュール
  または小さな Clash module)

---

## 2. GUI 操作仕様 (encoder マッピング)

### 2.1 ペダルボード的役割割当

| Encoder | Rotate | Push short | Push long |
| --- | --- | --- | --- |
| **Encoder 1** | `selected_fx` を変更 (8 effects 間を循環) | `selected_fx` の ON / OFF 切替 | safe bypass (全 ON/OFF) |
| **Encoder 2** | `selected_fx` 内の parameter / model selection を変更 | model dropdown / parameter group 切替 | preset mode / model mode 切替 |
| **Encoder 3** | selected parameter の値を変更 | 決定 / apply (`apply_pending` 反映) | preset save / reset current parameter |

### 2.2 focus state (GUI / AppState 追加項目)

新規 `AppState` field (Phase 7G で実装):

```python
# GUI/compact_v2/state.py に追加予定
focus_effect_index: int        # 0..7 (EFFECTS index)
focus_param_index: int         # 選択中エフェクト内の parameter index (0..N-1)
edit_mode: bool                # True なら encoder3 で値変更中
model_select_mode: bool        # True なら encoder2 で model dropdown 操作中
last_encoder_event: dict | None  # 直近イベント (描画 hint 用)
value_dirty: bool              # 未 apply の変更あり
apply_pending: bool            # apply 待ち
last_control_source: str       # "notebook" / "encoder"
```

### 2.3 描画要件 (renderer 側)

`GUI/compact_v2/renderer.py` に Phase 7G で追加する表示要素:

- selected effect highlight (現在の `selected_fx` を強調表示、既存)
- **focus effect highlight** (encoder1 の現在位置、`selected_fx` と別)
- **focus parameter highlight** (encoder で選択中の knob を太線で囲む等)
- **edit mode indicator** (`edit_mode` が True のとき特殊カーソル)
- **dirty / apply pending indicator** (`value_dirty` / `apply_pending`)
- **switch press feedback** (短押し / 長押しを視覚的に表現)
- **last_control_source** 表示 (右下に小さく `notebook` / `encoder`)

### 2.4 model dropdown 表示条件 (既存維持)

Phase 6H 仕様 (`DECISIONS.md` D24) のまま維持:

| Effect | model dropdown 表示 |
| --- | --- |
| PEDAL 系 (`Overdrive` / `Distortion`) | pedal model dropdown 表示 |
| `Amp Sim` | amp model dropdown 表示 |
| `Cab IR` | cab model dropdown 表示 |
| `Reverb` / `EQ` / `Compressor` / `Noise Sup` / preset / safe bypass | **非表示** |

encoder UI は上記表示条件を尊重する。model dropdown 非表示の effect
では encoder2 短押しの `model_select_mode` トグルは無効化する
(あるいは `parameter group` 切替のみに使う)。

### 2.5 既存 GUI への変更方針 (Phase 7G で実装)

- `GUI/compact_v2/state.py` に focus state を追加
- `GUI/compact_v2/renderer.py` に focus 表示 / dirty 表示 / press feedback を追加
- `GUI/compact_v2/hit_test.py` は **マウス / タッチ用の既存ロジックを維持**。
  encoder 経由の入力はそもそも hit test 不要なので別経路。
- `GUI/pynq_multi_fx_gui.py` は **shim のまま維持** (`DECISIONS.md` D26)
- `audio_lab_pynq/hdmi_effect_state_mirror.py` も shim のまま維持
- 状態の **真の所有者** は `AppState` (= `GUI/compact_v2/state.py`)、
  mirror は反映先のみ

### 2.6 notebook と encoder の競合方針

- notebook から `AudioLabOverlay.set_*` API を呼んだ場合: `last_control_source = "notebook"` を set
- encoder 操作を検出した場合: `last_control_source = "encoder"` を set
- 競合時 (notebook が apply 中に encoder が同じ effect を変更等): **後勝ち** とする (シンプル原則)
- ただし `apply_pending` 中の encoder 値変更は notebook を上書きしない
  (`value_dirty` で示し、ユーザが apply するまで反映保留)

---

## 3. Python driver 仕様 (将来追加)

候補ファイル (Phase 7G で実装):
- `audio_lab_pynq/encoder_ui.py` (高位 API、AppState 反映)
- `audio_lab_pynq/encoder_input.py` (低位 driver、AXI register アクセス)

### 3.1 公開 API 案

```python
# audio_lab_pynq/encoder_input.py
class EncoderInput:
    """Low-level driver over the encoder PL IP at 0x43CE0000 (TBD)."""

    def __init__(self, overlay):
        self._mmio = overlay.encoder_ip.mmio  # or AXI GPIO input

    def read_status(self) -> int:
        """Read STATUS register (event bits + button events)."""

    def read_delta_packed(self) -> Tuple[int, int, int]:
        """Read DELTA_PACKED register and return (d0, d1, d2) as signed int8."""

    def read_counts(self) -> Tuple[int, int, int]:
        """Read absolute COUNT0..2."""

    def read_button_state(self) -> int:
        """Read BUTTON_STATE register (raw debounced switch level)."""

    def write_config(self, value: int) -> None:
        """Write CONFIG (debounce time, accel enable, invert, clear-on-read)."""

    def clear_events(self, mask: int) -> None:
        """Explicit event clear (when clear-on-read is disabled)."""


# audio_lab_pynq/encoder_ui.py
class EncoderUiController:
    """Translate raw encoder events into AppState / overlay mutations."""

    def __init__(self, input_driver: EncoderInput, *, debounce_ms: int = 5):
        ...

    def poll(self) -> None:
        """Read one tick of events from PL and queue them."""

    def get_events(self) -> List[EncoderEvent]:
        """Drain the internal event queue (rotate, short_press, long_press)."""

    def apply_to_state(self, state: "AppState") -> None:
        """Mutate AppState based on queued events. Sets last_control_source."""

    def apply_to_overlay(self, overlay, mirror) -> None:
        """Push parameter changes to the overlay + mirror (debounced)."""
```

### 3.2 イベント型

```python
@dataclass
class EncoderEvent:
    kind: Literal["rotate", "short_press", "long_press", "release"]
    encoder_id: int    # 0, 1, 2
    delta: int = 0     # rotate only, signed
    timestamp: float = 0.0
```

### 3.3 GUI / overlay 反映先

- `AppState.selected_fx`
- `AppState.focus_param_index`
- `AppState.edit_mode`
- `AppState.selected_model_category`
- `AppState.all_knob_values[effect_name][param_index]`
- `AppState.last_control_source`
- `HdmiEffectStateMirror.update_from_appstate(...)` (既存 path)
- `AudioLabOverlay.set_*` API (確定値のみ)

### 3.4 注意 / 設計原則

- **encoder 回転ごとに GPIO write しない**。
  encoder の典型は 1 detent = 4 quadrature edge = ~ 24 detent/turn。
  `apply_pending` を立て、apply timing (短押し / 一定周期) で DSP に反映する。
- UI 表示と DSP 反映のズレを避けるため、値変更は **mirror を唯一の経路** にする
- `apply_to_overlay` は **debounce** (例: 連続変更時は 50 ms 間隔で OR レート制限)
- `last_control_source` を必ず記録し、HDMI GUI / debug log で見えるようにする
- thread 安全性: poll は GUI loop thread から呼ぶか、PL の event 用 IRQ を将来 hook するか、Phase 7G で確定する
- Phase 7A で API シグネチャを確定する義務はない (実装時に整える)

---

## 4. 将来の encoder PL IP register map 案

新規 AXI IP の base address は GPIO map と衝突しないよう、現状の
`axi_gpio_*` 群 (0x43C30000 ~ 0x43CD0000) の **次** に置く:

候補 base: **`0x43CE0000`** (Phase 7F で確定)

| Offset | Name | Bits | Meaning |
| --- | --- | --- | --- |
| `0x00` | `STATUS` | [2:0] event flags (enc0/1/2_event), [10:8] sw_short events, [18:16] sw_long events, [26:24] sw_release events | clear-on-read or explicit clear via `CLEAR_EVENTS` |
| `0x04` | `DELTA_PACKED` | [7:0] enc0_delta (s8), [15:8] enc1_delta (s8), [23:16] enc2_delta (s8) | 直近 polling 期間内の累積回転。read で 0 リセット |
| `0x08` | `COUNT0` | [31:0] (s32 absolute counter, encoder 0) | 累積 detent (overflow wrap) |
| `0x0C` | `COUNT1` | [31:0] (s32 absolute counter, encoder 1) | |
| `0x10` | `COUNT2` | [31:0] (s32 absolute counter, encoder 2) | |
| `0x14` | `BUTTON_STATE` | [2:0] debounced raw switch level (1 = pressed) | polling 用 |
| `0x18` | `CONFIG` | [7:0] debounce_ms (1..255), [8] accel_enable, [9] invert_a, [10] invert_b, [11] invert_sw, [12] clear_on_read_enable, [13] long_press_enable | |
| `0x1C` | `CLEAR_EVENTS` | write [2:0] / [10:8] / [18:16] / [26:24] = 1 to clear corresponding bit in `STATUS` | clear_on_read 無効時に使う |

### 4.1 PL 側仕様

- 2-stage synchronizer (audio clock domain → PS AXI domain crossover)
- debounce counter (`CONFIG.debounce_ms`)
- quadrature state machine (Gray code FSM、A/B の遷移で +1 / -1)
- signed delta accumulator (per encoder)
- absolute count register (per encoder)
- event latch (rotate / short / long / release)
- clear-on-read **または** explicit clear via `CLEAR_EVENTS`
- optional interrupt 出力 (Phase 7G 以降で検討、最初は polling で良い)
- short_press / long_press 判定:
  - press detected → start timer
  - release before `long_press_ms` → short_press event
  - timer expires → long_press event (release を待たない)

### 4.2 既存 GPIO 設計との分離原則 (重要)

- 既存 `axi_gpio_*` (`0x43C30000` ~ `0x43CD0000`) には **混ぜない**
- encoder は **新規 AXI IP** または **新規 AXI GPIO input** を使う
- 既存 `ctrlA` / `ctrlB` / `ctrlC` / `ctrlD` 構造 (4 byte unpacking) は encoder には流用しない (event bit / signed delta が混在するため)
- `block_design.tcl` 変更は Phase 7F (encoder IP 追加時) でユーザ承認の上で行う
- これは `axi_gpio_noise_suppressor` (`0x43CC0000`, `DECISIONS.md` D11) / `axi_gpio_compressor` (`0x43CD0000`, `DECISIONS.md` D14) と同じ "個別承認の例外" 扱いになる

### 4.3 リソース見積 (粗い見積、Phase 7F で実測)

- encoder 1 個あたり: 2-sync (~6 FF) + debounce counter (~16 FF) + FSM (~10 LUT) + delta/count (~40 FF)
- 3 個合計: ~150 LUT、~200 FF オーダー (現状空き枠で問題ない)
- AXI-Lite slave: 別途 ~ 100 LUT

---

## 5. Phase 別実装計画 (Phase 7F / 7G 詳細)

### Phase 7F (PL 側)

- ロータリーエンコーダー decode HDL / Clash モジュール実装
- AXI-Lite slave (or AXI GPIO input) 接続
- `block_design.tcl` 修正 (encoder IP 追加、address segment 設定)
- XDC 更新 (encoder ピン定義、`PULLUP` 設定)
- bit / hwh build + timing summary check (WNS 悪化に注意)
- 簡単な debug script で raw delta が出るか確認

### Phase 7G (PS 側)

- `audio_lab_pynq/encoder_input.py` 実装 (low-level driver)
- `audio_lab_pynq/encoder_ui.py` 実装 (high-level controller)
- `GUI/compact_v2/state.py` に focus state 追加
- `GUI/compact_v2/renderer.py` に focus / dirty / press feedback 描画追加
- `HdmiGui.ipynb` を encoder 駆動でも動くように更新 (notebook と encoder 両対応)
- 1 つの notebook cell で `EncoderUiController.poll()` + `apply_to_state()` + `apply_to_overlay()` を呼ぶ loop
- notebook-less control loop prototype (encoder のみで全機能操作)

### Phase 7H (筐体)

- enclosure / front panel 配線
- encoder の機械固定 / 操作感調整
- noise / grounding レビュー
- 外付け codec (PCM1808 / PCM5102) との同居検証

---

## 6. Phase 7A での状態 (本フェーズの成果物)

- 仕様・設計のみ
- 実装 (HDL / Python / GUI) は **行わない**
- `block_design.tcl` / `audio_lab.xdc` / bit / hwh は **未変更**
- 既存 GPIO control map は **未変更**
- HDMI baseline (SVGA 800x600 @ 40 MHz) は **維持**
- DSP / Clash は **未変更**
- 本ドキュメント + `IO_PIN_RESERVATION.md` + `EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md` の 3 本 + `CURRENT_STATE.md` / `DECISIONS.md` / `RESUME_PROMPTS.md` の追記のみ
