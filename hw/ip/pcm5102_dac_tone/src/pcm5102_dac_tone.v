// -----------------------------------------------------------------------------
// pcm5102_dac_tone
//
// Phase 7C DAC-only bring-up for the external PCM5102 DAC sitting on PMOD JB.
// Drives the four I2S signals out from a single 12.288 MHz audio master clock:
//   ext_audio_mclk_o   : 12.288 MHz (passthrough of clk_12m288_i)
//   ext_audio_bclk_o   :  3.072 MHz (MCLK / 4)
//   ext_audio_lrclk_o  : 48.000 kHz (BCLK / 64)
//   ext_dac_din_o      :  1 kHz sine, 24-bit signed, quarter-scale, L=R
//
// Frame format: I2S Philips, 32-bit slot per channel, 24-bit data MSB-first,
// 8 LSB zero pad. LRCLK transitions on BCLK falling edge; the first data bit
// appears one BCLK after the transition.
//
// The module is fully self-contained -- no AXI-Lite, no reset polarity choice.
// Reset is active-low, synchronous to the 12.288 MHz clock (held externally by
// proc_sys_reset's peripheral_aresetn). After de-assert the module starts
// emitting tone immediately.
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module pcm5102_dac_tone (
    input  wire clk_12m288_i,
    input  wire resetn_i,
    output wire ext_audio_mclk_o,
    output wire ext_audio_bclk_o,
    output wire ext_audio_lrclk_o,
    output wire ext_dac_din_o
);

    // -------------------------------------------------------------------------
    // MCLK passthrough.
    // -------------------------------------------------------------------------
    assign ext_audio_mclk_o = clk_12m288_i;

    // -------------------------------------------------------------------------
    // mclk_phase: divide-by-4 to build BCLK at 3.072 MHz.
    //   phase 0,1 -> BCLK high
    //   phase 2,3 -> BCLK low
    // -------------------------------------------------------------------------
    reg [1:0] mclk_phase;
    always @(posedge clk_12m288_i) begin
        if (!resetn_i)
            mclk_phase <= 2'd0;
        else
            mclk_phase <= mclk_phase + 2'd1;
    end

    wire bclk = ~mclk_phase[1];
    assign ext_audio_bclk_o = bclk;

    // Single-MCLK pulse on the cycle that precedes a BCLK falling edge
    // (mclk_phase==1 means the next posedge will land on mclk_phase==2 and
    // simultaneously drop BCLK). bit_idx, sample_idx, and DIN all update on
    // that boundary so the receiver sees stable data across the next BCLK
    // high half-period.
    wire bclk_fall_pre = (mclk_phase == 2'd1);

    // -------------------------------------------------------------------------
    // bit_idx: 0..63 BCLK slots within a stereo frame.
    //   bit_idx[5] == 0 -> left  channel slot  (LRCLK low)
    //   bit_idx[5] == 1 -> right channel slot  (LRCLK high)
    // bit_idx wraps from 63 back to 0 at the start of the next left slot.
    // -------------------------------------------------------------------------
    reg [5:0] bit_idx;
    always @(posedge clk_12m288_i) begin
        if (!resetn_i)
            bit_idx <= 6'd0;
        else if (bclk_fall_pre)
            bit_idx <= bit_idx + 6'd1;
    end

    assign ext_audio_lrclk_o = bit_idx[5];

    // -------------------------------------------------------------------------
    // 1 kHz sine ROM at 48 kHz fs (48 samples per cycle), signed 24-bit,
    // quarter scale (amplitude = 2^21 = 2097152).
    // -------------------------------------------------------------------------
    reg signed [23:0] sine_rom [0:47];
    initial begin
        sine_rom[ 0] = 24'sd0;
        sine_rom[ 1] = 24'sd273733;
        sine_rom[ 2] = 24'sd542783;
        sine_rom[ 3] = 24'sd802545;
        sine_rom[ 4] = 24'sd1048576;
        sine_rom[ 5] = 24'sd1276665;
        sine_rom[ 6] = 24'sd1482910;
        sine_rom[ 7] = 24'sd1663783;
        sine_rom[ 8] = 24'sd1816187;
        sine_rom[ 9] = 24'sd1937516;
        sine_rom[10] = 24'sd2025693;
        sine_rom[11] = 24'sd2079211;
        sine_rom[12] = 24'sd2097152;
        sine_rom[13] = 24'sd2079211;
        sine_rom[14] = 24'sd2025693;
        sine_rom[15] = 24'sd1937516;
        sine_rom[16] = 24'sd1816187;
        sine_rom[17] = 24'sd1663783;
        sine_rom[18] = 24'sd1482910;
        sine_rom[19] = 24'sd1276665;
        sine_rom[20] = 24'sd1048576;
        sine_rom[21] = 24'sd802545;
        sine_rom[22] = 24'sd542783;
        sine_rom[23] = 24'sd273733;
        sine_rom[24] = 24'sd0;
        sine_rom[25] = -24'sd273733;
        sine_rom[26] = -24'sd542783;
        sine_rom[27] = -24'sd802545;
        sine_rom[28] = -24'sd1048576;
        sine_rom[29] = -24'sd1276665;
        sine_rom[30] = -24'sd1482910;
        sine_rom[31] = -24'sd1663783;
        sine_rom[32] = -24'sd1816187;
        sine_rom[33] = -24'sd1937516;
        sine_rom[34] = -24'sd2025693;
        sine_rom[35] = -24'sd2079211;
        sine_rom[36] = -24'sd2097152;
        sine_rom[37] = -24'sd2079211;
        sine_rom[38] = -24'sd2025693;
        sine_rom[39] = -24'sd1937516;
        sine_rom[40] = -24'sd1816187;
        sine_rom[41] = -24'sd1663783;
        sine_rom[42] = -24'sd1482910;
        sine_rom[43] = -24'sd1276665;
        sine_rom[44] = -24'sd1048576;
        sine_rom[45] = -24'sd802545;
        sine_rom[46] = -24'sd542783;
        sine_rom[47] = -24'sd273733;
    end

    // sample_idx advances once per stereo frame on the BCLK boundary at
    // bit_idx == 63 -> 0. Both channels emit the same sample (mono tone in
    // both L and R), so we only need a single ROM index.
    reg [5:0] sample_idx;
    always @(posedge clk_12m288_i) begin
        if (!resetn_i)
            sample_idx <= 6'd0;
        else if (bclk_fall_pre && bit_idx == 6'd63)
            sample_idx <= (sample_idx == 6'd47) ? 6'd0 : sample_idx + 6'd1;
    end

    wire signed [23:0] cur_sample = sine_rom[sample_idx];

    // -------------------------------------------------------------------------
    // DIN: combinational from bit_idx + cur_sample.
    // I2S Philips slot layout (32 BCLK per channel):
    //   slot_idx  0      : 1 BCLK delay after LRCLK transition (DIN = 0)
    //   slot_idx  1..24  : 24 data bits, MSB first
    //                      slot_idx==1 -> cur_sample[23]
    //                      slot_idx==24 -> cur_sample[0]
    //   slot_idx 25..31  : 7 zero pad bits
    // -------------------------------------------------------------------------
    wire [4:0] slot_idx = bit_idx[4:0];
    reg din_r;
    always @(*) begin
        if (slot_idx >= 5'd1 && slot_idx <= 5'd24)
            din_r = cur_sample[24 - slot_idx];
        else
            din_r = 1'b0;
    end
    assign ext_dac_din_o = din_r;

endmodule
