module watchdog(
    input clk,
    input reset,
    input heartbeat,              
    input [23:0] timeout_limit,   
    output reg kill_motors
);

    reg [23:0] wd_counter = 24'd0;
    reg hb_prev = 1'b0;

    wire hb_rising;

    assign hb_rising = (~hb_prev & heartbeat);

    always @(posedge clk) begin
        if (reset) begin
            wd_counter <= 24'd0;
            kill_motors <= 1'b0;
            hb_prev <= 1'b0;
        end else begin

            hb_prev <= heartbeat;

            if (hb_rising) begin
                wd_counter <= 24'd0;
                kill_motors <= 1'b0;
            end else if (wd_counter >= timeout_limit) begin
                kill_motors <= 1'b1;
            end else begin
                wd_counter <= wd_counter + 1;
            end
        end
    end

endmodule
