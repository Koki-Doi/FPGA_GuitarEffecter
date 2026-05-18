# Current state

Last updated: **2026-05-18 (Phase 7D close-out + PCM5102 quality follow-up plan): PCM1808 mux flipped back to ADAU pending hardware diagnosis; SCKI moved off JB1 onto JB8**
(Phase 7D first attempt picked PCM1808 as the build-time ADC source via
the `pcm1808_input_select` mux and put PCM1808 SCKI back on JB1
12.288 MHz. On the bench this re-broke PCM5102 (audible graininess
from JB1's MCLK cross-coupling to PCM5102 SCK that was nominally
tied to GND on the module, DECISIONS.md D40 / D42). The fix: PCM1808
SCKI moved to a dedicated `ext_pcm1808_sckie_o` port on PMOD JB8 /
W16 (driven directly from `clk_wiz_audio_ext/clk_out1` in
`pcm1808_adc_integration.tcl`), and `pcm5102_audio_out.v` keeps
`ext_audio_mclk_o = 1'b0` so JB1 stays low structurally regardless
of any physical SCK wiring. PCM5102 now plays inject-sine cleanly.
PCM1808's `capture-adc` returns pure zeros even with smartphone
line-in connected and mode straps confirmed at I2S Philips slave
(MD0=MD1=FMT=GND); the chip is alive enough to clock out I2S
frames (finger-touch test grounds EMI to 0) but does not encode
analog input -- suspect chip / analog-front-end damage from the
earlier 3.3V-on-VCC misconnection that brown-out'd the PMOD rail.
The deployed Phase 7D bit therefore flips the build-time mux
constant back to **CONST_VAL=0 (ADAU)** so the input path is the
known-good Phase 7E ADAU-mirror configuration; flipping back to
PCM1808 needs only `CONFIG.CONST_VAL {1}` in
`pcm1808_adc_integration.tcl` and a rebuild. User confirmed:
ADAU Line In -> AudioLab DSP -> PCM5102 line out works on the bench
(minor audio-quality nits remain, deferred). PCM5102 SCK still GND
(D40 / D42 preserved). Follow-up diagnosis concluded that the first
non-physical improvement should be a build variant / option that drives
`ext_pcm1808_sckie_o` low when PCM1808 is not the active ADC source,
because the deployed mux=ADAU bit still emits 12.288 MHz on JB8 and
that pin sits adjacent to PCM5102 DIN on JB7. The second follow-up is a
PCM5102 debug output mode (`processed audio` / digital silence /
`-18 dBFS` 1 kHz tone / ramp) to separate DSP, I2S, and analog-output
faults before any further audio-path edits. HDMI / encoder /
GPIO_CONTROL_MAP / LowPassFir untouched in this planning pass.
DECISIONS.md D41 / D42 / D43 / D44.

Previous-pass header (Phase 7D first attempt):
**PCM1808 external ADC inserted as default input source via a build-time wire mux**
(new RTL `hw/ip/pcm1808_adc_input/src/pcm1808_input_select.v` is a 2:1
combinational mux between the existing ADAU1761 `sdata_i` port and the
new PCM1808 DOUT input port `ext_adc_dout_i` (JB4 / T10). The mux
output drives the existing `i2s_to_stream_0/si` pin, so the AXIS DSP
chain is bit-for-bit unchanged regardless of which ADC source is
selected. `sel_external_i` is tied to `1'b1` by an `xlconstant` in
`hw/Pynq-Z2/pcm1808_adc_integration.tcl` -- Phase 7D bring-up default
is PCM1808; flipping the constant to 0 and rebuilding falls back to
ADAU1761. The Phase 7E SCK-low compensation in `pcm5102_audio_out.v`
is reverted: `ext_audio_mclk_o` again carries the 12.288 MHz from
`clk_wiz_audio_ext`, but JB1 now drives **PCM1808 SCKI** -- PCM5102
SCK is physically hard-tied to GND on the module per the new Phase 7D
board rewiring, so the wizard output no longer affects PCM5102.
Output side untouched: ADAU1761 DAC and PCM5102 DAC still receive
the same `i2s_to_stream_0/so` bitstream in parallel. HDMI / encoder
integration / GPIO_CONTROL_MAP / LowPassFir DSP all untouched. bit/
hwh rebuilt, deploy PASS, on-board smoke
(`scripts/test_pcm1808_adc_to_pcm5102.py`) PASS. Known caveat
(DECISIONS.md D41): PCM1808 SCKI is NOT bit-true synchronous to BCK
(same async-clocks risk that hit PCM5102 in Phase 7E); PCM1808 lacks
a PCM510x-style internal-PLL fallback, so if the bench shows audible
graininess the next step is to make the FPGA the I2S master.

Previous-pass header (Phase 7E follow-up):
**PCM5102 SCK tied LOW to fix MCLK/BCK async jitter**
(initial Phase 7E `9f21546` mirrored ADAU1761 I2S onto PMOD JB while keeping
the Phase 7C 12.288 MHz `clk_wiz_audio_ext` driving PCM5102 SCK. On the
real board the resulting audio had audible graininess / periodic jitter
because the 12.288 MHz MCLK comes from the PS 100 MHz PLL and BCK comes
from the ADAU1761 PLL -- the two are not bit-true synchronous and
PCM510x external-SCK locking drifted in and out. `pcm5102_audio_out.v`
now drives `ext_audio_mclk_o = 1'b0`; PCM510x therefore enters its
internal-SYSCLK mode and derives sysclk from BCK alone. The
`clk_wiz_audio_ext` instance is left in `pcm5102_dac_integration.tcl`
for future PCM1808 SCKI use, but its output has no consumer in this bit
and gets optimised away during synth. Timing improved (WNS -8.004 ns
vs the earlier -8.724 ns) because the unused 12.288 MHz domain was
pruned. ADAU1761 ADC / DSP chain / HDMI / encoder all still untouched.
`DECISIONS.md` D40.

Previous-pass header (Phase 7E initial bring-up, jitter known):
**Phase 7E PCM5102 now carries the existing AudioLab DSP output (parallel to ADAU1761 DAC)**
(new RTL module `hw/ip/pcm5102_audio_out/src/pcm5102_audio_out.v` is a
trivial 4-signal pass-through that mirrors the existing ADAU1761 I2S
DAC interface onto the four PMOD JB pins: `JB2 BCK <- bclk` (input
port, R18), `JB3 LCK <- lrclk` (input port, T17), `JB7 DIN <-
i2s_to_stream_0/so` (same serial DAC data that drives ADAU `sdata_o`
at G18), and `JB1 MCLK <- clk_wiz_audio_ext/clk_out1` (12.288 MHz from
the Phase 7C MMCM). The Phase 7C free-running tone module
`pcm5102_dac_tone` is **no longer instantiated** by the block design
(file kept in repo as a known-good debug reference). PCM5102 therefore
now receives bit-for-bit the same processed audio the ADAU1761 DAC
receives -- both DACs stream in parallel and either can be used as
the listening source. **PCM1808 ADC is NOT implemented (Phase 7D
still pending).** ADAU1761 ADC path / DSP chain (`i2s_to_stream_0` /
`axis_data_fifo_0` / `clash_lowpass_fir_0` / `axis_switch_*` /
`axi_dma_0`) untouched. HDMI integration / encoder integration /
GPIO_CONTROL_MAP / LowPassFir DSP untouched. bit/hwh rebuilt, deploy
PASS, on-board smoke (`scripts/test_pcm5102_dsp_output.py`) PASS:
ADC HPF True, all required IPs intact, no overlay regression.
DECISIONS.md D39.

Previous-pass header (Phase 7C):
**Phase 7C PCM5102 external DAC bring-up landed (DAC-only)**
(new RTL module `hw/ip/pcm5102_dac_tone/src/pcm5102_dac_tone.v` is a
free-running I2S master that emits a 1 kHz / 24-bit / quarter-scale sine
to both stereo channels at 48 kHz fs. A new MMCM
(`clk_wiz_audio_ext`, `100 MHz -> 12.288 MHz exact` via
`DIVCLK_DIVIDE=5, MULT_F=48.0, CLKOUT0_DIVIDE_F=78.125, VCO=960 MHz`)
drives the module. The four signals come out of PMOD JB:
JB1 W14 MCLK / JB2 Y14 BCLK / JB3 T11 LRCLK / JB7 V16 DIN
(LVCMOS33, no PULLUP, added to `audio_lab.xdc`). New tcl
`hw/Pynq-Z2/pcm5102_dac_integration.tcl` sourced from
`create_project.tcl` after `encoder_integration.tcl`. NO AXI-Lite
slave, NO new GPIO, NO change to the ADAU1761 path, HDMI integration,
encoder integration, GPIO_CONTROL_MAP, or LowPassFir DSP. PCM1808
ADC is **NOT** implemented (Phase 7D). bit/hwh rebuilt and deployed.
Smoke `scripts/test_pcm5102_dac_tone.py` PASS on PYNQ (overlay loads,
all required existing IPs intact, encoder IP visible as
`enc_in_0/s_axi`, no overlay regression). LCD GUI / encoder GUI not
re-verified visually yet on this build but no Python or notebook
changed; only Python touched is the new smoke script. `DECISIONS.md`
D38.

Previous-pass header (revert era):
**GUI catalog / HDMI shim refactor reverted after LCD display regression**
(reverted three commits — `ee0bc93` *Avoid encoder GUI overlay redownload*,
`4d141a0` *Start encoder HDMI GUI with initial frame*, `bef00b2` *Refactor
GUI catalog and HDMI shims* — because `EncoderGuiSmoke.ipynb` stopped
showing the GUI on the LCD after the refactor landed. Baseline restored
is `6524d1f` *Docs sweep for Phase 7G+ encoder GUI live apply (D37)*
plus the three revert commits (`70f86df` / `93c1e0c` / `63b8cd9`).
No bit / hwh / RTL / XDC / block-design / Vivado / DSP change; only
Python + notebook + docs touched. The single-cell `EncoderGuiSmoke.ipynb`
shape (Encoder1/2/3 + AudioLabOverlay + EncoderInput + ResourceSampler +
`backend.stop`) is preserved. Next time the GUI catalog / HDMI shim
refactor is attempted, display verification on the LCD must be a gating
step at every commit boundary.

Previous-pass header (refactor era, now reverted):
**Phase 7G+ encoder GUI-first live apply added**
(new module `audio_lab_pynq/encoder_effect_apply.py` translates the
compact-v2 AppState into `AudioLabOverlay` public setters with a 100 ms
default throttle; `EncoderUiController` gained `applier=` / `live_apply=`
/ `skip_rat=` kwargs; `scripts/run_encoder_hdmi_gui.py` and the
single-cell `EncoderGuiSmoke.ipynb` were rewritten around the dirty-flag
loop with the new applier; RAT pedal-mask bit 2 is excluded from
encoder cycling and live apply by default — the Clash stage and the
notebook `HdmiEffectStateMirror` API remain untouched. Earlier baseline
commits `5332b7e` / `3afd9c4` / `e2ece2e` brought the Phase 6I C2 baseline up;
`d1c4e8e` thinned `set_guitar_effects` into a 6-helper facade;
`52c5ea4` extracted the 1727-line `hdmi_effect_state_mirror.py` into
the `audio_lab_pynq/hdmi_state/` subpackage; `5173baf` extracted the
1685-line `GUI/pynq_multi_fx_gui.py` into the `GUI/compact_v2/`
subpackage; `c7a8680` added the rotary encoder input IP and the
follow-up deploy smoke added the encoder Notebook and PYNQ Python 3.6
compatibility fixes. See `DECISIONS.md` D26 / D33 / D35).

**Planning-only addition (2026-05-18, post Phase 7D close-out)**:
Digilent **Pmod I2S2** (CS4344 stereo DAC + CS5343 stereo ADC on one
PMOD board) has been ordered and will be evaluated as a stable external
I2S I/O reference before any further PCM1808 work. The full design /
phase / pin / test plan lives in
`docs/ai_context/PMOD_I2S2_INTEGRATION_PLAN.md`. No RTL / XDC / Tcl /
Vivado / bit/hwh / Python / Notebook change has been made for this;
deployed bit is still the Phase 7D close-out `f502373` series. PCM5102
SCK = GND (D40 / D42), PCM1808 mux = ADAU (D43), Phase 7D close-out
WNS `-7.931 ns`. See `DECISIONS.md` D45.

## Current load-bearing facts

- **HDMI signal**: VESA SVGA `800x600 @ 60 Hz`, pixel clock
  `40.000 MHz`, `H total 1056`, `V total 628`, `rgb2dvi kClkRange=3`
  (`DECISIONS.md` D25). Not 720p, not native 800x480.
- **Framebuffer**: `audio_lab_pynq/hdmi_backend.py` defaults to
  `DEFAULT_WIDTH=800`, `DEFAULT_HEIGHT=600`. The 800x480 compact-v2
  GUI composes at framebuffer `(0,0)` (top 480 rows = UI, bottom 120
  rows = black). VDMA: `HSIZE=2400, STRIDE=2400, VSIZE=600`.
- **GUI renderer**: `GUI/pynq_multi_fx_gui.py::render_frame_800x480_compact_v2`
  + the (1).py-spec `EFFECT_KNOBS` / `AppState.all_knob_values` /
  `hit_test_compact_v2()` API from Phase 6H port (`DECISIONS.md` D24).
  The renderer is split per-theme under `GUI/compact_v2/{knobs, state,
  layout, renderer, hit_test}.py`; `GUI/pynq_multi_fx_gui.py` is a
  120-line re-export shim. `DECISIONS.md` D26.
- **HDMI GUI state mirror**: `audio_lab_pynq/hdmi_effect_state_mirror.py`
  still exports `HdmiEffectStateMirror` and every public helper, but
  the constants / normalisation helpers / `ResourceSampler` live under
  `audio_lab_pynq/hdmi_state/{pedals, amps, cabs, selected_fx, knobs,
  resource_sampler, common}.py`. `DECISIONS.md` D26.
- **`set_guitar_effects()`**: thin facade over 6 private helpers
  (`_require_effect_gpios`, `_merge_cached_distortion_state`,
  `_merge_cached_noise_suppressor_state`, `_write_effect_gpios`,
  `_refresh_cached_words`, `_route_effect_chain`). Behaviour and return
  value byte-for-byte preserved from the pre-split implementation.
  `DECISIONS.md` D26.
- **Notebook runtime**: `audio_lab_pynq/notebooks/HdmiGui.ipynb`
  (live loop, resource monitor, `OFFSET_X` / `OFFSET_Y` calibration)
  and `audio_lab_pynq/notebooks/HdmiGuiShow.ipynb` (one-shot,
  smart-attach via `download=False` when bit already loaded —
  protects the rgb2dvi PLL at the 800 MHz VCO lower edge from
  re-`download=True` knock-outs in the same Jupyter session).
- **PL timing baseline**: WNS `-8.096 ns`, TNS `-6389.430 ns`,
  WHS `+0.040 ns`, THS `0.000 ns`; Slice LUTs `18618 (35.00%)`,
  Slice Registers `20846 (19.59%)`. Within the historical
  `-7..-9 ns` deploy band. See `TIMING_AND_FPGA_NOTES.md`.
- **Encoder GUI live apply (Phase 7G+)**: `EncoderEffectApplier` is the
  only Python object allowed to translate the compact-v2 `AppState`
  into `AudioLabOverlay` calls from the encoder runtime. It uses
  `set_noise_suppressor_settings`, `set_compressor_settings`, and a
  single `set_guitar_effects(**kwargs)` per push — no raw GPIO writes.
  Throttle defaults to 100 ms (`--apply-interval-ms`); encoder 3 short
  press always force-applies regardless of the throttle. RAT
  (`distortion_pedal_mask` bit 2) is suppressed when `skip_rat=True`
  (default); pass `--include-rat` to override. EQ knob values are
  mapped GUI 0..100 → overlay 0..200 (50 == unity). Cab `MODEL` knob
  is overridden by `AppState.cab_model_idx` (0..2). RAT remains
  available via `HdmiEffectStateMirror.rat()` from notebooks; only
  the encoder loop refuses to touch it.
- **Encoder GUI render loop**: `scripts/run_encoder_hdmi_gui.py` and
  `audio_lab_pynq/notebooks/EncoderGuiSmoke.ipynb` share a dirty-flag
  loop — poll at 10 Hz while events are arriving, drop to 4 Hz after
  1 s of silence, render only when the AppState signature changes, cap
  at 5 fps even under continuous rotation. Idle `proc_cpu` measured
  at ~0–1% on the deployed PYNQ-Z2 image during the dry-run smoke.

## Phase history (chronological)

Phase 4 integrated HDMI framebuffer deployed; Phase 4C profiled the
deployed bit; Phase 4D added LCD fit modes; Phase 4E tested the
800x480 logical GUI; Phase 4F added manual viewport calibration;
Phase 4G shipped compact-v2 + negative-offset placement; Phase 4H
added vertical safe margins + a layout-debug overlay; Phase 4I rolled
back Phase 4H's chassis push-down to the 4G baseline; Phase 4J's
horizontal-only negative-offset sweep was left uncommitted, superseded
by Phase 5A. Phase 5A started HDMI output-side diagnosis for the
5-inch 800x480 LCD; Phase 5C locked the user-confirmed
`x=0,y=0,w=800,h=480` viewport default on the PYNQ-Z2 at
`192.168.1.9`; the post-5C cleanup kept active `GUI/` and removed the
legacy untracked `HDMI/` tree. Phase 5D added the Pip-Boy-inspired
phosphor-green theme + soft scanline overlay on the (then) 1280x720
path. Phase 6F rechecked the recurring right-shift report (bbox /
backend / framebuffer all `(0,0)`); Phase 6G added strong-UI-bbox
diagnostics + an actual-UI visual test (intermediate renderer
x-tightening was rolled back). Phase 6H (`d7ea0ab`) ported the
compact-v2 renderer to the (1).py spec (single `EFFECT_KNOBS` dict,
inline PEDAL / AMP / CAB model dropdown, Phase 4G / 4I baseline
coordinates restored). The subsequent Phase 6H native 800x480 / 40 MHz
timing pass was **rejected** on the LCD (white screen) and never
committed. Phase 6I rolled back to 720p, swept candidate timings, and
deployed **VESA SVGA 800x600 @ 60 Hz / 40 MHz** as the working HDMI
signal — same H/V totals as the rejected Phase 6H, but with
SVGA-standard 800x600 active that the LCD's HDMI receiver actually
recognises. The Phase 5D / 6F references to a "1280x720 HDMI signal"
below this paragraph describe what was true at those phases; the
current signal is the Phase 6I SVGA 800x600 path.

Detailed CURRENT_STATE-flavoured snapshots from earlier phases were
moved out of this file to keep it short. Read them only when an old
phase is the load-bearing reference:

- `history/current_state/PHASE_6F_TO_6I_DETAIL.md` — dated 2026-05-16
  paragraphs for Phase 6F (recurrence check), Phase 6G (actual UI
  x-origin fix, partially rolled back), Phase 6H (1).py spec port +
  rejected native 800x480 timing, Phase 6I HDMI timing sweep with
  C2 SVGA 800x600 deployed.
- `history/current_state/HDMI_GUI_HISTORY.md` — Phase 4 / 4C / 4D /
  4E / 4F / 4G / 4H / 4I / 4J / 5A / 5C / 5D HDMI GUI snapshots and
  the original "HDMI GUI integration planning" prose, plus the
  Phase 1 / 2A / 2B / 2C / 2D / 3 render-bench / PYNQ-compat /
  bridge-plan / bridge-runtime / Vivado-design-proposal snapshots.
- `history/current_state/DSP_AND_VOICING_HISTORY.md` — internal mono
  DSP pipeline, LowPassFir behavior-preserving split, Amp Simulator
  fizz-control and named-model passes, audio-analysis voicing fixes,
  Amp/Cab real voicing, reserved-pedal implementation, real-pedal
  voicing pass, chain presets, compressor add, the earlier
  effect-chain refactor, plus the post-reserved-pedal Headline /
  Working tree / Live verification / Vivado timing / Notebooks
  snapshot.
- `history/current_state/PHASE_7_PLANNING_HISTORY.md` — Phase 7A
  (external codec + encoder planning), Phase 7B (module verification
  + candidate package pin docs), and the Phase 7F/7G encoder PL IP +
  Python driver + HDMI GUI control implementation log.

Per-phase plan / result memos for the HDMI arc are still in the
sibling `history/hdmi_phases/` directory; the snapshots above are
the CURRENT_STATE-flavoured prose of the same milestones.

## PYNQ-Z2 network identity

The lab board should be kept at a stable router DHCP reservation:

| Field | Value |
| --- | --- |
| Device name | `PYNQ-Z2` |
| eth0 MAC | `00:05:6B:02:CA:04` |
| Reserved IP | `192.168.1.9` |
| SSH | `ssh xilinx@192.168.1.9` |
| Jupyter | `http://192.168.1.9:9090/tree` |

Use `bash scripts/show_pynq_network_info.sh` to confirm hostname, IP,
and eth0 MAC from the board. The reservation itself must be created in
the router management UI; do not rely on ad-hoc IP scans as normal
operation, and do not write a static IP directly on the PYNQ for this
workflow. After changing the reservation, reboot the PYNQ-Z2 and run:

```sh
ssh xilinx@192.168.1.9 'hostname; ip -br addr; cat /sys/class/net/eth0/address'
bash scripts/deploy_to_pynq.sh
```

## What to do next

Open work, in roughly priority order:

1. **D44 follow-up RTL/Tcl pass** (`DECISIONS.md` D44, plan only).
   (a) `pcm1808_adc_integration.tcl` で `CONFIG.CONST_VAL` に応じて
   `ext_pcm1808_sckie_o` を `clk_wiz_audio_ext/clk_out1` か
   `xlconstant 0` に切替 (deploy bit が mux=ADAU の時 JB8 に不要な
   12.288 MHz を出さない)。(b) `pcm5102_audio_out.v` に build-time
   `MODE` パラメータで `processed audio / digital silence /
   -18 dBFS 1 kHz tone / ramp` を選べる selector を追加。Vivado
   rebuild + timing review が要る。PCM1808 復活時 (`CONST_VAL {1}`)
   は SCKI 復元を忘れない。
2. **PCM1808 ハードウェア診断 / 再投入** (`DECISIONS.md` D43)。新規
   module に差し替えて `hw/Pynq-Z2/pcm1808_adc_integration.tcl` の
   `CONFIG.CONST_VAL {0}` を `{1}` に戻し、bit/hwh rebuild + deploy、
   `scripts/test_pcm1808_adc_to_pcm5102.py --capture-adc` で
   `min/max/mean/RMS/peak_dBFS` を確認。pure 0 が続けば chip / analog
   前段の damage 仮説継続。
3. **物理 rotary encoder smoke** (`DECISIONS.md` D35)。3 ch すべての
   rotate / short / long / release を実操作で記録し、必要なら
   `--reverse-encN` / `--swap-encN` / `--debounce-ms` の最終設定を
   docs に反映する。
4. **8th pedal slot.** Bit 7 of `distortion_control.ctrlD` is the
   only remaining reserved pedal slot. If a future voicing wants
   in, it lands there as a new register-staged Clash block
   following the same shape as the new `ds1` / `big_muff` /
   `fuzz_face` stages.
5. **Drive WNS toward 0.** The deployed build is at the value
   recorded in `TIMING_AND_FPGA_NOTES.md` (Phase 7D close-out
   `-7.931 ns`); the audio path tolerates the current band in
   practice but the build is not formally clean. Worth a pass that
   splits any remaining deeper combinational stage and / or
   pipelines the cab or reverb tap address paths.
6. **UI / preset polish** in the notebooks. Possible adds:
   per-pedal default presets, an A/B compare cell, a quick-record
   cell that pairs the pedalboard with the existing diagnostic
   capture helpers.
7. **Diagnostic capture for distortion stages.** Re-use
   `diagnostics.capture_input` to log a clip waveform per pedal so
   we can compare voicings without ear fatigue.

## Things to be careful about

- Do **not** silently revert the ADC HPF default-on. `R19_ADC_CONTROL`
  must read back as `0x23` after `config_codec()`.
- Do **not** reintroduce a single function with a `case` over all
  seven pedals. That is exactly what regressed timing the first time;
  see `TIMING_AND_FPGA_NOTES.md`.
- Do **not** deploy a bitstream whose WNS is significantly worse than
  the current Phase 7D close-out build's WNS (`-7.931 ns`) without
  flagging the regression first. A -15 ns-class result remains a hard
  reject.
- Do **not** revive the legacy `gateGainNext` / `gateFrame` registers
  in the active pipeline. The active gain stage is the noise
  suppressor (`nsApplyFrame`); the legacy helpers are kept as Haskell
  source for backward compatibility but are not wired up.
- Do **not** drop the legacy `gate_control.ctrlB` write from
  `set_guitar_effects` -- older bitstreams without
  `axi_gpio_noise_suppressor` still rely on it.
- Do **not** silently replace the ADAU1761 path with PCM1808 / PCM5102.
  Phase 7 では外付け codec は別 I2S path として追加し (`DECISIONS.md`
  D27)、Phase 7C / 7E で PCM5102 は ADAU 並列出力、Phase 7D で PCM1808
  は build-time mux + JB8 SCKI (`DECISIONS.md` D38 / D39 / D41 / D42)
  に landing 済。既存 ADAU1761 経路 / DSP / GPIO map を破壊しない。
- Do **not** drive `pcm5102_audio_out.v` の `ext_audio_mclk_o` を 0 以外に
  する (`DECISIONS.md` D40 / D42)。PCM5102 SCK は GND-tied / internal-
  SYSCLK 固定。JB1 は構造的に常時 0。PCM1808 SCKI は JB8 / W16
  (`ext_pcm1808_sckie_o`) 経由でのみ供給する。
- Do **not** flip `pcm1808_adc_integration.tcl` の `CONFIG.CONST_VAL {0}`
  を勝手に `{1}` に戻す (`DECISIONS.md` D43)。PCM1808 module の analog
  前段ハードウェア診断が完了するまで mux=ADAU フォールバック維持。
- Do **not** allocate rotary encoder GPIO into the PMOD reserved for
  external audio. Audio が優先で、encoder は Raspberry Pi header 側へ
  逃がす (`DECISIONS.md` D28、`IO_PIN_RESERVATION.md`)。
- Do **not** poll encoder A / B / SW from Python directly. PL 側で
  debounce + quadrature decode + event 化する (`DECISIONS.md` D30、
  `ENCODER_GUI_CONTROL_SPEC.md`)。
- Do **not** connect PCM1808 analog input directly to a guitar. 必要な
  analog front-end (高 impedance buffer / AC coupling / bias / gain /
  anti-alias LPF / clamp) は Phase 7E 以降。
- Do **not** wire the rotary encoder module `+` pin to 5V. 必ず
  PYNQ-Z2 **3.3V** rail を使う (`DECISIONS.md` D31)。基板上 pull-up が
  `+` 経由で `CLK / DT / SW` を 5V 化し、PL pin (3.3V LVCMOS33) を
  破損する可能性がある。
- Do **not** rename or move the `axi_encoder_input` IP base address.
  `0x43D10000` は `axi_vdma_hdmi` (`0x43CE0000`) / `v_tc_hdmi`
  (`0x43CF0000`) / `0x43D00000` (HDMI 拡張枠) を避けて選定済み
  (`DECISIONS.md` D32)。
- Do **not** merge encoder bits into existing `axi_gpio_*` IPs. encoder
  は独立 AXI-Lite IP として実装 (`DECISIONS.md` D33)。
  `GPIO_CONTROL_MAP.md` の `ctrlA..D` 4-byte 契約に encoder event /
  delta を混ぜない。
- Do **not** allocate encoder pins to PMOD JB / PMOD JA. これらは
  外付け PCM1808 / PCM5102 codec 予約のまま温存 (`DECISIONS.md` D28 /
  D34)。encoder は Raspberry Pi header の JA 非共有 pin
  (`raspberry_pi_tri_i_6..14`) を使う。
- Do **not** push, pull, or fetch.
