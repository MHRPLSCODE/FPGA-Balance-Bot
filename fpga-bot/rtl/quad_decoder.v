module quad_decoder(
    input clk,
    input reset,
    input enc_a,
    input enc_b,
    output reg [15:0] count,
    output reg dir
);

    reg a_prev = 0;
    reg b_prev = 0;

    wire a_rising;

    // Detect rising edge on channel A: was 0, now 1
    assign a_rising = (~a_prev & enc_a);

    always @(posedge clk) begin
        if (reset) begin
            count <= 16'd0;
            dir <= 1'b0;
            a_prev <= 1'b0;
            b_prev <= 1'b0;
        end else begin
            // Store previous values for edge detection next cycle
            a_prev <= enc_a;
            b_prev <= enc_b;

            // On rising edge of A, check B to determine direction
            if (a_rising) begin
                if (~enc_b) begin
                    // A rose while B is low → A leads B → forward
                    count <= count + 1;
                    dir <= 1'b1;
                end else begin
                    // A rose while B is high → B leads A → reverse
                    count <= count - 1;
                    dir <= 1'b0;
                end
            end
        end
    end

endmodule
