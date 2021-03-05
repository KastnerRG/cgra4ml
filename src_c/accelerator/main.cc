
#include "xparameters.h"
#include "xdebug.h"
#include "xstatus.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "xstatus.h"
#include <machine/_default_types.h>
#include <cmath>
#include <iostream>

#if (!defined(DEBUG))
extern void xil_printf(const char *format, ...);
#endif

#include "params.h"
#include "D:/cnn-fpga/src_c/zynq-oop-drivers/dma/my_dma.h"
#include "cnn.h"


int status;
bool done = false;
#define I_LAYER 3-1

const std::array<Layer, N_LAYERS> layers = build_yolo_mod();
const chunk_s chunk_a = {(s8*) IMAGE_RGB_A_P, {(s8*) DATA_A0_P, (s8*) DATA_A1_P} };
const chunk_s chunk_b = {(s8*) IMAGE_RGB_B_P, {(s8*) DATA_B0_P, (s8*) DATA_B1_P} };

My_DMA dma_im_in_1("im_in_1", XPAR_DMA_IM_IN_1_DEVICE_ID);
My_DMA dma_im_in_2("im_in_2", XPAR_DMA_IM_IN_2_DEVICE_ID);
My_DMA dma_weights("weights", XPAR_DMA_WEIGHTS_DEVICE_ID);
My_DMA dma_im_out ("im_out", XPAR_DMA_IM_OUT_DEVICE_ID);


void restart_weights()
{
	static int i_itr = 0, i_layers = I_LAYER;
	static s8* weights_read_p = (s8*)WEIGHTS_P;

	status = dma_weights.mm2s_start( (UINTPTR)weights_read_p, layers[i_layers].WORDS_WEIGHTS_PER_ITR);

	xil_printf("---------weights restarted. Reading from (i_layers,i_itr,:):\t (%d/%d, %d/%d, %d);\t ptr:%p \r\n",
				i_layers,N_LAYERS,
				i_itr	,layers[i_layers].ITR,
				layers[i_layers].WORDS_WEIGHTS_PER_ITR,
				weights_read_p);

	weights_read_p += layers[i_layers].WORDS_WEIGHTS_PER_ITR;

	/* prepare next indices */

	if (i_itr < layers[i_layers].ITR-1)
		i_itr += 1;
	else
	{
		i_itr = 0;

		if(i_layers < N_LAYERS-1)
			i_layers += 1;
		else
		{
			i_layers = 0;
			weights_read_p = (s8*)WEIGHTS_P;
		}
	}
}

void restart_pixels()
{
	static int i_itr = 0, i_layers = I_LAYER;

	status = dma_im_in_1.mm2s_start((UINTPTR) chunk_a.data_ps[0], layers[i_layers].WORDS_PIXELS_0);
	if (layers[i_layers].IS_MAX)
		status = dma_im_in_2.mm2s_start((UINTPTR) chunk_a.data_ps[1], layers[i_layers].WORDS_PIXELS_1);

	xil_printf("----------pixels restarted. Reading from (i_layers,i_itr,:):\t (%d/%d, %d/%d, [%d,%d]);\t ptr: [%p, %p] \r\n",
			i_layers,N_LAYERS,
			i_itr	,layers[i_layers].ITR,
			layers[i_layers].WORDS_PIXELS_0, layers[i_layers].WORDS_PIXELS_1,
			chunk_a.data_ps[0], chunk_a.data_ps[1]);

	/* prepare next indices */

	if (i_itr < layers[i_layers].ITR-1)
		i_itr += 1;
	else
	{
		i_itr = 0;

		if(i_layers < N_LAYERS-1) i_layers += 1;
		else					  i_layers = 0;
	}
}
void callback_image_2_mm2s_done()
{
	xil_printf("image_1 mm2s_done \r\n");
}

#define DEBUG_PAD

