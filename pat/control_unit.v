`timescale 1ns / 1ps

module control_unit (
    input clk,
    input rst,

    // From top-level
    input start,
    input [15:0] start_pc,
    input [15:0] num_threads,

    // From write back unit
    input [3:0] threads_done,

    // To imem
    output [15:0] pc_out,

    // To regfile unit
    output [12:0] iteration_ct_out
);

// ---------- Local Parameters ---------- //


// ---------- Local Variables ---------- //

reg [15:0] pc;
wire [15:0] pc_next;
reg [12:0] num_iterations, iteration_ct;

assign pc_out = pc;
assign iteration_ct_out = iteration_ct;

// ---------- Control Logic ---------- //

always @(*) begin
    if (pc == 32'hFFFF) begin
        pc_next = (start) ? start_pc : 16'hFFFF;
    end else begin
        pc_next = pc + 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        pc <= 16'hFFFF;
        num_iterations <= 0;
        iteration_ct <= 0;
    end else begin
        pc <= pc_next;
        if (start) num_iterations <= num_threads[14:2]; // num threads / 4 threads at a time
    end
end

endmodule