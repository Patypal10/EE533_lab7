`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    19:56:21 02/28/2026 
// Design Name: 
// Module Name:    relu_unit 
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
module relu_unit( input [15:0] a,
						output [15:0] z
    );

assign z = a[15] ? 16'd0 : a;

endmodule
