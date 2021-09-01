/*//////////////////////////////////////////////////////////////////////////////////
Group : ABruTECH
Engineer: Abarajithan G.

Create Date: 21/07/2020
Design Name: Pad filter
Tool Versions: Vivado 2018.2
Description: Computes two masks that allow horizontal zero padding for
                convolutions where output image should have same size as input.
            * Maximum kernal width can be specified as a parameter and fixed in synthesis.
            * Any odd kernel less than max can be used
            * Lookup logic is created for every possible odd kernels less than max,
                independantly for datapaths, allowing back to back kernel change
            * kw_1 is taken from user_in. Hence tied to data.

            * For kw = 1: start, end, masks, left, right are all undefined (X) 

Revision:
Revision 0.01 - File Created
Additional Comments: 
            OPTIMIZATION
                - The whiteboard, excel sheet and previous commit (4f4cd) calculates kw2_wire-1,
                    indexing of end_col, packed dimension of lookup tables and equations
                    all use (r = kw2-1) based indexing.
                - To prevent the tool from synthesising a combinational adder to compute
                    kw2_wire-1, all indexing have been moved up by 1.
                - indexing of start, end registers begin at 1 and go upto KW2_MAX
                - For loops begin at 1 and go upto KW2_MAX
                - In equations, r (=kw2-1) has be replaced by kw2 (=r+1)

//////////////////////////////////////////////////////////////////////////////////*/

