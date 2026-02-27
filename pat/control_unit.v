`timescale 1ns / 1ps

module control_unit (
    input clk,
    input rst,

    // From top-level
    input start,
    input [15:0] start_pc,
    input [15:0] num_threads,

    // From write back unit
    input [3:0] threads_returned,

    // To imem
    output [15:0] pc_out,

    // To regfile unit
    output [12:0] iteration_ct_out,

    // To writeback unit
    output [3:0] curr_threads_finished
);

// ---------- Local Parameters ---------- //


// ---------- Local Variables ---------- //

reg [15:0] pc;
wire [15:0] pc_next;
reg [12:0] num_iterations, iteration_ct;
wire kernel_done; // PROBABLY EXPOSE TO TOP LEVEL TO KNOW WHEN KERNEL IS FINISHED
wire iteration_done;
reg [3:0] lanes_done;

assign pc_out = pc;
assign iteration_ct_out = iteration_ct;
assign kernel_done = (iteration_ct == num_iterations);
assign iteration_done = (lanes_done == 4'hf);
assign curr_threads_finished = lanes_done;

// ---------- Control Logic ---------- //

always @(*) begin
    if (pc == 16'hFFFF) begin
        pc_next = (start) ? start_pc : 16'hFFFF;
    end else begin
        pc_next = (iteration_done) ? start_pac : pc + 1'b1;
    end
end

always @(posedge clk) begin
    if (rst || kernel_done) begin
        pc <= 16'hFFFF;
        num_iterations <= 0;
        iteration_ct <= 0;
        lanes_done <= 0;
    end else begin
        pc <= pc_next;

        // Set num_iterations at beginning of kernel run
        if (start) num_iterations <= num_threads[14:2]; // num threads / 4 threads at a time
        
        // Update threads that are finished
        lanes_done <= lanes_done | threads_returned;

        // Update pc and iteration ct after finishing iteration ** MIGHT NEED TO ADD A FLUSH BC BY TIME ITER FINISHES THERE WILL BE SOME INST IN PIPELINE
        iteration_ct <= iteration_ct + 1'b1;

    end
end

endmodule