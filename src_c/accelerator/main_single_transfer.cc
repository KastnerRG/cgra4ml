
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

#if (!defined(DEBUG))
extern void xil_printf(const char *format, ...);
#endif

My_DMA dma_im_in_1("im_in_1", XPAR_DMA_IM_IN_1_DEVICE_ID);
My_DMA dma_im_in_2("im_in_2", XPAR_DMA_IM_IN_2_DEVICE_ID);
My_DMA dma_weights("weights", XPAR_DMA_WEIGHTS_DEVICE_ID);
My_DMA dma_im_out("im_out", XPAR_DMA_IM_OUT_DEVICE_ID);

////// Layer 1:
//// mwr -bin -file D:/cnn-fpga/data/1_weights.bin 0x0A000000 722; mwr -bin -file D:/cnn-fpga/data/1_conv_in_0.bin 0x02000000 55297; mwr -bin -file D:/cnn-fpga/data/1_conv_in_1.bin 0x03000000 55296;
//#define IM_OUT_BYTES  6*2*2*4/2
//#define WEIGHTS_BYTES 1444
//#define IM_IN_BYTES   221184
//#define IS_MAX_ 1

// Layer 3:
// mwr -bin -file D:/cnn-fpga/data/3_weights.bin 0x0A000000 5114; mwr -bin -file D:/cnn-fpga/data/3_conv_in_0.bin 0x02000000 147458;
#define IM_OUT_BYTES  6*2*2*4
#define WEIGHTS_BYTES 10228
#define IM_IN_BYTES   589830
#define IS_MAX_ 0
#define NUM_TRANSFERS 1*16*96

////// Layer 4:
//// mwr -bin -file D:/cnn-fpga/data/4_weights.bin 0x0A000000 3386; mwr -bin -file D:/cnn-fpga/data/4_conv_in_0.bin 0x02000000 294913;
//#define IM_OUT_BYTES  6*2*2*4*3
//#define WEIGHTS_BYTES 6772
//#define IM_IN_BYTES   1179654
//#define IS_MAX_ 0

void callback_weights_mm2s_done()
{
	xil_printf("weights mm2s_done \r\n");
//	dma_weights.mm2s_start((UINTPTR)WEIGHTS_P, WEIGHTS_BYTES);
}
void callback_image_1_mm2s_done()
{
	xil_printf("image_0 mm2s_done \r\n");
//	dma_im_in_1.
}
void callback_image_2_mm2s_done()
{
	xil_printf("image_1 mm2s_done \r\n");
}

bool done = false;

void callback_output_s2mm_done()
{
//	xil_printf("out s2mm done \r\n");
	done = true;
}

int main()
{
	int status;

	xil_printf("\r\n--- Entering main() --- \r\n");

	// Initiate DMAs
	status = dma_weights.intr_init_mm2s(XPAR_FABRIC_DMA_WEIGHTS_MM2S_INTROUT_INTR);
	status = dma_im_out.intr_init_s2mm(XPAR_FABRIC_DMA_IM_OUT_S2MM_INTROUT_INTR);
	status = dma_im_in_1.intr_init_mm2s(XPAR_FABRIC_DMA_IM_IN_1_MM2S_INTROUT_INTR);
	status = dma_im_in_2.intr_init_mm2s(XPAR_FABRIC_DMA_IM_IN_2_MM2S_INTROUT_INTR);

	// Attach custom callbacks
	dma_weights.mm2s_done_callback = callback_weights_mm2s_done;
	dma_im_out.s2mm_done_callback = callback_output_s2mm_done;
	dma_im_in_1.mm2s_done_callback = callback_image_1_mm2s_done;
	dma_im_in_2.mm2s_done_callback = callback_image_2_mm2s_done;

	// Start transfer

	volatile s8* write_p = (s8*)(DATA_B_P);

	for (int i_itr=0; i_itr<3; i_itr++)
	{
		status = dma_weights.mm2s_start((UINTPTR)WEIGHTS_P, WEIGHTS_BYTES);
		xil_printf("%d \r\n",status);
		status = dma_im_in_1.mm2s_start((UINTPTR)DATA_A_P, IM_IN_BYTES + UNITS_EDGES);
		xil_printf("%d \r\n",status);
		if (IS_MAX_)
			status = dma_im_in_2.mm2s_start((UINTPTR)(DATA_A_P+UNITS_EDGES+IM_IN_BYTES), IM_IN_BYTES);
		xil_printf("%d \r\n",status);

		xil_printf("starting out itr done: i_itr = %d, address = %p \r\n", i_itr, write_p);
		for (int i_out=0; i_out<NUM_TRANSFERS; i_out++)
		{
			status = dma_im_out.s2mm_start((UINTPTR)write_p, IM_OUT_BYTES);
			while(!done){}
			done=false;
			Xil_DCacheFlushRange((UINTPTR)write_p, IM_OUT_BYTES);

//			xil_printf("out s2mm done: i_out = %d /%d, address = %p \r\n", i_out, NUM_TRANSFERS, write_p);
			write_p += IM_OUT_BYTES;
		}
	}

	xil_printf("--- Exiting main() --- \r\n");
	return XST_SUCCESS;

}
