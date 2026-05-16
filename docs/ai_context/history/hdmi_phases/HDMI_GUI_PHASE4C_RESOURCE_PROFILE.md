# HDMI GUI Phase 4C resource profile

Date: 2026-05-15 JST

## Summary

Phase 4C re-ran the integrated HDMI static-frame path on the PYNQ-Z2 and
measured PS-side runtime cost while the VDMA held a static frame for
60 seconds. This phase did **not** rebuild Vivado, did **not** regenerate
`audio_lab.bit` / `audio_lab.hwh`, did **not** edit
`block_design.tcl`, `audio_lab.xdc`, `create_project.tcl`, Clash, DSP,
or GPIO semantics, and did **not** load `base.bit`.

| Field | Value |
| --- | --- |
| Branch | `feature/hdmi-gui-phase4-vivado-integration` |
| Measured commit | `28778a1` (`Integrate HDMI framebuffer output into AudioLab overlay`) |
| Measurement script | `scripts/profile_hdmi_static_frame.py` |
| PYNQ-Z2 | `192.168.1.9` |
| PYNQ Python | `3.6.5` |
| Bitstream | deployed Phase 4 `audio_lab.bit`, 4,045,680 bytes |
| HWH | deployed Phase 4 `audio_lab.hwh`, 1,054,120 bytes |
| Physical HDMI display | later confirmed by Phase 5A/5C; 5-inch LCD uses top-left 800x480 viewport |
| Scanout/log status | VDMA/VTC started; no VDMA internal/slave/decode error bits |
| Board output dir | `/tmp/hdmi_phase4c_resource_profile/` |
| Local logs | `/tmp/hdmi_phase4c_static_frame.log`, `/tmp/hdmi_phase4c_resource_profile.log` |

The static test and profile both loaded exactly one `AudioLabOverlay()`.
They did not call `Overlay("base.bit")`, did not call
`run_pynq_hdmi()`, and did not load a second overlay after AudioLab.

## PL resource utilization

No new Vivado run was made for Phase 4C. The table below uses the Phase 4
routed timing/utilization reports under
`hw/Pynq-Z2/audio_lab/audio_lab.runs/impl_1/` and compares them with the
internal-mono baseline recorded before HDMI integration.

| Metric | Baseline | After HDMI | Delta | Usage before | Usage after |
| --- | ---: | ---: | ---: | ---: | ---: |
| WNS | `-8.155 ns` | `-8.163 ns` | `-0.008 ns` | n/a | n/a |
| TNS | `-6492.876 ns` | `-6599.061 ns` | `-106.185 ns` | n/a | n/a |
| WHS | `+0.052 ns` | `+0.051 ns` | `-0.001 ns` | n/a | n/a |
| THS | `0.000 ns` | `0.000 ns` | `0.000 ns` | n/a | n/a |
| Slice LUTs | `15473` | `18619` | `+3146` | `29.08%` | `35.00%` |
| Slice Registers | `14914` | `20846` | `+5932` | `14.02%` | `19.59%` |
| Block RAM Tile | `7` | `9` | `+2` | `5.00%` | `6.43%` |
| DSPs | `83` | `83` | `0` | `37.73%` | `37.73%` |

Additional after-HDMI details from the placed utilization and routed
clock-utilization reports:

| Resource | After HDMI |
| --- | ---: |
| LUT as Logic | `16615` (`31.23%`) |
| LUT as Memory | `2004` (`11.52%`) |
| LUT as Distributed RAM | `1094` |
| LUT as Shift Register | `910` |
| Bonded IOB | `17` (`13.60%`) |
| OLOGIC / OSERDES | `8` |
| BUFGCTRL | `8 / 32` (`25.00%`) |
| MMCME2_ADV | `2 / 4` (`50.00%`) |
| PLLE2_ADV | `1 / 4` (`25.00%`) |

HDMI clock-domain timing is not the limiting path:

- `clk_out1_block_design_clk_wiz_hdmi_0`: WNS `+2.622 ns`, TNS `0`.
- `PixelClkIO`: pulse-width slack `+11.313 ns`.
- `SerialClkIO`: pulse-width slack `+0.538 ns`.
- `clk_fpga_0 -> HDMI pixel clock`: WNS `+8.443 ns`.
- `HDMI pixel clock -> clk_fpga_0`: WNS `+11.802 ns`.

The remaining negative setup slack is still in the existing audio-side
clock crossings, not in the HDMI pixel/serial domain.

## PS runtime resource usage

Profile command:

```sh
sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
  python3 scripts/profile_hdmi_static_frame.py \
  --hold-seconds 60 \
  --iterations 10 \
  --out-dir /tmp/hdmi_phase4c_resource_profile
```

Runtime summary:

