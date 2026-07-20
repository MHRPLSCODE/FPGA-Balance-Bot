`timescale 1ns/1ps

module tb_top;
    reg clk = 0;
    reg rst_n = 0;
    reg ss_n = 1;
    reg sck = 0;
    reg mosi = 0;
    wire miso, miso_en, led;
    wire clk_en, led_en;

    always #10 clk = ~clk;

    top dut (
        .clk_i(clk), .clk_en_o(clk_en), .rst_ni(rst_n),
        .spi_ss_ni(ss_n), .spi_sck_i(sck), .spi_mosi_i(mosi),
        .spi_miso_o(miso), .spi_miso_en_o(miso_en),
        .led_o(led), .led_en_o(led_en)
    );

    task send_byte(input [7:0] b);
        integer i;
        begin
            ss_n = 0; #500;
            for (i = 7; i >= 0; i = i - 1) begin
                mosi = b[i];
                #500 sck = 1;
                #500 sck = 0;
            end
            #500 ss_n = 1;
            #2000;
        end
    endtask

    initial begin
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);

        #100 rst_n = 1;
        #1000;

        send_byte(8'hA5);
        send_byte(8'h13);
        send_byte(8'h88);
        send_byte(8'h00);

        #20000;
        $finish;
    end
endmodule
