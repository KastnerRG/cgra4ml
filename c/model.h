#define N_BUNDLES 7
Bundle_t bundles [N_BUNDLES] = {
   {.n=8, .l=3, .kw=11, .coe=2, .coe_tl=2, .r_ll=8, .h=24, .w=32, .ci=3, .co=16, .w_kw2=27, .t=8, .p=3, .cm=1, .cm_p0=1, .w_bpt=140, .w_bpt_p0=140, .x_bpt=9992, .x_bpt_p0=9992, .o_bytes=36608, .is_bias=1, .is_flatten=0, .b_offset=0, .b_val_shift=5, .b_bias_shift=0, .ca_nzero=0, .ca_shift=8, .ca_pl_scale=0, .csh=2, .ch=12, .csh_shift=1, .pkh=0, .psh=0, .ph=0, .psh_shift=0, .csw=3, .cw=11, .csw_shift=1, .pkw=0, .psw=0, .pw=0, .psw_shift=0, .oh=12, .ow=11, .x_header=414356454485524480, .x_header_p0=414356454485524480, .w_header=414602830989492224, .w_header_p0=414356454485524480 , .debug_nhwc_words=16896 },
   {.n=8, .l=2, .kw=1, .coe=24, .coe_tl=0, .r_ll=4, .h=12, .w=11, .ci=16, .co=16, .w_kw2=11, .t=1, .p=1, .cm=20, .cm_p0=16, .w_bpt=200, .w_bpt_p0=200, .x_bpt=36616, .x_bpt_p0=36616, .o_bytes=36608, .is_bias=0, .is_flatten=0, .b_offset=16, .b_val_shift=0, .b_bias_shift=0, .ca_nzero=1, .ca_shift=3, .ca_pl_scale=0, .csh=1, .ch=12, .csh_shift=0, .pkh=0, .psh=0, .ph=0, .psh_shift=0, .csw=1, .cw=11, .csw_shift=0, .pkw=0, .psw=0, .pw=0, .psw_shift=0, .oh=12, .ow=11, .x_header=8682951076686594048, .x_header_p0=8682951076686594048, .w_header=8683197496140234752, .w_header_p0=8682951076686594048 , .debug_nhwc_words=16896 },
   {.n=8, .l=2, .kw=7, .coe=3, .coe_tl=4, .r_ll=4, .h=12, .w=11, .ci=16, .co=16, .w_kw2=8, .t=6, .p=8, .cm=2, .cm_p0=2, .w_bpt=176, .w_bpt_p0=176, .x_bpt=4584, .x_bpt_p0=4584, .o_bytes=36608, .is_bias=1, .is_flatten=0, .b_offset=16, .b_val_shift=5, .b_bias_shift=0, .ca_nzero=1, .ca_shift=8, .ca_pl_scale=0, .csh=1, .ch=12, .csh_shift=0, .pkh=0, .psh=0, .ph=0, .psh_shift=0, .csw=1, .cw=11, .csw_shift=0, .pkw=0, .psw=0, .pw=0, .psw_shift=0, .oh=12, .ow=11, .x_header=828673326552449024, .x_header_p0=828673326552449024, .w_header=828919728826220544, .w_header_p0=828673326552449024 , .debug_nhwc_words=16896 },
   {.n=8, .l=2, .kw=5, .coe=4, .coe_tl=4, .r_ll=4, .h=12, .w=11, .ci=16, .co=16, .w_kw2=9, .t=4, .p=4, .cm=4, .cm_p0=4, .w_bpt=248, .w_bpt_p0=248, .x_bpt=9160, .x_bpt_p0=9160, .o_bytes=36608, .is_bias=0, .is_flatten=0, .b_offset=34, .b_val_shift=0, .b_bias_shift=0, .ca_nzero=1, .ca_shift=6, .ca_pl_scale=3, .csh=1, .ch=12, .csh_shift=0, .pkh=0, .psh=0, .ph=0, .psh_shift=0, .csw=1, .cw=11, .csw_shift=0, .pkw=0, .psw=0, .pw=0, .psw_shift=0, .oh=12, .ow=11, .x_header=1909537237121368064, .x_header_p0=1909537237121368064, .w_header=1909783690934747136, .w_header_p0=1909537237121368064 , .debug_nhwc_words=16896 },
   {.n=8, .l=2, .kw=3, .coe=8, .coe_tl=8, .r_ll=4, .h=12, .w=11, .ci=16, .co=24, .w_kw2=10, .t=3, .p=3, .cm=6, .cm_p0=4, .w_bpt=224, .w_bpt_p0=152, .x_bpt=13736, .x_bpt_p0=9160, .o_bytes=54912, .is_bias=1, .is_flatten=0, .b_offset=34, .b_val_shift=5, .b_bias_shift=0, .ca_nzero=0, .ca_shift=8, .ca_pl_scale=0, .csh=1, .ch=12, .csh_shift=0, .pkh=0, .psh=0, .ph=0, .psh_shift=0, .csw=1, .cw=11, .csw_shift=0, .pkw=0, .psw=0, .pw=0, .psw_shift=0, .oh=12, .ow=11, .x_header=2990401147690287104, .x_header_p0=1837479643083440128, .w_header=2990647584323796992, .w_header_p0=1837479643083440128 , .debug_nhwc_words=25344 },
   {.n=8, .l=2, .kw=1, .coe=24, .coe_tl=2, .r_ll=4, .h=12, .w=11, .ci=24, .co=50, .w_kw2=11, .t=3, .p=2, .cm=20, .cm_p0=4, .w_bpt=248, .w_bpt_p0=56, .x_bpt=45768, .x_bpt_p0=9160, .o_bytes=85800, .is_bias=0, .is_flatten=1, .b_offset=58, .b_val_shift=0, .b_bias_shift=0, .ca_nzero=1, .ca_shift=6, .ca_pl_scale=3, .csh=1, .ch=12, .csh_shift=0, .pkh=0, .psh=0, .ph=0, .psh_shift=0, .csw=1, .cw=11, .csw_shift=0, .pkw=0, .psw=0, .pw=0, .psw_shift=0, .oh=12, .ow=11, .x_header=10988794085900288000, .x_header_p0=1765422049045512192, .w_header=10989040539713667072, .w_header_p0=1765422049045512192 , .debug_nhwc_words=52800 },
   {.n=1, .l=1, .kw=1, .coe=24, .coe_tl=0, .r_ll=8, .h=8, .w=1, .ci=6600, .co=10, .w_kw2=1, .t=1, .p=330, .cm=20, .cm_p0=20, .w_bpt=248, .w_bpt_p0=248, .x_bpt=268, .x_bpt_p0=268, .o_bytes=80, .is_bias=1, .is_flatten=0, .b_offset=58, .b_val_shift=5, .b_bias_shift=0, .ca_nzero=1, .ca_shift=11, .ca_pl_scale=3, .csh=1, .ch=8, .csh_shift=0, .pkh=0, .psh=0, .ph=0, .psh_shift=0, .csw=1, .cw=1, .csw_shift=0, .pkw=0, .psw=0, .pw=0, .psw_shift=0, .oh=8, .ow=1, .x_header=10952754293765046272, .x_header_p0=10952754293765046272, .w_header=10952754456973803520, .w_header_p0=10952754293765046272 , .debug_nhwc_words=80 }
};

#define X_BITS_L2   3
#define W_BITS_L2   2
#define X_PAD       5
#define KH_MAX      11
#define PE_ROWS     8
#define PE_COLS     24

#define WB_BYTES    100692
#define W_BYTES     100528
#define X_BYTES     29976
#define O_WORDS     80
#define O_BYTES_MAX 85800
#define X_BYTES_ALL 319904
#define Y_BYTES     405512
#define B_TYPE      signed short
#define B_WORDS     82
#define DATA_DIR   "D:/dnn-engine/test/vectors"

