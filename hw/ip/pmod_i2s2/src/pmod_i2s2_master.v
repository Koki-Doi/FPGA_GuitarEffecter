// -----------------------------------------------------------------------------
// pmod_i2s2_master
//
// Phase Pmod-1/2/3 bring-up module for the Digilent Pmod I2S2 module
// (CS4344 stereo DAC + CS5343 stereo ADC) on PYNQ-Z2 PMOD JB.
//
// The FPGA is the I2S master. One internal MCLK / BCLK / LRCK clock tree
// is generated from a 12.288 MHz audio reference (shared with the existing
// `clk_wiz_audio_ext` MMCM Phase 7C built; no new MMCM is added here) and
// fanned out to BOTH the D/A side (Pin 1..4) and the A/D side (Pin 7..10)
// of the Pmod I2S2 board so D/A and A/D run bit-true synchronous.
//
// Output mapping (FPGA -> Pmod I2S2 J1):
//   ext_pmod_i2s2_da_mclk_o   = JB1  W14   12.288 MHz (passthrough)
//   ext_pmod_i2s2_da_lrck_o   = JB2  Y14   48 kHz
//   ext_pmod_i2s2_da_sclk_o   = JB3  T11   3.072 MHz
//   ext_pmod_i2s2_da_sdin_o   = JB4  T10   24-bit I2S Philips MSB-first
//   ext_pmod_i2s2_ad_mclk_o   = JB7  V16   12.288 MHz (fanout of internal MCLK)
//   ext_pmod_i2s2_ad_lrck_o   = JB8  W16   48 kHz     (fanout of internal LRCK)
//   ext_pmod_i2s2_ad_sclk_o   = JB9  V12   3.072 MHz  (fanout of internal BCLK)
//   ext_pmod_i2s2_ad_sdout_i  = JB10 W13   24-bit I2S Philips MSB-first  (in)
//
// Build-time MODE values (`cfg_mode_i`):
//   0 = TX_TONE + ADC_PROBE  (default at reset; SDIN gets the internal sine
//                             tone; ADC status counters track SDOUT for the
//                             probe smoke.)
//   1 = ADC_TO_DAC_LOOPBACK  (SDIN echoes the last received ADC sample, no
//                             DSP. ADC status counters still update.
//                             Use cautiously while Line Out / Line In are
//                             physically tied -- feedback risk.)
//   2 = ADC_DSP_DAC          (SDIN forwards `dsp_dac_sdin_i`, the bit-serial
//                             output of the existing AudioLab DSP chain
//                             clocked by the Pmod-generated BCLK / LRCK
//                             tree. The DSP chain receives the Pmod ADC
//                             SDOUT through `i2s_to_stream_0/si` (rewired
//                             by `pmod_i2s2_integration.tcl`). Feedback
//                             risk if Line Out <-> Line In jumper is on.)
//   3 = MUTE                 (SDIN = 0. Default-safe state, useful for
//                             silencing the DAC while reading status.)
//
// Status outputs are read by `axi_pmod_i2s2_status` over a small AXI-Lite
// slave (see `axi_pmod_i2s2_status.v`). They live in the MCLK / BCLK domain
// here; the AXI-Lite slave samples them with a 2-FF synchronizer.
//
// I2S framing:
//   - 32 BCLK per channel slot, 64 BCLK per stereo frame.
//   - LRCK low = LEFT channel, high = RIGHT channel.
//   - Data MSB appears 1 BCLK after each LRCK transition (Philips frame).
//   - 24 data bits MSB-first, then 8 zero pad LSBs.
//
// Self-contained: no AXI-Lite here, no external IP dependency, no MMCM.
// Reset is active-low, synchronous to the 12.288 MHz MCLK.
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps
`default_nettype none

module pmod_i2s2_master (
    // 12.288 MHz audio reference (from clk_wiz_audio_ext/clk_out1)
    input  wire        clk_12m288_i,
    input  wire        resetn_i,

    // Mode select. Comes from the AXI-Lite slave on a different clock
    // domain; this module synchronizes it internally with a 2-FF chain.
    //   0 = TX tone + ADC probe
    //   1 = ADC -> DAC loopback (SDIN echoes SDOUT)
    //   2 = ADC -> DSP -> DAC (SDIN = dsp_dac_sdin_i)
    //   3 = mute (SDIN = 0)
    input  wire [1:0]  cfg_mode_i,
    // CLEAR toggle from the AXI-Lite slave (also async). Every flip means
    // "zero the counters / peak registers." Edge-detected after a 2-FF sync.
    input  wire        cfg_clear_toggle_i,

    // Pmod I2S2 J1 -- D/A side (Pin 1..4)
    output wire        ext_pmod_i2s2_da_mclk_o,
    output wire        ext_pmod_i2s2_da_lrck_o,
    output wire        ext_pmod_i2s2_da_sclk_o,
    output wire        ext_pmod_i2s2_da_sdin_o,

    // Pmod I2S2 J1 -- A/D side (Pin 7..10)
    output wire        ext_pmod_i2s2_ad_mclk_o,
    output wire        ext_pmod_i2s2_ad_lrck_o,
    output wire        ext_pmod_i2s2_ad_sclk_o,
    input  wire        ext_pmod_i2s2_ad_sdout_i,

    // Internal clock fanout for the AudioLab DSP I2S converter
    // (i2s_to_stream_0). Drive these into `bclk` / `lrclk` on the converter
    // so the DSP chain runs in the Pmod-generated I2S clock domain.
    output wire        dsp_bclk_o,
    output wire        dsp_lrck_o,
    // Bit-serial DSP DAC stream coming back from i2s_to_stream_0/so. The
    // converter samples on `dsp_bclk_o` rising edges and outputs MSB-first
    // 24-bit-in-32-slot I2S Philips, identical framing to the internal
    // tone serializer. In `cfg_mode == 2'd2` this wire drives the DAC pin.
    input  wire        dsp_dac_sdin_i,

    // Status outputs (read by axi_pmod_i2s2_status). All in MCLK domain.
    output reg  [31:0] frame_count_o,
    output reg  [31:0] nonzero_count_o,
    output reg  [31:0] sdout_transition_count_o,
    output reg  [31:0] clip_count_o,
    output reg  [23:0] last_left_o,
    output reg  [23:0] last_right_o,
    output reg  [23:0] peak_abs_left_o,
    output reg  [23:0] peak_abs_right_o,
    output reg         lrclk_seen_o,
    output reg         bclk_seen_o,
    output reg         sdout_alive_o
);

    // -------------------------------------------------------------------------
    // Pass-through MCLK to both sides of the Pmod I2S2 board.
    // -------------------------------------------------------------------------
    assign ext_pmod_i2s2_da_mclk_o = clk_12m288_i;
    assign ext_pmod_i2s2_ad_mclk_o = clk_12m288_i;

    // -------------------------------------------------------------------------
    // CDC of AXI-clock configuration into the MCLK domain.
    //   cfg_mode      : 2-FF synchronizer on each bit. Level signal, the
    //                   master uses it directly.
    //   cfg_clear     : the slave toggles a single bit on every CLEAR write.
    //                   Sync 2-FF + edge detect -> one MCLK pulse per write.
    // -------------------------------------------------------------------------
    reg [1:0] cfg_mode_s0, cfg_mode_s1;
    reg       clr_tog_s0, clr_tog_s1, clr_tog_s2;
    always @(posedge clk_12m288_i) begin
        if (!resetn_i) begin
            cfg_mode_s0 <= 2'd0;
            cfg_mode_s1 <= 2'd0;
            clr_tog_s0  <= 1'b0;
            clr_tog_s1  <= 1'b0;
            clr_tog_s2  <= 1'b0;
        end else begin
            cfg_mode_s0 <= cfg_mode_i;
            cfg_mode_s1 <= cfg_mode_s0;
            clr_tog_s0  <= cfg_clear_toggle_i;
            clr_tog_s1  <= clr_tog_s0;
            clr_tog_s2  <= clr_tog_s1;
        end
    end
    wire [1:0] cfg_mode      = cfg_mode_s1;
    wire       cfg_clear_pul = clr_tog_s1 ^ clr_tog_s2;

    // -------------------------------------------------------------------------
    // mclk_phase: 2-bit free-running counter clocked by 12.288 MHz.
    //   phase 0,1 -> BCLK high
    //   phase 2,3 -> BCLK low
    // BCLK = 12.288 MHz / 4 = 3.072 MHz.
    // -------------------------------------------------------------------------
    reg [1:0] mclk_phase;
    always @(posedge clk_12m288_i) begin
        if (!resetn_i)
            mclk_phase <= 2'd0;
        else
            mclk_phase <= mclk_phase + 2'd1;
    end

    wire bclk_int   = ~mclk_phase[1];
    assign ext_pmod_i2s2_da_sclk_o = bclk_int;
    assign ext_pmod_i2s2_ad_sclk_o = bclk_int;
    // Internal BCLK / LRCK fanout for the AudioLab DSP I2S converter. Driven
    // from the same divider that produces the JB pins so the DSP chain runs
    // in the same clock domain as the Pmod ADC sampling and the DAC SDIN
    // serializer. No CDC needed between i2s_to_stream_0 and pmod_master_0.
    assign dsp_bclk_o = bclk_int;

    // Single-MCLK pre-pulses for BCLK edge handling.
    //   bclk_fall_pre: next posedge of clk_12m288 will land on a BCLK falling
    //                  edge. Use this as the global "bit slot tick" so the
    //                  receiver sees stable DIN during the next BCLK high.
    //   bclk_rise_pre: next posedge will land on a BCLK rising edge. Use this
    //                  as the SDOUT sampling tick (data stable on BCLK high).
    wire bclk_fall_pre = (mclk_phase == 2'd1);
    wire bclk_rise_pre = (mclk_phase == 2'd3);

    // -------------------------------------------------------------------------
    // bit_idx: 0..63 BCLK slot within a stereo frame.
    //   bit_idx[5] == 0 -> LEFT slot  (LRCK low)
    //   bit_idx[5] == 1 -> RIGHT slot (LRCK high)
    // bit_idx advances once per BCLK falling edge (i.e. once per "slot").
    // -------------------------------------------------------------------------
    reg [5:0] bit_idx;
    always @(posedge clk_12m288_i) begin
        if (!resetn_i)
            bit_idx <= 6'd0;
        else if (bclk_fall_pre)
            bit_idx <= bit_idx + 6'd1;
    end

    wire lrck_int = bit_idx[5];
    assign ext_pmod_i2s2_da_lrck_o = lrck_int;
    assign ext_pmod_i2s2_ad_lrck_o = lrck_int;
    assign dsp_lrck_o = lrck_int;

    // slot_idx 0..31 inside one channel slot. I2S Philips uses
    //   slot_idx 0       -> 1 BCLK delay (DIN = 0)
    //   slot_idx 1..24   -> 24 data bits, MSB first
    //   slot_idx 25..31  -> 7 zero pad LSBs
    wire [4:0] slot_idx = bit_idx[4:0];

    // -------------------------------------------------------------------------
    // 1 kHz sine ROM at 48 kHz fs (48 samples / cycle), signed 24-bit,
    // quarter scale (amplitude = 2^21 = 2097152). Reused from pcm5102_dac_tone.
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

    reg [5:0] sample_idx;
    always @(posedge clk_12m288_i) begin
        if (!resetn_i)
            sample_idx <= 6'd0;
        else if (bclk_fall_pre && bit_idx == 6'd63)
            sample_idx <= (sample_idx == 6'd47) ? 6'd0 : sample_idx + 6'd1;
    end

    wire signed [23:0] tone_sample = sine_rom[sample_idx];

    // -------------------------------------------------------------------------
    // RX path: sample SDOUT on BCLK rising edge into a 2-FF synchronizer,
    // then shift into a 24-bit register MSB-first while slot_idx 1..24 of
    // the current channel slot is active. LEFT capture finishes at slot_idx
    // 25 of the LEFT slot; RIGHT capture finishes at slot_idx 25 of the
    // RIGHT slot. The 24-bit captured values get latched into last_left/
    // last_right at the slot boundary.
    // -------------------------------------------------------------------------
    reg [1:0] sdout_sync;
    always @(posedge clk_12m288_i) begin
        if (!resetn_i)
            sdout_sync <= 2'b00;
        else
            sdout_sync <= {sdout_sync[0], ext_pmod_i2s2_ad_sdout_i};
    end
    wire sdout_q = sdout_sync[1];

    reg [23:0] rx_shift;
    reg [23:0] rx_left_captured;
    reg [23:0] rx_right_captured;

    // Shift in on BCLK rising edge during slot_idx 1..24 of any slot.
    wire rx_shift_en = bclk_rise_pre && (slot_idx >= 5'd1) && (slot_idx <= 5'd24);
    // Latch the completed 24-bit at slot_idx 25 of the just-finished slot.
    wire rx_latch_en = bclk_fall_pre && (slot_idx == 5'd25);

    always @(posedge clk_12m288_i) begin
        if (!resetn_i) begin
            rx_shift          <= 24'd0;
            rx_left_captured  <= 24'd0;
            rx_right_captured <= 24'd0;
        end else begin
            if (rx_shift_en)
                rx_shift <= {rx_shift[22:0], sdout_q};
            if (rx_latch_en) begin
                if (lrck_int == 1'b0)
                    rx_left_captured <= rx_shift;
                else
                    rx_right_captured <= rx_shift;
            end
        end
    end

    // -------------------------------------------------------------------------
    // TX path: pick the 24-bit source for DAC SDIN based on cfg_mode_i.
    //   mode 0: tone sample on both L and R
    //   mode 1: ADC-captured sample on L; ADC-captured right on R (true stereo loopback)
    // Output is serialized over the next channel slot using slot_idx.
    // -------------------------------------------------------------------------
    wire signed [23:0] tx_sample_left  = (cfg_mode == 2'd1) ? rx_left_captured  : tone_sample;
    wire signed [23:0] tx_sample_right = (cfg_mode == 2'd1) ? rx_right_captured : tone_sample;

    // Latch the per-slot sample on the boundary so the serializer reads a
    // stable value through the whole 32-bit slot.
    reg signed [23:0] tx_cur_sample;
    always @(posedge clk_12m288_i) begin
        if (!resetn_i)
            tx_cur_sample <= 24'sd0;
        else if (bclk_fall_pre && slot_idx == 5'd31) begin
            // slot_idx 31 -> bit_idx will become 32 (start of right) or 0 (start
            // of left). bit_idx[5] before increment == lrck for the current slot,
            // so we pre-load the NEXT slot's sample by inverting lrck_int.
            tx_cur_sample <= lrck_int ? tx_sample_left : tx_sample_right;
        end
    end

    // Internal serializer for mode 0 / 1: slot_idx 1..24 = MSB-first data,
    // else 0. tx_cur_sample is a latched 24-bit (tone or ADC echo).
    reg din_internal_r;
    always @(*) begin
        if (slot_idx >= 5'd1 && slot_idx <= 5'd24)
            din_internal_r = tx_cur_sample[24 - slot_idx];
        else
            din_internal_r = 1'b0;
    end

    // -------------------------------------------------------------------------
    // Mode 2 RIGHT-to-LEFT mirror buffer.
    //
    // The i2s_to_stream IP that bridges the AudioLab DSP chain into the
    // Pmod I2S2 codec has two issues that make mode 2 sound distorted even
    // with every effect off:
    //   1. i2sIn LEFT extraction is broken. DMA captures of axis_li_tdata
    //      show LEFT hitting near -0 dBFS while Pmod-master deserializer
    //      peaks at the same time stay below -5 dBFS. RIGHT extraction
    //      matches Pmod-master exactly.
    //   2. i2sOut updates `so` on BCLK rising edges -- the same edge the
    //      DAC samples on -- so the DAC can latch the OLD bit and play a
    //      1-BCLK-shifted bitstream that sounds like asymmetric distortion.
    //
    // Fix: capture i2s_to_stream/so once per BCLK during the RIGHT slot of
    // every frame into `mode2_right_snapshot` (32 bits, indexed by
    // slot_idx). In mode 2, drive the DAC SDIN from the same buffer
    // position regardless of LEFT vs RIGHT slot. The user hears mono
    // (= IP RIGHT slot data in both ears) with a one-frame delay (about
    // 21 us, imperceptible).
    //
    // The snapshot is updated at bclk_fall_pre, i.e., the MCLK posedge
    // where mclk_phase is 01. At that moment dsp_dac_sdin_i = the IP's so
    // post the most-recent BCLK rising edge, so the bit is the IP's
    // intended payload for the current slot (not the pre-edge stale
    // value the DAC would otherwise see). The DAC samples on BCLK rising
    // edges and so reads din_mux_r = the snapshot at the slot index of
    // the period that just started -- which holds the previous frame's
    // matching RIGHT slot bit. Identical bits land in both LEFT and
    // RIGHT slots, giving a clean mono signal.
    //
    // Mode 0 / 1 / 3 paths are unchanged.
    // -------------------------------------------------------------------------
    reg [31:0] mode2_right_snapshot;
    always @(posedge clk_12m288_i) begin
        if (!resetn_i) begin
            mode2_right_snapshot <= 32'd0;
        end else if (bclk_fall_pre && bit_idx[5]) begin
            // bit_idx pre-edge here is the slot index that just finished
            // its BCLK period (the falling edge is about to increment it).
            // bit_idx[5] == 1 -> the just-ended period was a RIGHT slot
            // bit.
            mode2_right_snapshot[bit_idx[4:0]] <= dsp_dac_sdin_i;
        end
    end

    // Final DAC SDIN mux. cfg_mode is 2-FF-synchronized into the MCLK domain
    // above, so this is a clean combinational select.
    //   2'd0 -> internal serializer (tone)
    //   2'd1 -> internal serializer (ADC echo via cfg_mode==1 in tx_sample_*)
    //   2'd2 -> mode2_right_snapshot[slot_idx]  (RIGHT-mirrored mono, both
    //           ears get the previous frame's RIGHT slot bits; works around
    //           the i2s_to_stream IP LEFT-extraction bug and the 1-BCLK
    //           setup race documented above.)
    //   2'd3 -> mute
    // The mode 0 / mode 1 distinction is already encoded inside
    // `tx_sample_left` / `tx_sample_right` (they pick tone vs ADC echo based
    // on cfg_mode == 2'd1); the internal serializer is shared.
    reg din_mux_r;
    always @(*) begin
        case (cfg_mode)
            2'd0:    din_mux_r = din_internal_r;
            2'd1:    din_mux_r = din_internal_r;
            2'd2:    din_mux_r = mode2_right_snapshot[bit_idx[4:0]];
            default: din_mux_r = 1'b0;
        endcase
    end
    assign ext_pmod_i2s2_da_sdin_o = din_mux_r;

    // -------------------------------------------------------------------------
    // Status counters (MCLK domain). Read via axi_pmod_i2s2_status.
    //
    // frame_count: bumped at the start of each LEFT slot (bit_idx -> 0).
    // last_left / last_right: updated when the rx capture latches.
    // peak_abs_left / peak_abs_right: max |sample| seen since reset.
    // nonzero_count: number of captured samples != 0.
    // sdout_transition_count: counts SDOUT edges (any direction) -- detects
    //                          a stuck-0 / stuck-1 hardware path.
    // clip_count: number of samples equal to +/- full-scale (saturation hint).
    // lrclk_seen, bclk_seen: sticky "seen at least one edge" flags.
    // sdout_alive_o: sticky "saw at least one edge on SDOUT" flag.
    // -------------------------------------------------------------------------

    // sdout transition detector
    reg sdout_q_prev;
    always @(posedge clk_12m288_i) begin
        if (!resetn_i)
            sdout_q_prev <= 1'b0;
        else
            sdout_q_prev <= sdout_q;
    end
    wire sdout_edge = sdout_q ^ sdout_q_prev;

    // lrclk / bclk edge detectors (purely informative; in master mode the
    // FPGA itself drives both, so these should always be true).
    reg lrck_int_prev;
    reg bclk_int_prev;
    always @(posedge clk_12m288_i) begin
        if (!resetn_i) begin
            lrck_int_prev <= 1'b0;
            bclk_int_prev <= 1'b0;
        end else begin
            lrck_int_prev <= lrck_int;
            bclk_int_prev <= bclk_int;
        end
    end

    // |x| for the just-completed 24-bit sample (rx_shift snapshot at latch).
    // -2^23 maps to +2^23-1 to avoid overflow.
    wire signed [23:0] rx_shift_signed = $signed(rx_shift);
    wire [23:0] abs_rx = rx_shift_signed[23]
        ? (rx_shift_signed == -24'sd8388608 ? 24'd8388607 : -rx_shift_signed)
        : rx_shift_signed;

    always @(posedge clk_12m288_i) begin
        if (!resetn_i) begin
            frame_count_o            <= 32'd0;
            nonzero_count_o          <= 32'd0;
            sdout_transition_count_o <= 32'd0;
            clip_count_o             <= 32'd0;
            last_left_o              <= 24'd0;
            last_right_o             <= 24'd0;
            peak_abs_left_o          <= 24'd0;
            peak_abs_right_o         <= 24'd0;
            lrclk_seen_o             <= 1'b0;
            bclk_seen_o              <= 1'b0;
            sdout_alive_o            <= 1'b0;
        end else if (cfg_clear_pul) begin
            // CLEAR pulse: zero the *clearable* counters / peaks, but leave
            // last_left / last_right so the user can still see "the last
            // sample we got". frame_count_o is left alone too (it's a free-
            // running monotonic counter for "is the I2S frame engine alive").
            nonzero_count_o          <= 32'd0;
            sdout_transition_count_o <= 32'd0;
            clip_count_o             <= 32'd0;
            peak_abs_left_o          <= 24'd0;
            peak_abs_right_o         <= 24'd0;
        end else begin
            if (sdout_edge) begin
                sdout_transition_count_o <= sdout_transition_count_o + 32'd1;
                sdout_alive_o            <= 1'b1;
            end
            if (lrck_int != lrck_int_prev)
                lrclk_seen_o <= 1'b1;
            if (bclk_int != bclk_int_prev)
                bclk_seen_o <= 1'b1;

            // frame_count: rising LRCK edge (LEFT -> RIGHT means R slot started,
            //              so a full L+R frame is being shipped; bump on LEFT
            //              slot start by detecting lrck high->low.)
            if (lrck_int_prev == 1'b1 && lrck_int == 1'b0)
                frame_count_o <= frame_count_o + 32'd1;

            // Latch on the same tick as rx_latch_en so AXI side sees a clean
            // 24-bit value.
            if (rx_latch_en) begin
                if (lrck_int == 1'b0) begin
                    last_left_o <= rx_shift;
                    if (rx_shift != 24'd0)
                        nonzero_count_o <= nonzero_count_o + 32'd1;
                    if (rx_shift == 24'h7FFFFF || rx_shift == 24'h800000)
                        clip_count_o <= clip_count_o + 32'd1;
                    if (abs_rx > peak_abs_left_o)
                        peak_abs_left_o <= abs_rx;
                end else begin
                    last_right_o <= rx_shift;
                    if (rx_shift != 24'd0)
                        nonzero_count_o <= nonzero_count_o + 32'd1;
                    if (rx_shift == 24'h7FFFFF || rx_shift == 24'h800000)
                        clip_count_o <= clip_count_o + 32'd1;
                    if (abs_rx > peak_abs_right_o)
                        peak_abs_right_o <= abs_rx;
                end
            end
        end
    end

endmodule

`default_nettype wire