| Metric | Value |
| --- | ---: |
| `AudioLabOverlay` import | `4.759 s` |
| `AudioLabOverlay()` load | `2.702 s` |
| Cold GUI render | `2.979 s` |
| Cached same-state render avg / p95 | `0.00052 s` / `0.00217 s` |
| Change-driven render avg / p95 | `0.276 s` / `0.280 s` |
| Framebuffer allocation | `0.033 s` |
| RGB888 -> DDR `GBR888` copy avg / p95 | `0.206 s` / `0.206 s` |
| VDMA/VTC init + start | `0.0023 s` |
| Full script wall time | `75.864 s` |
| Full script user CPU | `13.577 s` |
| Full script system CPU | `1.457 s` |
| Full script CPU percent | `19.82%` |
| Process max RSS | `136876 kB` |
| MemAvailable before / after | `390860 kB` / `270764 kB` |
| MemFree before / after | `160752 kB` / `40568 kB` |
| Hold samples | `60` |
| Hold system CPU avg / max | `0.190%` / `0.990%` |
| Hold process CPU avg / max | `0.352%` / `0.418%` |
| Temperature before / after | unavailable; no thermal/hwmon temp files exposed |

The memory delta is measured while the overlay, renderer cache, RGB
frame, and contiguous framebuffer are still alive inside the profiling
process. It should not be read as a leak by itself; the 60-second hold
CSV stayed flat at process RSS about `130888 kB` and max RSS
`136876 kB`.

## HDMI static frame result

The Phase 4B static-frame test was re-run before profiling:

- `AudioLabOverlay()` load: OK.
- ADC HPF: `True`.
- `R19_ADC_CONTROL`: `0x23`.
- `axi_gpio_delay_line`: `False`.
- legacy `axi_gpio_delay`: `True`.
- `axi_gpio_noise_suppressor`: present.
- `axi_gpio_compressor`: present.
- `axi_vdma_hdmi`: present in `ip_dict`.
- `v_tc_hdmi`: present in `ip_dict`.
- `rgb2dvi_hdmi` and `v_axi4s_vid_out_hdmi`: present in HWH.
- Renderer output: `[720, 1280, 3]`, dtype `uint8`.
- Static-test render time: `2.924 s`.
- Framebuffer physical address: `0x16900000`.
- Framebuffer size: `2764800` bytes.
- Framebuffer format: `GBR888 packed in DDR from RGB888 input`.
- VDMA HSIZE: `3840`.
- VDMA STRIDE: `3840`.
- VDMA VSIZE: `720`.
- Static-test `VDMACR`: `0x00010001`.
- Static-test `DMASR`: `0x00011000`.
- Profile `DMASR`: `0x00010000`.
- VDMA error bits: `dmainterr=False`, `dmaslverr=False`,
  `dmadecerr=False`, `halted=False`, `idle=False`.
- VTC status: `vtc_ctl=0x00000006`, `v_tc_hdmi` at `0x43CF0000`.

The difference between the static-test and profile `DMASR` raw values
did not affect the error-bit decode; both runs reported no VDMA error
conditions. At Phase 4C time, Codex could verify only scanout start plus
healthy VDMA/VTC register status. Phase 5A/5C later added user visual
confirmation on the 5-inch LCD and selected the top-left 800x480
framebuffer viewport.

## Interpretation

- HDMI scanout itself is cheap on the PS once VDMA is running. During
  the 60-second static hold, process CPU averaged only `0.352%` and
  system CPU averaged `0.190%`; the Python process is not busy-looping.
- The expensive parts are Python/PIL/NumPy rendering and the Python-side
  RGB888-to-`GBR888` framebuffer copy.
- First visible frame cost is roughly cold render + copy + VDMA start:
  `2.979 + 0.206 + 0.002 = 3.187 s`.
- Warm change-driven updates are roughly render + copy:
  `0.276 + 0.206 = 0.482 s`, or about `2.1 fps` practical update rate
  for this static/change-driven renderer profile.
- Same-state cached render is sub-millisecond; when the GUI state has
  not changed, the right behavior is to reuse the existing framebuffer
  and let VDMA continue scanning.
- Continuous 30 fps GUI output is not realistic with the current Python
  renderer and full-frame copy path. It would require a redesigned
  renderer, partial updates, lower resolution, or more work moved out of
  Python.

## Risks

- Physical monitor output is not visually confirmed yet.
- HDMI color order is not visually confirmed yet; the current `GBR888`
  packing is based on `rgb2dvi` bus mapping and register/log validation.
- Long-run stability is measured only for 60 seconds, not minutes or
  hours.
- HDMI hotplug / reconnect behavior is not tested.
- Notebook concurrency while HDMI scanout is active is not tested.
- The PYNQ image did not expose thermal readings through
  `/sys/class/thermal` or `/sys/class/hwmon`, so temperature trend is
  unavailable from this run.

## Next step

1. User visually confirms HDMI output and color order on a connected
   monitor.
2. Optional 10-minute hold test using the same profile script.
3. Phase 5 can build a change-driven GUI loop that renders only on
   state changes and keeps VDMA scanning the last completed frame.
