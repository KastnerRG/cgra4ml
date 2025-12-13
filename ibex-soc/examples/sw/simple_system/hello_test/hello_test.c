// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "simple_system_common.h"
#include <stdarg.h>
#include <stdint.h>

#define XDEBUG

#define MEM_BASEADDR 0x00104000
#include "firmware_helpers.h"
#include "runtime.h"

Memory_st *p_mem = (Memory_st *)MEM_BASEADDR;

int main(int argc, char **argv) {
  pcount_enable(0);
  pcount_reset();
  pcount_enable(1);

  puts("\n\nHello from Ibex!\n\n"); 
  printf("Welcome to CGRA4ML!\n Store wbx at: %p; y:%p; buffers {0:%p,1:%p};\n", &p_mem->w, &p_mem->y, &p_mem->out_buffers[0], &p_mem->out_buffers[1]);

  int8_t *w = (int8_t *)MEM_BASEADDR;
  printf("sizeof(w[0]): %d bytes\n", sizeof(w[0]));
  for (int ii=0; ii < 10; ii++) printf("w[%d]: %d \n", ii, w[ii]);

  run((void*)p_mem);
  print_output(p_mem);

  pcount_enable(0);
  return 0;
}
