// -----------------------------------------------------------------------------
// pcm1808_input_select
//
// Phase 7D 2:1 wire-level mux between the existing ADAU1761 I2S serial-data
// input (`sdata_i` top-level port, F17) and the new external PCM1808 ADC
// DOUT (`ext_adc_dout_i` top-level port, JB4 / T10). The mux output drives
// the existing `i2s_to_stream_0/si` pin, so the AXIS DSP chain downstream
// is bit-for-bit unchanged regardless of which ADC source is selected.
//
// `sel_external_i` chooses the source:
//   0 = ADAU1761 ADC      (PCM1808 DOUT ignored; falls back to the
//                          pre-Phase-7D path)
//   1 = external PCM1808  (ADAU1761 ADC ignored; Phase 7D bring-up default)
//
// `sel_external_i` is driven from a single-bit `xlconstant` instance in the
// integration tcl (build-time selection). Switching to runtime AXI GPIO
// control is deferred; the AXIS contract, sample width, LRCK polarity, and
// `i2s_to_stream_0` config stay identical to the ADAU path on purpose --
// PCM1808 is strapped on the board to I2S Philips 24-bit slave mode so the
// downstream serializer treats both sources as the same I2S protocol.
//
// No registers, no CDC, no AXI. Both DOUT lines are sampled in the
// existing `bclk` domain by `i2s_to_stream_0` itself; the mux just selects
// which physical line the serializer sees.
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module pcm1808_input_select (
    input  wire adau_sdata_i,     // ADAU1761 ADC I2S serial input (port sdata_i, F17)
    input  wire pcm1808_dout_i,   // PCM1808 ADC I2S DOUT          (port ext_adc_dout_i, T10)
    input  wire sel_external_i,   // 0 = ADAU, 1 = PCM1808
    output wire sdata_to_dsp_o    // -> i2s_to_stream_0/si
);

    assign sdata_to_dsp_o = sel_external_i ? pcm1808_dout_i : adau_sdata_i;

endmodule
