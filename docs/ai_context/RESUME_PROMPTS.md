# Resume prompts

Short prompts the user can paste back to either Claude Code or Codex
after a rate-limit, context reset, or session restart. Each one is
self-contained and points the agent at the right docs instead of
asking it to re-discover the project from scratch.

## General resume

> 前回の作業は途中停止しました。リポジトリ全体を再調査しないでください。
> まず `AGENTS.md` または `CLAUDE.md` を読み、続けて
> `docs/ai_context/PROJECT_CONTEXT.md`、`CURRENT_STATE.md`、
> `DECISIONS.md` を読んでください。
> 次に `git status --short` と `git diff --stat` を確認してください。
> 未commit差分は破棄せず、現在の差分から作業を再開してください。
> `git push` / `git pull` / `git fetch` は禁止です。
> ADC HPF デフォルトON 設定を壊さないでください。
> `hw/Pynq-Z2/block_design.tcl` は変更しないでください。
> GPIO 設計は固定 (`DECISIONS.md` D12)、既存 GPIO 名 / address /
> ctrlA-D 割り当てを再配置しないでください。
> C++ DSP プロトタイプは削除済み (`DECISIONS.md` D13)。
> 新エフェクト追加では C++ → 移植の手順に戻らず、Python API / UI
> 予約 → Clash ステージ追加で進めてください。

## HDMI GUI integration — design only, not implemented

> HDMI GUI統合は調査/設計段階で、まだ実装していません。
> まず `AGENTS.md`、`docs/ai_context/PROJECT_CONTEXT.md`、
> `CURRENT_STATE.md`、`DECISIONS.md` を読み、続けて
> `docs/ai_context/HDMI_GUI_INTEGRATION_PLAN.md` を読んでください。
> 現在の `audio_lab.bit` には HDMI video out 系 IP が無く、
> `GUI/pynq_multi_fx_gui.py` の既存 `run_pynq_hdmi()` は
> `Overlay("base.bit")` をロードするため、そのまま使うと
> AudioLab DSP overlay が消えます。PYNQ は基本的に full bitstream を
> 1つしかロードできないので、AudioLab DSP と HDMI GUI を同時に使うには
> 将来的に `audio_lab.bit` 側へ HDMI framebuffer output path を統合する
> 必要があります。次作業を始める前に `git status --short` と
> `git diff --stat` を確認してください。`base.bit` をロードしないで
> ください。`AudioLabOverlay()` の後に別 `Overlay()` をロードしないで
> ください。`hw/Pynq-Z2/block_design.tcl`、Clash/DSP、Pythonコード、
> bitstream、deploy はユーザの明示承認なしに変更しないでください。
> `git push` / `git pull` / `git fetch` は禁止です。

### HDMI GUI Phase 1 prompt

> HDMI GUI統合の Phase 1 を実施してください。対象は
> `GUI/pynq_multi_fx_gui.py` の `render_frame(AppState())` を PYNQ-Z2 上で
> offscreen 実行し、1 frame生成時間、cached path、必要メモリを測定する
> ことです。HDMI出力、Vivado変更、bitstream rebuild、deploy、
> `base.bit` ロードはしないでください。結果を docs に記録してください。

### HDMI GUI Phase 1 result — continue from benchmark

> HDMI GUI Phase 1 の offscreen render benchmark は完了済みです。
> `docs/ai_context/HDMI_GUI_PHASE1_RENDER_BENCH.md` を読んでから再開して
> ください。PYNQ-Z2 (`192.168.1.9`) の環境は Python 3.6.5 /
> NumPy 1.16.0 / Pillow 5.1.0。`GUI/pynq_multi_fx_gui.py` はPYNQ上の
> repoには未配置だったため、測定時は `/tmp/hdmi_gui_phase1/` に一時
> コピーしました。raw import は `dataclasses` backport 不足で失敗。
> 測定専用shimでは NumPy `default_rng` と Pillow `ImageDraw` 互換も
> 補って render 成功。frame shape は `[720, 1280, 3]`、dtype は
> `uint8`。cold render は約 `3871 ms`、same-state cache hit は平均
> `0.177 ms/frame` / p95 `0.242 ms`、dynamic 30-frame loop は平均
> `744 ms/frame` / p95 `2247 ms` / 推定 `1.34 fps`。現在のrendererで
> animated 5/10/15/30fps HDMI は現実的ではありません。次に進むなら、
> HDMIやVivadoではなく、まず Python互換性 (`dataclasses`,
> NumPy 1.16, Pillow 5.1) と change-driven/static寄りの描画方針を
> Phase 2 の bridge設計に反映してください。`base.bit` ロード、
> `run_pynq_hdmi()`、Vivado変更、bitstream rebuild、deploy、
> `git push` / `git pull` / `git fetch`は禁止です。

### HDMI GUI Phase 2A result — PYNQ-compatible offscreen renderer

> HDMI GUI Phase 2A は完了済みです。
> `GUI/pynq_multi_fx_gui.py` は PYNQ-Z2 の Python 3.6.5 /
> NumPy 1.16.0 / Pillow 5.1.0 で shim なしに import / offscreen render
> できるよう、最小互換修正済みです。`dataclasses` fallback、
> NumPy 1.16 用 RNG adapter、Pillow 5.1 の `ImageDraw` keyword 互換を
> 追加しています。PYNQ 上の `/tmp/hdmi_gui_phase2a/` で raw import
> 成功、`render_frame_fast(AppState())` 成功、frame shape は
> `[720, 1280, 3]`、dtype は `uint8`。import は `451.188 ms`、
> cold render は `3764.514 ms`、same-state cache hit は平均
> `0.171034 ms/frame` / p95 `0.201208 ms`。change-driven redraw sample
> は平均 `1972.889 ms/frame` / p95 `2111.738 ms` で、animated
> 5/10/15/30fps HDMI は引き続き非現実的です。PNG は
> `/tmp/hdmi_gui_phase2a/phase2a_render.png` に保存し、1280x720 RGBで
> 見た目の大きな崩れなし。HDMI出力、`run_pynq_hdmi()`、
> `Overlay("base.bit")`、`AudioLabOverlay()`、Vivado変更、bitstream
> rebuild、deploy、GPIO bridge、DSP変更はしていません。詳細は
> `docs/ai_context/HDMI_GUI_PHASE2A_PYNQ_COMPAT.md` を読んでください。

### HDMI GUI Phase 2B result — static/change-driven renderer optimized

