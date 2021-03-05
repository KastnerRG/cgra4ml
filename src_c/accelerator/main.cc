
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
const chunk_s chunk_a = {(s8*) IMAGE_RGB_A_P, (s8*) DATA_A_P, (s8*)DATA_A_P + UNITS_EDGES};
const chunk_s chunk_b = {(s8*) IMAGE_RGB_B_P, (s8*) DATA_B_P, (s8*)DATA_B_P + UNITS_EDGES};

My_DMA dma_im_in_1("im_in_1", XPAR_DMA_IM_IN_1_DEVICE_ID);
My_DMA dma_im_in_2("im_in_2", XPAR_DMA_IM_IN_2_DEVICE_ID);
My_DMA dma_weights("weights", XPAR_DMA_WEIGHTS_DEVICE_ID);
My_DMA dma_im_out ("im_out", XPAR_DMA_IM_OUT_DEVICE_ID);

void restart_weights()
{
	static int i_itr = 0, i_layers = I_LAYER;
	static s8* weights_read_p = (s8*)WEIGHTS_P;

	status = dma_weights.mm2s_start((UINTPTR)weights_read_p, layers[i_layers].WORDS_WEIGHTS_PER_ITR);

#if defined DEBUG
	xil_printf("---------weights restarted. Reading from (i_layers,i_itr,:):\t (%d/%d, %d/%d, %d);\t ptr:%p \r\n",
				i_layers,N_LAYERS,
				i_itr	,layers[i_layers].ITR,
				layers[i_layers].WORDS_WEIGHTS_PER_ITR,
				weights_read_p);
#endif

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

	s8 *read_p1, *read_p2;
	unsigned long words_1, words_2;

	read_p1 = chunk_a.data_p;
	words_1 = UNITS_EDGES+layers[i_layers].WORDS_PIXELS_PER_ARR;

	read_p2 = read_p1 + words_1;
	words_2 = layers[i_layers].WORDS_PIXELS_PER_ARR;

	status = dma_im_in_1.mm2s_start((UINTPTR)read_p1, words_1);
	if (layers[i_layers].IS_MAX)
		status = dma_im_in_2.mm2s_start((UINTPTR)(read_p2), words_2);

#if defined DEBUG
	xil_printf("----------pixels restarted. Reading from (i_layers,i_itr,:):\t (%d/%d, %d/%d, [%d,%d]);\t ptr: [%p, %p] \r\n",
			i_layers,N_LAYERS,
			i_itr	,layers[i_layers].ITR,
			words_1, words_2,
			read_p1, read_p2);
#endif

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

volatile s8* unravel_index_5(volatile s8* base_p,
		int& i_0, int& i_1, int& i_2, int& i_3, int& i_4,
		const int D_0, const int D_1, const int D_2, const int D_3, const int D_4)
{
	 long idx = i_0*(D_1*D_2*D_3*D_4) + i_1*(D_2*D_3*D_4) + i_2*(D_3*D_4) + i_3*(D_4) + i_4;
	 return base_p + idx;
}

volatile s8* unravel_image_abwcu(volatile s8* base_p,
		int& i_arr, int& i_bpa, int& i_w, int& i_cout, int i_ue, int& i_layers)
{
	return unravel_index_5(base_p,

							i_arr, i_bpa, i_w, i_cout, i_ue,

							layers[i_layers].MAX_FACTOR,
							layers[i_layers].OUT_BLOCKS_PER_ARR,
							layers[i_layers].OUT_W_IN,
							layers[i_layers].C_OUT,
							UNITS_EDGES);
}


//#define DEBUG_PAD
void pad_prev(	int& i_w_next,
				int& i_blocks_next,
				int& i_bpa_next,
				int& i_arr_next,
				int& i_cout_base_next,
				int& i_layers_next,
				volatile s8* pixels_p_next)
{
	/* Called with params of ongoing transaction.
	 * Those are stored. Prev params are used to pad
	 * */
	static volatile s8* pixels_p = nullptr;
	static int i_w, i_blocks, i_bpa, i_arr, i_cout_base, i_layers;

	static bool is_sys_start = true;
	if (is_sys_start) is_sys_start = false;
	else
	{
		int i_arr_prev = (i_blocks-1) % layers[i_layers].MAX_FACTOR;
		int i_bpa_prev = (i_blocks-1) / layers[i_layers].MAX_FACTOR;

		for (int i_cout=i_cout_base; i_cout < i_cout_base + layers[i_layers].EFF_CORES; i_cout++)
		{
			volatile s8 *pad_prev_p = unravel_image_abwcu(pixels_p, i_arr_prev,i_bpa_prev,i_w,i_cout,0  , i_layers);
			volatile s8 *pad_this_p = unravel_image_abwcu(pixels_p, i_arr     ,i_bpa     ,i_w,i_cout,0  , i_layers);
			if (i_blocks != 0)
			{
				for (int i_kh2=0; i_kh2 < layers[i_layers].KH_IN/2; i_kh2++)
				{
					// prev_top   <- this_bottom

					int i_prev_ue_to   = KH_MAX/2 +UNITS + i_kh2;
					int i_this_ue_from = KH_MAX/2 + i_kh2;

					pad_prev_p[i_prev_ue_to]  = pad_this_p[i_this_ue_from];

					// prev_bottom -> this_top

					int i_this_ue_to   = KH_MAX/2-1 - i_kh2;
					int i_prev_ue_from = KH_MAX/2 +UNITS-1 - i_kh2;

					pad_this_p[i_this_ue_to] = pad_prev_p[i_prev_ue_from];
				}
#if defined DEBUG && defined DEBUG_PAD
			xil_printf("Padded [%p <-> %p] (abwcu): (%d,%d,%d,%d,%d)<-(%d,%d,%d,%d,%d) {%d} \t (%d,%d,%d,%d,%d)->(%d,%d,%d,%d,%d) {%d}  \r\n",
					(UINTPTR)pad_prev_p, (UINTPTR)pad_this_p,

					i_arr_prev,i_bpa_prev,i_w,i_cout, (KH_MAX/2 +UNITS),
					i_arr     ,i_bpa     ,i_w,i_cout,  KH_MAX/2,
					pad_this_p[KH_MAX/2],

					i_arr_prev,i_bpa_prev,i_w,i_cout,KH_MAX/2 +UNITS-1,
					i_arr     ,i_bpa     ,i_w,i_cout,KH_MAX/2-1,
					pad_prev_p[KH_MAX/2 +UNITS-1]);
#endif
			}
		}
	}

	i_w = i_w_next;
	i_blocks = i_blocks_next;
	i_bpa = i_bpa_next;
	i_arr = i_arr_next;
	i_cout_base= i_cout_base_next;
	i_layers = i_layers_next;
	pixels_p = pixels_p_next;
}

void restart_output()
{
	const chunk_s* chunk_write_p = &chunk_b;
	static volatile s8 * write_p = chunk_write_p->pixels_p;
	static int i_w=0, i_blocks=0, i_bpa=0, i_arr=0, i_cout=0, i_itr=0, i_layers=I_LAYER;
	static bool is_new_layer=true;

	// start transfer
	dma_im_out.s2mm_start(  (UINTPTR)write_p,
							layers[i_layers].WORDS_OUT_PER_TRANSFER);

	pad_prev(i_w,i_blocks,i_bpa,i_arr,i_cout,i_layers,chunk_write_p->pixels_p);

	// set config
	if (is_new_layer)
	{
		layers[(i_layers+1) % N_LAYERS].set_config(chunk_write_p->data_p);
		is_new_layer = false;
	}

	// PREPARE NEXT INDICES
	// TODO - handle skip connection
#ifdef DEBUG
	Xil_DCacheFlushRange((UINTPTR)write_p, layers[i_layers].WORDS_OUT_PER_TRANSFER);
#endif

	if (i_w < layers[i_layers].OUT_W_IN-1)
		i_w += 1;
	else
	{
		i_w = 0;

		xil_printf(" i_blocks: %d \r\n", i_blocks);

		if (i_blocks < layers[i_layers].OUT_BLOCKS-1)
		{
			i_blocks  += 1;
			i_arr      = i_blocks % layers[i_layers].OUT_MAX_FACTOR;
			i_bpa      = i_blocks / layers[i_layers].OUT_MAX_FACTOR;
		}
		else
		{
			i_blocks   = 0;
			i_arr      = 0;
			i_bpa      = 0;

			xil_printf(" i_itr: %d \r\n", i_itr);

			if (i_itr == 0)
			{
				// TODO - handle skip connection
				i_itr += 1;
				i_cout = layers[i_layers].COUT_VALID;

				xil_printf("i_itr= %d, i_cout= %d, offset= %d \r\n",i_itr, i_cout);
			}
			else if (i_itr < layers[i_layers].ITR-1)
			{
				// TODO - handle skip connection
				i_itr  += 1;
				i_cout += layers[i_layers].EFF_CORES;

				xil_printf("i_itr= %d, i_cout= %d, offset= %d \r\n",i_itr, i_cout);
			}
			else
			{
				is_new_layer = true;
				i_itr = 0;
				i_cout= 0;

				write_p = chunk_write_p->pixels_p;

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

	write_p = unravel_image_abwcu(chunk_write_p->pixels_p, i_arr,i_bpa,i_w,i_cout,0, i_layers);
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
