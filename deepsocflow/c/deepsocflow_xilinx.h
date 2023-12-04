#include "platform.h"
#include "xaxidma.h"
#include "xparameters.h"
#include "xparameters_ps.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "xscugic.h"
#include "xtime_l.h"
#include <assert.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>

#define MEM_BASEADDR 0x20000000

#ifdef NDEBUG
  #define debug_xil_printf(...)
#else
  #define debug_xil_printf xil_printf
#endif

static volatile uint8_t bundle_read_done = 0, done_pixels = 0, done_weights = 0, done_output = 0, done_all = 0;
static UINTPTR w_base, x_base, y_base;
static int32_t w_bpt, x_bpt, y_bpt;
static XAxiDma dma_pixels, dma_weights, dma_output;
static XScuGic intr_controller; // Generic interrupt controller
static u32     status;


// RUNTIME.H included here

static void start_pixels_dma();
static void start_wait_output(UINTPTR, u32);

#define printf xil_printf
#include "runtime.h"
#undef printf


// OUTPUT DMA: Used in runtime.h

static void start_wait_output(UINTPTR baseaddr, u32 bpt){
	int status = XAxiDma_SimpleTransfer(&dma_output , baseaddr, bpt, XAXIDMA_DEVICE_TO_DMA);
	if (status != XST_SUCCESS) xil_printf("S2MM transfer failed, base:%p, bpt:%d\n", baseaddr, bpt);
	while(!done_output);
	debug_xil_printf("Done output dma at :%p, bpt:%d\n", baseaddr, bpt);
	Xil_DCacheFlushRange((INTPTR)baseaddr, bpt);
	done_output = 0;
}

static void s2mm_output_handler(void* CallbackRef){
  u32 IrqStatus = XAxiDma_IntrGetIrq(&dma_output, XAXIDMA_DEVICE_TO_DMA); // Read pending interrupts
  XAxiDma_IntrAckIrq(&dma_output, IrqStatus, XAXIDMA_DEVICE_TO_DMA); // Acknowledge pending interrupts
  if (!(IrqStatus & XAXIDMA_IRQ_IOC_MASK)) return;
  debug_xil_printf("output s2mm finished!\n");
  done_output = 1;
}



// PIXELS DMA: restart automatically

static void start_pixels_dma() {
  load_x (&done_pixels, &bundle_read_done, &x_base, &x_bpt);
  Xil_DCacheFlushRange((INTPTR)x_base, x_bpt);
  status = XAxiDma_SimpleTransfer(&dma_pixels , x_base  , x_bpt, XAXIDMA_DMA_TO_DEVICE); assert_printf (status, ==, XST_SUCCESS, "Pixels  DMA transfer failed ", "base:%p, bpt:%d\n", x_base, x_bpt);
}

static void mm2s_pixels_handler(void* CallbackRef){
  u32 IrqStatus = XAxiDma_IntrGetIrq(&dma_pixels, XAXIDMA_DMA_TO_DEVICE); // Read pending interrupts
  XAxiDma_IntrAckIrq(&dma_pixels, IrqStatus, XAXIDMA_DMA_TO_DEVICE); // Acknowledge pending interrupts
  if (!(IrqStatus & XAXIDMA_IRQ_IOC_MASK)) return;
  debug_xil_printf("Done pixels dma at base:%p, bpt:%d\n", x_base, x_bpt);
  if (!bundle_read_done) start_pixels_dma();
}



// WEIGHTS DMA: restart automatically

static void start_weights_dma() {
  load_w (&done_weights, &w_base, &w_bpt);
  status = XAxiDma_SimpleTransfer(&dma_weights, w_base, w_bpt, XAXIDMA_DMA_TO_DEVICE); assert_printf (status, ==, XST_SUCCESS, "Weights DMA transfer failed", "base:%p, bpt:%d\n", w_base, w_bpt);
}

static void mm2s_weights_handler(void* CallbackRef){
  u32 IrqStatus = XAxiDma_IntrGetIrq(&dma_weights, XAXIDMA_DMA_TO_DEVICE); // Read pending interrupts
  XAxiDma_IntrAckIrq(&dma_weights, IrqStatus, XAXIDMA_DMA_TO_DEVICE); // Acknowledge pending interrupts
  if (!(IrqStatus & XAXIDMA_IRQ_IOC_MASK)) return;
  debug_xil_printf("Done weights dma at base:%p, bpt:%d\n", w_base, w_bpt);
  start_weights_dma();
}


// HARDWARE & MODEL SETUP

static void setup_interrupt(XScuGic *p_intr_controller, u32 intr_id, Xil_InterruptHandler handler_fn, u8 priority){
  XScuGic_SetPriorityTriggerType(p_intr_controller, intr_id, priority, 0x3);            // set priority level, triggered by rising edge
  status = XScuGic_Connect(p_intr_controller, intr_id, handler_fn, 0); assert_printf (status, ==, XST_SUCCESS, "ERROR! Failed to connect to the interrupt controller.\r\n",);
  XScuGic_Enable(p_intr_controller, intr_id); // enable interrupt
}

static inline void hardware_setup(){

  init_platform();

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

}

static inline void hardware_cleanup(){
  // ------------ CLEANUP ---------------
  XScuGic_Disconnect(&intr_controller, XPAR_FABRIC_DMA_PIXELS_MM2S_INTROUT_INTR );
  XScuGic_Disconnect(&intr_controller, XPAR_FABRIC_DMA_WEIGHTS_MM2S_INTROUT_INTR);
  XScuGic_Disconnect(&intr_controller, XPAR_FABRIC_DMA_OUTPUT_S2MM_INTROUT_INTR );
  cleanup_platform();
}

static inline void model_setup(){
  Xil_DCacheFlushRange((INTPTR)&mem.w, WB_BYTES+X_BYTES);  // force transfer to DDR, starting addr & length
  start_weights_dma();
}

static inline void model_run(){
  start_pixels_dma();
  load_y (&done_all, &y_base, &y_bpt);
}
