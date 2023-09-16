#define N_BUNDLES 7
Bundle_t bundles [N_BUNDLES] = {
   {.n=8, .l=2, .kw=11, .coe=2, .coe_tl=2, .r_ll=8, .h=16, .w=8, .w_kw2=3, .t=8, .p=3, .cm=1, .cm_p0=1, .w_bpt=140, .w_bpt_p0=140, .x_bpt=840, .x_bpt_p0=840, .is_bias=1, .b_offset=0, .b_val_shift=9, .b_bias_shift=0, .ca_nzero=1, .ca_shift=15, .ca_pl_scale=3, .x_header=414341061322735616, .x_header_p0=414341061322735616, .w_header=414587437826703360, .w_header_p0=414341061322735616 },
   {.n=8, .l=2, .kw=1, .coe=24, .coe_tl=0, .r_ll=8, .h=16, .w=8, .w_kw2=8, .t=1, .p=1, .cm=20, .cm_p0=16, .w_bpt=200, .w_bpt_p0=200, .x_bpt=13320, .x_bpt_p0=13320, .is_bias=0, .b_offset=16, .b_val_shift=0, .b_bias_shift=0, .ca_nzero=1, .ca_shift=3, .ca_pl_scale=0, .x_header=8700964375684448256, .x_header_p0=8700964375684448256, .w_header=8701210795138088960, .w_header_p0=8700964375684448256 },
   {.n=8, .l=2, .kw=7, .coe=3, .coe_tl=4, .r_ll=8, .h=16, .w=8, .w_kw2=5, .t=6, .p=8, .cm=2, .cm_p0=2, .w_bpt=176, .w_bpt_p0=176, .x_bpt=1672, .x_bpt_p0=1672, .is_bias=1, .b_offset=16, .b_val_shift=9, .b_bias_shift=0, .ca_nzero=1, .ca_shift=12, .ca_pl_scale=0, .x_header=846686625550303232, .x_header_p0=846686625550303232, .w_header=846933027824074752, .w_header_p0=846686625550303232 },
   {.n=8, .l=2, .kw=5, .coe=4, .coe_tl=4, .r_ll=8, .h=16, .w=8, .w_kw2=6, .t=4, .p=4, .cm=4, .cm_p0=4, .w_bpt=248, .w_bpt_p0=248, .x_bpt=3336, .x_bpt_p0=3336, .is_bias=0, .b_offset=34, .b_val_shift=0, .b_bias_shift=0, .ca_nzero=1, .ca_shift=6, .ca_pl_scale=3, .x_header=1927550536119222272, .x_header_p0=1927550536119222272, .w_header=1927796989932601344, .w_header_p0=1927550536119222272 },
   {.n=8, .l=2, .kw=3, .coe=8, .coe_tl=8, .r_ll=8, .h=16, .w=8, .w_kw2=7, .t=3, .p=3, .cm=6, .cm_p0=4, .w_bpt=224, .w_bpt_p0=152, .x_bpt=5000, .x_bpt_p0=3336, .is_bias=1, .b_offset=34, .b_val_shift=9, .b_bias_shift=0, .ca_nzero=1, .ca_shift=15, .ca_pl_scale=3, .x_header=3008414446688141312, .x_header_p0=1855492942081294336, .w_header=3008660883321651200, .w_header_p0=1855492942081294336 },
   {.n=8, .l=2, .kw=1, .coe=24, .coe_tl=2, .r_ll=8, .h=16, .w=8, .w_kw2=8, .t=3, .p=2, .cm=20, .cm_p0=4, .w_bpt=248, .w_bpt_p0=56, .x_bpt=16648, .x_bpt_p0=3336, .is_bias=0, .b_offset=58, .b_val_shift=0, .b_bias_shift=0, .ca_nzero=1, .ca_shift=6, .ca_pl_scale=3, .x_header=11006807384898142208, .x_header_p0=1783435348043366400, .w_header=11007053838711521280, .w_header_p0=1783435348043366400 },
   {.n=1, .l=1, .kw=1, .coe=24, .coe_tl=0, .r_ll=8, .h=8, .w=1, .w_kw2=1, .t=1, .p=320, .cm=20, .cm_p0=20, .w_bpt=248, .w_bpt_p0=248, .x_bpt=138, .x_bpt_p0=138, .is_bias=1, .b_offset=58, .b_val_shift=9, .b_bias_shift=0, .ca_nzero=1, .ca_shift=15, .ca_pl_scale=3, .x_header=10952754293765046272, .x_header_p0=10952754293765046272, .w_header=10952754456973803520, .w_header_p0=10952754293765046272 }
};

#define X_BITS_L2   2
#define W_BITS_L2   2
#define PE_ROWS     8
#define PE_COLS     24

#define WB_BYTES    98212
#define W_BYTES     98048
#define X_BYTES     2520
#define X_BYTES_ALL 120040
#define Y_BYTES     294920
#define B_TYPE      signed short
#define B_WORDS     82
#define DATA_DIR   "D:/dnn-engine/test/vectors"

