`timescale 1ns/1ps
`include "defines.svh"

module proc_engine #(
  parameter   COLS                = `COLS                ,
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
              W_BPT                = `W_BPT              ,
              BITS_COLS           = $clog2(COLS) 
)(
  input  logic clk, resetn,

  output logic [COLS-1:0] s_ready,
  input  logic [COLS-1:0] s_valid, s_last,
  input  logic [ROWS-1:0][X_BITS-1:0] s_data_pixels,
  input  logic [COLS-1:0][K_BITS-1:0] s_data_weights,                                                                        
  input  tuser_st [COLS-1:0] s_user,
  input  logic pixels_m_valid,
  output logic [COLS-1:0] pixels_m_valid_pipe,

  //input  logic m_ready,
  //output logic m_valid, m_last,
  //output logic [COLS-1:0][ROWS-1:0][Y_BITS-1:0] m_data,
  //output tuser_st m_user,
 
  input  logic m_ready,
  output logic [ROWS -1:0][WORD_WIDTH  -1:0] m_data,
  output logic m_valid, m_last, m_last_pkt,
  output logic [W_BPT-1:0] m_bytes_per_transfer
);

  logic [COLS-1:1] pixels_m_valid_pipe_reg; // fix verilator compile - does not allow variable to be both continuous and procedurally assigned.
  logic [COLS-1:0] en;
  logic force_en, force_en_reset;
  logic [COLS-1:0] acc_m_valid_next, acc_m_valid;
  logic [COLS-1:0] mac_freeze;
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

  logic [COLS-1:0] en_outshift, sel_outshift, outshift_flag;
  logic shift_out_ready_last_col_prev;
  logic [BITS_COLS-1:0] count_outshift;
  logic cnt_en;

  logic [COLS-1:0] s_axis_tvalid;

  genvar k2, c_1;
  genvar co;
  generate
  for (k2=0; k2 <= KW_MAX/2; k2++) begin : lut_k
    localparam k = k2*2+1;
    for (c_1=0; c_1 <  COLS; c_1++) begin : lut_c
      localparam c = c_1 + 1;
      assign lut_valid      [k2][c_1] = (c % k == 0);
      assign lut_valid_last [k2][c_1] = ((c % k > k2) || (c % k == 0)) && (c <= (COLS/k)*k);
      assign lut_last       [k2][c_1] = (c == k);
      assign lut_last_pkt   [k2][c_1] = (c == k2+1);
    end
    assign lut_bpt [0][k2] = (ROWS * (COLS/k) * 1      * Y_OUT_BITS) / 8;
    assign lut_bpt [1][k2] = (ROWS * (COLS/k) * (k2+1) * Y_OUT_BITS) / 8;
  end
  for (c_1=0; c_1 < COLS; c_1++) begin : val_mask
    assign valid_mask[c_1] = !acc_m_user[c_1].is_w_first_kw2 && !acc_m_user[c_1].is_config;
    assign s_valid_cols_sel[c_1] = acc_m_user[c_1].is_w_last ? lut_valid_last[acc_m_user[c_1].kw2][c_1] : lut_valid[acc_m_user[c_1].kw2][c_1];
    assign s_last_cols_sel[c_1]  = acc_m_user[c_1].is_w_last ? lut_last_pkt  [acc_m_user[c_1].kw2][c_1] : lut_last [acc_m_user[c_1].kw2][c_1];
  end
  endgenerate
  
  assign s_ready = clken_mul;

  // pixel_valid_pipe[i] indicates whether column i has a valid pixel or not. 
  assign pixels_m_valid_pipe[0] = pixels_m_valid;

generate
  genvar i;
  for (i=0; i<COLS; i++) begin : pixel_valid_pipe
    // if prev column is not ready, current column pixel valid will either i) be set to 0 or ii) hold its current value, depending on s_ready[i].
    if (i>0) begin
      always_ff@(posedge clk) begin 
        pixels_m_valid_pipe_reg[i] <= (s_ready[i-1]) ? pixels_m_valid_pipe[i-1] : (s_ready[i]) ? 1'b0 : pixels_m_valid_pipe[i];
      end
    end
    //assign weights_m_ready[i] = s_ready[i]   && (pixels_m_valid_pipe[i] || s_user[i].is_config);
    // s_valid is valid from weights_rotator.  it is ANDed with pixels_valid to get the combined valid signal to send to the MAC.
    assign s_axis_tvalid[i]   = s_valid[i] && (pixels_m_valid_pipe[i] || s_user[i].is_config);
    if (i>0) assign pixels_m_valid_pipe[i] = pixels_m_valid_pipe_reg[i];
