`timescale 1ns / 1ps

module writeback_unit (
    input clk,
    input rst,

    // From control unit
    input [3:0] curr_threads_finished,

    // From dmem
    input [63:0] dmem_dout_in,

    // From EXWB pipeline register
    input [3:0] exwb_opcode_in,
    input exwb_predicated_in,
    input exwb_thread_batch_done_in,
    input exwb_rd_data_source_in,
    input [3:0]  exwb_predicate_d_in,
    input exwb_reg_we_in,
    input [63:0] exwb_rd_d_in,
    input [63:0] tuwb_rd_d_in,          // attach to tensor unit/wb pipeline reg

    // To control unit
    output [3:0] threads_returned_out,

    // To dmem
    output [63:0] dmem_din_out,
    output dmem_we_out,

    // To register unit
    output [3:0] commit_out,
    output [63:0] regfile_din_out
);

// ---------- Local Variables ---------- //
wire  [63:0]    regfile_din_out;
wire  [3:0]     commit;
wire  [3:0]     threads_returned;
wire  [63:0]    dmem_din;
wire            dmem_we;

// ---------- Writeback Logic ---------- //

always @(*) begin
    regfile_din_out = (exwb_rd_data_source_in) ? tuwb_rd_d_in : exwb_rd_d_in;
    dmem_we = (exwb_opcode_in == `STORE) && (curr_threads_finished != 4'hf);

    if (exwb_predicated_in) begin
        // Regfile predication/thread finished check
        commit[0] = exwb_reg_we_in && exwb_predicate_d_in[0] && ~curr_threads_finished[0];
        commit[1] = exwb_reg_we_in && exwb_predicate_d_in[1] && ~curr_threads_finished[1];
        commit[2] = exwb_reg_we_in && exwb_predicate_d_in[2] && ~curr_threads_finished[2];
        commit[3] = exwb_reg_we_in && exwb_predicate_d_in[3] && ~curr_threads_finished[3];

        // Dmem predication/thread finished check
        dmem_din[15:0] = (exwb_predicate_d_in[0]) ? exwb_rd_d_in[15:0] : dmem_dout_in[15:0];
        dmem_din[31:16] = (exwb_predicate_d_in[1]) ? exwb_rd_d_in[31:16] : dmem_dout_in[31:16];
        dmem_din[47:32] = (exwb_predicate_d_in[2]) ? exwb_rd_d_in[47:32] : dmem_dout_in[47:32];
        dmem_din[63:48] = (exwb_predicate_d_in[3]) ? exwb_rd_d_in[63:48] : dmem_dout_in[63:48];

        // Thread finished predication check
        threads_returned[0] = exwb_thread_batch_done_in && exwb_predicate_d_in[0];
        threads_returned[1] = exwb_thread_batch_done_in && exwb_predicate_d_in[1];
        threads_returned[2] = exwb_thread_batch_done_in && exwb_predicate_d_in[2];
        threads_returned[3] = exwb_thread_batch_done_in && exwb_predicate_d_in[3];
    end else begin
        commit = {4{exwb_reg_we_in}};
        dmem_din = exwb_rd_d_in;
        threads_returned = {4{exwb_thread_batch_done_in}};
    end
end

assign threads_returned_out = threads_returned;
assign dmem_din_out = dmem_din;
assign dmem_we_out = dmem_we;
assign commit_out = commit;
assign regfile_din_out = regfile_din;


endmodule