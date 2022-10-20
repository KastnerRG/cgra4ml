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

`timescale 1ns/1ps
`include "../include/params.v"

module pad_filter #(ZERO=0)
(
    aclk,
    aclken,
    aresetn,
    user_in,
    valid_in,
    valid_mask,
    clr,
    shift_a,
    shift_b
);

    localparam KW_MAX           = `KW_MAX             ;
    localparam SW_MAX           = `SW_MAX             ;
    localparam MEMBERS          = `MEMBERS            ;
    localparam TUSER_WIDTH      = `TUSER_WIDTH_CONV_IN;
    localparam I_IS_COLS_1_K2   = `I_IS_COLS_1_K2     ;
    localparam I_IS_CONFIG      = `I_IS_CONFIG        ;
    localparam I_IS_CIN_LAST    = `I_IS_CIN_LAST      ;
    localparam I_IS_COL_VALID   = `I_IS_COL_VALID     ;
    localparam I_KW2            = `I_KW2              ;
    localparam I_SW_1           = `I_SW_1             ;

    localparam KW2_MAX          = KW_MAX      /2; //R, 3->1, 5->2, 7->3
    localparam BITS_KW          = `BITS_KW;
    localparam BITS_KW2         = `BITS_KW2;
    localparam BITS_SW          = `BITS_SW;
    localparam BITS_MEMBERS     = `BITS_MEMBERS  ;
    localparam BITS_OUT_SHIFT   = `BITS_OUT_SHIFT;

    input  logic aclk, aresetn, aclken, valid_in;
    input  logic [TUSER_WIDTH - 1: 0] user_in ;
    output logic [MEMBERS - 1 : 0][BITS_KW - 1 : 0] clr; // 0-center, 1-center-left, 2-center-right, 3-left, 4-right
    output logic valid_mask;
    output logic [BITS_MEMBERS  -1:0] shift_a;
    output logic [BITS_OUT_SHIFT-1:0] shift_b;

   
    logic   [BITS_KW2-1 : 0] kw2_wire;
    logic   [BITS_SW -1 : 0] sw_1_wire;
    assign kw2_wire  = user_in [BITS_KW2 + I_KW2  -1: I_KW2 ]; // kw = 7 : kw2_wire = 3,   kw = 5 : kw2_wire = 2,   kw = 3 : kw2_wire = 1
    assign sw_1_wire = user_in [BITS_SW  + I_SW_1 -1: I_SW_1];
    
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

    logic   reg_clken       ;
    logic   [KW2_MAX : 1] col_end_in     ;
    logic   [KW2_MAX : 0] col_end        ;
    logic   [MEMBERS-1:0] reg_clken_masked;
    logic   [KW2_MAX : 1] col_start_in   ;
    logic   [KW2_MAX : 1] col_start      ;
    logic   [MEMBERS-1:0][KW2_MAX : 0] col_end_masked;

    logic [BITS_KW-1:0] clr_left_lut  [2**KW2_MAX:0][KW_MAX      /2:0];
    logic [BITS_KW-1:0] clr_right_lut [2**KW2_MAX:0];

    logic [BITS_KW-1: 0] clr_left_in ;
    logic [BITS_KW-1: 0] clr_left_out;

    logic lut_next_full  [MEMBERS - 1 : 0] [KW2_MAX : 0];

    generate
        assign reg_clken = aclken && valid_in && (user_in [I_IS_CIN_LAST] || user_in [I_IS_CONFIG]);

        assign col_end_in   [1]  = user_in [I_IS_COLS_1_K2] && (kw2_wire != 0);
        assign col_start_in [1]  = user_in [I_IS_CONFIG] ? (kw2_wire != 0) : col_end[kw2_wire]; // This is a mux

        for (genvar k=2; k < KW2_MAX+1; k++) begin: col_end_gen_k
            assign col_end_in     [k]  = col_end  [k-1];
            assign col_start_in   [k]  = user_in  [I_IS_CONFIG] ? 0 : col_start[k-1];
        end

        register #(
            .WORD_WIDTH     (KW2_MAX),
            .RESET_VALUE    (0 )
        ) COL_END_REG (
            .clock          (aclk       ),
            .clock_enable   (reg_clken  ),
            .resetn         (aresetn    ),
            .data_in        (col_end_in ),
            .data_out       (col_end    [KW2_MAX : 1])
        );
        assign col_end [0] = 0; // to solve issue with end_partial

        register #(
            .WORD_WIDTH     (KW2_MAX),
            .RESET_VALUE    (0 )
        ) COL_START_REG (
            .clock          (aclk        ),
            .clock_enable   (reg_clken   ),
            .resetn         (aresetn     ),
            .data_in        (col_start_in),
            .data_out       (col_start   )
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

        for (genvar kw2=0; kw2 <= KW2_MAX; kw2++) begin
            
            localparam kw = kw2*2+1;
            assign clr_left_lut [0][kw2] = 0;

            for (genvar log_col=0; log_col<=KW2_MAX; log_col++)
                assign clr_left_lut [2**log_col][kw2] = 1 + 2*log_col + kw-KW_MAX      ;
        end

        assign clr_left_in = clr_left_lut[col_start][kw2_wire];

        register #(
            .WORD_WIDTH     (BITS_KW),
            .RESET_VALUE    (1)
        ) REG_CLR_LEFT (
            .clock          (aclk         ),
            .clock_enable   (reg_clken    ),
            .resetn         (aresetn      ),
            .data_in        (clr_left_in  ),
            .data_out       (clr_left_out )
        );

        /*
            RIGHT (2,4,6,8...):
            - s0->2, s1->4,
            - col_end_masked {e2,e1,e0}  =   [0,2,4,8]
            - log(col_end_masked)        =   [0,1,2,3]
            - 2*log(col_end_masked)      =   [0,2,4,6]

            - right = 2*log(col_end_masked)
        */

        for (genvar m=0; m<MEMBERS; m++) begin

            assign lut_next_full[m][0] = 1;
            for (genvar kw2=1;  kw2 <= KW2_MAX; kw2++) begin
                localparam kw = kw2*2+1;
                assign lut_next_full[m][kw2] = (m % kw) == kw-2; // before last
            end
            assign reg_clken_masked  [m] = aclken && valid_in && lut_next_full[m][kw2_wire] && user_in [I_IS_CIN_LAST];

            register #(
                .WORD_WIDTH     (KW2_MAX),
                .RESET_VALUE    (0 )         
            ) COL_END_MASKED_REG (
                .clock          (aclk              ),
                .clock_enable   (reg_clken_masked[m]),
                .resetn         (aresetn           ),
                .data_in        (col_end_in        ),
                .data_out       (col_end_masked  [m][KW2_MAX : 1])
            );
            assign col_end_masked [m][0] = 0;


            if (m==0) begin
                assign clr_right_lut [0] = 0;
                for (genvar log_col=0; log_col<=KW2_MAX; log_col++)
                    assign clr_right_lut [2**log_col] = 2*log_col;
            end

            /* CLR */

            assign clr[m] = clr_left_out | clr_right_lut[col_end_masked[m]];
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
    
    logic lut_not_start_cols              [KW2_MAX : 0];
    logic lut_allow     [MEMBERS - 1 : 0] [KW2_MAX : 0][SW_MAX-1:0];

    logic [KW2_MAX:0][SW_MAX-1:0][BITS_MEMBERS  -1:0] lut_shift_a;
    logic [KW2_MAX:0][SW_MAX-1:0][BITS_OUT_SHIFT-1:0] lut_shift_b;

    generate
        assign lut_not_start_cols[0] = 1;
        for (genvar kw2=1;  kw2 <= KW2_MAX; kw2++)
            assign lut_not_start_cols[kw2] = !(|col_start[kw2:1]);  // 1,2,...k2 : first k/2 colums are to be ignored

        assign valid_mask = (lut_not_start_cols[kw2_wire] & user_in [I_IS_COL_VALID])  | user_in [I_IS_CONFIG];

        for (genvar kw2=1;  kw2 <= KW2_MAX; kw2++)
            for (genvar sw_1=0;  sw_1 < SW_MAX; sw_1++) begin
                localparam k = kw2*2 + 1;
                localparam s = sw_1 + 1;
                localparam j = k + s -1;

                if (`KS_COMBS_EXPR) begin
                    assign lut_shift_a[kw2][sw_1] = col_end [kw2] ? kw2 : 0; // only for S=1
                    assign lut_shift_b[kw2][sw_1] = k==1 ? 0 : MEMBERS/j-1; 
                end
            end

        assign shift_a = lut_shift_a[kw2_wire][sw_1_wire];
        assign shift_b = lut_shift_b[kw2_wire][sw_1_wire];
    endgenerate

        // for (genvar m=0; m < MEMBERS; m++)   begin: M
        //     for (genvar kw2=1;  kw2 <= KW2_MAX; kw2++)
        //         for (genvar sw_1=0;  sw_1 < SW_MAX; sw_1++)   begin: S

        //             localparam k = kw2*2 + 1;
        //             localparam s = sw_1 + 1;
        //             localparam j = k + s -1;

        //             if (`KS_COMBS_EXPR) begin
        //                 logic full_datapath, unused_datapaths, last_col, last_malformed, at_start_and_middle, at_last_col;
                    
        //                 assign full_datapath       = (m % j) >= k-1         ; // M=24, kw=5: m=0,4,9,14,19
        //                 assign unused_datapaths    = m >= (MEMBERS/j)*j     ; // m >= 20
        //                 assign last_col            = col_end  [kw2]         ; // if the last column:
        //                 assign last_malformed      = (m % j) <  k-1-s       ; // M=24, kw=5: m=0,1,5,6; All (m<k2) datapaths contain malformed data, rest contain padded data
        //                 assign at_start_and_middle = lut_not_start_cols[kw2] & full_datapath; // During start_cols, block all datapaths. During middle_cols, allow only full_datapth.
        //                 assign at_last_col         = last_col & !last_malformed & !unused_datapaths; // At the last_col, only allow datapaths that have partially formed padding

        //                 assign lut_allow [m][kw2][sw_1]  = at_start_and_middle | at_last_col;
        //             end
        //         end
        //     assign     lut_allow [m][0][0] = 1;

        //     // assign     keep_mask[m]  =  lut_allow [m][kw2_wire][sw_1_wire] | user_in [I_IS_CONFIG];
        // end
endmodule