end
endgenerate

  generate
    genvar r,c,kw2,d;
    for(c=0; c<COLS; c++) begin : selshift
      n_delay #(.N(DELAY_MUL), .W(TUSER_WIDTH+2)) MUL_CONTROL (.c(clk), .rng(resetn), .rnl(1'b1), .e(clken_mul[c]), .i({s_axis_tvalid[c], s_last[c], s_user[c]}), .o ({mul_m_valid[c], mul_m_last[c], mul_m_user[c]}));
      
      assign sel_shift_next[c] = mul_m_valid[c] && mul_m_user[c].is_cin_last && (mul_m_user[c].kw2 != 0);

      always_ff @(posedge clk `OR_NEGEDGE(resetn))
        if (!resetn) sel_shift[c] <= 0;
        else if (en[c]) sel_shift[c] <= sel_shift_next[c];
      //assign sel_shift[c] = sel_shift_next[c];

      assign clken_mul[c] = en[c]  && !sel_shift[c];
    end        

    for (c=0; c < COLS; c++) begin: Cg

      // Lookup table
      for (kw2=0; kw2 <= KW_MAX/2; kw2++) begin : lutsumst
        assign lut_sum_start[kw2][c] = c % (kw2*2+1) == 0; // c % 3 < 1 : 0,1
      end
      
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
          end
          else if (clken_mul[c]) begin
            //{pixels_reg[0], weights_reg} <= {s_data_pixels[r], s_data_weights[c]}; // move this to outside the for loop?
            weights_reg <= s_data_weights[c];  
          end
          
          if(c>0) begin
            always_ff @ (posedge clk `OR_NEGEDGE(resetn))
            if (!resetn) begin
              pixels_reg[c] <= '0; 
            end
            else if (clken_mul[c]) begin
              pixels_reg[c] <= pixels_reg[c-1];  
            end
          end
        // Multiplier
        wire [M_BITS-1:0] mul_comb = $signed(pixels_reg[c]) * $signed(weights_reg);

        n_delay #(.N(DELAY_MUL-1), .W(M_BITS)) MUL_PIPE (.c(clk), .rng(resetn), .rnl(1'b1), .e(clken_mul[c]), .i(mul_comb), .o (mul_m_data[c][r]));
        
        // changed shift_data to FF instead of wire, so that it has previous cycle data. 
        // shift_data[i] is loaded with acc_m_data[i-1] when acc_m_valid[i-1] is high. 
        // This is because the column i will get sel_shift one cycle after column i-1.
        if(c == 0) begin
          always_ff @ (posedge clk `OR_NEGEDGE(resetn)) begin
            if(!resetn) shift_data [c][r] <= '0;
            else begin
              shift_data [c][r] <= '0;
            end
          end
        end
        else begin // c > 0
          always_ff @ (posedge clk `OR_NEGEDGE(resetn)) begin
            if(!resetn) shift_data [c][r] <= '0;
            else begin
              if (acc_m_valid[c-1]) shift_data [c][r] <= acc_m_data [c-1][r];
            end
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
    
    // counter value is used as pointer to which is the last column to be shifted out
    //counter #(.W(BITS_COLS)) C_OUTSHIFT (.clk(clk), .rstn_g(1'b1), .rst_l(~resetn), .en(cnt_en), .max_in(COLS-1), .last_clk(), .last(), .first(), .count(count_outshift));
    
    //assign cnt_en = m_ready & ~shift_out_ready[COLS-1] & (outshift_flag[COLS-1-count_outshift] == 1);

    always_ff@(posedge clk `OR_NEGEDGE(resetn)) begin
        if (!resetn) begin 
          outshift_flag <= 0;
        end
        else begin
          shift_out_ready_last_col_prev <= shift_out_ready[COLS-1];

          if(shift_out_ready_last_col_prev & ~shift_out_ready[COLS-1]) begin // when last col of out shifter gets data from acc, it is ready to start shifting.
            outshift_flag <= '1;
          end
          else begin
          //else if ((count_outshift == (COLS-1)-co) && en_outshift[co]) begin
          if (m_ready && ~shift_out_ready[COLS-1]) outshift_flag <= (outshift_flag << 1);
          end
        end
      end
    
    for (co=0; co<COLS; co=co+1) begin : Cs

      // outshift_flag is used to decide whether the column should be shifted out or not
      // outshift_flag is set to 1 for all cols when the last col of out shifter gets valid data
      // it is set to 0 when shift_out_ready[co] = 0 i.e. the data from that col has been shifted out.
      // always_ff@(posedge clk `OR_NEGEDGE(resetn)) begin
      //   if (!resetn) begin 
      //     outshift_flag[co] <= 0;
      //   end
      //   else begin
      //     if (co == COLS-1) shift_out_ready_last_col_prev <= shift_out_ready[COLS-1];

      //     if(shift_out_ready_last_col_prev & ~shift_out_ready[COLS-1]) begin // when last col of out shifter gets data from acc, it is ready to start shifting.
      //       outshift_flag[co] <= 1;
      //     end
      //     else begin
      //     //else if ((count_outshift == (COLS-1)-co) && en_outshift[co]) begin
      //       if (co < COLS-1) begin
      //         if (shift_out_ready[co]) begin
      //           outshift_flag[co] <= 0;
      //         end
      //       end
      //       else if (shift_out_ready[co]) outshift_flag[co] <= 0; // for last column

      //     end
      //   end
      // end
      
      // en_outshift enables the output shifter register. The first condition is to shift data out,
      // and the second condition is for the accumulator to write to the output shifter.
      assign en_outshift[co] = (m_ready & outshift_flag[co]) | ~sel_outshift[co];
      
      // sel_outshift = 1 -> data comes from prev col, 0 -> data comes from accumulator.
      if (co < COLS-1)
        assign sel_outshift[co] = ~(acc_m_valid[co] & valid_mask[co] & shift_out_ready[co] & shift_out_ready[co+1]);
      else
        assign sel_outshift[co] = ~(acc_m_valid[co] & valid_mask[co] & shift_out_ready[co]);

      if (co>0) begin
        always_ff@(posedge clk `OR_NEGEDGE(resetn)) begin
          if (!resetn) begin 
            shift_out_ready[co] <= '1;
            // m_bytes_per_transfer <= 0;
            {shift_data_out[co], shift_valid[co], shift_last[co], shift_last_pkt[co]} <= '0;
          end else  
            if(en_outshift[co]) begin
              shift_data_out[co]  <= (sel_outshift[co]) ? shift_data_out[co-1]: acc_m_data[co] ;
              shift_last_pkt[co]  <= (sel_outshift[co]) ? shift_last_pkt[co-1] : {acc_m_last[co]} & lut_last_pkt[acc_m_user[co].kw2][co];
              shift_valid[co]     <= (sel_outshift[co]) ? shift_valid[co-1] : s_valid_cols_sel[co] & valid_mask[co];
              shift_last[co]      <= (sel_outshift[co]) ? shift_last[co-1] :s_last_cols_sel[co];
              shift_out_ready[co] <= (sel_outshift[co]) ? shift_out_ready[co-1] : 1'b0;
              
              // if(co == COLS-1) begin
              //   if(~sel_outshift[co]) m_bytes_per_transfer <= lut_bpt[acc_m_user[COLS-1].is_w_last][acc_m_user[COLS-1].kw2];
              // end
            end
        end
      end
      else begin //COL 0
        always_ff@(posedge clk `OR_NEGEDGE(resetn)) begin
          if (!resetn) begin 
            shift_out_ready[co] <= '1;
            //m_bytes_per_transfer <= 0;
            {shift_data_out[co], shift_valid[co], shift_last[co], shift_last_pkt[co]} <= '0;
          end else  
            if(en_outshift[co]) begin
                shift_data_out[co]  <= (sel_outshift[co]) ? shift_data_out[co]: acc_m_data[co] ;
                shift_last_pkt[co]  <= (sel_outshift[co]) ? shift_last_pkt[co] : {acc_m_last[co]} & lut_last_pkt[acc_m_user[co].kw2][co];
                shift_valid[co]     <= (sel_outshift[co]) ? shift_valid[co] : s_valid_cols_sel[co] & valid_mask[co];
                shift_last[co]      <= (sel_outshift[co]) ? shift_last[co] :s_last_cols_sel[co];
                shift_out_ready[co] <= (sel_outshift[co]) ? 1'b1 : 1'b0; // shift_out_ready[0] becomes 1 when data is shifted out, becomes 0 if it is loaded with acculumator data.
            end
        end
      end
    end

    always_ff@(posedge clk `OR_NEGEDGE(resetn)) begin
      if (!resetn) begin
          m_bytes_per_transfer <= 0;
      end
      else begin
        if (en_outshift[COLS-1] && ~sel_outshift[COLS-1]) m_bytes_per_transfer <= lut_bpt[acc_m_user[COLS-1].is_w_last][acc_m_user[COLS-1].kw2];
      end
    end

    assign m_data   = shift_data_out [COLS-1];
    assign m_valid  = shift_valid[COLS-1] & outshift_flag[COLS-1];
    assign m_last   = shift_last [COLS-1];
    assign m_last_pkt = shift_last_pkt [COLS-1];

    // -------------- OUTPUT SHIFTER ----------------      

    //assign en_mac = &(~acc_m_valid | shift_out_ready);
    //assign en[0] = ~acc_m_valid[0] | shift_out_ready[0];
    for(c=0; c<COLS; c++) begin : C
      if(c<COLS-1) begin
        // If current column and next column output shifter regs both have valid data, and accumulator has valid data column gets frozen 
        assign mac_freeze[c] = (acc_m_valid[c] & ~(shift_out_ready[c] & shift_out_ready[c+1]));
        //assign en[c] = (~acc_m_valid[c] | shift_out_ready[c] & shift_out_ready[c+1]);
        always_ff @(posedge clk `OR_NEGEDGE(resetn))
          if (!resetn) begin            
            acc_m_valid[c] <= '0;
          end
          else begin
            if (en[c])            acc_m_valid[c] <= acc_m_valid_next[c];
            else if (~en[c] & acc_m_valid[c] & shift_out_ready[c] & shift_out_ready[c+1]) acc_m_valid[c] <= acc_m_valid_next[c]; // if handshake happens when en is 0, acc_m_valid should become low    
          end
      end
      else begin // Final Column
        assign mac_freeze[c] = (acc_m_valid[c] & ~shift_out_ready[c]);
        //assign en[c] = (~acc_m_valid[c] | shift_out_ready[c]);
        always_ff @(posedge clk `OR_NEGEDGE(resetn))
          if (!resetn) begin            
            acc_m_valid[c] <= '0;
          end
          else begin
            if (en[c])            acc_m_valid[c] <= acc_m_valid_next[c];
            else if (~en[c] & acc_m_valid[c] & shift_out_ready[c]) acc_m_valid[c] <= acc_m_valid_next[c]; // if handshake happens when en is 0, acc_m_valid should become low
          end
      end

      //assign en[c] = &(~mac_freeze);
      assign en[c] = &(~mac_freeze[COLS-1:c]);  // all cols to the left of frozen column should freeze.

      assign acc_m_valid_next[c] = !sel_shift[c] & mul_m_valid[c] & (mul_m_user[c].is_config | mul_m_user[c].is_cin_last);

      always_ff @(posedge clk `OR_NEGEDGE(resetn))
        if (!resetn)            {acc_m_user[c], acc_m_last[c]} <= 0;
        else begin
          if (en[c] & mul_m_valid[c]) acc_m_user[c]                <= mul_m_user[c];
          if (en[c])               acc_m_last[c] <= mul_m_last[c];
        end
    
    end

  endgenerate
endmodule
