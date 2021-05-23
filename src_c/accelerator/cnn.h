#pragma once

#include "xparameters.h"
#include "xdebug.h"
#include "xstatus.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "xstatus.h"
#include "xil_cache.h"
#include <machine/_default_types.h>
#include <cmath>
#include <iostream>
#include <array>

#include "params.h"
#include "D:/cnn-fpga/src_c/zynq-oop-drivers/dma/my_dma.h"

//struct chunk_s {s8 * image_rgb_p; s8 * data_p; s8 * pixels_p;};
struct chunk_s {s8 * data_p; bool valid;};

std::array<chunk_s, 3> chunks {{
	{(s8*) DATA_1_P, false},
	{(s8*) DATA_2_P, false},
	{(s8*) DATA_3_P, false},
}};

chunk_s temp_in_chunk  = {(s8*) TEMP_DATA_IN_P , true};
chunk_s temp_out_chunk = {(s8*) TEMP_DATA_OUT_P, true};

chunk_s * get_chunk()
{
	for (size_t i=0; i<chunks.size(); i++)
	{
		if(!chunks[i].valid)
		{
			chunks[i].valid = true;
			return &(chunks[i]);
		}
	}
	xil_printf("ERROR: All chunks are valid. Cannot allocate \r\n");
	exit(1);
}

class Layer
{
public:
	 int idx, H_IN, W_IN, C_IN, C_OUT, KH_IN, KW_IN;
	 bool IS_NOT_MAX, IS_MAX, IS_LRELU;

	 Layer * PREV_P = nullptr;
	 Layer * NEXT_P = nullptr;

	 int BLOCKS, BLOCKS_PER_ARR;
	 u8 MAX_FACTOR, SUB_CORES, EFF_CORES, ITR, COUT_FPGA, COUT_VALID, COUT_INVALID;
	 u8 KW_PAD;

	 int OUT_W_IN, OUT_BLOCKS, OUT_MAX_FACTOR, OUT_BLOCKS_PER_ARR, OUT_KH;

	 int DATA_BEATS_PIXELS, BEATS_LRELU;
	 int WORDS_PIXELS_PER_ARR;
	 int WORDS_WEIGHTS_PER_ITR, WORDS_WEIGHTS;

	 int WORDS_OUT_PER_TRANSFER, TRANSFERS_OUT_PER_ITR;
	 int WORDS_OUT_PER_TRANSFER_ARR [3];

	 chunk_s * input_chunk_p  = nullptr;
	 chunk_s * output_chunk_p = nullptr;
	 bool done_write = false;

