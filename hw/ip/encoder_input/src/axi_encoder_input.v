// =============================================================================
// axi_encoder_input
//
// 3-channel rotary encoder input IP with debouncing, quadrature decoding,
// signed delta accumulator, signed absolute counter, and short/long press
// event latches behind a tiny AXI4-Lite slave.
//
// Phase 7F/7G of FPGA_GuitarEffecter. Self-contained Verilog module used as a
// block-design module reference. No external IP dependencies.
//
// External pins (3.3V LVCMOS33 on Raspberry Pi header):
//   enc[012]_clk_i / enc[012]_dt_i / enc[012]_sw_i
//
// AXI register map (offsets are byte addresses, register width is 32-bit):
//   0x00 STATUS         (R)  event/short/long/sw-level latches
//        bit  2:0  rotate_event[2:0]
//        bit 10:8  short_press[2:0]
//        bit 18:16 long_press[2:0]
//        bit 26:24 sw_level[2:0]  (1 = pressed after sw_active_low)
//   0x04 DELTA_PACKED   (R)  signed int8 per encoder; cleared on read when
//                            cfg_clear_on_read = 1.
//   0x08 COUNT0         (R)  signed int32 absolute count, encoder 0
//   0x0C COUNT1         (R)
//   0x10 COUNT2         (R)
//   0x14 BUTTON_STATE   (R)  raw debounced SW level (same as STATUS[26:24])
//   0x18 CONFIG         (R/W)
//        bit  7:0  debounce_ms (1..255; sampled at 1 ms tick)
//        bit  8    clear_on_read_enable (STATUS/DELTA auto-clear on read)
//        bit  9    acceleration_enable (reserved)
//        bit 12:10 reverse_direction[2:0]
//        bit 15:13 clk_dt_swap[2:0]
//        bit 16    sw_active_low (default 1)
//   0x1C CLEAR_EVENTS   (W)  write 1 to STATUS bit positions to clear.
//                            Bit 0..2 also clears the accumulated delta.
//   0x20 VERSION        (R)  0x00070001
//
// Long-press threshold is fixed at 500 ms (LONG_PRESS_MS parameter).
// A 1 ms internal tick is divided from the AXI clock assuming 100 MHz
// (FCLK_CLK0 in this design).
//
// Quadrature decoding accumulates +1 / -1 per stable AB transition. A typical
// detented encoder produces 4 transitions per detent; the Python driver
// divides the raw delta by 4 to get a detent count.
// =============================================================================

