`timescale 1ns / 1ps

module control_unit (
    input clk,
    input rst,

    // From top-level
    input start,
    
    // From decode unit
    input ex_unit_to_use,

    // From ex_unit
    input all_threads_done,

    // To imem
    output [31:0] pc_out
);

// ---------- Local Parameters ---------- //
// FSM State defines
localparam WAIT = 3'd0;
localparam FETCH = 3'd1;
localparam DECODE = 3'd2;
localparam EX_UNIT = 3'd4;
localparam TENSOR_UNIT = 3'd5;
localparam WRITE_BACK = 3'd7;

// ---------- Local Variables ---------- //
reg [2:0] curr_state, next_state;
reg [31:0] pc;

assign pc_out = pc;

// ---------- FSM Logic ---------- //
always @(*) begin
    case (curr_state)
        WAIT : next_state = (start) ? FETCH : WAIT;
        FETCH : next_state = DECODE;
        DECODE : next_state = (ex_unit_to_use) ? EX_UNIT : TENSOR_UNIT;
        EX_UNIT : next_state = WRITE_BACK;
        TENSOR_UNIT : next_state = WRITE_BACK;
        WRITE_BACK : next_state = (all_threads_done) WAIT : WRITE_BACK;
        default : next_state = WAIT;
    endcase

end

always @(posedge clk) begin
    if (rst) begin
        curr_state <= WAIT;
        next_state <= WAIT;
        pc <= 0;
    end else begin
        curr_state <= next_state;
        pc <= pc_next;
    end
end

endmodule