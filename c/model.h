#define N_BUNDLES 7
Bundle_t bundles [N_BUNDLES] = {
   {.n=8, .l=3, .kw=11, .coe=2, .coe_tl=2, .r_ll=2, .h=18, .w=8, .ci=3, .co=16, .w_kw2=3, .t=8, .p=3, .cm=1, .cm_p0=1, .w_bpt=140, .w_bpt_p0=140, .x_bpt=2504, .x_bpt_p0=2504, .o_bytes=39936, .is_bias=1, .conv2dense=0, .b_offset=0, .b_val_shift=5, .b_bias_shift=0, .ca_nzero=0, .ca_shift=8, .ca_pl_scale=0, .x_header=414349857415757824, .x_header_p0=414349857415757824, .w_header=414596233919725568, .w_header_p0=414349857415757824 },
   {.n=8, .l=3, .kw=1, .coe=24, .coe_tl=0, .r_ll=2, .h=18, .w=8, .ci=16, .co=16, .w_kw2=8, .t=1, .p=1, .cm=20, .cm_p0=16, .w_bpt=200, .w_bpt_p0=200, .x_bpt=39944, .x_bpt_p0=39944, .o_bytes=39936, .is_bias=0, .conv2dense=0, .b_offset=16, .b_val_shift=0, .b_bias_shift=0, .ca_nzero=1, .ca_shift=3, .ca_pl_scale=0, .x_header=8700973171777470464, .x_header_p0=8700973171777470464, .w_header=8701219591231111168, .w_header_p0=8700973171777470464 },
   {.n=8, .l=3, .kw=7, .coe=3, .coe_tl=4, .r_ll=2, .h=18, .w=8, .ci=16, .co=16, .w_kw2=5, .t=6, .p=8, .cm=2, .cm_p0=2, .w_bpt=176, .w_bpt_p0=176, .x_bpt=5000, .x_bpt_p0=5000, .o_bytes=39936, .is_bias=1, .conv2dense=0, .b_offset=16, .b_val_shift=5, .b_bias_shift=0, .ca_nzero=1, .ca_shift=8, .ca_pl_scale=0, .x_header=846695421643325440, .x_header_p0=846695421643325440, .w_header=846941823917096960, .w_header_p0=846695421643325440 },
   {.n=8, .l=3, .kw=5, .coe=4, .coe_tl=4, .r_ll=2, .h=18, .w=8, .ci=16, .co=16, .w_kw2=6, .t=4, .p=4, .cm=4, .cm_p0=4, .w_bpt=248, .w_bpt_p0=248, .x_bpt=9992, .x_bpt_p0=9992, .o_bytes=39936, .is_bias=0, .conv2dense=0, .b_offset=34, .b_val_shift=0, .b_bias_shift=0, .ca_nzero=1, .ca_shift=6, .ca_pl_scale=3, .x_header=1927559332212244480, .x_header_p0=1927559332212244480, .w_header=1927805786025623552, .w_header_p0=1927559332212244480 },
   {.n=8, .l=3, .kw=3, .coe=8, .coe_tl=8, .r_ll=2, .h=18, .w=8, .ci=16, .co=24, .w_kw2=7, .t=3, .p=3, .cm=6, .cm_p0=4, .w_bpt=224, .w_bpt_p0=152, .x_bpt=14984, .x_bpt_p0=9992, .o_bytes=59904, .is_bias=1, .conv2dense=0, .b_offset=34, .b_val_shift=5, .b_bias_shift=0, .ca_nzero=0, .ca_shift=8, .ca_pl_scale=0, .x_header=3008423242781163520, .x_header_p0=1855501738174316544, .w_header=3008669679414673408, .w_header_p0=1855501738174316544 },
   {.n=8, .l=3, .kw=1, .coe=24, .coe_tl=2, .r_ll=2, .h=18, .w=8, .ci=24, .co=50, .w_kw2=8, .t=3, .p=2, .cm=20, .cm_p0=4, .w_bpt=248, .w_bpt_p0=56, .x_bpt=49928, .x_bpt_p0=9992, .o_bytes=93600, .is_bias=0, .conv2dense=1, .b_offset=58, .b_val_shift=0, .b_bias_shift=0, .ca_nzero=1, .ca_shift=6, .ca_pl_scale=3, .x_header=11006816180991164416, .x_header_p0=1783444144136388608, .w_header=11007062634804543488, .w_header_p0=1783444144136388608 },
   {.n=1, .l=1, .kw=1, .coe=24, .coe_tl=0, .r_ll=8, .h=8, .w=1, .ci=7200, .co=10, .w_kw2=1, .t=1, .p=360, .cm=20, .cm_p0=20, .w_bpt=248, .w_bpt_p0=248, .x_bpt=268, .x_bpt_p0=268, .o_bytes=80, .is_bias=1, .conv2dense=0, .b_offset=58, .b_val_shift=5, .b_bias_shift=0, .ca_nzero=1, .ca_shift=11, .ca_pl_scale=3, .x_header=10952754293765046272, .x_header_p0=10952754293765046272, .w_header=10952754456973803520, .w_header_p0=10952754293765046272 }
};

#define X_BITS_L2   3
#define W_BITS_L2   2
#define X_PAD       5
#define KH_MAX      11
#define PE_ROWS     8
#define PE_COLS     24

#define WB_BYTES    108132
#define W_BYTES     107968
#define X_BYTES     7512
#define O_WORDS     80
#define O_BYTES_MAX 93600
#define X_BYTES_ALL 323784
#define Y_BYTES     442376
#define B_TYPE      signed short
#define B_WORDS     82
#define DATA_DIR   "D:/dnn-engine/test/vectors"

