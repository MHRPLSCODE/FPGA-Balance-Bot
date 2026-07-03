`timescale 1ns/1ps

module stall_detector_tb;

reg clk = 0;
reg reset = 0;
reg step_pulse = 0;
reg [15:0] encoder_count = 16'd0;
reg [15:0] stall_threshold = 16'd3;  
wire stall_flag;

stall_detector uut (
    .clk(clk),
    .reset(reset),
    .step_pulse(step_pulse),
    .encoder_count(encoder_count),
    .stall_threshold(stall_threshold),
    .stall_flag(stall_flag)
);

always #5 clk = ~clk;
task send_step;
    begin
        @(posedge clk);
        step_pulse = 1;
        @(posedge clk);
        step_pulse = 0;
    end
endtask
initial begin
    $dumpfile("stall_detector_tb.vcd");
    $dumpvars(0, stall_detector_tb);
    reset = 1;
    #30;
    reset = 0;
    #20;
    send_step; encoder_count = 16'd1;  #50;
    send_step; encoder_count = 16'd2;  #50;
    send_step; encoder_count = 16'd3;  #50;
    send_step; encoder_count = 16'd4;  #50;
    send_step; encoder_count = 16'd5;  #50;
    send_step; #50; 
    send_step; #50; 
    send_step; #50;  
    send_step; #50;  
    #200;
    encoder_count = 16'd8; #50;  
    
    #200;
    $finish;
end

endmodule
