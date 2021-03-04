
#include "xparameters.h"
#include "xdebug.h"
#include "xstatus.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "xstatus.h"
#include <machine/_default_types.h>
#include <cmath>
#include <iostream>

#include "params.h"
#include "D:/cnn-fpga/src_c/zynq-oop-drivers/dma/my_dma.h"
#include "cnn.h"

#if (!defined(DEBUG))
extern void xil_printf(const char *format, ...);
#endif
#define DEBUG

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

	status = dma_im_in_1.mm2s_start((UINTPTR) chunk_a.data_p[0], layers[i_layers].WORDS_PIXELS_0);
	if (layers[i_layers].IS_MAX)
		status = dma_im_in_2.mm2s_start((UINTPTR) chunk_a.data_p[1], layers[i_layers].WORDS_PIXELS_1);

	xil_printf("----------pixels restarted. Reading from (i_layers,i_itr,:):\t (%d/%d, %d/%d, [%d,%d]);\t ptr: [%p, %p] \r\n",
			i_layers,N_LAYERS,
			i_itr	,layers[i_layers].ITR,
			layers[i_layers].WORDS_PIXELS_0, layers[i_layers].WORDS_PIXELS_1,
			chunk_a.data_p[0], chunk_a.data_p[1]);

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


void restart_output()
{
	static int i_w=0, i_blocks=0, i_arr=0, i_arr_prev=0, i_itr=0, i_layers=I_LAYER;
	static volatile s8 * write_p [2] = {chunk_b.data_p[0], chunk_b.data_p[1]};

	/* SET CONFIG BITS
	 * - for first packet
	 * - cannot set at the end, since next layer im_in might start before this layer is over
	 */

	static bool first_packet = true;
	if (first_packet)
	{
		layers[(i_layers+1) % N_LAYERS].set_config(write_p[0]);

		write_p[0]  += UNITS_EDGES;
		first_packet = false;
	}

	// start transfer

	dma_im_out.s2mm_start(  (UINTPTR)write_p[i_arr],
							layers[i_layers].WORDS_OUT_PER_TRANSFER);

//	xil_printf("Writing to (layer,arr,bpa,w,itr,cout_fpga*ue):\t (%d/%d, %d/%d, %d/%d, %d/%d, %d/%d, %d);\t ptr: %p \r\n",
//			i_layers,N_LAYERS,
//			i_arr	,layers[i_layers].OUT_MAX_FACTOR,
//			i_blocks/layers[i_layers].OUT_MAX_FACTOR, layers[i_layers].OUT_BLOCKS_PER_ARR,
//			i_w		,layers[i_layers].OUT_W_IN,
//			i_itr	,layers[i_layers].ITR,
//			layers[i_layers].WORDS_OUT_PER_TRANSFER,
//			write_p[i_arr]);

	// Padding

	static volatile s8 * pad_prev_p  [2] = {write_p[0], write_p[1]};
	static volatile s8 * pad_this_p [2] = {write_p[0], write_p[1]};

	for (int i_cout=0; i_cout < layers[i_layers].EFF_CORES; i_cout++)
	{
		if (i_w != 0)
		{
			if (i_blocks != 0)
			{
				for (int i_kh2=0; i_kh2 < layers[i_layers].KH_IN/2; i_kh2++)
				{
					int i_prev_to   = KH_MAX/2 +UNITS + i_kh2;
					int i_this_from = KH_MAX/2 + i_kh2;

					pad_prev_p[i_arr][i_prev_to] = pad_this_p[i_arr_prev][i_this_from];

					int i_this_to   = KH_MAX/2-1 - i_kh2;
					int i_prev_from = KH_MAX/2 +UNITS-1 - i_kh2;

					pad_this_p[i_arr_prev][i_this_to] = pad_prev_p[i_arr][i_prev_from];

//					xil_printf("\t P[%d]<-T[%d]; \t P[%d]->T[%d]", i_prev_to, i_this_from, i_prev_from, i_this_to);
				}
				pad_prev_p[i_arr_prev] += UNITS_EDGES;
			}
			pad_this_p[i_arr] += UNITS_EDGES;
		}
	}

	// PREPARE NEXT INDICES

	// Next data beat next col (i_w) but same c_out & units_edges. Hence push this ptr to that point
	// TODO - handle skip connection
#ifdef DEBUG
	Xil_DCacheFlushRange((UINTPTR)write_p[i_arr], layers[i_layers].WORDS_OUT_PER_TRANSFER);
#endif

	write_p[i_arr] += layers[i_layers].C_OUT * UNITS_EDGES;



	if (i_w < layers[i_layers].OUT_W_IN-1)
		i_w += 1;
	else
	{
		i_w = 0;

		xil_printf(" i_blocks: %d \r\n", i_blocks);


		if (i_blocks < layers[i_layers].OUT_BLOCKS-1)
		{
			i_blocks  += 1;
			i_arr_prev = i_arr;
			i_arr      = i_blocks%layers[i_layers].OUT_MAX_FACTOR;
		}
		else
		{
			i_blocks   = 0;
			i_arr      = 0;
			i_arr_prev = 0;

			xil_printf(" i_itr: %d \r\n", i_itr);

			for (int m=0; m< layers[i_layers].OUT_MAX_FACTOR; m++)
			{
				write_p [m] = chunk_b.data_p[m];
				pad_prev_p[m] = write_p [m];
				pad_this_p[m] = write_p [m];
			}
			write_p [0] += UNITS_EDGES;


			if (i_itr == 0)
			{
				i_itr += 1;

				// TODO - handle skip connection
				int offset = i_itr * layers[i_layers].COUT_VALID * UNITS_EDGES;

				xil_printf("i_itr= %d, cout_off= %d, offset= %d \r\n",i_itr,layers[i_layers].COUT_VALID, offset);

				for (int m=0; m< layers[i_layers].OUT_MAX_FACTOR; m++)
					write_p [m] += offset;
			}
			else if (i_itr < layers[i_layers].ITR-1)
			{
				i_itr += 1;

				// TODO - handle skip connection
				int offset = i_itr * layers[i_layers].EFF_CORES * UNITS_EDGES;

				xil_printf("i_itr= %d, cout_off= %d, offset= %d \r\n",i_itr,layers[i_layers].COUT_VALID, offset);

				for (int m=0; m< layers[i_layers].OUT_MAX_FACTOR; m++)
					write_p [m] += offset;
			}
			else
			{
				i_itr = 0;
				first_packet = true;

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
	int status;

	xil_printf("\r\n--- Entering main() --- \r\n");

//	preprocess_input(image_rgb_p_A, chunk_a.data_p, IS_NOT_MAX_0, IS_MAX_0, IS_RELU_0, KH_0);

	// Initiate DMAs
	status = dma_weights.intr_init_mm2s(XPAR_FABRIC_DMA_WEIGHTS_MM2S_INTROUT_INTR);
	status = dma_im_in_1.intr_init_mm2s(XPAR_FABRIC_DMA_IM_IN_1_MM2S_INTROUT_INTR);
	status = dma_im_in_2.intr_init_mm2s(XPAR_FABRIC_DMA_IM_IN_2_MM2S_INTROUT_INTR);
	status = dma_im_out.intr_init_s2mm (XPAR_FABRIC_DMA_IM_OUT_S2MM_INTROUT_INTR);

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
