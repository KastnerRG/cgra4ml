#include <linux/delay.h>
#include <linux/jiffies.h>
#include <linux/ktime.h>
#include <linux/printk.h>

#include "cgra4ml_hw.h"
#include "cgra4ml_regs.h"

u32 cgra4ml_read_reg(struct cgra4ml_dev *cdev, u32 offset)
{
    if (offset + sizeof(u32) > cdev->regs_size) {
        dev_warn(cdev->dev, "read offset 0x%x outside reg size 0x%pa\n",
             offset, &cdev->regs_size);
        return 0xffffffff;
    }

    return ioread32(cdev->regs + offset);
}

void cgra4ml_write_reg(struct cgra4ml_dev *cdev, u32 offset, u32 value)
{
    if (offset + sizeof(u32) > cdev->regs_size) {
        dev_warn(cdev->dev, "write offset 0x%x outside reg size 0x%pa\n",
             offset, &cdev->regs_size);
        return;
    }

    iowrite32(value, cdev->regs + offset);
}

void cgra4ml_hw_reset(struct cgra4ml_dev *cdev)
{
    cgra4ml_write_reg(cdev, CGRA4ML_REG_START,       0);

    cgra4ml_write_reg(cdev, CGRA4ML_REG_DONE_READ0,  1);
    cgra4ml_write_reg(cdev, CGRA4ML_REG_DONE_READ1,  1);

    cgra4ml_write_reg(cdev, CGRA4ML_REG_DONE_WRITE0, 0);
    cgra4ml_write_reg(cdev, CGRA4ML_REG_DONE_WRITE1, 0);

    cgra4ml_write_reg(cdev, CGRA4ML_REG_BUNDLE_DONE, 1);
    cgra4ml_write_reg(cdev, CGRA4ML_REG_W_DONE,      0);
    cgra4ml_write_reg(cdev, CGRA4ML_REG_X_DONE,      0);
    cgra4ml_write_reg(cdev, CGRA4ML_REG_O_DONE,      0);
}

void cgra4ml_hw_program_base_addrs(struct cgra4ml_dev *cdev)
{
    cgra4ml_write_reg(cdev, CGRA4ML_REG_OCM_BASE0,
              lower_32_bits(cdev->ocm0.dma_addr));
    cgra4ml_write_reg(cdev, CGRA4ML_REG_OCM_BASE1,
              lower_32_bits(cdev->ocm1.dma_addr));
    cgra4ml_write_reg(cdev, CGRA4ML_REG_WEIGHTS_BASE,
              lower_32_bits(cdev->weights.dma_addr));
}

void cgra4ml_hw_start(struct cgra4ml_dev *cdev, u32 n_bundles)
{
    cgra4ml_hw_reset(cdev);
    cgra4ml_hw_program_base_addrs(cdev);

    cgra4ml_write_reg(cdev, CGRA4ML_REG_N_BUNDLES, n_bundles);
    cgra4ml_write_reg(cdev, CGRA4ML_REG_START, 1);
}

u32 cgra4ml_hw_status(struct cgra4ml_dev *cdev)
{
    u32 w = cgra4ml_read_reg(cdev, CGRA4ML_REG_W_DONE);
    u32 x = cgra4ml_read_reg(cdev, CGRA4ML_REG_X_DONE);
    u32 o = cgra4ml_read_reg(cdev, CGRA4ML_REG_O_DONE);

    return (w & 0xff) | ((x & 0xff) << 8) | ((o & 0xff) << 16);
}

int cgra4ml_hw_wait_done(struct cgra4ml_dev *cdev, unsigned long timeout_ms)
{
    unsigned long deadline = jiffies + msecs_to_jiffies(timeout_ms);
    u32 status;

    while (time_before(jiffies, deadline)) {
        status = cgra4ml_hw_status(cdev);

        if ((status >> 16) & 0xff)
            return 0;

        cpu_relax();
        usleep_range(100, 500);
    }

    dev_warn(cdev->dev, "timeout waiting for O_DONE, status=0x%08x\n",
         cgra4ml_hw_status(cdev));
    return -ETIMEDOUT;
}
