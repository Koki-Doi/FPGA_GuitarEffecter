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
