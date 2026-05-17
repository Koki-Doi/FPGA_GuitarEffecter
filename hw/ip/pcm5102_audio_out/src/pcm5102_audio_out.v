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
// Master clock output on JB1 (W14) was TIED LOW in the Phase 7E follow-up
// because that pin was physically wired to the PCM5102 SCK input, and
// driving an unsynchronised 12.288 MHz external MCLK against the
// ADAU-PLL-sourced BCK caused PCM510x external-SCK lock to drift in and
// out (audible graininess; DECISIONS.md D40). Phase 7D rewires the
// physical board so PCM5102 SCK is now hard-tied to GND on the module
// side and JB1 instead feeds PCM1808 SCKI. With that wiring change in
// place, this module restores the passthrough of the Phase 7C 12.288
// MHz `clk_wiz_audio_ext` output onto `ext_audio_mclk_o`. PCM5102 is
// unaffected (its SCK is GND on the board, not JB1) and PCM1808 gets
// the SCKI it requires for slave-mode operation (DECISIONS.md D41).
//
// The 12.288 MHz wizard is NOT bit-true synchronous to ADAU's
// PLL-sourced BCK -- the same async-clocks caveat that hit PCM5102 in
// Phase 7E may bite PCM1808. PCM1808 does not have a PCM510x-style
// "SCKI absent -> internal PLL from BCK" fallback, so if the chip
// produces noisy / unlocked output on the bench the next step is to
// either (a) make the FPGA the I2S master and generate BCK/LRCK/SCKI
// from a single source, or (b) phase-lock the wizard to ADAU's BCK
// via a deliberate clock-recovery path. Both are deferred.
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

    // JB1 now drives PCM1808 SCKI (12.288 MHz) per the Phase 7D board
    // rewiring. PCM5102 SCK is hard-tied to GND on the module side and
    // is not connected to JB1 any more.
    assign ext_audio_mclk_o  = mclk_12m288_i;
    assign ext_audio_bclk_o  = adau_bclk_i;
    assign ext_audio_lrclk_o = adau_lrclk_i;
    assign ext_dac_din_o     = adau_sdata_o_i;

endmodule
