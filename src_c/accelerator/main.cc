
#include "xparameters.h"
#include "xdebug.h"
#include "xstatus.h"
#include "xil_printf.h"
#include "xstatus.h"
#include <machine/_default_types.h>
#include <cmath>
#include <iostream>
#include <bitset>

#if (!defined(DEBUG))
extern void PRINT(const char *format, ...);
#endif

#include "params.h"
#include "D:/cnn-fpga/src_c/zynq-oop-drivers/dma/my_dma.h"
#include "cnn.h"

#include "xil_cache.h"

#ifdef DEBUG
	#define PRINT(...)  xil_printf (__VA_ARGS__)
#else
	#define PRINT(...)
#endif

int status;
bool done = false;

const int i_layers_start = 1-1;

std::array<Layer, N_LAYERS> layers = build_yolo_mod();

My_DMA dma_im_in_1("im_in_1", XPAR_DMA_IM_IN_1_DEVICE_ID);
My_DMA dma_im_in_2("im_in_2", XPAR_DMA_IM_IN_2_DEVICE_ID);
My_DMA dma_weights_im_out("weights_im_out", XPAR_DMA_WEIGHTS_IM_OUT_DEVICE_ID);


void restart_im_2()
{
	/* This callback can be started from outside or inside (as callback)
	 *
	 * i_layers=0, i_itr=0, called from restart_pixels()
	 * 		enters IF, sets FLAG, starts first itr, calculates itr=1
	 * if restart_pixels() calls it again, it returns because mm2s is set high
	 * when completed, callback sets mm2s=false and calls this
	 * at last itr, it calcs next i_layer
	 *
	 * if next layer has no MAX, this is called, but just increments counters.
	 *
	 * */
	if (!dma_im_in_2.mm2s_done) return;

	static int i_itr = 0, i_layers = i_layers_start;
	s8 *read_p1, *read_p2;
	unsigned long words_1, words_2;

	if (layers[i_layers].IS_MAX)
	{
		read_p1 = (s8*)(layers[i_layers].input_chunk_p->data_p);
		words_1 = UNITS_EDGES+layers[i_layers].WORDS_PIXELS_PER_ARR;
		read_p2 = read_p1 + words_1;
		words_2 = layers[i_layers].WORDS_PIXELS_PER_ARR;

		// Xil_DCacheFlushRange((UINTPTR)read_p2, words_2);

//		PRINT("Image_2 in: [");
//		for (int i=0; i<UNITS_EDGES; i++){
//			PRINT(" %d,", read_p2[words_2-UNITS_EDGES+i]);
//		}
//		PRINT("] \r\n");

		status = dma_im_in_2.mm2s_start((UINTPTR)(read_p2), words_2);
	}

	if (i_itr < layers[i_layers].ITR-1)
		i_itr += 1;
	else
	{
		i_itr = 0;

		if(i_layers < N_LAYERS-1) i_layers += 1;
		else					  i_layers = 0;
	}
}

bool w_done = false;
void restart_weights()
{
	static int i_itr = 0, i_layers = i_layers_start;
	static s8* weights_read_p = (s8*)WEIGHTS_P;

	status = dma_weights_im_out.mm2s_start((UINTPTR)weights_read_p, layers[i_layers].WORDS_WEIGHTS_PER_ITR);

	if (w_done) return;

#if defined DEBUG

//	if (i_itr==0) layers[i_layers].print_weights_params();

	PRINT("---------weights restarted. Reading from (i_layers,i_itr,:):\t (%d/%d, %d/%d, %d);\t ptr:%p; status:%d \r\n",
			i_layers,N_LAYERS,
			i_itr	,layers[i_layers].ITR,
			layers[i_layers].WORDS_WEIGHTS_PER_ITR,
			weights_read_p, status);
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
			w_done = true;
		}
	}
}