	 Layer ( int idx,
			 int H_IN, int W_IN, int C_IN, int C_OUT,
			 int KH_IN, int KW_IN,
			 bool IS_NOT_MAX, bool IS_MAX, bool IS_LRELU):
					 idx    (idx),
					 H_IN   (H_IN),
					 W_IN   (W_IN),
					 C_IN   (C_IN),
					 C_OUT  (C_OUT),
					 KH_IN   (KH_IN),
					 KW_IN   (KW_IN),
					 IS_NOT_MAX(IS_NOT_MAX),
					 IS_MAX    (IS_MAX),
					 IS_LRELU  (IS_LRELU)
	 {
		 BLOCKS     = H_IN / UNITS;
		 MAX_FACTOR = IS_MAX ? 2 : 1;
		 BLOCKS_PER_ARR = BLOCKS / MAX_FACTOR;

		 KW_PAD = KW_IN - 2*IS_MAX;

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

		 WORDS_PIXELS_PER_ARR  =      DATA_BEATS_PIXELS  * UNITS_EDGES;
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

	 void set_config()
	 {
		 input_chunk_p->data_p[0] = (s8)(IS_NOT_MAX);
		 input_chunk_p->data_p[1] = (s8)(IS_MAX);
		 input_chunk_p->data_p[2] = (s8)(IS_LRELU);
		 input_chunk_p->data_p[3] = (s8)(KH_IN-1);

#ifdef DEBUG
		 for (int i=4; i<UNITS_EDGES; i++) input_chunk_p->data_p[i] = 0;
#endif
		 Xil_DCacheFlushRange((UINTPTR)input_chunk_p->data_p, UNITS_EDGES);
	 };

	 void set_out_params()
	 {
		 /* Next layer can be null (if this is last) or can have multiple next layers.
		  * We are interested in how to arrange the output values of this, to match the next
		  */

		 OUT_W_IN   = W_IN / MAX_FACTOR;
		 OUT_BLOCKS = (H_IN / MAX_FACTOR) / UNITS;

		 OUT_MAX_FACTOR     = (NEXT_P == nullptr) ? 1 : NEXT_P->MAX_FACTOR;
		 OUT_BLOCKS_PER_ARR = OUT_BLOCKS/OUT_MAX_FACTOR;

		 OUT_KH = (NEXT_P == nullptr) ? KH_IN : NEXT_P->KH_IN;
	 }

	 inline s8* get_input_pixels_base_p()
	 {
		 return (s8*)(input_chunk_p->data_p) + UNITS_EDGES;
	 }
	 inline s8* get_output_pixels_base_p()
	 {
		 return (s8*)(output_chunk_p->data_p) + UNITS_EDGES;
	 }

	 void print_input_params()
	 {
		xil_printf("\n--------------- INPUT INFO, idx: %d ------------ \r\n\n",idx);

		xil_printf(" - W                    : %d \r\n", W_IN);
		xil_printf(" - MAX_FACTOR           : %d \r\n", MAX_FACTOR);
		xil_printf(" - BLOCKS               : %d \r\n", BLOCKS);
		xil_printf(" - BLOCKS_PER_ARR       : %d \r\n", BLOCKS_PER_ARR);
		xil_printf(" - ITR                  : %d \r\n", ITR);
		xil_printf(" - DATA_BEATS_PIXELS    : %d \r\n", DATA_BEATS_PIXELS);
		xil_printf(" - WORDS_PIXELS_PER_ARR : %d \r\n", WORDS_PIXELS_PER_ARR);
		xil_printf(" - DATA_ADDR            : %p \r\n", input_chunk_p->data_p);

	 }
	 void print_output_params()
	 {

		xil_printf("\n--------------- OUTPUT INFO, idx: %d ------------ \r\n\n",idx);

		xil_printf(" - WORDS_OUT_PER_TRANSFER  : %d \r\n", WORDS_OUT_PER_TRANSFER);
		xil_printf(" - TRANSFERS_OUT_PER_ITR   : %d \r\n", TRANSFERS_OUT_PER_ITR);
		xil_printf(" - OUT_WIN                 : %d \r\n", OUT_W_IN);
		xil_printf(" - OUT_MAX_FACTOR          : %d \r\n", OUT_MAX_FACTOR);
		xil_printf(" - OUT_BLOCKS              : %d \r\n", OUT_BLOCKS);
		xil_printf(" - OUT_BLOCKS_PER_ARR      : %d \r\n", OUT_BLOCKS_PER_ARR);
		xil_printf(" - OUT_KH                  : %d \r\n", OUT_KH);
		xil_printf(" - KW_PAD                  : %d \r\n", KW_PAD);
		xil_printf(" - DATA_ADDR               : %p \r\n", output_chunk_p->data_p);
	 }

	 void print_weights_params()
	 {
		xil_printf("\n--------------- WEIGHTS INFO, layer idx: %d ------------ \r\n\n",idx);

		xil_printf(" - SUB_CORES               : %d \r\n", SUB_CORES);
		xil_printf(" - EFF_CORES               : %d \r\n", EFF_CORES);
		xil_printf(" - ITR                     : %d \r\n", ITR);
		xil_printf(" - COUT_FPGA               : %d \r\n", COUT_FPGA);
		xil_printf(" - COUT_VALID              : %d \r\n", COUT_VALID);
		xil_printf(" - COUT_INVALID            : %d \r\n", COUT_INVALID);
		xil_printf(" - BEATS_LRELU             : %d \r\n", BEATS_LRELU);
		xil_printf(" - WORDS_WEIGHTS_PER_ITR   : %d \r\n", WORDS_WEIGHTS_PER_ITR);
		xil_printf(" - WORDS_WEIGHTS           : %d \r\n", WORDS_WEIGHTS);
	 }
};

auto build_yolo_mod()
{
	std::array<Layer,21> layers = {
			Layer(	1,
					H_RGB,W_RGB,
					3,32,
					3, 3,
					false, true, true
			),
			Layer(	2,
					H_RGB/2,W_RGB/2,
					32,64,
					3, 3,
					false, true, true
			),
			Layer(	3,
					H_RGB/4,W_RGB/4,
					64,128,
					3, 3,
					true, false, true
			),
			Layer(	4,
					H_RGB/4,W_RGB/4,
					128,64,
					1, 1,
					true, false, true
			),
			Layer(	5,
					H_RGB/4,W_RGB/4,
					64,128,
					3, 3,
					false, true, true
			),
			Layer(	6,
					H_RGB/8,W_RGB/8,
					128,256,
					3, 3,
					true, false, true
			),
			Layer(	7,
					H_RGB/8,W_RGB/8,
					256,128,
					1, 1,
					true, false, true
			),
			Layer(	8,
					H_RGB/8,W_RGB/8,
					128,256,
					3, 3,
					false, true, true
			),
			Layer(	9,
					H_RGB/16,W_RGB/16,
					256,512,
					3, 3,
					true, false, true
			),
			Layer(	10,
					H_RGB/16,W_RGB/16,
					512,256,
					1, 1,
					true, false, true
			),
			Layer(	11,
					H_RGB/16,W_RGB/16,
					256,512,
					3, 3,
					true, false, true
			),
			Layer(	12,
					H_RGB/16,W_RGB/16,
					512,256,
					1, 1,
					true, false, true
			),
			Layer(	13,
					H_RGB/16,W_RGB/16,
					256,512,
					3, 3,
					false, true, true
			),
			Layer(	14,
					H_RGB/32,W_RGB/32,
					512,1024,
					3, 3,
					true, false, true
			),
			Layer(	15,
					H_RGB/32,W_RGB/32,
					1024,512,
					1, 1,
					true, false, true
			),
			Layer(	16,
					H_RGB/32,W_RGB/32,
					512,1024,
					3, 3,
					true, false, true
			),
			Layer(	17,
					H_RGB/32,W_RGB/32,
					64,128,
					1024, 512,
					true, false, true
			),
			Layer(	18,
					H_RGB/32,W_RGB/32,
					64,128,
					512, 1024,
					true, false, true
			),
			Layer(	19,
					H_RGB/32,W_RGB/32,
					1024,1024,
					3, 3,
					true, false, true
			),
			Layer(	20,
					H_RGB/32,W_RGB/32,
					1024,1024,
					3, 3,
					true, false, true
			),
			Layer(	21,
					H_RGB/32,W_RGB/32,
					1024,45,
					1, 1,
					true, false, false
			)
	};

	for (int i=0; i < N_LAYERS; i++)
	{
		if (i!=0         ) layers[i].PREV_P = &layers[i-1];
		if (i!=N_LAYERS-1) layers[i].NEXT_P = &layers[i+1];

		layers[i].set_out_params();
	}

	return layers;
}


void preprocess_input(
		UINTPTR image_rgb_p,
		UINTPTR * Pdata_p_IN,
		s8 IS_NOT_MAX,
		bool IS_MAX,
		bool IS_RELU,
		u8 KH)
{
	/* STORE CONFIG	 */
	((s8*)Pdata_p_IN[0])[0] = (s8)IS_NOT_MAX;
	((s8*)Pdata_p_IN[0])[1] = (s8)IS_MAX;
	((s8*)Pdata_p_IN[0])[2] = (s8)IS_RELU;
	((s8*)Pdata_p_IN[0])[3] = (s8)KH-1;

	const s8 MAX_FACTOR     = IS_MAX ? 2 : 1;
	const s8 BLOCKS         = H_RGB / UNITS;
	const s8 BLOCKS_PER_ARR = BLOCKS / MAX_FACTOR;

	/* POINTER CASTINGS FOR RESHAPE */

	s8 * lut_p   = (s8*)INPUT_LUT_P; // gamma and quantization

	typedef u8 image_in_buwc_t [BLOCKS][UNITS][W_RGB][CIN_RGB];
	image_in_buwc_t &image_rgb_p_buwc = *reinterpret_cast<image_in_buwc_t*>(image_rgb_p);

	typedef s8 image_in_bwcu_t [BLOCKS_PER_ARR][W_RGB][CIN_RGB][UNITS_EDGES];
	image_in_bwcu_t &p_image_in_bwcu_0 = *reinterpret_cast<image_in_bwcu_t*>(Pdata_p_IN[0] + UNITS_EDGES);
	image_in_bwcu_t &p_image_in_bwcu_1 = *reinterpret_cast<image_in_bwcu_t*>(Pdata_p_IN[1]);
	image_in_bwcu_t * pp_image_in_mbwcu [MAX_FACTOR] = {&p_image_in_bwcu_0, &p_image_in_bwcu_1};


	int i_arr, i_b_arr, i_ue, value;

	for (int i_b = 0; i_b < BLOCKS; i_b++)
		for (int i_u = 0; i_u < UNITS; i_u++)
			for (int i_w = 0; i_w < W_RGB; i_w++)
				for (int i_cin = 0; i_cin < CIN_RGB; i_cin++){

					// write pointers
					i_arr   = i_b%MAX_FACTOR;
					i_b_arr = i_b/MAX_FACTOR;
					i_ue    = i_u+KH_MAX/2;

					value = lut_p[image_rgb_p_buwc[i_b][i_u][i_w][i_cin]];

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

