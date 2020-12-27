/*//////////////////////////////////////////////////////////////////////////////////
Group : ABruTECH
Engineer: Abarajithan G.

Create Date: 14/07/2020
Design Name: Step Buffer
Tool Versions: Vivado 2018.2
Description:
        * 1x1 : All datapaths are delayed by one clock
                - Zero relative delay between datapaths, they move together
                - Output is registered to help performace and fanout, since
                    one image_buffer feeds upto 16 cores and
                    one weights_buffer feeds 8 units

        * nxm : Delays data (for nxm convolution) in steps such that each datapath is (A-2)
                clocks behind the previous, to ensure following operation in 
                perfect sync within the conv unit.

            1. last data from multiplier comes to mux_s1[i]
                * Directly goes into acc_s[i]
                * Clearing the accumulator with it
                * mul_m_last[i] that comes with it gets delayed (enters  mux_sel[i])

            2. On next data beat, last data from acc_s[i-1] comes into mux_s2[i]
                * mux_sel[i] is asserted, mux[i] allows mux_s2[i] into acc_s[i]
                * acc_s[i-1] enters acc_s[i], as 1st data of new accumulation
                    its tlast is not allowed to pass
                * All multipliers are disabled
                * All accumulators, except [i] are disabled
                * acc_s[i] accepts acc_s[i-1]
                * "bias" has come to the mul_s[i] and waits
                    as multipler pipeline is disabled

            3. On next data_beat, mux_sel[i] is updated (deasserted)
                * BECAUSE acc_s_valid_[i-1] was high in prev clock
                * mux[i] allows mux_s1[i] into acc_s[i]
                * acc_s[i] accepts bias as 2nd data of new accumulation
                * all multipliers and other accumulators resume operation

            - If last data from acc_s[i-1] doesn't follow last data of mul_s[i]:
                - mux_sel[i] will NOT be deasserted (updated)
                - multipliers and other accumulators will freeze forever
            - For this sync to happen:
                - datapath[i] should be delayed by DELAY clocks than datapath[i-1]
                - DELAY = (A-1) -1 = (A-2)
                    - When multipliers are frozen, each accumulator works 
                        one extra clock than its corresponding multiplier,
                        in (2), to accept other acc_s value. This means, the
                        relative delay of accumulator is (A-1) 
                        as seen by a multiplier
                    - If (A-1), both mul_s[i] and acc_s[i-1] will give tlast together
                    - (-1) ensures mul_s[i] comes first

Revision:
Revision 0.01 - File Created
Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////*/

module step_buffer  #(
    parameter WORD_WIDTH       ,
    parameter STEPS            ,
    parameter ACCUMULATOR_DELAY,
    parameter TUSER_WIDTH      
)(
    aclk,
    aclken,
    aresetn,

    is_1x1,

    s_valid,
    s_data,
    s_last,
    s_user,

    m_valid,
    m_data,
    m_last,
    m_user
);

    input  wire aclk;
    input  wire aclken;
    input  wire aresetn;
    input  wire is_1x1;
  
    // N-delay'i slaves

    input wire                      s_valid  [STEPS-1 : 0];
    input wire [WORD_WIDTH  - 1: 0] s_data   [STEPS-1 : 0];
    input wire                      s_last   [STEPS-1 : 0];
    input wire [TUSER_WIDTH - 1: 0] s_user   [STEPS-1 : 0];

    // Hold'i master
    
    output wire                      m_valid [STEPS-1 : 0];
    output wire [WORD_WIDTH  - 1: 0] m_data  [STEPS-1 : 0];
    output wire                      m_last  [STEPS-1 : 0];
    output wire [TUSER_WIDTH - 1: 0] m_user  [STEPS-1 : 0];
    
    // N-delay'i master

    wire                      delay_m_valid  [STEPS-1 : 0];
    wire [WORD_WIDTH  - 1: 0] delay_m_data   [STEPS-1 : 0];
    wire                      delay_m_last   [STEPS-1 : 0];
    wire [TUSER_WIDTH - 1: 0] delay_m_user   [STEPS-1 : 0];

    // Hold'i slave

    wire                      hold_s_valid   [STEPS-1 : 0];
    wire [WORD_WIDTH  - 1: 0] hold_s_data    [STEPS-1 : 0];
    wire                      hold_s_last    [STEPS-1 : 0];
    wire [TUSER_WIDTH - 1: 0] hold_s_user    [STEPS-1 : 0];



    genvar i;
    generate

        // DELAYS for i > 0:    i*(ACCUMULATOR_DELAY-1)-(i-1)  = i*(ACCUMULATOR_DELAY-2) + 1

        for (i=1 ;  i < STEPS;  i = i+1) begin : delays_gen
            
            localparam DELAY = i * (ACCUMULATOR_DELAY-2) + 1;

            n_delay_stream #(
                .N              (DELAY),
                .WORD_WIDTH     (WORD_WIDTH),
                .TUSER_WIDTH    (TUSER_WIDTH)
            )
            n_delay_stream_unit
            (
                .aclk           (aclk),
                .aclken         (aclken),
                .aresetn        (aresetn),
                .valid_in       (s_valid        [i]),
                .data_in        (s_data         [i]),
                .last_in        (s_last         [i]),
                .user_in        (s_user         [i]),
                .valid_out      (delay_m_valid  [i]),
                .data_out       (delay_m_data   [i]),
                .last_out       (delay_m_last   [i]),
                .user_out       (delay_m_user   [i])
            );
        end

        for (i=1 ;  i < STEPS;  i = i+1) begin : hold_muxes_gen

            assign m_valid [i] = delay_m_valid [i];
            assign m_data  [i] = delay_m_data  [i];
            assign m_last  [i] = delay_m_last  [i];
            assign m_user  [i] = delay_m_user  [i];
        end

        assign m_valid [0] = s_valid [0];
        assign m_data  [0] = s_data  [0];
        assign m_last  [0] = s_last  [0];
        assign m_user  [0] = s_user  [0];

    endgenerate



endmodule