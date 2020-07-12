
//////////////////////////////////////////////////////////////////////////////////
// Group : ABruTECH
// Engineer: Abarajithan G.
// 
// Create Date: 11/07/2020
// Design Name: AXIS Shell
// Tool Versions: Vivado 2018.2
// Description: A wrapper that can convert any dumb module (adder, multiplier..)
//              with constant delay into an AXI Stream module
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
//
// Additional Comments: This expects the downstream module to follow AXI Stream
//                      guideline of keeping s_ready high whenever possible.
//                      The data is not pushed, only pulled through negative pressue
//                      (from downstream) to flush the dumb pipe properly.
//
//                      Two valid ways: using reg_slice IP or skid_buffer (both verified)
// 
//////////////////////////////////////////////////////////////////////////////////

module axis_shell #(
    parameter DATA_WIDTH,
    parameter DELAY
)(
    aclk,
    aresetn,

    S_AXIS_tdata,
    S_AXIS_tvalid,
    S_AXIS_tready,
    S_AXIS_tlast,

    M_AXIS_tdata,
    M_AXIS_tvalid,
    M_AXIS_tready,
    M_AXIS_tlast
);

    input   wire  aclk;
    input   wire  aresetn;
    input   wire  [DATA_WIDTH - 1 : 0]  S_AXIS_tdata;
    input   wire                        S_AXIS_tvalid;
    output  wire                        S_AXIS_tready;
    input   wire                        S_AXIS_tlast;

    output  wire  [DATA_WIDTH - 1 : 0]  M_AXIS_tdata;
    output  wire                        M_AXIS_tvalid;
    input   wire                        M_AXIS_tready;
    output  wire                        M_AXIS_tlast;

    /*
    PULL (CLOCK_ENABLE)

    * Data is pulled ONLY using negative pressure.
    * If insert is used, pipe will not get flushed after slave interface
        finishes inserting data.
    * If remove is used, pipe will not get flushed once an invalid data
        appears on the output side of pipe.
    * S_axis_tready is M_axis_tready delayed by 1 (also registered)
    * If (S_axis_tready == 0), no handshake, do not insert.

    */
    wire pull;
    assign pull = S_AXIS_tready;

    /*
    GUARD REGISTERS

    * s_data is ANDed with s_valid to make sure all invalid data is zero.
    * This reduces (?) power consumption when pulling with m_ready
    * Also, it avoids unnessary data corrupting a multiplier, accumulator or adder
    * Result is buffered in guard register
    * s_valid and s_tlast also buffered once to keep them tied to data

    */
    wire [DATA_WIDTH-1 : 0] data_guard_in;
    wire [DATA_WIDTH-1 : 0] data_guard_out;
    wire                    valid_guard_out;
    wire                    last_guard_out;

    assign data_guard_in = S_AXIS_tdata & {DATA_WIDTH{S_AXIS_tvalid}};

    register
    #(
        .WORD_WIDTH     (DATA_WIDTH),
        .RESET_VALUE    (0)
    )
    s_data_guard_reg
    (
        .clock          (aclk),
        .clock_enable   (pull),
        .resetn         (aresetn),
        .data_in        (data_guard_in),
        .data_out       (data_guard_out)
    );

    register
    #(
        .WORD_WIDTH     (1),
        .RESET_VALUE    (0)
    )
    s_valid_guard_reg
    (
        .clock          (aclk),
        .clock_enable   (pull),
        .resetn         (aresetn),
        .data_in        (S_AXIS_tvalid),
        .data_out       (valid_guard_out)
    );

    register
    #(
        .WORD_WIDTH     (1),
        .RESET_VALUE    (0)
    )
    s_last_guard_reg
    (
        .clock          (aclk),
        .clock_enable   (pull),
        .resetn         (aresetn),
        .data_in        (S_AXIS_tlast),
        .data_out       (last_guard_out)
    );

    /*
    DELAY MODULES

    * Replace "data_delay_module" with any dumb module
    * valid and tlast are delayed accordingly

    */

    wire [DATA_WIDTH-1 : 0] data_delay_out;
    wire                    valid_delay_out;
    wire                    last_delay_out;

    n_delay #(
        .N(DELAY),
        .DATA_WIDTH(DATA_WIDTH)
    )
    data_delay_module
    (
        .clk(aclk),
        .resetn(aresetn),
        .clken(pull),
        .data_in(data_guard_out),
        .data_out(data_delay_out)
    );

    n_delay #(
        .N(DELAY),
        .DATA_WIDTH(1)
    )
    s_valid_delay_reg
    (
        .clk(aclk),
        .resetn(aresetn),
        .clken(pull),
        .data_in(valid_guard_out),
        .data_out(valid_delay_out)
    );

    n_delay #(
        .N(DELAY),
        .DATA_WIDTH(1)
    )
    s_last_delay_reg
    (
        .clk(aclk),
        .resetn(aresetn),
        .clken(pull),
        .data_in(last_guard_out),
        .data_out(last_delay_out)
    );

    /*
    REGISTER SLICE IP
    * Placed after guard and N-delay
    * IP must be generated with correct data width
    */

    axis_reg_slice axis_reg_slice_ip(
        .aclk(aclk),
        .aresetn(aresetn),

        .s_axis_tvalid(valid_delay_out),
        .s_axis_tready(S_AXIS_tready),
        .s_axis_tdata(data_delay_out),
        .s_axis_tlast(last_delay_out),

        .m_axis_tvalid(M_AXIS_tvalid),
        .m_axis_tready(M_AXIS_tready),
        .m_axis_tdata(M_AXIS_tdata),
        .m_axis_tlast(M_AXIS_tlast)
    );

    /*
    CUSTOM SKID BUFFER -------------------------------------------------------

    * Placed after guard and N-delay
    * Tlast and data and concated and given

    */

    // wire [(DATA_WIDTH + 1) - 1 : 0] data_skid_in;
    // wire [(DATA_WIDTH + 1) - 1 : 0] data_skid_out;

    // assign data_skid_in  = {last_delay_out, data_delay_out};
    // assign M_AXIS_tdata  = data_skid_out[DATA_WIDTH-1:0];
    // assign M_AXIS_tlast  = data_skid_out[DATA_WIDTH  : DATA_WIDTH];

    // axis_skid_reg
    // #(
    //     .WORD_WIDTH (DATA_WIDTH + 1) // data + last
    // )
    // axis_data_skid_reg
    // (
    //     .clock(aclk),
    //     .resetn(aresetn),

    //     .input_valid    (valid_delay_out),
    //     .input_ready    (S_AXIS_tready),
    //     .input_data     (data_skid_in),

    //     .output_valid   (M_AXIS_tvalid),
    //     .output_ready   (M_AXIS_tready),
    //     .output_data    (data_skid_out)
    // );

endmodule