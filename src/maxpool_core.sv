/*//////////////////////////////////////////////////////////////////////////////////
Group : ABruTECH
Engineer: Abarajithan G.

Create Date: 04/11/2020
Design Name: MAXPOOL CORE
Tool Versions: Vivado 2018.2
Description: * Performs 2x2 maxpool on input data
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
                  - MAX_2 state
                    * Goes high after all members
                    * 1 packet = members(8) * units(8) * copies(2) * groups(2) = 32*8 = 64 bytes
                  - MAX_4 state
                    * Goes high at every beat
                    * non-max packet = units(8) * copies(2) * groups(2)   = 32   = 32 bytes
                    * max packet     = units(8) * copies(2) * groups(2)/2 = 32/2 = 16 bytes

Revision:
Revision 0.01 - File Created
Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////*/


module maxpool_core #(
    parameter UNITS      = 2,
    parameter MEMEBERS   = 8,
    parameter WORD_WIDTH = 8,

    parameter INDEX_IS_NOT_MAX = 0,
    parameter INDEX_IS_MAX     = 1
  )(
    clk,
    clken,
    resetn,

    s_valid,
    s_data,
    s_ready,
    s_user,

    m_valid,
    m_data,
    m_keep,
    m_last
  );
  typedef logic signed [WORD_WIDTH-1:0] word_t;

  input  logic clk, clken, resetn;
  input  logic s_valid;
  output logic m_valid, s_ready, m_last;
  input  logic [0:1] s_user;

  input  word_t s_data [UNITS][2];
  output word_t m_data [UNITS][2];
  output logic  m_keep [UNITS][2];

  logic s_handshake;
  assign s_handshake = s_valid && s_ready;
  
  /*
    STATE LOGIC

    * state = MAX_2 during 8 (=members) handshakes of pure non maxpool 
              & first 8 handshakes of maxpool
    * state = MAX_4 during latter 8 handshakes of maxpool : we select max from 4
  */
  localparam MEMEBERS_BITS = $clog2(MEMEBERS);
  logic [MEMEBERS_BITS-1:0] in_count, in_count_next;

  assign in_count_next = (in_count == MEMEBERS-1) ? 0 : in_count  + 1;

  register #(
    .WORD_WIDTH   (MEMEBERS_BITS), 
    .RESET_VALUE  (0)
  ) IN_COUNT (
    .clock        (clk   ),
    .resetn       (resetn),
    .clock_enable (clken && s_handshake),
    .data_in      (in_count_next),
    .data_out     (in_count)
  );

  localparam MAX_2 = 0;
  localparam MAX_4 = 1;
  logic state, state_trigger;

  assign state_trigger = s_handshake && (in_count == MEMEBERS-1) && s_user[INDEX_IS_MAX];

  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (MAX_2)
  ) STATE (
    .clock        (clk   ),
    .resetn       (resetn),
    .clock_enable (clken && state_trigger),
    .data_in      (~state),
    .data_out     (state )
  );

  /*
    MAX_4_HANDSHAKE DELAY

    * The most important signal
    * goes high one clock after the input handshake at state = MAX_4
    * signifies the clockcycle where max inputs chosen from buffers (instead of s_data)
  */
  logic max_4_handshake, max_4_handshake_delay;
  assign max_4_handshake = s_handshake && (state==MAX_4);

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
  logic sel_max_4_in; 
  assign sel_max_4_in = max_4_handshake_delay;

  /*
    BUFFER ENABLES - to save power
  */
  logic buf_0_en, buf_n_en, buf_delay_en;

  assign buf_0_en = s_user[INDEX_IS_MAX] && (s_handshake || max_4_handshake_delay);
  assign buf_n_en = s_handshake && s_user[INDEX_IS_MAX];
  assign buf_delay_en = s_handshake && s_user[INDEX_IS_NOT_MAX];


  /*
    OUTPUT
  */
  logic  out_delay_valid;
  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (0)
  ) OUT_DELAY_VALID (
    .clock        (clk   ),
    .resetn       (resetn),
    .clock_enable (clken ),
    .data_in      (s_handshake && s_user[INDEX_IS_NOT_MAX]),
    .data_out     (out_delay_valid)
  );

  logic out_max_valid, out_max_valid_next;
  assign out_max_valid_next = s_handshake && s_user[INDEX_IS_MAX] && (state == MAX_4);
  n_delay #(
      .N          (2),
      .DATA_WIDTH (1)
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
  logic max_4_max_and_non_max_delay;
  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (0)
  ) MAX_NON_DELAY (
    .clock        (clk   ),
    .resetn       (resetn),
    .clock_enable (clken && s_handshake),
    .data_in      (s_user[INDEX_IS_NOT_MAX] && s_user[INDEX_IS_MAX] && state==MAX_4),
    .data_out     (max_4_max_and_non_max_delay)
  );

  assign m_last = (in_count == 0) | max_4_max_and_non_max_delay;


  generate
    for (genvar u=0; u < UNITS; u++) begin: units
      /*
        Delay s_data
      */
      word_t out_delay_data  [2];
      for (genvar c=0; c < 2; c++) begin: two
        register #(
          .WORD_WIDTH   (WORD_WIDTH), 
          .RESET_VALUE  (0)
        ) DATA_DELAY (
          .clock        (clk   ),
          .resetn       (resetn),
          .clock_enable (clken && buf_delay_en),
          .data_in      (s_data     [u][c]),
          .data_out     (out_delay_data[c])
        );
      end

      /*
        BUFFER
      */
      word_t buffer [MEMEBERS + 2];
      assign buffer[0] = max_out;

      for (genvar i=0; i < MEMEBERS + 1; i++) begin: bufgen

        logic buf_en;
        assign buf_en = (i==0) ? buf_0_en : buf_n_en;

        register #(
          .WORD_WIDTH   (WORD_WIDTH), 
          .RESET_VALUE  (0)
        ) BUFFER (
          .clock        (clk   ),
          .resetn       (resetn),
          .clock_enable (clken && buf_en),
          .data_in      (buffer [i  ]),
          .data_out     (buffer [i+1])
        );
      end

      /*
        COMPARATOR
      */
      word_t max_in_1, max_in_2, max_out;
      assign max_out = (max_in_1 > max_in_2) ? max_in_1 : max_in_2;

      assign max_in_1 = sel_max_4_in ? buffer[1] : s_data[u][0];
      assign max_in_2 = sel_max_4_in ? buffer[MEMEBERS+1] : s_data[u][1];

      /*
        OUTPUT
      */
      assign m_data [u][0] = out_max_valid ? buffer[1] : out_delay_data[0];
      assign m_data [u][1] = out_delay_data[1];
      
      assign m_keep [u][0] = 1;
      assign m_keep [u][1] = out_max_valid ? 0 : 1;

    end
  endgenerate

endmodule