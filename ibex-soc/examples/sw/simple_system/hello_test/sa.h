
typedef struct {
  TK k [K][C];
  TX x [K][R];
  TY a [C][R];
  TY y [C][R];
} Memory_st;

// #define mem_phy (*(Memory_st* restrict)MEM_BASEADDR)
Memory_st mem_phy;

volatile uint32_t get_config(void *config_base, uint32_t offset){
    const volatile uint32_t *p = (const volatile uint32_t *)((uintptr_t)config_base + offset * 4u);
    return *p;
}

void set_config(void *config_base, uint32_t offset, uint32_t data){	
  *(volatile uint32_t *restrict)(config_base + offset*4) = data;
}

uint32_t addr_64to32 (void* addr){
  return (uint32_t)((uintptr_t)addr);
}

static unsigned rng_state = 1u;
void srand(unsigned seed) { rng_state = seed ? seed : 1u; }
int  rand(void) {
  // LCG: simple, small, good enough for test input
  rng_state = 1664525u * rng_state + 1013904223u;
  return (int)(rng_state >> 1);
}

extern void run(Memory_st *restrict mp, void *p_config, int *done) {

  puts("Setting regs\n");
  puts("Config   : "); puthex((uintptr_t)p_config); putchar('\n');
  puts("mem_phy.k: "); puthex((uintptr_t)mem_phy.k); putchar('\n');

  set_config(p_config, A_MM2S_0_ADDR , addr_64to32(mem_phy.k));
  set_config(p_config, A_MM2S_0_BYTES,      sizeof(mem_phy.k));
  set_config(p_config, A_MM2S_1_ADDR , addr_64to32(mem_phy.x));
  set_config(p_config, A_MM2S_1_BYTES,      sizeof(mem_phy.x));
  set_config(p_config, A_MM2S_2_ADDR , addr_64to32(mem_phy.a));
  set_config(p_config, A_MM2S_2_BYTES,      sizeof(mem_phy.a));
  set_config(p_config, A_S2MM_ADDR   , addr_64to32(mem_phy.y));
  set_config(p_config, A_S2MM_BYTES  ,      sizeof(mem_phy.y));
  set_config(p_config, A_START       , 1);  // Start

  while(!(get_config(p_config, A_S2MM_DONE))){
    // puthex(get_config(p_config, A_S2MM_DONE)); putchar('\n');
  }

  *done = 1;
}

void randomize_inputs(Memory_st *restrict mp, int seed){
  srand(seed);

  for (int k=0; k<K; k++)
    for (int c=0;c<C; c++)
      mp->k[k][c] = rand();

  for (int k=0; k<K; k++)
    for (int r=0;r<R; r++)
      mp->x[k][r] = rand();

  for (int c=0; c<C; c++)
    for (int r=0;r<R; r++)
      mp->a[c][r] = rand();

  puts("Randomized inputs\n");
}

void check_output(Memory_st *restrict mp){

  TY y_exp [C][R];

  for (int c=0; c<C; c++)
    for (int r=0; r<R; r++){
      int sum = 0;
      for (int k=0; k<K; k++)
        sum += (int)(mp->k[k][c]) * (int)(mp->x[k][r]);
      sum += mp->a[c][r];
      y_exp[c][r] = sum;
    }

  int error = 0;

  for (int c=0; c<C; c++)
    for (int r=0; r<R; r++)
      if (mp->y[c][r] != y_exp[c][r]){
        error += 1;
        puts("Output does not match\n");
      } else {
        puts("Outputs match\n");
      }
  puts("All outputs match\n");
}

void itoa_simple(int num, char *buf) {
    char tmp[12]; // enough for 32-bit int (-2147483648\0)
    int i = 0, j, neg = 0;

    if (num == 0) {
        buf[0] = '0';
        buf[1] = '\0';
        return;
    }

    if (num < 0) {
        neg = 1;
        num = -num;
    }

    while (num > 0) {
        tmp[i++] = (num % 10) + '0';
        num /= 10;
    }

    if (neg) tmp[i++] = '-';

    // reverse into buf
    for (j = 0; j < i; j++) {
        buf[j] = tmp[i - j - 1];
    }
    buf[i] = '\0';
}

char str [20];