
`include "params.v"

module axis_conv_engine #(ZERO) (
    aclk                 ,
    aresetn              ,
    s_axis_tvalid        ,
    s_axis_tready        ,
    s_axis_tlast         ,
    s_axis_tuser         ,
    s_axis_tdata_pixels_1,
    s_axis_tdata_pixels_2,
    s_axis_tdata_weights ,
    m_axis_tvalid        ,
    m_axis_tready        ,
    m_axis_tdata         ,
    m_axis_tkeep         ,
    m_axis_tlast         ,
    m_axis_tuser         
  );

  localparam COPIES              = `COPIES              ;
  localparam GROUPS              = `GROUPS              ;
  localparam MEMBERS             = `MEMBERS             ;
  localparam UNITS               = `UNITS               ;
  localparam WORD_WIDTH_IN       = `WORD_WIDTH          ; 
  localparam WORD_WIDTH_OUT      = `WORD_WIDTH_ACC      ; 
  localparam TUSER_WIDTH_CONV_IN = `TUSER_WIDTH_CONV_IN ;
  localparam TUSER_WIDTH_CONV_OUT= `TUSER_WIDTH_LRELU_IN;

  input  wire aclk;
  input  wire aresetn;
  input  wire s_axis_tvalid;
  output wire s_axis_tready;
  input  wire s_axis_tlast;
  input  wire m_axis_tready;
  input  wire [TUSER_WIDTH_CONV_IN                -1:0] s_axis_tuser;
  input  wire [WORD_WIDTH_IN*UNITS                -1:0] s_axis_tdata_pixels_1;
  input  wire [WORD_WIDTH_IN*UNITS                -1:0] s_axis_tdata_pixels_2;
  input  wire [WORD_WIDTH_IN*COPIES*GROUPS*MEMBERS-1:0] s_axis_tdata_weights;

  wire slice_s_axis_tready;
  wire slice_s_axis_tvalid;
  wire slice_s_axis_tlast ;

  wire [COPIES*GROUPS*MEMBERS*UNITS*WORD_WIDTH_OUT-1:0] slice_s_axis_tdata;
  wire [MEMBERS*TUSER_WIDTH_CONV_OUT-1:0] slice_s_axis_tuser;
  wire [COPIES*GROUPS*MEMBERS*UNITS*WORD_WIDTH_OUT/8-1:0] slice_s_axis_tkeep;

  logic [WORD_WIDTH_OUT      -1:0]   slice_s_data [COPIES -1:0][GROUPS-1:0][MEMBERS-1:0][UNITS-1:0];
  logic [TUSER_WIDTH_CONV_OUT-1:0]   slice_s_user [MEMBERS-1:0];
  logic [WORD_WIDTH_OUT/8    -1:0]   slice_s_keep [COPIES -1:0][GROUPS-1:0][MEMBERS-1:0][UNITS-1:0]; 
  logic [WORD_WIDTH_OUT      -1:0]   m_data       [COPIES -1:0][GROUPS-1:0][MEMBERS-1:0][UNITS-1:0];
  logic [TUSER_WIDTH_CONV_OUT-1:0]   m_user       [MEMBERS-1:0];
  logic [WORD_WIDTH_OUT/8    -1:0]   m_keep       [COPIES -1:0][GROUPS-1:0][MEMBERS-1:0][UNITS-1:0]; 

  output wire m_axis_tvalid;
  output wire m_axis_tlast ;
  output wire [COPIES*GROUPS*MEMBERS*UNITS*WORD_WIDTH_OUT-1:0] m_axis_tdata;
  output wire [MEMBERS*TUSER_WIDTH_CONV_OUT-1:0] m_axis_tuser;
  output wire [COPIES*GROUPS*MEMBERS*UNITS*WORD_WIDTH_OUT/8-1:0] m_axis_tkeep;

  assign {>>{m_axis_tdata}} = m_data;
  assign {>>{m_axis_tuser}} = m_user;
  assign {>>{m_axis_tkeep}} = m_keep;
  assign slice_s_data = {>>{slice_s_axis_tdata}};
  assign slice_s_user = {>>{slice_s_axis_tuser}};
  assign slice_s_keep = {>>{slice_s_axis_tkeep}};


  conv_engine #(.ZERO(ZERO)) ENGINE (
    .clk          (aclk),
    .clken        (slice_s_axis_tready),
    .resetn       (aresetn            ),
    .s_valid      (s_axis_tvalid      ),
    .s_ready      (s_axis_tready      ),
    .s_last       (s_axis_tlast       ),
    .s_user       (s_axis_tuser       ),
    .m_valid      (slice_s_axis_tvalid),
    .m_data_flat  (slice_s_axis_tdata ),
    .m_last       (slice_s_axis_tlast ),
    .m_user_flat  (slice_s_axis_tuser ),
    .m_keep_flat  (slice_s_axis_tkeep ),
    .s_data_pixels_1_flat (s_axis_tdata_pixels_1),
    .s_data_pixels_2_flat (s_axis_tdata_pixels_2),
    .s_data_weights_flat  (s_axis_tdata_weights )
  );

  generate
    for (genvar c=0; c<COPIES; c=c+1) begin
      for (genvar g=0; g<GROUPS; g=g+1) begin
        for (genvar m=0; m<MEMBERS; m=m+1) begin

          logic [UNITS*WORD_WIDTH_OUT  -1:0] slice_s_data_flat, slice_m_data_flat;
          assign {>>{slice_s_data_flat}} = slice_s_data [c][g][m];
          assign m_data [c][g][m] = {>>{slice_m_data_flat}};


          if (c==0 && g==0) begin

            logic [UNITS*WORD_WIDTH_OUT/8-1:0] slice_s_keep_flat, slice_m_keep_flat;
            assign {>>{slice_s_keep_flat}} = slice_s_keep [c][g][m];
            assign m_keep [c][g][m] = {>>{slice_m_keep_flat}};

            if (m==0)
              slice_conv_active slice (
                .aclk           (aclk                    ),
                .aresetn        (aresetn                 ),
                .s_axis_tvalid  (slice_s_axis_tvalid     ),
                .s_axis_tready  (slice_s_axis_tready     ),
                .s_axis_tdata   (slice_s_data_flat       ),
                .s_axis_tuser   (slice_s_user         [m]),  
                .s_axis_tkeep   (slice_s_keep_flat       ),  
                .s_axis_tlast   (slice_s_axis_tlast      ),  
                .m_axis_tvalid  (m_axis_tvalid           ),
                .m_axis_tready  (m_axis_tready           ),
                .m_axis_tdata   (slice_m_data_flat       ),
                .m_axis_tuser   (m_user               [m]),
                .m_axis_tkeep   (slice_m_keep_flat       ),
                .m_axis_tlast   (m_axis_tlast            )
              );
            else
              slice_conv_semi_active slice (
                .aclk           (aclk                    ),
                .aresetn        (aresetn                 ),
                .s_axis_tvalid  (slice_s_axis_tvalid     ),
                .s_axis_tdata   (slice_s_data_flat       ),
                .s_axis_tkeep   (slice_s_keep_flat       ),  
                .s_axis_tuser   (slice_s_user         [m]),  
                .m_axis_tready  (m_axis_tready           ),
                .m_axis_tdata   (slice_m_data_flat       ),
                .m_axis_tkeep   (slice_m_keep_flat       ),
                .m_axis_tuser   (m_user               [m])
              );
          end
          else begin
            slice_conv slice (
              .aclk           (aclk                    ),
              .aresetn        (aresetn                 ),
              .s_axis_tvalid  (slice_s_axis_tvalid     ),
              .s_axis_tdata   (slice_s_data_flat       ),
              .m_axis_tready  (m_axis_tready           ),
              .m_axis_tdata   (slice_m_data_flat       )
            );
            assign m_keep [c][g][m] = m_keep [0][0][m];
          end
        end
      end
    end
  endgenerate
endmodule