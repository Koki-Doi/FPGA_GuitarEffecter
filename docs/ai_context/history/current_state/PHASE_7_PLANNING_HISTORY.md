# Phase 7A / 7B / 7F / 7G planning history (extracted from CURRENT_STATE.md)

This file consolidates the original CURRENT_STATE.md snapshots from
Phase 7A (external codec + encoder planning), Phase 7B (module
verification + candidate package pin docs), and the Phase 7F/7G
encoder PL IP + Python driver + HDMI GUI control implementation
log. The deployed Phase 7C / 7E / 7D external-codec state and the
Phase 7G+ encoder live-apply runtime are described in the live
`CURRENT_STATE.md` headers and in `DECISIONS.md` D27 — D44.

Authoritative living docs: `EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md`
(plan + Phase 7C/7E/7D close-out), `IO_PIN_RESERVATION.md`,
`ENCODER_GUI_CONTROL_SPEC.md`, `ENCODER_INPUT_IMPLEMENTATION.md`,
`ENCODER_INPUT_MAP.md`, `DECISIONS.md` D27 — D44.

---

## Phase 7A — external PCM1808 ADC / PCM5102 DAC and rotary encoder planning (2026-05-17)

Phase 7A は **planning only**。実装 / XDC / block_design / bit / hwh
変更は一切なし (`DECISIONS.md` D27 / D28 / D29 / D30)。

成果物 (docs のみ):
- `docs/ai_context/EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md` (新規)
- `docs/ai_context/IO_PIN_RESERVATION.md` (新規)
- `docs/ai_context/ENCODER_GUI_CONTROL_SPEC.md` (新規)

確定事項:
- 外付け ADC は **Youmile PCM1808** (24-bit stereo, single-ended)
- 外付け DAC は **PCM5102 / PCM5102A** (I2S input, 内蔵 PLL)
- FPGA を **I2S clock master** にする (`48 kHz / 24-bit / BCLK=3.072 MHz / MCLK=12.288 MHz` 第一候補)
- 外付け audio pin を **PMOD JB** にまとめる候補 (clock skew 最小化)、追加 control / mode strap は **PMOD JA** に分散
- ロータリーエンコーダー 3 個 (各 A / B / SW, 9 pin) は **Raspberry Pi header** 候補 (audio 用 PMOD を潰さない)
- encoder は **PL 側で debounce + quadrature decode + delta/event 化** (Python polling は不採用)
- 外付け codec は ADAU1761 の **即置換ではなく** 別 I2S path として追加 (Phase 7B では選択肢 A または C)
- PCM1808 の analog input は **line-level** 想定。ギター直結は不可 (analog front-end は Phase 7E 以降)

実装は Phase 7B 以降:
- Phase 7B: 実モジュール検証 + XDC 候補
- Phase 7C: PCM5102 DAC 出力 prototype
- Phase 7D: PCM1808 ADC 入力 prototype
- Phase 7E: 外付け / ADAU1761 path 切替 + DSP 組込み
- Phase 7F: encoder PL IP + XDC + bit/hwh
- Phase 7G: Python encoder driver + GUI focus state
- Phase 7H: 筐体 / front panel

未実装 (Phase 7A 時点):
- `hw/Pynq-Z2/audio_lab.xdc` の外付け codec / encoder pin 追加
- `hw/Pynq-Z2/block_design.tcl` の encoder IP 追加
- `audio_lab_pynq/encoder_input.py` / `encoder_ui.py`
- `GUI/compact_v2/state.py` の focus state 拡張
- `GUI/compact_v2/renderer.py` の focus 表示

詳細は新規 3 docs (`EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md` /
`IO_PIN_RESERVATION.md` / `ENCODER_GUI_CONTROL_SPEC.md`) を参照。

## Phase 7B — module verification + candidate package pin docs (2026-05-17)