`default_nettype none

module axi_encoder_input #(
    parameter integer C_S_AXI_ADDR_WIDTH = 6,
    parameter integer C_S_AXI_DATA_WIDTH = 32
)(
    // AXI4-Lite slave
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

    // External encoder pins (asynchronous, raw from RPi header)
    input  wire                              enc0_clk_i,
    input  wire                              enc0_dt_i,
    input  wire                              enc0_sw_i,
    input  wire                              enc1_clk_i,
    input  wire                              enc1_dt_i,
    input  wire                              enc1_sw_i,
    input  wire                              enc2_clk_i,
    input  wire                              enc2_dt_i,
    input  wire                              enc2_sw_i
);

    // -------------------------------------------------------------------------
    // Constants
    // Default: clear_on_read=1, sw_active_low=1, debounce_ms=5 -> 0x00010105
    // -------------------------------------------------------------------------
    localparam [31:0] CONFIG_DEFAULT = 32'h00010105;
    localparam [31:0] VERSION_VALUE  = 32'h00070001;
    localparam integer LONG_PRESS_MS = 500;

    // CONFIG register
    reg [31:0] cfg;
    wire [7:0]  cfg_debounce_ms   = cfg[7:0];
    wire        cfg_clear_on_read = cfg[8];
    // wire cfg_accel             = cfg[9];   // reserved
    wire [2:0]  cfg_reverse_dir   = cfg[12:10];
    wire [2:0]  cfg_clk_dt_swap   = cfg[15:13];
    wire        cfg_sw_active_low = cfg[16];

    // -------------------------------------------------------------------------
    // 1 ms tick generator (FCLK_CLK0 = 100 MHz, divide by 100,000)
    // -------------------------------------------------------------------------
    reg [16:0] tick_div;
    reg        tick_1ms;
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            tick_div <= 17'd0;
            tick_1ms <= 1'b0;
        end else if (tick_div == 17'd99_999) begin
            tick_div <= 17'd0;
            tick_1ms <= 1'b1;
        end else begin
            tick_div <= tick_div + 17'd1;
            tick_1ms <= 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // Bundle the raw encoder inputs into arrays for indexed access.
    // -------------------------------------------------------------------------
    wire [2:0] enc_clk_raw = {enc2_clk_i, enc1_clk_i, enc0_clk_i};
    wire [2:0] enc_dt_raw  = {enc2_dt_i,  enc1_dt_i,  enc0_dt_i };
    wire [2:0] enc_sw_raw  = {enc2_sw_i,  enc1_sw_i,  enc0_sw_i };

    // -------------------------------------------------------------------------
    // Per-encoder pipeline state
    // -------------------------------------------------------------------------
    reg [1:0] sync_clk [0:2];
    reg [1:0] sync_dt  [0:2];
    reg [1:0] sync_sw  [0:2];

    reg       deb_clk_stable [0:2];
    reg       deb_dt_stable  [0:2];
    reg       deb_sw_stable  [0:2];
    reg [7:0] deb_clk_cnt    [0:2];
    reg [7:0] deb_dt_cnt     [0:2];
    reg [7:0] deb_sw_cnt     [0:2];
    reg       deb_clk_prev   [0:2];
    reg       deb_dt_prev    [0:2];
    reg       deb_sw_prev    [0:2];

    reg [1:0] q_prev   [0:2];

    reg signed [7:0]  delta_acc [0:2];
    reg signed [31:0] count_abs [0:2];
    reg               rotate_evt[0:2];
    reg               short_evt [0:2];
    reg               long_evt  [0:2];
    reg               sw_pressed[0:2];
    reg               sw_pressed_d[0:2];
    reg [15:0]        press_ms_cnt[0:2];
    reg               long_fired [0:2];

    integer i;
    initial begin
        for (i = 0; i < 3; i = i + 1) begin
            sync_clk[i] = 2'b11;
            sync_dt[i]  = 2'b11;
            sync_sw[i]  = 2'b11;
            deb_clk_stable[i] = 1'b1;
            deb_dt_stable[i]  = 1'b1;
            deb_sw_stable[i]  = 1'b1;
            deb_clk_cnt[i] = 8'd0;
            deb_dt_cnt[i]  = 8'd0;
            deb_sw_cnt[i]  = 8'd0;
            deb_clk_prev[i] = 1'b1;
            deb_dt_prev[i]  = 1'b1;
            deb_sw_prev[i]  = 1'b1;
            q_prev[i] = 2'b11;
            delta_acc[i] = 8'sd0;
            count_abs[i] = 32'sd0;
            rotate_evt[i] = 1'b0;
            short_evt[i]  = 1'b0;
            long_evt[i]   = 1'b0;
            sw_pressed[i] = 1'b0;
            sw_pressed_d[i] = 1'b0;
            press_ms_cnt[i] = 16'd0;
            long_fired[i] = 1'b0;
        end
        cfg = CONFIG_DEFAULT;
    end

    // -------------------------------------------------------------------------
    // Clear-request pulses combine writes-to-CLEAR_EVENTS and clear-on-read
    // -------------------------------------------------------------------------
    reg [2:0] wclr_rotate;
    reg [2:0] wclr_short;
    reg [2:0] wclr_long;
    reg [2:0] rclr_rotate;
    reg [2:0] rclr_short;
    reg [2:0] rclr_long;
    wire [2:0] clr_rotate = wclr_rotate | rclr_rotate;
    wire [2:0] clr_short  = wclr_short  | rclr_short;
    wire [2:0] clr_long   = wclr_long   | rclr_long;

    // -------------------------------------------------------------------------
    // Per-encoder pipeline (generate-for)
    // -------------------------------------------------------------------------
    genvar g;
    generate
        for (g = 0; g < 3; g = g + 1) begin : g_enc
            // Stage 1: 2-stage synchroniser
            always @(posedge s_axi_aclk) begin
                sync_clk[g] <= {sync_clk[g][0], enc_clk_raw[g]};
                sync_dt[g]  <= {sync_dt[g][0],  enc_dt_raw[g]};
                sync_sw[g]  <= {sync_sw[g][0],  enc_sw_raw[g]};
            end

            // Stage 2: debounce (cfg_debounce_ms consecutive ms samples)
            always @(posedge s_axi_aclk) begin
                if (!s_axi_aresetn) begin
                    deb_clk_stable[g] <= 1'b1;
                    deb_dt_stable[g]  <= 1'b1;
                    deb_sw_stable[g]  <= 1'b1;
                    deb_clk_cnt[g] <= 8'd0;
                    deb_dt_cnt[g]  <= 8'd0;
                    deb_sw_cnt[g]  <= 8'd0;
                    deb_clk_prev[g] <= 1'b1;
                    deb_dt_prev[g]  <= 1'b1;
                    deb_sw_prev[g]  <= 1'b1;
                end else if (tick_1ms) begin
                    // CLK
                    if (sync_clk[g][1] == deb_clk_prev[g]) begin
                        if (deb_clk_cnt[g] < cfg_debounce_ms)
                            deb_clk_cnt[g] <= deb_clk_cnt[g] + 8'd1;
                        else
                            deb_clk_stable[g] <= sync_clk[g][1];
                    end else begin
                        deb_clk_cnt[g] <= 8'd0;
                    end
                    deb_clk_prev[g] <= sync_clk[g][1];
                    // DT
                    if (sync_dt[g][1] == deb_dt_prev[g]) begin
                        if (deb_dt_cnt[g] < cfg_debounce_ms)
                            deb_dt_cnt[g] <= deb_dt_cnt[g] + 8'd1;
                        else
                            deb_dt_stable[g] <= sync_dt[g][1];
                    end else begin
                        deb_dt_cnt[g] <= 8'd0;
                    end
                    deb_dt_prev[g] <= sync_dt[g][1];
                    // SW
                    if (sync_sw[g][1] == deb_sw_prev[g]) begin
                        if (deb_sw_cnt[g] < cfg_debounce_ms)
                            deb_sw_cnt[g] <= deb_sw_cnt[g] + 8'd1;
                        else
                            deb_sw_stable[g] <= sync_sw[g][1];
                    end else begin
                        deb_sw_cnt[g] <= 8'd0;
                    end
                    deb_sw_prev[g] <= sync_sw[g][1];
                end
            end
        end
    endgenerate

    // Stage 3/4/5: quadrature decode + delta/count + press timer.
    // Implemented per-channel with explicit logic for clarity.
    genvar h;
    generate
        for (h = 0; h < 3; h = h + 1) begin : g_decode
            // Effective A/B after optional swap
            wire a_eff = cfg_clk_dt_swap[h] ? deb_dt_stable[h]  : deb_clk_stable[h];
            wire b_eff = cfg_clk_dt_swap[h] ? deb_clk_stable[h] : deb_dt_stable[h];
            wire [1:0] q_now = {a_eff, b_eff};

            // Quadrature transition table -> step in {-1, 0, +1}
            reg signed [1:0] step;
            always @* begin
                case ({q_prev[h], q_now})
                    4'b0001, 4'b0111, 4'b1110, 4'b1000: step = 2'sd1;
                    4'b0010, 4'b1011, 4'b1101, 4'b0100: step = -2'sd1;
                    default: step = 2'sd0;
                endcase
            end
            wire signed [1:0] step_dir = cfg_reverse_dir[h] ? -step : step;

            always @(posedge s_axi_aclk) begin
                if (!s_axi_aresetn) begin
                    q_prev[h]      <= 2'b11;
                    delta_acc[h]   <= 8'sd0;
                    count_abs[h]   <= 32'sd0;
                    rotate_evt[h]  <= 1'b0;
                    sw_pressed[h]  <= 1'b0;
                    sw_pressed_d[h] <= 1'b0;
                    short_evt[h]   <= 1'b0;
                    long_evt[h]    <= 1'b0;
                    press_ms_cnt[h] <= 16'd0;
                    long_fired[h]  <= 1'b0;
                end else begin
                    q_prev[h] <= q_now;
                    // Delta + absolute count
                    if (step_dir != 2'sd0) begin
                        // Saturating add for the s8 delta accumulator
                        if (step_dir == 2'sd1) begin
                            if (delta_acc[h] != 8'sd127)
                                delta_acc[h] <= delta_acc[h] + 8'sd1;
                        end else begin
                            if (delta_acc[h] != -8'sd128)
                                delta_acc[h] <= delta_acc[h] - 8'sd1;
                        end
                        count_abs[h] <= count_abs[h] + {{30{step_dir[1]}}, step_dir};
                        rotate_evt[h] <= 1'b1;
                    end else if (clr_rotate[h]) begin
                        rotate_evt[h] <= 1'b0;
                        delta_acc[h]  <= 8'sd0;
                    end

                    // Switch press normalisation (active-low default)
                    sw_pressed[h]   <= cfg_sw_active_low ? ~deb_sw_stable[h] : deb_sw_stable[h];
                    sw_pressed_d[h] <= sw_pressed[h];

                    // Press timer (counts at 1 ms tick while pressed)
                    if (sw_pressed[h] && !sw_pressed_d[h]) begin
                        press_ms_cnt[h] <= 16'd0;
                        long_fired[h] <= 1'b0;
                    end else if (sw_pressed[h] && tick_1ms) begin
                        if (press_ms_cnt[h] != 16'hFFFF)
                            press_ms_cnt[h] <= press_ms_cnt[h] + 16'd1;
                        if (!long_fired[h] && press_ms_cnt[h] >= LONG_PRESS_MS) begin
                            long_evt[h]   <= 1'b1;
                            long_fired[h] <= 1'b1;
                        end
                    end else if (!sw_pressed[h] && sw_pressed_d[h]) begin
                        // Falling edge: short_press iff long never fired
                        if (!long_fired[h])
                            short_evt[h] <= 1'b1;
                        press_ms_cnt[h] <= 16'd0;
                        long_fired[h] <= 1'b0;
                    end

                    // Per-bit clear hooks
                    if (clr_short[h])
                        short_evt[h] <= 1'b0;
                    if (clr_long[h])
                        long_evt[h] <= 1'b0;
                end
            end
        end
    endgenerate

    // -------------------------------------------------------------------------
    // AXI4-Lite slave (single writer for write-side regs)
    // -------------------------------------------------------------------------
    wire [3:0] reg_sel_w = s_axi_awaddr[5:2];
    wire [3:0] reg_sel_r = s_axi_araddr[5:2];

    localparam [3:0]
        REG_STATUS       = 4'h0,
        REG_DELTA_PACKED = 4'h1,
        REG_COUNT0       = 4'h2,
        REG_COUNT1       = 4'h3,
        REG_COUNT2       = 4'h4,
        REG_BUTTON_STATE = 4'h5,
        REG_CONFIG       = 4'h6,
        REG_CLEAR_EVENTS = 4'h7,
        REG_VERSION      = 4'h8;

    // --- Write FSM ---
    reg [3:0] write_addr_lat;
    reg       write_in_progress;

    always @(posedge s_axi_aclk) begin
        // Default: pulse clear-request lines low every cycle.
        wclr_rotate <= 3'b000;
        wclr_short  <= 3'b000;
        wclr_long   <= 3'b000;

        if (!s_axi_aresetn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            write_in_progress <= 1'b0;
            write_addr_lat <= 4'h0;
            cfg <= CONFIG_DEFAULT;
        end else begin
            // 1. AW
            if (!write_in_progress && s_axi_awvalid && !s_axi_awready) begin
                s_axi_awready <= 1'b1;
                write_addr_lat <= reg_sel_w;
                write_in_progress <= 1'b1;
            end else begin
                s_axi_awready <= 1'b0;
            end

            // 2. W
            if (write_in_progress && s_axi_wvalid && !s_axi_wready && !s_axi_bvalid) begin
                s_axi_wready <= 1'b1;
                case (write_addr_lat)
                    REG_CONFIG: begin
                        if (s_axi_wstrb[0]) cfg[ 7:0]  <= s_axi_wdata[ 7:0];
                        if (s_axi_wstrb[1]) cfg[15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) cfg[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) cfg[31:24] <= s_axi_wdata[31:24];
                    end
                    REG_CLEAR_EVENTS: begin
                        if (s_axi_wstrb[0]) wclr_rotate <= s_axi_wdata[2:0];
                        if (s_axi_wstrb[1]) wclr_short  <= s_axi_wdata[10:8];
                        if (s_axi_wstrb[2]) wclr_long   <= s_axi_wdata[18:16];
                    end
                    default: ; // reads-only or unmapped
                endcase
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;
                write_in_progress <= 1'b0;
            end else begin
                s_axi_wready <= 1'b0;
            end

            // 3. B
            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // --- Read FSM ---
    reg [3:0] read_addr_lat;

    function [31:0] read_mux;
        input [3:0] sel;
        begin
            case (sel)
                REG_STATUS:       read_mux = {5'd0, sw_pressed[2], sw_pressed[1], sw_pressed[0],
                                               5'd0, long_evt[2],   long_evt[1],   long_evt[0],
                                               5'd0, short_evt[2],  short_evt[1],  short_evt[0],
                                               5'd0, rotate_evt[2], rotate_evt[1], rotate_evt[0]};
                REG_DELTA_PACKED: read_mux = {8'h00, delta_acc[2], delta_acc[1], delta_acc[0]};
                REG_COUNT0:       read_mux = count_abs[0];
                REG_COUNT1:       read_mux = count_abs[1];
                REG_COUNT2:       read_mux = count_abs[2];
                REG_BUTTON_STATE: read_mux = {29'd0, sw_pressed[2], sw_pressed[1], sw_pressed[0]};
                REG_CONFIG:       read_mux = cfg;
                REG_VERSION:      read_mux = VERSION_VALUE;
                default:          read_mux = 32'h0;
            endcase
        end
    endfunction

    always @(posedge s_axi_aclk) begin
        // Default: pulse read-clear lines low every cycle.
        rclr_rotate <= 3'b000;
        rclr_short  <= 3'b000;
        rclr_long   <= 3'b000;

        if (!s_axi_aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00;
            s_axi_rdata   <= 32'h0;
            read_addr_lat <= 4'h0;
        end else begin
            // AR handshake + R response. Use reg_sel_r directly here; using the
            // latched address in the same cycle would return the previous read's
            // register and clear the wrong latch.
            if (!s_axi_arready && s_axi_arvalid && !s_axi_rvalid) begin
                s_axi_arready <= 1'b1;
                read_addr_lat <= reg_sel_r;
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00;
                s_axi_rdata  <= read_mux(reg_sel_r);
                // Clear-on-read pulses for value-carrying registers
                if (cfg_clear_on_read) begin
                    case (reg_sel_r)
                        REG_DELTA_PACKED: rclr_rotate <= 3'b111;
                        REG_STATUS: begin
                            rclr_rotate <= 3'b111;
                            rclr_short  <= 3'b111;
                            rclr_long   <= 3'b111;
                        end
                        default: ;
                    endcase
                end
            end else begin
                s_axi_arready <= 1'b0;
            end

            if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule

`default_nettype wire
