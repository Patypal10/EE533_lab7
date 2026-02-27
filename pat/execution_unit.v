`timescale 1ns / 1ps

module execution_unit (
    input clk,
    input rst,

    // From idex pipeline reg
    input [3:0] opcode_in,
    input [15:0] imm_in,
    input dtype_in,
    input rs1_type_in,
    input move_source_in,
    input [63:0] rs1_d_in,
    input [63:0] rs2_d_in,
    input move_source_thread_idx_in,

    // To exwb pipeline reg/dmem
    output [63:0] rd_d_out,
    output [15:0] dmem_addr    // For loads send read request from here
);

// ---------- Local Variables ---------- //
wire  [63:0]        rd_d;

wire  [1:0]         func;   // 0 = add, 1 = sub, 2 = greater/equal, 3 = max
wire  [15:0]        alu_out_0, alu_out_1, alu_out_2, alu_out_3;

wire  [15:0]        dmem_addr;

// ---------- Execution Logic ---------- //
mini_alu t0_alu(
    .func (func),
    .a (rs1_d_in[15:0]),
    .b (rs2_d_in[15:0]),
    .out (alu_out_0)
);

mini_alu t1_alu(
    .func (func),
    .a (rs1_d_in[31:16]),
    .b (rs2_d_in[31:16]),
    .out (alu_out_1)
);

mini_alu t2_alu(
    .func (func),
    .a (rs1_d_in[47:32]),
    .b (rs2_d_in[47:32]),
    .out (alu_out_2)
);

mini_alu t3_alu(
    .func (func),
    .a (rs1_d_in[63:48]),
    .b (rs2_d_in[63:48]),
    .out (alu_out_3)
);


always @(*) begin
    rd_d = 64'd00;
    func = 1'b0;
    dmem_addr = 16'd0;

    case (opcode_in)
        `LOAD : begin
            dmem_addr = rs1_d_in;
            rd_d = (rs1_type_in) ? {rs1_d_in[15:0], rs1_d_in[15:0], rs1_d_in[15:0], rs1_d_in[15:0]} : 64'd00; // If loading from param reg, param data will be passed into rs1_d in top level
        end

        `STORE : begin
            dmem_addr = rs2_d_in;
        end

        `MOVE : begin
            if (move_source_in) begin
                rd_d[15:0] = imm_in;
            end else if (move_source_thread_idx_in) begin
                rd_d[12:0] = rs1_d_in[12:0];
                rd_d[29:16] = rs1_d_in[12:0] + 2'b01;
                rd_d[45:32] = rs1_d_in[12:0] + 2'b10;
                rd_d[61:48] = rs1_d_in[12:0] + 2'b11;
            end else begin
                rd_d = rs1_d_in;
            end
        end

        `SETP : begin
            rd_d[0] = alu_out_0[0];
            rd_d[16] = alu_out_1[0];
            rd_d[32] = alu_out_2[0];
            rd_d[48] = alu_out_3[0];
            func = 2'b10;
        end

        `ADD : begin
            rd_d = {alu_out_3, alu_out_2, alu_out_1, alu_out_0}
            func = 2'b00;
        end

        `SUB : begin
            rd_d = {alu_out_3, alu_out_2, alu_out_1, alu_out_0}
            func = 2'b01;
        end

        `MAX : begin
            rd_d = {alu_out_3, alu_out_2, alu_out_1, alu_out_0}
            func = 2'b11;
        end

        `DEFAULT : begin // Dont need to do anything for RET, handle FMA in tensor unit?

        end

    endcase

end


endmodule