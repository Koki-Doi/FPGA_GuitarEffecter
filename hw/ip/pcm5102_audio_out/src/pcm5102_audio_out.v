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
// Master clock output on JB1 (W14) is TIED LOW (Phase 7E D40 restored
// after the Phase 7D first attempt re-introduced async-clocks noise on
// PCM5102 output during inject-sine bench testing). The earlier Phase
// 7D attempt assumed the user could physically isolate PCM5102 SCK to
// GND while reusing JB1 to drive PCM1808 SCKI; in practice JB1's 12.288
// MHz square wave still coupled onto PCM5102 SCK and re-broke the
// internal-PLL mode that D40 was relying on. Phase 7D follow-up moves
// PCM1808 SCKI off JB1 to a dedicated PMOD JB8 / W16 pin
// (`ext_pcm1808_sckie_o`, driven directly from `clk_wiz_audio_ext` in
// `pcm1808_adc_integration.tcl`), so JB1 can stay constantly low and
// PCM5102 stays in internal-SYSCLK mode (DECISIONS.md D40 / D42).
//
// `mclk_12m288_i` is therefore unused again; the integration tcl still
// passes the wizard output here to keep the module interface stable,
// so synth will optimise the unused path away.
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

    // JB1 = constant 0. PCM5102 SCK stays in internal-SYSCLK mode
    // regardless of how the user physically wired around the module
    // (D40 restored, D42 makes the constant the structural guarantee).
    // PCM1808 SCKI is driven from a separate top-level port
    // (ext_pcm1808_sckie_o on JB8 / W16, see pcm1808_adc_integration.tcl).
    assign ext_audio_mclk_o  = 1'b0;
    assign ext_audio_bclk_o  = adau_bclk_i;
    assign ext_audio_lrclk_o = adau_lrclk_i;
    assign ext_dac_din_o     = adau_sdata_o_i;

    // Suppress synth "unused input" warning while keeping the integration
    // tcl untouched.
    wire _unused_mclk = mclk_12m288_i;

endmodule
