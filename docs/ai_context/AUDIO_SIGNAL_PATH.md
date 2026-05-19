# Audio signal path

This is the picture you should keep in your head when something sounds
wrong. The PL never sees raw analog — by the time samples reach the Clash
block they are already two's-complement 24-bit numbers from the codec.

```
ADAU1761 ADC
  | I2S (SDATA_I, BCLK, LRCLK)
  v
i2s_to_stream_0
  | 48-bit AXI-Stream (TDATA[47:24]=right, TDATA[23:0]=left)
  v
axis_switch_source  (1-of-N source select, controlled from PS via AXI-Lite)
  +-- M00 --> axis_switch_sink/S00 -> i2s_to_stream_0/axis_hp -> ADAU1761 DAC  (passthrough)
  |
  +-- M01 --> axis_data_fifo_0 -> clash_lowpass_fir_0 -> axis_switch_sink/S01 -> i2s_to_stream_0/axis_hp -> ADAU1761 DAC  (effect path)
  |
  +-- M0x --> axis_subset_converter_1 -> S2MM DMA  (capture; 24-bit -> 32-bit sign-extended per channel)
```

The reverse direction (PS-to-board playback) goes through the MM2S DMA, a
sign-narrowing subset converter, and back into `axis_switch_sink`.

## On-the-wire layout

`i2s_to_stream_0` emits a 48-bit AXIS word per stereo frame:

| Bits | Meaning |
| --- | --- |
| `[23:0]` | Left, signed 24-bit two's complement. |
| `[47:24]` | Right, signed 24-bit two's complement. |

`axis_subset_converter_1` re-packs the 48-bit stream into a 64-bit DMA word
where each channel is sign-extended to 32 bits:

| Bits | Meaning |
| --- | --- |
| `[31:0]` | Left, sign-extended `int32` (only the low 24 bits carry data). |
| `[63:32]` | Right, sign-extended `int32`. |

In `numpy`, capture buffers are read back as `numpy.int32` of shape
`(num_frames, 2)`, with column 0 = left and column 1 = right.

## Routing controlled from Python

| Source | `XbarSource` | Sink | `XbarSink` |
| --- | --- | --- | --- |
| Line-in | `line_in` | DAC | `headphone` |
| MM2S DMA | `dma`     | S2MM DMA | `dma` |

`XbarEffect` selects whether the active route goes through `passthrough`,
`guitar_chain` (the Clash effect block), or alternative paths. See
`AudioLabOverlay.route()`.

## External PCM1808 / PCM5102 paths (Phase 7C / 7E / 7D)

Two additional physical paths on PMOD JB share the same internal AXIS
plumbing. They were added by Phase 7C / 7E / 7D
(`DECISIONS.md` D38 / D39 / D40 / D41 / D42 / D43 / D44) without any change
to `LowPassFir.hs`, `i2s_to_stream_0`, `axis_switch_*`, or the GPIO
control map.

### Output side (parallel to the ADAU1761 DAC)

`hw/ip/pcm5102_audio_out/src/pcm5102_audio_out.v` is a trivial
4-signal pass-through that fans out the existing ADAU1761 I2S DAC
interface to the PMOD JB pins driving the external PCM5102. The serial
data stream is *bit-for-bit identical* to what the ADAU `sdata_o` pin
sees; both DACs play in parallel.

```
i2s_to_stream_0/so  ──┬──► ADAU sdata_o (G18) ──► ADAU1761 DAC ──► onboard line/headphone out
                      └──► JB7 (V16) ext_dac_din_o ──► PCM5102 DIN ──► PCM5102 line out

bclk (R18)  ──┬──► ADAU1761 BCLK input
              └──► JB2 (Y14) ext_audio_bclk_o ──► PCM5102 BCK

lrclk (T17) ──┬──► ADAU1761 LRCLK input
              └──► JB3 (T11) ext_audio_lrclk_o ──► PCM5102 LCK

JB1 (W14) ext_audio_mclk_o = 1'b0  (PCM5102 SCK stays GND-driven
                                    structurally; PCM5102 enters its
                                    internal-SYSCLK mode, D40 / D42)
```

