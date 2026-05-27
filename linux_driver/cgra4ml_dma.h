#ifndef CGRA4ML_DMA_H
#define CGRA4ML_DMA_H

#include "cgra4ml_priv.h"

int cgra4ml_dma_alloc_all(struct cgra4ml_dev *cdev,
              size_t weights_size,
              size_t input_size,
              size_t output_size,
              size_t ocm_size);

void cgra4ml_dma_free_all(struct cgra4ml_dev *cdev);

int cgra4ml_dma_mmap(struct cgra4ml_dev *cdev, struct vm_area_struct *vma);

void cgra4ml_dma_fill_info(struct cgra4ml_dev *cdev,
               struct cgra4ml_buf_info *info);

#endif
