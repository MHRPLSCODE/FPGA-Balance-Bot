`timescale 1ns/1ps

module stepper_driver_tb;
reg clk = 0;
reg reset = 0;
reg [19:0] step_limit = 20'd10;
reg direction = 0;
wire step_out;
wire step_oe;
wire dir_out;
wire dir_oe;
wire o_osc_ctrl_en;

stepper_driver uut (
    .clk(clk),
    .reset(reset),
    .step_limit(step_limit),
    .direction(direction),
    .step_out(step_out),
    .step_oe(step_oe),
    .dir_out(dir_out),
    .dir_oe(dir_oe),
    .o_osc_ctrl_en(o_osc_ctrl_en)
);

always #5 clk = ~clk;

initial begin
    $dumpfile("stepper_driver_tb.vcd");
    $dumpvars(0, stepper_driver_tb);
    
    // pulse reset at start
    reset = 1;
    #20;
    reset = 0;
    
    // run forward direction for a while
    #500;
    
    // flip direction
    direction = 1;
    
    // run reverse for a while
    #500;
    
    $finish;
end
endmodule 
