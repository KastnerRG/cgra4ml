#define N_BUNDLES 7
Bundle_t bundles [N_BUNDLES] = {
   {.n=8, .l=3, .kw=11, .coe=2, .coe_tl=2, .r_ll=2, .h=18, .w=18, .ci=3, .co=8, .w_kw2=13, .t=4, .p=3, .cm=1, .cm_p0=1, .w_bpt=140, .w_bpt_p0=140, .x_bpt=5624, .x_bpt_p0=5624, .o_bytes=9984, .is_bias=1, .is_flatten=0, .b_offset=0, .b_val_shift=5, .b_bias_shift=0, .ca_nzero=0, .ca_shift=8, .ca_pl_scale=0, .csh=1, .ch=18, .csh_shift=0, .pkh=3, .psh=2, .ph=9, .psh_shift=0, .csw=1, .cw=18, .csw_shift=0, .pkw=4, .psw=3, .pw=6, .psw_shift=0, .p_type=POOL_MAX, .on=8, .oh=9, .ow=6, .oc=8, .x_header=378324358931677184, .x_header_p0=378324358931677184, .w_header=378570735435644928, .w_header_p0=378324358931677184 , .debug_nhwc_words=3456 },
   {.n=8, .l=2, .kw=1, .coe=24, .coe_tl=0, .r_ll=1, .h=9, .w=6, .ci=8, .co=8, .w_kw2=6, .t=1, .p=1, .cm=20, .cm_p0=8, .w_bpt=104, .w_bpt_p0=104, .x_bpt=9992, .x_bpt_p0=9992, .o_bytes=9984, .is_bias=0, .is_flatten=0, .b_offset=8, .b_val_shift=0, .b_bias_shift=0, .ca_nzero=1, .ca_shift=3, .ca_pl_scale=0, .csh=1, .ch=9, .csh_shift=0, .pkh=1, .psh=1, .ph=9, .psh_shift=0, .csw=1, .cw=6, .csw_shift=0, .pkw=1, .psw=1, .pw=6, .psw_shift=0, .p_type=POOL_NONE, .on=8, .oh=9, .ow=6, .oc=8, .x_header=4053249560238096384, .x_header_p0=4053249560238096384, .w_header=4053495910972260352, .w_header_p0=4053249560238096384 , .debug_nhwc_words=3456 },
   {.n=8, .l=2, .kw=7, .coe=3, .coe_tl=2, .r_ll=1, .h=9, .w=6, .ci=8, .co=8, .w_kw2=3, .t=3, .p=4, .cm=2, .cm_p0=2, .w_bpt=176, .w_bpt_p0=176, .x_bpt=2504, .x_bpt_p0=2504, .o_bytes=9984, .is_bias=1, .is_flatten=0, .b_offset=8, .b_val_shift=5, .b_bias_shift=0, .ca_nzero=1, .ca_shift=8, .ca_pl_scale=0, .csh=1, .ch=9, .csh_shift=0, .pkh=1, .psh=1, .ph=9, .psh_shift=0, .csw=1, .cw=6, .csw_shift=0, .pkw=1, .psw=1, .pw=6, .psw_shift=0, .p_type=POOL_NONE, .on=8, .oh=9, .ow=6, .oc=8, .x_header=810657828531339264, .x_header_p0=810657828531339264, .w_header=810904230805110784, .w_header_p0=810657828531339264 , .debug_nhwc_words=3456 },
   {.n=8, .l=2, .kw=5, .coe=4, .coe_tl=4, .r_ll=1, .h=9, .w=6, .ci=8, .co=8, .w_kw2=4, .t=2, .p=2, .cm=4, .cm_p0=4, .w_bpt=248, .w_bpt_p0=248, .x_bpt=5000, .x_bpt_p0=5000, .o_bytes=9984, .is_bias=0, .is_flatten=0, .b_offset=17, .b_val_shift=0, .b_bias_shift=0, .ca_nzero=1, .ca_shift=6, .ca_pl_scale=3, .csh=1, .ch=9, .csh_shift=0, .pkh=1, .psh=1, .ph=9, .psh_shift=0, .csw=1, .cw=6, .csw_shift=0, .pkw=1, .psw=1, .pw=6, .psw_shift=0, .p_type=POOL_NONE, .on=8, .oh=9, .ow=6, .oc=8, .x_header=1891521739100258304, .x_header_p0=1891521739100258304, .w_header=1891768192913637376, .w_header_p0=1891521739100258304 , .debug_nhwc_words=3456 },
   {.n=8, .l=2, .kw=3, .coe=8, .coe_tl=8, .r_ll=1, .h=9, .w=6, .ci=8, .co=24, .w_kw2=5, .t=3, .p=2, .cm=6, .cm_p0=2, .w_bpt=224, .w_bpt_p0=80, .x_bpt=7496, .x_bpt_p0=2504, .o_bytes=29952, .is_bias=1, .is_flatten=0, .b_offset=17, .b_val_shift=5, .b_bias_shift=0, .ca_nzero=0, .ca_shift=8, .ca_pl_scale=0, .csh=1, .ch=9, .csh_shift=0, .pkh=1, .psh=1, .ph=9, .psh_shift=0, .csw=1, .cw=6, .csw_shift=0, .pkw=1, .psw=1, .pw=6, .psw_shift=0, .p_type=POOL_NONE, .on=8, .oh=9, .ow=6, .oc=24, .x_header=2972385649669177344, .x_header_p0=666542640455483392, .w_header=2972632086302687232, .w_header_p0=666542640455483392 , .debug_nhwc_words=10368 },
   {.n=8, .l=2, .kw=1, .coe=24, .coe_tl=0, .r_ll=1, .h=9, .w=6, .ci=24, .co=10, .w_kw2=6, .t=1, .p=2, .cm=20, .cm_p0=4, .w_bpt=248, .w_bpt_p0=56, .x_bpt=24968, .x_bpt_p0=5000, .o_bytes=7020, .is_bias=0, .is_flatten=1, .b_offset=41, .b_val_shift=0, .b_bias_shift=0, .ca_nzero=1, .ca_shift=6, .ca_pl_scale=3, .csh=1, .ch=9, .csh_shift=0, .pkh=1, .psh=1, .ph=9, .psh_shift=0, .csw=1, .cw=6, .csw_shift=0, .pkw=1, .psw=1, .pw=6, .psw_shift=0, .p_type=POOL_NONE, .on=1, .oh=8, .ow=1, .oc=540, .x_header=10970778587879178240, .x_header_p0=1747406551024402432, .w_header=10971025041692557312, .w_header_p0=1747406551024402432 , .debug_nhwc_words=4320 },
   {.n=1, .l=1, .kw=1, .coe=24, .coe_tl=0, .r_ll=8, .h=8, .w=1, .ci=540, .co=10, .w_kw2=1, .t=1, .p=27, .cm=20, .cm_p0=20, .w_bpt=248, .w_bpt_p0=248, .x_bpt=268, .x_bpt_p0=268, .o_bytes=80, .is_bias=1, .is_flatten=0, .b_offset=41, .b_val_shift=5, .b_bias_shift=0, .ca_nzero=1, .ca_shift=11, .ca_pl_scale=3, .csh=1, .ch=8, .csh_shift=0, .pkh=1, .psh=1, .ph=8, .psh_shift=0, .csw=1, .cw=1, .csw_shift=0, .pkw=1, .psw=1, .pw=1, .psw_shift=0, .p_type=POOL_NONE, .on=1, .oh=8, .ow=1, .oc=10, .x_header=10952754293765046272, .x_header_p0=10952754293765046272, .w_header=10952754456973803520, .w_header_p0=10952754293765046272 , .debug_nhwc_words=80 }
};

#define X_BITS_L2   3
#define W_BITS_L2   2
#define X_PAD       5
#define KH_MAX      11
#define PE_ROWS     8
#define PE_COLS     24

#define WB_BYTES    12930
#define W_BYTES     12800
#define X_BYTES     16872
#define O_WORDS     80
#define O_BYTES_MAX 29952
#define X_BYTES_ALL 94084
#define Y_BYTES     110600
#define B_TYPE      signed short
#define B_WORDS     65
#define DATA_DIR   "D:/dnn-engine/test/vectors"

