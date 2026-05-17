# Encoder + GUI control spec (Phase 7A / 7B planning, Phase 7F/7G implementation)

3 個のロータリーエンコーダー (各 `CLK` / `DT` / `SW`、押しスイッチ付) で
HDMI GUI 全機能を notebook なしに操作するための仕様。

Phase 7A / 7B ではアーキテクチャ / 操作仕様 / Python driver 案 /
AXI IP register map 案を記録した。Phase 7F / 7G でこの方針に沿って
`axi_encoder_input`、Python driver、compact-v2 GUI control を実装済み。
確定 register map は `ENCODER_INPUT_MAP.md`、実装結果は
`ENCODER_INPUT_IMPLEMENTATION.md` を参照。

## Module pin labels (Phase 7B 確定)

実モジュールのシルクは 5 pin: **`CLK` / `DT` / `SW` / `+` / `GND`**
(`DECISIONS.md` D31)。

| シルク | 役割 | 内部 quadrature 表記 |
| --- | --- | --- |
| `CLK` | quadrature **A 相** (回転で `GND` open/close) | `A` |
| `DT`  | quadrature **B 相** (`CLK` と 90 度位相差) | `B` |
| `SW`  | push switch (押下で `GND` 短絡、active-low) | -- |
| `+`   | 電源 (**3.3V 専用**、`5V` 禁止) | power |
| `GND` | グランド | ground |

- 外部配線指示 / XDC 候補 / 物理表は **`CLK` / `DT` / `SW` 表記** を使う
- PL 内部 (Clash / HDL / register layout) では `A` (= CLK) / `B` (= DT) と
  呼んでもよい
- Python / API 公開名は **semantic** (`rotate` / `short_press` /
  `long_press`) を優先する
- `+` を 5V に繋がない (モジュール基板上の pull-up が `+` 経由で `CLK` /
  `DT` / `SW` を 5V 化し、PL pin を直撃して壊す可能性あり、
  `DECISIONS.md` D31)

関連:
- `docs/ai_context/IO_PIN_RESERVATION.md` (encoder ピン予約 + candidate package pin)
- `docs/ai_context/EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md` (外付け audio 設計)
- `docs/ai_context/CURRENT_STATE.md` / `DECISIONS.md` (D30 / D31 / D32 /
  D33 / D34 / D35)
- 既存 GUI: `GUI/compact_v2/` (renderer / state / hit_test)
- 既存 state mirror: `audio_lab_pynq/hdmi_state/`

---

## 1. 推奨入力アーキテクチャ

```
Encoder pins (CLK / DT / SW)
  ↓
[2-stage synchronizer]        ← PL fabric
  ↓
[debounce counter]            ← PL fabric
  ↓
[quadrature decoder FSM (CLK=A, DT=B)] ← PL fabric
  ↓
[delta accumulator + event latch] ← PL fabric
  ↓
[AXI-Lite custom IP register]
  ↓
[Python driver: encoder_input.py / encoder_ui.py] ← PS side
  ↓
[AppState / AudioLabGuiBridge or test mirror]
  ↓
[HDMI GUI update + DSP / overlay control]
```

### 比較

| 案 | 概要 | 評価 |
| --- | --- | --- |
| **A.** Python polling で `CLK` / `DT` / `SW` を直接読む | PS から GPIO 読みでチャタリング / quadrature 判定 | **NG**. polling 周期が遅すぎて取りこぼし。debounce も不安定。CPU 負荷も増える。 |
| **B.** AXI GPIO input で `CLK` / `DT` / `SW` 生値を読む | AXI GPIO input にして PS で raw 読み | A よりはマシだが、debounce / quadrature 判定が PS 側のままで、依然取りこぼしと CPU 負荷の問題。 |
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
| **Encoder 1** | `selected_fx` を変更 (8 effects 間を循環) | `selected_fx` の ON / OFF 切替 + live apply | safe bypass (全 ON/OFF) + live apply |
| **Encoder 2** | `selected_fx` 内の parameter / model selection を変更 (Distortion で skip\_rat=True の時は RAT slot を飛ばす) | PEDAL / AMP / CAB は `model_select_mode` toggle、それ以外は `edit_mode` toggle | reserved (`model_select_mode` を解除) |
| **Encoder 3** | selected parameter の値を変更 (live\_apply=True なら 100 ms throttle で `EncoderEffectApplier` 経由 apply) | 決定 / 強制 apply (`apply_pending` 反映、live\_apply に関係なく force) | 選択中 knob を GUI default に戻す + apply |

