`timescale 1ns / 1ps

module decode_unit (
    input clk,
    input rst,

    // From imem
    input [31:0] inst,

    // To idex pipeline reg
    output [4:0] rd_s_out,
    output [3:0] opcode_out,
    output eop_out,
    output predicated_out,
    output thread_batch_done_out,
    output [15:0] imm_out,
    output dtype_out,
    output rs1_type_out,
    output move_source_out,
    output rd_data_source_out,
    output move_source_thread_idx,

    // To regfile
    output [4:0] rs1_s_out,
    output [4:0] rs2_s_out,
    output [4:0] rs3_s_out
);

// ---------- Local Parameters ---------- //


// ---------- Local Variables ---------- //
wire [3:0] opcode;
wire [4:0] rd_s, rs1_s, rs2_s, rs3_s;
wire [15:0] imm;
wire eop, predicated, dtype;

wire thread_batch_done;
wire rs1_type;  // 0 = regular regs, 1 = param regs
wire move_source;   // 0 = register, 1 = immediate
wire rd_data_source;    // 0 = ex unit, 1 = tensor unit
wire move_source_thread_idx;    // 0 = no, 1 = yes move source is %tid.x

// these dont change based off inst so just assign
assign opcode = inst[3:0];
assign imm = inst[25:10];
assign eop = inst[31];
assign predicated = inst[30];
assign dtype = inst[29];

// ---------- Decode Logic ---------- //

always @(*) begin
    rd_s = 5'd0;
    rs1_s = 5'd0;
    rs2_s = 5'd0;
    rs3_s = 5'd0;
    thread_batch_done = 1'b0;
    rs1_type = 1'b0;
    move_source = 1'b0;
    rd_data_source = 1'b0;
    move_source_thread_idx = 1'b0;

    case (opcode)
        `RET : begin
            thread_batch_done = 1'b1;
        end

        `LOAD : begin
            rd_s = inst[9:5];
            rs1_s = inst[14:10];
            rs1_type = inst[4];
            rd_data_source = 1'b0;
        end

        `STORE : begin
            rs2_s = inst[9:5];
            rs1_s = inst[14:10];
            rs1_type = 1'b0;    // cannot store to param regs read only
        end

        `MOVE : begin
            rd_s = inst[9:5];
            move_source = inst[4];
            rs1_s = (move_source) ? 5'd0 : inst[14:10];
            move_source_thread_idx = (rs1_s == 5'b11111);
            rd_data_source = 1'b0;
        end

        `SETP : begin
            rs1_s = inst[8:4];
            rs2_s = inst[13:9];
            rd_data_source = 1'b0;
        end

        `ADD : begin
            rd_s = inst[8:4];
            rs1_s = inst[13:9];
            rs2_s = inst[18:14];
            rd_data_source = 1'b0;
        end

        `SUB : begin
            rd_s = inst[8:4];
            rs1_s = inst[13:9];
            rs2_s = inst[18:14];
            rd_data_source = 1'b0;
        end

        `FMA : begin
            rd_s = inst[8:4];
            rs1_s = inst[13:9];
            rs2_s = inst[18:14];
            rs3_s = inst[24:19];
            rd_data_source = 1'b1;
        end

        `MAX : begin
            rd_s = inst[8:4];
            rs1_s = inst[13:9];
            rs2_s = inst[18:14];
            rd_data_source = 1'b0;
        end

        DEFAULT : begin
            thread_batch_done = 1'b1;
        end
    endcase
end

assign rd_s_out = rd_s;
assign opcode_out = opcode;
assign eop_out = eop;
assign predicated_out = predicated;
assign thread_batch_done_out = thread_batch_done;
assign imm_out = imm;
assign dtype_out = dtype;
assign rs1_type_out = rs1_type;
assign move_source_out = move_source;
assign rd_data_source_out = rd_data_source;

assign rs1_s_out = rs1_s;
assign rs2_s_out = rs2_s;
assign rs3_s_out = rs3_s;

endmodule