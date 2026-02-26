`timescale 1ns/1ps

module gpu 
   #(
      parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH = DATA_WIDTH/8,
      parameter UDP_REG_SRC_WIDTH = 2
   )
   (
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

//--------------------------------------------------------------------------------------------------------------------------------------------------------------------//
// Param registers store input data from CPU
reg   [15:0]      param0_reg, param1_reg, param2_reg, param3_reg, param4_reg;
reg   [15:0]      num_threads_reg;
reg               control_reg;
reg   [15:0]      dmem_addr, dmem_data;

// Top-level signals
wire start_prog;
assign start_prog = (control_reg == 1'b1);

// From control unit
wire  [31:0]      pc_ctrl;

// From imem
wire  [31:0]      inst;

//--------------------------------------------------------------------------------------------------------------------------------------------------------------------//

control_unit gpu_ctrl (
   .clk (clk),
   .rst (reset),

   // From top-level
   .start (start_prog),

   // From decode unit
   .ex_unit_to_use (),

    // From ex_unit
   .all_threads_done (),

    // To imem
   .pc_out (pc_ctrl)
);

decode_unit gpu_decode (
   .clk (clk),
   .rst (reset),

   // From imem
   .inst (),

    // To control unit: signals to be registered there
   .rd_s_out (),
   .opcode_out (),
   .eop_out (),
   .predicated_out (),
   .thread_batch_done_out (),
   .imm_out (),
   .dtype_out (),
   .rs1_type_out (),
   .move_source_out (),
   .rd_data_source_out (),

    // To regfile
   .rs1_s_out (),
   .rs2_s_out (),
   .rs3_s_out ()
);


instruction_memory gpu_imem (
	.addra(),   // a used for writing imem from reg interface
	.addrb(pc_ctrl),            // b used for gpu
	.clka(clk),
	.clkb(clk),
	.dina(),
	.dinb(32'd0),
	.douta(),
	.doutb(inst),
	.wea(),
	.web(1'b0)
);


// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------//

generic_regs
   #( 
      .UDP_REG_SRC_WIDTH   (UDP_REG_SRC_WIDTH),
      .TAG                 (`GPU_BLOCK_ADDR),          // Tag -- eg. MODULE_TAG
      .REG_ADDR_WIDTH      (`GPU_REG_ADDR_WIDTH),     // Width of block addresses -- eg. MODULE_REG_ADDR_WIDTH
      .NUM_COUNTERS        (0),                 // Number of counters
      .NUM_SOFTWARE_REGS   (3),                 // Number of sw regs
      .NUM_HARDWARE_REGS   (3)                  // Number of hw regs
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
                           dmem_dout,
                           imem_dout,
                           pc
                        }),

      .clk              (clk),
      .reset            (reset)
   );


   endmodule