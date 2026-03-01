`timescale 1ns / 1ps

module bfloat16add (
    input  wire [15:0] a,
    input  wire [15:0] b,
    output wire [15:0] out
);

    // --- Unpack & quick special-case detection
    wire sa = a[15], sb = b[15];
    wire [7:0] ea = a[14:7], eb = b[14:7];
    wire [6:0] fa = a[6:0], fb = b[6:0];

    wire a_nan = (ea == 8'hFF) & (fa != 0);
    wire b_nan = (eb == 8'hFF) & (fb != 0);
    wire a_inf = (ea == 8'hFF) & (fa == 0);
    wire b_inf = (eb == 8'hFF) & (fb == 0);
    wire a_zero = (ea == 0) & (fa == 0);
    wire b_zero = (eb == 0) & (fb == 0);

    // Prefer propagate a's NaN payload, else b, else default qNaN
    wire [15:0] qnan_a = {1'b0, 8'hFF, {1'b1, fa[5:0]}};
    wire [15:0] qnan_b = {1'b0, 8'hFF, {1'b1, fb[5:0]}};
    wire [15:0] default_qnan = 16'h7FC1;

    // Special-case output if needed
    wire special = a_nan | b_nan | a_inf | b_inf | a_zero | b_zero;
    wire [15:0] out_special =
        a_nan ? qnan_a :
        b_nan ? qnan_b :
        (a_inf & b_inf & (sa != sb)) ? default_qnan : // Inf - Inf -> NaN
        a_inf ? {sa,8'hFF,7'b0} :
        b_inf ? {sb,8'hFF,7'b0} :
        (a_zero & b_zero) ? ({(sa & sb),8'b0,7'b0}) :
        a_zero ? {sb, eb, fb} :
        b_zero ? {sa, ea, fa} :
        default_qnan; // fallback

    // --- Build significands (8-bit: implicit 1 for normals)
    wire [7:0] sig_a = (ea == 8'b0) ? {1'b0, fa} : {1'b1, fa};
    wire [7:0] sig_b = (eb == 8'b0) ? {1'b0, fb} : {1'b1, fb};

    // Ensure operand A has >= magnitude (exp then mantissa)
    wire exp_gt = (ea > eb);
    wire exp_eq = (ea == eb);
    wire mant_gt = (sig_a > sig_b);

    wire swap = (~exp_gt & (~exp_eq | ~mant_gt)); // swap when b is larger
    wire sA = swap ? sb : sa;
    wire sB = swap ? sa : sb;
    wire [7:0] eA = swap ? eb : ea;
    wire [7:0] eB = swap ? ea : eb;
    wire [7:0] mA = swap ? sig_b : sig_a;
    wire [7:0] mB = swap ? sig_a : sig_b;

    // --- Alignment (cap shift to 11 = mantissa(8)+GRS(3))
    wire [8:0] raw_diff = eA - eB; // non-negative (A has >= exponent)
    wire [3:0] d = (raw_diff[8:4] != 0) ? 4'd11 : (raw_diff[3:0] > 4'd11 ? 4'd11 : raw_diff[3:0]);

    wire [10:0] mB_ext = {mB, 3'b000}; // append G,R,S slots
    wire [10:0] mA_ext = {mA, 3'b000};

    // Shift with sticky: if d >= 11 => B becomes 0 and sticky = OR(all B bits)
    reg [10:0] mB_sh;
    reg sticky;
    integer i;
    always @(*) begin
        if (d >= 11) begin
            mB_sh = 11'b0;
            sticky = |mB_ext;
        end else begin
            mB_sh = mB_ext >> d;
            // sticky = OR of shifted-out bits
            sticky = 1'b0;
            for (i = 0; i < d; i = i + 1) sticky = sticky | mB_ext[i];
        end
    end

    wire G = mB_sh[2];
    wire R = mB_sh[1];
    wire LSB_part = mB_sh[0];

    // Combined sticky includes the leftover LSB part that was shifted into bit0
    wire sticky_comb = sticky | LSB_part;

    // --- Add/Subtract
    wire same_sign = (sA == sB);
    wire [11:0] sum = {1'b0, mA_ext} + {1'b0, mB_sh};       // up to 12 bits
    wire [11:0] diffm = {1'b0, mA_ext} - {1'b0, mB_sh};     // up to 12 bits
    wire [11:0] mag = same_sign ? sum : diffm;
    wire res_sign = sA;

    // --- Normalization
    // If addition overflow (bit11==1) -> right shift by 1, exp+1
    // Else need leading-zero count on mag[10:0] and left shift accordingly
    function [3:0] lz11;
        input [10:0] v;
        integer k;
        begin
            lz11 = 4'd0;
            for (k = 10; k >= 0; k = k - 1) begin
                if (v[k] == 1'b0) lz11 = lz11 + 1;
                else k = -1; // break
            end
        end
    endfunction

    reg [10:0] norm_m;   // 11 bits: [10:3] mant, [2]=G,[1]=R,[0]=S
    reg [7:0]  norm_e;
    reg is_zero;
    reg to_inf;
    integer lz;
    always @(*) begin
        is_zero = 1'b0;
        to_inf = 1'b0;
        if (mag == 12'b0) begin
            is_zero = 1'b1;
            norm_m = 11'b0;
            norm_e = 8'b0;
        end else if (same_sign && mag[11]) begin
            // add with carry
            norm_m = mag[11:1]; // shift right 1
            if (eA == 8'hFE) begin
                to_inf = 1'b1;
                norm_e = 8'hFF;
            end else norm_e = eA + 1;
        end else begin
            // either add without carry or subtract result -> left normalize
            lz = lz11(mag[10:0]);
            if (eA <= lz) begin
                // underflow to subnormal or zero: set exponent 0 and produce mantissa shifted (we'll handle subnormal rounding below)
                norm_e = 8'b0;
                norm_m = mag[10:0] << lz;
            end else begin
                norm_e = eA - lz;
                norm_m = mag[10:0] << lz;
            end
        end
        // Ensure sticky bit folded into norm_m[0] (already happened earlier for shifted B; we OR with sticky_comb)
        norm_m[0] = norm_m[0] | sticky_comb;
    end

    // --- Rounding (round-to-nearest-even)
    wire lsb = norm_m[3];   // least significant retained bit
    wire gbit = norm_m[2];
    wire rbit = norm_m[1];
    wire sbit = norm_m[0];

    wire round_inc = gbit & (rbit | sbit | lsb);

    wire [8:0] top8 = {1'b0, norm_m[10:3]}; // 9-bit so we can detect carry from rounding
    wire [8:0] rounded = top8 + (round_inc ? 9'd1 : 9'd0);

    // If rounding produced carry into bit8 -> exponent increment needed
    wire round_carry = rounded[8];

    // Final exponent and fraction selection
    reg [7:0] final_e;
    reg [6:0] final_f;
    reg final_is_inf, final_is_zero;
    always @(*) begin
        final_is_inf = 1'b0;
        final_is_zero = 1'b0;

        if (is_zero) begin
            final_is_zero = 1'b1;
            final_e = 8'b0;
            final_f = 7'b0;
        end else if (to_inf) begin
            final_is_inf = 1'b1;
            final_e = 8'hFF;
            final_f = 7'b0;
        end else begin
            if (round_carry) begin
                if (norm_e == 8'hFE) begin
                    final_is_inf = 1'b1;
                    final_e = 8'hFF;
                    final_f = 7'b0;
                end else begin
                    final_e = norm_e + 1;
                    final_f = rounded[6:0];
                end
            end else begin
                final_e = norm_e;
                final_f = rounded[6:0];
            end
        end
    end

    // Select special vs datapath
    wire [15:0] datapath_out = final_is_inf ? {res_sign,8'hFF,7'b0} :
                               final_is_zero ? {res_sign,8'b0,7'b0} :
                               {res_sign, final_e, final_f};

    assign out = special ? out_special : datapath_out;

endmodule