> HDMI GUI Phase 2B は完了済みです。
> `GUI/pynq_multi_fx_gui.py` に static/change-driven 向け軽量化を入れ、
> HDMI出力なしで PYNQ-Z2 (`192.168.1.9`) 上の offscreen benchmark を
> 再実行しました。変更は Python renderer と docs のみで、Vivado、
> bitstream、deploy、`AudioLabOverlay()`、GPIO bridge、DSP/Clash は
> 触っていません。主な変更: static LCD / knob-panel chrome を
> `render_static_base()` に移してcache、main display / knob panel を
> static chrome と state content に分離、knob body cache 追加、
> `make_pynq_static_render_cache()` と `render_frame_pynq_static()` 追加、
> PYNQ static mode では synthetic visualizer / waveform を固定し、
> glow / blur stamp を抑制。raw import 成功、frame shape/dtype は
> `[720, 1280, 3]` / `uint8`。default fast change-driven は Phase 2A の
> avg `1972.889 ms` / p95 `2111.738 ms` から avg `690.397 ms` /
> p95 `726.448 ms` に改善。PYNQ static mode は cold `2886.108 ms`、
> same-state p95 `0.200019 ms`、change-driven avg `255.625 ms` /
> p95 `276.171 ms`。PNG は
> `/tmp/hdmi_gui_phase2b/phase2b_pynq_static.png` に保存し、1280x720 RGBで
> 見た目の大きな崩れなし。詳細は
> `docs/ai_context/HDMI_GUI_PHASE2B_RENDER_OPTIMIZATION.md` を読んでください。
> `base.bit` ロード、`run_pynq_hdmi()`、Vivado変更、bitstream rebuild、
> deploy、`git push` / `git pull` / `git fetch`は禁止です。

### HDMI GUI Phase 2C prompt

> HDMI GUI統合の Phase 2C を実施してください。HDMI出力と Vivado変更は
> まだしないでください。`GUI/pynq_multi_fx_gui.py` の描画を温存し、
> `AppState` 変更を `AudioLabOverlay` の既存APIへ反映する bridge を
> 作ってください。GPIO write は毎frameではなく変更時または低rateにし、
> chain drag reorder は現行DSP固定順序と矛盾しないようライブモードで
> 無効化または表示専用にしてください。`base.bit` はロード禁止です。
> GUI表示は animated loop ではなく static/change-driven 前提にし、
> visualizer / waveform / meter は freeze または低頻度更新にしてください。

### HDMI GUI Phase 2C result — AppState bridge dry-run ready

> HDMI GUI Phase 2C は完了済みです。
> `GUI/audio_lab_gui_bridge.py` に renderer から分離した
> `AppState` -> `AudioLabOverlay` API bridge を追加し、
> `tests/test_hdmi_gui_bridge.py` で dry-run / same-state skip /
> knob-drag throttle / Chain Preset alias / Safe Bypass sequence を確認
> しています。bridge は `AudioLabOverlay()` を生成せず、bitstreamを
> ロードせず、GPIOを直接叩かず、`dry_run=True` がデフォルトです。
> 実GPIO writeは `dry_run=False` かつ既にロード済みの overlay を呼び元
> が渡した場合だけです。PYNQ-Z2 (`192.168.1.9`) の
> `/tmp/hdmi_gui_phase2c/` で shimなし import 成功、Python 3.6.5、
> dry-run plan は `set_noise_suppressor_settings` /
> `set_compressor_settings` / `clear_distortion_pedals` /
> `set_distortion_settings` / `set_guitar_effects`、同一状態2回目は
> 0 operations、knob drag は 10Hz 相当で throttle、throttle後は
> 1 operation。`render_frame_pynq_static(AppState())` は
> `[720, 1280, 3]` / `uint8` を維持。詳細は
> `docs/ai_context/HDMI_GUI_PHASE2C_BRIDGE_PLAN.md` を読んでください。
> HDMI出力、`run_pynq_hdmi()`、`Overlay("base.bit")`、
> `AudioLabOverlay()` load、Vivado変更、bitstream rebuild、deploy、
> Notebook変更、DSP/Clash変更、`git push` / `git pull` / `git fetch`
> はしていません。

### HDMI GUI Phase 3 prompt

> HDMI GUI統合の Phase 3 として、`audio_lab.bit` に HDMI video out 系を
> 統合する Vivado設計案だけを作成してください。まだ
> `hw/Pynq-Z2/block_design.tcl` は変更しないでください。AXI VDMA または
> PYNQ video subsystem 相当、HDMI output IP、video timing、clocking、
> framebuffer path、1280x720 RGB、既存Audio DSPとの共存、AXI/DDR負荷、
> resource/timingリスク、address map影響、rollback案を docs にまとめ、
> 実装はユーザ承認を待ってください。

### HDMI GUI Phase 2D result — bridge runtime test on real overlay

> HDMI GUI Phase 2D は完了済みです。
> PYNQ-Z2 (`192.168.1.9`) 上で `GUI/audio_lab_gui_bridge.py` を
> 実 `AudioLabOverlay()` に対して `dry_run=False` で実行し、
> `clear_distortion_pedals` / `set_distortion_settings` /
> `set_noise_suppressor_settings` / `set_compressor_settings` /
> `set_guitar_effects` / `apply_chain_preset` を本当に呼びました。
> `AudioLabOverlay()` のロードは 1 回のみ、HDMI出力なし、
> `Overlay("base.bit")` 未使用、second overlay load なし、
> `render_frame*` 未呼び、Vivado / block_design / bitstream / hwh /
> Notebook / DSP 変更なし、`scripts/deploy_to_pynq.sh` 未実行、
> `git push` / `git pull` / `git fetch` 未実施。Safe Bypass 適用、
> Basic Clean chain preset 適用、same-state 2 回目は 0 ops、
> Noise Sup THRESHOLD だけ変更 → `set_noise_suppressor_settings` +
> `set_guitar_effects` (legacy mirror) で section-scoped、
> Compressor RATIO だけ変更 → `set_compressor_settings` のみ、
> knob_drag throttle 100 ms 窓の内側は 0 ops / 1 skipped、
> 窓の外は 1 op。pre/post smoke はどちらも `ADC HPF=True`、
> `R19=0x23`、`has delay_line gpio=False`、
> `has legacy axi_gpio_delay=True`。詳細は
> `docs/ai_context/HDMI_GUI_PHASE2D_BRIDGE_RUNTIME_TEST.md`。

### HDMI GUI Phase 3 result — Vivado integration proposal

