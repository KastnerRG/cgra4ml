
#include "xparameters.h"
#include "xdebug.h"
#include "xstatus.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "xstatus.h"
#include <machine/_default_types.h>
#include <cmath>

#include "params.h"
#include "D:/cnn-fpga/src_c/zynq-oop-drivers/dma/my_dma.h"

#if (!defined(DEBUG))
extern void xil_printf(const char *format, ...);
#endif

My_DMA dma_im_in_1("im_in_1", XPAR_DMA_IM_IN_1_DEVICE_ID);
My_DMA dma_im_in_2("im_in_2", XPAR_DMA_IM_IN_2_DEVICE_ID);
My_DMA dma_weights("weights", XPAR_DMA_WEIGHTS_DEVICE_ID);
My_DMA dma_im_out("im_out", XPAR_DMA_IM_OUT_DEVICE_ID);

//// Layer 1:
// mwr -bin -file D:/cnn-fpga/data/1_weights.bin 0x0A000000 722; mwr -bin -file D:/cnn-fpga/data/1_conv_in_0.bin 0x02000000 55297; mwr -bin -file D:/cnn-fpga/data/1_conv_in_1.bin 0x03000000 55296;
#define IM_OUT_BYTES  6*2*2*4
#define WEIGHTS_BYTES 1444
#define IM_IN_BYTES   221184
#define IS_MAX_ 1

//// Layer 3:
//// mwr -bin -file D:/cnn-fpga/data/3_weights.bin 0x0A000000 5114; mwr -bin -file D:/cnn-fpga/data/3_conv_in_0.bin 0x02000000 147457;
//#define IM_OUT_BYTES  6*2*2*4
//#define WEIGHTS_BYTES 10228
//#define IM_IN_BYTES   589830
//#define IS_MAX_ 0

////// Layer 4:
//// mwr -bin -file D:/cnn-fpga/data/4_weights.bin 0x0A000000 3386; mwr -bin -file D:/cnn-fpga/data/4_conv_in_0.bin 0x02000000 294913;
//#define IM_OUT_BYTES  6*2*2*4
//#define WEIGHTS_BYTES 6772
//#define IM_IN_BYTES   1179654
//#define IS_MAX_ 0

void callback_weights_mm2s_done(My_DMA* dma)
{
	xil_printf("weights mm2s_done \r\n");
	dma_weights.mm2s_start((UINTPTR)P_WEIGHTS, WEIGHTS_BYTES);
}
void callback_image_1_mm2s_done(My_DMA* dma)
{
	xil_printf("image_0 mm2s_done \r\n");
}
void callback_image_2_mm2s_done(My_DMA* dma)
{
	xil_printf("image_1 mm2s_done \r\n");
}

bool done = false;


void callback_output_s2mm_done(My_DMA* dma)
{
	xil_printf("out s2mm done \r\n");
	done = true;
}

