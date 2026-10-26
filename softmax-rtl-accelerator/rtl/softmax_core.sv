module softmax_core #(
  parameter integer MAX_LEN=16384,
  parameter integer MODE=1 // 0 Horner, 1 Estrin
)(
  input logic clk, rst,
  input logic in_valid,
  output logic in_ready,
  input logic signed [15:0] in_score, // signed raw / 256
  input logic in_mask, in_last,      // mask=1 excludes the entry
  output logic out_valid,
  input logic out_ready,
  output logic [24:0] out_probability, // unsigned raw / 2^24
  output logic out_last, out_error
);
  localparam integer AW=(MAX_LEN<2)?1:$clog2(MAX_LEN);
  localparam integer CW=(MAX_LEN<2)?1:$clog2(MAX_LEN+1);
  localparam integer SW=25+$clog2(MAX_LEN);
  typedef enum logic [2:0] {LOAD, PREPARE, EXPONENTS,
                           RECIP_START, RECIP_WAIT, EMIT} state_t;
  state_t state;
  // Same synchronous RAM holds scores/masks, then exponentials.
  // Never reset the array: this permits block-RAM inference.
  
  logic read_en, write_en, read_valid, read_last;
  logic [AW-1:0] read_addr, write_addr;
  logic [24:0] read_data, write_data;
  logic [CW-1:0] load_count, row_len, read_count, recv_count;
  logic signed [15:0] maximum;
  logic signed [16:0] wide_difference;
  logic any_active, protocol_error, emit_ce;
  logic [SW-1:0] sum_q24;
  logic [24:0] reciprocal, exp_value;
  logic [49:0] probability_product;
  logic exp_valid, exp_ready, recip_done, recip_busy;

  assign in_ready=(state==LOAD) && !rst;
  assign emit_ce=!out_valid || out_ready;
  assign out_error=protocol_error || !any_active;
  assign probability_product=read_data * reciprocal;

  always_comb begin
    read_en=0; write_en=0;
    read_addr=read_count[AW-1:0]; write_addr='0; write_data='0;
    if (!rst) begin
      if (state==LOAD && in_valid && in_ready) begin
        write_en=1; write_addr=load_count[AW-1:0];
        write_data={8'b0,in_mask,in_score};
      end
      if (state==EXPONENTS) begin
        // exp_ready is always high here: its output never stalls.
        read_en=(read_count<row_len);
        if (exp_valid) begin
          write_en=1; write_addr=recv_count[AW-1:0]; write_data=exp_value;
        end
      end
      if (state==EMIT && emit_ce) read_en=(read_count<row_len);
    end
    wide_difference='0;
    if (state==EXPONENTS && read_valid && !read_data[16])
      wide_difference=$signed({maximum[15],maximum}) -
                      $signed({read_data[15],read_data[15:0]});
  end

  // Separate clocked processes infer simple dual-port block RAM in Vivado.
  

  

  exp_approx #(.MODE(MODE)) exp_unit(
    .clk(clk),.rst(rst),.in_valid(read_valid && state==EXPONENTS),
    .in_ready(exp_ready),.in_difference(wide_difference[15:0]),
    .in_mask(read_data[16]),.out_valid(exp_valid),
    .out_ready(state==EXPONENTS),.out_value(exp_value)
  );
  reciprocal_q24 #(.DEN_W(SW)) reciprocal_unit(
    .clk(clk),.rst(rst),.start(state==RECIP_START),.denominator(sum_q24),
    .busy(recip_busy),.done(recip_done),.reciprocal(reciprocal)
  );

  always_ff @(posedge clk) begin
    if (rst) begin
      state<=LOAD; load_count<=0; row_len<=0; read_count<=0; recv_count<=0;
      maximum<=16'sh8000; any_active<=0; protocol_error<=0; sum_q24<=0;
      read_valid<=0; read_last<=0;
      out_valid<=0; out_last<=0; out_probability<=0;
    end else begin
      case (state)
        LOAD: begin
          read_valid<=0; out_valid<=0;
          if (in_valid && in_ready) begin
            if (!in_mask) begin
              any_active<=1;
              if (!any_active || in_score>maximum) maximum<=in_score;
            end
            if (in_last || load_count==MAX_LEN-1) begin
              row_len<=load_count+1'b1; protocol_error<=!in_last; state<=PREPARE;
            end else load_count<=load_count+1'b1;
          end
        end
        PREPARE: begin
          read_count<=0; recv_count<=0; sum_q24<=0; read_valid<=0;
          state<=EXPONENTS;
        end
        EXPONENTS: begin
          read_valid<=read_en;
          if (read_en) read_count<=read_count+1'b1;
          if (exp_valid) begin
            sum_q24<=sum_q24+exp_value; recv_count<=recv_count+1'b1;
            if (recv_count==row_len-1'b1) begin
              state<=RECIP_START; read_valid<=0;
            end
          end
        end
        RECIP_START: state<=RECIP_WAIT;
        RECIP_WAIT: if (recip_done) begin
          read_count<=0; read_valid<=0; state<=EMIT;
        end
        EMIT: begin
          if (emit_ce) begin
            read_valid<=read_en;
            if (read_en) begin
              read_count<=read_count+1'b1;
              read_last<=(read_count==row_len-1'b1);
            end
            out_valid<=read_valid;
            if (read_valid) begin
              out_probability<=probability_product[48:24];
              out_last<=read_last;
            end
          end
          if (out_valid && out_ready && out_last) begin
            state<=LOAD; load_count<=0; maximum<=16'sh8000;
            any_active<=0; protocol_error<=0; read_valid<=0; out_valid<=0;
          end
        end
        default: state<=LOAD;
      endcase
    end
  end


  // Shared score/exponential buffer with one-cycle read latency.
  xpm_memory_sdpram #(
    .ADDR_WIDTH_A       (AW),
    .ADDR_WIDTH_B       (AW),
    .BYTE_WRITE_WIDTH_A (25),
    .CLOCKING_MODE      ("common_clock"),
    .ECC_MODE           ("no_ecc"),
    .MEMORY_INIT_FILE   ("none"),
    .MEMORY_INIT_PARAM  ("0"),
    .MEMORY_PRIMITIVE   ("block"),
    .MEMORY_SIZE        (MAX_LEN * 25),
    .READ_DATA_WIDTH_B  (25),
    .READ_LATENCY_B     (1),
    .READ_RESET_VALUE_B ("0"),
    .RST_MODE_B         ("SYNC"),
    .SIM_ASSERT_CHK     (1),
    .USE_MEM_INIT       (0),
    .WAKEUP_TIME        ("disable_sleep"),
    .WRITE_DATA_WIDTH_A (25),
    .WRITE_MODE_B       ("no_change")
  ) row_memory_xpm (
    .clka           (clk),
    .clkb           (clk),
    .ena            (write_en),
    .wea            (write_en),
    .addra          (write_addr),
    .dina           (write_data),
    .enb            (read_en),
    .addrb          (read_addr),
    .doutb          (read_data),
    .regceb         (1'b1),
    .rstb           (rst),
    .sleep          (1'b0),
    .injectsbiterra (1'b0),
    .injectdbiterra (1'b0),
    .sbiterrb       (),
    .dbiterrb       ()
  );

endmodule
