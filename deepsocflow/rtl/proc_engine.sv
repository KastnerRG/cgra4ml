`timescale 1ns/1ps
`include "defines.svh"

module proc_engine #(
  localparam  COLS                = `COLS                ,
              ROWS                = `ROWS                ,
              X_BITS              = `X_BITS              ,
              K_BITS              = `K_BITS              ,
              Y_BITS              = `Y_BITS              ,
              DELAY_MUL           = `DELAY_MUL           ,
              KW_MAX              = `KW_MAX              ,
              TUSER_WIDTH         = `TUSER_WIDTH         ,
              M_BITS              = X_BITS + K_BITS      ,
              WORD_WIDTH           = `Y_BITS             ,
              Y_OUT_BITS           = `Y_OUT_BITS         ,
              W_BPT                = `W_BPT      
)(
  input  logic clk, resetn,

  output logic [COLS-1:0] s_ready,
  input  logic [COLS-1:0] s_valid, s_last,
  input  logic [ROWS-1:0][X_BITS-1:0] s_data_pixels,
  input  logic [COLS-1:0][K_BITS-1:0] s_data_weights,                                                                        
  input  tuser_st [COLS-1:0] s_user,

  //input  logic m_ready,
  //output logic m_valid, m_last,
  //output logic [COLS-1:0][ROWS-1:0][Y_BITS-1:0] m_data,
  //output tuser_st m_user,
 
  input  logic m_ready,
  output logic [ROWS -1:0][WORD_WIDTH  -1:0] m_data,
  output logic m_valid, m_last, m_last_pkt,
  output logic [W_BPT-1:0] m_bytes_per_transfer
);

  logic [COLS-1:0] en;
  logic force_en, force_en_reset;
  logic [COLS-1:0] acc_m_valid_next, acc_m_valid;
  //logic en;
  logic [COLS-1:0] clken_mul;
  logic [COLS-1:0] sel_shift_next, sel_shift, mul_m_valid, mul_m_last;
  //logic acc_m_valid_next, acc_m_valid;
  logic [COLS-1:0] acc_m_last;
  tuser_st [COLS-1:0] mul_m_user;
  tuser_st [COLS-1:0] acc_m_user;
  logic [COLS-1:0] clken_acc, bypass_sum, bypass_sum_next, bypass, acc_m_sum_start, acc_s_valid;
  logic [COLS-1:0] lut_sum_start [KW_MAX/2:0];
  logic [COLS-1:0][ROWS-1:0][M_BITS -1:0] mul_m_data;
  logic [COLS-1:0][ROWS-1:0][Y_BITS -1:0] shift_data, acc_m_data;

  logic [COLS-1:0] shift_out_ready;
  
  logic [COLS-1:0][ROWS -1:0][WORD_WIDTH-1:0] shift_data_out;
  logic [1:0][KW_MAX/2:0][W_BPT-1:0] lut_bpt;
  logic [KW_MAX/2:0][COLS-1:0] lut_valid, lut_valid_last, lut_last_pkt, lut_last; 
  logic [COLS-1:0] shift_last, shift_last_pkt, shift_valid;

  wire [COLS-1:0] valid_mask; 
  wire [COLS-1:0] s_valid_cols_sel; 
  wire [COLS-1:0] s_last_cols_sel;  

  genvar k2, c_1;
  integer co;
  for (k2=0; k2 <= KW_MAX/2; k2++) begin
    localparam k = k2*2+1;
    for (c_1=0; c_1 <  COLS; c_1++) begin
      localparam c = c_1 + 1;
      assign lut_valid      [k2][c_1] = (c % k == 0);
      assign lut_valid_last [k2][c_1] = ((c % k > k2) || (c % k == 0)) && (c <= (COLS/k)*k);
      assign lut_last       [k2][c_1] = (c == k);
      assign lut_last_pkt   [k2][c_1] = (c == k2+1);
    end
    assign lut_bpt [0][k2] = (ROWS * (COLS/k) * 1      * Y_OUT_BITS) / 8;
    assign lut_bpt [1][k2] = (ROWS * (COLS/k) * (k2+1) * Y_OUT_BITS) / 8;
  end
  for (c_1=0; c_1 < COLS; c_1++) begin
    assign valid_mask[c_1] = !acc_m_user[c_1].is_w_first_kw2 && !acc_m_user[c_1].is_config;
    assign s_valid_cols_sel[c_1] = acc_m_user[c_1].is_w_last ? lut_valid_last[acc_m_user[c_1].kw2][c_1] : lut_valid[acc_m_user[c_1].kw2][c_1];
    assign s_last_cols_sel[c_1]  = acc_m_user[c_1].is_w_last ? lut_last_pkt  [acc_m_user[c_1].kw2][c_1] : lut_last [acc_m_user[c_1].kw2][c_1];
  end
  //assign valid_mask = !acc_m_user[0].is_w_first_kw2 && !acc_m_user[0].is_config;
  //assign s_valid_cols_sel = acc_m_user[COLS-1].is_w_last ? lut_valid_last[acc_m_user[COLS-1].kw2] : lut_valid[acc_m_user[COLS-1].kw2];
  //assign s_last_cols_sel  = acc_m_user[COLS-1].is_w_last ? lut_last_pkt  [acc_m_user[COLS-1].kw2] : lut_last [acc_m_user[COLS-1].kw2];

  logic [$clog2(COLS+1)-1:0] counter;
  enum {IDLE, SHIFT} state;

  assign s_ready = clken_mul;

  generate
    genvar r,c,kw2,d;
    for(c=0; c<COLS; c++) begin
      n_delay #(.N(DELAY_MUL), .W(TUSER_WIDTH+2)) MUL_CONTROL (.c(clk), .rng(resetn), .rnl(1'b1), .e(clken_mul[c]), .i({s_valid[c], s_last[c], s_user[c]}), .o ({mul_m_valid[c], mul_m_last[c], mul_m_user[c]}));
      
      assign sel_shift_next[c] = mul_m_valid[c] && mul_m_user[c].is_cin_last && (mul_m_user[c].kw2 != 0);

      always_ff @(posedge clk `OR_NEGEDGE(resetn))
        if (!resetn) sel_shift[c] <= 0;
        else if (en[c]) sel_shift[c] <= sel_shift_next[c];
      //assign sel_shift[c] = sel_shift_next[c];

      assign clken_mul[c] = en[c]  && !sel_shift[c];
    end        

    for (c=0; c < COLS; c++) begin: Cg

      // Lookup table
      for (kw2=0; kw2 <= KW_MAX/2; kw2++)
        assign lut_sum_start[kw2][c] = c % (kw2*2+1) == 0; // c % 3 < 1 : 0,1
      
      assign acc_m_sum_start [c] = lut_sum_start[acc_m_user[0].kw2][c];
      assign acc_s_valid     [c] = sel_shift[c] ? ~acc_m_sum_start [c] : mul_m_valid[c];
      assign clken_acc       [c] = en[c]    && acc_s_valid [c];

      assign bypass_sum_next [c] = mul_m_user[c].is_cin_last || mul_m_user[c].is_config;

      always_ff @(posedge clk `OR_NEGEDGE(resetn))
        if (!resetn)            bypass_sum [c] <= 0;
        else if (clken_acc [c]) bypass_sum [c] <= bypass_sum_next [c];

      assign bypass    [c] = bypass_sum [c] || mul_m_user[c].is_w_first_clk; // clears all partial sums for every first col

    end

    // PE ARRAY: ROWS * COLS
    for (r=0; r < ROWS ; r++) begin: Rg
      logic [COLS-1:0][X_BITS-1:0] pixels_reg;
      
      always_ff @ (posedge clk `OR_NEGEDGE(resetn)) begin
        if(!resetn) pixels_reg[0] <= '0;
        else if (clken_mul[0]) pixels_reg[0] <= s_data_pixels[r];
      end

      for (c=0; c < COLS   ; c++) begin: Cg
        // --------------- PROCESSING ELEMENT ------------------

        // Pipeline DSP input
        //logic [X_BITS-1:0] pixels_reg; changed to pipeline
        logic [K_BITS-1:0] weights_reg;
        always_ff @ (posedge clk `OR_NEGEDGE(resetn))
          if (!resetn) begin        
            weights_reg <= '0;
            if (c>0) pixels_reg[c] <= '0; 
          end
          else if (clken_mul[c]) begin
            //{pixels_reg[0], weights_reg} <= {s_data_pixels[r], s_data_weights[c]}; // move this to outside the for loop?
            weights_reg <= s_data_weights[c];
            if (c>0) pixels_reg[c] <= pixels_reg[c-1];  
          end
        // Multiplier
        wire [M_BITS-1:0] mul_comb = $signed(pixels_reg[c]) * $signed(weights_reg);

        n_delay #(.N(DELAY_MUL-1), .W(M_BITS)) MUL_PIPE (.c(clk), .rng(resetn), .rnl(1'b1), .e(clken_mul[c]), .i(mul_comb), .o (mul_m_data[c][r]));
        
        //TODO: change to FF so that it has previous cycle data?
        always_ff @ (posedge clk `OR_NEGEDGE(resetn)) begin
          if(!resetn) shift_data [c][r] <= '0;
          else begin
            if(c == 0) shift_data [c][r] <= '0;
            else shift_data [c][r] <= acc_m_data [c-1][r];
          end
        end
        //if (c == 0) assign shift_data [c][r] = '0;
        //else        assign shift_data [c][r] = acc_m_data [c-1][r];

        // Two muxes
        wire signed [Y_BITS -1:0] add_in_1 = sel_shift[c] ? shift_data [c][r]: Y_BITS'($signed(mul_m_data[c][r]));
        wire signed [Y_BITS -1:0] add_in_2 = bypass[c] ? 0                : acc_m_data [c][r];

        // Accumulator
        always_ff @(posedge clk `OR_NEGEDGE(resetn))
          if (!resetn)           acc_m_data [c][r] <= '0;
          else if (clken_acc[c]) acc_m_data [c][r] <= add_in_1 + add_in_2;
        
        // --------------- PROCESSING ELEMENT ------------------
      end 
    end
    // -------------- OUTPUT SHIFTER ----------------
    always_ff@(posedge clk `OR_NEGEDGE(resetn)) begin
      if (!resetn) begin 
        state   <= IDLE;
        shift_out_ready <= '1;
        m_bytes_per_transfer <= 0;
        {shift_data_out, shift_valid, shift_last, shift_last_pkt} <= '0;
      end else case (state)
        IDLE  :  begin if (!shift_out_ready) begin // Final Column ready to be shifted out
                  state   <= SHIFT;
                  //hift_out_ready <= 0;
                  m_bytes_per_transfer <= lut_bpt[acc_m_user[COLS-1].is_w_last][acc_m_user[COLS-1].kw2];
                  //shift_valid <= s_valid_cols_sel & {COLS{valid_mask}};
                  //shift_last  <= s_last_cols_sel;
                  //shift_last_pkt <= {COLS{acc_m_last[0]}} & lut_last_pkt[acc_m_user[0].kw2];
                end
                else begin
                  for (co=0; co<COLS; co=co+1) begin : Cs
                    if(acc_m_valid[co] && valid_mask[co] && shift_out_ready[co]) begin
                      shift_data_out[co]  <= acc_m_data[co];
                      shift_out_ready[co] <= 0;
                      shift_last_pkt[co] <= {acc_m_last[co]} & lut_last_pkt[acc_m_user[co].kw2][co];
                      shift_valid[co] <= s_valid_cols_sel[co] & valid_mask[co];
                      shift_last[co]  <= s_last_cols_sel[co];
                      
                    end
                  end
                end        
              end
                  
        SHIFT : if (m_ready) begin

                  shift_data_out  <= shift_data_out  << (ROWS * WORD_WIDTH);
                  shift_valid <= shift_valid << 1;
                  shift_last  <= shift_last  << 1;
                  shift_last_pkt  <= shift_last_pkt  << 1;

                  if (counter == 1) begin
                    state   <= IDLE;
                    shift_out_ready <= '1;
                  end
                end
      endcase
    end

    always_ff @(posedge clk `OR_NEGEDGE(resetn))
    if      (!resetn)                counter <= COLS;
    else if (state==SHIFT && m_ready) counter <= counter == 1 ? COLS : counter - 1;

    assign m_data   = shift_data_out [COLS-1];
    assign m_valid  = shift_valid[COLS-1];
    assign m_last   = shift_last [COLS-1];
    assign m_last_pkt = shift_last_pkt [COLS-1];

    // -------------- OUTPUT SHIFTER ----------------      

    //assign en_mac = &(~acc_m_valid | shift_out_ready);
    assign en[0] = ~acc_m_valid[0] | shift_out_ready[0];
    for(c=0; c<COLS; c++) begin
      //assign en[c] = ~acc_m_valid[c] | shift_out_ready[c];
      assign acc_m_valid_next[c] = !sel_shift[c] & mul_m_valid[c] & (mul_m_user[c].is_config | mul_m_user[c].is_cin_last);
      
      always_ff @(posedge clk `OR_NEGEDGE(resetn))
      if (!resetn) begin            
        acc_m_valid[c] <= '0;
      end
      else begin
        if (en[c])            acc_m_valid[c] <= acc_m_valid_next[c];
        if (c > 0)            en[c] <= en[c-1];
      end

      always_ff @(posedge clk `OR_NEGEDGE(resetn))
        if (!resetn)            {acc_m_user, acc_m_last} <= '0;
        else begin
          if (en[c] & mul_m_valid[c]) acc_m_user[c]                <= mul_m_user[c];
          if (en[c])               acc_m_last[c] <= mul_m_last[c];
        end
    
    end

    // always_ff @(posedge clk `OR_NEGEDGE(resetn) `OR_NEGEDGE(~force_en_reset)) begin
    //   if (!resetn) force_en <= 0;
    //   else if (force_en_reset) force_en <= 1'b0;
    //   else if (m_ready & m_valid) force_en <= 1'b1;
    // end

    // always_ff @(posedge clk `OR_NEGEDGE(resetn)) begin
    //   if (!resetn) force_en_reset <= 0;
    //   else force_en_reset <= force_en;
    // end

    // Pipeline AXI-Stream signals with DELAY_ACC=1
    // always_ff @(posedge clk `OR_NEGEDGE(resetn))
    //   if (!resetn)            {acc_m_user, acc_m_last} <= '0;
    //   else begin
    //     if (en[0] & mul_m_valid[0]) acc_m_user                <= mul_m_user[0];
    //     if (en[0])               acc_m_last <= mul_m_last[0];
    //   end

    // AXI Stream
    //assign en = m_ready || !m_valid;

    //assign {m_data, m_valid, m_last, m_user} = {acc_m_data, &acc_m_valid, acc_m_last, acc_m_user};

  endgenerate
endmodule