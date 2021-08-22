/*//////////////////////////////////////////////////////////////////////////////////
Group : ABruTECH
Engineer: Abarajithan G.

Create Date: 04/11/2020
Design Name: MAXPOOL CORE
Tool Versions: Vivado 2018.2
Description: * Performs 2x2 maxpool on input data for constant number of MEMBERS
             * Can optionally give out maxpool and non-maxpool data in consecutive clocks
             * Pulls s_ready down when comparing two stored values
             * TLAST 
                - non-max only
                  * Goes high after all members
                  * 1 packet = members(8) * units(8) * copies(2) * groups(2)   = 32*8 = 256 bytes
                - max-only
                  * Goes high after all members
                  * 1 packet = members(8) * units(8) * copies(2) * groups(2)/2 = 32*8/2 = 128 bytes
                - max-and-non-max
                  - MAX_2_S state
                    * Goes high after all members
                    * 1 packet = members(8) * units(8) * copies(2) * groups(2) = 32*8 = 64 bytes
                  - MAX_4_S state
                    * Goes high at every beat
                    * non-max packet = units(8) * copies(2) * groups(2)   = 32   = 32 bytes
                    * max packet     = units(8) * copies(2) * groups(2)/2 = 32/2 = 16 bytes

Limitations: * For KW != KW_MAX (1x1), can only do non-max

Revision:
Revision 0.01 - File Created
Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////*/

