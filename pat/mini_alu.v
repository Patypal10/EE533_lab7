`timescale 1ns / 1ps

module mini_alu (
    input [1:0] func, // 0 = ADD, 1 = SUB, 2 = greater/equal, 3 = max
    input [15:0] a,
    input [15:0] b,
    output [15:0] out
);

wire [15:0] adder_out;
wire        ge;


// Adder/Subtractor
wire [15:0]  adder_b_in  =  (func == 2'b01) ? ~b : b;
wire         adder_cin   =  (func == 2'b01) ? 1'b1 : 1'b0;

wire [16:0]  adder_result = {1'b0, a} + {1'b0, adder_b_in} + adder_cin;

wire [15:0]  adder_sum   =  adder_result[31:0];
//wire         adder_cout  =  adder_result[32];
//wire 		 adder_overflow = (a[15] == adder_b_in[15]) && (adder_sum[15] != a[15]);


// Comparison logic
ge = $signed(a) >= $signed(b);


// Output selection
always @(*) begin
    case (func) 
        2'b00 : adder_out = adder_sum;
        2'b01 : adder_out = adder_sum;
        2'b10 : adder_out = {{15'b0}, ge};
        2'b11 : adder_out = (ge) ? a : b;
        default : adder_out = 16'b0;
    endcase
end

assign out = adder_out;

endmodule