### 2.1a GUI-first live apply (Phase 7G+)

- `audio_lab_pynq/encoder_effect_apply.py` の `EncoderEffectApplier` が
  AppState → `AudioLabOverlay` public API の唯一の経路。raw GPIO は
  書かない。
- 使う overlay API は `set_noise_suppressor_settings`、
  `set_compressor_settings`、`set_guitar_effects(**kwargs)` の 3 つだけ。
  pedal 選択は `set_distortion_settings` ではなく
  `set_guitar_effects(distortion_pedal_mask=...)` を使う (cached 状態と
  整合)。
- throttle は `apply_interval_s` (default 100 ms)。連続回転で flooding
  しない。encoder 3 short press は throttle を bypass して force apply。
- RAT (`distortion_pedal_mask` bit 2) は `skip_rat=True` (default) の
  時に encoder cycle / live apply の対象から除外。Clash stage と
  `HdmiEffectStateMirror.rat()` は手付かず。
- EQ knob は GUI 0..100 → overlay 0..200 (50 == unity) に変換。
- Cab `MODEL` knob は `AppState.cab_model_idx` (0..2) で上書き。
- 例外は `last_apply_ok=False` / `last_apply_message=...` に記録するだけ
  で loop は落とさない。GUI status strip と resource print に反映される。

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

## 3. Python driver 仕様 (Phase 7F/7G 実装)

実装済みファイル:
- `audio_lab_pynq/encoder_ui.py` (高位 API、AppState 反映)
- `audio_lab_pynq/encoder_input.py` (低位 driver、AXI register アクセス)

### 3.1 公開 API 案

