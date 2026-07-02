module accel_ramp(
    input clk,
    input reset,
    input [19:0] target_limit,
    input [20:0] ramp_rate,
    output reg [19:0] current_limit
);

    reg [20:0] ramp_counter = 21'd0;

    always @(posedge clk) begin
        if (reset) begin
            current_limit <= 20'hFFFFF;
            ramp_counter <= 21'd0;
        end else if (ramp_counter >= ramp_rate) begin
            ramp_counter <= 21'd0;
            if (current_limit > target_limit)
                current_limit <= current_limit - 1;
            else if (current_limit < target_limit)
                current_limit <= current_limit + 1;
        end else begin
            ramp_counter <= ramp_counter + 1;
        end
    end

endmodule
