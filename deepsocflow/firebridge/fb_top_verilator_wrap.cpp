#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>

// TB_MODULE and FB_MODULE are defined from outside via -D option

#define STR1(x) #x
#define STR(x)  STR1(x)
#define CAT(a,b)  a##b
#define XCAT(a,b) CAT(a,b)

// Build V<tb>.h
#define VTB(tb) XCAT(V, tb)
#define VTB_H(tb) STR(VTB(tb).h)
#include VTB_H(TB_MODULE)

// Build V<tb>_<tb>.h
#define VTB_TB(tb) V##tb##_##tb
#define VTB_TB_H(tb) STR(VTB_TB(tb).h)
#include VTB_TB_H(TB_MODULE)

// Build V<tb>_<fb>__pi1.h
#define VTB_FIREBRIDGE(tb, fb) V##tb##_##fb##__pi1
#define VTB_FIREBRIDGE_H(tb, fb) STR(VTB_FIREBRIDGE(tb, fb).h)
#include VTB_FIREBRIDGE_H(TB_MODULE, FB_MODULE)

#define VCLASS XCAT(V, TB_MODULE)

using namespace std;

vluint64_t sim_time = 0;
VCLASS *top;
VerilatedContext *contextp;

#ifdef __cplusplus
  #define EXT_C "C"
  #define restrict __restrict__ 
#else
  #define EXT_C
#endif

// Below are helper functions to pass time inside SV

extern "C" unsigned char get_clk();

extern "C" void step_time_veri() {
    top->eval();
    contextp->timeInc(1);
}

extern "C" void at_posedge_clk(){
    vluint8_t prev_clk = get_clk();
    while(true){
        step_time_veri();
        if(prev_clk == 0 && get_clk() == 1){
            for (int i = 0; i < 10; i++) step_time_veri();
            break;
        }
        prev_clk = get_clk();
    }
}



int main(int argc, char** argv){

    contextp = new VerilatedContext();
    contextp->commandArgs(argc, argv);
    contextp->traceEverOn(true);
    top = new VCLASS(contextp);

    while(!contextp->gotFinish()) step_time_veri();

    delete top;
    delete contextp;
    return 0;
}