If PCM5102 sounds clean but the on-board ADAU DAC sounds wrong (or vice
versa), the problem is in the analog output stage of the misbehaving
DAC, not in the DSP — both sinks see the same bits.

### Input side (build-time selectable ADC source)

`hw/ip/pcm1808_adc_input/src/pcm1808_input_select.v` is a 2:1
combinational wire mux. The deployed bit ships with the build-time
`xlconstant` in `hw/Pynq-Z2/pcm1808_adc_integration.tcl` set to
`CONFIG.CONST_VAL {0}` (mux=ADAU fallback, `DECISIONS.md` D43);
flipping to `{1}` and rebuilding selects PCM1808.

```
ADAU1761 ADC ──► sdata_i (F17) ──┐
                                 ├──► pcm1808_input_select ──► i2s_to_stream_0/si
PCM1808 DOUT ──► JB4 (T10)    ──┘                                  (existing AXIS chain
                                                                    is unchanged downstream)

JB8 (W16) ext_pcm1808_sckie_o ──► PCM1808 SCKI   (12.288 MHz from clk_wiz_audio_ext, D42)
JB2 (Y14) ext_audio_bclk_o    ──► PCM1808 BCK    (shared with PCM5102 BCK)
JB3 (T11) ext_audio_lrclk_o   ──► PCM1808 LRCK   (shared with PCM5102 LCK)
```

Caveats baked into Phase 7D:

- `CONFIG.CONST_VAL` is a **build-time** select. There is no runtime
  AXI control over the mux; switching sources requires a rebuild and a
  redeploy.
- PCM1808 SCKI (12.288 MHz from the PS PLL via `clk_wiz_audio_ext`) is
  NOT bit-true synchronous to BCK (ADAU PLL). PCM1808 has no
  PCM510x-style internal-PLL fallback; if the bench shows
  graininess, the next escalation is to make the FPGA the I2S master
  rather than another RTL tweak (deferred).
- While `CONFIG.CONST_VAL {0}` keeps PCM1808 out of the active input
  path, the current bit still drives `ext_pcm1808_sckie_o` on JB8 at
  12.288 MHz. For PCM5102-only quality work, D44 records the next
  non-physical improvement: gate or tie this output low when PCM1808 is
  unused, then add a PCM5102 debug output mode (processed audio /
  digital silence / `-18 dBFS` tone / ramp) for repeatable diagnosis.
- The current PCM1808 module on the user's bench returns pure zeros on
  `--capture-adc` even with line-in from a smartphone; the most
  plausible hypothesis is analog-front-end damage from an earlier
  `3.3V on VCC` brown-out (memory
  `pcm1808-dual-supply-and-pmod-brownout`). Until the module is
  replaced, keep `CONST_VAL = 0`.

## Pmod I2S2 PMOD JB audio path (Phase Pmod-1, `DECISIONS.md` D48, branch `feature/pmod-i2s2-bringup`)

The Digilent Pmod I2S2 module (CS4344 stereo DAC + CS5343 stereo
ADC) is the **sole** external audio device on PMOD JB.
`hw/Pynq-Z2/create_project.tcl` unconditionally sources
`hw/Pynq-Z2/pmod_i2s2_integration.tcl`; the PCM5102 / PCM1808
integration tcls, RTL, and `audio_lab_pcm.xdc` stay in the repo as
archival reference only and are not part of the deployed build
(see the section above for the historical PCM5102 / PCM1808 path,
kept for triage of older bitstreams from `git log` history).

The ADAU1761 → AXIS → ADAU1761 DSP loop documented at the top of
this file is **unchanged**. The Pmod I2S2 path is a completely
separate bringup-only path that does not feed the AXIS DSP chain —
ADAU Line In / Line Out on the on-board codec keeps working
exactly as before for users who do not need Pmod I2S2.

