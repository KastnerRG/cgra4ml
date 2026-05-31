#ifndef DEEPSOCFLOW_LINUX_H
#define DEEPSOCFLOW_LINUX_H

/*
 * Linux userspace adapter for deepsocflow runtime.h
 *
 * Strategy: override fb_* macros to use IOCTL-based register access
 * and DMA-coherent buffer address translation.  Place the entire
 * Memory_st struct inside the driver's weights DMA buffer so that
 * hardware and CPU share the same physical memory.
 *
 * Usage:
 *   #include "deepsocflow_linux.h"   // instead of deepsocflow_xilinx.h
 *
 *   int linux_fd;                     // must be defined in your .c file
 *   Memory_st *linux_mp;
 *   uint32_t linux_weights_phys;
 *
 *   // open /dev/cgra4ml, mmap weights buffer into linux_mp,
 *   // set linux_weights_phys from GET_BUFS, then call:
 *   run(linux_mp);
 *   print_output(linux_mp);
 */

#define DEEPSOCFLOW_LINUX_OVERRIDE

/* ---- forward declarations (needed before runtime.h is processed) ---- */
#include <stdint.h>
#include <sys/ioctl.h>

static inline uint32_t linux_fb_read_reg32(void *addr);
static inline void     linux_fb_write_reg32(void *addr, uint32_t data);
static inline uint32_t linux_fb_addr_64to32(void *addr);

/* ---- override fb_fw_wrap.h / runtime.h ---- */
#define fb_read_reg32(addr)       linux_fb_read_reg32(addr)
#define fb_write_reg32(addr,val)  linux_fb_write_reg32(addr,val)
#define fb_addr_64to32(addr)      linux_fb_addr_64to32(addr)
#define flush_cache(addr,bytes)   ((void)0)

/*
 * mem_phy is only used inside model_setup() where the Memory_st
 * parameter is named 'mp'.  Defining it as (*mp) makes
 * mem_phy.field expand to mp->field, i.e. the correct local
 * parameter pointer in every runtime function.
 */
#define mem_phy (*mp)

#include "runtime.h"

/* ---- globals (defined in the .c file) ---- */
#include "cgra4ml_ioctl.h"

extern int        linux_fd;
extern Memory_st *linux_mp;
extern uint32_t   linux_weights_phys;

/* ---- IOCTL-based register access ---- */

static inline uint32_t linux_fb_read_reg32(void *addr)
{
    struct cgra4ml_reg_access reg = {
        .offset = (uintptr_t)addr - CONFIG_BASEADDR,
        .value  = 0,
    };
    ioctl(linux_fd, CGRA4ML_IOC_READ_REG, &reg);
    return reg.value;
}

static inline void linux_fb_write_reg32(void *addr, uint32_t data)
{
    struct cgra4ml_reg_access reg = {
        .offset = (uintptr_t)addr - CONFIG_BASEADDR,
        .value  = data,
    };
    ioctl(linux_fd, CGRA4ML_IOC_WRITE_REG, &reg);
}

/* Translate a virtual pointer inside linux_mp to a physical DMA address. */
static inline uint32_t linux_fb_addr_64to32(void *addr)
{
    return linux_weights_phys + (uint32_t)((uint8_t *)addr - (uint8_t *)linux_mp);
}

#endif /* DEEPSOCFLOW_LINUX_H */
