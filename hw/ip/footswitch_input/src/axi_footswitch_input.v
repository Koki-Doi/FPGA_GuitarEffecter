// =============================================================================
// axi_footswitch_input
//
// 3-channel footswitch input IP with debouncing and a per-channel "press
// event" latch behind a tiny AXI4-Lite slave.
//
// Footswitch feature of FPGA_GuitarEffecter. Self-contained Verilog module
// used as a block-design module reference, mirroring the structure of
// axi_encoder_input.v. No external IP dependencies.
//
// The footswitches are standard guitar-pedal 3PDT *latching* (alternate
// action) switches. Each physical stomp flips the contact, so the debounced
// logic level toggles 0<->1 on every press. We therefore detect *either*
// edge of the debounced level and latch one press_event per stomp -- the
// absolute level is irrelevant. (This is the key difference from the
// encoder SW path, which is a momentary active-low button.)
//
// External pins (3.3V LVCMOS33 on Raspberry Pi header, with PULLUP true):
//   fsw0_i (FX toggle) / fsw1_i (preset next) / fsw2_i (preset prev)
// Wiring per switch: common -> GPIO pin, one throw -> GND, the other throw
// open (the internal pull-up drives it high). open=1, grounded=0.
//
// AXI register map (offsets are byte addresses, register width is 32-bit):
//   0x00 STATUS         (R)  press/level latches
//        bit  2:0  press_event[2:0]  (1 = a stomp occurred since last clear)
//        bit 10:8  level[2:0]        (debounced raw level, diagnostics only)
//        Cleared on read when cfg_clear_on_read = 1.
//   0x18 CONFIG         (R/W)
//        bit  7:0  debounce_ms (1..255; sampled at 1 ms tick)
//        bit  8    clear_on_read_enable (STATUS auto-clears on read)
//   0x1C CLEAR_EVENTS   (W)  write 1 to press_event bit positions to clear.
//   0x20 VERSION        (R)  0x00F50001
//
// A 1 ms internal tick is divided from the AXI clock assuming 100 MHz
// (FCLK_CLK0 in this design), identical to axi_encoder_input.v.
//
// Note on power-up: level_seen resets to 1 (matching the pulled-up "open"
// position). If a switch happens to boot in the grounded position one
// phantom press_event may latch; the Python driver clears events once after
// overlay load to absorb it.
// =============================================================================

`default_nettype none

module axi_footswitch_input #(
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

    // External footswitch pins (asynchronous, raw from RPi header)
    input  wire                              fsw0_i,
    input  wire                              fsw1_i,
    input  wire                              fsw2_i
);

    // -------------------------------------------------------------------------
    // Constants
    // Default: clear_on_read=1, debounce_ms=5 -> 0x00000105
    // -------------------------------------------------------------------------
    localparam [31:0] CONFIG_DEFAULT = 32'h00000105;
    localparam [31:0] VERSION_VALUE  = 32'h00F50001;

    // CONFIG register
    reg [31:0] cfg;
    wire [7:0]  cfg_debounce_ms   = cfg[7:0];
    wire        cfg_clear_on_read = cfg[8];

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
    // Bundle the raw footswitch inputs for indexed access.
    // -------------------------------------------------------------------------
    wire [2:0] fsw_raw = {fsw2_i, fsw1_i, fsw0_i};

    // -------------------------------------------------------------------------
    // Per-channel pipeline state
    // -------------------------------------------------------------------------
    reg [1:0] sync_fsw     [0:2];
    reg       deb_stable   [0:2];
    reg [7:0] deb_cnt      [0:2];
    reg       deb_prev     [0:2];
    reg       level_seen   [0:2];   // last level that generated an event
    reg       press_evt    [0:2];

    integer i;
    initial begin
        for (i = 0; i < 3; i = i + 1) begin
            sync_fsw[i]   = 2'b11;
            deb_stable[i] = 1'b1;
            deb_cnt[i]    = 8'd0;
            deb_prev[i]   = 1'b1;
            level_seen[i] = 1'b1;
            press_evt[i]  = 1'b0;
        end
        cfg = CONFIG_DEFAULT;
    end

    // -------------------------------------------------------------------------
    // Clear-request pulses combine writes-to-CLEAR_EVENTS and clear-on-read
    // -------------------------------------------------------------------------
    reg  [2:0] wclr_evt;
    reg  [2:0] rclr_evt;
    wire [2:0] clr_evt = wclr_evt | rclr_evt;

    // -------------------------------------------------------------------------
    // Per-channel pipeline (sync + debounce + dual-edge event latch)
    // -------------------------------------------------------------------------
    genvar g;
    generate
        for (g = 0; g < 3; g = g + 1) begin : g_fsw
            // Stage 1: 2-stage synchroniser
            always @(posedge s_axi_aclk) begin
                sync_fsw[g] <= {sync_fsw[g][0], fsw_raw[g]};
            end

            // Stage 2: debounce (cfg_debounce_ms consecutive ms samples)
            always @(posedge s_axi_aclk) begin
                if (!s_axi_aresetn) begin
                    deb_stable[g] <= 1'b1;
                    deb_cnt[g]    <= 8'd0;
                    deb_prev[g]   <= 1'b1;
                end else if (tick_1ms) begin
                    if (sync_fsw[g][1] == deb_prev[g]) begin
                        if (deb_cnt[g] < cfg_debounce_ms)
                            deb_cnt[g] <= deb_cnt[g] + 8'd1;
                        else
                            deb_stable[g] <= sync_fsw[g][1];
                    end else begin
                        deb_cnt[g] <= 8'd0;
                    end
                    deb_prev[g] <= sync_fsw[g][1];
                end
            end

            // Stage 3: dual-edge press-event latch
            always @(posedge s_axi_aclk) begin
                if (!s_axi_aresetn) begin
                    level_seen[g] <= 1'b1;
                    press_evt[g]  <= 1'b0;
                end else begin
                    if (deb_stable[g] != level_seen[g]) begin
                        press_evt[g]  <= 1'b1;
                        level_seen[g] <= deb_stable[g];
                    end else if (clr_evt[g]) begin
                        press_evt[g] <= 1'b0;
                    end
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
        REG_CONFIG       = 4'h6,
        REG_CLEAR_EVENTS = 4'h7,
        REG_VERSION      = 4'h8;

    // --- Write FSM ---
    reg [3:0] write_addr_lat;
    reg       write_in_progress;

    always @(posedge s_axi_aclk) begin
        // Default: pulse clear-request lines low every cycle.
        wclr_evt <= 3'b000;

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
                        if (s_axi_wstrb[0]) wclr_evt <= s_axi_wdata[2:0];
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
                REG_STATUS:  read_mux = {21'd0,
                                          deb_stable[2], deb_stable[1], deb_stable[0],
                                          5'd0,
                                          press_evt[2], press_evt[1], press_evt[0]};
                REG_CONFIG:  read_mux = cfg;
                REG_VERSION: read_mux = VERSION_VALUE;
                default:     read_mux = 32'h0;
            endcase
        end
    endfunction

    always @(posedge s_axi_aclk) begin
        // Default: pulse read-clear lines low every cycle.
        rclr_evt <= 3'b000;

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
                // Clear-on-read pulse for STATUS
                if (cfg_clear_on_read && reg_sel_r == REG_STATUS)
                    rclr_evt <= 3'b111;
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
