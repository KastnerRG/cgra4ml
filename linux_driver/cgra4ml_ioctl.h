#ifndef CGRA4ML_IOCTL_H
#define CGRA4ML_IOCTL_H

#include <linux/types.h>

#define CGRA4ML_IOCTL_MAGIC 'G'

struct cgra4ml_reg_access {
    __u32 offset;
    __u32 value;
};

struct cgra4ml_buf_info {
    __u64 weights_phys;
    __u64 input_phys;
    __u64 output_phys;
    __u64 ocm0_phys;
    __u64 ocm1_phys;

    __u32 weights_size;
    __u32 input_size;
    __u32 output_size;
    __u32 ocm_size;
    __u32 reg_size;
};

struct cgra4ml_start_config {
    __u32 n_bundles;
    __u32 reserved;
};

#define CGRA4ML_IOC_READ_REG     _IOWR(CGRA4ML_IOCTL_MAGIC, 0x01, struct cgra4ml_reg_access)
#define CGRA4ML_IOC_WRITE_REG    _IOW (CGRA4ML_IOCTL_MAGIC, 0x02, struct cgra4ml_reg_access)
#define CGRA4ML_IOC_GET_BUFS     _IOR (CGRA4ML_IOCTL_MAGIC, 0x03, struct cgra4ml_buf_info)
#define CGRA4ML_IOC_HW_RESET     _IO  (CGRA4ML_IOCTL_MAGIC, 0x04)
#define CGRA4ML_IOC_HW_START     _IOW (CGRA4ML_IOCTL_MAGIC, 0x05, struct cgra4ml_start_config)
#define CGRA4ML_IOC_WAIT_DONE    _IOR (CGRA4ML_IOCTL_MAGIC, 0x06, __u32)
#define CGRA4ML_IOC_DUMP_STATUS  _IOR (CGRA4ML_IOCTL_MAGIC, 0x07, __u32)

#endif