```
clk_wiz_audio_ext.clk_out1 (12.288 MHz)
        └──► pmod_i2s2_master ─┬── 1 kHz sine ROM (cfg_mode=0, default)
                               │      └──► JB4 (T10) ext_pmod_i2s2_da_sdin_o
                               │             ──► Pmod I2S2 CS4344 DAC ──► Line Out
                               │
                               └── ADC RX deserializer (24-bit I2S Philips)
                                      ◄── JB10 (W13) ext_pmod_i2s2_ad_sdout_i
                                              ◄── Pmod I2S2 CS5343 ADC ◄── Line In

         Shared FPGA-master clock tree (one source, two fanouts):
         MCLK 12.288 MHz   ──┬──► JB1 (W14)  ext_pmod_i2s2_da_mclk_o
                             └──► JB7 (V16)  ext_pmod_i2s2_ad_mclk_o
         BCLK  3.072 MHz   ──┬──► JB3 (T11)  ext_pmod_i2s2_da_sclk_o
                             └──► JB9 (V12)  ext_pmod_i2s2_ad_sclk_o
         LRCK  48 kHz      ──┬──► JB2 (Y14)  ext_pmod_i2s2_da_lrck_o
                             └──► JB8 (W16)  ext_pmod_i2s2_ad_lrck_o
```

Mode select (AXI register at `0x43D20000 + 0x28`):
- `cfg_mode = 0` (default, mode name `tone`): DAC SDIN gets the
  internal 1 kHz quarter-scale sine; ADC SDOUT is captured but only
  feeds the status counters (no audio sink). Used by
  `scripts/test_pmod_i2s2.py --mode tone` to verify clocks + ADC
  line-in via the on-module Line Out → Line In physical loopback.
- `cfg_mode = 1` (mode name `loopback`): DAC SDIN echoes the
  just-received ADC sample (24-bit L → L, 24-bit R → R, no DSP, no
  attenuation). With the on-module Line Out ↔ Line In jumper
  installed the analog loop has gain ~ 1 and can feed back, so
  `scripts/test_pmod_i2s2.py --mode loopback` REQUIRES
  `--confirm-loopback` to engage; without it the script falls back
  to mode 0 with a safety warning. Recommended workflow: disconnect
  the on-module jumper, put a real audio source on Line In at low
  volume, and listen on Line Out via a separate audio interface.
- `cfg_mode = 2` / `3`: reserved. The Pmod I2S2 ADC is **NOT** wired
  into the AudioLab DSP chain (`i2s_to_stream_0` /
  `stream_to_i2s_0`); a "mode 2 = ADC → DSP → DAC" path is
  intentionally NOT implemented in the current branch.

Triage tips specific to the Pmod I2S2 variant:
- If `frame_count` (`0x43D20000 + 0x08`) is stuck at 0, the BCLK /
  LRCK generator is dead — check `clk_wiz_audio_ext` locked, check
  the `pmod_master_0` reset.
- If `frame_count` is rising but `sdout_xcount` (`+ 0x10`) is 0,
  the ADC line in JB10 (W13) is dead (cable / module / FPGA pin).
- If `sdout_xcount` is rising but `peak_abs_left/right` (`+ 0x20 /
  + 0x24`) is 0, the ADC is alive but the analog line-in is silent.
- ADAU1761 DAC / ADC, HDMI, encoder, GPIO_CONTROL_MAP, LowPassFir
  are all *unchanged* in this variant — if they break, the issue is
  in the Pmod I2S2 integration tcl, not in the existing path.

## Triage rules of thumb

- If the **bypass route** (`passthrough`, no Clash) is noisy, look at the
  output side: codec DAC, headphone amp, R29-R32 (HP/LO volume), R35
  (playback power), grounding. Editing Clash will not fix it.
- If `output_zero_test` is silent and `output_sine_test` is clean, the
  output stage is good and any noise is upstream of the DAC.
- Capture stats with input shorted: mean near zero, RMS small. If mean
  drifts, the ADC HPF is probably off. Confirm `R19_ADC_CONTROL == 0x23`.
- Capture stats with the guitar plugged in but silent: any large RMS
  comes from pickups / cable / room, not the FPGA.
- Bit-bypass is the contract: with every effect off, samples in must
  equal samples out.
