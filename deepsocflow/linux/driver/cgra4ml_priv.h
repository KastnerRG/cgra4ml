#ifndef CGRA4ML_PRIV_H
#define CGRA4ML_PRIV_H

#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/dma-mapping.h>
#include <linux/io.h>
#include <linux/miscdevice.h>
#include <linux/mutex.h>
#include <linux/platform_device.h>
#include <linux/wait.h>

#include "cgra4ml_regs.h"
#include "cgra4ml_ioctl.h"

#define CGRA4ML_DRV_NAME "cgra4ml"
#define CGRA4ML_DEV_NAME "cgra4ml"

#define CGRA4ML_MMAP_WEIGHTS 0
#define CGRA4ML_MMAP_INPUT   1
#define CGRA4ML_MMAP_OUTPUT  2
#define CGRA4ML_MMAP_OCM0    3
#define CGRA4ML_MMAP_OCM1    4

struct cgra4ml_dma_buf {
    void       *cpu_addr;
    dma_addr_t dma_addr;
    size_t      size;
    const char *name;
};

struct cgra4ml_dev {
    struct device       *dev;
    void __iomem        *regs;
    resource_size_t      regs_phys;
    resource_size_t      regs_size;

    struct miscdevice    miscdev;
    struct mutex         lock;
    wait_queue_head_t    waitq;

    struct cgra4ml_dma_buf weights;
    struct cgra4ml_dma_buf input;
    struct cgra4ml_dma_buf output;
    struct cgra4ml_dma_buf ocm0;
    struct cgra4ml_dma_buf ocm1;
};

#endif
