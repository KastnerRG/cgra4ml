
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

struct chunk_s {s8 * p_image_rgb;	s8 * p_data [2]; };
chunk_s chunk_a = { (s8*) P_IMAGE_RGB_A, {(s8*) P_DATA_A_0, (s8*) P_DATA_A_1} };
chunk_s chunk_b = {	(s8*) P_IMAGE_RGB_A, {(s8*) P_DATA_A_0, (s8*) P_DATA_A_1} };

class Layer
{
public:
	 int H_IN, W_IN, C_IN, C_OUT, KH_IN, KW_IN;
	 bool IS_NOT_MAX, IS_MAX, IS_LRELU;

	 Layer * P_PREV;
	 Layer * P_NEXT;

	 int BLOCKS, BLOCKS_PER_ARR;
	 u8 MAX_FACTOR, SUB_CORES, EFF_CORES, ITR, COUT_FPGA, COUT_VALID, COUT_INVALID;

	 int DATA_BEATS_PIXELS, BEATS_LRELU;
	 int WORDS_PIXELS_0, WORDS_PIXELS_1;
	 int WORDS_WEIGHTS_PER_ITR, WORDS_WEIGHTS;

	 int WORDS_OUT_PER_TRANSFER, TRANSFERS_OUT_PER_ITR;
	 int WORDS_OUT_PER_TRANSFER_ARR [3];

