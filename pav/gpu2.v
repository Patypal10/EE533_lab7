`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    23:50:58 02/27/2026 
// Design Name: 
// Module Name:    gpu2 
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
module gpu2(
				input clk,
				input reset,
				input func_args_memory_pointer,
				input number_of_arguments_passed,
				input [14:0] vec_size,
				input start,
				output done
			   );

wire [11:0] pc_out;
wire [3:0] lane_mask_out;
wire [12:0] current_iteration;
wire [31:0] instr;

controlunit2 IF_control_unit(
.clk(clk),
.rst(reset),
.vec_size(vec_size),
.start(start),
.ret(mem_wb_ret),
.current_iteration(current_iteration),
.pc_out(pc_out),
.lane_mask_out(lane_mask_out),
.done(done)
);

instruction_memory gpu_imem (
	.addra(),         // a used for writing imem from reg interface
	.addrb(pc_out),  // b used for gpu
	.clka(clk),
	.clkb(clk),
	.dina(),
	.dinb(32'd0),
	.douta(),
	.doutb(instr),
	.wea(),
	.web(1'b0)
);



wire [4:0] rd_s;
wire [3:0] opcode;
wire eop;
wire predicated;
wire thread_batch_done;
wire [15:0] imm;
wire dtype;
wire rs1_type;
wire move_source;
wire rd_data_source;
wire move_source_thread_idx;
wire reg_we;
wire [4:0] rs1_s_id, rs2_s_id, rs3_s_id;


wire [63:0] wb_rd_data_mux_out;

//////////////////////////
reg [3:0] if_id_lane_mask_reg;
reg [11:0] if_id_pc_out_reg;
reg [13:0] if_id_current_iteration_reg;

reg [4:0] id_ex_rd_s_out_reg;
reg [3:0] id_ex_opcode_reg;
reg id_ex_eop_reg;
reg id_ex_predicated_out_reg;
reg [15:0] id_ex_immediate_reg;
reg id_ex_dtype_reg;
reg id_ex_move_source_out_reg;
reg id_ex_imm_or_reg_source_out_reg;
reg id_ex_rd_data_source_out_reg;
reg id_ex_move_source_thread_idx_out;
reg id_ex_reg_write_enable;
reg [63:0] id_ex_rs1_s_reg;
reg [63:0] id_ex_rs2_s_reg;
reg [63:0] id_ex_rs3_s_reg;
reg [13:0] id_ex_if_id_current_iteration_reg;
reg [3:0] id_ex_lane_mask_reg;
reg id_ex_mem_we_reg;
reg id_ex_ret;

reg ex_mem_mem_write_enable;
reg [63:0] ex_mem_alu_out;
reg [3:0] ex_mem_opcode_reg;
reg [4:0] ex_mem_rd_s_out_reg;
reg ex_mem_rd_data_source_reg;
reg ex_mem_reg_write_enable;
reg ex_mem_ret;

reg [63:0] mem_wb_dmem_dout_reg;
reg [63:0] mem_wb_alu_out;
reg [3:0] mem_wb_opcode_reg;
reg [4:0] mem_wb_rd_s_out_reg;
reg mem_wb_rd_data_source_reg;
reg mem_wb_reg_write_enable;
reg mem_wb_ret;
/////////////////////////
wire mem_we;
decode_unit2 gpu_decode (
   .inst (instr),

   .rd_s_out (rd_s),
   .opcode_out (opcode),
   .eop_out (eop),
   .predicated_out (predicated),
   .thread_batch_done_out (thread_batch_done),
   .imm_out (imm),
   .dtype_out (dtype),
   .imm_or_reg_source_out (rs1_type),
   .move_source_out (move_source),
   .rd_data_source_out (rd_data_source),
   .move_source_thread_idx_out (move_source_thread_idx),
   .reg_write_enable (reg_we),
   .mem_write_enable(mem_we),
    // To regfile
   .rs1_s_out (rs1_s_id),
   .rs2_s_out (rs2_s_id),
   .rs3_s_out (rs3_s_id)
);

wire [63:0] rs1_d, rs2_d, rs3_d;

registerunit2 gpu_regfile (
   .clk (clk),
   .rst (reset),

     // From decode unit
   .rs1_s (rs1_s_id),
   .rs2_s (rs2_s_id),
   .rs3_s (rs3_s_id),

  
   .rd_s (mem_wb_rd_s_out_reg),
   .rd_d (wb_rd_data_mux_out),
   .we(mem_wb_reg_write_enable),
    // To pipeline registers
   .rs1_d (rs1_d),
   .rs2_d (rs2_d),
   .rs3_d (rs3_d)
 
);

wire [64:0] exec_alu_out;
wire [15:0] dmem_addr;

executionunit2 gpu_ex_unit (
   .clk (clk),
   .rst (reset),

   // From idex pipeline reg
   .opcode_in (id_ex_opcode_reg),
   .imm_in (id_ex_immediate_reg),
   .dtype_in (id_ex_dtype_reg),
   .rs1_type_in (id_ex_imm_or_reg_source_out_reg),
   .move_source_in (id_ex_move_source_out_reg),
   .rs1_d_in (id_ex_rs1_s_reg),
   .rs2_d_in (id_ex_rs2_s_reg),
	.rs3_d_in (id_ex_rs3_s_reg),
   .move_source_thread_idx_in (id_ex_move_source_thread_idx_out),
	.iteration_count(id_ex_if_id_current_iteration_reg),
	.lane_masks(id_ex_lane_mask_reg),
   // To exwb pipeline reg/dmem
   .rd_d_out (exec_alu_out),
   .dmem_addr (dmem_addr)   // For loads send read request from here
);

wire [63:0] dmem_dout;

data_memory gpu_dmem(
	.addra(dmem_addr[9:0]),             // Port A is for reading from EX
	.addrb(),    // Port B is for writing from WB
	.clka(clk),
	.clkb(),
	.dina(id_ex_rs2_s_reg),
	.dinb(),
	.douta(dmem_dout),
	.doutb(),
	.wea(id_ex_mem_we_reg),
	.web() 
);



assign wb_rd_data_mux_out = ex_mem_rd_data_source_reg ? mem_wb_dmem_dout_reg : mem_wb_alu_out;


always@(clk)
	begin
		if(reset)
			begin
				if_id_lane_mask_reg <= 0;
				if_id_pc_out_reg <= 0;
				if_id_current_iteration_reg <= 0;
				
				id_ex_rd_s_out_reg <= 0;
				id_ex_opcode_reg <= 0;
				id_ex_eop_reg <= 0;
				id_ex_predicated_out_reg <= 0;
				id_ex_immediate_reg <= 0;
				id_ex_dtype_reg  <= 0;
				id_ex_move_source_out_reg <= 0;
				id_ex_imm_or_reg_source_out_reg <= 0;
				id_ex_rd_data_source_out_reg <= 0;
				id_ex_move_source_thread_idx_out <= 0;
				//id_ex_mem_write_enable <= 0;
				id_ex_rs1_s_reg <= 0;
				id_ex_rs2_s_reg <= 0;
				id_ex_rs3_s_reg <= 0;
				id_ex_if_id_current_iteration_reg <= 0;
				id_ex_lane_mask_reg <= 0;
				id_ex_mem_we_reg <= 0;
				
				ex_mem_mem_write_enable <= 0;
				ex_mem_alu_out <= 0;
				ex_mem_opcode_reg <= 0;
				ex_mem_rd_s_out_reg <= 0;
				ex_mem_rd_data_source_reg <= 0;
				
				mem_wb_dmem_dout_reg <= 0;
				mem_wb_alu_out <= 0;
				mem_wb_opcode_reg <= 0;
				mem_wb_rd_s_out_reg <= 0;
				mem_wb_rd_data_source_reg <= 0;
			end
		else
			begin
				if_id_lane_mask_reg <= lane_mask_out;
				if_id_pc_out_reg <= pc_out;
				if_id_current_iteration_reg <= current_iteration;
				
				id_ex_rd_s_out_reg <= rd_s;
				id_ex_opcode_reg <= opcode;
				id_ex_eop_reg <= eop;
				id_ex_predicated_out_reg <= predicated;
				id_ex_immediate_reg <= imm;
				id_ex_dtype_reg  <= dtype;
				id_ex_move_source_out_reg <= move_source;
				id_ex_imm_or_reg_source_out_reg <= rs1_type;
				id_ex_rd_data_source_out_reg <= rd_data_source;
				id_ex_move_source_thread_idx_out <= move_source_thread_idx;
				id_ex_reg_write_enable <= reg_we;
				id_ex_rs1_s_reg <= rs1_type ? {48'd0,imm} : rs1_d;
				id_ex_rs2_s_reg <= rs2_d;
				id_ex_rs3_s_reg <= rs3_d;
				id_ex_if_id_current_iteration_reg <= if_id_current_iteration_reg;
				id_ex_lane_mask_reg <= if_id_lane_mask_reg;
				id_ex_mem_we_reg <= mem_we;
				id_ex_ret <= thread_batch_done;
				
				ex_mem_reg_write_enable <= id_ex_reg_write_enable;
				ex_mem_alu_out <= exec_alu_out;
				ex_mem_opcode_reg <= id_ex_opcode_reg;
				ex_mem_rd_s_out_reg <= id_ex_rd_s_out_reg;
				ex_mem_rd_data_source_reg <= id_ex_rd_data_source_out_reg;
				ex_mem_ret <= id_ex_ret;
				
				mem_wb_dmem_dout_reg <= dmem_dout;
				mem_wb_alu_out <= ex_mem_alu_out;
				mem_wb_opcode_reg <= ex_mem_opcode_reg;
				mem_wb_rd_s_out_reg <= ex_mem_rd_s_out_reg;
				mem_wb_rd_data_source_reg <= ex_mem_rd_data_source_reg;
				mem_wb_reg_write_enable <= ex_mem_reg_write_enable;
				mem_wb_ret <= ex_mem_ret;
				
			end
	end

endmodule
