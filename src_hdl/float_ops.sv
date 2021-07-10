
package float_ops;

  // synthesis translate_off

  virtual class float_downsize #(parameter EXP_IN, FRA_IN, EXP_OUT, FRA_OUT);
    static function logic [EXP_OUT+FRA_OUT:0] downsize (input logic [EXP_IN+FRA_IN:0] float_in);
      /*
        Downsize
        * eg: Float32 -> Float16
            - EXP_IN  : 8
            - FRA_IN  : 23
            - EXP_OUT : 5
            - FRA_OUT : 10
        * Mantissa is rounded to avoid error
      */
      logic sign;
      logic [EXP_IN -1:0] exp_in;
      logic [FRA_IN -1:0] fra_in;
      logic [EXP_OUT-1:0] exp_out;
      logic [FRA_OUT  :0] fra_out_extra, fra_out_round;
      logic [FRA_OUT-1:0] fra_out;
      
      {sign, exp_in, fra_in} = float_in;
      exp_out = exp_in - (2**(EXP_IN-1)-2**(EXP_OUT-1));
      fra_out_extra = fra_in >> (FRA_IN-FRA_OUT-1);
      // fra_out_round = sign ? fra_out_extra - fra_in[FRA_IN-FRA_OUT]: fra_out_extra + fra_in[FRA_IN-FRA_OUT];
      // fra_out = fra_out_round >> 1;
      fra_out = fra_in >> (FRA_IN-FRA_OUT);
      return {sign, exp_out, fra_out};
    endfunction
  endclass

  virtual class float_upsize #(parameter EXP_IN, FRA_IN, EXP_OUT, FRA_OUT);  
    static function logic [EXP_OUT+FRA_OUT:0] upsize (input logic [EXP_IN+FRA_IN:0] float_in);
      /*
        Upsize
        * eg: Float32 -> Float16
            - EXP_IN  : 5
            - FRA_IN  : 10
            - EXP_OUT : 8
            - FRA_OUT : 23
        * No need to round
      */
      logic sign;
      logic [EXP_IN -1:0] exp_in;
      logic [FRA_IN -1:0] fra_in;
      logic [EXP_OUT-1:0] exp_out;
      logic [FRA_OUT-1:0] fra_out;
      
      {sign, exp_in, fra_in} = float_in;
      exp_out = exp_in + (2**(EXP_OUT-1)-2**(EXP_IN-1));
      fra_out = fra_in << (FRA_OUT-FRA_IN);
      return {sign, exp_out, fra_out};
    endfunction
  endclass

  // synthesis translate_on
endpackage