void restart_pixels()
{
	static int i_itr = 0, i_layers = i_layers_start;

	s8 *read_p1;
	unsigned long words_1;

	read_p1 = (s8*)(layers[i_layers].input_chunk_p->data_p);
	words_1 = UNITS_EDGES+layers[i_layers].WORDS_PIXELS_PER_ARR;

	// Xil_DCacheFlushRange((UINTPTR)read_p1, words_1);

//	PRINT("Image_1 in: [");
//	for (int i=0; i<UNITS_EDGES; i++){
//		PRINT(" %d,", read_p1[words_1-UNITS_EDGES+i]);
//	}
//	PRINT("] \r\n");

	status = dma_im_in_1.mm2s_start((UINTPTR)read_p1, words_1);
	restart_im_2();

//	PRINT("----------pixels restarted. Reading from (i_layers,i_itr,:):\t (%d/%d, %d/%d, [%d]);\t ptr: [%p] \r\n",
//			i_layers,N_LAYERS,
//			i_itr	,layers[i_layers].ITR,
//			words_1,
//			read_p1);

	if (i_itr == 0)
	{
//#ifdef DEBUG
//		layers[i_layers].print_input_params();
//#endif
		// Invalidate the read layer.

		chunk_s * prev_input_chunk_p = (i_layers == 0) ? layers[N_LAYERS-1].input_chunk_p : layers[i_layers-1].input_chunk_p;

		if (prev_input_chunk_p)
		{
			prev_input_chunk_p-> valid = false;
//			PRINT("Prev input chunk freed. Addr = %p \r\n", prev_input_chunk_p->data_p);
		}
	}

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

volatile s8* unravel_index_5(volatile s8* const base_p,
		const int i_0, const int i_1, const int i_2, const int i_3, const int i_4,
		const int D_0, const int D_1, const int D_2, const int D_3, const int D_4)
{
	 long idx = i_0*(D_1*D_2*D_3*D_4) + i_1*(D_2*D_3*D_4) + i_2*(D_3*D_4) + i_3*(D_4) + i_4;
	 return base_p + idx;
}

volatile s8* unravel_image_abwcu(volatile s8* const pixels_base_p, const int i_arr, const int i_bpa, const int i_w, const int i_cout, const int i_ue, const int i_layers)
{
	return unravel_index_5( pixels_base_p,

							i_arr, i_bpa, i_w, i_cout, i_ue,

							layers[i_layers].MAX_FACTOR,
							layers[i_layers].OUT_BLOCKS_PER_ARR,
							layers[i_layers].OUT_W_IN,
							layers[i_layers].C_OUT,
							UNITS_EDGES);
}

//void read_gpios()
//{
//	UINTPTR gpio_bases[5] = {
//			XPAR_AXI_GPIO_0_BASEADDR,
//			XPAR_AXI_GPIO_1_BASEADDR,
//			XPAR_AXI_GPIO_2_BASEADDR,
//			XPAR_AXI_GPIO_3_BASEADDR,
//			XPAR_AXI_GPIO_4_BASEADDR
//	};
//
//	u32 * extracted_ptr = (u32*)0x00002000;
//
//	for (int i=0; i<5; i++){
//		extracted_ptr[i] = Xil_In32(gpio_bases[i]);
//		Xil_DCacheFlushRange((UINTPTR)(gpio_bases[i]), 4);
//
//		std::bitset<32> bits(extracted_ptr[i]);
//		PRINT("bits at %d : %s \r\n", i, bits.to_string().c_str());
//	}
//
//}

//#define DEBUG_PAD
void pad_prev(	const int i_w_next,
				const int i_blocks_next,
				const int i_bpa_next,
				const int i_arr_next,
				const int i_cout_base_next,
				const int i_layers_next)
{
	/* Called with params of ongoing transaction.
	 * Those are stored. Prev params are used to pad
	 * */
	static volatile s8* output_pixels_base_p = nullptr;
	static int i_w=0, i_blocks=0, i_bpa=0, i_arr=0, i_cout_base=0, i_layers=i_layers_start;

	static bool is_sys_start = true;
	if (is_sys_start) is_sys_start = false;
	else
	{
		if (i_blocks != 0)
		{
			int i_arr_prev = (i_blocks-1) % layers[i_layers].OUT_MAX_FACTOR;
			int i_bpa_prev = (i_blocks-1) / layers[i_layers].OUT_MAX_FACTOR;

			for (int i_cout=i_cout_base; i_cout < i_cout_base + layers[i_layers].EFF_CORES; i_cout++)
			{
				for (int i_kh2=0; i_kh2 < layers[i_layers].OUT_KH/2; i_kh2++)
				{
					// prev_top   <- this_bottom

					int i_prev_ue_to   = KH_MAX/2 +UNITS + i_kh2;
					int i_this_ue_from = KH_MAX/2 + i_kh2;

					volatile s8 *pad_prev_p_to   = unravel_image_abwcu(output_pixels_base_p,i_arr_prev,i_bpa_prev,i_w,i_cout,i_prev_ue_to  ,i_layers);
					volatile s8 *pad_this_p_from = unravel_image_abwcu(output_pixels_base_p,i_arr     ,i_bpa     ,i_w,i_cout,i_this_ue_from,i_layers);

					*pad_prev_p_to = *pad_this_p_from;


					// prev_bottom -> this_top

					int i_this_ue_to   = KH_MAX/2-1 - i_kh2;
					int i_prev_ue_from = KH_MAX/2 +UNITS-1 - i_kh2;

					volatile s8 *pad_this_p_to   = unravel_image_abwcu(output_pixels_base_p,i_arr     ,i_bpa     ,i_w,i_cout,i_this_ue_to  , i_layers);
					volatile s8 *pad_prev_p_from = unravel_image_abwcu(output_pixels_base_p,i_arr_prev,i_bpa_prev,i_w,i_cout,i_prev_ue_from, i_layers);

					*pad_this_p_to = *pad_prev_p_from;

#if defined DEBUG_PAD
			PRINT("Padded (abwcu: addr): (%d,%d,%d,%d,%d: %p)<-(%d,%d,%d,%d,%d: %p) \t (%d,%d,%d,%d,%d :%p)<-(%d,%d,%d,%d,%d :%p) \r\n",

					i_arr_prev,i_bpa_prev,i_w,i_cout, i_prev_ue_to  , (UINTPTR)pad_prev_p_to  ,
					i_arr     ,i_bpa     ,i_w,i_cout, i_this_ue_from, (UINTPTR)pad_this_p_from,

					i_arr_prev,i_bpa_prev,i_w,i_cout, i_this_ue_to  , (UINTPTR)pad_this_p_to  ,
					i_arr     ,i_bpa     ,i_w,i_cout, i_prev_ue_from, (UINTPTR)pad_prev_p_from
					);
#endif
				}

			}
		}
	}

	if (i_layers != i_layers_next)
	{
		layers[i_layers].done_write = true;
		PRINT("done writing & padding layer: %d; addr: %p \r\n", i_layers, layers[i_layers].output_chunk_p->data_p);
		PRINT("done layer \r\n");
	}

	i_w = i_w_next;
	i_blocks = i_blocks_next;
	i_bpa = i_bpa_next;
	i_arr = i_arr_next;
	i_cout_base= i_cout_base_next;
	i_layers = i_layers_next;
	output_pixels_base_p = layers[i_layers].get_output_pixels_base_p();
}

void restart_output_flat()
{
	static int i_w=0, i_blocks=0, i_itr=0, i_layers=i_layers_start;
	static volatile s8 * write_p = layers[i_layers].get_output_pixels_base_p();

	dma_weights_im_out.s2mm_start((UINTPTR)write_p,
								  layers[i_layers].WORDS_OUT_PER_TRANSFER);

	write_p += layers[i_layers].WORDS_OUT_PER_TRANSFER;

	if (i_w < layers[i_layers].OUT_W_IN-1)
		i_w += 1;
	else
	{
		i_w = 0;
//		PRINT(" i_blocks: %d, write_p: %p \r\n", i_blocks, write_p);

		if (i_blocks < layers[i_layers].OUT_BLOCKS-1)
			i_blocks  += 1;
		else
		{
			i_blocks   = 0;
//			PRINT(" i_itr: %d \r\n", i_itr);

			if (i_itr < layers[i_layers].ITR-1)
				i_itr  += 1;
			else
			{
				i_itr = 0;

				long bytes = layers[i_layers].WORDS_OUT_PER_TRANSFER * layers[i_layers].TRANSFERS_OUT_PER_ITR * layers[i_layers].ITR + UNITS_EDGES;

//				PRINT("Layer %d done. out_bytes: %d, addr: %d \r\n",
//						i_layers, bytes, layers[i_layers].get_output_pixels_base_p());

				if (i_layers < N_LAYERS-1)
					i_layers += 1;
				else
				{
					i_layers = 0;
					done = true;
					PRINT("All Layers done \r\n");
				}
			}
		}
	}
}

void restart_output()
{
	static int i_w=0, i_w_flipped=0, i_blocks=0, i_bpa=0, i_arr=0, i_cout=0, i_itr=0, i_layers=i_layers_start;
	static volatile s8 * write_p = layers[i_layers].get_output_pixels_base_p();
	static bool is_new_layer=true;

    static volatile s8 * write_p_old = 0;
	Xil_DCacheFlushRange((UINTPTR)write_p_old, UNITS_EDGES);

	if ((i_itr == 0 && i_blocks == 31) || (i_itr == 1 && i_blocks == 0)){
		for (int i=0; i<UNITS_EDGES; i++){
			PRINT(" %d,", write_p_old[i]);
		}
		PRINT("] \r\n");
		PRINT("(%d,%d,%d,%d-%d,:) -- %p [", i_arr, i_bpa, i_w_flipped,i_itr,i_cout, write_p);


//		PRINT("0x40D7F46 [");
//		for (int i=0; i<UNITS_EDGES; i++){
//			PRINT(" %d,", ((volatile s8 *)0x40D7F46)[i]);
//		}
//		PRINT("] \r\n");
	}
	write_p_old = write_p;


//	if (i_w==0 && i_blocks==0)
//		PRINT("i_itr= %d, i_cout= %d, ptr= %p \r\n",i_itr, i_cout, write_p);

	// start transfer
	dma_weights_im_out.s2mm_start(	(UINTPTR)write_p,
									layers[i_layers].WORDS_OUT_PER_TRANSFER);

	pad_prev(i_w_flipped,i_blocks,i_bpa,i_arr,i_cout,i_layers);

	// if (i_itr == 1 && i_blocks == 0 && i_w == 20){
	// 	PRINT("BREAK");
	// }

	// set config
	if (is_new_layer && i_layers != N_LAYERS-1)
	{
		layers[i_layers].NEXT_P->set_config();
		layers[i_layers].NEXT_P->done_write = false;
		is_new_layer = false;
	}

	// PREPARE NEXT INDICES
	// TODO - handle skip connection

	// blocks = 31 (a=1,bpa=15), w_f = 191 (w = 190), itr = 0

	if (i_w < layers[i_layers].OUT_W_IN-1)
	{
		i_w += 1;

		// Flip last KW-1 columns : flipped = 2w-(kw+iw)
		// For max: kw <- kw-2
		if (i_w > layers[i_layers].OUT_W_IN - layers[i_layers].KW_PAD)
		{
			i_w_flipped = 2 * layers[i_layers].OUT_W_IN - (i_w + layers[i_layers].KW_PAD);
//			PRINT("%d -> %d \r\n", i_w, i_w_flipped);
		}
		else
			i_w_flipped = i_w;
	}
	else
	{
		i_w = 0;
		i_w_flipped = 0;

		// PRINT(" i_blocks: %d, write_p: %p \r\n", i_blocks, write_p);

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

			// PRINT(" i_itr: %d \r\n", i_itr);

			if (i_itr >= layers[i_layers].ITR-1)
			{
				is_new_layer = true;
				i_itr = 0;
				i_cout= 0;

				if (i_layers < N_LAYERS-1)
					i_layers += 1;
				else
				{
					i_layers = 0;
					done = true;
					PRINT("All Layers done \r\n");
				}

				/* Chaining
				 * 	- Get a new invalid chunk for input of next layer == output of this layer
				 * */

				if (i_layers == N_LAYERS-1)
				{
					layers[0].input_chunk_p = &temp_in_chunk;
					layers[i_layers].output_chunk_p = &temp_out_chunk;
				}
				else
				{
					layers[i_layers].output_chunk_p = get_chunk();
					layers[i_layers].NEXT_P->input_chunk_p = layers[i_layers].output_chunk_p;
				}
//				PRINT("Writing to new layer: chained_chunks (idx:%d -> idx:%d), data_p= %p \r\n",
//						    layers[i_layers].idx, layers[i_layers].NEXT_P->idx,
//							layers[i_layers].output_chunk_p->data_p);

//				layers[i_layers].print_output_params();
			}
			else if (i_itr == 0)
			{
				// TODO - handle skip connection
				i_itr += 1;
				i_cout = layers[i_layers].COUT_VALID;
			}
			else
			{
				// TODO - handle skip connection
				i_itr  += 1;
				i_cout += layers[i_layers].EFF_CORES;
			}
		}
	}
	// blocks = 31 (a=1,bpa=15), w_f = 191, itr = 0
	write_p = unravel_image_abwcu(layers[i_layers].get_output_pixels_base_p(),
								  i_arr,i_bpa,i_w_flipped,i_cout,0, i_layers);
}

