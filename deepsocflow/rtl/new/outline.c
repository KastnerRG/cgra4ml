#define SIM


#define A_START        0x0
#define A_DONE_READ    0x1 // 2
#define A_DONE_WRITE   0x3 // 2
#define A_OCM_BASE     0x5 // 2
#define A_WEIGHTS_BASE 0x7
#define A_BUNDLE_DONE  0x8
#define A_N_BUNDLES_1  0x9
#define A_W_DONE       0xA // W,X,O done are written by PL, read by PS to debug which one hangs
#define A_X_DONE       0xB 
#define A_O_DONE       0xC


#ifdef SIM
	extern int32_t get_config(int32_t offset);
	extern void set_config(int32_t offset, int32_t data);
#else
	int32_t get_config(int32_t offset){
		return *((int32_t*)(CONFIG_BASEADDR + offset));
	}
	void set_config(int32_t offset, int32_t data){	
		*((int32_t*)(CONFIG_BASEADDR + offset)) = data;
	}
#endif

extern EXT_C void model_setup() {
	// use set_config() to set all configs except start
}

extern EXT_C void model_run() {
	set_config(A_START, 1);
	load_y(p_done);
}

void load_y(uint8_t *p_done) {
	// more code
#ifdef SIM // this part is already there. After first call, we jump to waiting stage

  typedef enum {W_DMA, W_SET_READ, W_SET_B_DONE} wait_label_t;
	static wait_label_t wait_label = W_DMA;
  static char is_first_call = 1;

  if      (is_first_call)              is_first_call = 0;
	else if (wait_label == W_SET_READ)   goto SET_READ_WAIT;
	else if (wait_label == W_SET_B_DONE) goto SET_B_DONE_WAIT;
  else if (wait_label == W_DMA)        goto DMA_WAIT;
#endif

	// more code
	for
		for
			for
				...

#ifdef SIM
DMA_WAIT:
	    if (!get_config(A_DONE_WRITE + ocm_bank)) 
	      return; // if sim return, so SV can pass time, and call again, which will jump to DMA_WAIT again
#else
		// in FPGA, wait for write done
		while (!get_config(A_DONE_WRITE + ocm_bank));
#endif
		// more code
		set_config(A_DONE_READ + ocm_bank, 1); // at the end of for iw_kw2
    // more code
	set_config(A_BUNDLE_DONE, 1); // at the end of for ib
	// more code
	*p_done = 1;	
}