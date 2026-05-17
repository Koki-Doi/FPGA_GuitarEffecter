// -----------------------------------------------------------------------------
// pcm5102_audio_out
//
// Phase 7E external-DAC output path for the AudioLab DSP chain.
//
// This module is a *trivial 4-signal pass-through*. It mirrors the existing
// ADAU1761 I2S DAC interface (BCLK input from R18, LRCLK input from T17,
// serial DAC data from i2s_to_stream_0/so that already drives the ADAU
// sdata_o pin at G18) onto the four PMOD JB pins that feed the external
// PCM5102 DAC. The PCM5102 receives bit-for-bit the same processed audio
// the ADAU1761 DAC receives, so the two outputs run in parallel and either
// can be used as the listening source.
//
// Master clock for PCM5102 (SCK pin) is supplied by the same dedicated
// 12.288 MHz MMCM clk_wiz_audio_ext that Phase 7C added. It is not strictly
// synchronised to the ADAU1761 BCLK (3.072 MHz from the ADAU PLL), but the
// 256:1 ratio is within the PCM510x internal PLL lock range and the chip
// re-derives its sample clock from BCK/LCK during calibration. If a future
// board reveals lock issues, the safe fallback is to drive ext_audio_mclk_o
// constant low so PCM5102 enters internal-PLL mode.
//
// Free-running tone generator (pcm5102_dac_tone.v) is intentionally not
// instantiated by the integration tcl any more; the file stays in the repo
// as a known-good debug reference (DECISIONS.md D38 / D39).
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module pcm5102_audio_out (
    input  wire mclk_12m288_i,     // 12.288 MHz from clk_wiz_audio_ext
    input  wire adau_bclk_i,       // ADAU1761 I2S BCLK input net (top-level port bclk, R18)
    input  wire adau_lrclk_i,      // ADAU1761 I2S LRCLK input net (top-level port lrclk, T17)
    input  wire adau_sdata_o_i,    // i2s_to_stream_0/so -- same data that drives ADAU sdata_o (G18)
    output wire ext_audio_mclk_o,  // PMOD JB1 (W14) -> PCM5102 SCK
    output wire ext_audio_bclk_o,  // PMOD JB2 (Y14) -> PCM5102 BCK
    output wire ext_audio_lrclk_o, // PMOD JB3 (T11) -> PCM5102 LCK
    output wire ext_dac_din_o      // PMOD JB7 (V16) -> PCM5102 DIN
);

    assign ext_audio_mclk_o  = mclk_12m288_i;
    assign ext_audio_bclk_o  = adau_bclk_i;
    assign ext_audio_lrclk_o = adau_lrclk_i;
    assign ext_dac_din_o     = adau_sdata_o_i;

endmodule
