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
// Master clock for PCM5102 (SCK pin) is intentionally TIED LOW. The Phase
// 7C MMCM clk_wiz_audio_ext still runs and its 12.288 MHz output is still
// wired into this module's mclk_12m288_i port (so the integration tcl does
// not need to be rewritten), but the output assignment ignores it and
// drives constant 1'b0 instead. This puts PCM510x into BCK-derived
// internal-SYSCLK mode and avoids the audible jitter / graininess Phase 7E
// initial bring-up exhibited when an external 12.288 MHz MCLK from the
// 100 MHz FCLK_CLK0 PLL was driven against an ADAU1761-PLL-sourced ~3.072
// MHz BCLK -- the two PLLs are not bit-true synchronous and the chip's
// external-SCK locking went in and out of phase. With SCK low the chip
// derives SYSCLK from BCK alone and the output is clean.
//
// If a future revision needs to drive an external MCLK again (e.g. to feed
// PCM1808 SCKI in Phase 7D), uncomment the original passthrough assignment
// AND ensure the MCLK source is genuinely synchronous to BCK; the wizard
// alone is not sufficient (DECISIONS.md D40).
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

    // SCK = 0 -> PCM5102 internal PLL mode (sysclk from BCK alone).
    // mclk_12m288_i is intentionally unused; see header comment above.
    assign ext_audio_mclk_o  = 1'b0;
    assign ext_audio_bclk_o  = adau_bclk_i;
    assign ext_audio_lrclk_o = adau_lrclk_i;
    assign ext_dac_din_o     = adau_sdata_o_i;

    // Suppress synth "unused input" warning while keeping the integration
    // tcl untouched.
    wire _unused_mclk = mclk_12m288_i;

endmodule
