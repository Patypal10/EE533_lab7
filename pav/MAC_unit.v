`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    19:57:59 02/28/2026 
// Design Name: 
// Module Name:    MAC_unit 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module MAC_unit(input [15:0] a,
					 input [15:0] b,
					 input [15:0] c,
					 output [15:0] z
    );


wire [15:0] mult_out;

bfloat16mult mult(.a(a),.b(b),.out(mult_out));
blfoat16add add(.a(mult_out),.b(c),.out(z));

endmodule