//// mwr -bin -file D:/cnn-fpga/data/1_weights.bin 0x0A000000 722; mwr -bin -file D:/cnn-fpga/data/1_conv_in_0.bin 0x02000000 55297; mwr -bin -file D:/cnn-fpga/data/1_conv_in_1.bin 0x03000000 55296;
//   mwr -bin -file D:/cnn-fpga/data/3_weights.bin 0x0A000000 5114; mwr -bin -file D:/cnn-fpga/data/3_conv_in_0.bin 0x02000000 147458;
//// mwr -bin -file D:/cnn-fpga/data/4_weights.bin 0x0A000000 3386; mwr -bin -file D:/cnn-fpga/data/4_conv_in_0.bin 0x02000000 294913;

// mwr -bin -file D:/cnn-fpga/data/weights_all.bin 0x08000000 10232828; mwr -bin -file D:/cnn-fpga/data/1_conv_in.bin 0x02000000 110594;

int main()
{

	PRINT("\r\n--- Entering main() --- \r\n");

//	preprocess_input(image_rgb_p_A, chunk_a.data_ps, IS_NOT_MAX_0, IS_MAX_0, IS_RELU_0, KH_0);

	// Initiate DMAs
	status = dma_weights_im_out.intr_init_mm2s(XPAR_FABRIC_DMA_WEIGHTS_IM_OUT_MM2S_INTROUT_INTR);
	status = dma_weights_im_out.intr_init_s2mm(XPAR_FABRIC_DMA_WEIGHTS_IM_OUT_S2MM_INTROUT_INTR);
	status = dma_im_in_1.intr_init_mm2s(XPAR_FABRIC_DMA_IM_IN_1_MM2S_INTROUT_INTR);
	status = dma_im_in_2.intr_init_mm2s(XPAR_FABRIC_DMA_IM_IN_2_MM2S_INTROUT_INTR);

	// Attach custom callbacks
	dma_weights_im_out.s2mm_done_callback = restart_output;
	dma_im_in_1.mm2s_done_callback = restart_pixels;
	dma_im_in_2.mm2s_done_callback = restart_im_2;

	Layer & layer_start = layers[i_layers_start];

	// Initial chain:
	layer_start.input_chunk_p = &temp_in_chunk;
	layer_start.output_chunk_p = get_chunk();;
	layer_start.NEXT_P->input_chunk_p = layer_start.output_chunk_p;

	PRINT(" data_in_0: %p, data_out_0: %p, data_in_1: %p, next_i: %d \r\n",
			   layer_start.input_chunk_p->data_p, layer_start.output_chunk_p->data_p,
			   layer_start.NEXT_P->input_chunk_p->data_p, layer_start.NEXT_P->idx);

	// Layer Details
//	layer_start.print_input_params();
//	layer_start.print_output_params();

	// Start transfer
	dma_im_in_2.mm2s_done = true;
	restart_output();
	restart_pixels();

	/* Restarting weights via interrupt does not work for first three restarts
	 * 	- resulting sequence i_itr=(0,1,0,3,4,5...)
	 * 	- note: i_itr is a static variable, incremented every time at function call. but gets 0 again.
	 * 	- looks like a race condition
	 * 	- tried:
	 * 		- splitting the weights dma into two
	 * 		- pre-loading w_rot with itr=(0,1) - then sequence is itr=(0,1,2,3,2,4,5,6)
	 * 	- manually controlling it works
	 * */
	while(!done && !w_done)
	{
		restart_weights();
		while (!dma_weights_im_out.mm2s_done) {}
	}

	pad_prev(0,0,0,0,0,0);

	PRINT("--- Exiting main() --- \r\n");
	getchar();
	return XST_SUCCESS;

}
