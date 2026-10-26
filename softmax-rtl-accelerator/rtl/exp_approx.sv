`timescale 1ns/1ps
module exp_approx #(
  parameter integer MODE = 1
)(
  input logic clk, rst,
  input logic in_valid,
  output logic in_ready,
  input logic [15:0] in_difference, // (maximum - score), unsigned Q8.8
  input logic in_mask,
  output logic out_valid,
  input logic out_ready,
  output logic [24:0] out_value // unsigned, 24 fractional bits
);
  import softmax_pkg::*;
  localparam integer DEPTH = (MODE == 0) ? 3 : 2;
  logic ce, range_valid, exact_one, range_mask;
  logic [32:0] scaled_product;
  logic [15:0] fraction;
  logic [8:0] exponent_k;
  logic [8:0] k_pipe [0:DEPTH-1];
  logic [DEPTH-1:0] one_pipe, mask_pipe;
  logic signed [25:0] poly_value;
  integer i;

  assign ce = !out_valid || out_ready;
  assign in_ready = ce && !rst;
  assign scaled_product = in_difference * LOG2E_Q16;
  always_ff @(posedge clk) begin
    if (rst) begin
      range_valid <= 1'b0; fraction <= '0; exponent_k <= '0;
      exact_one <= 1'b0; one_pipe <= '0; range_mask <= 0; mask_pipe <= '0;
      for (i=0; i<DEPTH; i=i+1) k_pipe[i] <= '0;
    end else if (ce) begin
      range_valid <= in_valid;
      if (in_valid) begin
        // Difference is Q8.8, product Q24: discard 8 bits to obtain Q16.
        fraction <= scaled_product[23:8];
        exponent_k <= scaled_product[32:24];
        exact_one <= (in_difference == 0);
        range_mask <= in_mask;
      end
      k_pipe[0] <= exponent_k;
      one_pipe[0] <= exact_one;
      mask_pipe[0] <= range_mask;
      for (i=1; i<DEPTH; i=i+1) begin
        k_pipe[i] <= k_pipe[i-1]; one_pipe[i] <= one_pipe[i-1]; mask_pipe[i] <= mask_pipe[i-1];
      end
    end
  end
  poly_eval #(.MODE(MODE)) polynomial (
    .clk(clk), .rst(rst), .ce(ce), .in_valid(range_valid),
    .in_frac(fraction), .out_valid(out_valid), .out_value(poly_value)
  );
  always_comb begin
    if (mask_pipe[DEPTH-1]) out_value = '0;
    else if (one_pipe[DEPTH-1]) out_value = ONE_Q24;
    else if (poly_value <= 0 || k_pipe[DEPTH-1] >= 32) out_value = '0;
    else if (poly_value > $signed({1'b0,ONE_Q24}))
      out_value = ONE_Q24 >> k_pipe[DEPTH-1];
    else out_value = $unsigned(poly_value) >> k_pipe[DEPTH-1];
  end
endmodule
