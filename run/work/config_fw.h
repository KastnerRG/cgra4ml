#define N_BUNDLES 5
Bundle_t bundles [N_BUNDLES] = {
   {.n=1  , .l=2  , .kw=1  , .coe=96 , .h=14 , .w=14 , .ci=256 , .co=1024, .w_kw2=14 , .t=11 , .p=1  , .cm=512, .cm_p0=256, .on=1  , .oh=14 , .ow=14 , .oc=1024, .ch=14 , .ph=14 , .cw=14 , .pw=14 , .pkh=1  , .psh=1  , .pkw=1  , .psw=1  , .xp_words=196   , .b_offset=0    , .w_bpt=12288, .w_bpt_p0=12288, .x_bpt=25088   , .x_bpt_p0=25088   , .o_words=200704  , .o_bytes=100352  , .ib_out=1   , .in_buffer_idx=-1 , .out_buffer_idx=0  , .add_out_buffer_idx=0 , .add_in_buffer_idx=-1, .is_bias=1  , .is_flatten=0  , .is_softmax=0  , .x_pad=0  , .b_val_shift=9  , .b_bias_shift=0  , .ca_nzero=1  , .ca_shift=12 , .ca_pl_scale=0  , .aa_nzero=0  , .aa_shift=0  , .aa_pl_scale=0  , .pa_nzero=0  , .pa_shift=0  , .pa_pl_scale=0  , .softmax_frac=0  , .csh=1  , .csh_shift=0  , .psh_shift=0  , .csw=1  , .csw_shift=0  , .psw_shift=0  , .pool=POOL_NONE , .softmax_max_f=0              , .header=    2303582550611202152u, .debug_nhwc_words=200704    },
   {.n=1  , .l=2  , .kw=1  , .coe=96 , .h=14 , .w=14 , .ci=1024, .co=256 , .w_kw2=14 , .t=3  , .p=2  , .cm=512, .cm_p0=512, .on=1  , .oh=14 , .ow=14 , .oc=256 , .ch=14 , .ph=14 , .cw=14 , .pw=14 , .pkh=1  , .psh=1  , .pkw=1  , .psw=1  , .xp_words=196   , .b_offset=1056 , .w_bpt=24576, .w_bpt_p0=24576, .x_bpt=50176   , .x_bpt_p0=50176   , .o_words=78848   , .o_bytes=39424   , .ib_out=2   , .in_buffer_idx=0  , .out_buffer_idx=1  , .add_out_buffer_idx=-1, .add_in_buffer_idx=-1, .is_bias=1  , .is_flatten=0  , .is_softmax=0  , .x_pad=0  , .b_val_shift=9  , .b_bias_shift=0  , .ca_nzero=0  , .ca_shift=12 , .ca_pl_scale=0  , .aa_nzero=0  , .aa_shift=0  , .aa_pl_scale=0  , .pa_nzero=0  , .pa_shift=0  , .pa_pl_scale=0  , .softmax_frac=0  , .csh=1  , .csh_shift=0  , .psh_shift=0  , .csw=1  , .csw_shift=0  , .psw_shift=0  , .pool=POOL_NONE , .softmax_max_f=0              , .header=    2305834350559105128u, .debug_nhwc_words=50176     },
   {.n=1  , .l=2  , .kw=3  , .coe=32 , .h=14 , .w=14 , .ci=256 , .co=256 , .w_kw2=13 , .t=8  , .p=2  , .cm=170, .cm_p0=86 , .on=1  , .oh=14 , .ow=14 , .oc=256 , .ch=14 , .ph=14 , .cw=14 , .pw=14 , .pkh=1  , .psh=1  , .pkw=1  , .psw=1  , .xp_words=308   , .b_offset=1344 , .w_bpt=24480, .w_bpt_p0=12384, .x_bpt=26180   , .x_bpt_p0=13244   , .o_words=50176   , .o_bytes=25088   , .ib_out=3   , .in_buffer_idx=1  , .out_buffer_idx=0  , .add_out_buffer_idx=-1, .add_in_buffer_idx=-1, .is_bias=1  , .is_flatten=0  , .is_softmax=0  , .x_pad=4  , .b_val_shift=9  , .b_bias_shift=0  , .ca_nzero=0  , .ca_shift=12 , .ca_pl_scale=0  , .aa_nzero=0  , .aa_shift=0  , .aa_pl_scale=0  , .pa_nzero=0  , .pa_shift=0  , .pa_pl_scale=0  , .softmax_frac=0  , .csh=1  , .csh_shift=0  , .psh_shift=0  , .csw=1  , .csw_shift=0  , .psw_shift=0  , .pool=POOL_NONE , .softmax_max_f=0              , .header=    2294592851648450665u, .debug_nhwc_words=50176     },
   {.n=1  , .l=2  , .kw=1  , .coe=96 , .h=14 , .w=14 , .ci=256 , .co=1024, .w_kw2=14 , .t=11 , .p=1  , .cm=512, .cm_p0=256, .on=1  , .oh=14 , .ow=14 , .oc=1024, .ch=14 , .ph=14 , .cw=14 , .pw=14 , .pkh=1  , .psh=1  , .pkw=1  , .psw=1  , .xp_words=196   , .b_offset=1600 , .w_bpt=12288, .w_bpt_p0=12288, .x_bpt=25088   , .x_bpt_p0=25088   , .o_words=200704  , .o_bytes=100352  , .ib_out=4   , .in_buffer_idx=0  , .out_buffer_idx=1  , .add_out_buffer_idx=-1, .add_in_buffer_idx=0 , .is_bias=1  , .is_flatten=0  , .is_softmax=0  , .x_pad=0  , .b_val_shift=9  , .b_bias_shift=0  , .ca_nzero=1  , .ca_shift=12 , .ca_pl_scale=0  , .aa_nzero=0  , .aa_shift=0  , .aa_pl_scale=0  , .pa_nzero=0  , .pa_shift=0  , .pa_pl_scale=0  , .softmax_frac=0  , .csh=1  , .csh_shift=0  , .psh_shift=0  , .csw=1  , .csw_shift=0  , .psw_shift=0  , .pool=POOL_NONE , .softmax_max_f=0              , .header=    2303582550611202152u, .debug_nhwc_words=200704    },
   {.n=1  , .l=2  , .kw=1  , .coe=96 , .h=14 , .w=14 , .ci=1024, .co=2048, .w_kw2=14 , .t=22 , .p=2  , .cm=512, .cm_p0=512, .on=1  , .oh=7  , .ow=7  , .oc=2048, .ch=7  , .ph=7  , .cw=7  , .pw=7  , .pkh=1  , .psh=1  , .pkw=1  , .psw=1  , .xp_words=196   , .b_offset=2656 , .w_bpt=24576, .w_bpt_p0=24576, .x_bpt=50176   , .x_bpt_p0=50176   , .o_words=100352  , .o_bytes=401408  , .ib_out=-1  , .in_buffer_idx=1  , .out_buffer_idx=-1 , .add_out_buffer_idx=-1, .add_in_buffer_idx=-1, .is_bias=1  , .is_flatten=0  , .is_softmax=0  , .x_pad=0  , .b_val_shift=9  , .b_bias_shift=0  , .ca_nzero=1  , .ca_shift=12 , .ca_pl_scale=0  , .aa_nzero=0  , .aa_shift=0  , .aa_pl_scale=0  , .pa_nzero=0  , .pa_shift=0  , .pa_pl_scale=0  , .softmax_frac=0  , .csh=2  , .csh_shift=0  , .psh_shift=0  , .csw=2  , .csw_shift=0  , .psw_shift=0  , .pool=POOL_NONE , .softmax_max_f=0              , .header=    2305834350559105128u, .debug_nhwc_words=100352    }
};

#define X_BITS_L2   2
#define W_BITS_L2   2
#define KH_MAX      9
#define PE_ROWS     7
#define PE_COLS     96

#define N_OUT_BUF   2
#define N_ADD_BUF   1
#define WB_BYTES    1803584
#define W_BYTES     1794048
#define X_BYTES     25088
#define O_WORDS     100352
#define O_WORDS_MAX 200704
#define O_BYTES_MAX 401408
#define X_BYTES_ALL 290304
#define NHWC_WORDS  401408
#define Y_TYPE      int32_t
#define B_TYPE      int16_t
#define O_TYPE      int32_t
#define B_WORDS     4768
#define AXI_WIDTH   128
#define CONFIG_BASEADDR 0xB0000000
#define DATA_DIR   "../vectors"

static const uint8_t X_POSITION_INVERTED_MASKS [] = { 240, 15 };
