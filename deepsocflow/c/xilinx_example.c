//#define XDEBUG
#include "platform.h"
#include "deepsocflow_xilinx.h"

int main()
{
    hardware_setup();

    // For baremetal, give physical address
    Memory_st *p_mem = (Memory_st *)MEM_BASEADDR;
    void *p_config = (void *)CONFIG_BASEADDR;
    // For linux, give virtual address
    // Memory_st *p_mem = (Memory_st *)mmap(NULL, sizeof(Memory_st), PROT_READ | PROT_WRITE, MAP_SHARED, dh, MEM_BASEADDR);
    // void *p_config = mmap(NULL, 4*16+N_BUNDLES*32, PROT_READ | PROT_WRITE, MAP_SHARED, dh, CONFIG_BASEADDR);

    xil_printf("Welcome to DeepSoCFlow!\n Store wbx at: %p; y:%p; buffers {0:%p,1:%p};\n", &p_mem->w, &p_mem->y, &p_mem->out_buffers[0], &p_mem->out_buffers[1]);

    model_setup(p_mem, p_config);
    model_run_timed(p_mem, p_config, 20);    // run model and measure time
    print_output(p_mem);

    hardware_cleanup();
    return 0;
}