void pad(volatile s8** write_ps_next,
		int& i_arr_next,
		int& i_blocks_next,
		bool& is_new_itr_next,
		int& itr_offset_next,
		int& i_layers_next,
		bool& is_new_layer_next
#if defined DEBUG && defined DEBUG_PAD
		,int& i_w_next, int&i_itr_next
#endif
		)
{
	/* Called with params of ongoing transaction.
	 * Those are stored. Prev params are used to pad
	 * */

	static bool is_sys_start = true;
	static int i_arr, i_blocks, i_layers;
	static volatile s8 * pad_this_ps [2] = {nullptr, nullptr};
	static volatile s8 * pad_prev_ps [2] = {chunk_b.data_ps[0] + UNITS_EDGES, chunk_b.data_ps[1]};
#ifdef DEBUG
	static int i_w, i_itr;
#endif

	int i_arr_prev = (i_blocks-1)%layers[i_layers].MAX_FACTOR;

	if (is_sys_start) is_sys_start = false;
	else
	{
		for (int i_eff_cout=0; i_eff_cout < layers[i_layers].EFF_CORES; i_eff_cout++)
		{
			if (i_blocks != 0)
			{
				for (int i_kh2=0; i_kh2 < layers[i_layers].KH_IN/2; i_kh2++)
				{
					int i_prev_to   = KH_MAX/2 +UNITS + i_kh2;
					int i_this_from = KH_MAX/2 + i_kh2;

					pad_prev_ps[i_arr_prev][i_prev_to] = pad_this_ps[i_arr][i_this_from];

					int i_this_to   = KH_MAX/2-1 - i_kh2;
					int i_prev_from = KH_MAX/2 +UNITS-1 - i_kh2;

					pad_this_ps[i_arr][i_this_to] = pad_prev_ps[i_arr_prev][i_prev_from];

//					xil_printf("\t P[%d]<-T[%d]; \t P[%d]->T[%d]", i_prev_to, i_this_from, i_prev_from, i_this_to);
				}
				pad_prev_ps[i_arr_prev] += UNITS_EDGES;

#if defined DEBUG && defined DEBUG_PAD
			const s8* im_p [2] = {chunk_b.data_ps[0] + UNITS_EDGES, chunk_b.data_ps[1]};
			xil_printf("Padded [%p <-> %p] (arr,blocks,w,itr,eff_cores,ue): (%d,%d,%d,%d,%d,%d)->(%d,%d,%d,%d,%d,%d) {%d} \t (%d,%d,%d,%d,%d,%d)<-(%d,%d,%d,%d,%d,%d) {%d}  \r\n",
					(UINTPTR)(pad_prev_ps[i_arr_prev]-im_p[i_arr_prev]), (UINTPTR)(pad_this_ps[i_arr]+(i_eff_cout*UNITS_EDGES) -im_p[i_arr]),

					i_arr,i_blocks-1,i_w,i_itr,i_eff_cout,UNITS_EDGES-1,
					i_arr,i_blocks,i_w,i_itr,i_eff_cout,0,
					pad_prev_ps[i_arr_prev][UNITS_EDGES-2],

					i_arr,i_blocks-1,i_w,i_itr,i_eff_cout,UNITS_EDGES,
					i_arr,i_blocks,i_w,i_itr,i_eff_cout,1,
					pad_this_ps[i_arr][1]);
#endif
			}
			pad_this_ps[i_arr] += UNITS_EDGES;
		}
	}

	/* UPDATE NEXT VALUES
	 * */

	if (is_new_itr_next)
	{
		if (is_new_layer_next)
		{
			for (int m=0; m< layers[i_layers].OUT_MAX_FACTOR; m++)
				pad_prev_ps[m] = chunk_b.data_ps[m];

			pad_prev_ps[0] += UNITS_EDGES;
		}
		else
		{
			for (int m=0; m< layers[i_layers].OUT_MAX_FACTOR; m++)
				pad_prev_ps[m] = chunk_b.data_ps[m] + itr_offset_next;

			pad_prev_ps[0] += UNITS_EDGES;
		}
	}
	for (int m=0; m< layers[i_layers].OUT_MAX_FACTOR; m++)
		pad_this_ps[m] = write_ps_next[m];

	i_arr = i_arr_next;
	i_blocks = i_blocks_next;
	i_layers = i_layers_next;
#if defined DEBUG && defined DEBUG_PAD
	i_w = i_w_next;
	i_itr = i_itr_next;
#endif
}

