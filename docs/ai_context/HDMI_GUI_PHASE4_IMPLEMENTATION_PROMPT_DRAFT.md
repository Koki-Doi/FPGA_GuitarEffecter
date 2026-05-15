# HDMI GUI Phase 4 implementation prompt draft

Date: 2026-05-14

Status: **DRAFT — do not execute without explicit user approval.**

Phase 3 only proposes the Vivado integration; this file packages the
Phase 4 work into a single self-contained prompt the user can paste back
to a future session once they decide to ship the block-design change.

## Pre-flight requirements (the user must confirm before starting Phase 4)

- The Phase 3 design proposal in
  `docs/ai_context/HDMI_GUI_PHASE3_VIVADO_DESIGN_PROPOSAL.md` is the
  agreed-upon plan. Option B (`axi_vdma` + `v_tc` + `rgb2dvi`) is
  approved.
- `hw/Pynq-Z2/block_design.tcl` is no longer off-limits for this
  branch only. The user has explicitly removed the
  `block_design.tcl off-limits` constraint for the Phase 4 task.
- Backup of `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}` to a dated
  path is acceptable.
- New AXI-Lite address candidates (`0x43CE0000`, `0x43CF0000`,
  `0x43D00000`) are acceptable for the new IPs.
- Audio-domain WNS deploy gate is unchanged
  (`TIMING_AND_FPGA_NOTES.md`): a Phase 4 bit may be deployed only
  if WNS is not significantly worse than the latest deployed
  baseline (`-8.155 ns`).

## Prompt (copy / paste)

