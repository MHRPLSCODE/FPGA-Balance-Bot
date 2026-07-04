module spi_slave(
    input clk,
    input reset,

    input sclk,
    input ss_n,
    input mosi,
    output miso,

    input [23:0] tx_data,
    output reg [23:0] rx_data,
    output reg rx_valid
);

    reg [23:0] shift_reg = 24'd0;
    reg [4:0] bit_count = 5'd0;

    assign miso = shift_reg[23];

    always @(posedge sclk or posedge ss_n) begin
        if (ss_n) begin
            bit_count <= 5'd0;
            shift_reg <= tx_data;
        end else begin
            shift_reg <= {shift_reg[22:0], mosi};
            bit_count <= bit_count + 1;
        end
    end

    reg ss_n_prev = 1'b1;
    wire ss_n_rising;

    assign ss_n_rising = (ss_n & ~ss_n_prev);

    always @(posedge clk) begin
        if (reset) begin
            rx_data <= 24'd0;
            rx_valid <= 1'b0;
            ss_n_prev <= 1'b1;
        end else begin
            ss_n_prev <= ss_n;

            if (ss_n_rising) begin
                rx_data <= shift_reg;
                rx_valid <= 1'b1;
            end else begin
                rx_valid <= 1'b0;
            end
        end
    end

endmodule