> HDMI GUI Phase 3 は完了済みです。`hw/Pynq-Z2/block_design.tcl`、
> `audio_lab.xdc`、Clash / DSP、bitstream、hwh、deploy は触っていません。
> 推奨構成は Option B (`axi_vdma` + `v_tc` + `v_axi4s_vid_out` +
> Digilent `rgb2dvi`) を 1280x720@60 固定モードで使用、追加 `clk_wiz`
> で `pixel_clk=74.25 MHz` と `serial_clk=371.25 MHz` を生成、
> 追加 `proc_sys_reset` で video domain reset、
> `processing_system7_0` の `S_AXI_HP0` を有効化して VDMA MM2S を
> PS DDR フレームバッファに繋ぐ、`ps7_0_axi_periph` の `NUM_MI` を
> 15 → 17 に拡張、VDMA / VTC の AXI-Lite control 用 address 候補は
> `0x43CE0000` / `0x43CF0000` / `0x43D00000` (rgb2dvi 用 control が
> 必要な場合)。既存 `axi_gpio_*` の address / name / `ctrlA`-`ctrlD`
> semantics は一切変更しない。`axi_gpio_delay` (legacy RAT) も
> そのまま保持。framebuffer は XRGB8888、double buffer、Python は
> `render_frame_pynq_static` を変更時のみ呼んで一度コピーする
> change-driven 運用。Phase 2B 計測ベースで現実的なredrawは
> 2..4 fps。リソース追加見積りは LUT +3.4k..+4.0k、FF +4.8k..+5.3k、
> BRAM +4..+7、DSP +0。Deploy gate は audio domain WNS が baseline
> -8.155 ns から significantly に悪化していないこと。pixel / serial
> 両 domain は WNS >= 0。Rollback は bit/hwh 日付付きバックアップと
> 将来 feature branch 上の `git revert`、`git push` / `pull` /
> `fetch` は引き続き禁止。設計書は
> `docs/ai_context/HDMI_GUI_PHASE3_VIVADO_DESIGN_PROPOSAL.md`、
> `block_design.tcl` パッチ案 (未適用) は
> `docs/ai_context/HDMI_BLOCK_DESIGN_TCL_PATCH_PLAN.md`、Phase 4
> 実装用プロンプト雛形は
> `docs/ai_context/HDMI_GUI_PHASE4_IMPLEMENTATION_PROMPT_DRAFT.md`。

### HDMI GUI Phase 4 result — integrated overlay deployed

> HDMI GUI Phase 4 は完了済みです。
> `feature/hdmi-gui-phase4-vivado-integration` で dirty recovery から
> 再開し、Digilent `vivado-library`
> (`/home/doi20/digilent-vivado-library`) の
> `digilentinc.com:ip:rgb2dvi:1.4` を Vivado 2019.1 catalog で確認後、
> `hw/Pynq-Z2/hdmi_integration.tcl` を `create_project.tcl` から source
> する形で HDMI path を統合しました。追加 IP は
> `axi_vdma_hdmi` (`0x43CE0000`)、`v_tc_hdmi` (`0x43CF0000`)、
> `v_axi4s_vid_out_hdmi`、`rgb2dvi_hdmi`、`clk_wiz_hdmi`、
> `rst_video_0`、`axi_smc_hdmi`。GUI renderer output は
> RGB888 `[720,1280,3]` / `uint8`、DDR framebuffer は packed `GBR888`、
> VDMA HSIZE/STRIDE は `3840`、VSIZE は `720`。Vivado build は
> `write_bitstream` 成功、timing は WNS=-8.163 ns / TNS=-6599.061 ns /
> WHS=+0.051 ns / THS=0.000 ns。Utilization は LUT 18619、Registers
> 20846、BRAM 9、DSP 83。`bash scripts/deploy_to_pynq.sh` で
> PYNQ-Z2 (`192.168.1.9`) に deploy 済み。Smoke は ADC HPF=True /
> R19=0x23 / `axi_gpio_delay_line=False` / legacy `axi_gpio_delay=True` /
> noise_suppressor と compressor GPIO present / required chain presets
> OK。HDMI static frame は renderer が RGB888 を生成し、VDMA は
> framebuffer `0x16900000`、`DMASR=0x00011000`、error bits なし。
> 物理 display の目視確認だけ未実施。`AudioLabHdmiBackend` は
> PYNQ の `AxiVDMA` driver ではなく `ip_dict` から `pynq.MMIO` を直接
> 作る設計です。`Overlay("base.bit")`、`run_pynq_hdmi()`、second
> overlay load、DSP/Clash/topEntity/GPIO 変更、`git push` / `pull` /
> `fetch` は引き続き禁止です。詳細は
> `docs/ai_context/HDMI_GUI_PHASE4_IMPLEMENTATION_RESULT.md`。

### HDMI GUI Phase 4C result — static frame and resource profile

> HDMI GUI Phase 4C は完了済みです。
> Vivado rebuild、bit/hwh再生成、full deploy、`block_design.tcl` /
> `audio_lab.xdc` / `create_project.tcl` / Clash / DSP / `topEntity` /
> GPIO変更はしていません。追加した測定スクリプトは
> `scripts/profile_hdmi_static_frame.py`、結果docsは
> `docs/ai_context/HDMI_GUI_PHASE4C_RESOURCE_PROFILE.md` です。
> PYNQ-Z2 (`192.168.1.9`) で `AudioLabOverlay()` を1回だけロードし、
> `Overlay("base.bit")`、`run_pynq_hdmi()`、second overlay load は
> 未使用です。Static frame再確認は ADC HPF=True / R19=0x23 /
> `axi_gpio_delay_line=False` / legacy `axi_gpio_delay=True` /
> HDMI IP present / renderer `[720,1280,3] uint8` / framebuffer
> `0x16900000` / VDMA HSIZE=3840 STRIDE=3840 VSIZE=720 /
> `VDMACR=0x00010001` / `DMASR=0x00011000` / error bitsなし。
> VTC readback は `0x00000006`。物理HDMIモニタと色順は
> Codexでは目視未確認なので、ユーザー確認待ちです。
> 60秒hold profileでは cold render=2.979s、same-state cached
> avg/p95=0.00052s/0.00217s、change-driven render avg/p95=0.276s/0.280s、
> RGB888->DDR GBR888 copy avg/p95=0.206s/0.206s、VDMA/VTC start=0.0023s。
> Hold中process CPU avg/max=0.352%/0.418%、system CPU avg/max=0.190%/0.990%、
> process max RSS=136876 kB、MemAvailable before/after=390860/270764 kB。
> 温度はPYNQ imageが thermal/hwmon temp file を公開していなかったため
> 取得不能。実用的なwarm change-driven更新は約2.1fpsで、現行Python
> full-frame renderer/copyのまま30fps連続GUIは非現実的です。
> 次はユーザーの物理HDMI目視確認、任意の10分hold test、その後 Phase 5
> change-driven GUI loopです。`git push` / `pull` / `fetch`は禁止です。

### HDMI GUI Phase 4D result — small LCD fit modes

