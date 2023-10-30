#define N_BUNDLES 7
Bundle_t bundles [N_BUNDLES] = {
   {.n=8, .l=3, .kw=11, .coe=2, .coe_tl=2, .r_ll=8, .h=24, .w=32, .ci=3, .co=8, .w_kw2=27, .t=4, .p=3, .cm=1, .cm_p0=1, .w_bpt=140, .w_bpt_p0=140, .x_bpt=9992, .x_bpt_p0=9992, .o_bytes=18304, .is_bias=1, .is_flatten=0, .b_offset=0, .b_val_shift=5, .b_bias_shift=0, .ca_nzero=0, .ca_shift=8, .ca_pl_scale=0, .csh=2, .ch=12, .csh_shift=1, .pkh=1, .psh=1, .ph=12, .psh_shift=0, .csw=3, .cw=11, .csw_shift=1, .pkw=1, .psw=1, .pw=11, .psw_shift=0, .on=8, .oh=12, .ow=11, .oc=8, .x_header=414356454485524480, .x_header_p0=414356454485524480, .w_header=414602830989492224, .w_header_p0=414356454485524480 , .debug_nhwc_words=8448 },
   {.n=8, .l=2, .kw=1, .coe=24, .coe_tl=0, .r_ll=4, .h=12, .w=11, .ci=8, .co=8, .w_kw2=11, .t=1, .p=1, .cm=20, .cm_p0=8, .w_bpt=104, .w_bpt_p0=104, .x_bpt=18312, .x_bpt_p0=18312, .o_bytes=18304, .is_bias=0, .is_flatten=0, .b_offset=8, .b_val_shift=0, .b_bias_shift=0, .ca_nzero=1, .ca_shift=3, .ca_pl_scale=0, .csh=1, .ch=12, .csh_shift=0, .pkh=1, .psh=1, .ph=12, .psh_shift=0, .csw=1, .cw=11, .csw_shift=0, .pkw=1, .psw=1, .pw=11, .psw_shift=0, .on=8, .oh=12, .ow=11, .oc=8, .x_header=4071265058259206144, .x_header_p0=4071265058259206144, .w_header=4071511408993370112, .w_header_p0=4071265058259206144 , .debug_nhwc_words=8448 },
   {.n=8, .l=2, .kw=7, .coe=3, .coe_tl=2, .r_ll=4, .h=12, .w=11, .ci=8, .co=8, .w_kw2=8, .t=3, .p=4, .cm=2, .cm_p0=2, .w_bpt=176, .w_bpt_p0=176, .x_bpt=4584, .x_bpt_p0=4584, .o_bytes=18304, .is_bias=1, .is_flatten=0, .b_offset=8, .b_val_shift=5, .b_bias_shift=0, .ca_nzero=1, .ca_shift=8, .ca_pl_scale=0, .csh=1, .ch=12, .csh_shift=0, .pkh=1, .psh=1, .ph=12, .psh_shift=0, .csw=1, .cw=11, .csw_shift=0, .pkw=1, .psw=1, .pw=11, .psw_shift=0, .on=8, .oh=12, .ow=11, .oc=8, .x_header=828673326552449024, .x_header_p0=828673326552449024, .w_header=828919728826220544, .w_header_p0=828673326552449024 , .debug_nhwc_words=8448 },
   {.n=8, .l=2, .kw=5, .coe=4, .coe_tl=4, .r_ll=4, .h=12, .w=11, .ci=8, .co=8, .w_kw2=9, .t=2, .p=2, .cm=4, .cm_p0=4, .w_bpt=248, .w_bpt_p0=248, .x_bpt=9160, .x_bpt_p0=9160, .o_bytes=18304, .is_bias=0, .is_flatten=0, .b_offset=17, .b_val_shift=0, .b_bias_shift=0, .ca_nzero=1, .ca_shift=6, .ca_pl_scale=3, .csh=1, .ch=12, .csh_shift=0, .pkh=1, .psh=1, .ph=12, .psh_shift=0, .csw=1, .cw=11, .csw_shift=0, .pkw=1, .psw=1, .pw=11, .psw_shift=0, .on=8, .oh=12, .ow=11, .oc=8, .x_header=1909537237121368064, .x_header_p0=1909537237121368064, .w_header=1909783690934747136, .w_header_p0=1909537237121368064 , .debug_nhwc_words=8448 },
   {.n=8, .l=2, .kw=3, .coe=8, .coe_tl=8, .r_ll=4, .h=12, .w=11, .ci=8, .co=24, .w_kw2=10, .t=3, .p=2, .cm=6, .cm_p0=2, .w_bpt=224, .w_bpt_p0=80, .x_bpt=13736, .x_bpt_p0=4584, .o_bytes=54912, .is_bias=1, .is_flatten=0, .b_offset=17, .b_val_shift=5, .b_bias_shift=0, .ca_nzero=0, .ca_shift=8, .ca_pl_scale=0, .csh=1, .ch=12, .csh_shift=0, .pkh=1, .psh=1, .ph=12, .psh_shift=0, .csw=1, .cw=11, .csw_shift=0, .pkw=1, .psw=1, .pw=11, .psw_shift=0, .on=8, .oh=12, .ow=11, .oc=24, .x_header=2990401147690287104, .x_header_p0=684558138476593152, .w_header=2990647584323796992, .w_header_p0=684558138476593152 , .debug_nhwc_words=25344 },
   {.n=8, .l=2, .kw=1, .coe=24, .coe_tl=0, .r_ll=4, .h=12, .w=11, .ci=24, .co=5, .w_kw2=11, .t=1, .p=2, .cm=20, .cm_p0=4, .w_bpt=248, .w_bpt_p0=56, .x_bpt=45768, .x_bpt_p0=9160, .o_bytes=8580, .is_bias=0, .is_flatten=1, .b_offset=41, .b_val_shift=0, .b_bias_shift=0, .ca_nzero=1, .ca_shift=6, .ca_pl_scale=3, .csh=1, .ch=12, .csh_shift=0, .pkh=1, .psh=1, .ph=12, .psh_shift=0, .csw=1, .cw=11, .csw_shift=0, .pkw=1, .psw=1, .pw=11, .psw_shift=0, .on=1, .oh=8, .ow=1, .oc=660, .x_header=10988794085900288000, .x_header_p0=1765422049045512192, .w_header=10989040539713667072, .w_header_p0=1765422049045512192 , .debug_nhwc_words=5280 },
   {.n=1, .l=1, .kw=1, .coe=24, .coe_tl=0, .r_ll=8, .h=8, .w=1, .ci=660, .co=10, .w_kw2=1, .t=1, .p=33, .cm=20, .cm_p0=20, .w_bpt=248, .w_bpt_p0=248, .x_bpt=268, .x_bpt_p0=268, .o_bytes=80, .is_bias=1, .is_flatten=0, .b_offset=41, .b_val_shift=5, .b_bias_shift=0, .ca_nzero=1, .ca_shift=11, .ca_pl_scale=3, .csh=1, .ch=8, .csh_shift=0, .pkh=1, .psh=1, .ph=8, .psh_shift=0, .csw=1, .cw=1, .csw_shift=0, .pkw=1, .psw=1, .pw=1, .psw_shift=0, .on=1, .oh=8, .ow=1, .oc=10, .x_header=10952754293765046272, .x_header_p0=10952754293765046272, .w_header=10952754456973803520, .w_header_p0=10952754293765046272 , .debug_nhwc_words=80 }
};

#define X_BITS_L2   3
#define W_BITS_L2   2
#define X_PAD       5
#define KH_MAX      11
#define PE_ROWS     8
#define PE_COLS     24

#define WB_BYTES    14418
#define W_BYTES     14288
#define X_BYTES     29976
#define O_WORDS     80
#define O_BYTES_MAX 54912
#define X_BYTES_ALL 167036
#define Y_BYTES     196616
#define B_TYPE      signed short
#define B_WORDS     65
#define DATA_DIR   "D:/dnn-engine/test/vectors"

