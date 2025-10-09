// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "simple_system_common.h"
#include <stdarg.h>
#include <stdint.h>

#define debug_printf printf
#define MEM_BASEADDR 0x00104000
#include "firmware_helpers.h"
#include "runtime.h"

volatile uint32_t * const p_config = (volatile uint32_t *)CONFIG_BASEADDR;
Memory_st *p_mem = &mem_phy;

int main(int argc, char **argv) {
  pcount_enable(0);
  pcount_reset();
  pcount_enable(1);

  puts("\n\nHello from Ibex!\n\n"); 
  printf("Welcome to CGRA4ML!\n Store wbx at: %p; y:%p; buffers {0:%p,1:%p};\n", &p_mem->w, &p_mem->y, &p_mem->out_buffers[0], &p_mem->out_buffers[1]);

  // Test read/write to config regs
  volatile uint32_t * const p_addr = &p_config[A_WEIGHTS_BASE];
  puts("Addr:"); puthex((uintptr_t)p_addr); putchar('\n');
  *p_addr = 123u;
  puthex(0xDEADBEEF); putchar('\n');
  uint32_t val = *p_addr;
  puts("Val:"); puthex(val); putchar('\n');

  volatile uint32_t *p = (volatile uint32_t *)MEM_BASEADDR;
  for (int i = 0; i < 32; ++i) {
    puthex((uint32_t)(p + i));
    putchar(':'); putchar(' ');
    puthex(p[i]);
    putchar('\n');
  }

  // Run the test
  // model_setup((void*)p_mem, (void*)p_config);
  // model_run((void*)p_mem, (void*)p_config);    // run model and measure time
  // print_output(p_mem);

  pcount_enable(0);
  return 0;
}
