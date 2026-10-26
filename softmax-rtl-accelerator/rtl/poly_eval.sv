`timescale 1ns/1ps
module poly_eval #(
  parameter integer MODE = 1 // 0: Horner, 1: Estrin
)(
  input logic clk, rst, ce, in_valid,
  input logic [15:0] in_frac,
  output logic out_valid,
  output logic signed [25:0] out_value
);
  import softmax_pkg::*;
  generate if (MODE == 0) begin : g_horner
    logic [2:0] valid_pipe;
    logic [15:0] f0, f1;
    logic signed [25:0] t0, t1, t2;
    always_ff @(posedge clk) begin
      if (rst) begin
        valid_pipe <= '0; f0 <= '0; f1 <= '0;
        t0 <= '0; t1 <= '0; t2 <= '0;
      end else if (ce) begin
        valid_pipe <= {valid_pipe[1:0], in_valid};
        if (in_valid) begin
          t0 <= C2 + mul_frac(C3, in_frac);
          f0 <= in_frac;
        end
        if (valid_pipe[0]) begin
          t1 <= C1 + mul_frac(t0, f0);
          f1 <= f0;
        end
        if (valid_pipe[1]) t2 <= C0 + mul_frac(t1, f1);
      end
    end
    assign out_valid = valid_pipe[2];
    assign out_value = t2;
  end else begin : g_estrin
    logic [1:0] valid_pipe;
    logic signed [25:0] a, b, result_q;
    logic [15:0] square_q16;
    logic [31:0] square_full;
    assign square_full = {16'b0,in_frac} * {16'b0,in_frac};
    always_ff @(posedge clk) begin
      if (rst) begin
        valid_pipe <= '0; a <= '0; b <= '0;
        square_q16 <= '0; result_q <= '0;
      end else if (ce) begin
        valid_pipe <= {valid_pipe[0], in_valid};
        if (in_valid) begin
          a <= C0 + mul_frac(C1, in_frac);
          b <= C2 + mul_frac(C3, in_frac);
          square_q16 <= square_full[31:16];
        end
        if (valid_pipe[0]) result_q <= a + mul_frac(b, square_q16);
      end
    end
    assign out_valid = valid_pipe[1];
    assign out_value = result_q;
  end endgenerate
endmodule