> HDMI GUI 統合の Phase 4 を実施してください。
> 前提: Phase 2D bridge runtime test と Phase 3 Vivado 設計案は
> 完了済みです。Option B (`axi_vdma` + `v_tc` + `v_axi4s_vid_out` +
> `rgb2dvi`) を採用します。
>
> 必ず最初に読んでください:
> - `CLAUDE.md`
> - `docs/ai_context/PROJECT_CONTEXT.md`
> - `docs/ai_context/CURRENT_STATE.md`
> - `docs/ai_context/DECISIONS.md`
> - `docs/ai_context/TIMING_AND_FPGA_NOTES.md`
> - `docs/ai_context/GPIO_CONTROL_MAP.md`
> - `docs/ai_context/BUILD_AND_DEPLOY.md`
> - `docs/ai_context/PYNQ_RUNTIME.md`
> - `docs/ai_context/HDMI_GUI_INTEGRATION_PLAN.md`
> - `docs/ai_context/HDMI_GUI_PHASE2D_BRIDGE_RUNTIME_TEST.md`
> - `docs/ai_context/HDMI_GUI_PHASE3_VIVADO_DESIGN_PROPOSAL.md`
> - `docs/ai_context/HDMI_BLOCK_DESIGN_TCL_PATCH_PLAN.md`
>
> 作業ブランチ: `feature/hdmi-vivado-integration` を main / master から
> 切ってください。Phase 4 のあいだだけ
> `hw/Pynq-Z2/block_design.tcl` の編集はユーザの明示承認のもとで許可
> されます。Phase 4 が終わったらこの例外は閉じます。
>
> 実装:
> 1. `hw/Pynq-Z2/bitstreams/audio_lab.{bit,hwh}` を
>    `audio_lab.bit.pre-hdmi-<date>` / `audio_lab.hwh.pre-hdmi-<date>`
>    にバックアップしてください。
> 2. `hw/Pynq-Z2/block_design.tcl` に
>    `docs/ai_context/HDMI_BLOCK_DESIGN_TCL_PATCH_PLAN.md` で指定されている
>    変更を追加してください。具体的には:
>    - 新規 `clk_wiz_hdmi`
>      (`pixel_clk` 74.25 MHz, `serial_clk` 371.25 MHz, BUFG)
>    - 新規 `proc_sys_reset_hdmi`
>    - `axi_vdma`, `v_tc`, `v_axi4s_vid_out`, `rgb2dvi` インスタンス
>    - `processing_system7_0` の `PCW_USE_S_AXI_HP0 {1}` 化と
>      `S_AXI_HP0` のクロック / リセット接続
>    - `axi_smc` または 新規 SmartConnect を介した
>      `axi_vdma.M_AXI_MM2S -> S_AXI_HP0`
>    - `ps7_0_axi_periph` `NUM_MI` 拡張 (15 -> 17) と
>      VDMA / VTC の AXI-Lite control 接続
>    - VDMA `M_AXIS_MM2S -> v_axi4s_vid_out -> rgb2dvi`
>    - `v_tc -> v_axi4s_vid_out` / `v_tc -> rgb2dvi`
>    - top-level に TMDS 出力ポート追加
> 3. `hw/Pynq-Z2/audio_lab.xdc` に:
>    - PYNQ-Z2 HDMI TX (`TMDS_clk_p/n`, `TMDS_data_p/n[2:0]`) の
>      pin assignments
>    - `set_false_path` between `clk_fpga_0` and new
>      `pixel_clk` / `serial_clk`
> 4. address segments:
>    - `axi_vdma/S_AXI_LITE` -> `0x43CE0000`, range `0x00010000`
>    - `v_tc/CTRL` -> `0x43CF0000`, range `0x00010000`
>    - `rgb2dvi/CTRL` -> `0x43D00000`, range `0x00010000`
>      (該当する場合)
>    既存 AXI GPIO address / `ctrlA`-`ctrlD` semantics / name は
>    一切変更しないこと。`axi_gpio_delay` は名前そのままで残すこと。
> 5. `audio_lab_pynq/HdmiOutput.py` を追加:
>    - `class AudioLabHdmiBackend(overlay)`
>    - `pynq.allocate(shape=(720, 1280, 4), dtype=numpy.uint8, cacheable=False)`
>    - VDMA レジスタ初期化
>    - `start(mode='1280x720@60')` / `stop()` / `write(frame_rgb)`
>    - frame_rgb は `(720, 1280, 3)` `uint8`; XRGB へのコピーは
>      `fb[:, :, :3] = frame_rgb; fb[:, :, 3] = 0` で十分
> 6. Vivado bitstream build: `bash hw/Pynq-Z2/Makefile` 経由
>    (`make` 直接でも可)。
> 7. Timing summary を取得:
>    - audio domain (`clk_fpga_0`) の WNS / TNS / WHS / THS
>    - pixel domain (`pixel_clk`) の WNS / TNS / WHS / THS
>    - serial domain (`serial_clk`) の WNS / TNS / WHS / THS
>    audio WNS が baseline -8.155 ns から significantly 悪化した
>    bitstream は deploy しないこと。
>    `TIMING_AND_FPGA_NOTES.md` に新ビルドの行を追加してください。
> 8. PYNQ deploy: `PYNQ_HOST=192.168.1.9 bash scripts/deploy_to_pynq.sh`
> 9. PYNQ smoke test:
>    - `AudioLabOverlay()` を 1 回だけロード
>    - `overlay.codec.get_adc_hpf_state() == True`
>    - `overlay.codec.R19_ADC_CONTROL[0] == 0x23`
>    - `hasattr(overlay, 'axi_gpio_delay_line') == False`
>    - `hasattr(overlay, 'axi_gpio_delay') == True`
>    - `hasattr(overlay, 'axi_vdma_hdmi') == True` (新)
>    - `apply_chain_preset('Safe Bypass')` / `'Basic Clean'` /
>      `'Tube Screamer Lead'` 適用 OK
>    - Phase 2D の bridge runtime test (
>      `/tmp/hdmi_gui_phase2d/run_phase2d_bridge_test.py`) が通ること
> 10. HDMI 静止 1 フレーム表示: `render_frame_pynq_static(AppState())`
>     を `AudioLabHdmiBackend.write(...)` 経由で出力し、音は通り続ける
>     ことを確認してください。
> 11. ローカル `python3 -m compileall audio_lab_pynq scripts GUI`、
>     `python3 tests/test_overlay_controls.py`、
>     `python3 tests/test_hdmi_gui_bridge.py` を pass させてください。
> 12. 結果を `docs/ai_context/HDMI_GUI_PHASE4_*` に記録し、
>     `CURRENT_STATE.md` / `RESUME_PROMPTS.md` を更新してください。
>
> 禁止事項 (引き続き):
> - `Overlay("base.bit")`
> - `AudioLabOverlay()` の後の別 Overlay() ロード
> - 既存 GPIO address / name / `ctrlA`-`ctrlD` semantics 変更
> - GPIO `axi_gpio_delay` の rename
> - `axi_gpio_delay_line` の新規追加
> - `topEntity` / Clash port / DSP 動作の変更
> - GPL / 商用ペダル / 商用 IR / 商用回路の source コピー
> - `git push` / `git pull` / `git fetch`
> - WNS が baseline 比で大幅に悪化した bitstream の deploy
>
> rollback:
> - Vivado build 失敗時は backup を戻し
>   `bash scripts/deploy_to_pynq.sh` で audio-only bit を再 deploy
> - PYNQ smoke 失敗時も同様にロールバック
> - git revert で feature branch 上の Phase 4 commit を巻き戻す
>
> 最終報告に含める項目:
> - 作業ブランチ名
> - 追加した IP 一覧と address
> - timing summary (audio / pixel / serial)
> - utilization
> - PYNQ smoke 結果
> - HDMI 表示の様子
> - audio passthrough の様子
> - bitstream backup の場所
> - `git push` していないこと