Phase 7B も **planning only**。XDC / block_design / bit / hwh は無変更。
Phase 7A の docs を実モジュールのシルクと PYNQ-Z2 board file
(`/home/doi20/board_files/XilinxBoardStore/boards/TUL/pynq-z2/1.0/part0_pins.xml`)
に基づいて訂正 + 具体化 (`DECISIONS.md` D31 / D32)。

成果物 (docs のみ):
- `docs/ai_context/IO_PIN_RESERVATION.md` 更新:
  - encoder 信号を `ENC*_CLK` / `ENC*_DT` / `ENC*_SW` に rename
    (元 `ENC*_A` / `ENC*_B` / `ENC*_SW`)
  - 物理シルク `CLK` / `DT` / `SW` / `+` / `GND` に揃え、`+` は
    3.3V 専用とすること明記
  - 新規 section 4A "Candidate package pins, Phase 7B draft":
    PMOD JB / PMOD JA / Raspberry Pi header / Arduino header の
    候補 package pin 表 (`LVCMOS33`、`Status` 付)
  - 新規 section 4.6 "PMOD JA ⇄ Raspberry Pi 共有ピン警告":
    PYNQ-Z2 上で `JA1..JA10` は `raspberry_pi_tri_i_{0..5}` および
    `respberry_sd_i` / `respberry_sc_i` と物理共有しており、
    PMOD JA を使うと該当 RPi GPIO は同時に使えない。encoder は
    `raspberry_pi_tri_i_6..24` (= JA と共有しない 19 pin) を選ぶ。
- `docs/ai_context/EXTERNAL_PCM1808_PCM5102_AUDIO_PLAN.md` 更新:
  - 新規 section 11 "Phase 7B 実モジュール確認チェックリスト"
    (PCM1808 / PCM5102 verification、Phase 7B pin candidate plan、
    PMOD JB / JA 接続案、Phase 7C / 7D / 7E 検証計画)
  - 禁止事項に `encoder IP の base address を HDMI VDMA range に
    置く (0x43CE0000 / 0x43CF0000 禁止)` を追加
- `docs/ai_context/ENCODER_GUI_CONTROL_SPEC.md` 更新:
  - タイトル / 全文を `CLK` / `DT` / `SW` 表記に統一
  - module pin labels セクションを冒頭に追加 (`+` 3.3V 専用警告含む)
  - encoder IP base address を **TBD** に戻し、`0x43CE0000` /
    `0x43CF0000` 禁止を明記 (`DECISIONS.md` D32)
  - CONFIG レジスタに `invert_clk` / `invert_dt` / `clk_dt_swap` /
    `reverse_direction` / `sw_active_low` を追加
  - 新規 section 7 "Phase 7B encoder module 物理確認チェックリスト"
- `docs/ai_context/DECISIONS.md` 更新:
  - D30 内の `0x43CE0000` 仮置きを TBD + `D32 で禁止` に訂正
  - 新規 D31 "Rotary encoder module pins are CLK / DT / SW / + / GND"
    (`+` は 3.3V 専用、5V で PL pin 破損リスク、方向はレジスタ補正)
  - 新規 D32 "Encoder PL IP の AXI base address は TBD、
    `0x43CE0000` (`axi_vdma_hdmi`) / `0x43CF0000` (`v_tc_hdmi`)
    禁止"
- `docs/ai_context/RESUME_PROMPTS.md` 更新:
  - Phase 7B prompt を物理確認 + candidate pin docs フェーズに更新
  - Phase 7C prompt (PCM5102 DAC 出力 prototype、XDC 最初の追加) を新設
  - Phase 7F prompt の `base 候補 0x43CE0000` を **TBD + 禁止 list** に訂正

確定事項 (Phase 7B):
- encoder module シルクは `CLK` / `DT` / `SW` / `+` / `GND`、論理名は
  `ENC*_CLK` / `ENC*_DT` / `ENC*_SW`、power は `ENC_3V3` / `ENC_GND`
- `ENC_3V3` は **3.3V のみ** (5V 禁止、`DECISIONS.md` D31)
- encoder IP base address は **TBD**。`0x43CE0000` (HDMI VDMA) と
  `0x43CF0000` (HDMI VTC) は禁止 (`DECISIONS.md` D32)