```python
# audio_lab_pynq/encoder_input.py
class EncoderInput:
    """Low-level driver over the encoder PL IP.
    Base address is 0x43D10000. 0x43CE0000 / 0x43CF0000 are forbidden
    (HDMI VDMA / VTC, DECISIONS.md D32)."""

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
- `GUI/audio_lab_gui_bridge.py` (live overlay path)
- `HdmiEffectStateMirror.update_from_appstate(...)` or `update(...)`
  (dry-run / test path)
- `AudioLabOverlay.set_*` API (確定値のみ)

### 3.4 注意 / 設計原則

- **encoder 回転ごとに GPIO write しない**。
  encoder の典型は 1 detent = 4 quadrature edge = ~ 24 detent/turn。
  `apply_pending` を立て、apply timing (短押し / 一定周期) で DSP に反映する。
- UI 表示と DSP 反映のズレを避けるため、live 反映は
  `AudioLabGuiBridge` 経由で `AudioLabOverlay.set_*` public API に流す
- `apply()` は短押し / apply 操作でのみ反映し、回転イベントごとの raw GPIO
  write はしない
- `last_control_source` を必ず記録し、HDMI GUI / debug log で見えるようにする
- thread 安全性: poll は GUI loop thread から呼ぶか、PL の event 用 IRQ を将来 hook するか、Phase 7G で確定する
- Phase 7A で API シグネチャを確定する義務はない (実装時に整える)

---

## 4. Encoder PL IP register map (Phase 7F/7G 確定)

確定版の詳細は `ENCODER_INPUT_MAP.md`。新規 AXI IP の base address は
**`0x43D10000`** (`DECISIONS.md` D32 / D33)。

**禁止 base address**:
- `0x43CE0000` — 既存 `axi_vdma_hdmi` (HDMI フレームバッファ VDMA、
  `DECISIONS.md` D23 / `HDMI_GUI_INTEGRATION_PLAN.md`)
- `0x43CF0000` — 既存 `v_tc_hdmi` (HDMI Video Timing Controller)
- `0x43D00000` — future HDMI / rgb2dvi control surface reserved range

選定結果:
- HWH で `enc_in_0` / `axi_encoder_input` が
  `0x43D10000..0x43D1FFFF` に出ることを確認済み
- HDMI VDMA/VTC と既存 effect GPIO addresses は unchanged
- `GPIO_CONTROL_MAP.md` には混ぜず、input IP 専用 ledger
  (`ENCODER_INPUT_MAP.md`) として管理する

| Offset | Name | Bits | Meaning |
| --- | --- | --- | --- |
| `0x00` | `STATUS` | [2:0] rotate_event, [10:8] sw_short, [18:16] sw_long, [26:24] sw_level | clear-on-read or explicit clear via `CLEAR_EVENTS` |
| `0x04` | `DELTA_PACKED` | [7:0] enc0_delta (s8), [15:8] enc1_delta (s8), [23:16] enc2_delta (s8) | 直近 polling 期間内の累積回転。read で 0 リセット |
| `0x08` | `COUNT0` | [31:0] (s32 absolute counter, encoder 0) | 累積 detent (overflow wrap) |
| `0x0C` | `COUNT1` | [31:0] (s32 absolute counter, encoder 1) | |
| `0x10` | `COUNT2` | [31:0] (s32 absolute counter, encoder 2) | |
| `0x14` | `BUTTON_STATE` | [2:0] debounced raw switch level (1 = pressed) | polling 用 |
| `0x18` | `CONFIG` | [7:0] debounce_ms, [8] clear_on_read_enable, [9] acceleration_enable (reserved), [12:10] encN_reverse_direction, [15:13] encN_clk_dt_swap, [16] sw_active_low | default `0x00010105` |
| `0x1C` | `CLEAR_EVENTS` | write [2:0] / [10:8] / [18:16] = 1 to clear corresponding event bit | clear_on_read 無効時に使う |
| `0x20` | `VERSION` | `0x00070001` | RTL version |

**CONFIG bit 詳細**:
- `sw_active_low`: default 1。`SW` が押下で `GND` 短絡する典型構成
- `clk_dt_swap`: `CLK` と `DT` を **PL 内部で入れ替え**。物理配線で
  AB が逆になった場合に rewiring せず補正
- `reverse_direction`: quadrature decoder 出力の符号を反転。CW / CCW
  方向が GUI の期待方向と逆になった場合に補正

これらは **実モジュールごとに方向や極性が異なる可能性** がある
ため、PCB / 配線を物理的に直すよりレジスタで補正する方が早い
(`DECISIONS.md` D31 / D32)。

### 4.1 PL 側仕様

- 2-stage synchronizer (audio clock domain → PS AXI domain crossover)
- debounce counter (`CONFIG.debounce_ms`)
- quadrature state machine (Gray code FSM、A/B の遷移で +1 / -1)
- signed delta accumulator (per encoder)
- absolute count register (per encoder)
- event latch (rotate / short / long) + debounced button state
- clear-on-read **または** explicit clear via `CLEAR_EVENTS`
- optional interrupt 出力は未実装。最初は polling。
- short_press / long_press 判定:
  - press detected → start timer
  - release before `long_press_ms` → short_press event
  - timer expires → long_press event (release を待たない)

### 4.2 既存 GPIO 設計との分離原則 (重要)

- 既存 `axi_gpio_*` (`0x43C30000` ~ `0x43CD0000`) には **混ぜない**
- encoder は **新規 AXI IP** (`axi_encoder_input`) を使う
- 既存 `ctrlA` / `ctrlB` / `ctrlC` / `ctrlD` 構造 (4 byte unpacking) は encoder には流用しない (event bit / signed delta が混在するため)
- `block_design.tcl` 本体は変更せず、`encoder_integration.tcl` を
  `create_project.tcl` から source する (HDMI integration と同じ増分方式)

### 4.3 リソース実測

- Phase 7F/7G local build after place: Slice LUTs `19095 (35.89%)`,
  Slice Registers `21259 (19.98%)`, Block RAM Tile `9 (6.43%)`,
  DSPs `83 (37.73%)`
- Timing: WNS `-8.395 ns`, TNS `-6609.224 ns`, WHS `+0.052 ns`,
  THS `0.000 ns`

---

## 5. Phase 別実装計画 (Phase 7F / 7G 詳細)

### Phase 7F (PL 側)

- ロータリーエンコーダー decode Verilog module 実装済み
- AXI-Lite slave 接続済み (`enc_in_0`, M17, `0x43D10000`)
- `encoder_integration.tcl` 追加済み (`block_design.tcl` 本体は未変更)
- XDC 更新済み (encoder 9 pin、`PULLUP` は未設定)
- bit / hwh local build + timing summary check 済み
- 物理 encoder smoke は未配線のため未実施

### Phase 7G (PS 側)

- `audio_lab_pynq/encoder_input.py` 実装済み (low-level driver)
- `audio_lab_pynq/encoder_ui.py` 実装済み (high-level controller)
- `GUI/compact_v2/state.py` に focus state 追加済み
- `GUI/compact_v2/renderer.py` に status strip 追加済み
- `scripts/run_encoder_hdmi_gui.py` を追加済み (notebook-less loop)
- `scripts/test_encoder_input.py` /
  `scripts/test_hdmi_encoder_gui_control.py` を追加済み

### Phase 7H (筐体)

- enclosure / front panel 配線
- encoder の機械固定 / 操作感調整
- noise / grounding レビュー
- 外付け codec (PCM1808 / PCM5102) との同居検証

---

## 6. Phase 状態

### Phase 7A / 7B

- 仕様・設計のみ
- 実装 (HDL / Python / GUI) は **行わない**
- `block_design.tcl` / `audio_lab.xdc` / bit / hwh は **未変更**
- 既存 GPIO control map は **未変更**
- HDMI baseline (SVGA 800x600 @ 40 MHz) は **維持**
- DSP / Clash は **未変更**
- 本ドキュメント + `IO_PIN_RESERVATION.md` + `EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md` の 3 本 + `CURRENT_STATE.md` / `DECISIONS.md` / `RESUME_PROMPTS.md` の追記のみ
- Phase 7B: 信号名を `CLK` / `DT` / `SW` 表記に正し、encoder IP base
  address を TBD に戻し (`0x43CE0000` / `0x43CF0000` 禁止)、CONFIG に
  `invert_clk` / `invert_dt` / `clk_dt_swap` / `reverse_direction` /
  `sw_active_low` を追加 (`DECISIONS.md` D31 / D32)

### Phase 7F / 7G

- 実装済み: PL IP / XDC / Tcl integration / Python low-level driver /
  high-level GUI controller / compact-v2 state + renderer strip /
  standalone runner / smoke scripts / offline unit tests
- local bit/hwh build 済み、PYNQ deploy は未実施
- 物理 encoder smoke は未配線のため未実施。未配線状態の ip_dict 確認や
  scripted events は standalone 操作成功の代替にしない (`DECISIONS.md` D35)

---

## 7. Phase 7B encoder module 物理確認チェックリスト

実モジュール (CLK / DT / SW / + / GND の 5 pin タイプ) を入手したら、
以下を確認した上で Phase 7F の XDC / IP 実装に進む。

電源 / 信号レベル:
- [ ] `+` の許容電圧範囲 (商品ページ / 仕様表)
- [ ] **`+` を 3.3V に繋いだ場合に動作するか** (5V に繋がない)
- [ ] `CLK` / `DT` / `SW` 出力レベル (3.3V tolerant か)
- [ ] 基板上 pull-up 抵抗の有無と抵抗値 R (`+` → `CLK` / `DT` / `SW`)
- [ ] pull-up が `+` ピン経由か独立 (5V 化リスクの最終確認)
- [ ] 3.3V で pull-up が弱い場合の外付け強化 (10 kΩ → 3.3V)

メカニカル動作:
- [ ] 回転時に `CLK` が `GND` に open/close するか (open contact)
- [ ] 回転時に `DT` が `GND` に open/close するか (90 度位相差)
- [ ] 押下時に `SW` が `GND` に短絡するか (active-low)
- [ ] 1 回転あたり detent 数
- [ ] 1 detent あたり quadrature edge 数 (典型 4 edge)
- [ ] mechanical bounce の継続時間 (debounce_ms 設定値の根拠)

方向:
- [ ] CW 回転で `CLK` / `DT` の位相関係 (期待: CW で COUNT 増加)
- [ ] 期待と逆なら CONFIG `reverse_direction` または `clk_dt_swap` を set
- [ ] 物理 rewiring は最後の手段
