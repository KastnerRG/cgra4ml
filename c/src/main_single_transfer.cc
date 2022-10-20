
#include "xparameters.h"
#include "xdebug.h"
#include "xstatus.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "xstatus.h"
#include <machine/_default_types.h>
#include <cmath>
#include <iostream>
#include <bitset>

#include "params.h"
#include "D:/cnn-fpga/src_c/zynq-oop-drivers/dma/my_dma.h"

#if (!defined(DEBUG))
extern void xil_printf(const char *format, ...);
#endif

My_DMA dma_im_in_1("im_in_1", XPAR_DMA_IM_IN_1_DEVICE_ID);
My_DMA dma_im_in_2("im_in_2", XPAR_DMA_IM_IN_2_DEVICE_ID);
My_DMA dma_weights_im_out("weights_im_out", XPAR_DMA_WEIGHTS_IM_OUT_DEVICE_ID);

// Layer 1:
// mwr -bin -file D:/cnn-fpga/data/1_weights.bin 0x08000000 722; mwr -bin -file D:/cnn-fpga/data/1_conv_in.bin 0x02000000 110594;
//int WEIGHTS_BYTES = 3472;
//int IM_IN_BYTES = 221190-6;
//int IS_MAX_= 1;
//int IM_OUT_BYTES = 6*(2/2)*2*(12/3); // output
//int NUM_TRANSFERS = 73728/IM_OUT_BYTES;  // output



// Layer 2:
int WEIGHTS_BYTES = 5044;
int IM_IN_BYTES = 589830-6;
int IS_MAX_= 1;
int IM_OUT_BYTES = 6*(2/2)*2*(12/3); // output
int NUM_TRANSFERS = 73728/IM_OUT_BYTES;  // output

// mrd -bin -file D:/cnn-fpga/data/1_fpga_out_flat.bin 0x04000000 787136;

////// Layer 3:
//// mwr -bin -file D:/cnn-fpga/data/3_weights.bin 0x08000000 5114; mwr -bin -file D:/cnn-fpga/data/3_conv_in_0.bin 0x02000000 147458;
//#define IM_OUT_BYTES  6*2*2*4
//#define WEIGHTS_BYTES 10228
//#define IM_IN_BYTES   589830
//#define IS_MAX_ 0
//#define NUM_TRANSFERS 1*16*96

////// Layer 4:
//// mwr -bin -file D:/cnn-fpga/data/4_weights.bin 0x08000000 3386; mwr -bin -file D:/cnn-fpga/data/4_conv_in_0.bin 0x02000000 294913;
//#define IM_OUT_BYTES  6*2*2*4*3
//#define WEIGHTS_BYTES 6772
//#define IM_IN_BYTES   1179654
//#define IS_MAX_ 0

void callback_weights_mm2s_done()
{
	xil_printf("weights mm2s_done \r\n");
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
//
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
//		xil_printf("bits at %d : %s \r\n", i, bits.to_string().c_str());
//	}
//
//}

int main()
{
	int status;

	xil_printf("\r\n--- Entering main() --- \r\n");

	// Initiate DMAs
	status = dma_weights_im_out.intr_init_mm2s(XPAR_FABRIC_DMA_WEIGHTS_IM_OUT_MM2S_INTROUT_INTR);
	status = dma_weights_im_out.intr_init_s2mm(XPAR_FABRIC_DMA_WEIGHTS_IM_OUT_S2MM_INTROUT_INTR);
	status = dma_im_in_1.intr_init_mm2s(XPAR_FABRIC_DMA_IM_IN_1_MM2S_INTROUT_INTR);
	status = dma_im_in_2.intr_init_mm2s(XPAR_FABRIC_DMA_IM_IN_2_MM2S_INTROUT_INTR);

	// Attach custom callbacks
	dma_weights_im_out.mm2s_done_callback = callback_weights_mm2s_done;
	dma_weights_im_out.s2mm_done_callback = callback_output_s2mm_done;
	dma_im_in_1.mm2s_done_callback = callback_image_1_mm2s_done;
	dma_im_in_2.mm2s_done_callback = callback_image_2_mm2s_done;

	// Start transfer


	for (int i_itr=0; i_itr<8; i_itr++)
	{
		volatile s8* write_p = (s8*)(DATA_1_P);

		status = dma_weights_im_out.mm2s_start((UINTPTR)WEIGHTS_P, WEIGHTS_BYTES);
		xil_printf("%d \r\n",status);
		xil_printf("-------INITIAL------- \r\n");
//		read_gpios();

		xil_printf("Done reading \r\n");

		status = dma_im_in_1.mm2s_start((UINTPTR)TEMP_DATA_IN_P, IM_IN_BYTES + UNITS_EDGES);
		xil_printf("%d \r\n",status);
		if (IS_MAX_)
			status = dma_im_in_2.mm2s_start((UINTPTR)(TEMP_DATA_IN_P + IM_IN_BYTES + UNITS_EDGES), IM_IN_BYTES);
		xil_printf("%d \r\n",status);

		xil_printf("starting out i_itr = %d, address = %p \r\n", i_itr, write_p);
		for (int i_out=0; i_out<NUM_TRANSFERS; i_out++)
		{
			status = dma_weights_im_out.s2mm_start((UINTPTR)write_p, IM_OUT_BYTES);
			while(!done){}
			xil_printf("im_out_done packet_size: %d, packet_n: %d / %d \r\n", IM_OUT_BYTES, i_out, NUM_TRANSFERS);
			done=false;
			Xil_DCacheFlushRange((UINTPTR)write_p, IM_OUT_BYTES);

			write_p += IM_OUT_BYTES;
		}
//		read_gpios();
		xil_printf("done itr \r\n");
	}

	xil_printf("--- Exiting main() --- \r\n");
	return XST_SUCCESS;

}