- candidate package pin: PMOD JB に audio (`W14 / Y14 / T11 / T10 /
  V16` + spare `W16 / V12 / W13`)、PMOD JA に audio control 候補
  (`Y18 / Y19 / Y16 / Y17 / U18 / U19 / W18 / W19`、ただし RPi と
  共有なので strap で固定するのが望ましい)、Raspberry Pi header の
  JA 非共有 pin (`F19, V10, V8, W10, B20, W8, V6, Y6, B19, U7, C20,
  Y8, A20, Y9, U8, W6, Y7, F20, W9`) を encoder + spare に割当
- 実 package pin 確定 / `audio_lab.xdc` 書込みは Phase 7C 以降

未実装 (Phase 7B 時点):
- `hw/Pynq-Z2/audio_lab.xdc` への外付け codec / encoder pin 追加
- `hw/Pynq-Z2/block_design.tcl` の encoder IP 追加
- 実モジュールでの物理確認結果反映 (チェックリストは作成済み、
  module 入手後に結果を `Status: needs physical verification` の
  行に反映)
- encoder PL IP 実装 / Python driver / GUI focus state

## Phase 7F/7G — Rotary encoder PL IP + Python driver + HDMI GUI control (2026-05-17)

Phase 7F (PL) + Phase 7G (PS) を一括実装 (`feature/rotary-encoder-hdmi-gui-control`
branch)。外付け PCM1808 / PCM5102 codec パスは触らず、PMOD JB / JA も
未配線のまま。`DECISIONS.md` D33 / D34 / D35 を追加。

新規 PL IP:
- `hw/ip/encoder_input/src/axi_encoder_input.v` — 単一 Verilog ファイル
  (~440 行)。AXI4-Lite slave + 3 ch quadrature + debounce + signed delta
  + s32 abs count + short/long press event latch + `invert_clk / dt`,
  `clk_dt_swap`, `reverse_direction`, `sw_active_low`, `debounce_ms`,
  `clear_on_read` を CONFIG レジスタで提供。`VERSION = 0x00070001`。
- `hw/Pynq-Z2/encoder_integration.tcl` — `hdmi_integration.tcl` と同じ
  パターン。`ps7_0_axi_periph/NUM_MI` を 17 → 18 に bump (M15=VDMA、
  M16=VTC、**M17=encoder**)、module reference として instantiate
  (`create_bd_cell -type module -reference axi_encoder_input enc_in_0`)、
  AXI address segment `0x43D10000 / 0x10000` を作成。
- `hw/Pynq-Z2/create_project.tcl` — encoder Verilog を `add_files` で
  追加、`generate_target {synthesis}` で per-IP OOC synth を保証、
  encoder_integration.tcl を hdmi_integration.tcl の後に source。
- `hw/Pynq-Z2/audio_lab.xdc` — encoder 9 pin を追加 (`F19 / V10 / V8`
  + `W10 / B20 / W8` + `V6 / Y6 / B19`、すべて `LVCMOS33`)。
  ADAU1761 / HDMI pin は無変更。PMOD JB / JA も無変更。

Python 層:
- `audio_lab_pynq/encoder_input.py` — low-level driver。
  `EncoderInput.from_overlay(overlay)` で IP を発見し、
  `poll(timestamp=)` が `EncoderEvent(kind, encoder_id, delta,
  raw_delta, timestamp)` を返す。`EDGES_PER_DETENT = 4`、edge carry
  で 2 polls 跨ぎの 1 detent も漏らさず emit。PYNQ-Z2 の Python
  3.6 image で動かすため、`EncoderEvent` は dataclass ではなく
  plain class。PYNQ 2020.1 の module-reference HWH では encoder が
  `ip_dict` 上 `enc_in_0/s_axi` として出るため、driver は bare
  `enc_in_0` hierarchy を MMIO IP と誤認せず bus-interface 名を探索する。
