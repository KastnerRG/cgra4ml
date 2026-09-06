#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include "cgra4ml_ioctl.h"

#define DEV_PATH "/dev/cgra4ml"

int main(void)
{
    int fd;
    struct cgra4ml_buf_info info;
    uint32_t status;

    fd = open(DEV_PATH, O_RDWR);
    if (fd < 0) {
        perror("open /dev/cgra4ml");
        return 1;
    }

    if (ioctl(fd, CGRA4ML_IOC_GET_BUFS, &info) < 0) {
        perror("CGRA4ML_IOC_GET_BUFS");
        close(fd);
        return 1;
    }

    printf("CGRA4ML buffer info:\n");
    printf("  weights phys: 0x%llx size: %u\n",
           (unsigned long long)info.weights_phys, info.weights_size);
    printf("  input   phys: 0x%llx size: %u\n",
           (unsigned long long)info.input_phys, info.input_size);
    printf("  output  phys: 0x%llx size: %u\n",
           (unsigned long long)info.output_phys, info.output_size);
    printf("  ocm0    phys: 0x%llx size: %u\n",
           (unsigned long long)info.ocm0_phys, info.ocm_size);
    printf("  ocm1    phys: 0x%llx size: %u\n",
           (unsigned long long)info.ocm1_phys, info.ocm_size);
    printf("  reg size: %u\n", info.reg_size);

    if (ioctl(fd, CGRA4ML_IOC_DUMP_STATUS, &status) < 0) {
        perror("CGRA4ML_IOC_DUMP_STATUS");
        close(fd);
        return 1;
    }

    printf("status packed: 0x%08x\n", status);
    printf("  W_DONE = %u\n", status & 0xff);
    printf("  X_DONE = %u\n", (status >> 8) & 0xff);
    printf("  O_DONE = %u\n", (status >> 16) & 0xff);

    close(fd);
    return 0;
}
