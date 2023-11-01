#define N_BUNDLES 7
Bundle_t bundles [N_BUNDLES] = {
   {.n=8  , .l=3  , .kw=11 , .coe=2  , .coe_tl=2  , .r_ll=2  , .h=18 , .w=18 , .ci=3  , .co=8  , .w_kw2=13 , .t=4  , .p=3  , .cm=1  , .cm_p0=1  , .w_bpt=272  , .w_bpt_p0=272  , .x_bpt=5624 , .x_bpt_p0=5624 , .o_bytes=4992 , .is_bias=1  , .is_flatten=0  , .b_offset=0  , .b_val_shift=1  , .b_bias_shift=0  , .ca_nzero=0  , .ca_shift=8  , .ca_pl_scale=0  , .csh=2  , .ch=9  , .csh_shift=1  , .pkh=3  , .psh=2  , .ph=5  , .psh_shift=1  , .csw=1  , .cw=18 , .csw_shift=0  , .pkw=4  , .psw=3  , .pw=6  , .psw_shift=0  , .pool=POOL_MAX  , .on=8  , .oh=5  , .ow=6  , .oc=8  , .x_header=     378324358931677184u, .x_header_p0=     378324358931677184u, .w_header=     378570735435644928u, .w_header_p0=       378324358931677184u , .debug_nhwc_words=1920  },
   {.n=8  , .l=1  , .kw=1  , .coe=24 , .coe_tl=0  , .r_ll=5  , .h=5  , .w=6  , .ci=8  , .co=8  , .w_kw2=6  , .t=1  , .p=1  , .cm=20 , .cm_p0=8  , .w_bpt=200  , .w_bpt_p0=200  , .x_bpt=5000 , .x_bpt_p0=5000 , .o_bytes=4992 , .is_bias=0  , .is_flatten=0  , .b_offset=8  , .b_val_shift=0  , .b_bias_shift=0  , .ca_nzero=1  , .ca_shift=7  , .ca_pl_scale=0  , .csh=1  , .ch=5  , .csh_shift=0  , .pkh=1  , .psh=1  , .ph=5  , .psh_shift=0  , .csw=1  , .cw=6  , .csw_shift=0  , .pkw=1  , .psw=1  , .pw=6  , .psw_shift=0  , .pool=POOL_NONE , .on=8  , .oh=5  , .ow=6  , .oc=8  , .x_header=    4053240764145074176u, .x_header_p0=    4053240764145074176u, .w_header=    4053487114879238144u, .w_header_p0=      4053240764145074176u , .debug_nhwc_words=1920  },
   {.n=8  , .l=1  , .kw=7  , .coe=3  , .coe_tl=2  , .r_ll=5  , .h=5  , .w=6  , .ci=8  , .co=8  , .w_kw2=3  , .t=3  , .p=4  , .cm=2  , .cm_p0=2  , .w_bpt=344  , .w_bpt_p0=344  , .x_bpt=1256 , .x_bpt_p0=1256 , .o_bytes=4992 , .is_bias=1  , .is_flatten=0  , .b_offset=8  , .b_val_shift=1  , .b_bias_shift=0  , .ca_nzero=1  , .ca_shift=8  , .ca_pl_scale=0  , .csh=1  , .ch=5  , .csh_shift=0  , .pkh=1  , .psh=1  , .ph=5  , .psh_shift=0  , .csw=1  , .cw=6  , .csw_shift=0  , .pkw=1  , .psw=1  , .pw=6  , .psw_shift=0  , .pool=POOL_NONE , .on=8  , .oh=5  , .ow=6  , .oc=8  , .x_header=     810649032438317056u, .x_header_p0=     810649032438317056u, .w_header=     810895434712088576u, .w_header_p0=       810649032438317056u , .debug_nhwc_words=1920  },
   {.n=8  , .l=1  , .kw=5  , .coe=4  , .coe_tl=4  , .r_ll=5  , .h=5  , .w=6  , .ci=8  , .co=8  , .w_kw2=4  , .t=2  , .p=2  , .cm=4  , .cm_p0=4  , .w_bpt=488  , .w_bpt_p0=488  , .x_bpt=2504 , .x_bpt_p0=2504 , .o_bytes=4992 , .is_bias=0  , .is_flatten=0  , .b_offset=17 , .b_val_shift=0  , .b_bias_shift=0  , .ca_nzero=1  , .ca_shift=10 , .ca_pl_scale=3  , .csh=1  , .ch=5  , .csh_shift=0  , .pkh=1  , .psh=1  , .ph=5  , .psh_shift=0  , .csw=1  , .cw=6  , .csw_shift=0  , .pkw=1  , .psw=1  , .pw=6  , .psw_shift=0  , .pool=POOL_NONE , .on=8  , .oh=5  , .ow=6  , .oc=8  , .x_header=    1891512943007236096u, .x_header_p0=    1891512943007236096u, .w_header=    1891759396820615168u, .w_header_p0=      1891512943007236096u , .debug_nhwc_words=1920  },
   {.n=8  , .l=1  , .kw=3  , .coe=8  , .coe_tl=8  , .r_ll=5  , .h=5  , .w=6  , .ci=8  , .co=24 , .w_kw2=5  , .t=3  , .p=2  , .cm=6  , .cm_p0=2  , .w_bpt=440  , .w_bpt_p0=152  , .x_bpt=3752 , .x_bpt_p0=1256 , .o_bytes=14976, .is_bias=1  , .is_flatten=0  , .b_offset=17 , .b_val_shift=1  , .b_bias_shift=0  , .ca_nzero=0  , .ca_shift=8  , .ca_pl_scale=0  , .csh=1  , .ch=5  , .csh_shift=0  , .pkh=1  , .psh=1  , .ph=5  , .psh_shift=0  , .csw=1  , .cw=6  , .csw_shift=0  , .pkw=1  , .psw=1  , .pw=6  , .psw_shift=0  , .pool=POOL_NONE , .on=8  , .oh=5  , .ow=6  , .oc=24 , .x_header=    2972376853576155136u, .x_header_p0=     666533844362461184u, .w_header=    2972623290209665024u, .w_header_p0=       666533844362461184u , .debug_nhwc_words=5760  },
   {.n=8  , .l=1  , .kw=1  , .coe=24 , .coe_tl=0  , .r_ll=5  , .h=5  , .w=6  , .ci=24 , .co=10 , .w_kw2=6  , .t=1  , .p=2  , .cm=20 , .cm_p0=4  , .w_bpt=488  , .w_bpt_p0=104  , .x_bpt=12488, .x_bpt_p0=2504 , .o_bytes=3900 , .is_bias=0  , .is_flatten=1  , .b_offset=41 , .b_val_shift=0  , .b_bias_shift=0  , .ca_nzero=1  , .ca_shift=10 , .ca_pl_scale=3  , .csh=1  , .ch=5  , .csh_shift=0  , .pkh=1  , .psh=1  , .ph=5  , .psh_shift=0  , .csw=1  , .cw=6  , .csw_shift=0  , .pkw=1  , .psw=1  , .pw=6  , .psw_shift=0  , .pool=POOL_NONE , .on=1  , .oh=8  , .ow=1  , .oc=300, .x_header=   10970769791786156032u, .x_header_p0=    1747397754931380224u, .w_header=   10971016245599535104u, .w_header_p0=      1747397754931380224u , .debug_nhwc_words=2400  },
   {.n=1  , .l=1  , .kw=1  , .coe=24 , .coe_tl=0  , .r_ll=8  , .h=8  , .w=1  , .ci=300, .co=10 , .w_kw2=1  , .t=1  , .p=15 , .cm=20 , .cm_p0=20 , .w_bpt=488  , .w_bpt_p0=488  , .x_bpt=268  , .x_bpt_p0=268  , .o_bytes=80   , .is_bias=1  , .is_flatten=0  , .b_offset=41 , .b_val_shift=1  , .b_bias_shift=0  , .ca_nzero=1  , .ca_shift=11 , .ca_pl_scale=3  , .csh=1  , .ch=8  , .csh_shift=0  , .pkh=1  , .psh=1  , .ph=8  , .psh_shift=0  , .csw=1  , .cw=1  , .csw_shift=0  , .pkw=1  , .psw=1  , .pw=1  , .psw_shift=0  , .pool=POOL_NONE , .on=1  , .oh=8  , .ow=1  , .oc=10 , .x_header=   10952754293765046272u, .x_header_p0=   10952754293765046272u, .w_header=   10952754456973803520u, .w_header_p0=     10952754293765046272u , .debug_nhwc_words=80    }
};

#define X_BITS_L2   3
#define W_BITS_L2   3
#define X_PAD       5
#define KH_MAX      11
#define PE_ROWS     8
#define PE_COLS     24

#define WB_BYTES    19362
#define W_BYTES     19232
#define X_BYTES     16872
#define O_WORDS     80
#define O_BYTES_MAX 14976
#define X_BYTES_ALL 55924
#define Y_BYTES     110600
#define B_TYPE      int16_t
#define B_WORDS     65
#define DATA_DIR   "D:/dnn-engine/test/vectors"

