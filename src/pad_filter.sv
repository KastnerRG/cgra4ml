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


module pad_filter # (
    KERNEL_W_MAX  ,
    TUSER_WIDTH   ,
    I_IS_1X1      ,
    I_IS_COLS_1_K2,
    I_IS_CONFIG   ,
    I_IS_ACC_LAST ,
    I_KERNEL_W_1 
)(
    aclk,
    aclken,
    aresetn,
    user_in,
    valid_in,
    
    mask_partial,
    mask_full,
    is_left_col,
    is_right_col
);
    genvar i,k,kw2;
    localparam KW2_MAX           = KERNEL_W_MAX/2; //R, 3->1, 5->2, 7->3
    localparam BITS_KERNEL_W    = $clog2(KERNEL_W_MAX);

    input  logic                      aclk;
    input  logic [KERNEL_W_MAX-1 : 0] aclken;               
    input  logic                      aresetn;

    input  logic [TUSER_WIDTH - 1: 0] user_in      [KERNEL_W_MAX - 1 : 0];
    input  logic                      valid_in     [KERNEL_W_MAX - 1 : 0];

    output logic                      mask_partial [KERNEL_W_MAX - 1 : 1];
    output logic                      mask_full    [KERNEL_W_MAX - 1 : 0];
    
    output logic is_left_col  [KERNEL_W_MAX - 1 : 0];
    output logic is_right_col [KERNEL_W_MAX - 1 : 0];

    /*
    KW2_1

    * From user_in, hence tied to valid and last
    * Value: (kw/2 -1)
        - (7 x m) : 2
        - (5 x m) : 1
        - (3 x m) : 0
    * Acts as mux_sel for lookup logic
    */
    
    logic   [BITS_KERNEL_W-1 : 0]  kw_wire [KERNEL_W_MAX-1 : 0];
    logic   [BITS_KERNEL_W-2 : 0] kw2_wire [KERNEL_W_MAX-1 : 0];
    
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

    *  LAST_COLUMN      :   end_out[kw2_wire] asserted
    * FIRST_COLUMN      : start_out[ 1      ] asserted
    
    */

    logic                            reg_clken           [KERNEL_W_MAX - 1 : 0];
    logic   [KW2_MAX          : 1]   col_end_in          [KERNEL_W_MAX - 1 : 0];
    logic   [KW2_MAX          : 1]   col_end             [KERNEL_W_MAX - 1 : 0];
    logic   [KW2_MAX          : 1]   col_start_in        [KERNEL_W_MAX - 1 : 0];
    logic   [KW2_MAX          : 1]   col_start           [KERNEL_W_MAX - 1 : 0];
    generate
        for (i=0; i < KERNEL_W_MAX; i = i+1) begin: col_end_gen_i
        
            assign kw_wire [i] = user_in[i][BITS_KERNEL_W + I_KERNEL_W_1-1: I_KERNEL_W_1];
            assign kw2_wire[i] = kw_wire[i] / 2; // kw = 7 : kw2_wire = 3,   kw = 5 : kw2_wire = 2,   kw = 3 : kw2_wire = 1


            assign reg_clken[i] = user_in [i][I_IS_ACC_LAST] && aclken[i] && valid_in[i];

            assign col_end_in         [i][1]  = user_in[i][I_IS_COLS_1_K2];
            assign col_start_in       [i][1]  = col_end[i][kw2_wire[i]]; // This is a mux

            for (   k=2;    k < KW2_MAX+1;    k = k+1) begin: col_end_gen_k
                assign col_end_in     [i][k]  = col_end[i][k-1];
                assign col_start_in   [i][k]  = col_start[i][k-1];
            end

            register
            #(
                .WORD_WIDTH     (KW2_MAX),
                .RESET_VALUE    (0      )         
            )
            COL_END_REG
            (
                .clock          (aclk              ),
                .clock_enable   (reg_clken      [i]),
                .resetn         (aresetn           ),
                .data_in        (col_end_in     [i]),
                .data_out       (col_end        [i])
            );

            register
            #(
                .WORD_WIDTH     (KW2_MAX),
                .RESET_VALUE    (1      )         
            )
            COL_START_REG
            (
                .clock          (aclk                ),
                .clock_enable   (reg_clken        [i]),
                .resetn         (aresetn             ),
                .data_in        (col_start_in     [i]),
                .data_out       (col_start        [i])
            );

            assign is_left_col [i]  = col_end  [KERNEL_W_MAX-1];
            assign is_right_col[i]  = col_start[0];
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
    
    logic lut_allow_full     [KERNEL_W_MAX - 1 : 0] [KW2_MAX : 1];
    logic lut_stop_partial   [KERNEL_W_MAX - 1 : 1] [KW2_MAX : 1]; 

    generate
        for ( i=0; i < KERNEL_W_MAX; i = i+1)   begin: lookup_full_datapath_gen
            for ( kw2=1;  kw2 < KW2_MAX+1; kw2 = kw2+1)   begin: lookup_full_kw_gen

                logic full_datapath, unused_datapaths, start_cols, last_col, last_malformed, at_start_and_middle, at_last_col;
            
                assign full_datapath             =     i == 2*kw2            ; // i == kw-1 = (2k2+1)-1 = (2(kw2)+1)-1 = 2kw2
                assign unused_datapaths          =     i >  2*kw2            ; // Anything above that is unused
                assign start_cols                =     |col_start[i][kw2:1]  ; // 1,2,...k2 : first k/2 colums are to be ignored
                assign last_col                  =      col_end  [i][kw2  ]  ; // if the last column:
                assign last_malformed            =     i <  kw2              ; // All (i<k2) datapaths contain malformed data, rest contain padded data
                assign at_start_and_middle       =     full_datapath & !start_cols; // During start_cols, block all datapaths. During middle_cols, allow only full_datapth.
                assign at_last_col               =     last_col & !last_malformed & !unused_datapaths; // At the last_col, only allow datapaths that have partially formed padding

                assign lut_allow_full   [i][kw2] =     at_start_and_middle | at_last_col;
            end

            assign    mask_full[i]  =  (lut_allow_full [i][kw2_wire[i]] & kw2_wire[i] !=0) | (user_in[i][I_IS_CONFIG] & (i==0)) | (user_in[i][I_IS_1X1] && ~user_in[i][I_IS_CONFIG]);
        end

        for ( i=1; i < KERNEL_W_MAX; i = i+1)   begin: lookup_partial_datapath_gen
            for ( kw2=1;  kw2 <  KW2_MAX+1 ; kw2 = kw2+1) begin: lut_partial_kw_gen
                
                logic unused_datapaths, end_partial;

                assign unused_datapaths  =  i >  2*kw2 ;          // Anything above i == kw2 should be blocked

                if (i > kw2)
                    assign end_partial = col_end[i][kw2];       // Block i>kw2 datapaths, only for last col. For others, we need those partial sums for first few columns
                else
                    assign end_partial = |col_end[i][kw2:i];    // or(i, i+1, i+2, ... k2), horizontal rows of the blocking triangle

               assign lut_stop_partial [i][kw2] =  end_partial | unused_datapaths;
                
            end

            assign    mask_partial[i]         = !lut_stop_partial [i][kw2_wire[i]];
        end
    endgenerate
endmodule