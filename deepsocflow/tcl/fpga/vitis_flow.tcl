app create -name dsf_app -os {standalone} -proc {psu_cortexa53_0} -lang {c} -arch {64} -hw {D:\dnn-engine\run\work_ccd\dsf_zcu104\design_1_wrapper.xsa} -out {C:/Users/abara/workspace};
app config -name dsf_app -append libraries {m}
app config -name dsf_app -set compiler-optimization {Optimize most (-O3)}
app config -name dsf_app -add include-path D:/dnn-engine/deepsocflow/c/
app config -name dsf_app -add include-path D:/dnn-engine/run/work/


cp D:/dnn-engine/deepsocflow/c/xilinx_example.c C:/Users/abara/workspace/dsf_app/src/helloworld.c
app build -name dsf_app



