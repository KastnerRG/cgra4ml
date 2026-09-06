// inference.c - CGRA4ML Linux inference entry point
//
// Loads wbx.bin (weights + input), runs inference on the CGRA accelerator,
// and prints the output class probabilities.

#include <stdio.h>

// --- libinference.so API ---

void *host_setup(const char *dev, const char *wbx_path);
void  host_cleanup(void *mp);
void  run(void *mp);
void  print_output(void *mp);

// --- main ---

int main(int argc, char **argv)
{
    const char *wbx_path = argc > 1 ? argv[1] : "wbx.bin";

    void *mp = host_setup("/dev/cgra4ml", wbx_path);
    if (!mp) return 1;

    printf("CGRA4ML Linux inference\n");
    printf("  running inference...\n");
    run(mp);
    printf("\n--- output ---\n");
    print_output(mp);

    host_cleanup(mp);
    return 0;
}
