`timescale 1ns / 1ps

module register_unit (
    input clk,
    input rst,

    // From decode unit
    input [4:0] rs1_s,
    input [4:0] rs2_s,
    input [4:0] rs3_s,

    // From write back unit
    input [3:0] opcode,
    input [3:0] commit,
    input [4:0] rd_s,
    input [63:0] rd_d,

    // To pipeline registers
    output [63:0] rs1_d,
    output [63:0] rs2_d,
    output [63:0] rs3_d,
    output [3:0] predicate_d
);

// ---------- Local Variables ---------- //
reg [63:0] data_reg [0:21];
reg [3:0] predicate_reg;

wire [63:0] new_rd_d;
wire [15:0] thread0_rd_d, thread1_rd_d, thread2_rd_d, thread3_rd_d;
wire [3:0] new_predicate_d;
wire thread0_predicate_d, thread1_predicate_d, thread2_predicate_d, thread3_predicate_d;

// ---------- Logic ---------- //
always @(*) begin
    thread0_rd_d = (commit[0]) ? rd_d[15:0] ? data_reg[rd_s][15:0];
    thread1_rd_d = (commit[1]) ? rd_d[31:16] ? data_reg[rd_s][31:16];
    thread2_rd_d = (commit[2]) ? rd_d[47:32] ? data_reg[rd_s][47:32];
    thread3_rd_d = (commit[3]) ? rd_d[63:48] ? data_reg[rd_s][63:48];
    new_rd_d = {thread3_rd_d, thread2_rd_d, thread1_rd_d, thread0_rd_d};

    thread0_predicate_d = (commit[0]) ? rd_d[0] ? predicate_reg[0];
    thread1_predicate_d = (commit[1]) ? rd_d[1] ? predicate_reg[1];
    thread2_predicate_d = (commit[2]) ? rd_d[2] ? predicate_reg[2];
    thread3_predicate_d = (commit[3]) ? rd_d[3] ? predicate_reg[3];
    new_predicate_d = {thread3_predicate_d, thread2_predicate_d, thread1_predicate_d, thread0_predicate_d};

    // Read logic
    rs1_d = data_reg[rs1_s];
    rs2_d = data_reg[rs2_s];
    rs3_d = data_reg[rs3_s];
    predicate_d = predicate_reg;
end

always @(posedge clk) begin
    if (rst) begin
        for (int i = 0; i < 22; i=i+1) begin
            data_reg[i[4:0]] <= 0;
        end 
        predicate_reg <= 0;
    end else begin
        // Write logic
        if (commit != 4'd0) begin
            if (opcode == 4'd4) begin   // write to predicate registers if setp
                predicate_reg <= new_predicate_d;
            end else begin
                data_reg[rd_s] <= new_rd_d;
            end
        end
    end
end

endmodule