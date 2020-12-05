module axis_maxpool_engine #(
    parameter UNITS      = 8,
    parameter GROUPS     = 2,
    parameter MEMEBERS   = 8,
    parameter WORD_WIDTH = 8,

    parameter INDEX_IS_NOT_MAX = 0,
    parameter INDEX_IS_MAX     = 1
  )(
    aclk         ,
    aresetn      ,
    s_axis_tvalid,
    s_axis_tready,
    s_axis_tdata ,
    s_axis_tuser ,
    m_axis_tvalid,
    m_axis_tready,
    m_axis_tdata ,
    m_axis_tkeep ,
    m_axis_tlast 
  );

  input  wire aclk, aresetn;
  input  wire s_axis_tvalid, m_axis_tready;
  output wire m_axis_tvalid, s_axis_tready, m_axis_tlast;
  input  wire [0:1] s_axis_tuser;

  input wire  [GROUPS*UNITS*2*WORD_WIDTH-1:0] s_axis_tdata;
  output wire [GROUPS*UNITS*2*WORD_WIDTH-1:0] m_axis_tdata;
  output wire [GROUPS*UNITS*2-1:0]            m_axis_tkeep;
  wire        [GROUPS*UNITS*2*WORD_WIDTH-1:0] m_data;
  wire        [GROUPS*UNITS*2-1:0]            m_keep;

  wire m_valid, slice_ready, engine_ready, m_last, engine_clken;
  


  /*
    Syncing
  */
  assign engine_clken = slice_ready;
  assign s_axis_tready = engine_ready && slice_ready;

  maxpool_engine #(
    .UNITS            (UNITS           ),
    .GROUPS           (GROUPS          ),
    .MEMEBERS         (MEMEBERS        ),
    .WORD_WIDTH       (WORD_WIDTH      ),
    .INDEX_IS_NOT_MAX (INDEX_IS_NOT_MAX),
    .INDEX_IS_MAX     (INDEX_IS_MAX    )
  )
  engine
  (
    .clk         (aclk         ),
    .clken       (engine_clken ),
    .resetn      (aresetn      ),
    .s_valid     (s_axis_tvalid),
    .s_data_flat (s_axis_tdata ),
    .s_ready     (engine_ready ),
    .s_user      (s_axis_tuser ),
    .m_valid     (m_valid      ),
    .m_data_flat_cgu (m_data       ),
    .m_keep_flat_cgu (m_keep       ),
    .m_last      (m_last       )
  );

  axis_reg_slice_32 slice (
    .aclk           (aclk           ),  // input wire aclk
    .aresetn        (aresetn        ),  // input wire aresetn
    .s_axis_tvalid  (m_valid        ),  // input wire s_axis_tvalid
    .s_axis_tready  (slice_ready    ),  // output wire s_axis_tready
    .s_axis_tdata   (m_data         ),  // input wire [2047 : 0] s_axis_tdata
    .s_axis_tkeep   (m_keep         ),  // input wire [255 : 0] s_axis_tkeep
    .s_axis_tlast   (m_last         ),  // input wire s_axis_tlast

    .m_axis_tvalid  (m_axis_tvalid  ),  // output wire m_axis_tvalid
    .m_axis_tready  (m_axis_tready  ),  // input wire m_axis_tready
    .m_axis_tdata   (m_axis_tdata   ),  // output wire [2047 : 0] m_axis_tdata
    .m_axis_tkeep   (m_axis_tkeep   ),  // output wire [255 : 0] m_axis_tkeep
    .m_axis_tlast   (m_axis_tlast   )   // output wire m_axis_tlast
  );

endmodule

module test_reg_slice_tb();

  reg aclk         =0;  
  reg aresetn      =1;  
  reg s_axis_tvalid=1;  
  reg [0:255] s_axis_tdata ;  
  reg [0:31] s_axis_tkeep ;  
  reg s_axis_tlast =1;  
  reg m_axis_tready=1;  

  wire s_axis_tready;  
  wire m_axis_tvalid;  
  wire [0:255] m_axis_tdata ;  
  wire [0:31] m_axis_tkeep ;  
  wire m_axis_tlast ;  

  axis_reg_slice_32 slice (
    .aclk           (aclk           ),  // input wire aclk
    .aresetn        (aresetn        ),  // input wire aresetn
    .s_axis_tvalid  (s_axis_tvalid  ),  // input wire s_axis_tvalid
    .s_axis_tready  (s_axis_tready  ),  // output wire s_axis_tready
    .s_axis_tdata   (s_axis_tdata   ),  // input wire [2047 : 0] s_axis_tdata
    .s_axis_tkeep   (s_axis_tkeep   ),  // input wire [255 : 0] s_axis_tkeep
    .s_axis_tlast   (s_axis_tlast   ),  // input wire s_axis_tlast
    .m_axis_tvalid  (m_axis_tvalid  ),  // output wire m_axis_tvalid
    .m_axis_tready  (m_axis_tready  ),  // input wire m_axis_tready
    .m_axis_tdata   (m_axis_tdata   ),  // output wire [2047 : 0] m_axis_tdata
    .m_axis_tkeep   (m_axis_tkeep   ),  // output wire [255 : 0] m_axis_tkeep
    .m_axis_tlast   (m_axis_tlast   )   // output wire m_axis_tlast
  );

  always begin
    #5 aclk = ~aclk;
  end

  initial begin
    @(posedge aclk);
    @(posedge aclk);
    @(posedge aclk);
    s_axis_tdata <= 111;
    s_axis_tkeep <= 10;
  end


endmodule