	 Layer (
			 int H_IN, int W_IN, int C_IN, int C_OUT,
			 int KH_IN, int KW_IN,
			 bool IS_NOT_MAX, bool IS_MAX, bool IS_LRELU,
			 Layer * P_PREV, Layer *P_NEXT):
					 H_IN   (H_IN),
					 W_IN   (W_IN),
					 C_IN   (C_IN),
					 C_OUT  (C_OUT),
					 KH_IN   (KH_IN),
					 KW_IN   (KW_IN),
					 IS_NOT_MAX(IS_NOT_MAX),
					 IS_MAX    (IS_MAX),
					 IS_LRELU  (IS_LRELU),
					 P_PREV    (P_PREV),
					 P_NEXT    (P_NEXT)
	 {
		 BLOCKS     = H_IN / UNITS;
		 MAX_FACTOR = IS_MAX ? 2 : 1;
		 BLOCKS_PER_ARR = BLOCKS / MAX_FACTOR;

		 SUB_CORES = KW_MAX / KW_IN;
		 EFF_CORES = CORES * SUB_CORES / MAX_FACTOR;
		 ITR       = (int)(std::ceil((float)C_OUT / (float)EFF_CORES));
		 COUT_FPGA = EFF_CORES * ITR;

		 COUT_VALID = C_OUT % EFF_CORES;
		 COUT_VALID = (COUT_VALID == 0) ? EFF_CORES : COUT_VALID;

		 COUT_INVALID = EFF_CORES - COUT_VALID;

		 /* CALCULATE BYTES */

		 BEATS_LRELU = KW_IN == 3 ? BEATS_CONFIG_3X3 : BEATS_CONFIG_1X1;
		 DATA_BEATS_PIXELS = BLOCKS_PER_ARR * W_IN * C_IN;

		 WORDS_PIXELS_0        =      DATA_BEATS_PIXELS  * UNITS_EDGES;
		 WORDS_PIXELS_1        = (1 + DATA_BEATS_PIXELS) * UNITS_EDGES;
		 WORDS_WEIGHTS_PER_ITR = (S_WEIGHTS_WIDTH/8) + (BEATS_LRELU + C_IN*KH_IN)*CORES*KW_MAX;
		 WORDS_WEIGHTS         = ITR * WORDS_WEIGHTS_PER_ITR;

		 /* CALCULATE WORDS OUT
		  *
		  * (H_out, W_out, COUT)
		  * (H_in/MAX, W_in/MAX, COUT)
		  * (BLOCKS_in/MAX, UNITS_EDGES, W_in/MAX, COUT)
		  * (BLOCKS_in/MAX, UNITS_EDGES, W_in/MAX, COUT_FPGA)
		  * (BLOCKS_in/MAX, UNITS_EDGES, W_in/MAX, ITR, EFF_CORES)
		  * (BLOCKS_in/MAX, UNITS_EDGES, W_in/MAX, ITR, SUB_CORES, CORES/M)
		  * (BLOCKS_in/MAX, UNITS_EDGES, W_in/MAX, ITR, SUB_CORES, MEMBERS, COPIES*GROUPS/M)
		  *
		  *
		  *
		  * 	If (MAX & NON_MAX),
		  * 		Rotates through three modes - 1,2: non_max, 3: max
		  *
		  *			WORDS_PER_TRANSFER =
		  * 			0: SUB_CORES * MEMBERS * COPIES*GROUPS * UNITS_EDGES
		  * 			1: COPIES*GROUPS   * UNITS_EDGES
		  * 			2: COPIES*GROUPS/M * UNITS_EDGES
		  *
		  * 		TRANSFERS_OUT_PER_ITR =
		  * 			0	 : BLOCKS_in/MAX * W_in/MAX
		  * 			1	 : BLOCKS_in/MAX * W_in/MAX * SUB_CORES * MEMBERS
		  * 			2	 : BLOCKS_in/MAX * W_in/MAX * SUB_CORES * MEMBERS
		  * 			Total: BLOCKS_in/MAX * W_in/MAX * (1 + 2 * SUB_CORES * MEMBERS)
		  *
		  * 	Else:
		  * 		words_per_beat     = COPIES*GROUPS/M * UNITS_EDGES
		  * 		words_per_transfer = SUB_CORES * MEMBERS beats (tlast given)
		  * 		transfers_per_itr  = BLOCKS_in/MAX * W_in/MAX
		  *
		  */

		 if (IS_NOT_MAX && IS_MAX)
		 {
			 WORDS_OUT_PER_TRANSFER_ARR[0] = SUB_CORES * MEMBERS * COPIES * GROUPS * UNITS_EDGES;
			 WORDS_OUT_PER_TRANSFER_ARR[1] =                       COPIES * GROUPS * UNITS_EDGES;
			 WORDS_OUT_PER_TRANSFER_ARR[2] =                       COPIES * GROUPS * UNITS_EDGES / MAX_FACTOR;

			 TRANSFERS_OUT_PER_ITR = BLOCKS/MAX_FACTOR * W_IN/MAX_FACTOR * (1 + 2 * SUB_CORES * MEMBERS);
		 }
		 else
		 {
			 WORDS_OUT_PER_TRANSFER = SUB_CORES * MEMBERS * COPIES * GROUPS * UNITS_EDGES / MAX_FACTOR;
			 TRANSFERS_OUT_PER_ITR  = BLOCKS/MAX_FACTOR * W_IN/MAX_FACTOR;
		 }
	 };

	 void set_config(chunk_s chunk)
	 {
		 chunk.p_data[0][0] = (s8)(IS_NOT_MAX);
		 chunk.p_data[0][1] = (s8)(IS_MAX);
		 chunk.p_data[0][2] = (s8)(IS_LRELU);
		 chunk.p_data[0][3] = (s8)(KH_IN);
	 };

};

void callback_weights_mm2s_done(My_DMA* dma)
{
	xil_printf("weights mm2s_done \r\n");
}
void callback_image_1_mm2s_done(My_DMA* dma)
{
	xil_printf("image_0 mm2s_done \r\n");
}
void callback_image_2_mm2s_done(My_DMA* dma)
{
	xil_printf("image_1 mm2s_done \r\n");
}

int i_w = 0, i_blocks = 0, i_itr = 0, i_layers = 0;
Layer * layer;
int status;
s8 * p_write [2];

My_DMA dma_im_in_1("im_in_1", XPAR_DMA_IM_IN_1_DEVICE_ID);
My_DMA dma_im_in_2("im_in_2", XPAR_DMA_IM_IN_2_DEVICE_ID);
My_DMA dma_weights_im_out("weights_imout", XPAR_DMA_WEIGHTS_IM_OUT_DEVICE_ID);

