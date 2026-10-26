`timescale 1ns/1ps
module softmax_tester #(parameter integer MODE=1)(input logic clk, output logic done);
  logic rst=1, in_valid=0, in_ready, in_mask=0, in_last=0;
  logic signed [15:0] in_score=0;
  logic out_valid, out_ready=0, out_last, out_error;
  logic [24:0] out_probability;
  `include "vectors.svh"
  softmax_core #(.MAX_LEN(16384),.MODE(MODE)) dut(.*);
  integer first, finish, idx, received, cycles=0, rows=0;
  integer row_start, last_input, first_output;
  logic held=0;
  logic [26:0] held_value;
  logic [24:0] expected;

  always @(posedge clk) begin
    cycles<=cycles+1;
    if (rst) held<=0;
    else begin
      if (held && (!out_valid || {out_error,out_last,out_probability}!==held_value))
        $fatal(1,"MODE=%0d output changed under backpressure",MODE);
      held<=out_valid && !out_ready;
      held_value<={out_error,out_last,out_probability};
    end
    if (cycles>2000000) $fatal(1,"Simulation timeout");
  end

  initial begin
    done=0;
    repeat(5) @(negedge clk);
    rst=0;
    // Reset a partially loaded row; no memory initialization is required.
    in_valid=1; in_score=17;
    @(negedge clk); in_valid=0; rst=1;
    repeat(2) @(negedge clk);
    rst=0;
    first=0;
    while (first<VECTOR_COUNT) begin
      finish=first;
      while (!vectors[finish][69]) finish=finish+1;
      row_start=cycles;
      for (idx=first;idx<=finish;idx=idx+1) begin
        @(negedge clk);
        in_valid=0;
        if ((idx%7)==0) @(negedge clk);
        in_score=vectors[idx][15:0];
        in_mask=vectors[idx][16]; in_last=vectors[idx][17]; in_valid=1;
        @(posedge clk);
        while (!in_ready) @(posedge clk);
      end
      last_input=cycles;
      @(negedge clk); in_valid=0; out_ready=1;
      received=first; first_output=-1;
      while (received<=finish) begin
        @(posedge clk);
        if (out_valid && out_ready) begin
          if (first_output<0) first_output=cycles;
          expected=(MODE==0)?vectors[received][42:18]:vectors[received][67:43];
          if (out_probability!==expected)
            $fatal(1,"MODE=%0d index=%0d expected=%0d got=%0d",
                   MODE,received,expected,out_probability);
          if (out_last!==vectors[received][69] || out_error!==vectors[received][68])
            $fatal(1,"MODE=%0d framing/error mismatch at %0d",MODE,received);
          received=received+1;
        end
        @(negedge clk);
        out_ready=((cycles%5)!=0 && (cycles%5)!=1);
      end
      out_ready=0;
      $display("MODE=%0d row=%0d length=%0d last-input-to-first-output=%0d total-with-stalls=%0d",
               MODE,rows,finish-first+1,first_output-last_input,cycles-row_start);
      rows=rows+1; first=finish+1;
    end
    repeat(5) @(negedge clk);
    if (out_valid) $fatal(1,"Unexpected extra output");
    $display("MODE %0d PASSED: %0d rows, %0d outputs",MODE,rows,VECTOR_COUNT);
    done=1;
  end
endmodule

module tb_softmax;
  logic clk=0;
  wire done_horner, done_estrin;
  always #2.5 clk=~clk;
  softmax_tester #(.MODE(0)) h(clk,done_horner);
  softmax_tester #(.MODE(1)) e(clk,done_estrin);
  initial begin
    wait(done_horner && done_estrin);
    $display("ALL SOFTMAX RTL TESTS PASSED");
    $finish;
  end
endmodule