> HDMI GUI Phase 4D は完了済みです。
> ユーザー目視で小型HDMI LCDにGUI表示は確認済みですが、native 1280x720
> はLCD側crop/overscanで画面からはみ出していました。Vivado rebuild、
> bit/hwh再生成、`block_design.tcl` / `audio_lab.xdc` /
> `create_project.tcl` / Clash / DSP / `topEntity` / GPIO / HDMI IP構成
> 変更はしていません。`audio_lab_pynq/hdmi_backend.py` にPython側
> fit modeを追加し、RGB888 frameを縮小して黒背景1280x720へ中央配置
> してから既存のDDR `GBR888` copyを使うようにしました。追加modeは
> `native`、`fit-97`、`fit-95`、`fit-90`、`fit-85`、`fit-80` と
> custom `--scale`。新規 `scripts/test_hdmi_fit_frame.py` は1px外枠、
> 10/20/40px inset border、TL/TR/BL/BR、CENTER、grid、crosshair、
> 1280x720表記、fit mode表記を描画します。PYNQ-Z2 (`192.168.1.9`)
> では `native`、`fit-95`、`fit-90` test pattern と GUI `fit-90` が
> すべて60秒hold成功、VDMA error bitsなし。`fit-90` は scaled
> `1152x648`、offset `(64,36)`、GUI render=2.979s、
> resize/compose=0.265s、copy=0.207s。共通statusは
> `VDMACR=0x00010001`、`DMASR=0x00011000`、HSIZE/STRIDE=3840、
> VSIZE=720、VTC=`0x00000006`、framebuffer=`0x16900000`。
> 推奨候補はまず `fit-90`。まだ40px borderやcorner labelが切れるなら
> `fit-85`、`fit-95`で全て見えるなら `fit-95` が画面面積を多く使えます。
> Codexは物理画面を見られないため、最終fit mode、色順、文字可読性、
> 縦横比はユーザー目視で決定してください。詳細は
> `docs/ai_context/HDMI_GUI_PHASE4D_LCD_FIT_TEST.md`。
> `Overlay("base.bit")`、`run_pynq_hdmi()`、second overlay load、
> `git push` / `pull` / `fetch` は引き続き禁止です。

### HDMI GUI Phase 4E result — 800x480 logical GUI

> HDMI GUI Phase 4E は完了済みです。
> 小型HDMI LCDは5インチ800x480の可能性が高いため、1280x720 GUIの縮小
> ではなく、`GUI/pynq_multi_fx_gui.py::render_frame_800x480(AppState())`
> を5インチ向けlogical rendererに差し替えました。出力は `[480,800,3]`
> / `uint8`。既存1280x720 rendererは維持しています。UIはdark
> AudioLab/plugin調を維持しつつ、24px safe margin、大きいpreset/status、
> compact chain、selected FX summary、simplified signal monitor、IN/OUT
> levelを優先表示します。`AudioLabHdmiBackend` はlogical frameを
> 1280x720 framebuffer中央へ配置でき、800x480では offset `x=240`,
> `y=120`。VDMA HSIZE/STRIDE/VSIZE、HDMI signal、Vivado、bit/hwh、
> `block_design.tcl`、`audio_lab.xdc`、`create_project.tcl`、Clash/DSP、
> `topEntity`、GPIO、HDMI IP構成は変更していません。
> PYNQ-Z2 (`192.168.1.9`) で
> `scripts/test_hdmi_800x480_frame.py --hold-seconds 60` が成功しました。
> `AudioLabOverlay()` は1回だけload、`Overlay("base.bit")` /
> `run_pynq_hdmi()` / second overlay load は未使用。ADC HPF=True、
> R19=0x23、`axi_gpio_delay_line=False`、legacy `axi_gpio_delay=True`、
> HDMI IP present、post Safe Bypass smoke OK。測定値は render=0.317s、
> center compose=0.026s、full framebuffer copy=0.207s、total update約0.550s。
> VDMAは `VDMACR=0x00010001`、`DMASR=0x00011000`、HSIZE/STRIDE=3840、
> VSIZE=720、error bitsなし。VTC=`0x00000006`。
> 1280x720 `fit-90` の cold path (`2.979 + 0.265 + 0.207s`) より
> 大幅に軽いですが、copyはまだ1280x720全体をswizzleしています。次は
> ユーザーの物理目視で読みやすさ・色順・縦横比・中央配置を確認し、
> 必要なら800x480 layout調整、部分copy最適化、Phase 5 change-driven
> loopへ進んでください。詳細は
> `docs/ai_context/HDMI_GUI_PHASE4E_800X480_LOGICAL_GUI.md`。

### HDMI GUI Phase 4F result — viewport calibration and manual placement

> HDMI GUI Phase 4F は完了済みです。
> Phase 4E の800x480 logical GUI中央配置 offset `(240,120)` は、実機
> 5インチLCD上で大きく右寄りに見えました。1280x720 framebuffer全体を
> LCDが正しく縮小表示しているなら中央に見えるはずなので、LCD側crop
> または viewport sampling ずれの可能性が高いです。Vivado rebuild、
> bit/hwh再生成/転送、`block_design.tcl` / `audio_lab.xdc` /
> `create_project.tcl` / Clash / DSP / `topEntity` / GPIO / HDMI IP構成 /
> VDMA設定変更はしていません。`AudioLabHdmiBackend` に
> `placement="manual"`、`offset_x`、`offset_y` を追加し、logical frameが
> framebuffer外へ出る場合もclipして安全にcopyします。`placement="center"`
> は既存互換です。新規 `scripts/test_hdmi_viewport_calibration.py` は
> 1280x720座標grid、FB四隅/中央ラベル、800x480候補枠 `(0,0)` /
> `(120,60)` / `(240,120)` / `(320,120)` を描きます。
> PYNQ-Z2 (`192.168.1.9`) では calibration pattern と manual offset
> `(0,0)`、`(80,40)`、`(120,60)` の800x480 GUI testがすべて60秒hold成功。
> `AudioLabOverlay()` は1回だけload、`Overlay("base.bit")` /
> `run_pynq_hdmi()` / second overlay load は未使用。ADC HPF=True、
> R19=0x23、`axi_gpio_delay_line=False`、legacy `axi_gpio_delay=True`、
> post Safe Bypass smoke OK。共通statusは `VDMACR=0x00010001`、
> `DMASR=0x00011000`、HSIZE/STRIDE=3840、VSIZE=720、VTC=`0x00000006`、
> error bitsなし。manual GUIは render約0.315s、compose約0.025s、
> full framebuffer copy約0.207s。最終offsetはユーザー目視で決めてください:
> `(0,0)` が合うなら左上crop、`(80,40)` が合うなら軽いoverscan、
> `(120,60)` が合うなら中程度offset、どれも合わないならHDMI timing /
> LCD controller側を疑います。詳細は
> `docs/ai_context/HDMI_GUI_PHASE4F_VIEWPORT_CALIBRATION.md`。

