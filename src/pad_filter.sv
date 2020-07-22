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

    in_valid_last,
    in_last,
    in_user,
    
    snake_valid,

    m_valid,
    m_last
);
    genvar i,k,r;
    localparam KERNEL_W_WIDTH    = $clog2(KERNEL_W_MAX   + 1);

    input  wire                      aclk;
    input  wire                      aclken;               
    input  wire                      aresetn;
    input  wire                      start;

    input  wire [KERNEL_W_WIDTH-1:0] kernel_w_1_in ;

    input  wire                      in_valid_last [KERNEL_W_MAX - 1 : 0];
    input  wire                      in_last       [KERNEL_W_MAX - 1 : 0];
    input  wire [TUSER_WIDTH - 1: 0] in_user       [KERNEL_W_MAX - 1 : 0];

    output wire                      snake_valid   [KERNEL_W_MAX - 1 : 1];
    output wire                      m_valid       [KERNEL_W_MAX - 1 : 0];
    output wire                      m_last        [KERNEL_W_MAX - 1 : 0];



    localparam KW2_MAX  = KERNEL_W_MAX/2; //R, 3->1, 5->2, 7->3

    // r - Register

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
    
    // e_ register bank

    wire   [KW2_MAX      - 1 : 0]  col_end_in      [KERNEL_W_MAX - 1 : 0]; // e_
    wire   [KW2_MAX      - 1 : 0]  col_end         [KERNEL_W_MAX - 1 : 0]; // e_
    generate
        for (i=0; i < KERNEL_W_MAX; i = i+1) begin: col_end_gen_i

            assign col_end_in       [i][0]  = in_user[i][INDEX_IS_COLS_1_K2];

            for (   k=1;    k < KW2_MAX;    k = k+1) begin: col_end_gen_k
                assign col_end_in   [i][k]  = col_end[i][k-1];
            end

            register
            #(
                .WORD_WIDTH     (KW2_MAX),
                .RESET_VALUE    (0      )         
            )
            COL_END_REG
            (
                .clock          (aclk              ),
                .clock_enable   (in_valid_last  [i]),
                .resetn         (aresetn           ),
                .data_in        (col_end_in     [i]),
                .data_out       (col_end        [i])
            );

        end
    endgenerate

    // s_ - Register bank

    wire   [KW2_MAX      - 1 : 0]    col_start_in       [KERNEL_W_MAX - 1 : 0]; // s_
    wire   [KW2_MAX      - 1 : 0]    col_start          [KERNEL_W_MAX - 1 : 0]; // s_

    generate 
        for (i=0; i < KERNEL_W_MAX; i = i+1) begin: col_start_gen

            assign col_start_in[i][0] = col_end[i][kw2_1_reg_out]; // This is a mux
            
            for (   k=1;    k < KW2_MAX;    k = k+1) begin: col_start_gen_k
                assign col_start_in   [i][k]  = col_start[i][k-1];
            end

            register
            #(
                .WORD_WIDTH     (KW2_MAX),
                .RESET_VALUE    (0      )         
            )
            COL_START_REG
            (
                .clock          (aclk                ),
                .clock_enable   (in_valid_last    [i]),
                .resetn         (aresetn             ),
                .data_in        (col_start_in     [i]),
                .data_out       (col_start        [i])
            );
        end
    endgenerate

    // Out and snake lookup tables
    
    bit   lut_allow_out     [KERNEL_W_MAX - 1 : 0] [KW2_MAX      - 1 : 0];
    bit   lut_block_snake   [KERNEL_W_MAX - 1 : 0] [KW2_MAX      - 1 : 0]; 

    wire   is_1x1 = in_user[INDEX_IS_1x1];
    generate
        for ( i=0; i < KERNEL_W_MAX; i = i+1) begin: lookup_gen_i
            for ( r=0;  r < KW2_MAX; r = r+1) begin: lut_allow_gen_r
               assign lut_allow_out   [i][r] = ((i==2*(r+1)) & (!(|col_start[i][r:0]))) | (col_end[i][r] & (i>r) & (i<2*r+3)) | is_1x1;
            end

            for ( r=0;  r <  i     ; r = r+1) begin: lut_block_gen_r1
               assign lut_block_snake [i][r] =  (i > 2*r+2);
            end
            for ( r=i;  r < KW2_MAX; r = r+1) begin: lut_block_gen_r2
               assign lut_block_snake [i][r] =  (|col_end[i][r:i]) | (i > 2*r+2);
            end
        end

        for ( i=1; i < KERNEL_W_MAX; i = i+1) begin: filter_snake
            assign snake_valid[i] = in_valid_last[i-1] & (!lut_block_snake[i][kw2_1_reg_out]);
        end
        
        for ( i=0; i < KERNEL_W_MAX; i = i+1) begin: filter_out
            assign m_valid[i]     = in_valid_last[i] & lut_allow_out[i][kw2_1_reg_out];
            assign m_last [i]     = in_last      [i] & lut_allow_out[i][kw2_1_reg_out];
        end

    endgenerate


endmodule