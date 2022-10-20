#pragma once

#define DEBUG

#define UNITS   4
#define MEMBERS 12
#define COPIES  2
#define GROUPS  2
#define KW_MAX 3
#define KH_MAX 3
#define UNITS_EDGES  6
#define S_WEIGHTS_WIDTH  32

#define INPUT_LUT_P   0x00001000

#define TEMP_DATA_IN_P  0x02000000
#define TEMP_DATA_OUT_P 0x03000000

#define DATA_1_P     0x04000000
#define DATA_2_P     0x05000000
#define DATA_3_P     0x06000000
#define DATA_4_P     0x07000000

#define WEIGHTS_P     0x08000000

#define H_RGB    256
#define W_RGB    384
#define CIN_RGB  3
#define COUT_RGB 32
#define N_LAYERS 21

#define IS_NOT_MAX_0 0
#define IS_MAX_0     1
#define IS_RELU_0    1
#define KH_0         3
#define KW_0         3

#ifdef DEBUG
	#pragma message("********* DEBUG is defined *************")
#endif