### HDMI GUI Phase 4G result — compact-v2 layout and negative offsets

> HDMI GUI Phase 4G は完了済みです。
> Phase 4F の中央/正方向offsetでも5インチLCD上で左に大きな空白が残り、
> GUIが右寄りに見えていました。Phase 4Gでは、Vivado rebuild / bit /
> hwh再生成 / `block_design.tcl` / `audio_lab.xdc` /
> `create_project.tcl` / Clash / DSP / `topEntity` / GPIO / HDMI IP /
> VDMA / VTC設定を一切触らず、Python側だけで以下2点を追加しました。
> (1) `GUI/pynq_multi_fx_gui.py::render_frame_800x480_compact_v2` を
> 新設し、`render_frame_800x480(state, variant="compact-v2",
> placement_label=...)` でも呼べます。`compact-v1` は既存呼び出し用に
> 残しています。compact-v2は外枠12pxマージン、2-3px stroke、横一列
> chain (NS/CMP/OD/DIST/AMP/CAB/EQ/RVB)、`AMP SIM` などの hero text、
> 4本knob bar、16-segment IN/OUT meter、TL/TR/BL/BR の四隅マーカー、
> 画面下部に `v=compact-v2 p=manual off=(x,y)` の小ラベルを描きます。
> (2) `audio_lab_pynq/hdmi_backend.py::compose_logical_frame` が
> 負offsetを受けてsource側をclipし、`negative_offset` / `clipped` /
> `fully_offscreen` / `requested_destination_region` をmetaに追加。
> `scripts/test_hdmi_800x480_frame.py` は `--variant`、`--placement`、
> 負値可の `--offset-x` / `--offset-y` を取り、新規
> `scripts/test_hdmi_800x480_cycle_offsets.py` は `AudioLabOverlay()`
> を1回だけloadして `(0,0)`、`(-80,0)`、`(-120,0)`、`(-160,0)`、
> `(-240,0)`、`(0,-40)`、`(-120,-40)`、`(-160,-40)` を順に表示します。
> PYNQ-Z2 (`192.168.1.9`) では board上の `audio_lab.bit` (4,045,680B)
> と `audio_lab.hwh` (1,054,120B) はdeploy前後で同サイズのままで、
> Python/scriptsだけを `scp` で更新しました。compact-v2 `(0,0)` 単発は
> 60秒hold成功、render `0.337s`、compose `0.026s`、framebuffer copy
> `0.207s`、`VDMACR=0x00010001`、`DMASR=0x00011000`、
> `vtc_ctl=0x00000006`、error bitsなし。8 offset cycleも全offsetで
> error bitsなし、各offset render 約0.09s (label変化のためcache miss)、
> compose 約0.025s、copy 約0.206s、負offsetは
> `negative_offset=True` / `clipped=True` / `fully_offscreen=False`。
> post Safe Bypass smoke OK。最適offsetはユーザー目視で
> `--seconds-per-offset 15` 等で再撮影して決定してください。詳細は
> `docs/ai_context/HDMI_GUI_PHASE4G_800X480_LAYOUT_CORRECTION.md`。

## PYNQ-Z2 DHCP reservation / deploy

> PYNQ-Z2 はルーター DHCP 固定割当で `192.168.1.9` に固定して運用します。
> 実機 eth0 MAC は `00:05:6B:02:CA:04`、Jupyter は
> `http://192.168.1.9:9090/tree`、SSH は `ssh xilinx@192.168.1.9`。
> ルーター管理画面で Device name `PYNQ-Z2`、MAC
> `00:05:6B:02:CA:04`、Reserved IP `192.168.1.9` を登録し、PYNQ を
> 再起動してください。確認は
> `bash scripts/show_pynq_network_info.sh` と
> `ssh xilinx@192.168.1.9 'hostname; ip -br addr'`。
> deploy は通常 `bash scripts/deploy_to_pynq.sh` でよく、必要なら
> `PYNQ_HOST=192.168.1.9 bash scripts/deploy_to_pynq.sh` と明示します。
> 到達不能なら電源、LAN、DHCP固定割当、予約MAC、IP重複を確認してください。

## LowPassFir split refactor — local build complete, deploy pending

> `feature/split-lowpassfir-behavior-preserving` では
> `LowPassFir.hs` を挙動不変で `AudioLab.Types` / `FixedPoint` /
> `Control` / `Axis` / `Effects.*` / `Pipeline` に分割しました。
> `LowPassFir.hs` には Vivado-visible な `topEntity` と annotation だけを
> 残しています。DSP 係数、bit 幅、pipeline 順、`Frame` shape、
> `topEntity` port、`block_design.tcl`、GPIO、Python API、Notebook UI、
> Chain Preset は変更していません。Clash type check / VHDL生成、
> IP repackage、Vivado bit/hwh rebuild は完了し、timing は
> WNS=-8.022 ns / TNS=-13937.512 ns / WHS=+0.052 ns / THS=0.000 ns
> で前回 deploy baseline と同値です。local Python tests と Notebook
> JSON checks も pass 済み。`PYNQ_HOST=192.168.1.9` で deploy 済みで、
> smoke test では ADC HPF=True / R19=0x23 / delay_line gpio False /
> legacy axi_gpio_delay True / amp models / 指定 chain preset を確認済みです。

## Adding a new effect

> 新しいエフェクトを追加するときは、まず
> `docs/ai_context/EFFECT_ADDING_GUIDE.md` の判断フローを読んでくださ
> い。GPIO 設計は固定なので、まず `GPIO_CONTROL_MAP.md` の `reserved`
> 領域 (例: `axi_gpio_distortion.ctrlD[3..5,7]`、
> `axi_gpio_noise_suppressor.ctrlD`、`axi_gpio_eq.ctrlD`) で済ませら
> れるかを確認してください。新規 `axi_gpio_*` 追加は最後の手段で、
> ユーザの明示承認が必要です (`DECISIONS.md` D2 / D11 / D12)。
> Python 側のヘルパは `audio_lab_pynq/control_maps.py` に集約されてい
> ます (pack_u8x4 / set_byte / percent_to_u8 など)。defaults と presets
> は `audio_lab_pynq/effect_defaults.py` /
> `audio_lab_pynq/effect_presets.py`。新エフェクトの仕様は
> `EFFECT_STAGE_TEMPLATE.md` を埋めて記録してください。

## Distortion pedal-mask is shipped — do not roll it back

> 歪みセクションは pedal-mask 方式 (commit `baa97ff` ほか) で実装済み・
> deploy済み・実機確認済みです。全 7 ペダル (`clean_boost` /
> `tube_screamer` / `rat` / `ds1` / `big_muff` / `fuzz_face` /
> `metal`) に Clash ステージが揃っており、bit 7 のみ reserved です。
> 8-way `model_select` 方式へ戻さないでください。新しいペダル / フィルタ
> を追加するときも、巨大 `case` ではなく独立 register-staged ブロックを
> 維持してください。詳細は `docs/ai_context/DISTORTION_REFACTOR_PLAN.md`
> と `DECISIONS.md` の D6 / D8 / D9 を確認してください。

