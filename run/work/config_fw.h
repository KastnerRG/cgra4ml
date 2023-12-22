#define N_BUNDLES 5
Bundle_t bundles [N_BUNDLES] = {
   {.n=1  , .l=1  , .kw=11 , .coe=2  , .coe_tl=2  , .r_ll=8  , .h=8  , .w=8  , .ci=3   , .co=8  , .w_kw2=3  , .t=4  , .p=3  , .cm=1  , .cm_p0=1  , .xp_words=112 , .ib_out=1   , .w_bpt=280  , .w_bpt_p0=280  , .x_bpt=128  , .x_bpt_p0=128  , .o_words=336  , .o_bytes=352  , .out_buffer_idx=0 , .add_out_buffer_idx=0 , .add_in_buffer_idx=-1, .is_bias=1  , .is_flatten=0  , .is_softmax=0  , .b_offset=0  , .b_val_shift=1  , .b_bias_shift=0  , .ca_nzero=0  , .ca_shift=8  , .ca_pl_scale=0  , .aa_nzero=0  , .aa_shift=0  , .aa_pl_scale=0  , .pa_nzero=1  , .pa_shift=0  , .pa_pl_scale=0  , .softmax_frac=0  , .softmax_max_f=0              , .csh=2  , .ch=4  , .csh_shift=1  , .pkh=3  , .psh=2  , .ph=2  , .psh_shift=0  , .csw=1  , .cw=8  , .csw_shift=0  , .pkw=4  , .psw=3  , .pw=3  , .psw_shift=1  , .pool=POOL_AVG  , .on=1  , .oh=2  , .ow=3  , .oc=8  , .x_header=                 114693u, .x_header_p0=                 114693u, .w_header=           343597498373u, .w_header_p0=                   114693u , .debug_nhwc_words=48    },
   {.n=1  , .l=1  , .kw=1  , .coe=24 , .coe_tl=0  , .r_ll=2  , .h=2  , .w=3  , .ci=8   , .co=8  , .w_kw2=3  , .t=1  , .p=1  , .cm=20 , .cm_p0=8  , .xp_words=42  , .ib_out=2   , .w_bpt=208  , .w_bpt_p0=208  , .x_bpt=352  , .x_bpt_p0=352  , .o_words=336  , .o_bytes=368  , .out_buffer_idx=1 , .add_out_buffer_idx=-1, .add_in_buffer_idx=0 , .is_bias=1  , .is_flatten=0  , .is_softmax=0  , .b_offset=8  , .b_val_shift=1  , .b_bias_shift=0  , .ca_nzero=1  , .ca_shift=8  , .ca_pl_scale=0  , .aa_nzero=1  , .aa_shift=0  , .aa_pl_scale=0  , .pa_nzero=0  , .pa_shift=0  , .pa_pl_scale=0  , .softmax_frac=0  , .softmax_max_f=0              , .csh=1  , .ch=2  , .csh_shift=0  , .pkh=1  , .psh=1  , .ph=2  , .psh_shift=0  , .csw=1  , .cw=3  , .csw_shift=0  , .pkw=1  , .psw=1  , .pw=3  , .psw_shift=0  , .pool=POOL_NONE , .on=1  , .oh=2  , .ow=3  , .oc=8  , .x_header=                  32824u, .x_header_p0=                  32824u, .w_header=           240518201400u, .w_header_p0=                    32824u , .debug_nhwc_words=48    },
   {.n=1  , .l=1  , .kw=3  , .coe=8  , .coe_tl=8  , .r_ll=2  , .h=2  , .w=3  , .ci=8   , .co=24 , .w_kw2=2  , .t=3  , .p=2  , .cm=6  , .cm_p0=2  , .xp_words=42  , .ib_out=3   , .w_bpt=448  , .w_bpt_p0=160  , .x_bpt=268  , .x_bpt_p0=100  , .o_words=1008 , .o_bytes=1040 , .out_buffer_idx=0 , .add_out_buffer_idx=-1, .add_in_buffer_idx=-1, .is_bias=1  , .is_flatten=0  , .is_softmax=0  , .b_offset=32 , .b_val_shift=1  , .b_bias_shift=0  , .ca_nzero=0  , .ca_shift=8  , .ca_pl_scale=0  , .aa_nzero=0  , .aa_shift=0  , .aa_pl_scale=0  , .pa_nzero=0  , .pa_shift=0  , .pa_pl_scale=0  , .softmax_frac=0  , .softmax_max_f=0              , .csh=1  , .ch=2  , .csh_shift=0  , .pkh=1  , .psh=1  , .ph=2  , .psh_shift=0  , .csw=1  , .cw=3  , .csw_shift=0  , .pkw=1  , .psw=1  , .pw=3  , .psw_shift=0  , .pool=POOL_NONE , .on=1  , .oh=2  , .ow=3  , .oc=24 , .x_header=                  32809u, .x_header_p0=                  32777u, .w_header=           584115585065u, .w_header_p0=                    32777u , .debug_nhwc_words=144   },
   {.n=1  , .l=1  , .kw=1  , .coe=24 , .coe_tl=0  , .r_ll=2  , .h=2  , .w=3  , .ci=24  , .co=10 , .w_kw2=3  , .t=1  , .p=2  , .cm=20 , .cm_p0=4  , .xp_words=42  , .ib_out=4   , .w_bpt=496  , .w_bpt_p0=112  , .x_bpt=856  , .x_bpt_p0=184  , .o_words=840  , .o_bytes=888  , .out_buffer_idx=1 , .add_out_buffer_idx=-1, .add_in_buffer_idx=-1, .is_bias=1  , .is_flatten=1  , .is_softmax=0  , .b_offset=56 , .b_val_shift=1  , .b_bias_shift=0  , .ca_nzero=1  , .ca_shift=11 , .ca_pl_scale=3  , .aa_nzero=0  , .aa_shift=0  , .aa_pl_scale=0  , .pa_nzero=0  , .pa_shift=0  , .pa_pl_scale=0  , .softmax_frac=0  , .softmax_max_f=0              , .csh=1  , .ch=2  , .csh_shift=0  , .pkh=1  , .psh=1  , .ph=2  , .psh_shift=0  , .csw=1  , .cw=3  , .csw_shift=0  , .pkw=1  , .psw=1  , .pw=3  , .psw_shift=0  , .pool=POOL_NONE , .on=1  , .oh=1  , .ow=1  , .oc=60 , .x_header=                  32920u, .x_header_p0=                  32792u, .w_header=           652835061912u, .w_header_p0=                    32792u , .debug_nhwc_words=60    },
   {.n=1  , .l=1  , .kw=1  , .coe=24 , .coe_tl=0  , .r_ll=1  , .h=1  , .w=1  , .ci=60  , .co=10 , .w_kw2=1  , .t=1  , .p=3  , .cm=20 , .cm_p0=20 , .xp_words=14  , .ib_out=-1  , .w_bpt=496  , .w_bpt_p0=496  , .x_bpt=296  , .x_bpt_p0=296  , .o_words=10   , .o_bytes=40   , .out_buffer_idx=-1, .add_out_buffer_idx=-1, .add_in_buffer_idx=-1, .is_bias=1  , .is_flatten=0  , .is_softmax=1  , .b_offset=80 , .b_val_shift=1  , .b_bias_shift=0  , .ca_nzero=1  , .ca_shift=11 , .ca_pl_scale=3  , .aa_nzero=0  , .aa_shift=0  , .aa_pl_scale=0  , .pa_nzero=0  , .pa_shift=0  , .pa_pl_scale=0  , .softmax_frac=7  , .softmax_max_f=0.9921875      , .csh=1  , .ch=1  , .csh_shift=0  , .pkh=1  , .psh=1  , .ph=1  , .psh_shift=0  , .csw=1  , .cw=1  , .csw_shift=0  , .pkw=1  , .psw=1  , .pw=1  , .psw_shift=0  , .pool=POOL_NONE , .on=1  , .oh=1  , .ow=1  , .oc=10 , .x_header=                    152u, .x_header_p0=                    152u, .w_header=           652835029144u, .w_header_p0=                      152u , .debug_nhwc_words=10    }
};

#define X_BITS_L2   3
#define W_BITS_L2   3
#define X_PAD       6
#define KH_MAX      13
#define PE_ROWS     8
#define PE_COLS     24

#define N_ADD_BUF   1
#define WB_BYTES    7696
#define W_BYTES     7488
#define X_BYTES     384
#define O_WORDS     10
#define O_WORDS_MAX 1008
#define O_BYTES_MAX 1040
#define X_BYTES_ALL 3032
#define NHWC_WORDS  512
#define Y_TYPE      int32_t
#define B_TYPE      int16_t
#define O_TYPE      float
#define B_WORDS     104
#define AXI_WIDTH   128
#define DATA_DIR   "../vectors"

static const uint8_t X_POSITION_INVERTED_MASKS [] = { 0 };