`include "params.v"

module maxpool_engine (
    clk,
    clken,
    resetn,
    debug_config,

    s_valid,
    s_data_flat_cgu,
    s_ready,
    s_user,

    m_valid,
    m_data_flat_cgu,
    m_keep_flat_cgu,
    m_last
  );

  localparam UNITS                      = `UNITS                     ;
  localparam GROUPS                     = `GROUPS                    ;
  localparam MEMBERS                    = `MEMBERS                   ;
  localparam WORD_WIDTH                 = `WORD_WIDTH                ;
  localparam DEBUG_CONFIG_WIDTH_MAXPOOL = `DEBUG_CONFIG_WIDTH_MAXPOOL;
  localparam KERNEL_W_MAX               = `KERNEL_W_MAX              ;
  localparam I_IS_NOT_MAX               = `I_IS_NOT_MAX              ;
  localparam I_IS_MAX                   = `I_IS_MAX                  ;
  localparam I_KERNEL_H_1               = `I_KERNEL_H_1              ;
  localparam BITS_KERNEL_H              = `BITS_KERNEL_H             ;
  localparam TUSER_WIDTH_MAXPOOL_IN     = `TUSER_WIDTH_MAXPOOL_IN;

  input  logic clk, clken, resetn;
  input  logic s_valid;
  output logic m_valid, s_ready, m_last;
  input  logic [TUSER_WIDTH_MAXPOOL_IN   -1:0] s_user;

  input  logic [2*GROUPS*UNITS*WORD_WIDTH-1:0] s_data_flat_cgu;
  output logic [2*GROUPS*UNITS*WORD_WIDTH-1:0] m_data_flat_cgu;
  output logic [2*GROUPS*UNITS-1:0]            m_keep_flat_cgu;

  logic signed [WORD_WIDTH-1:0] s_data_cgu [1:0][GROUPS-1:0][UNITS-1:0];
  logic signed [WORD_WIDTH-1:0] m_data_cgu [1:0][GROUPS-1:0][UNITS-1:0];
  logic                         m_keep_cgu [1:0][GROUPS-1:0][UNITS-1:0];
  
  logic s_handshake;
  localparam SUB_MEMBERS_BITS = $clog2(MEMBERS*KERNEL_W_MAX);
  logic [SUB_MEMBERS_BITS-1:0] in_count, in_count_next, ref_sub_members_1;

  localparam MAX_2_S = 0;
  localparam MAX_4_S = 1;
  logic state, state_en;
  output logic [DEBUG_CONFIG_WIDTH_MAXPOOL-1:0] debug_config;
  assign debug_config = state;

  logic max_4_handshake, max_4_handshake_delay;
  logic sel_max_4_in; 
  logic buf_0_en, buf_n_en, buf_delay_en;
  logic buf_en_m [MEMBERS :0];


  logic signed [WORD_WIDTH-1:0] delay_data_cgu [1:0][GROUPS-1:0][UNITS-1:0];
  logic signed [WORD_WIDTH-1:0] buffer_gum          [GROUPS-1:0][UNITS-1:0][MEMBERS + 2];
  logic signed [WORD_WIDTH-1:0] max_in_1_gu         [GROUPS-1:0][UNITS-1:0];
  logic signed [WORD_WIDTH-1:0] max_in_2_gu         [GROUPS-1:0][UNITS-1:0]; 
  logic signed [WORD_WIDTH-1:0] max_out_gu          [GROUPS-1:0][UNITS-1:0];

  logic out_delay_valid;
  logic out_max_valid, out_max_valid_next;
  logic max_4_max_and_non_max_delay;

  assign s_data_cgu = {>>{s_data_flat_cgu}};
  assign {>>{m_data_flat_cgu}} = m_data_cgu;
  assign {>>{m_keep_flat_cgu}} = m_keep_cgu;

  /*
    Transpose and reshape for comparison

    * Input: s_data_cgu
    * During max, c contains two blocks
    * Comparison should be done for adjacent pixels of u
    * max_out_cgu[c,g,u] = max( s_data_cgu [c,g,u], s_data_cgu [c,g,u+1])

    * For this, we transpose and reshape s_data_cgu into s_data_gup
  */
  logic [WORD_WIDTH-1:0] s_data_flat_gup   [2*GROUPS*UNITS-1:0];
  logic signed [WORD_WIDTH-1:0] s_data_gup [GROUPS-1:0][UNITS-1:0][1:0];
  logic signed [WORD_WIDTH-1:0] s_data_gcu [GROUPS-1:0][1:0][UNITS-1:0];
  generate
    for (genvar c=0; c<2; c++)
      for (genvar g=0; g<GROUPS; g++)
        for (genvar u=0; u<UNITS; u++)
          assign s_data_gcu [g][c][u] = s_data_cgu[c][g][u];
  endgenerate
  assign {>>{s_data_flat_gup}} = s_data_gcu;
  assign s_data_gup = {>>{s_data_flat_gup}};

  assign s_handshake = s_valid && s_ready;

  /*
    STATE LOGIC

    * state = MAX_2_S during 8 (=members) handshakes of pure non maxpool 
              & first 8 handshakes of maxpool
    * state = MAX_4_S during latter 8 handshakes of maxpool : we select max from 4
  */
  logic is_1x1;
  assign is_1x1 = s_user[I_KERNEL_H_1+BITS_KERNEL_H-1:I_KERNEL_H_1] == 0;
  assign ref_sub_members_1 = is_1x1 ? KERNEL_W_MAX * MEMBERS-1 : MEMBERS-1;

  assign in_count_next = (in_count == ref_sub_members_1) ? 0 : in_count  + 1;

  register #(
    .WORD_WIDTH   (SUB_MEMBERS_BITS), 
    .RESET_VALUE  (0)
  ) IN_COUNT (
    .clock        (clk   ),
    .resetn       (resetn),
    .clock_enable (clken && s_handshake),
    .data_in      (in_count_next),
    .data_out     (in_count)
  );

  assign state_en = s_handshake && (in_count == ref_sub_members_1) && s_user[I_IS_MAX];

  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (MAX_2_S)
  ) STATE (
    .clock        (clk   ),
    .resetn       (resetn),
    .clock_enable (clken && state_en),
    .data_in      (~state),
    .data_out     (state )
  );

  /*
    MAX_4_HANDSHAKE DELAY

    * The most important signal
    * goes high one clock after the input handshake at state = MAX_4_S
    * signifies the clockcycle where max inputs chosen from buffers (instead of s_data_uc)
  */

  assign max_4_handshake = s_handshake && (state==MAX_4_S);

  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (0)
  ) MAX_4_HANDSHAKE (
    .clock        (clk   ),
    .resetn       (resetn),
    .clock_enable (clken ),
    .data_in      (max_4_handshake),
    .data_out     (max_4_handshake_delay)
  );

  assign s_ready = ~max_4_handshake_delay;

  // Sel bit for the 2 multiplexer at comparator's inputs
  assign sel_max_4_in = max_4_handshake_delay;

  /*
    BUFFER ENABLES - to save power
  */

  assign buf_0_en = s_user[I_IS_MAX] && (s_handshake || max_4_handshake_delay);
  assign buf_n_en = s_handshake && s_user[I_IS_MAX];
  assign buf_delay_en = s_handshake && s_user[I_IS_NOT_MAX];

  generate
    for (genvar m = 0; m < MEMBERS+1; m++) assign buf_en_m[m] = (m==0) ? buf_0_en : buf_n_en;
  endgenerate

  /*
    Data
  */
  generate
    for (genvar g = 0; g < GROUPS; g++) begin: cores
      for (genvar u=0; u < UNITS; u++) begin: units
        /*
          Delay s_data
        */
        for (genvar c=0; c < 2; c++) begin: two
          register #(
            .WORD_WIDTH   (WORD_WIDTH), 
            .RESET_VALUE  (0)
          ) DATA_DELAY (
            .clock        (clk   ),
            .resetn       (resetn),
            .clock_enable (clken && buf_delay_en),
            .data_in      (s_data_cgu     [c][g][u]),
            .data_out     (delay_data_cgu [c][g][u])
          );
        end

        /*
          BUFFER
        */
        assign buffer_gum [g][u][0] = max_out_gu [g][u];

        for (genvar m=0; m < MEMBERS + 1; m++) begin: bufgen
          register #(
            .WORD_WIDTH   (WORD_WIDTH), 
            .RESET_VALUE  (0)
          ) BUFFER (
            .clock        (clk   ),
            .resetn       (resetn),
            .clock_enable (clken && buf_en_m[m]),
            .data_in      (buffer_gum [g][u][m  ]),
            .data_out     (buffer_gum [g][u][m+1])
          );
        end

        /*
          COMPARATOR
        */
        assign max_out_gu  [g][u] = (max_in_1_gu [g][u] > max_in_2_gu [g][u]) ? max_in_1_gu [g][u] : max_in_2_gu [g][u];
        assign max_in_1_gu [g][u] = sel_max_4_in ? buffer_gum [g][u][1]          : s_data_gup [g][u][0];
        assign max_in_2_gu [g][u] = sel_max_4_in ? buffer_gum [g][u][MEMBERS +1] : s_data_gup [g][u][1];

        /*
          OUTPUT
        */
        assign m_data_cgu [0][g][u] = out_max_valid ? buffer_gum [g][u][1] : delay_data_cgu[0][g][u];
        assign m_data_cgu [1][g][u] = delay_data_cgu [1][g][u];
        
        assign m_keep_cgu [0][g][u] = 1;
        assign m_keep_cgu [1][g][u] = out_max_valid ? 0 : 1;

      end
    end
  endgenerate

  /*
    Valid
  */
  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (0)
  ) OUT_DELAY_VALID (
    .clock        (clk   ),
    .resetn       (resetn),
    .clock_enable (clken ),
    .data_in      (s_handshake && s_user[I_IS_NOT_MAX]),
    .data_out     (out_delay_valid)
  );

  assign out_max_valid_next = s_handshake && s_user[I_IS_MAX] && (state == MAX_4_S);
  n_delay #(
      .N          (2),
      .WORD_WIDTH (1)
  ) OUT_MAX_VALID (
      .clk        (clk         ),
      .resetn     (resetn      ),
      .clken      (clken       ),
      .data_in    (out_max_valid_next),
      .data_out   (out_max_valid     )
  );

  assign m_valid = out_max_valid ? out_max_valid : out_delay_valid;

  /*
    MLAST GENERATION

    * For max-only / non-max only: high at in_count=0
    * For both: max_4_max_and_non_max_delay (this goes low before last out. but then in_count==0 happens there)
  */
  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (0)
  ) MAX_NON_DELAY (
    .clock        (clk   ),
    .resetn       (resetn),
    .clock_enable (clken && s_handshake),
    .data_in      (s_user[I_IS_NOT_MAX] && s_user[I_IS_MAX] && state==MAX_4_S),
    .data_out     (max_4_max_and_non_max_delay)
  );

  assign m_last = (in_count == 0) | max_4_max_and_non_max_delay;

endmodule