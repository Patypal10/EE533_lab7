`timescale 1ns / 1ps

module bfloat16mult(
    input [15:0] a,
    input [15:0] b,
    output reg [15:0] out
);

// Break apart fields
wire a_sign = a[15];
wire [7:0] a_exp = a[14:7];
wire [6:0] a_mantissa = a[6:0];

wire b_sign = b[15];
wire [7:0] b_exp = b[14:7];
wire [6:0] b_mantissa = b[6:0];

// Special cases
wire a_is_zero = (a_exp == 8'd0) && (a_mantissa == 7'd0);
wire b_is_zero = (b_exp == 8'd0) && (b_mantissa == 7'd0);
wire a_is_inf  = (a_exp == 8'hFF) && (a_mantissa == 7'd0);
wire b_is_inf  = (b_exp == 8'hFF) && (b_mantissa == 7'd0);
wire a_is_nan  = (a_exp == 8'hFF) && (a_mantissa != 7'd0);
wire b_is_nan  = (b_exp == 8'hFF) && (b_mantissa != 7'd0);

// Sign calc
wire prod_sign = a_sign ^ b_sign;

// Get fractional representation
wire [7:0] fractionA = (a_exp == 8'd0) ? {1'b0, a_mantissa} : {1'b1, a_mantissa};
wire [7:0] fractionB = (b_exp == 8'd0) ? {1'b0, b_mantissa} : {1'b1, b_mantissa};
wire [15:0] product = fractionA * fractionB;

// Unbias exponents
wire signed [10:0] expA_unbiased = (a_exp == 8'd0) ? (11'sd1 - $signed(127)) : ($signed({3'b000, a_exp}) - $signed(127));
wire signed [10:0] expB_unbiased = (b_exp == 8'd0) ? (11'sd1 - $signed(127)) : ($signed({3'b000, b_exp}) - $signed(127));

// Normalization and rounding determination
wire prod_msb = product[15]; // if 1, product >= 2.0 so shift later
wire [7:0] prod_retained = prod_msb ? product[15:8] : product[14:7]; // 8 bits: [7]=implicit 1 or 0 for subnormal inputs and rest are fracitonal bits
wire guard = prod_msb ? product[7]  : product[6];
wire roundb = prod_msb ? product[6]  : product[5];
wire sticky = prod_msb ? |product[5:0] : |product[4:0];
wire round_up = guard & (roundb | sticky | prod_retained[0]); // Round to nearest even 
// | retained (8 bits) | G | R | SSSSSS |

// Product exponent unbiased
wire signed [11:0] prod_exponent_unbiased = $signed(expA_unbiased) + $signed(expB_unbiased) + (prod_msb ? 11'sd1 : 11'sd0);

// Apply rounding
wire [8:0] rounded_prod = {1'b0, prod_retained} + {8'b0, round_up}; // 9 bits to detect carry
wire roundup_prod_carry = rounded_prod[8];
wire [7:0] rounded_prod_sig = rounded_prod[7:0];
//if round up must shift right and increment exp
wire signed [12:0] exp_after_round = $signed(prod_exponent_unbiased) + (roundup_prod_carry ? 13'sd1 : 13'sd0);

// Calculte exponent with bias
wire signed [13:0] exp_with_bias = exp_after_round + $signed(127);

// Format output
reg [7:0] final_sig;
reg [7:0] exp_field;

always @* begin
    // Defaults
    out = 16'h0000;

    // Propagate NaN if any input is NaN
    if (a_is_nan || b_is_nan) begin
        // canonical quiet NaN: sign=0, exp=255, MSB of frac=1
        out = {1'b0, 8'hFF, 7'b1000000};
    end else if ( (a_is_inf && b_is_zero) || (b_is_inf && a_is_zero) ) begin
        // Inf * 0 -> NaN
        out = {1'b0, 8'hFF, 7'b1000000};
    end else if (a_is_inf || b_is_inf) begin
        // Inf * non-zero -> Inf with sign
        out = {prod_sign, 8'hFF, 7'd0};
    end else if (a_is_zero || b_is_zero) begin
        // Zeroes
        out = {prod_sign, 8'd0, 7'd0};
    end else begin
        // Normal numeric flow
        // Check final exponent ranges
        // If exponent_with_bias >= 255 -> overflow => Inf
        // If exponent_with_bias <= 0   -> underflow => flush-to-zero
        if (exp_with_bias >= 14'sd255) begin
            // Overflow -> infinity
            out = {prod_sign, 8'hFF, 7'd0};
        end else if (exp_with_bias <= 14'sd0) begin
            // Underflow -> flush-to-zero (simplified)
            out = {prod_sign, 8'd0, 7'd0};
        end else begin
            // Normal packing
            // If rounding caused carry, the implied 1 is at bit position of rounded result:
            // - If roundup_prod_carry: the normalized mantissa is (rounded_sig becomes 8'h80 implicitly, fractional bits 0)
            // - else: mantissa bits are rounded_sig[6:0]
            final_sig = roundup_prod_carry ? {1'b1, 7'b0} : rounded_prod_sig;
            exp_field = exp_with_bias[7:0]; // safe because we've checked range

            // Pack: sign | exponent | fraction (lower 7 bits of final_sig)
            out = {prod_sign, exp_field, final_sig[6:0]};
        end
    end
end

endmodule