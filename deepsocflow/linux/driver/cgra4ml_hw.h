#ifndef CGRA4ML_HW_H
#define CGRA4ML_HW_H

#include "cgra4ml_priv.h"

u32 cgra4ml_read_reg(struct cgra4ml_dev *cdev, u32 offset);
void cgra4ml_write_reg(struct cgra4ml_dev *cdev, u32 offset, u32 value);

void cgra4ml_hw_reset(struct cgra4ml_dev *cdev);
void cgra4ml_hw_program_base_addrs(struct cgra4ml_dev *cdev);
void cgra4ml_hw_start(struct cgra4ml_dev *cdev, u32 n_bundles);
u32 cgra4ml_hw_status(struct cgra4ml_dev *cdev);
int cgra4ml_hw_wait_done(struct cgra4ml_dev *cdev, unsigned long timeout_ms);

#endif
