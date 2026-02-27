`timescale 1ns / 1ps

module execution_unit (
    input clk,
    input rst,

    // From idex pipeline reg
    input [4:0] rd_s_in,
    input [3:0] opcode_in,
    input eop_in,
    input predicated_in,
    input thread_batch_done_in,
    input [15:0] imm_in,
    input dtype_in,
    input rs1_type_in,
    input move_source_in,
    input rd_data_source_in,
    input [63:0] rs1_d_in,
    input [63:0] rs2_d_in,
    input [63:0] rs3_d_in,
    input [3:0] predicate_d_in,
    input move_source_thread_idx_in,

    // From control unit
    input [12:0] iteration_ct_in,

    // To pipeline reg
    output [15:0] rd_d_out,
    output [15:0] dmem_addr,    // For loads send read request from here
    
);

// ---------- Local Variables ---------- //
wire  [15:0]        rd_d;

wire  [1:0]         func;   // 0 = add, 1 = sub, 2 = greater/equal, 3 = max
wire  [15:0]        alu_out_0, alu_out_1, alu_out_2, alu_out_3;

wire  [15:0]        dmem_addr;
wire  [63:0]        move_rd_d;


assign move_rd_d = (move_source_thread_idx_in) ? {{3'b000, {rs1_d_din[12:0] + 3}}, {3'b000, {rs1_d_din[12:0] + 2}}, {3'b000, {rs1_d_din[12:0] + 1}}, {3'b000, {rs1_d_din[12:0]}}} : rs1_d_din;

// ---------- Execution Logic ---------- //
mini_alu t0_alu(
    .func (func),
    .a (rs1_d_din[15:0]),
    .b (rs2_d_in[15:0]),
    .out (alu_out_0)
);

mini_alu t1_alu(
    .func (func),
    .a (rs1_d_din[31:16]),
    .b (rs2_d_in[31:16]),
    .out (alu_out_1)
);

mini_alu t2_alu(
    .func (func),
    .a (rs1_d_din[47:32]),
    .b (rs2_d_in[47:32]),
    .out (alu_out_2)
);

mini_alu t3_alu(
    .func (func),
    .a (rs1_d_din[63:48]),
    .b (rs2_d_in[63:48]),
    .out (alu_out_3)
);


always @(*) begin
    rd_d = 64'd00;
    func = 1'b0;
    dmem_addr = 16'd0;

    case (opcode)
        `LOAD : begin
            dmem_addr = rs1_d_in;
        end

        `STORE : begin
            dmem_addr = rs2_d_din;
        end

        `MOVE : begin
            rd_d = (move_source_in) ? imm_in : move_rd_d;
        end

        `SETP : begin
            rd_d = {alu_out_3[0], alu_out_2[0], alu_out_1[0], alu_out_0[0]}
            func = 2'b10;
        end

        `ADD : begin
            rd_d[15:0] = alu_out_0;
            rd_d[31:16] = alu_out_1;
            rd_d[47:32] = alu_out_2;
            rd_d[63:48] = alu_out_3;
            func = 2'b00;
        end

        `SUB : begin
            rd_d[15:0] = alu_out_0;
            rd_d[31:16] = alu_out_1;
            rd_d[47:32] = alu_out_2;
            rd_d[63:48] = alu_out_3;
            func = 2'b01;
        end

        `MAX : begin
            rd_d[0] = alu_out_0[0];
            rd_d[16] = alu_out_1[0];
            rd_d[32] = alu_out_2[0];
            rd_d[48] = alu_out_3[0];
            func = 2'b11;
        end

        `DEFAULT : begin // Dont need to do anything for RET handle FMA in tensor unit?

        end

    endcase

end


endmodule