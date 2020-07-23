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
    reg                         valid_last [KERNEL_W_MAX - 1 : 0] = '{default:'0};
    reg  [TUSER_WIDTH - 1: 0]   user       [KERNEL_W_MAX - 1 : 0] = '{default:'0};
    wire                        mask_partial  [KERNEL_W_MAX - 1 : 1];
    wire                        mask_full     [KERNEL_W_MAX - 1 : 0];

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
        .valid_last      (valid_last   ),
        .user            (user         ),
        .mask_partial    (mask_partial ),
        .mask_full       (mask_full    )
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
        aclken      <= 1;
        
        user         [0][INDEX_IS_1x1] <= IS_1x1;
        user         [1][INDEX_IS_1x1] <= IS_1x1;
        user         [2][INDEX_IS_1x1] <= IS_1x1;
        user         [3][INDEX_IS_1x1] <= IS_1x1;
        user         [4][INDEX_IS_1x1] <= IS_1x1;
        user         [5][INDEX_IS_1x1] <= IS_1x1;
        user         [6][INDEX_IS_1x1] <= IS_1x1;

        @(posedge aclk);
        start       <= 1;
        @(posedge aclk);
        start       <= 0;

        #(CLK_PERIOD*3)
        @(posedge aclk);
        valid_last <= {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};

        @(posedge aclk);
        valid_last <= {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};

        @(posedge aclk);
        valid_last <= {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};

        @(posedge aclk);
        valid_last <= {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};
        user         [0][INDEX_IS_COLS_1_K2] <= 1;
        user         [1][INDEX_IS_COLS_1_K2] <= 1;
        user         [2][INDEX_IS_COLS_1_K2] <= 1;
        user         [3][INDEX_IS_COLS_1_K2] <= 1;
        user         [4][INDEX_IS_COLS_1_K2] <= 1;
        user         [5][INDEX_IS_COLS_1_K2] <= 1;
        user         [6][INDEX_IS_COLS_1_K2] <= 1;
        @(posedge aclk);
        valid_last <= {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};
        user         [0][INDEX_IS_COLS_1_K2] <= 0;
        user         [1][INDEX_IS_COLS_1_K2] <= 0;
        user         [2][INDEX_IS_COLS_1_K2] <= 0;
        user         [3][INDEX_IS_COLS_1_K2] <= 0;
        user         [4][INDEX_IS_COLS_1_K2] <= 0;
        user         [5][INDEX_IS_COLS_1_K2] <= 0;
        user         [6][INDEX_IS_COLS_1_K2] <= 0;

        #(CLK_PERIOD*3)
        @(posedge aclk);
        valid_last <= {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};
        @(posedge aclk);
        valid_last <= {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};

        #(CLK_PERIOD*3)
        @(posedge aclk);
        valid_last <= {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};
        @(posedge aclk);
        valid_last <= {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};

        #(CLK_PERIOD*3)
        @(posedge aclk);
        valid_last <= {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};
        @(posedge aclk);
        valid_last <= {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};

        #(CLK_PERIOD*3)
        @(posedge aclk);
        valid_last <= {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};
        @(posedge aclk);
        valid_last <= {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};

        #(CLK_PERIOD*3)
        @(posedge aclk);
        valid_last <= {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};
        @(posedge aclk);
        valid_last <= {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};

        #(CLK_PERIOD*3)
        @(posedge aclk);
        valid_last <= {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};
        @(posedge aclk);
        valid_last <= {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};

        #(CLK_PERIOD*3)
        @(posedge aclk);
        valid_last <= {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};
        @(posedge aclk);
        valid_last <= {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};

        #(CLK_PERIOD*3)
        @(posedge aclk);
        valid_last <= {1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1};
        @(posedge aclk);
        valid_last <= {1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0};


    end

endmodule