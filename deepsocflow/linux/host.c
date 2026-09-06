// host.c - CGRA4ML Linux host-side platform initialization
//
// Provides host_setup() and host_cleanup() functions that:
// - Open /dev/cgra4ml device
// - Query buffer physical addresses via GET_BUFS ioctl
// - mmap DMA-coherent buffer into userspace
// - Load wbx.bin (weights + bias + input) into the buffer
//
// These functions are exported from libinference.so and called by both
// inference.c (C) and runner.py (Python via ctypes).

#define DEEPSOCFLOW_LINUX_OVERRIDE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#include "deepsocflow_linux.h"

// --- Global state (declared extern in deepsocflow_linux.h) ---

int        linux_fd;
Memory_st *linux_mp;
u32        linux_weights_phys;
static size_t linux_map_size;

// --- Forward declarations ---

void host_cleanup(void *mp);

// --- host_setup ---

void *host_setup(const char *dev, const char *wbx_path)
{
    struct cgra4ml_buf_info info;
    void *map;
    FILE *fp;
    size_t n;
    size_t total = WB_BYTES + X_BYTES;

    linux_fd = open(dev, O_RDWR);
    if (linux_fd < 0) { perror("open"); return NULL; }

    if (ioctl(linux_fd, CGRA4ML_IOC_GET_BUFS, &info) < 0) {
        perror("GET_BUFS"); close(linux_fd); return NULL;
    }

    map = mmap(NULL, info.weights_size,
               PROT_READ | PROT_WRITE, MAP_SHARED, linux_fd, 0);
    if (map == MAP_FAILED) {
        perror("mmap"); close(linux_fd); return NULL;
    }

    linux_mp           = (Memory_st *)map;
    linux_weights_phys = (u32)info.weights_phys;
    linux_map_size     = info.weights_size;

    fp = fopen(wbx_path, "rb");
    if (!fp) { perror("fopen"); host_cleanup(map); return NULL; }
    n = fread(linux_mp->w, 1, total, fp);
    fclose(fp);
    if (n != total) {
        fprintf(stderr, "wbx: read %zu of %zu bytes\n", n, total);
        host_cleanup(map); return NULL;
    }

    return map;
}

// --- host_cleanup ---

void host_cleanup(void *mp)
{
    if (mp) munmap(mp, linux_map_size);
    if (linux_fd >= 0) close(linux_fd);
    linux_fd = -1;
    linux_mp = NULL;
    linux_weights_phys = 0;
}
