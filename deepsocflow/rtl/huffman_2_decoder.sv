// // https://ieeexplore.ieee.org/stamp/stamp.jsp?arnumber=7801877

// module huffman_2_decoder #(
//   parameter  M_WIDTH = 4,
//   localparam S_WIDTH = M_WIDTH +1
// )(
//   input  logic clk,
//   input  logic rstn,
//   input  logic s_valid,
//   output logic s_ready, // r_en
//   input  logic [S_WIDTH: 0] s_data,
//   output logic m_valid,
//   input  logic m_ready,
//   output logic [M_WIDTH-1:0] m_data
// );

//   localparam  W_BUFFER  = S_WIDTH*2, 
//               W_INDEX   = $clog2(W_BUFFER+1);
  
//   logic [W_BUFFER-1:0] buffer;
//   logic [W_INDEX -1:0] wr_ptr, wr_ptr_next;

//   wire s_beat = s_ready && s_valid;
//   wire m_beat = m_ready && m_valid;

//   always_ff @(posedge clk)
//     if (m_beat && s_beat)
//       if (buffer[0]) buffer <= { buffer[S_WIDTH:wr_ptr-1]};

//       buffer [wr_ptr + S_WIDTH-1: wr_ptr] <= s_data;

//   always_ff @(posedge clk)
//     wr_ptr <= !rstn ? '0 : wr_ptr_next;

//   assign s_ready = (wr_ptr <= S_WIDTH);
//   assign m_valid = (wr_ptr >= M_WIDTH);
//   assign m_data  = buffer [M_WIDTH:1]; // exclude lsb

//   always_comb
//     if (m_beat)
//       if (buffer[0]) 



// endmodule