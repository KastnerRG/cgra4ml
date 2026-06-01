#include <linux/mm.h>
#include <linux/slab.h>

#include "cgra4ml_dma.h"

static int cgra4ml_dma_alloc_one(struct cgra4ml_dev *cdev,
                 struct cgra4ml_dma_buf *buf,
                 const char *name,
                 size_t size)
{
    buf->name = name;
    buf->size = PAGE_ALIGN(size);

    buf->cpu_addr = dma_alloc_coherent(cdev->dev, buf->size,
                       &buf->dma_addr, GFP_KERNEL);
    if (!buf->cpu_addr) {
        dev_err(cdev->dev, "failed to allocate %s buffer, size=%zu\n",
            name, buf->size);
        return -ENOMEM;
    }

    memset(buf->cpu_addr, 0, buf->size);

    dev_info(cdev->dev, "%s: cpu=%p dma=%pad size=%zu\n",
         name, buf->cpu_addr, &buf->dma_addr, buf->size);
    return 0;
}

static void cgra4ml_dma_free_one(struct cgra4ml_dev *cdev,
                 struct cgra4ml_dma_buf *buf)
{
    if (!buf->cpu_addr)
        return;

    dma_free_coherent(cdev->dev, buf->size, buf->cpu_addr, buf->dma_addr);

    buf->cpu_addr = NULL;
    buf->dma_addr = 0;
    buf->size = 0;
}

int cgra4ml_dma_alloc_all(struct cgra4ml_dev *cdev,
              size_t weights_size,
              size_t input_size,
              size_t output_size,
              size_t ocm_size)
{
    int ret;

    ret = cgra4ml_dma_alloc_one(cdev, &cdev->weights, "weights", weights_size);
    if (ret)
        goto fail;

    ret = cgra4ml_dma_alloc_one(cdev, &cdev->input, "input", input_size);
    if (ret)
        goto fail;

    ret = cgra4ml_dma_alloc_one(cdev, &cdev->output, "output", output_size);
    if (ret)
        goto fail;

    ret = cgra4ml_dma_alloc_one(cdev, &cdev->ocm0, "ocm0", ocm_size);
    if (ret)
        goto fail;

    ret = cgra4ml_dma_alloc_one(cdev, &cdev->ocm1, "ocm1", ocm_size);
    if (ret)
        goto fail;

    return 0;

fail:
    cgra4ml_dma_free_all(cdev);
    return ret;
}

void cgra4ml_dma_free_all(struct cgra4ml_dev *cdev)
{
    cgra4ml_dma_free_one(cdev, &cdev->ocm1);
    cgra4ml_dma_free_one(cdev, &cdev->ocm0);
    cgra4ml_dma_free_one(cdev, &cdev->output);
    cgra4ml_dma_free_one(cdev, &cdev->input);
    cgra4ml_dma_free_one(cdev, &cdev->weights);
}

static struct cgra4ml_dma_buf *cgra4ml_dma_select_buf(struct cgra4ml_dev *cdev,
                              unsigned long index)
{
    switch (index) {
    case CGRA4ML_MMAP_WEIGHTS:
        return &cdev->weights;
    case CGRA4ML_MMAP_INPUT:
        return &cdev->input;
    case CGRA4ML_MMAP_OUTPUT:
        return &cdev->output;
    case CGRA4ML_MMAP_OCM0:
        return &cdev->ocm0;
    case CGRA4ML_MMAP_OCM1:
        return &cdev->ocm1;
    default:
        return NULL;
    }
}

int cgra4ml_dma_mmap(struct cgra4ml_dev *cdev, struct vm_area_struct *vma)
{
    unsigned long index = vma->vm_pgoff;
    size_t requested = vma->vm_end - vma->vm_start;
    struct cgra4ml_dma_buf *buf;

    buf = cgra4ml_dma_select_buf(cdev, index);
    if (!buf || !buf->cpu_addr)
        return -EINVAL;

    if (requested > buf->size)
        return -EINVAL;

    return dma_mmap_coherent(cdev->dev, vma, buf->cpu_addr,
                 buf->dma_addr, requested);
}

void cgra4ml_dma_fill_info(struct cgra4ml_dev *cdev,
               struct cgra4ml_buf_info *info)
{
    memset(info, 0, sizeof(*info));

    info->weights_phys = (u64)cdev->weights.dma_addr;
    info->input_phys   = (u64)cdev->input.dma_addr;
    info->output_phys  = (u64)cdev->output.dma_addr;
    info->ocm0_phys    = (u64)cdev->ocm0.dma_addr;
    info->ocm1_phys    = (u64)cdev->ocm1.dma_addr;

    info->weights_size = (u32)cdev->weights.size;
    info->input_size   = (u32)cdev->input.size;
    info->output_size  = (u32)cdev->output.size;
    info->ocm_size     = (u32)cdev->ocm0.size;
    info->reg_size     = (u32)cdev->regs_size;
}
