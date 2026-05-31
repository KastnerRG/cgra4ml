#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#include "deepsocflow_linux.h"

#define DEV_PATH     "/dev/cgra4ml"
#define MMAP_WEIGHTS 0

/* ---- global state (declared extern in deepsocflow_linux.h) ---- */
int        linux_fd;
Memory_st *linux_mp;
u32        linux_weights_phys;

/* ---- load wbx.bin (weights + bias + input) ---- */

static int load_wbx(const char *path, Memory_st *mp)
{
    FILE *fp = fopen(path, "rb");
    if (!fp) {
        perror("fopen");
        return -1;
    }

    size_t total = WB_BYTES + X_BYTES;
    size_t n    = fread(mp->w, 1, total, fp);
    fclose(fp);

    if (n != total) {
        fprintf(stderr, "wbx: read %zu of %zu bytes\n", n, total);
        return -1;
    }
    return 0;
}

/* ---- main ---- */

int main(int argc, char **argv)
{
    const char *wbx_path = argc > 1 ? argv[1] : "wbx.bin";
    struct cgra4ml_buf_info info;
    long page_size;
    void *weights_map;
    int ret = 1;

    linux_fd = open(DEV_PATH, O_RDWR);
    if (linux_fd < 0) {
        perror("open " DEV_PATH);
        return 1;
    }

    if (ioctl(linux_fd, CGRA4ML_IOC_GET_BUFS, &info) < 0) {
        perror("CGRA4ML_IOC_GET_BUFS");
        goto out_close;
    }

    page_size   = sysconf(_SC_PAGESIZE);
    weights_map = mmap(NULL, info.weights_size,
                       PROT_READ | PROT_WRITE, MAP_SHARED,
                       linux_fd, (off_t)MMAP_WEIGHTS * page_size);
    if (weights_map == MAP_FAILED) {
        perror("mmap weights");
        goto out_close;
    }

    linux_mp            = (Memory_st *)weights_map;
    linux_weights_phys  = (u32)info.weights_phys;

    printf("CGRA4ML Linux inference\n");
    printf("  Memory_st      : %p  (virtual)\n", (void *)linux_mp);
    printf("  weights phys   : 0x%x\n", linux_weights_phys);
    printf("  weights size   : %u\n", info.weights_size);
    printf("  sizeof(Memory_st): %zu\n", sizeof(Memory_st));
    printf("  loading wbx    : %s\n", wbx_path);

    if (load_wbx(wbx_path, linux_mp) < 0)
        goto out_unmap;

    printf("  running inference...\n");
    run(linux_mp);

    printf("\n--- output ---\n");
    print_output(linux_mp);

    ret = 0;

out_unmap:
    munmap(weights_map, info.weights_size);
out_close:
    close(linux_fd);
    return ret;
}
