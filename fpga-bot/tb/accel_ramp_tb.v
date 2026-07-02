`timescale 1ns/1ps

module accel_ramp_tb;

reg clk = 0;
reg reset = 0;
reg [19:0] target_limit = 20'd10;
reg [20:0] ramp_rate = 21'd5;
wire [19:0] current_limit;

accel_ramp uut (
    .clk(clk),
    .reset(reset),
    .target_limit(target_limit),
    .ramp_rate(ramp_rate),
    .current_limit(current_limit)
);

always #5 clk = ~clk;

initial begin
    $dumpfile("accel_ramp_tb.vcd");
    $dumpvars(0, accel_ramp_tb);
    reset = 1;
    #20;
    reset = 0;
    #5000;
    $finish;
end

endmodule
