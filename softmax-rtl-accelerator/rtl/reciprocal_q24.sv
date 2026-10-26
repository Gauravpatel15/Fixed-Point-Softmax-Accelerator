// floor(2^48 / denominator). Contract: denominator == 0 or >= 2^24.
// One shared shift/subtract divider, 49 cycles per nonempty row.
module reciprocal_q24 #(parameter integer DEN_W=39)(
  input logic clk, rst, start,
  input logic [DEN_W-1:0] denominator,
  output logic busy, done,
  output logic [24:0] reciprocal
);
  logic [DEN_W-1:0] divisor, remainder_q;
  logic [DEN_W:0] shifted_remainder, next_remainder;
  logic [24:0] quotient, next_quotient;
  logic [5:0] steps;
  logic subtract_enable;
  always_comb begin
    shifted_remainder = {remainder_q, (steps == 48)};
    subtract_enable = shifted_remainder >= {1'b0,divisor};
    next_remainder = subtract_enable ?
                     shifted_remainder - {1'b0,divisor} : shifted_remainder;
    next_quotient = {quotient[23:0], subtract_enable};
  end
  always_ff @(posedge clk) begin
    if (rst) begin
      busy<=0; done<=0; reciprocal<=0; divisor<=0;
      remainder_q<=0; quotient<=0; steps<=0;
    end else begin
      done<=0;
      if (start && !busy) begin
        if (denominator==0) begin reciprocal<=0; done<=1; end
        else begin
          divisor<=denominator; remainder_q<=0; quotient<=0;
          steps<=48; busy<=1;
        end
      end else if (busy) begin
        remainder_q<=next_remainder[DEN_W-1:0];
        quotient<=next_quotient;
        if (steps==0) begin reciprocal<=next_quotient; busy<=0; done<=1; end
        else steps<=steps-1'b1;
      end
    end
  end
endmodule
