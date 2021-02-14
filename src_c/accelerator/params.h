#define UNITS   8
#define MEMBERS 8
#define COPIES  2
#define GROUPS  2
#define KW_MAX 3
#define KH_MAX 3
#define UNITS_EDGES  10
#define CORES        32
#define BEATS_CONFIG_3X3 21
#define BEATS_CONFIG_1X1 13
#define S_WEIGHTS_WIDTH  32

#define P_INPUT_LUT   0x00001000
#define P_IMAGE_RGB_A 0x01000000
#define P_DATA_A_0    0x02000000
#define P_DATA_A_1    0x03000000

#define P_IMAGE_RGB_B 0x05000000
#define P_DATA_B_0    0x06000000
#define P_DATA_B_1    0x07000000

#define P_WEIGHTS     0x0A000000

#define HEIGHT_RGB 256
#define WIDTH_RGB  384
#define CIN_RGB    3
#define COUT_RGB   32

#define IS_NOT_MAX_0 0
#define IS_MAX_0     1
#define IS_RELU_0    1
#define KH_0         3
#define KW_0         3
