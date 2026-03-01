`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    19:08:16 02/27/2026 
// Design Name: 
// Module Name:    gpu_tb 
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
module gpu_tb;


				reg func_args_memory_pointer;
				reg number_of_arguments_passed;

				reg start;
				
      reg  [14:0]                       vec_size;
     // reg  [2:0]                        control_reg;


      // misc
      reg                                reset;
      reg                                clk;
		
gpu2 gpu_dut (.func_args_memory_pointer(func_args_memory_pointer),
				  .number_of_arguments_passed(number_of_arguments_passed),
				 .vec_size(vec_size),
				 .start(start),
				 .reset(reset),
				 .clk(clk)
				 );
				 
initial
	begin
		clk = 0;
		forever
			begin
				#10 clk = ~clk;
			end
	end

initial
	begin
		reset = 1;
		#20
		reset = 0;
		#20
		vec_size = 16'd7;
		#10
		start = 1;
	end
endmodule
