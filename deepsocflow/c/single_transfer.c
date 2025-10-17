#include "platform.h"
#include "xaxidma.h"
#include "xparameters.h"
#include "xparameters_ps.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "xscugic.h"
#include <assert.h>
#include <limits.h>
#include <stdint.h>

#define printf xil_printf
#define assert_printf(v1, op, v2, optional_debug_info,...) ((v1  op v2) || (printf("ASSERT FAILED: \n CONDITION: "), printf("( " #v1 " " #op " " #v2 " )"), printf(", VALUES: ( %ld %s %ld ), ", (long int)v1, #op, (long int)v2), printf("DEBUG_INFO: " optional_debug_info), printf(" " __VA_ARGS__), printf("\n\n"), assert(v1 op v2), 0))

//static int glb_s2mm_done = 0;
static int done_pixels = 0, done_weights = 0, done_output = 0;

XAxiDma dma_pixels, dma_weights, dma_output;
XScuGic intr_controller; // Generic interrupt controller
u32     status;


#define X_BITS_L2   2
#define W_BITS_L2   2
#define X_PAD       6
#define KH_MAX      13
#define PE_ROWS     8
#define PE_COLS     24

#define N_ADD_BUF
#define WB_BYTES    92
#define W_BYTES     44
#define X_BYTES     176
#define O_WORDS     1536
#define O_WORDS_MAX 1536
#define O_BYTES_MAX 6144
#define X_BYTES_ALL 176
#define NHWC_WORDS  1536
#define Y_TYPE      int16_t
#define B_TYPE      int16_t
#define O_TYPE      int32_t
#define B_WORDS     24
#define DATA_DIR   "../vectors"
typedef struct {
  volatile Y_TYPE ocm       [PE_ROWS*PE_COLS];
  int8_t     w              [W_BYTES     ];
  B_TYPE     b              [B_WORDS     ]; // keep next to w. weights are loaded to w_ptr
  int8_t     x              [X_BYTES_ALL ];
  int32_t    y              [O_WORDS     ];
  int32_t    nhwc           [NHWC_WORDS  ];
  int8_t     debug_tiled    [O_WORDS_MAX ];
  int32_t    debug_nhwc     [NHWC_WORDS  ];
  int8_t     out_buffers    [2           ][O_BYTES_MAX ];
  int8_t     add_buffers    [N_ADD_BUF   ][NHWC_WORDS  ];
} Memory_st;
Memory_st *p_mem = (Memory_st*) 0x20000000; //XPAR_PSU_OCM_RAM_0_S_AXI_BASEADDR;

#define Y_WORDS (PE_ROWS*PE_COLS)
#define Y_BYTES (Y_WORDS*sizeof(Y_TYPE))

static void mm2s_pixels_handler(void* CallbackRef){
  u32 IrqStatus = XAxiDma_IntrGetIrq(&dma_pixels, XAXIDMA_DMA_TO_DEVICE); // Read pending interrupts
  XAxiDma_IntrAckIrq(&dma_pixels, IrqStatus, XAXIDMA_DMA_TO_DEVICE); // Acknowledge pending interrupts
  if (!(IrqStatus & XAXIDMA_IRQ_IOC_MASK)) return;
  xil_printf("pixels mm2s finished!\n");
  done_pixels = 1;
}

static void mm2s_weights_handler(void* CallbackRef){
  u32 IrqStatus = XAxiDma_IntrGetIrq(&dma_weights, XAXIDMA_DMA_TO_DEVICE); // Read pending interrupts
  XAxiDma_IntrAckIrq(&dma_weights, IrqStatus, XAXIDMA_DMA_TO_DEVICE); // Acknowledge pending interrupts
  if (!(IrqStatus & XAXIDMA_IRQ_IOC_MASK)) return;
  xil_printf("weights mm2s finished!\n");
  done_weights = 1;
}

static void s2mm_output_handler(void* CallbackRef){
//  while(done_output);
  u32 IrqStatus = XAxiDma_IntrGetIrq(&dma_output, XAXIDMA_DEVICE_TO_DMA); // Read pending interrupts
  XAxiDma_IntrAckIrq(&dma_output, IrqStatus, XAXIDMA_DEVICE_TO_DMA); // Acknowledge pending interrupts
  if (!(IrqStatus & XAXIDMA_IRQ_IOC_MASK)) return;
  xil_printf("output s2mm finished!\n");

  for (int i=0; i<Y_WORDS; i++)
	  xil_printf("BRAM, i:%d, value: %d\n", i, p_mem->ocm[i]);
  done_output = 1;
}

static void setup_interrupt(XScuGic *p_intr_controller, u32 intr_id, Xil_InterruptHandler handler_fn, u8 priority){
  XScuGic_SetPriorityTriggerType(p_intr_controller, intr_id, priority, 0x3);            // set priority level, triggered by rising edge
  status = XScuGic_Connect(p_intr_controller, intr_id, handler_fn, 0); assert_printf (status, ==, XST_SUCCESS, "ERROR! Failed to connect to the interrupt controller.\r\n",);
  XScuGic_Enable(p_intr_controller, intr_id); // enable interrupt
}