- `audio_lab_pynq/encoder_ui.py` — `EncoderUiController.handle_event()`
  で AppState を変更。Encoder 0 = effect select / toggle / safe-bypass、
  Encoder 1 = knob select / model-select toggle、Encoder 2 = value
  change / apply / reset。`apply()` は test/dry-run mirror があれば
  それを使い、live overlay では `GUI/audio_lab_gui_bridge.py` 経由で
  `AudioLabOverlay.set_*` public API に流す (raw GPIO write しない)。
- `GUI/compact_v2/state.py` — `AppState` に 8 つの追加 field
  (`focus_effect_index` / `focus_param_index` / `edit_mode` /
  `model_select_mode` / `value_dirty` / `apply_pending` /
  `last_control_source` / `last_encoder_event`)。すべて互換 default
  で既存 renderer / notebook はそのまま動く。
- `GUI/compact_v2/renderer.py` — 800x480 frame 右下に小さなステータス
  ストリップ (`EDIT / MODEL / DIRTY / APPLY? / ENC`)。既存の Pip-Boy
  レイアウト / chain highlight / knob highlight / inline model dropdown
  rules はそのまま。

Standalone runtime + tests:
- `scripts/run_encoder_hdmi_gui.py` — notebook 不要の Pip-Boy GUI
  loop runner (CLI: `--fps` / `--reverse-encN` / `--swap-encN` /
  `--debounce-ms` / `--hold-seconds` / `--dry-run` / `--no-apply`)。
- `scripts/test_encoder_input.py` — 実機上の manual rotate/press smoke
  (VERSION / CONFIG / COUNT 表示 + 60 秒間 live event 出力)。
- `scripts/test_hdmi_encoder_gui_control.py` — 実機上の synthesized
  encoder events + HDMI frame write smoke (scripted または
  `--use-real-encoder`)。
- `audio_lab_pynq/notebooks/EncoderGuiSmoke.ipynb` — Jupyter から
  overlay attach、encoder/HDMI/ADAU1761 smoke、raw register read、
  live monitor、reverse/swap/debounce 設定、synthetic GUI event、
  real encoder -> AppState、real encoder -> HDMI GUI loop を段階的に
  確認する 10-cell Notebook。`AudioLabOverlay()` は 1 回だけ使い、
  `base.bit` や二重 Overlay load はしない。
- `tests/test_encoder_input_decode.py` (13 tests)、
  `tests/test_encoder_ui_controller.py` (13 tests)、
  `tests/test_compact_v2_encoder_state.py` (4 tests) — オフライン
  unit tests。`tests/_pynq_mock` 経由で `pynq` なしの workstation
  でも全 30 件 PASS。既存 6 件の HDMI / overlay テストにも regression なし。

新規 docs:
- `docs/ai_context/ENCODER_INPUT_IMPLEMENTATION.md` — 実装メモ
  (RTL / Tcl / Python / runtime / tests / rollback / risks)
- `docs/ai_context/ENCODER_INPUT_MAP.md` — register / address /
  CONFIG bit table。`GPIO_CONTROL_MAP.md` (effect output ledger) と
  別ファイル (input path は layout が違うため混ぜない)。

Vivado build:
- 最初の build は per-IP OOC synth が triggers されず DRC INBB-3 で
  失敗 (audio_lab.cache を `rm -rf` した直後だったため)。
  `create_project.tcl` に `generate_target {synthesis}` + 明示的な
  `launch_runs synth_1 -> impl_1` を入れて修正。
- 2 回目の full `create_project.tcl` build は成功したが、その後
  `axi_encoder_input.v` の AXI read path を最小修正したため、その
  bitstream は採用せず。
- 3 回目は既存 Vivado project を開いて `synth_1` / `impl_1` を
  reset し、修正後 RTL で `write_bitstream` まで再実行。
  log: `/tmp/fpga_guitar_effecter_backup/phase7f7g_vivado_build3.log`。
  `write_bitstream completed successfully`、`audio_lab.bit` /
  `audio_lab.hwh` を `hw/Pynq-Z2/bitstreams/` にコピー済み。
