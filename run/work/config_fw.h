#define N_BUNDLES 3
Bundle_t bundles [N_BUNDLES] = {
   {.n=8  , .l=3  , .kw=3  , .coe=8  , .coe_tl=8  , .r_ll=2  , .h=18 , .w=18 , .ci=3   , .co=24  , .w_kw2=17 , .t=3  , .p=1  , .cm=170, .cm_p0=3  , .xp_words=4752  , .ib_out=1   , .w_bpt=124  , .w_bpt_p0=124  , .x_bpt=7144    , .x_bpt_p0=7144    , .o_words=114048  , .o_bytes=57040   , .in_buffer_idx=-1 , .out_buffer_idx=0  , .add_out_buffer_idx=-1, .add_in_buffer_idx=-1, .is_bias=1  , .is_flatten=0  , .is_softmax=0  , .b_offset=0    , .b_val_shift=9  , .b_bias_shift=0  , .ca_nzero=0  , .ca_shift=12 , .ca_pl_scale=0  , .aa_nzero=0  , .aa_shift=0  , .aa_pl_scale=0  , .pa_nzero=0  , .pa_shift=0  , .pa_pl_scale=0  , .softmax_frac=0  , .softmax_max_f=0              , .csh=1  , .ch=18 , .csh_shift=0  , .pkh=1  , .psh=1  , .ph=18 , .psh_shift=0  , .csw=1  , .cw=18 , .csw_shift=0  , .pkw=1  , .psw=1  , .pw=18 , .psw_shift=0  , .pool=POOL_NONE , .on=8  , .oh=18 , .ow=18 , .oc=24  , .x_header=                8527881u, .x_header_p0=                8527881u, .w_header=           139326529545u, .w_header_p0=                  8527881u , .debug_nhwc_words=62208     },
   {.n=8  , .l=3  , .kw=1  , .coe=24 , .coe_tl=0  , .r_ll=2  , .h=18 , .w=18 , .ci=24  , .co=10  , .w_kw2=18 , .t=1  , .p=1  , .cm=512, .cm_p0=24 , .xp_words=4752  , .ib_out=2   , .w_bpt=304  , .w_bpt_p0=304  , .x_bpt=57040   , .x_bpt_p0=57040   , .o_words=35640   , .o_bytes=17932   , .in_buffer_idx=0  , .out_buffer_idx=1  , .add_out_buffer_idx=-1, .add_in_buffer_idx=-1, .is_bias=1  , .is_flatten=1  , .is_softmax=0  , .b_offset=24   , .b_val_shift=9  , .b_bias_shift=0  , .ca_nzero=1  , .ca_shift=15 , .ca_pl_scale=3  , .aa_nzero=0  , .aa_shift=0  , .aa_pl_scale=0  , .pa_nzero=0  , .pa_shift=0  , .pa_pl_scale=0  , .softmax_frac=0  , .softmax_max_f=0              , .csh=1  , .ch=18 , .csh_shift=0  , .pkh=1  , .psh=1  , .ph=18 , .psh_shift=0  , .csw=1  , .cw=18 , .csw_shift=0  , .pkw=1  , .psw=1  , .pw=18 , .psw_shift=0  , .pool=POOL_NONE , .on=1  , .oh=8  , .ow=1  , .oc=3240, .x_header=                8527964u, .x_header_p0=                8527964u, .w_header=           397024567388u, .w_header_p0=                  8527964u , .debug_nhwc_words=25920     },
   {.n=1  , .l=1  , .kw=1  , .coe=24 , .coe_tl=0  , .r_ll=8  , .h=8  , .w=1  , .ci=3240, .co=10  , .w_kw2=1  , .t=1  , .p=7  , .cm=512, .cm_p0=168, .xp_words=11    , .ib_out=-1  , .w_bpt=6160 , .w_bpt_p0=2032 , .x_bpt=2832    , .x_bpt_p0=940     , .o_words=80      , .o_bytes=320     , .in_buffer_idx=1  , .out_buffer_idx=-1 , .add_out_buffer_idx=-1, .add_in_buffer_idx=-1, .is_bias=1  , .is_flatten=0  , .is_softmax=1  , .b_offset=48   , .b_val_shift=9  , .b_bias_shift=0  , .ca_nzero=1  , .ca_shift=15 , .ca_pl_scale=3  , .aa_nzero=0  , .aa_shift=0  , .aa_pl_scale=0  , .pa_nzero=0  , .pa_shift=0  , .pa_pl_scale=0  , .softmax_frac=3  , .softmax_max_f=0.875          , .csh=1  , .ch=8  , .csh_shift=0  , .pkh=1  , .psh=1  , .ph=8  , .psh_shift=0  , .csw=1  , .cw=1  , .csw_shift=0  , .pkw=1  , .psw=1  , .pw=1  , .psw_shift=0  , .pool=POOL_NONE , .on=1  , .oh=8  , .ow=1  , .oc=10  , .x_header=                   2044u, .x_header_p0=                    668u, .w_header=          8778913155068u, .w_header_p0=                      668u , .debug_nhwc_words=80        }
};

#define X_BITS_L2   2
#define W_BITS_L2   2
#define X_PAD       3
#define KH_MAX      7
#define PE_ROWS     8
#define PE_COLS     24

#define N_OUT_BUF   2
#define N_ADD_BUF   
#define WB_BYTES    39812
#define W_BYTES     39668
#define X_BYTES     7144
#define O_WORDS     80
#define O_WORDS_MAX 114048
#define O_BYTES_MAX 57040
#define X_BYTES_ALL 82116
#define NHWC_WORDS  62208
#define Y_TYPE      int32_t
#define B_TYPE      int16_t
#define O_TYPE      float
#define B_WORDS     72
#define AXI_WIDTH   128
#define DATA_DIR   "../vectors"

static const uint8_t X_POSITION_INVERTED_MASKS [] = { 240, 15 };