void preprocess_input(
		UINTPTR p_image_rgb,
		UINTPTR * PP_DATA_IN,
		s8 IS_NOT_MAX,
		bool IS_MAX,
		bool IS_RELU,
		u8 KH)
{
	/* STORE CONFIG	 */
	((s8*)PP_DATA_IN[0])[0] = (s8)IS_NOT_MAX;
	((s8*)PP_DATA_IN[0])[1] = (s8)IS_MAX;
	((s8*)PP_DATA_IN[0])[2] = (s8)IS_RELU;
	((s8*)PP_DATA_IN[0])[3] = (s8)KH-1;

	const s8 MAX_FACTOR     = IS_MAX ? 2 : 1;
	const s8 BLOCKS         = HEIGHT_RGB / UNITS;
	const s8 BLOCKS_PER_ARR = BLOCKS / MAX_FACTOR;

	/* POINTER CASTINGS FOR RESHAPE */

	s8 * p_lut   = (s8*)P_INPUT_LUT; // gamma and quantization

	typedef u8 image_in_buwc_t [BLOCKS][UNITS][WIDTH_RGB][CIN_RGB];
	image_in_buwc_t &p_image_rgb_buwc = *reinterpret_cast<image_in_buwc_t*>(p_image_rgb);

	typedef s8 image_in_bwcu_t [BLOCKS_PER_ARR][WIDTH_RGB][CIN_RGB][UNITS_EDGES];
	image_in_bwcu_t &p_image_in_bwcu_0 = *reinterpret_cast<image_in_bwcu_t*>(PP_DATA_IN[0] + UNITS_EDGES);
	image_in_bwcu_t &p_image_in_bwcu_1 = *reinterpret_cast<image_in_bwcu_t*>(PP_DATA_IN[1]);
	image_in_bwcu_t * pp_image_in_mbwcu [MAX_FACTOR] = {&p_image_in_bwcu_0, &p_image_in_bwcu_1};


	int i_arr, i_b_arr, i_ue, value;

	for (int i_b = 0; i_b < BLOCKS; i_b++)
		for (int i_u = 0; i_u < UNITS; i_u++)
			for (int i_w = 0; i_w < WIDTH_RGB; i_w++)
				for (int i_cin = 0; i_cin < CIN_RGB; i_cin++){

					// write pointers
					i_arr   = i_b%MAX_FACTOR;
					i_b_arr = i_b/MAX_FACTOR;
					i_ue    = i_u+KH_MAX/2;

					value = p_lut[p_image_rgb_buwc[i_b][i_u][i_w][i_cin]];

					(* pp_image_in_mbwcu[i_arr]) [i_b_arr][i_w][i_cin][i_ue] = value;


					if (i_u < KH_MAX/2) // reading TOP ROWS
					{
						i_ue    = i_u + (UNITS + KH_MAX/2); // write to BOTTOM ROWS

						if (i_b == 0) // when reading top rows of FIRST BLOCK
						{
							value   = 0; 							// fill zeros
							i_arr   = (BLOCKS-1)%MAX_FACTOR;  // to bottom of LAST BLOCK
							i_b_arr = (BLOCKS-1)/MAX_FACTOR;
						}
						else // when reading top rows of OTHER BLOCKS
						{
							i_arr   = (i_b-1)%MAX_FACTOR; // fill values to PREVIOUS BLOCK
							i_b_arr = (i_b-1)/MAX_FACTOR;
						}

						(* pp_image_in_mbwcu[i_arr]) [i_b_arr][i_w][i_cin][i_ue] = value;
					}
					if (i_u >= UNITS-KH_MAX/2) // reading BOTTOM ROWS
					{
						i_ue    = i_u - (UNITS - KH_MAX/2); // write to TOP ROWS

						if (i_b == BLOCKS-1) // when reading bottom rows of LAST BLOCK
						{
							value   = 0; // fill zeros
							i_arr   = 0; // to top of FIRST BLOCK
							i_b_arr = 0;
						}
						else // When reading bottom rows of OTHER BLOCKS
						{
							i_arr   = (i_b+1)%MAX_FACTOR; //fill values to NEXT BLOCK
							i_b_arr = (i_b+1)/MAX_FACTOR;
						}

						(* pp_image_in_mbwcu[i_arr])[i_b_arr][i_w][i_cin][i_ue] = value;
					}
				}
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

	status = dma_im_out.s2mm_start((UINTPTR)P_DATA_B_0, IM_OUT_BYTES);
	xil_printf("%d \r\n",status);

	status = dma_weights.mm2s_start((UINTPTR)P_WEIGHTS, WEIGHTS_BYTES);
	xil_printf("%d \r\n",status);
	status = dma_im_in_1.mm2s_start((UINTPTR)P_DATA_A_0, IM_IN_BYTES + UNITS_EDGES);
	xil_printf("%d \r\n",status);
	if (IS_MAX_)
		status = dma_im_in_2.mm2s_start((UINTPTR)P_DATA_A_1, IM_IN_BYTES);
	xil_printf("%d \r\n",status);

	while(!done){}

//	while (Xil_In32(XPAR_GPIO_1_BASEADDR) == 0 ) {
////		xil_printf("%d \r\n", Xil_In32(XPAR_GPIO_1_BASEADDR));
//	}
//
//	int sum = 0;
//	for (int i; i<10000;i++)sum += i;
//	xil_printf("Valid: %d, Num bytes: %d, sum = %d \r\n", Xil_In32(XPAR_GPIO_0_BASEADDR), Xil_In32(XPAR_GPIO_1_BASEADDR), sum);


	xil_printf("--- Exiting main() --- \r\n");
	return XST_SUCCESS;

}
