`timescale 1ns/1ps

module quad_decoder_tb;

reg clk = 0;
reg reset = 0;
reg enc_a = 0;
reg enc_b = 0;
wire [15:0] count;
wire dir;

quad_decoder uut (
    .clk(clk),
    .reset(reset),
    .enc_a(enc_a),
    .enc_b(enc_b),
    .count(count),
    .dir(dir)
);

always #5 clk = ~clk;
task forward_step;
    begin
        enc_a = 0; enc_b = 0; #100;
        enc_a = 1; enc_b = 0; #100;  
        enc_a = 1; enc_b = 1; #100;
        enc_a = 0; enc_b = 1; #100;
        enc_a = 0; enc_b = 0; #100;
    end
endtask
task reverse_step;
    begin
        enc_a = 0; enc_b = 0; #100;
        enc_a = 0; enc_b = 1; #100;  
        enc_a = 1; enc_b = 1; #100;  
        enc_a = 1; enc_b = 0; #100;
        enc_a = 0; enc_b = 0; #100;
    end
endtask

initial begin
    $dumpfile("quad_decoder_tb.vcd");
    $dumpvars(0, quad_decoder_tb);
    reset = 1;
    #20;
    reset = 0;
    #20;
    forward_step;
    forward_step;
    forward_step;
    forward_step;
    forward_step;
    reverse_step;
    reverse_step;
    reverse_step;

    #200;
    $finish;
end

endmodule