## Reserved-pedal implementation — shipped

> `ds1` (bit 3), `big_muff` (bit 4), `fuzz_face` (bit 5) は
> 専用 Clash ステージとして実装済み・deploy 済み。
> `LowPassFir.hs` の `ds1HpfFrame -> ds1MulFrame -> ds1ClipFrame ->
> ds1ToneFrame -> ds1LevelFrame`、`bigMuffPreFrame ->
> bigMuffClip1Frame -> bigMuffClip2Frame -> bigMuffToneFrame ->
> bigMuffLevelFrame`、`fuzzFacePreFrame -> fuzzFaceClipFrame ->
> fuzzFaceToneFrame -> fuzzFaceLevelFrame` が `fxPipeline` で
> `metalLevelPipe` の後ろに連結され、`distortionPedalsPipe =
> fuzzFaceLevelPipe`。各ペダルは独立 enable で OFF 時 bit-exact bypass。
> 新規 GPIO / `topEntity` ポート / `block_design.tcl` 変更なし。
> 実装当時の WNS / deploy 結果は `TIMING_AND_FPGA_NOTES.md` を参照。
> 8-way `model_select` mux 構造へは絶対に戻さないこと
> (`DECISIONS.md` D6 / D9)。voicing 微調整は `LowPassFir.hs` の
> 該当ブロックの定数 / clip helper だけを編集する形で行うこと
> (`REAL_PEDAL_VOICING_TARGETS.md` の運用と同じ)。
> 商用ペダル / GPL DSP のソースコードコピーは禁止。8th pedal slot
> (bit 7) は引き続き reserved。

## Tightening WNS

> 現状 deploy 済の WNS = -8.731 ns (audio-analysis voicing fixes
> ビルド) はベースライン同等で、運用上は動いていますが厳密には
> まだ負です。これを 0 へ寄せたい場合は、`LowPassFir.hs` の中で
> 残った深い組合せブロックを register で分け、必要なら cab タップ
> や reverb BRAM のアドレス経路を pipeline 化してください。1 段に
> 大きな `case` や 4 段以上の演算を詰めない方針は維持してください
> (`TIMING_AND_FPGA_NOTES.md` 参照)。

## Amp Simulator named models — deployed

> Amp Simulator に 4 つの named voicing (`jc_clean` / `clean_combo` /
> `british_crunch` / `high_gain_stack`) を追加しました。新エフェクト
> ではなく、既存 `amp_character` byte に意味付けする convenience レイヤ
> です。`LowPassFir.hs` には `ampModelSel :: Unsigned 8 -> Unsigned 2`
> ヘルパを追加し、`ampPreLowpassFrame` の baseAlpha (`128 + ch>>2`) から
> band 別に高域を darken します。初回 named-model build は
> `0/2/8/16` でしたが、後続の fizz-control pass で `0/4/12/24` に
> 更新済みです (high-gain stack ほど強く)。他の amp ステージは既存連続
> カーブのまま。商用アンプ回路 /
> IR / 係数のコピーなし、GPL DSP コードのコピーなし。
> Python: `audio_lab_pynq.effect_defaults.AMP_MODELS = {jc_clean: 10,
> clean_combo: 35, british_crunch: 60, high_gain_stack: 85}`。
> `AudioLabOverlay.set_amp_model(name, **overrides)` は
> `set_guitar_effects(amp_character=AMP_MODELS[name], ...)` への薄い
> ラッパーで、`amp_character` 数値指定はそのまま動作。
> `GuitarPedalboardOneCell.ipynb` の Amp Simulator アコーディオンに
> Amp Model dropdown を追加 (Character スライダーは残す)。
> 新規 GPIO / `topEntity` port / `block_design.tcl` 変更なし。
> 8-way `model_select` / 巨大 case 構造には戻していません
> (`DECISIONS.md` D6 / D18)。bit/hwh rebuild と PYNQ deploy 済み。
> timing 結果は `TIMING_AND_FPGA_NOTES.md` を参照。

## Amp Simulator fizz-control pass — deployed

> Amp Simulator の高域 fizz 対策は `feature/amp-sim-fizz-control` で
> 実装済み・deploy 済みです。対象は DSP 内部の Amp Sim 高域だけで、
> 入力→バイパス差、codec/I2S/hardware 経路、ノイズ床、解析ツール、
> test signal 生成、Cab Sim 大規模再設計は対象外です。
> `LowPassFir.hs` では既存 Amp stage のみを retune:
> `ampPreLowpassFrame` の per-model darken を `0/2/8/16` から
> `0/4/12/24` へ、`ampTrebleGain character treble` で高域戻しを
> model 別 trim (`0/2/5/9`) 付きに、`ampResPresenceProductsFrame` で
> presence trim (`0`, `p>>5`, `p>>4`, `p>>3`) を追加、`ampPowerFrame` /
> `ampResPresenceMixFrame` の `softClipK` knee を `3_500_000` から
> `3_400_000` へ変更。新規 GPIO / `topEntity` port /
> `block_design.tcl` 変更なし、Delay line 実装なし、
> `axi_gpio_delay_line` なし、legacy `axi_gpio_delay` は維持。
> Compressor / Noise Suppressor / Reverb / Delay / Distortion /
> Overdrive / Cab IR は触っていません。
> timing は WNS=-8.022 ns、TNS=-13937.512 ns、WHS=+0.052 ns、
> THS=0.000 ns。前回 audio-analysis baseline WNS=-8.731 ns から
> +0.709 ns 改善。PYNQ smoke test で ADC HPF=True / R19=0x23 /
> delay_line gpio False / legacy axi_gpio_delay True / 4 amp model /
> 指定 chain preset を確認済み。商用 amp 回路/IR/係数や GPL code は
> コピーしていません。詳細は `DECISIONS.md` D20 と
> `TIMING_AND_FPGA_NOTES.md` を参照。

## Audio-analysis voicing fixes — deployed