`include "params.v"

module pad_filter 
# (
    KW_MAX        ,
    MEMBERS       ,
    TUSER_WIDTH   ,
    I_IS_COLS_1_K2,
    I_IS_CONFIG   ,
    I_IS_CIN_LAST ,
    I_KW2 
)(
    aclk,
    aclken,
    aresetn,
    user_in,
    valid_in,
    
    mask_partial,
    mask_full,
    valid_masked_in,
    clr
);
    localparam KW2_MAX          = KW_MAX      /2; //R, 3->1, 5->2, 7->3
    localparam BITS_KW          = `BITS_KW;
    localparam BITS_KW2         = `BITS_KW2;

    input  logic                      aclk;
    input  logic                      aresetn;
    input  logic [MEMBERS - 1 : 0]    aclken, valid_in, valid_masked_in;
    output logic [MEMBERS - 1 : 1]    mask_partial;
    output logic [MEMBERS - 1 : 0]    mask_full;
    output logic [BITS_KW - 1 : 0]    clr          [MEMBERS - 1 : 0]; // 0-center, 1-center-left, 2-center-right, 3-left, 4-right
    input  logic [TUSER_WIDTH - 1: 0] user_in      [MEMBERS - 1 : 0];

    /*
    KW2_1

    * From user_in, hence tied to valid and last
    * Value: (kw/2 -1)
        - (7 x m) : 2
        - (5 x m) : 1
        - (3 x m) : 0
    * Acts as mux_sel for lookup logic
    */
    
    logic   [BITS_KW2-1 : 0] kw2_wire [MEMBERS-1 : 0];
    
    /*
    COL_START, COL_END Registers

    * One bit, KW2_MAX regs are there (packed dimension) for every KW_MAX datapath (unpacked dimension)
    * is_col_1_k2 from TUSER, which rises at col==(col-1-k/2) is passed through these
    * updated at the end of each cin: (acc_m_valid & cin_last & acc_clken)
    * OPTIMIZATION: 
        To avoid synthesis of a combinational added when calculating kw/2-1 for indexing,
        start, end regs are indexed from 1,2...KW2_MAX and indexed by kw2_wire directly.        

    * For KW_MAX = 7 kw = 5, signals are asserted in following sequence:
        - col==(col-3)  :                   end_in[1]
        - col==(col-2)  :   end_out[1],     end_in[2]
        - col==(col-1)  :   end_out[2],   start_in[1]  (passed to start_in[1] through a mux)
        - col==  0      : start_out[1],   start_in[2]
        - col==  1      : start_out[2],   start_in[3]

    * LAST_COLUMN  (input) :   end_out[kw2_wire] asserted
    * FIRST_COLUMN (input) : start_out[ 1      ] asserted

    * LAST_COL  (RIGHT) : end[kw2_wire] AND i(datapath) = kw/2
    * FIRST_COL (LEFT ) : delay(start[kw2_wire])
    */

    logic   reg_clken                  [MEMBERS-1 : 0];
    logic   reg_clken_masked           [MEMBERS-1 : 0];
    logic   col_left_in                [MEMBERS-1 : 0];
    logic   [KW2_MAX : 1] col_end_in   [MEMBERS-1 : 0];
    logic   [KW2_MAX : 0] col_end      [MEMBERS-1 : 0];
    logic   [KW2_MAX : 0] col_end_masked [MEMBERS-1 : 0];
    logic   [KW2_MAX : 1] col_start_in [MEMBERS-1 : 0];
    logic   [KW2_MAX : 1] col_start    [MEMBERS-1 : 0];

    logic [BITS_KW-1:0] clr_left_lut  [2**KW2_MAX:0][KW_MAX      /2:0];
    logic [BITS_KW-1:0] clr_right_lut [2**KW2_MAX:0];

    logic [BITS_KW-1: 0] clr_left_in   [MEMBERS - 1 : 0];
    logic [BITS_KW-1: 0] clr_left_out  [MEMBERS - 1 : 0];

    logic lut_next_full  [MEMBERS - 1 : 0] [KW2_MAX : 0];

    generate
        for (genvar m=0; m < MEMBERS; m++) begin: col_end_gen_m
        
            assign kw2_wire [m] = user_in [m][BITS_KW2 + I_KW2-1: I_KW2]; // kw = 7 : kw2_wire = 3,   kw = 5 : kw2_wire = 2,   kw = 3 : kw2_wire = 1

            assign reg_clken[m] = aclken[m] && valid_in[m] && (user_in [m][I_IS_CIN_LAST] || user_in [m][I_IS_CONFIG]);

            assign col_end_in         [m][1]  = user_in[m][I_IS_COLS_1_K2] && (kw2_wire [m] != 0);
            assign col_start_in       [m][1]  = user_in[m][I_IS_CONFIG] ? (kw2_wire [m] != 0) : col_end[m][kw2_wire[m]]; // This is a mux

            for (genvar k=2; k < KW2_MAX+1; k++) begin: col_end_gen_k
                assign col_end_in     [m][k]  = col_end  [m][k-1];
                assign col_start_in   [m][k]  = user_in  [m][I_IS_CONFIG] ? 0 : col_start[m][k-1];
            end


            register
            #(
                .WORD_WIDTH     (KW2_MAX),
                .RESET_VALUE    (0 )         
            )
            COL_END_REG
            (
                .clock          (aclk              ),
                .clock_enable   (reg_clken      [m]),
                .resetn         (aresetn           ),
                .data_in        (col_end_in     [m]),
                .data_out       (col_end        [m][KW2_MAX : 1])
            );
            assign col_end [m][0] = 0; // to solve issue with end_partial

            register
            #(
                .WORD_WIDTH     (KW2_MAX),
                .RESET_VALUE    (0 )         
            )
            COL_START_REG
            (
                .clock          (aclk                ),
                .clock_enable   (reg_clken        [m]),
                .resetn         (aresetn             ),
                .data_in        (col_start_in     [m]),
                .data_out       (col_start        [m])
            );

            /*
                CLR (Center-Left-Right)

                kw=1: 000000000
                kw=3: 100000002
                kw=5: 130000042
                kw=7: 135000642

                CENTER (0):
                    if all col_start & col_end_masked are zeros
                
                LEFT (1,3,5,7...):
                    - for kw_max=7, kw=5:
                        - col_start{s2,s1,s0}                     = [0,1,2,4]
                        - reverse(col_start)                      = [0,4,2,1]
                        - log(rev(col_start))                     =   [2,1,0]
                        - 1 + 2*log(rev(col_start))               =   [5,3,1]
                        - 1 + 2*log(rev(col_start)) - (kw_max-kw) =   [3,1,-]

                    - left = 1 + 2*log(rev(col_start)) + kw - kw_max
            */

            if (m==0) begin
                for (genvar kw2=0; kw2 <= KW2_MAX; kw2++) begin
                    
                    localparam kw = kw2*2+1;
                    assign clr_left_lut [0][kw2] = 0;

                    for (genvar log_col=0; log_col<=KW2_MAX; log_col++)
                        assign clr_left_lut [2**log_col][kw2] = 1 + 2*log_col + kw-KW_MAX      ;
                end
            end

            assign clr_left_in [m] = clr_left_lut[col_start[m]][kw2_wire[m]];

            register #(
                .WORD_WIDTH     (BITS_KW),
                .RESET_VALUE    (1)         
            )
            REG_CLR_LEFT
            (
                .clock          (aclk           ),
                .clock_enable   (reg_clken   [m]),
                .resetn         (aresetn        ),
                .data_in        (clr_left_in [m]),
                .data_out       (clr_left_out[m])
            );


            /*
                RIGHT (2,4,6,8...):
                    - s0->2, s1->4,
                    - col_end_masked {e2,e1,e0}  =   [0,2,4,8]
                    - log(col_end_masked)        =   [0,1,2,3]
                    - 2*log(col_end_masked)      =   [0,2,4,6]

                    - right = 2*log(col_end_masked)
            */

            assign lut_next_full[m][0] = 1;
            for (genvar kw2=1;  kw2 <= KW2_MAX; kw2++) begin
                localparam kw = kw2*2+1;
                assign lut_next_full[m][kw2] = (m % kw) == kw-2; // before last
            end
            assign reg_clken_masked  [m] = aclken[m] && valid_in[m] && lut_next_full[m][kw2_wire[m]] && user_in [m][I_IS_CIN_LAST];

            register
            #(
                .WORD_WIDTH     (KW2_MAX),
                .RESET_VALUE    (0 )         
            )
            COL_END_MASKED_REG
            (
                .clock          (aclk              ),
                .clock_enable   (reg_clken_masked[m]),
                .resetn         (aresetn           ),
                .data_in        (col_end_in      [m]),
                .data_out       (col_end_masked  [m][KW2_MAX : 1])
            );
            assign col_end_masked [m][0] = 0;


            if (m==0) begin
                assign clr_right_lut [0] = 0;
                for (genvar log_col=0; log_col<=KW2_MAX; log_col++)
                    assign clr_right_lut [2**log_col] = 2*log_col;
            end

            /* CLR */

            assign clr[m] = clr_left_out[m] | clr_right_lut[col_end_masked[m]];
        end
    endgenerate

    /*
    LOOKUP LOGIC for two masks

    * Lookup logic is created for every possible odd kernels less than max,
        independantly for datapaths, allowing back to back kernel change
    * table[datapath][kernel]
    * logic is explained. Refer architecture.xlsx or whiteboard for further details

    * OPTIMIZATION: 
        - To avoid synthesis of a combinational added when calculating kw/2-1 for indexing,
            kernel dimension of LUTs go 1,2,...,KW2_MAX and indexed by kw_wire directly
        - All equations are transformed in terms of kw2
        - NOTE: Excel sheet and whiteboard are in terms of (r = kw2-1)

    */
    
    logic lut_allow_full     [MEMBERS - 1 : 0] [KW2_MAX : 0];
    logic lut_stop_partial   [MEMBERS - 1 : 1] [KW2_MAX : 0]; 

    generate
        for (genvar m=0; m < MEMBERS; m++)   begin: lookup_full_datapath_gen
            for (genvar kw2=1;  kw2 <= KW2_MAX; kw2++)   begin: lookup_full_kw_gen
                localparam kw = kw2*2 + 1;

                logic full_datapath, unused_datapaths, start_cols, last_col, last_malformed, at_start_and_middle, at_last_col;
            
                assign full_datapath             =     (m % kw) == kw-1      ; // M=24, kw=5: m=0,4,9,14,19
                assign unused_datapaths          =     m >= (MEMBERS/kw)*kw  ; // m >= 20
                assign start_cols                =     |col_start[m][kw2:1]  ; // 1,2,...k2 : first k/2 colums are to be ignored
                assign last_col                  =      col_end  [m][kw2  ]  ; // if the last column:
                assign last_malformed            =     (m % kw) <  kw2       ; // M=24, kw=5: m=0,1,5,6; All (m<k2) datapaths contain malformed data, rest contain padded data
                assign at_start_and_middle       =     full_datapath & !start_cols; // During start_cols, block all datapaths. During middle_cols, allow only full_datapth.
                assign at_last_col               =     last_col & !last_malformed & !unused_datapaths; // At the last_col, only allow datapaths that have partially formed padding

                assign lut_allow_full   [m][kw2] =     at_start_and_middle | at_last_col;
            end
            assign     lut_allow_full   [m][ 0 ] =     1;

            assign    mask_full[m]  =  lut_allow_full [m][kw2_wire[m]] | user_in[m][I_IS_CONFIG];
        end

        for (genvar m=1; m < MEMBERS; m++)   begin: lookup_partial_datapath_gen
            for (genvar kw2=0;  kw2 <=  KW2_MAX ; kw2++) begin: lut_partial_kw_gen
                localparam kw = kw2*2 + 1;

                logic unused_datapaths, end_partial;
                assign unused_datapaths  =  m >= (MEMBERS/kw)*kw;  // Anything above m == kw2 should be blocked

                if ((m % kw) > kw2)
                    assign end_partial =  col_end[m][kw2];       // Block m>kw2 datapaths, only for last col. For others, we need those partial sums for first few columns
                else
                    assign end_partial = |col_end[m][kw2:(m%kw)];    // or(w, w+1, w+2, ... k2), horizontal rows of the blocking triangle

               assign lut_stop_partial [m][kw2] =  end_partial | unused_datapaths;
            end
            assign    lut_stop_partial [m][ 0 ] =  1; 

            assign    mask_partial[m]         = !lut_stop_partial [m][kw2_wire[m]];
        end
    endgenerate
endmodule