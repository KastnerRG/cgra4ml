
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

	static int i = 0;

//	if (i<2)
	status = dma_weights.mm2s_start( (UINTPTR)weights_read_p, layers[i_layers].WORDS_WEIGHTS_PER_ITR);

//	i++;

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

//// mwr -bin -file D:/cnn-fpga/data/1_weights.bin 0x0A000000 722; mwr -bin -file D:/cnn-fpga/data/1_conv_in_0.bin 0x02000000 55297; mwr -bin -file D:/cnn-fpga/data/1_conv_in_1.bin 0x03000000 55296;
//// mwr -bin -file D:/cnn-fpga/data/3_weights.bin 0x0A000000 5114; mwr -bin -file D:/cnn-fpga/data/3_conv_in_0.bin 0x02000000 147457;
//// mwr -bin -file D:/cnn-fpga/data/4_weights.bin 0x0A000000 3386; mwr -bin -file D:/cnn-fpga/data/4_conv_in_0.bin 0x02000000 294913;

//mwr -bin -file D:/cnn-fpga/data/3_weights.bin 0x0A000000 20456; mwr -bin -file D:/cnn-fpga/data/3_conv_in_0.bin 0x02000000 147458;

void out_done(){
	static bool is_first_call = true;

	if (!is_first_call)
		dma_im_out.s2mm_start((UINTPTR)DATA_B0_P, 6*2*2*4);

	is_first_call = false;
	xil_printf("outDONE ");
//	done = true;
}
void im1_done(){
	xil_printf("im1DONE ");
//	done = true;
}
void im2_done(){
	xil_printf("im2DONE");
//	done = true;
}
void weights_done(){
	xil_printf("wDONE");
//	done = true;
}

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
//	dma_im_out.s2mm_done_callback = restart_output;
	dma_im_out.s2mm_done_callback = out_done;
//
//	// Start transfer
//	restart_output();
	out_done();
	status = dma_im_out.s2mm_start((UINTPTR)DATA_B0_P, 6*2*2*4);
//	xil_printf("%d \r\n",status);

	restart_weights();
	restart_pixels();

//	dma_weights.mm2s_done_callback = weights_done;
//	dma_im_in_1.mm2s_done_callback = im1_done;
//	dma_im_in_2.mm2s_done_callback = im2_done;


//	status = dma_weights.mm2s_start((UINTPTR)WEIGHTS_P, 10228);
//	xil_printf("%d \r\n",status);
//	status = dma_im_in_1.mm2s_start((UINTPTR)DATA_A0_P, 589830 + UNITS_EDGES);
//	xil_printf("%d \r\n",status);
//	if (0)
//		status = dma_im_in_2.mm2s_start((UINTPTR)DATA_A1_P, 589830);

	while (!done){};

	xil_printf("--- Exiting main() --- \r\n");
	return XST_SUCCESS;

}