int main() {
  init_platform();
  xil_printf("Store w: %p, x: %p, y:%p\n", &p_mem->w, &p_mem->x, &p_mem->ocm);
  print("Starting!!!\n\r");

  // Initialize Interrupt Controller
  XScuGic_Config *IntcConfig =  XScuGic_LookupConfig(XPAR_SCUGIC_SINGLE_DEVICE_ID);
  status = XScuGic_CfgInitialize(&intr_controller, IntcConfig, IntcConfig->CpuBaseAddress); assert_printf (status, ==, XST_SUCCESS, "Interrupt initialization failed",);
  Xil_ExceptionInit(); // Initialize exception table
  Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT, (Xil_ExceptionHandler)XScuGic_InterruptHandler, (void *)&intr_controller);  //register the interrupt controller handler with exception table
  Xil_ExceptionEnable(); // Enable non-critical exceptions


  // Initialize DMA - Pixels
  status = XAxiDma_CfgInitialize(&dma_pixels, XAxiDma_LookupConfigBaseAddr(XPAR_DMA_PIXELS_BASEADDR));  assert_printf (status, ==, XST_SUCCESS, "Pixels DMA initialization failed",);
  // MM2S
  setup_interrupt(&intr_controller, XPAR_FABRIC_DMA_PIXELS_MM2S_INTROUT_INTR, (Xil_InterruptHandler)mm2s_pixels_handler, 0xA8);
  XAxiDma_IntrDisable(&dma_pixels, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DMA_TO_DEVICE);
  XAxiDma_IntrEnable (&dma_pixels, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DMA_TO_DEVICE);

  // Initialize DMA - Weights
  status = XAxiDma_CfgInitialize(&dma_weights, XAxiDma_LookupConfigBaseAddr(XPAR_DMA_WEIGHTS_BASEADDR)); assert_printf (status, ==, XST_SUCCESS, "Weights DMA initialization failed",);
  // MM2S
  setup_interrupt(&intr_controller, XPAR_FABRIC_DMA_WEIGHTS_MM2S_INTROUT_INTR, (Xil_InterruptHandler)mm2s_weights_handler, 0xAB);
  XAxiDma_IntrDisable(&dma_weights, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DMA_TO_DEVICE);
  XAxiDma_IntrEnable (&dma_weights, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DMA_TO_DEVICE);

  // Initialize DMA - Output
  status = XAxiDma_CfgInitialize(&dma_output, XAxiDma_LookupConfigBaseAddr(XPAR_DMA_OUTPUT_BASEADDR));  assert_printf (status, ==, XST_SUCCESS, "Output DMA initialization failed",);
  // S2MM
  setup_interrupt(&intr_controller, XPAR_FABRIC_DMA_OUTPUT_S2MM_INTROUT_INTR, (Xil_InterruptHandler)s2mm_output_handler, 0xA0);
  XAxiDma_IntrDisable(&dma_output, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);
  XAxiDma_IntrEnable (&dma_output, XAXIDMA_IRQ_IOC_MASK, XAXIDMA_DEVICE_TO_DMA);



  // ------------ DATA TRANSFER ---------------

//  for (int t=0; t<1; t++){

    // 1. Prepare input data
    Xil_DCacheFlushRange((INTPTR)&p_mem->w, W_BYTES);  // force transfer to DDR, starting addr & length
    Xil_DCacheFlushRange((INTPTR)&p_mem->x, X_BYTES);

    // 2. Start transfers
    print("Starting DMA transfers\n\r");
    status = XAxiDma_SimpleTransfer(&dma_weights, (INTPTR)&p_mem->w  , W_BYTES, XAXIDMA_DMA_TO_DEVICE); assert_printf (status, ==, XST_SUCCESS, "Weights DMA transfer failed \r\n",);
    while(!done_weights);
    done_weights = 0;
    xil_printf("Weights done: %d/100 \n", 0);

    status = XAxiDma_SimpleTransfer(&dma_output , (INTPTR)&p_mem->ocm, Y_BYTES, XAXIDMA_DEVICE_TO_DMA); assert_printf (status, ==, XST_SUCCESS, "Output  DMA transfer failed \r\n",);
    status = XAxiDma_SimpleTransfer(&dma_pixels , (INTPTR)&p_mem->x  , X_BYTES, XAXIDMA_DMA_TO_DEVICE); assert_printf (status, ==, XST_SUCCESS, "Pixels  DMA transfer failed \r\n",);

    // 3. Wait for interrupt callbacks to set global variables
    print("Waiting to complete transfers\n\r");
    while (!done_pixels | !done_output);
    done_pixels  = 0;
    done_weights = 0;
    done_output  = 0;

    xil_printf("Done transfer: %d/100 \n", 0);
//  }

  XScuGic_Disconnect(&intr_controller, XPAR_FABRIC_DMA_PIXELS_MM2S_INTROUT_INTR );
  XScuGic_Disconnect(&intr_controller, XPAR_FABRIC_DMA_WEIGHTS_MM2S_INTROUT_INTR);
  XScuGic_Disconnect(&intr_controller, XPAR_FABRIC_DMA_OUTPUT_S2MM_INTROUT_INTR );

  cleanup_platform();
  return 0;
}

