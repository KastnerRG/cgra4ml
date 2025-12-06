#ifndef RISCV
  #include <assert.h>
  #include <stdlib.h>
#endif
#include <limits.h>
#include <stdint.h>

typedef int8_t   i8 ;
typedef int16_t  i16;
typedef int32_t  i32;
typedef int64_t  i64;
typedef uint8_t  u8 ;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef float    f32;
typedef double   f64;

#ifdef __cplusplus
  #define EXT_C "C"
  #define restrict __restrict__ 
#else
  #define EXT_C
#endif

#ifdef SIM
  #define XDEBUG
  #include <stdio.h>
  #define sim_fprintf fprintf
  #include <stdbool.h>
  #define STRINGIFY(x) #x
  #define TO_STRING(x) STRINGIFY(x)

  Memory_st mem_phy;
  extern EXT_C void fb_task_write_reg32(u64, u32);
	extern EXT_C void fb_task_read_reg32(u64);
	extern EXT_C u32  fb_fn_read_reg32();

	u32 fb_read_reg32(void* addr){
    fb_task_read_reg32((u64)addr);
    u32 data = fb_fn_read_reg32();
    return data;
  }
  void fb_write_reg32(void* addr, u32 data) {
    fb_task_write_reg32((u64)addr, data);
  }
  static inline void flush_cache(void *addr, uint32_t bytes) {} // Do nothing

#else
  #define sim_fprintf(...)

  #ifdef RISCV
    Memory_st mem_phy;
  #else
    #define mem_phy (*(Memory_st* restrict)MEM_BASEADDR)
  #endif

  volatile u32 fb_read_reg32(void *addr){
    return *(volatile u32 *)addr;
  }

  void fb_write_reg32(void *addr, u32 data){	
    *(volatile u32 *restrict)addr = data;
  }
#endif

#ifdef XDEBUG
  #define debug_printf printf
  #define assert_printf(v1, op, v2, optional_debug_info,...) ((v1  op v2) || (debug_printf("ASSERT FAILED: \n CONDITION: "), debug_printf("( " #v1 " " #op " " #v2 " )"), debug_printf(", VALUES: ( %d %s %d ), ", v1, #op, v2), debug_printf("DEBUG_INFO: " optional_debug_info), debug_printf(" " __VA_ARGS__), debug_printf("\n\n"), assert(v1 op v2), 0))
#else
  #define assert_printf(...)
  #define debug_printf(...)
#endif

// Rest of the helper functions used in simulation.
#ifdef SIM

extern EXT_C u32 fb_addr_64to32(void* restrict addr){
  u64 offset = (u64)addr - (u64)&mem_phy;
  return (u32)offset + MEM_BASEADDR;
}

extern EXT_C u64 fb_sim_addr_32to64(u32 addr){
  return (u64)addr - (u64)MEM_BASEADDR + (u64)&mem_phy;
}

extern EXT_C u8 fb_c_read_ddr8_addr32 (u32 addr_32){
  u64 addr = fb_sim_addr_32to64(addr_32);
  u8 val = *(u8*restrict)addr;
  return val;
}

extern EXT_C void fb_c_write_ddr8_addr32 (u32 addr_32, u8 data){
  u64 addr = fb_sim_addr_32to64(addr_32);
  *(u8*restrict)addr = data;
}

extern EXT_C void *fb_get_mp(){
  return &mem_phy;
}
#else

u32 fb_addr_64to32 (void* addr){
  return (u32)((uintptr_t)addr);
}
#endif