void start_image_in()
{
	status = dma_im_in_1.mm2s_start((UINTPTR) chunk_a.p_data[0], layer->WORDS_PIXELS_0);
	if (layer->IS_MAX)
		status = dma_im_in_2.mm2s_start((UINTPTR) chunk_a.p_data[1], layer->WORDS_PIXELS_0);
}

void callback_output_s2mm_done(My_DMA* dma)
{
	// start transfer

	status = dma_weights_im_out.s2mm_start(
			p_write[i_blocks % layer->MAX_FACTOR],
			layer->WORDS_OUT_PER_TRANSFER);

	p_write[i_blocks%layer->MAX_FACTOR] += layer->COUT_FPGA * UNITS_EDGES;

	// prepare next indices

	xil_printf("Done s2mm. Next: i_w:%d", i_w);

	if (i_w < layer->P_NEXT->W_IN)
		i_w += 1;
	else
	{
		i_w = 0;

		xil_printf(" i_blocks:%d ", i_blocks);

		if (i_blocks < layer->P_NEXT->BLOCKS)
			i_blocks += 1;
		else
		{
			i_blocks = 0;

			xil_printf(" i_itr:%d ", i_itr);

			if (i_itr == 0)
			{
				int offset = i_itr * layer->COUT_VALID * UNITS_EDGES;
				s8* p_im_out = (i_blocks%layer->MAX_FACTOR==0) ? chunk_b.p_data[0]+UNITS_EDGES : chunk_b.p_data[1];

				p_write[i_blocks%layer->MAX_FACTOR] = p_im_out + offset;
				start_image_in();
			}
			else if (i_itr < layer->ITR)
			{
				int offset = i_itr * layer->COUT_FPGA * UNITS_EDGES;
				s8* p_im_out = (i_blocks%layer->MAX_FACTOR==0) ? chunk_b.p_data[0]+UNITS_EDGES : chunk_b.p_data[1];

				p_write[i_blocks%layer->MAX_FACTOR] = p_im_out + offset;
				start_image_in();
			}
			else
			{
				xil_printf(" Done layer");
			}
		}
	}
	xil_printf("\r\n");
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

//	preprocess_input(P_IMAGE_RGB_A, chunk_a.p_data, IS_NOT_MAX_0, IS_MAX_0, IS_RELU_0, KH_0);

	Layer layer_0 = Layer(	HEIGHT_RGB,WIDTH_RGB,CIN_RGB,COUT_RGB,
							KH_0, KW_0,
							IS_NOT_MAX_0, IS_MAX_0, IS_RELU_0,
							0,0);

	Layer layer_1 = Layer(	HEIGHT_RGB/2,WIDTH_RGB/2,32,64,
								3, 3,
								false, true, true,
								0,0);

	layer_0.P_NEXT = &layer_1;
	layer_1.P_PREV = &layer_0;
	layer = &layer_0;

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
	layer->P_NEXT->set_config(chunk_b);
	p_write[0] = chunk_b.p_data[0] + UNITS_EDGES;
	p_write[1] = chunk_b.p_data[1];

	status = dma_weights_im_out.s2mm_start(p_write[0], layer->WORDS_OUT_PER_TRANSFER);
	xil_printf("%d \r\n",status);

	status = dma_weights_im_out.mm2s_start((UINTPTR) P_WEIGHTS, layer->WORDS_WEIGHTS_PER_ITR);
	xil_printf("%d \r\n",status);
	status = dma_im_in_1.mm2s_start((UINTPTR) chunk_a.p_data[0], layer->WORDS_PIXELS_0);
	xil_printf("%d \r\n",status);
	if (layer->IS_MAX)
		status = dma_im_in_2.mm2s_start((UINTPTR) chunk_a.p_data[1], layer->WORDS_PIXELS_0);
	xil_printf("%d \r\n",status);



	xil_printf("--- Exiting main() --- \r\n");
	return XST_SUCCESS;

}
