`include "params.h"
package lrelu_beats;

  function integer calc_beats_b (
      input integer clr_i, 
      input integer  kw2, 
      input integer MEMBERS
    );
    
    automatic integer clr_kw, kw, WIDTH_Bi, WRITE_DEPTH;
    
    clr_kw  = clr_i*2 + 1;
    kw      = kw2  *2 + 1;

    WIDTH_Bi    = MEMBERS/clr_kw;
    WRITE_DEPTH = 2*(MEMBERS/kw);
    
    calc_beats_b  = `CEIL(WRITE_DEPTH, WIDTH_Bi);
  endfunction

  function integer calc_beats_max (
      input integer KW_MAX, 
      input integer MEMBERS 
    );
    automatic integer kw2, kw, clr_i, beats_b;
    calc_beats_max = 2; // max(A)

    for (kw2 = 0; kw2 <= KW_MAX/2; kw2++) begin
      kw = kw2*2 +1;
      for (clr_i = 0; clr_i <= kw2; clr_i++) begin
        beats_b = calc_beats_b(.clr_i(clr_i), .kw2(kw2), .MEMBERS(MEMBERS));
        calc_beats_max = beats_b > calc_beats_max ? beats_b : calc_beats_max;
      end
    end    
  endfunction

  function integer calc_beats_total (
      input integer  kw2, 
      input integer MEMBERS
    );
    automatic integer kw, clr_i, mtb;

    kw = kw2*2 + 1;
    calc_beats_total = 1 + `CEIL(2, kw);
    
    for (clr_i = 0; clr_i <= kw2; clr_i++)
      for (mtb = 0; mtb <= clr_i*2; mtb++)
        calc_beats_total += calc_beats_b(.clr_i(clr_i), .kw2(kw2), .MEMBERS(MEMBERS));

  endfunction

  function integer calc_beats_total_max (
      input integer KW_MAX, 
      input integer MEMBERS 
    );
    calc_beats_total_max = 2; // max(A)
    for (int kw2 = 0; kw2 <= KW_MAX      /2; kw2++) begin
      automatic integer beats_tot = calc_beats_total(.kw2(kw2), .MEMBERS(MEMBERS));
      calc_beats_total_max = beats_tot > calc_beats_total_max ? beats_tot : calc_beats_total_max;
    end
  endfunction
endpackage