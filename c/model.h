#define N_BUNDLES 7
Bundle_t bundles [N_BUNDLES] = {
   {.n=8  , .l=3  , .kw=11 , .coe=2  , .coe_tl=2  , .r_ll=2  , .h=18 , .w=18 , .ci=3  , .co=8  , .w_kw2=13 , .t=4  , .p=3  , .cm=1  , .cm_p0=1  , .xp_words=6048, .w_bpt=140  , .w_bpt_p0=140  , .x_bpt=3032 , .x_bpt_p0=3032 , .o_words=5376 , .o_bytes=2696 , .is_bias=1  , .is_flatten=0  , .b_offset=0  , .b_val_shift=9  , .b_bias_shift=0  , .ca_nzero=0  , .ca_shift=12 , .ca_pl_scale=0  , .csh=2  , .ch=9  , .csh_shift=1  , .pkh=3  , .psh=2  , .ph=5  , .psh_shift=1  , .csw=1  , .cw=18 , .csw_shift=0  , .pkw=4  , .psw=3  , .pw=6  , .psw_shift=0  , .pool=POOL_MAX  , .on=8  , .oh=5  , .ow=6  , .oc=8  , .x_header=               17055749u, .x_header_p0=               17055749u, .w_header=           347372535813u, .w_header_p0=                 17055749u , .debug_nhwc_words=1920  },
   {.n=8  , .l=1  , .kw=1  , .coe=24 , .coe_tl=0  , .r_ll=5  , .h=5  , .w=6  , .ci=8  , .co=8  , .w_kw2=6  , .t=1  , .p=1  , .cm=20 , .cm_p0=8  , .xp_words=672, .w_bpt=104  , .w_bpt_p0=104  , .x_bpt=2696 , .x_bpt_p0=2696 , .o_words=5376 , .o_bytes=2720 , .is_bias=0  , .is_flatten=0  , .b_offset=8  , .b_val_shift=0  , .b_bias_shift=0  , .ca_nzero=1  , .ca_shift=3  , .ca_pl_scale=0  , .csh=1  , .ch=5  , .csh_shift=0  , .pkh=1  , .psh=1  , .ph=5  , .psh_shift=0  , .csw=1  , .cw=6  , .csw_shift=0  , .pkw=1  , .psw=1  , .pw=6  , .psw_shift=0  , .pool=POOL_NONE , .on=8  , .oh=5  , .ow=6  , .oc=8  , .x_header=                  81976u, .x_header_p0=                  81976u, .w_header=           244276346936u, .w_header_p0=                    81976u , .debug_nhwc_words=1920  },
   {.n=8  , .l=1  , .kw=7  , .coe=3  , .coe_tl=2  , .r_ll=5  , .h=5  , .w=6  , .ci=8  , .co=8  , .w_kw2=3  , .t=3  , .p=4  , .cm=2  , .cm_p0=2  , .xp_words=672, .w_bpt=176  , .w_bpt_p0=176  , .x_bpt=680  , .x_bpt_p0=680  , .o_words=5376 , .o_bytes=2704 , .is_bias=1  , .is_flatten=0  , .b_offset=8  , .b_val_shift=9  , .b_bias_shift=0  , .ca_nzero=1  , .ca_shift=12 , .ca_pl_scale=0  , .csh=1  , .ch=5  , .csh_shift=0  , .pkh=1  , .psh=1  , .ph=5  , .psh_shift=0  , .csw=1  , .cw=6  , .csw_shift=0  , .pkw=1  , .psw=1  , .pw=6  , .psw_shift=0  , .pool=POOL_NONE , .on=8  , .oh=5  , .ow=6  , .oc=8  , .x_header=                  81931u, .x_header_p0=                  81931u, .w_header=           450434777099u, .w_header_p0=                    81931u , .debug_nhwc_words=1920  },
   {.n=8  , .l=1  , .kw=5  , .coe=4  , .coe_tl=4  , .r_ll=5  , .h=5  , .w=6  , .ci=8  , .co=8  , .w_kw2=4  , .t=2  , .p=2  , .cm=4  , .cm_p0=4  , .xp_words=672, .w_bpt=248  , .w_bpt_p0=248  , .x_bpt=1352 , .x_bpt_p0=1352 , .o_words=5376 , .o_bytes=2704 , .is_bias=0  , .is_flatten=0  , .b_offset=17 , .b_val_shift=0  , .b_bias_shift=0  , .ca_nzero=1  , .ca_shift=6  , .ca_pl_scale=3  , .csh=1  , .ch=5  , .csh_shift=0  , .pkh=1  , .psh=1  , .ph=5  , .psh_shift=0  , .csw=1  , .cw=6  , .csw_shift=0  , .pkw=1  , .psw=1  , .pw=6  , .psw_shift=0  , .pool=POOL_NONE , .on=8  , .oh=5  , .ow=6  , .oc=8  , .x_header=                  81946u, .x_header_p0=                  81946u, .w_header=           656593207322u, .w_header_p0=                    81946u , .debug_nhwc_words=1920  },
   {.n=8  , .l=1  , .kw=3  , .coe=8  , .coe_tl=8  , .r_ll=5  , .h=5  , .w=6  , .ci=8  , .co=24 , .w_kw2=5  , .t=3  , .p=2  , .cm=6  , .cm_p0=2  , .xp_words=672, .w_bpt=224  , .w_bpt_p0=80   , .x_bpt=2024 , .x_bpt_p0=680  , .o_words=16128, .o_bytes=8080 , .is_bias=1  , .is_flatten=0  , .b_offset=17 , .b_val_shift=9  , .b_bias_shift=0  , .ca_nzero=0  , .ca_shift=12 , .ca_pl_scale=0  , .csh=1  , .ch=5  , .csh_shift=0  , .pkh=1  , .psh=1  , .ph=5  , .psh_shift=0  , .csw=1  , .cw=6  , .csw_shift=0  , .pkw=1  , .psw=1  , .pw=6  , .psw_shift=0  , .pool=POOL_NONE , .on=8  , .oh=5  , .ow=6  , .oc=24 , .x_header=                  81961u, .x_header_p0=                  81929u, .w_header=           587873730601u, .w_header_p0=                    81929u , .debug_nhwc_words=5760  },
   {.n=8  , .l=1  , .kw=1  , .coe=24 , .coe_tl=0  , .r_ll=5  , .h=5  , .w=6  , .ci=24 , .co=10 , .w_kw2=6  , .t=1  , .p=2  , .cm=20 , .cm_p0=4  , .xp_words=672, .w_bpt=248  , .w_bpt_p0=56   , .x_bpt=6728 , .x_bpt_p0=1352 , .o_words=4200 , .o_bytes=2220 , .is_bias=0  , .is_flatten=1  , .b_offset=41 , .b_val_shift=0  , .b_bias_shift=0  , .ca_nzero=1  , .ca_shift=6  , .ca_pl_scale=3  , .csh=1  , .ch=5  , .csh_shift=0  , .pkh=1  , .psh=1  , .ph=5  , .psh_shift=0  , .csw=1  , .cw=6  , .csw_shift=0  , .pkw=1  , .psw=1  , .pw=6  , .psw_shift=0  , .pool=POOL_NONE , .on=1  , .oh=8  , .ow=1  , .oc=300, .x_header=                  82072u, .x_header_p0=                  81944u, .w_header=           656593207448u, .w_header_p0=                    81944u , .debug_nhwc_words=2400  },
   {.n=1  , .l=1  , .kw=1  , .coe=24 , .coe_tl=0  , .r_ll=8  , .h=8  , .w=1  , .ci=300, .co=10 , .w_kw2=1  , .t=1  , .p=15 , .cm=20 , .cm_p0=20 , .xp_words=14 , .w_bpt=248  , .w_bpt_p0=248  , .x_bpt=148  , .x_bpt_p0=148  , .o_words=80   , .o_bytes=320  , .is_bias=1  , .is_flatten=0  , .b_offset=41 , .b_val_shift=9  , .b_bias_shift=0  , .ca_nzero=1  , .ca_shift=15 , .ca_pl_scale=3  , .csh=1  , .ch=8  , .csh_shift=0  , .pkh=1  , .psh=1  , .ph=8  , .psh_shift=0  , .csw=1  , .cw=1  , .csw_shift=0  , .pkw=1  , .psw=1  , .pw=1  , .psw_shift=0  , .pool=POOL_NONE , .on=1  , .oh=8  , .ow=1  , .oc=10 , .x_header=                    152u, .x_header_p0=                    152u, .w_header=           652835029144u, .w_header_p0=                      152u , .debug_nhwc_words=80    }
};

#define X_BITS_L2   2
#define W_BITS_L2   2
#define X_PAD       6
#define KH_MAX      13
#define PE_ROWS     8
#define PE_COLS     24

#define WB_BYTES    9954
#define W_BYTES     9824
#define X_BYTES     9096
#define O_WORDS     80
#define O_WORDS_MAX 16128
#define O_BYTES_MAX 8080
#define X_BYTES_ALL 30220
#define Y_BYTES     110600
#define B_TYPE      int16_t
#define B_WORDS     65
#define DATA_DIR   "D:/dnn-engine/test/vectors"

static const uint8_t X_POSITION_INVERTED_MASKS [] = { 240, 15 };
