`timescale 1ns / 1ps

module gpu 
   #(
      parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH = DATA_WIDTH/8,
      parameter UDP_REG_SRC_WIDTH = 2
   )
   (
      // From CPU
      input  [15:0]                       param0,
      input  [15:0]                       param1,
      input  [15:0]                       param2,
      input  [15:0]                       param3,
      input  [15:0]                       param4,
      input  [15:0]                       num_threads,
      input  [2:0]                        control,
      input  [15:0]                       mem_addr,
      input  [15:0]                       mem_data,

      // Register interface signals
      input  [DATA_WIDTH-1:0]             in_data,
      input  [CTRL_WIDTH-1:0]             in_ctrl,
      input                               in_wr,
      output                              in_rdy,

      output [DATA_WIDTH-1:0]             out_data,
      output [CTRL_WIDTH-1:0]             out_ctrl,
      output                              out_wr,
      input                               out_rdy,
      
      // --- Register interface
      input                               reg_req_in,
      input                               reg_ack_in,
      input                               reg_rd_wr_L_in,
      input  [`UDP_REG_ADDR_WIDTH-1:0]    reg_addr_in,
      input  [`CPCI_NF2_DATA_WIDTH-1:0]   reg_data_in,
      input  [UDP_REG_SRC_WIDTH-1:0]      reg_src_in,

      output                              reg_req_out,
      output                              reg_ack_out,
      output                              reg_rd_wr_L_out,
      output  [`UDP_REG_ADDR_WIDTH-1:0]   reg_addr_out,
      output  [`CPCI_NF2_DATA_WIDTH-1:0]  reg_data_out,
      output  [UDP_REG_SRC_WIDTH-1:0]     reg_src_out,

      // misc
      input                                reset,
      input                                clk
   );


// Global params
// Opcodes
`define RET    4'd0
`define LOAD   4'd1
`define STORE  4'd2
`define MOVE   4'd3
`define SETP   4'd4
`define ADD    4'd5
`define SUB    4'd6
`define FMA    4'd7
`define MAX    4'd8

//--------------------------------------------------------------------------------------------------------------------------------------------------------------------//
// Register interface for testing/demo
wire [31:0]       din_RI, addr_RI, command_RI, dmem_dout_RI, imem_dout_RI, regfile_dout_RI, pc_RI;


// Param registers store input data from CPU
reg   [15:0]      param0_reg, param1_reg, param2_reg, param3_reg, param4_reg; // 16 bits
reg   [15:0]      num_threads_reg;  // 16 bits
reg   [2:0]       control_reg;      // 2-3 bits
reg   [15:0]      mem_addr_reg, mem_data_reg;  //16 bits


// Top-level signals
wire start_prog;

assign start_prog = (control_reg == 3'd1);


// Control unit -> Decode
wire  [31:0]      pc_ctrl;

// Control unit -> Ex
wire  [12:0]      iteration_ct_ctrl;

// Control unit -> Writeback
wire  [3:0]       curr_threads_finished_ctrl;


// Decode -> Ex
wire  [31:0]      inst;
wire  [4:0]       rs1_s_id, rs2_s_id, rs3_s_id;
wire  [15:0]      param_d_id;

wire   [4:0]      rd_s;
wire   [3:0]      opcode;
wire              eop;
wire              predicated;
wire              thread_batch_done;
wire   [15:0]     imm;
wire              dtype;
wire              rs1_type;
wire              move_source;
wire              rd_data_source;
wire  [63:0]      rs1_d, rs2_d, rs3_d;
wire  [3:0]       predicate_d;
wire              move_source_thread_idx;
wire              reg_we;

reg   [4:0]       idex_rd_s_reg;
reg   [3:0]       idex_opcode_reg;
reg               idex_eop_reg;
reg               idex_predicated_reg;
reg               idex_thread_batch_done_reg;
reg   [15:0]      idex_imm_reg;
reg               idex_dtype_reg;
reg               idex_rs1_type_reg;
reg               idex_move_source_reg;
reg               idex_rd_data_source_reg;
reg   [63:0]      idex_rs1_d_reg;
reg   [63:0]      idex_rs2_d_reg;
reg   [63:0]      idex_rs3_d_reg;
reg   [3:0]       idex_predicate_d_reg;
reg               idex_move_source_thread_idx_reg;
reg               idex_reg_we_reg;


// Ex -> Write back

wire  [63:0]      rd_d;
wire  [15:0]      dmem_addr;

reg   [4:0]       exwb_rd_s_reg;
reg   [3:0]       exwb_opcode_reg;
reg               exwb_eop_reg;
reg               exwb_predicated_reg;
reg               exwb_thread_batch_done_reg;
reg   [15:0]      exwb_imm_reg;
reg               exwb_dtype_reg;
reg               exwb_rs1_type_reg;
reg               exwb_move_source_reg;
reg               exwb_rd_data_source_reg;
reg   [63:0]      exwb_rs1_d_reg;
reg   [63:0]      exwb_rs2_d_reg;
reg   [63:0]      exwb_rs3_d_reg;
reg   [3:0]       exwb_predicate_d_reg;
reg               exwb_move_source_thread_idx_reg;
reg               exwb_reg_we_reg;
reg   [63:0]      exwb_rd_d_reg;
reg   [15:0]      exwb_dmem_addr_reg;

// Write back -> Commit
wire  [63:0]      dmem_dout;
wire  [3:0]       threads_returned_wb;
wire  [63:0]      dmem_din_wb;
wire              dmem_we_wb;
wire  [3:0]       commit_wb;
wire  [63:0]      regfile_din_wb;


//--------------------------------------------------------------------------------------------------------------------------------------------------------------------//

control_unit gpu_ctrl (
   .clk (clk),
   .rst (reset),

   // From top-level
   .start (start_prog),
   .start_pc (mem_addr),
   .num_threads (num_threads),

   // From writeback unit
   .threads_returned (threads_returned_wb),

    // To imem
   .pc_out (pc_ctrl),

   // To register unit
   .iteration_ct_out(iteration_ct_ctrl),

   // To writeback unit
   .curr_threads_finished (curr_threads_finished_ctrl)
);

decode_unit gpu_decode (
   .clk (clk),
   .rst (reset),

   // From imem
   .inst (inst),

    // To pipeline regs
   .rd_s_out (rd_s),
   .opcode_out (opcode),
   .eop_out (eop),
   .predicated_out (predicated),
   .thread_batch_done_out (thread_batch_done),
   .imm_out (imm),
   .dtype_out (dtype),
   .rs1_type_out (rs1_type),
   .move_source_out (move_source),
   .rd_data_source_out (rd_data_source),
   .move_source_thread_idx_out (move_source_thread_idx),
   .reg_we_out (reg_we),

    // To regfile
   .rs1_s_out (rs1_s_id),
   .rs2_s_out (rs2_s_id),
   .rs3_s_out (rs3_s_id)
);

execution_unit gpu_ex_unit (
   .clk (clk),
   .rst (reset),

   // From idex pipeline reg
   .opcode_in (idex_opcode_reg),
   .imm_in (idex_imm_reg),
   .dtype_in (idex_dtype_reg),
   .rs1_type_in (idex_rs1_type_reg),
   .move_source_in (idex_move_source_reg),
   .rs1_d_in (idex_rs1_d_reg),
   .rs2_d_in (rs2_d),
   .move_source_thread_idx_in (idex_move_source_thread_idx),

   // To exwb pipeline reg/dmem
   .rd_d_out (rd_d),
   .dmem_addr (dmem_addr)   // For loads send read request from here
);

writeback_unit gpu_writeback (
   .clk (clk),
   .rst (reset),

    // From control unit
   .curr_threads_finished (curr_threads_finished_ctrl),

    // From dmem
   .dmem_dout_in (dmem_dout),

    // From EXWB pipeline register
   .exwb_opcode_in (exwb_opcode_reg),
   .exwb_predicated_in (exwb_predicated_reg),
   .exwb_thread_batch_done_in (exwb_thread_batch_done_reg),
   .exwb_rd_data_source_in (exwb_rd_data_source_reg),
   .exwb_predicate_d_in (exwb_predicate_d_reg),
   .exwb_reg_we_in (exwb_reg_we_reg),
   .exwb_rd_d_in (exwb_rd_d_reg),
   .tuwb_rd_d_in,          // attach to tensor unit/wb pipeline reg

    // To control unit
   .threads_returned_out (threads_returned_wb),

    // To dmem
   .dmem_din_out (dmem_din_wb),
   .dmem_we_out (dmem_we_wb),

    // To register unit
   .commit_out (commit_wb),
   .regfile_din_out (regfile_din_wb)
);

register_unit gpu_regfile (
   .clk (clk),
   .rst (reset),

   // From control unit
   .iteration_ct_in (iteration_ct_ctrl),

    // From decode unit
   .rs1_s (rs1_s_id),
   .rs2_s (rs2_s_id),
   .rs3_s (rs3_s_id),

    // From write back unit
   .opcode (exwb_opcode_reg),
   .commit (commit_wb),
   .rd_s (exwb_rd_s_reg),
   .rd_d (regfile_din_wb),

    // To pipeline registers
   .rs1_d (rs1_d),
   .rs2_d (rs2_d),
   .rs3_d (rs3_d),
   .predicate_d (predicate_d)
);

instruction_memory gpu_imem (
	.addra(),         // a used for writing imem from reg interface
	.addrb(pc_ctrl),  // b used for gpu
	.clka(clk),
	.clkb(clk),
	.dina(),
	.dinb(32'd0),
	.douta(),
	.doutb(inst),
	.wea(),
	.web(1'b0)
);

data_memory gpu_dmem(
	.addra(dmem_addr[9:0]),             // Port A is for reading from EX
	.addrb(exwb_dmem_addr_reg[9:0]),    // Port B is for writing from WB
	.clka(clk),
	.clkb(clk),
	.dina(63'd00),
	.dinb(dmem_din_wb),
	.douta(dmem_dout),
	.doutb(63'd00),
	.wea(1'b0),
	.web(dmem_we_wb) 
);

//--------------------------------------------------------------------------------------------------------------------------------------------------------------------//

// Mux for selecting param reg data input
always @(*) begin
   case (rs1_s[2:0])
      3'd0 : param_d_id = param0_reg;
      3'd1 : param_d_id = param1_reg;
      3'd2 : param_d_id = param2_reg;
      3'd3 : param_d_id = param3_reg;
      3'd4 : param_d_id = param4_reg;
      default : param_d_id = param0_reg;
   endcase
end

always @(posedge clk) begin
   if (reset) begin
      param0_reg <= 0;
      param1_reg <= 0;
      param2_reg <= 0;
      param3_reg <= 0;
      param4_reg <= 0;
      num_threads_reg <= 0;
      control_reg <= 0;
      mem_addr <= 0;
      mem_data <= 0;

      idex_rd_s_reg <= 0;
      idex_opcode_reg <= 0;
      idex_eop_reg <= 0;
      idex_predicated_reg <= 0;
      idex_thread_batch_done_reg <= 0;
      idex_imm_reg <= 0;
      idex_dtype_reg <= 0;
      idex_rs1_type_reg <= 0;
      idex_move_source_reg <= 0;
      idex_rd_data_source_reg <= 0;
      idex_rs1_d_reg <= 0;
      idex_rs2_d_reg <= 0;
      idex_rs3_d_reg <= 0;
      idex_predicate_d_reg <= 0;
      idex_move_source_thread_idx_reg <= 0;
      idex_reg_we_reg <= 0;

   end else begin
      // Parameter assignments
      if (start_prog) begin
         param0_reg <= param0;
         param1_reg <= param1;
         param2_reg <= param2;
         param3_reg <= param3;
         param4_reg <= param4;
      end

      // IDEX assignments
      idex_rd_s_reg <= rd_s;
      idex_opcode_reg <= opcode;
      idex_eop_reg <= eop;
      idex_predicated_reg <= predicated;
      idex_thread_batch_done_reg <= thread_batch_done;
      idex_imm_reg <= imm;
      idex_dtype_reg <= dtype;
      idex_rs1_type_reg <= rs1_type;
      idex_move_source_reg <= move_source;
      idex_rd_data_source_reg <= rd_data_source;
      idex_rs1_d_reg <= (rs1_type) ? {{48'b0}, param_d_id} : rs1_d;
      idex_rs2_d_reg <= rs2_d;
      idex_rs3_d_reg <= rs3_d;
      idex_predicate_d_reg <= predicate_d;
      idex_move_source_thread_idx_reg <= move_source_thread_idx;
      idex_reg_we_reg <= reg_we;

      // EXWB assignments
      exwb_rd_s_reg <= idex_rd_s_reg;
      exwb_opcode_reg <= idex_opcode_reg;
      exwb_eop_reg <= idex_eop_reg;
      exwb_predicated_reg <= idex_predicated_reg;
      exwb_thread_batch_done_reg <= idex_thread_batch_done_reg;
      exwb_imm_reg <= idex_imm_reg;
      exwb_dtype_reg <= idex_dtype_reg;
      exwb_rs1_type_reg <= idex_rs1_type_reg;
      exwb_move_source_reg <= idex_move_source_reg;
      exwb_rd_data_source_reg <= idex_rd_data_source_reg;
      exwb_rs1_d_reg <= idex_rs1_d_reg;
      exwb_rs2_d_reg <= idex_rs2_d_reg;
      exwb_rs3_d_reg <= idex_rs3_d_reg;
      exwb_predicate_d_reg <= idex_predicate_d_reg;
      exwb_move_source_thread_idx_reg <= idex_move_source_thread_idx_reg;
      exwb_reg_we_reg <= idex_reg_we_reg
      exwb_rd_d_reg <= rd_d;
      exwb_dmem_addr_reg <= dmem_addr;
   end

end

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------//

generic_regs
   #( 
      .UDP_REG_SRC_WIDTH   (UDP_REG_SRC_WIDTH),
      .TAG                 (`GPU_BLOCK_ADDR),          // Tag -- eg. MODULE_TAG
      .REG_ADDR_WIDTH      (`GPU_REG_ADDR_WIDTH),     // Width of block addresses -- eg. MODULE_REG_ADDR_WIDTH
      .NUM_COUNTERS        (0),                 // Number of counters
      .NUM_SOFTWARE_REGS   (3),                 // Number of sw regs
      .NUM_HARDWARE_REGS   (4)                  // Number of hw regs
   ) module_regs (
      .reg_req_in       (reg_req_in),
      .reg_ack_in       (reg_ack_in),
      .reg_rd_wr_L_in   (reg_rd_wr_L_in),
      .reg_addr_in      (reg_addr_in),
      .reg_data_in      (reg_data_in),
      .reg_src_in       (reg_src_in),

      .reg_req_out      (reg_req_out),
      .reg_ack_out      (reg_ack_out),
      .reg_rd_wr_L_out  (reg_rd_wr_L_out),
      .reg_addr_out     (reg_addr_out),
      .reg_data_out     (reg_data_out),
      .reg_src_out      (reg_src_out),

      // --- counters interface
      .counter_updates  (),
      .counter_decrement(),

      // --- SW regs interface
      .software_regs    ({ 
                           din_RI, 
                           addr_RI, 
                           command_RI
                           }),

      // --- HW regs interface
      .hardware_regs    ({
                           dmem_dout_RI,
                           imem_dout_RI,
                           regfile_dout_RI,
                           pc_RI
                        }),

      .clk              (clk),
      .reset            (reset)
   );


   endmodule