> 録音解析に基づく voicing fixes は
> `feature/audio-analysis-voicing-fixes` で実装済み・deploy 済みです。
> 新エフェクト追加ではなく、`LowPassFir.hs` の既存 stage だけを調整
> しています。主な変更は Compressor (`compThresholdSample`,
> `compEnvNext`, `compTargetGain`, `compGainNext`)、Overdrive
> (`overdriveDriveMultiplyFrame`, `overdriveDriveClipFrame`,
> `overdriveLevelFrame`)、Amp (`ampDriveMultiplyFrame`,
> `ampPreLowpassFrame`, `ampToneProductsFrame` / `ampTrebleGain`,
> `ampPowerFrame`, `ampResPresenceProductsFrame` /
> `ampResPresenceMixFrame`, `ampMasterFrame`)、Cab (`cabCoeff`)。
> `cabLevelMixFrame` は timing のため既存 `softClip` のままです。
> DS-1 Crunch preset は Cab model 2 / capped air に寄せました。
> 新規 GPIO / `topEntity` port / `block_design.tcl` 変更なし、Python API
> / Notebook UI 変更なし。bit/hwh rebuild と PYNQ deploy 済み。
> timing は WNS=-8.731 ns、TNS=-13665.555 ns、WHS=+0.051 ns、
> THS=0.000 ns。ADC HPF=True / `R19_ADC_CONTROL=0x23`、preset smoke
> test pass。商用 IR / 回路 / GPL DSP コードはコピーしていません。
> 根拠は `AUDIO_RECORDING_ANALYSIS.md`、決定は `DECISIONS.md` D17。

## Noise Suppressor work — branch in progress / shipped

> Noise Suppressor は専用 GPIO `axi_gpio_noise_suppressor` (`0x43CC0000`)
> 経由で THRESHOLD / DECAY / DAMP / mode を持ち、Clash 側で envelope +
> smoothed-gain 段に置き換え済み (`fxPipeline` の `nsLevelPipe ->
> nsEnv -> nsGain -> nsPipe`)。enable は引き続き `gate_control` bit 0
> (legacy `noise_gate_on`)。Python API は
> `set_noise_suppressor_settings(threshold=, decay=, damp=, enabled=,
> mode=)` / `get_noise_suppressor_settings()`、threshold byte は
> `round(threshold * 255 / 1000)` (新スケール: 100 ≡ 旧 10)。
> `set_guitar_effects(noise_gate_threshold=...)` も新スケール。互換
> として legacy `gate_control.ctrlB` にも同じ byte を書く (新ビットで
> は dead)。RNNoise / FFT / spectral 系は採用していない。BOSS NS-2 /
> NS-1X は思想のみ参考、コードコピーなし。詳しくは
> `docs/ai_context/DECISIONS.md` D11 / `DSP_EFFECT_CHAIN.md` Noise
> Suppressor 節 / `GPIO_CONTROL_MAP.md` Noise Suppressor 節を参照。
> 既存 distortion pedal-mask 実装と
> `GuitarPedalboardOneCell.ipynb` の他セクションは触らないでください。

## Compressor work — branch in progress / shipped

> Compressor は専用 GPIO `axi_gpio_compressor` (`0x43CD0000`) 経由で
> THRESHOLD / RATIO / RESPONSE / enable+MAKEUP を持ち、Clash 側で
> stereo-linked feed-forward peak compressor 段
> (`fxPipeline` の `compLevelPipe -> compEnv -> compGain ->
> compApplyPipe -> compMakeupPipe`) を Noise Suppressor の直後・
> Overdrive の直前に追加済みです。enable は専用 GPIO の `ctrlD` bit 7
> に置き、`gate_control.ctrlA` のフラグ byte は触っていません
> (`DECISIONS.md` D14)。Python API は
> `set_compressor_settings(threshold=, ratio=, response=, makeup=,
> enabled=)` / `get_compressor_settings()`、makeup byte は
> `round(makeup * 127 / 100)` で `[0, 127]` の Q7。Notebook
> (`GuitarPedalboardOneCell.ipynb`) には Comp Off / Light Sustain /
> Funk Tight / Lead Sustain / Limiter-ish の 5 プリセットを追加済み
> です。参考にした OSS (`harveyf2801/AudioFX-Compressor`、
> `bdejong/musicdsp`、`DanielRudrich/SimpleCompressor`、
> `chipaudette/OpenAudio_ArduinoLibrary`、`p-hlp/SMPLComp` (GPL)、
> `Ashymad/bancom` (GPL)) はパラメータ命名と設計思想のみ参照しており、
> ソースコードのコピーは行っていません。詳しくは `DECISIONS.md` D14、
> `DSP_EFFECT_CHAIN.md` Compressor 節、`GPIO_CONTROL_MAP.md` Compressor
> 節を参照。Noise Suppressor、Distortion Pedalboard、`set_guitar_effects`
> の互換 API は壊さないでください。

## Chain presets work — Python / notebook only, no bitstream rebuild

> Chain presets (Safe Bypass / Basic Clean / Clean Sustain / Light
> Crunch / Tube Screamer Lead / RAT Rhythm / Metal Tight / Ambient
> Clean / Solo Boost / Noise Controlled High Gain) は
> `audio_lab_pynq/effect_presets.py` の `CHAIN_PRESETS` に定義され、
> `AudioLabOverlay.apply_chain_preset(name)` /
> `get_chain_preset_names()` / `get_chain_preset(name)` /
> `get_current_pedalboard_state()` から駆動します。新規 GPIO や
> Clash 段は追加しておらず、既存セクションの set_*_settings /
> set_guitar_effects を組み合わせて適用するだけです。bit/hwh は
> 触らない / Vivado / Clash は実行しない (`DECISIONS.md` D15)。
> プリセット追加時の安全契約: Compressor `makeup` は 45..60、
> Distortion `level` <= 35、Safe Bypass は全 section enabled=False
> + reverb.mix=0。これらは `tests/test_overlay_controls.py` で
> 強制されているので、勝手に緩めないでください。Notebook 側
> (`GuitarPedalboardOneCell.ipynb`) は Chain Preset dropdown + Apply
> Chain Preset / Show Current State ボタンを持っており、原則 2 セル
> 構成。既存 Compressor / Noise Suppressor / Distortion UI は
> 触らないこと。

## Real-pedal voicing pass — deployed