void restart_output()
{
	static int i_w=0, i_blocks=0, i_arr=0, i_itr=0, i_layers=I_LAYER, itr_offset=0;
	static volatile s8 * write_ps [2] = {chunk_b.data_ps[0] + UNITS_EDGES, chunk_b.data_ps[1]};
	static bool is_new_itr = false, is_new_layer=true;

	/* SET CONFIG BITS
	 * - for first packet
	 * - cannot set at the end, since next layer im_in might start before this layer is over
	 */


	// start transfer

	dma_im_out.s2mm_start(  (UINTPTR)write_ps[i_arr],
							layers[i_layers].WORDS_OUT_PER_TRANSFER);

	pad(	write_ps,
			i_arr,
			i_blocks,
			is_new_itr,
			itr_offset,
			i_layers,
			is_new_layer
#if defined DEBUG && defined DEBUG_PAD
			,i_w,i_itr
#endif
			);

	if (is_new_layer)
	{
		layers[(i_layers+1) % N_LAYERS].set_config(write_ps[0]-UNITS_EDGES);
		is_new_layer = false;
	}



	// PREPARE NEXT INDICES

	// Next data beat next col (i_w) but same c_out & units_edges. Hence push this ptr to that point
	// TODO - handle skip connection
#ifdef DEBUG
	Xil_DCacheFlushRange((UINTPTR)write_ps[i_arr], layers[i_layers].WORDS_OUT_PER_TRANSFER);
#endif

	write_ps[i_arr] += layers[i_layers].C_OUT * UNITS_EDGES;

	if (i_w < layers[i_layers].OUT_W_IN-1)
		i_w += 1;
	else
	{
		i_w = 0;

		xil_printf(" i_blocks: %d \r\n", i_blocks);

		if (i_blocks < layers[i_layers].OUT_BLOCKS-1)
		{
			i_blocks  += 1;
			i_arr      = i_blocks%layers[i_layers].OUT_MAX_FACTOR;
		}
		else
		{
			is_new_itr = true;
			i_blocks   = 0;
			i_arr      = 0;

			xil_printf(" i_itr: %d \r\n", i_itr);

			for (int m=0; m< layers[i_layers].OUT_MAX_FACTOR; m++)
				write_ps [m] = chunk_b.data_ps[m];

			write_ps [0] += UNITS_EDGES;


			if (i_itr == 0)
			{
				i_itr += 1;

				// TODO - handle skip connection
				itr_offset = i_itr * layers[i_layers].COUT_VALID * UNITS_EDGES;

				xil_printf("i_itr= %d, cout_off= %d, offset= %d \r\n",i_itr,layers[i_layers].COUT_VALID, itr_offset);

				for (int m=0; m< layers[i_layers].OUT_MAX_FACTOR; m++)
					write_ps [m] += itr_offset;
			}
			else if (i_itr < layers[i_layers].ITR-1)
			{
				i_itr += 1;

				// TODO - handle skip connection
				itr_offset = i_itr * layers[i_layers].EFF_CORES * UNITS_EDGES;

				xil_printf("i_itr= %d, cout_off= %d, offset= %d \r\n",i_itr,layers[i_layers].COUT_VALID, itr_offset);

				for (int m=0; m< layers[i_layers].OUT_MAX_FACTOR; m++)
					write_ps [m] += itr_offset;
			}
			else
			{
				is_new_layer = true;
				i_itr = 0;

				write_ps [0] = chunk_b.data_ps[0] + UNITS_EDGES;
				write_ps [1] = chunk_b.data_ps[1];

				if (i_layers < N_LAYERS-1)
				{
					i_layers += 1;
					xil_printf(" layer: %d \r\n", i_layers);
					getchar();
				}
				else
				{
					i_layers = 0;
					xil_printf(" All Layers done");
					done = true;
				}
			}
		}
	}
}

//// mwr -bin -file D:/cnn-fpga/data/1_weights.bin 0x0A000000 722; mwr -bin -file D:/cnn-fpga/data/1_conv_in_0.bin 0x02000000 55297; mwr -bin -file D:/cnn-fpga/data/1_conv_in_1.bin 0x03000000 55296;
//// mwr -bin -file D:/cnn-fpga/data/3_weights.bin 0x0A000000 5114; mwr -bin -file D:/cnn-fpga/data/3_conv_in_0.bin 0x02000000 147457;
//// mwr -bin -file D:/cnn-fpga/data/4_weights.bin 0x0A000000 3386; mwr -bin -file D:/cnn-fpga/data/4_conv_in_0.bin 0x02000000 294913;

//mwr -bin -file D:/cnn-fpga/data/3_weights.bin 0x0A000000 20456; mwr -bin -file D:/cnn-fpga/data/3_conv_in_0.bin 0x02000000 147458;


int main()
{

	xil_printf("\r\n--- Entering main() --- \r\n");

//	preprocess_input(image_rgb_p_A, chunk_a.data_ps, IS_NOT_MAX_0, IS_MAX_0, IS_RELU_0, KH_0);

	// Initiate DMAs
	dma_weights.intr_init_mm2s(XPAR_FABRIC_DMA_WEIGHTS_MM2S_INTROUT_INTR);
	dma_im_in_1.intr_init_mm2s(XPAR_FABRIC_DMA_IM_IN_1_MM2S_INTROUT_INTR);
	dma_im_in_2.intr_init_mm2s(XPAR_FABRIC_DMA_IM_IN_2_MM2S_INTROUT_INTR);
	dma_im_out.intr_init_s2mm (XPAR_FABRIC_DMA_IM_OUT_S2MM_INTROUT_INTR);

	// Layer Details

	xil_printf("--- Layer Details --- \r\n");

	xil_printf("Layer         : %d \r\n", layers[I_LAYER].idx);
	xil_printf("W             : %d \r\n", layers[I_LAYER].W_IN);
	xil_printf("BLOCKS        : %d \r\n", layers[I_LAYER].BLOCKS);
	xil_printf("BLOCKS_PER_ARR: %d \r\n", layers[I_LAYER].BLOCKS_PER_ARR);
	xil_printf("ITR           : %d \r\n", layers[I_LAYER].ITR);
	xil_printf("MAX_FACTOR    : %d \r\n", layers[I_LAYER].MAX_FACTOR);

//	// Attach custom callbacks
	dma_weights.mm2s_done_callback = restart_weights;
	dma_im_in_1.mm2s_done_callback = restart_pixels;
	dma_im_in_2.mm2s_done_callback = callback_image_2_mm2s_done;
	dma_im_out.s2mm_done_callback = restart_output;

//	// Start transfer
	restart_output();
//	dma_im_out.s2mm_start((UINTPTR)DATA_B0_P + UNITS_EDGES, layers[I_LAYER].WORDS_OUT_PER_TRANSFER);
	restart_weights();
	restart_pixels();

	while (!done){};

	xil_printf("--- Exiting main() --- \r\n");
	return XST_SUCCESS;

}
