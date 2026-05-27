#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>

#include "cgra4ml_ioctl.h"

#define DEV_PATH "/dev/cgra4ml"

#define MMAP_WEIGHTS 0
#define MMAP_INPUT   1
#define MMAP_OUTPUT  2
#define MMAP_OCM0    3
#define MMAP_OCM1    4

static void *map_buf(int fd, int index, size_t size)
{
    long page = sysconf(_SC_PAGESIZE);
    off_t off = (off_t)index * page;

    void *ptr = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, off);
    if (ptr == MAP_FAILED) {
        perror("mmap");
        return NULL;
    }

    return ptr;
}

int main(void)
{
    int fd;
    struct cgra4ml_buf_info info;
    uint8_t *weights;
    uint8_t *input;
    uint8_t *output;

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

    weights = map_buf(fd, MMAP_WEIGHTS, info.weights_size);
    input   = map_buf(fd, MMAP_INPUT,   info.input_size);
    output  = map_buf(fd, MMAP_OUTPUT,  info.output_size);

    if (!weights || !input || !output) {
        close(fd);
        return 1;
    }

    printf("Writing test patterns into coherent buffers\n");

    for (size_t i = 0; i < 256; i++) {
        weights[i] = (uint8_t)(0xA0 + (i & 0x0F));
        input[i]   = (uint8_t)(0x10 + (i & 0x0F));
        output[i]  = 0;
    }

    printf("weights[0..15]: ");
    for (int i = 0; i < 16; i++)
        printf("%02x ", weights[i]);
    printf("\n");

    printf("input[0..15]:   ");
    for (int i = 0; i < 16; i++)
        printf("%02x ", input[i]);
    printf("\n");

    munmap(weights, info.weights_size);
    munmap(input, info.input_size);
    munmap(output, info.output_size);

    close(fd);
    return 0;
}
