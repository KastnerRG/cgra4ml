#define N_BUNDLES 6
Bundle_t bundles [N_BUNDLES] = {
   {.n=8, .l=2, .kw=11, .coe=2, .coe_tl=2, .r_ll=8, .h=16, .w=8, .w_kw2=3, .t=8, .p=3, .cm=1, .cm_p0=1, .w_bpt=152, .w_bpt_p0=152, .x_bpt=840, .x_bpt_p0=840, .is_bias=1, .b_offset=0, .b_val_shift=9, .b_bias_shift=0, .x_header=414341061322735616, .x_header_p0=414341061322735616, .w_header=414587446416637952, .w_header_p0=414341061322735616 },
   {.n=8, .l=2, .kw=1, .coe=24, .coe_tl=0, .r_ll=8, .h=16, .w=8, .w_kw2=8, .t=1, .p=1, .cm=19, .cm_p0=16, .w_bpt=212, .w_bpt_p0=212, .x_bpt=13320, .x_bpt_p0=13320, .is_bias=1, .b_offset=16, .b_val_shift=9, .b_bias_shift=0, .x_header=8700964375684448256, .x_header_p0=8700964375684448256, .w_header=8701210803728023552, .w_header_p0=8700964375684448256 },
   {.n=8, .l=2, .kw=7, .coe=3, .coe_tl=4, .r_ll=8, .h=16, .w=8, .w_kw2=5, .t=6, .p=8, .cm=2, .cm_p0=2, .w_bpt=188, .w_bpt_p0=188, .x_bpt=1672, .x_bpt_p0=1672, .is_bias=1, .b_offset=40, .b_val_shift=9, .b_bias_shift=0, .x_header=846686625550303232, .x_header_p0=846686625550303232, .w_header=846933036414009344, .w_header_p0=846686625550303232 },
   {.n=8, .l=2, .kw=5, .coe=4, .coe_tl=4, .r_ll=8, .h=16, .w=8, .w_kw2=6, .t=4, .p=6, .cm=3, .cm_p0=1, .w_bpt=200, .w_bpt_p0=80, .x_bpt=2504, .x_bpt_p0=840, .is_bias=1, .b_offset=58, .b_val_shift=9, .b_bias_shift=0, .x_header=1351089783815798784, .x_header_p0=198168279208951808, .w_header=1351336203269439488, .w_header_p0=198168279208951808 },
   {.n=8, .l=2, .kw=3, .coe=8, .coe_tl=8, .r_ll=8, .h=16, .w=8, .w_kw2=7, .t=3, .p=3, .cm=6, .cm_p0=4, .w_bpt=236, .w_bpt_p0=164, .x_bpt=5000, .x_bpt_p0=3336, .is_bias=1, .b_offset=74, .b_val_shift=9, .b_bias_shift=0, .x_header=3008414446688141312, .x_header_p0=1855492942081294336, .w_header=3008660891911585792, .w_header_p0=1855492942081294336 },
   {.n=8, .l=2, .kw=1, .coe=24, .coe_tl=2, .r_ll=8, .h=16, .w=8, .w_kw2=8, .t=3, .p=2, .cm=19, .cm_p0=5, .w_bpt=248, .w_bpt_p0=80, .x_bpt=15816, .x_bpt_p0=4168, .is_bias=1, .b_offset=98, .b_val_shift=9, .b_bias_shift=0, .x_header=10430346632594718720, .x_header_p0=2359896100346789888, .w_header=10430593086408097792, .w_header_p0=2359896100346789888 }
};

#define X_BITS_L2   2
#define W_BITS_L2   2
#define PE_ROWS     8
#define PE_COLS     24

#define WB_BYTES    20436
#define W_BYTES     20096
#define X_BYTES     2520
#define X_BYTES_ALL 75896
#define Y_BYTES     294920
#define B_TYPE      signed short
#define B_WORDS     170
#define DATA_DIR   "D:/dnn-engine/test/vectors"

