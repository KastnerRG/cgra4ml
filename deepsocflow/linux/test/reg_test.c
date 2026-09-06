#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include "cgra4ml_ioctl.h"
#include "cgra4ml_regs.h"

#define DEV_PATH "/dev/cgra4ml"

static int read_reg(int fd, uint32_t offset, uint32_t *value)
{
    struct cgra4ml_reg_access reg = {
        .offset = offset,
        .value = 0,
    };

    if (ioctl(fd, CGRA4ML_IOC_READ_REG, &reg) < 0) {
        perror("CGRA4ML_IOC_READ_REG");
        return -1;
    }

    *value = reg.value;
    return 0;
}

static int write_reg(int fd, uint32_t offset, uint32_t value)
{
    struct cgra4ml_reg_access reg = {
        .offset = offset,
        .value = value,
    };

    if (ioctl(fd, CGRA4ML_IOC_WRITE_REG, &reg) < 0) {
        perror("CGRA4ML_IOC_WRITE_REG");
        return -1;
    }

    return 0;
}

int main(void)
{
    int fd;
    uint32_t value;

    fd = open(DEV_PATH, O_RDWR);
    if (fd < 0) {
        perror("open /dev/cgra4ml");
        return 1;
    }

    printf("CGRA4ML register smoke test\n");

    if (ioctl(fd, CGRA4ML_IOC_HW_RESET) < 0) {
        perror("CGRA4ML_IOC_HW_RESET");
        close(fd);
        return 1;
    }

    if (read_reg(fd, CGRA4ML_REG_START, &value) == 0)
        printf("START       = 0x%08x\n", value);

    if (read_reg(fd, CGRA4ML_REG_DONE_READ0, &value) == 0)
        printf("DONE_READ0  = 0x%08x\n", value);

    if (read_reg(fd, CGRA4ML_REG_DONE_READ1, &value) == 0)
        printf("DONE_READ1  = 0x%08x\n", value);

    if (read_reg(fd, CGRA4ML_REG_W_DONE, &value) == 0)
        printf("W_DONE      = 0x%08x\n", value);

    if (read_reg(fd, CGRA4ML_REG_X_DONE, &value) == 0)
        printf("X_DONE      = 0x%08x\n", value);

    if (read_reg(fd, CGRA4ML_REG_O_DONE, &value) == 0)
        printf("O_DONE      = 0x%08x\n", value);

    printf("Writing N_BUNDLES register with test value 1\n");
    if (write_reg(fd, CGRA4ML_REG_N_BUNDLES, 1) == 0 &&
        read_reg(fd, CGRA4ML_REG_N_BUNDLES, &value) == 0)
        printf("N_BUNDLES   = 0x%08x\n", value);

    close(fd);
    return 0;
}
