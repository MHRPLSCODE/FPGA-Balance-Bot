// ============================================================================
// Module      : top
// Description : Level 2 motion coprocessor. RP2040 sends 4-byte SPI commands
//               (CMD, TARGET_HI, TARGET_LO, DIR_FLAGS) as 4 single-byte
//               transactions. FPGA's accel_ramp continuously ramps toward
//               the committed target. FPGA replies each byte with ACK,
//               RAMPED_HI, RAMPED_LO, STATUS respectively.
//
//               Key: rx_valid_w from spi_target stays HIGH for ~25 FPGA
//               clocks (one SCK half-period at 1 MHz SPI / 50 MHz FPGA),
//               not 1 clock as originally assumed. This RTL edge-detects
//               rx_valid_w so state advances exactly once per received byte.
//               Bug caught via iverilog + gtkwave simulation.
//
// Author      : MHR
// Project     : FPGA Balance Bot — Level 2 Motion Coprocessor
// ============================================================================

(* top *) module top (
    (* iopad_external_pin, clkbuf_inhibit *) input  clk_i,
    (* iopad_external_pin *)                 output clk_en_o,
    (* iopad_external_pin *)                 input  rst_ni,

    (* iopad_external_pin *) input  spi_ss_ni,
    (* iopad_external_pin *) input  spi_sck_i,
    (* iopad_external_pin *) input  spi_mosi_i,
    (* iopad_external_pin *) output spi_miso_o,
    (* iopad_external_pin *) output spi_miso_en_o,

    (* iopad_external_pin *) output reg led_o,
    (* iopad_external_pin *) output     led_en_o
);

    assign clk_en_o = 1'b1;
    assign led_en_o = 1'b1;

    localparam [7:0] ACK_OK = 8'hA5;

    localparam [1:0] S_IDLE     = 2'd0;
    localparam [1:0] S_WAIT_HI  = 2'd1;
    localparam [1:0] S_WAIT_LO  = 2'd2;
    localparam [1:0] S_WAIT_DIR = 2'd3;

    wire rst_ah_w = ~rst_ni;

    wire [7:0]  rx_data_w;
    wire        rx_valid_w;
    wire        tx_hold_w;
    reg  [7:0]  tx_data_r;

    wire [19:0] current_limit_w;

    reg [1:0]   state_r;
    reg [7:0]   target_hi_r;
    reg [7:0]   target_lo_r;
    reg [15:0]  target_rate_r;
    reg         direction_r;

    wire at_target_w = (current_limit_w[15:0] == target_rate_r);

    reg  rx_valid_prev_r;
    wire rx_valid_edge_w = rx_valid_w & ~rx_valid_prev_r;

    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) rx_valid_prev_r <= 1'b0;
        else         rx_valid_prev_r <= rx_valid_w;
    end

    spi_target #(
        .CPOL  (1'b0),
        .CPHA  (1'b0),
        .WIDTH (8),
        .LSB   (1'b0)
    ) u_spi_target (
        .i_clk           (clk_i),
        .i_rst_n         (rst_ni),
        .i_enable        (1'b1),
        .i_ss_n          (spi_ss_ni),
        .i_sck           (spi_sck_i),
        .i_mosi          (spi_mosi_i),
        .o_miso          (spi_miso_o),
        .o_miso_oe       (spi_miso_en_o),
        .o_rx_data       (rx_data_w),
        .o_rx_data_valid (rx_valid_w),
        .i_tx_data       (tx_data_r),
        .o_tx_data_hold  (tx_hold_w)
    );

    accel_ramp #(
        .LIMIT_WIDTH (20),
        .RATE_WIDTH  (21)
    ) u_accel_ramp (
        .clk_i           (clk_i),
        .rst_i           (rst_ah_w),
        .target_limit_i  ({4'b0, target_rate_r}),
        .ramp_rate_i     (21'd50_000),
        .current_limit_o (current_limit_w)
    );

    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_r       <= S_IDLE;
            tx_data_r     <= ACK_OK;
            target_hi_r   <= 8'd0;
            target_lo_r   <= 8'd0;
            target_rate_r <= 16'd0;
            direction_r   <= 1'b0;
            led_o         <= 1'b0;
        end
        else if (rx_valid_edge_w) begin
            case (state_r)
                S_IDLE: begin
                    tx_data_r <= current_limit_w[15:8];
                    state_r   <= S_WAIT_HI;
                end
                S_WAIT_HI: begin
                    target_hi_r <= rx_data_w;
                    tx_data_r   <= current_limit_w[7:0];
                    state_r     <= S_WAIT_LO;
                end
                S_WAIT_LO: begin
                    target_lo_r <= rx_data_w;
                    tx_data_r   <= {7'b0, at_target_w};
                    state_r     <= S_WAIT_DIR;
                end
                S_WAIT_DIR: begin
                    target_rate_r <= {target_hi_r, target_lo_r};
                    direction_r   <= rx_data_w[0];
                    tx_data_r     <= ACK_OK;
                    led_o         <= ~led_o;
                    state_r       <= S_IDLE;
                end
            endcase
        end
    end

endmodule