> 既存エフェクトを実機ペダル/アンプ/キャビネットの voicing に寄せる
> 調整パスを実施済みです。新規 GPIO / 新規 `topEntity` ポート /
> 新規 Clash ステージは追加していません (`DECISIONS.md` D16)。
> `LowPassFir.hs` の中の既存ステージの定数とクリップ関数だけを差し
> 替えています。狙いと変更箇所の一覧は
> `docs/ai_context/REAL_PEDAL_VOICING_TARGETS.md` を参照してください。
> 主な変更:
> - Overdrive: `softClip` -> `asymSoftClip` (kneeP=3.3M / kneeN=2.9M)
> - clean_boost: drive ceiling ~5x -> ~4x、安全 clip knee 4.2M -> 3.2M
> - tube_screamer: 入力 HPF alpha 範囲を 3..18 に拡大、drive ~9x -> ~7x、
>   asym knee を `2_900_000 / 2_500_000` に下げ、post LPF を `64..191`
> - rat: hard clip floor を `2_500_000` に、`ratPostLowpassFrame`
>   alpha 192 -> 176、tone alpha base 224 -> 200
> - metal: HPF alpha 範囲を 6..37 に拡大、drive ~22x -> ~19x、
>   clip floor 1.2M -> 1.5M、post LPF を `48..175`
> - Compressor: soft-knee オフセット (`threshold - threshold/4`)、
>   reduction slope を `excess >> 12` に
> - Noise Suppressor: 閾値ヒステリシス (`closeT = threshold -
>   threshold/4` + 現 gain register の中点比較) でチャタリング抑制
> - Cab IR: 4-tap 係数の c0 を低めに、c1/c2 を高めに rebalance
> - Reverb: tone byte をスケール (`tone - tone>>3`、最大 224)
> - EQ: 出力 mix に `softClip` を追加 (3-band 全 boost で過大歪みを起こさない)
>
> ビルド結果: WNS = -6.405 ns (前回 Compressor build の -7.516 ns
> より +1.111 ns 改善)、TNS = -8806.714 ns、WHS = +0.052 ns、
> THS = 0.000 ns。`R19_ADC_CONTROL = 0x23` 維持、ADC HPF default-on
> 維持、10 chain preset すべて smoke-test pass。商用ペダル/アンプの
> 回路コピーや GPL DSP コードの移植は行っていません。

## Amp/Cab real-voicing pass — deployed

> Amp Simulator / Cab IR の実機寄せ voicing pass は
> `feature/amp-cab-real-voicing` で実装済み・deploy 済みです。
> 新規 GPIO / 新規 `topEntity` ポート / 新規 Clash register stage /
> `block_design.tcl` 変更はありません。GPIO 名 / address / ctrlA-D
> 割り当ても変更なし。`LowPassFir.hs` では `ampHighpassFrame`、
> `ampDriveMultiplyFrame`、`ampAsymClip`、`ampPreLowpassFrame`、
> `ampSecondStageMultiplyFrame`、`ampPowerFrame`、
> `ampResPresenceProductsFrame` / `ampResPresenceMixFrame`、
> `ampMasterFrame`、`cabCoeff` を既存 stage 内で retune しています。
> Cab model 0 = 1x12 open back、model 1 = 2x12 combo、model 2 =
> 4x12 closed back。`air` は capped high return で、raw line には戻り
> ません。Chain Presets は Basic Clean / Clean Sustain / Light Crunch
> を model 0 寄り、Metal / Big Muff / Fuzz を model 2 寄りに調整済み。
> build 結果: WNS=-7.917 ns、TNS=-13100.457 ns、WHS=+0.051 ns、
> THS=0.000 ns。PYNQ deploy と preset smoke test pass、ADC HPF=True /
> `R19_ADC_CONTROL=0x23`。商用アンプ回路 / commercial cab IR /
> GPL DSP コードはコピーしていません。次に Amp/Cab を触る場合も
> `GPIO_CONTROL_MAP.md` と `DECISIONS.md` D17 を読んでから、既存
> stage 内の定数変更に留めてください。

## Notebook UI / preset polish (no bitstream rebuild)

> Notebook だけの編集は bit/hwh 再生成不要です。対象 Notebook:
> `GuitarPedalboardOneCell.ipynb` (1セル UI)、
> `GuitarEffectSwitcher.ipynb` (既存 UI + Distortion Pedalboard 追加部)、
> `DistortionModelsDebug.ipynb` (pedal API walkthrough)。
> Python API の変更は不要です。`LowPassFir.hs` / `AudioLabOverlay.py` /
> bit/hwh は触らずに、Notebook と必要なら `docs/ai_context/` を更新し、
> `bash scripts/deploy_to_pynq.sh` で配置してください。

## PYNQ deploy

> deploy は `PYNQ_HOST=192.168.1.9 bash scripts/deploy_to_pynq.sh` を
> 使ってください。実機 Python 実行は
> `sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 ...` を経由
> してください。Vivado 実装で WNS が現行 deploy(-8.155 ns)より明らかに
> 悪い bitstream は deploy しないでください。

## Internal mono DSP pipeline — deployed

> `feature/internal-mono-dsp-pipeline` で、外部 AXI/I2S 48-bit stereo
> I/O と `topEntity` interface は維持したまま、DSP内部の主経路を
> ADC Left 由来の mono source に整理済みです。Right input は未接続
> ノイズ回避のため破棄し、最終 mono result を output L/R に複製します。
> `block_design.tcl`、GPIO、Python API、Notebook、Chain Preset は変更
> していません。TLAST は `Frame.fLast` で入力から出力へ伝搬し、
> `AudioLab.Pipeline` は DMA backpressure で出力 frame/TLAST を落とさない
> よう accepted input を clock-domain pace します。
>
> Build/deploy: local tests、Notebook JSON、Clash/VHDL、IP repackage、
> Vivado bit/hwh、deploy、normal PYNQ smoke は pass。Timing:
> WNS=-8.155 ns、TNS=-6492.876 ns、WHS=+0.052 ns、THS=0.000 ns。
> Utilization: Slice LUTs 15473、Slice Registers 14914、BRAM Tile 7、
> DSPs 83。DMA確認は PYNQ reboot 後に 1 overlay load / 1 composite DMA
> packet で Case A (Left nonzero / Right different)、Case B (Left zero /
> Right large)、Case C (Right inverted noise) を実施し、timeoutなし。
> send/recv DMASR はどちらも `0x00001002`、skip_frames=16 以降の
> output L/R は完全一致、Right input rejection も確認済み。
>
> 次に触る場合は、内部 mono 方針と AXI TLAST 伝搬を壊さないこと。
> DMA timeout が再発した場合は、まず `AudioLab.Axis` /
> `AudioLab.Pipeline` の AXI metadata と accepted-frame pacing を確認して
> ください。DSP係数や effect voicing の変更と混ぜないでください。

## Codec / input debug

> 入力ノイズや DC offset を疑う場合は、`AUDIO_SIGNAL_PATH.md` の
> triage を上から確認してください。ADC HPF は既定 ON
> (`R19_ADC_CONTROL == 0x23`) です。`InputDebug.ipynb` で HPF を
> toggle した直後の peak_abs は IIR 整定中の過渡なので、
> `settling_ms=400` と `discard_initial_frames=2400` を使ってください。

## Documentation update

> `docs/ai_context/` は実装と一緒に更新してください。仕様や運用が
> 変わったら、関連 Markdown を更新するコミットを別に切ってください。
> 触ってよいファイルは `AGENTS.md` / `CLAUDE.md` / `docs/` 配下のみ。
> 実装ファイルや bitstream を巻き込まないでください。