- Final routed timing: WNS `-8.395 ns`, TNS `-6609.224 ns`,
  WHS `+0.052 ns`, THS `0.000 ns`。Phase 6I C2 baseline
  (WNS `-8.096 ns`, TNS `-6389.430 ns`) からの小幅悪化で、
  historical `-7..-9 ns` band 内。hold は clean。
- Utilization after place: Slice LUTs `19095 (35.89%)`, Slice
  Registers `21259 (19.98%)`, Block RAM Tile `9 (6.43%)`,
  DSPs `83 (37.73%)`。
- HWH address map: encoder module reference `enc_in_0`
  (`axi_encoder_input`) at `0x43D10000..0x43D1FFFF`。HDMI は
  `axi_vdma_hdmi=0x43CE0000`、`v_tc_hdmi=0x43CF0000` のまま。
  既存 effect GPIO (`0x43C30000..0x43CD0000`) も unchanged。
- PYNQ deploy completed to `192.168.1.9` with
  `PYNQ_HOST=192.168.1.9 bash scripts/deploy_to_pynq.sh`.
  `audio_lab.bit` / `audio_lab.hwh` were installed under the repo copy,
  package bitstreams, `/home/xilinx/pynq/overlays/audio_lab`, and the
  Notebook tree. The deploy script now recursively syncs `GUI/` so
  `GUI/compact_v2` is present on the board; it still excludes
  `GUI/README.md`, `GUI/fx_gui_state.json`, `__pycache__`, and
  notebook checkpoints.
- PYNQ smoke after deploy: `AudioLabOverlay()` loads, ADC HPF `True`,
  `R19=0x23`, `ip_dict` encoder key is `enc_in_0/s_axi`,
  `VERSION=0x00070001`, `CONFIG=0x00010105`, HDMI IPs
  `axi_vdma_hdmi` / `v_tc_hdmi` are present, and VTC `GEN_ACTSZ`
  reads `0x02580320` (V=600 / H=800).
- Low-level encoder smoke was executed for 60 s with
  `scripts/test_encoder_input.py --duration 60`; VERSION / CONFIG /
  idle COUNT read passed but no rotate or switch events were captured
  in that run (`COUNT0..2 = 0 / 0 / 0`, total events = 0). Therefore
  full physical encoder smoke is still **not** claimed.
- HDMI synthetic encoder GUI smoke passed:
  `scripts/test_hdmi_encoder_gui_control.py` started/stopped the HDMI
  backend, applied 10 scripted events to `AppState`, rendered frames,
  and reported `vdma_dmasr=0x00011000`.
- HDMI real encoder GUI loop started/stopped cleanly with
  `scripts/run_encoder_hdmi_gui.py --fps 2 --hold-seconds 10`;
  VDMA/VTC status stayed normal (`vdma_dmasr=0x00011000`,
  `vtc_ctl=0x00000006`, `HSIZE=2400`, `VSIZE=600`), and encoder 1/2
  rotate events were observed by the loop. Encoder 0 and SW short/long
  coverage still need hands-on confirmation.

未対応 (Phase 7H 以降):
- Jupyter UI または SSH セッションで、ユーザが実際に 3 個すべての
  encoder を回して `ENC0/1/2` rotate、SW short_press、SW long_press、
  release、チャタリング有無を記録する。必要なら Notebook / script の
  CONFIG で `reverse_direction` / `clk_dt_swap` / `debounce_ms` /
  `sw_active_low` を調整し、その最終値を docs に反映する。
- `EncoderGuiSmoke.ipynb` はローカルと PYNQ 上で JSON 妥当性を確認済み。
  PYNQ Jupyter path は
  `/home/xilinx/jupyter_notebooks/audio_lab/EncoderGuiSmoke.ipynb`。
  各 live cell の完全な手動操作確認は次の実機操作で行う。
- 外付け PCM1808 / PCM5102 codec 実装 (Phase 7C 以降の別作業)。

