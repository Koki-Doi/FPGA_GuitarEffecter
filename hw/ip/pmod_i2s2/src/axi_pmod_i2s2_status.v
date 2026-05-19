// =============================================================================
// axi_pmod_i2s2_status
//
// Small AXI4-Lite slave that exposes the `pmod_i2s2_master` runtime status to
// PYNQ Python so the bring-up smoke can verify (a) DAC clocks are alive,
// (b) ADC SDOUT is delivering non-trivial samples, and (c) the mode select
// (TX tone vs ADC->DAC loopback) is honoured at runtime.
//
// Phase Pmod-1/2 of Audio-Lab-PYNQ. Self-contained Verilog; no Xilinx IP
// dependency. Used by the block design as a module reference, exactly the
// way axi_encoder_input is wired in encoder_integration.tcl.
//
// AXI register map (offsets are byte addresses, 32-bit registers):
//
//   0x00 VERSION         (R)  0x00480001  (Pmod I2S2 = D48, rev 1)
//   0x04 STATUS          (R)
//        bit  0     lrclk_seen
//        bit  1     bclk_seen
//        bit  2     sdout_alive
//        bit  9:8   cfg_mode (current)
//   0x08 FRAME_COUNT     (R)  bumped per stereo frame
//   0x0C NONZERO_COUNT   (R)  number of ADC samples != 0
//   0x10 SDOUT_XCOUNT    (R)  edges seen on ADC SDOUT
//   0x14 CLIP_COUNT      (R)  ADC samples == +/- full-scale
//   0x18 LAST_LEFT       (R)  signed int32, sign-extended from 24-bit
//   0x1C LAST_RIGHT      (R)  signed int32, sign-extended from 24-bit
//   0x20 PEAK_ABS_LEFT   (R)  unsigned 24-bit (zero-extended)
//   0x24 PEAK_ABS_RIGHT  (R)
//   0x28 MODE            (R/W) [1:0] cfg_mode  (0 = TX tone + ADC probe,
//                                                1 = ADC -> DAC loopback)
//   0x2C CLEAR           (W)   write 1 to bit 0 to zero NONZERO/CLIP/PEAK
//                              counters and SDOUT_XCOUNT (frame_count keeps
//                              running for "is it alive" sanity).
//
// The status inputs live in the 12.288 MHz MCLK domain inside
// `pmod_i2s2_master`. This slave samples each input through a 2-FF
// synchronizer before exposing it on the AXI side. Multi-bit fields can
// momentarily tear during sampling but the bring-up smoke only watches
// monotonically-rising counters / sticky flags, so tearing is acceptable.
//
// CLEAR / MODE writes are AXI-side registers; their effect is sent to
// pmod_i2s2_master through a toggle-pulse handshake (mode is just a level,
// the clear pulse is widened to one MCLK period inside the master via a
// 3-FF synchronizer + edge detector).
// =============================================================================

