(* top *) module blink(
    (* clkbuf_inhibit *) input clk,
    output led,
    output led_oe,
    output o_osc_ctrl_en
);

reg [24:0] counter = 25'd0;

always @(posedge clk)
    counter <= counter + 1;

assign led = counter[24];
assign led_oe = 1'b1;     // enable the LED pin as an output
assign o_osc_ctrl_en = 1'b1;  // enable the on-chip oscillator

endmodule
