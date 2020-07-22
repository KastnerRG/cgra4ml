`timescale 1ns / 1ps

module pad_filter_tb # ();

    parameter CLK_PERIOD            = 10;
    parameter DATA_WIDTH            = 16;
    parameter KERNEL_W_MAX          = 7;
    parameter TUSER_WIDTH           = 4;

    parameter INDEX_IS_1x1          = 0;
    parameter INDEX_IS_COLS_1_K2    = 3;

    parameter KW_1                  = 5-1;
    parameter IS_1x1                = 0;

    localparam KERNEL_W_WIDTH       = $clog2(KERNEL_W_MAX   + 1);

    reg                         aclk                                 = 0;
    reg                         aclken                               = 0;               
    reg                         aresetn                              = 0;
    reg                         start                                = 0;
    reg  [KERNEL_W_WIDTH-1:0]   kernel_w_1_in                        = KW_1;
    reg                         in_valid_last [KERNEL_W_MAX - 1 : 0] = '{default:'0};
    reg                         in_last       [KERNEL_W_MAX - 1 : 0] = '{default:'0};
    reg  [TUSER_WIDTH - 1: 0]   in_user       [KERNEL_W_MAX - 1 : 0] = '{default:'0};
    wire                        snake_valid   [KERNEL_W_MAX - 1 : 1];
    wire                        m_valid       [KERNEL_W_MAX - 1 : 0];
    wire                        m_last        [KERNEL_W_MAX - 1 : 0];

    pad_filter # (
        .DATA_WIDTH        (DATA_WIDTH),
        .KERNEL_W_MAX      (KERNEL_W_MAX),
        .TUSER_WIDTH       (TUSER_WIDTH),
        .INDEX_IS_COLS_1_K2(INDEX_IS_COLS_1_K2),
        .INDEX_IS_1x1      (INDEX_IS_1x1)
    )
    pad_filter_dut
    (
        .aclk            (aclk         ),
        .aclken          (aclken       ),
        .aresetn         (aresetn      ),
        .start           (start        ),
        .kernel_w_1_in   (kernel_w_1_in),
        .in_valid_last   (in_valid_last),
        .in_last         (in_last      ),
        .in_user         (in_user      ),
        .snake_valid     (snake_valid  ),
        .m_valid         (m_valid      ),
        .m_last          (m_last       )
    );

    always begin
        #(CLK_PERIOD/2);
        aclk <= ~aclk;
    end

    integer n = 0;

    initial begin
        @(posedge aclk);
        #(CLK_PERIOD*3)
        aresetn     <= 1;

        @(posedge aclk);
        start       <= 1;
        @(posedge aclk);
        start       <= 0;

        #(CLK_PERIOD*3)
        @(posedge aclk);
        in_valid_last <= {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};

        @(posedge aclk);
        in_valid_last <= {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};

        @(posedge aclk);
        in_valid_last <= {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};

        @(posedge aclk);
        in_valid_last <= {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};
        in_user         [0][INDEX_IS_COLS_1_K2] <= 1;
        in_user         [1][INDEX_IS_COLS_1_K2] <= 1;
        in_user         [2][INDEX_IS_COLS_1_K2] <= 1;
        in_user         [3][INDEX_IS_COLS_1_K2] <= 1;
        in_user         [4][INDEX_IS_COLS_1_K2] <= 1;
        in_user         [5][INDEX_IS_COLS_1_K2] <= 1;
        in_user         [6][INDEX_IS_COLS_1_K2] <= 1;
        @(posedge aclk);
        in_valid_last <= {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};
        in_user         [0][INDEX_IS_COLS_1_K2] <= 0;
        in_user         [1][INDEX_IS_COLS_1_K2] <= 0;
        in_user         [2][INDEX_IS_COLS_1_K2] <= 0;
        in_user         [3][INDEX_IS_COLS_1_K2] <= 0;
        in_user         [4][INDEX_IS_COLS_1_K2] <= 0;
        in_user         [5][INDEX_IS_COLS_1_K2] <= 0;
        in_user         [6][INDEX_IS_COLS_1_K2] <= 0;

        @(posedge aclk);
        in_valid_last <= {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};
        @(posedge aclk);
        in_valid_last <= {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};

        @(posedge aclk);
        in_valid_last <= {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};
        @(posedge aclk);
        in_valid_last <= {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};

        @(posedge aclk);
        in_valid_last <= {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};
        @(posedge aclk);
        in_valid_last <= {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};

        @(posedge aclk);
        in_valid_last <= {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};
        @(posedge aclk);
        in_valid_last <= {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};





    end

endmodule