`default_nettype none

module axi_pmod_i2s2_status #(
    parameter integer C_S_AXI_ADDR_WIDTH = 6,
    parameter integer C_S_AXI_DATA_WIDTH = 32
)(
    input  wire                              s_axi_aclk,
    input  wire                              s_axi_aresetn,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_awaddr,
    input  wire [2:0]                        s_axi_awprot,
    input  wire                              s_axi_awvalid,
    output reg                               s_axi_awready,

    input  wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                              s_axi_wvalid,
    output reg                               s_axi_wready,

    output reg  [1:0]                        s_axi_bresp,
    output reg                               s_axi_bvalid,
    input  wire                              s_axi_bready,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_araddr,
    input  wire [2:0]                        s_axi_arprot,
    input  wire                              s_axi_arvalid,
    output reg                               s_axi_arready,

    output reg  [C_S_AXI_DATA_WIDTH-1:0]     s_axi_rdata,
    output reg  [1:0]                        s_axi_rresp,
    output reg                               s_axi_rvalid,
    input  wire                              s_axi_rready,

    // Status inputs from pmod_i2s2_master (MCLK domain). Each line is sampled
    // through a 2-FF synchronizer before exposure on AXI.
    input  wire [31:0]                       frame_count_i,
    input  wire [31:0]                       nonzero_count_i,
    input  wire [31:0]                       sdout_transition_count_i,
    input  wire [31:0]                       clip_count_i,
    input  wire [23:0]                       last_left_i,
    input  wire [23:0]                       last_right_i,
    input  wire [23:0]                       peak_abs_left_i,
    input  wire [23:0]                       peak_abs_right_i,
    input  wire                              lrclk_seen_i,
    input  wire                              bclk_seen_i,
    input  wire                              sdout_alive_i,

    // Control outputs to pmod_i2s2_master.
    //   cfg_mode_o         : level signal; resync inside the master with a 2-FF.
    //   cfg_clear_toggle_o : every CLEAR write flips this bit. The master
    //                        synchronizes the toggle and edge-detects it.
    //                        Robust under AXI<->MCLK clock-period mismatch.
    output reg  [1:0]                        cfg_mode_o,
    output reg                               cfg_clear_toggle_o
);

    localparam [31:0] VERSION_VALUE = 32'h00480001;

    // -------------------------------------------------------------------------
    // 2-FF synchronizers for each MCLK-domain status input.
    // -------------------------------------------------------------------------
    reg [31:0] frame_count_s0,   frame_count_s1;
    reg [31:0] nonzero_count_s0, nonzero_count_s1;
    reg [31:0] xcount_s0,        xcount_s1;
    reg [31:0] clip_s0,          clip_s1;
    reg [23:0] last_left_s0,     last_left_s1;
    reg [23:0] last_right_s0,    last_right_s1;
    reg [23:0] peak_left_s0,     peak_left_s1;
    reg [23:0] peak_right_s0,    peak_right_s1;
    reg [2:0]  flags_s0,         flags_s1;

    always @(posedge s_axi_aclk) begin
        frame_count_s0   <= frame_count_i;            frame_count_s1   <= frame_count_s0;
        nonzero_count_s0 <= nonzero_count_i;          nonzero_count_s1 <= nonzero_count_s0;
        xcount_s0        <= sdout_transition_count_i; xcount_s1        <= xcount_s0;
        clip_s0          <= clip_count_i;             clip_s1          <= clip_s0;
        last_left_s0     <= last_left_i;              last_left_s1     <= last_left_s0;
        last_right_s0    <= last_right_i;             last_right_s1    <= last_right_s0;
        peak_left_s0     <= peak_abs_left_i;          peak_left_s1     <= peak_left_s0;
        peak_right_s0    <= peak_abs_right_i;         peak_right_s1    <= peak_right_s0;
        flags_s0         <= {sdout_alive_i, bclk_seen_i, lrclk_seen_i};
        flags_s1         <= flags_s0;
    end

    wire        flag_lrclk_seen  = flags_s1[0];
    wire        flag_bclk_seen   = flags_s1[1];
    wire        flag_sdout_alive = flags_s1[2];

    // -------------------------------------------------------------------------
    // Cfg_mode + clear pulse register (AXI clock domain). cfg_clear_pulse_o is
    // a 1-AXI-clock pulse; the master must edge-detect after re-sync.
    // -------------------------------------------------------------------------
    initial cfg_mode_o         = 2'd0;
    initial cfg_clear_toggle_o = 1'b0;

    // -------------------------------------------------------------------------
    // AXI4-Lite write FSM (single writer for the two writable regs). Pattern
    // mirrors axi_encoder_input.v: latch the awaddr in the AW phase, commit
    // the write in the W phase using the latched address. The earlier
    // "use axi_awaddr_q in the same cycle it is being updated" formulation
    // dropped the new awaddr in the case statement, which on PYNQ caused
    // back-to-back MMIO writes (e.g. write MODE=0 then write CLEAR=1) to
    // commit at the previous transaction's address. The result was that
    // the CLEAR write landed on MODE and silently flipped cfg_mode_o.
    // -------------------------------------------------------------------------
    localparam [3:0]
        REG_VERSION_W = 4'h0,
        REG_MODE_W    = 4'hA,
        REG_CLEAR_W   = 4'hB;

    wire [3:0] reg_sel_w = s_axi_awaddr[5:2];
    reg  [3:0] write_addr_lat;
    reg        write_in_progress;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_awready      <= 1'b0;
            s_axi_wready       <= 1'b0;
            s_axi_bvalid       <= 1'b0;
            s_axi_bresp        <= 2'b00;
            write_in_progress  <= 1'b0;
            write_addr_lat     <= 4'h0;
            cfg_mode_o         <= 2'd0;
            cfg_clear_toggle_o <= 1'b0;
        end else begin
            // 1. AW phase: latch the address into write_addr_lat.
            if (!write_in_progress && s_axi_awvalid && !s_axi_awready) begin
                s_axi_awready     <= 1'b1;
                write_addr_lat    <= reg_sel_w;
                write_in_progress <= 1'b1;
            end else begin
                s_axi_awready <= 1'b0;
            end

            // 2. W phase: commit using the latched address.
            if (write_in_progress && s_axi_wvalid && !s_axi_wready && !s_axi_bvalid) begin
                s_axi_wready <= 1'b1;
                case (write_addr_lat)
                    REG_MODE_W: begin
                        if (s_axi_wstrb[0])
                            cfg_mode_o <= s_axi_wdata[1:0];
                    end
                    REG_CLEAR_W: begin
                        if (s_axi_wstrb[0] && s_axi_wdata[0])
                            cfg_clear_toggle_o <= ~cfg_clear_toggle_o;
                    end
                    default: ; // RO regs: ignore writes
                endcase
                s_axi_bvalid      <= 1'b1;
                s_axi_bresp       <= 2'b00;
                write_in_progress <= 1'b0;
            end else begin
                s_axi_wready <= 1'b0;
            end

            // 3. B phase: deassert bvalid when accepted.
            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // AXI4-Lite read channel
    // -------------------------------------------------------------------------
    reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr_q;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00;
            s_axi_rdata   <= {C_S_AXI_DATA_WIDTH{1'b0}};
            axi_araddr_q  <= {C_S_AXI_ADDR_WIDTH{1'b0}};
        end else begin
            if (!s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
                axi_araddr_q  <= s_axi_araddr;
            end else begin
                s_axi_arready <= 1'b0;
            end

            if (s_axi_arready && s_axi_arvalid && !s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00;
                case (axi_araddr_q[5:2])
                    4'h0: s_axi_rdata <= VERSION_VALUE;
                    4'h1: s_axi_rdata <= {22'd0, cfg_mode_o, 5'd0,
                                          flag_sdout_alive, flag_bclk_seen, flag_lrclk_seen};
                    4'h2: s_axi_rdata <= frame_count_s1;
                    4'h3: s_axi_rdata <= nonzero_count_s1;
                    4'h4: s_axi_rdata <= xcount_s1;
                    4'h5: s_axi_rdata <= clip_s1;
                    4'h6: s_axi_rdata <= {{8{last_left_s1[23]}}, last_left_s1};
                    4'h7: s_axi_rdata <= {{8{last_right_s1[23]}}, last_right_s1};
                    4'h8: s_axi_rdata <= {8'd0, peak_left_s1};
                    4'h9: s_axi_rdata <= {8'd0, peak_right_s1};
                    4'hA: s_axi_rdata <= {30'd0, cfg_mode_o};
                    4'hB: s_axi_rdata <= 32'd0;        // CLEAR is write-only
                    default: s_axi_rdata <= 32'h0;
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule

`default_nettype wire
