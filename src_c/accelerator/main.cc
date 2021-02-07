
#include "xparameters.h"
#include "xdebug.h"
#include "xstatus.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "xstatus.h"
#include <machine/_default_types.h>
#include "params.h"

#if (!defined(DEBUG))
extern void xil_printf(const char *format, ...);
#endif

#define P_INPUT_LUT    0x00001000
#define P_IMAGE_INPUT  0x01000000
#define P_IMAGE_IN_0   0x02000000
#define P_IMAGE_IN_1   0x03000000

const int in_height = 256;
const int in_width  = 384;
const int in_cin    = 3;

const bool in_is_not_max = 0;
const bool in_is_max     = 1;
const bool in_is_lrelu   = 1;
const s8 in_kh           = 3;

const s8 in_max_factor     = in_is_max ? 2 : 1;
const s8 in_blocks         = in_height / UNITS;
const s8 in_blocks_per_arr = in_blocks / in_max_factor;


s8 * p_input_lut   = (s8*)P_INPUT_LUT; // gamma and quantization

typedef u8 image_in_buwc_t [in_blocks][UNITS][in_width][in_cin];
image_in_buwc_t &p_image_input_buwc = *reinterpret_cast<image_in_buwc_t*>(P_IMAGE_INPUT);

typedef s8 image_in_bwcu_t [in_blocks_per_arr][in_width][in_cin][UNITS_EDGES];
image_in_bwcu_t &p_image_in_0 = *reinterpret_cast<image_in_bwcu_t*>(P_IMAGE_IN_0 + UNITS_EDGES);
image_in_bwcu_t &p_image_in_1 = *reinterpret_cast<image_in_bwcu_t*>(P_IMAGE_IN_1);
image_in_bwcu_t * pp_image_in_mbwcu [in_max_factor] = {&p_image_in_0, &p_image_in_1};

int main()
{
	int status;
	xil_printf("\r\n--- Entering main() --- \r\n");

	((u8*)P_IMAGE_IN_0)[0] = (u8)in_is_not_max;
	((u8*)P_IMAGE_IN_0)[1] = (u8)in_is_max;
	((u8*)P_IMAGE_IN_0)[2] = (u8)in_is_lrelu;
	((u8*)P_IMAGE_IN_0)[3] = in_kh-1;

	int i_arr, i_b_arr, i_ue, value;

	for (int i_b = 0; i_b < in_blocks; i_b++)
		for (int i_u = 0; i_u < UNITS; i_u++)
			for (int i_w = 0; i_w < in_width; i_w++)
				for (int i_cin = 0; i_cin < in_cin; i_cin++){

					// write pointers
					i_arr   = i_b%in_max_factor;
					i_b_arr = i_b/in_max_factor;
					i_ue    = i_u+KERNEL_H_MAX/2;

					value = p_input_lut[p_image_input_buwc[i_b][i_u][i_w][i_cin]];

					(* pp_image_in_mbwcu[i_arr]) [i_b_arr][i_w][i_cin][i_ue] = value;


					if (i_u < KERNEL_H_MAX/2) // reading TOP ROWS
					{
						i_ue    = i_u + (UNITS + KERNEL_H_MAX/2); // write to BOTTOM ROWS

						if (i_b == 0) // when reading top rows of FIRST BLOCK
						{
							value   = 0; 							// fill zeros
							i_arr   = (in_blocks-1)%in_max_factor;  // to bottom of LAST BLOCK
							i_b_arr = (in_blocks-1)/in_max_factor;
						}
						else // when reading top rows of OTHER BLOCKS
						{
							i_arr   = (i_b-1)%in_max_factor; // fill values to PREVIOUS BLOCK
							i_b_arr = (i_b-1)/in_max_factor;
						}

						(* pp_image_in_mbwcu[i_arr]) [i_b_arr][i_w][i_cin][i_ue] = value;
					}
					if (i_u >= UNITS-KERNEL_H_MAX/2) // reading BOTTOM ROWS
					{
						i_ue    = i_u - (UNITS - KERNEL_H_MAX/2); // write to TOP ROWS

						if (i_b == in_blocks-1) // when reading bottom rows of LAST BLOCK
						{
							value   = 0; // fill zeros
							i_arr   = 0; // to top of FIRST BLOCK
							i_b_arr = 0;
						}
						else // When reading bottom rows of OTHER BLOCKS
						{
							i_arr   = (i_b+1)%in_max_factor; //fill values to NEXT BLOCK
							i_b_arr = (i_b+1)/in_max_factor;
						}

						(* pp_image_in_mbwcu[i_arr])[i_b_arr][i_w][i_cin][i_ue] = value;
					}
				}


	xil_printf("--- Exiting main() --- \r\n");
	return XST_SUCCESS;

}
