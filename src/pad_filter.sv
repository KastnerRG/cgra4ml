/*//////////////////////////////////////////////////////////////////////////////////
Group : ABruTECH
Engineer: Abarajithan G.

Create Date: 21/07/2020
Design Name: Pad mask
Tool Versions: Vivado 2018.2
Description: Computes two masks that allow horizontal zero padding for
                convolutions where output image should have same size as input.
            * Maximum kernal width can be specified as a parameter and fixed in synthesis.
            * Any odd kernel less than max can be used
            * Lookup logic is created for every possible odd kernels less than max,
                independantly for datapaths, allowing back to back kernel change
            * kw_1 is accepted during start. TODO: tie it with data via tuser for back-to-back 
                kernel change

Revision:
Revision 0.01 - File Created
Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////*/


module pad_filter # (
    parameter DATA_WIDTH        ,
    parameter KERNEL_W_MAX      ,
    parameter TUSER_WIDTH       ,
    parameter INDEX_IS_COLS_1_K2,
    parameter INDEX_IS_1x1
)(
    aclk,
    aclken,
    aresetn,
    start,

    kernel_w_1_in,

    valid_last,
    user,
    
    mask_partial,
    mask_full
);
    genvar i,k,r;
    localparam KW2_MAX           = KERNEL_W_MAX/2; //R, 3->1, 5->2, 7->3
    localparam KERNEL_W_WIDTH    = $clog2(KERNEL_W_MAX   + 1);

    input  wire                      aclk;
    input  wire                      aclken;               
    input  wire                      aresetn;
    input  wire                      start;

    input  wire [KERNEL_W_WIDTH-1:0] kernel_w_1_in ;

    input  wire                      valid_last [KERNEL_W_MAX - 1 : 0];
    input  wire [TUSER_WIDTH - 1: 0] user       [KERNEL_W_MAX - 1 : 0];

    output wire                      mask_partial  [KERNEL_W_MAX - 1 : 1];
    output wire                      mask_full    [KERNEL_W_MAX - 1 : 0];

    /*
    KW2_1 Register

    * Holds the value of (kw/2 -1)
        - (7 x m) : 2
        - (5 x m) : 1
        - (3 x m) : 0
    * Accepts value during "start". TODO: Tie value to TUSER
    * Acts as mux_sel for lookup logic
    
    */

    wire   [KERNEL_W_WIDTH-1 : 0]    kw2_1_reg_in;
    wire   [KERNEL_W_WIDTH-1 : 0]    kw2_1_reg_out;

    assign kw2_1_reg_in = kernel_w_1_in/2 -1;

    register
    #(
        .WORD_WIDTH     (KERNEL_W_WIDTH),
        .RESET_VALUE    (1)         
    )
    KW2_1_REG
    (
        .clock          (aclk),
        .clock_enable   (start),
        .resetn         (aresetn),
        .data_in        (kw2_1_reg_in),
        .data_out       (kw2_1_reg_out)
    );

    /*
    COL_START, COL_END Registers

    * One bit
    * is_col_1_k2 from TUSER, which rises at col==(col-1-k/2) is passed through these
    * updated at each valid_last (end of channels_in)

    * For KW_MAX = 7 kw = 5, signals are asserted in following sequence:
        - col==(col-3)  :                   end_in[0]
        - col==(col-2)  :   end_out[0],     end_in[1]
        - col==(col-1)  :   end_out[1],   start_in[0]  (passed to start_in[0] through a mux)
        - col==  0      : start_out[0],   start_in[1]
        - col==  1      : start_out[1],   start_in[2]

    *  LAST_COLUMN      :   end_out[kw2_1] asserted
    * FIRST_COLUMN      : start_out[  0  ] asserted
    
    */


    wire                            reg_clken           [KERNEL_W_MAX - 1 : 0];
    wire   [KW2_MAX      - 1 : 0]   col_end_in          [KERNEL_W_MAX - 1 : 0];
    wire   [KW2_MAX      - 1 : 0]   col_end             [KERNEL_W_MAX - 1 : 0];
    wire   [KW2_MAX      - 1 : 0]   col_start_in        [KERNEL_W_MAX - 1 : 0];
    wire   [KW2_MAX      - 1 : 0]   col_start           [KERNEL_W_MAX - 1 : 0];
    generate
        for (i=0; i < KERNEL_W_MAX; i = i+1) begin: col_end_gen_i

            assign reg_clken[i] = valid_last  [i] && aclken;

            assign col_end_in         [i][0]  = user[i][INDEX_IS_COLS_1_K2];
            assign col_start_in       [i][0]  = col_end[i][kw2_1_reg_out]; // This is a mux

            for (   k=1;    k < KW2_MAX;    k = k+1) begin: col_end_gen_k
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
                .RESET_VALUE    (0      )         
            )
            COL_START_REG
            (
                .clock          (aclk                ),
                .clock_enable   (reg_clken        [i]),
                .resetn         (aresetn             ),
                .data_in        (col_start_in     [i]),
                .data_out       (col_start        [i])
            );
        end
    endgenerate

    /*
    LOOKUP LOGIC for two masks

    * Lookup logic is created for every possible odd kernels less than max,
        independantly for datapaths, allowing back to back kernel change
    * table[datapath][kernel]
    * logic is explained. Refer architecture.xlsx or whiteboard for further details
    */
    
    bit   lut_allow_full     [KERNEL_W_MAX - 1 : 0] [KW2_MAX      - 1 : 0];
    bit   lut_stop_partial   [KERNEL_W_MAX - 1 : 0] [KW2_MAX      - 1 : 0]; 

    wire   is_1x1 = user[INDEX_IS_1x1];
    generate
        for ( i=0; i < KERNEL_W_MAX; i = i+1)   begin: lookup_full_datapath_gen
            for ( r=0;  r < KW2_MAX; r = r+1)   begin: lookup_full_kw_gen
            
                wire full_datapath             =     i == 2*(r+1)        ; // i == kw-1 = (2k2+1)-1 = (2(r+1)+1)-1 = 2r+3-1 = 2(r+2)
                wire unused_datapaths          =     i >  2*(r+1)        ; // Anything above that is unused

                wire start_cols                =     |col_start[i][r:0]  ; // 0,1,...k2-1 : first k/2 colums are to be ignored
                wire last_col                  =      col_end  [i][r  ]  ; // if the last column...

                wire last_partial              =     i >  r              ; // i > k2-1 : i >= k2 : All (i<k2) datapaths contain insuffient data

                wire at_start_and_middle       =     full_datapath & !start_cols; // During start_cols, block all datapaths. During middle_cols, allow only full_datapth.
                wire at_last_col               =     last_col & last_partial & !unused_datapaths; // At the last_col, only allow datapaths that have partially formed padding

                assign lut_allow_full   [i][r] =     at_start_and_middle | at_last_col | is_1x1;
            end

            assign    mask_full[i]             =     lut_allow_full    [i][kw2_1_reg_out];
        end

        for ( i=1; i < KERNEL_W_MAX; i = i+1)   begin: lookup_partial_datapath_gen
            for ( r=0;  r <  KW2_MAX ; r = r+1) begin: lut_partial_kw_gen

                wire unused_datapaths  =  i >  2*(r+1) ;        // Anything above i == kw-1 should be blocked
                wire end_partial;

                if (r < i-1)
                    assign end_partial = 1;
                else
                    assign end_partial = |col_end[i][r:i-1];    // or(i-1, i, i+1, ... k2-1), horizontal rows of the blocking triangle

               assign lut_stop_partial [i][r] =  end_partial | unused_datapaths;
                
            end

            assign    mask_partial[i]         = !lut_stop_partial [i][kw2_1_reg_out];
        end

    endgenerate


endmodule