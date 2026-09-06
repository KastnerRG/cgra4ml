#include <linux/fs.h>
#include <linux/module.h>
#include <linux/of.h>
#include <linux/of_address.h>
#include <linux/platform_device.h>
#include <linux/uaccess.h>

#include "cgra4ml_priv.h"
#include "cgra4ml_hw.h"
#include "cgra4ml_dma.h"

static unsigned int weights_size = 16 * 1024 * 1024;
static unsigned int input_size   = 16 * 1024 * 1024;
static unsigned int output_size  = 16 * 1024 * 1024;
static unsigned int ocm_size     = 1  * 1024 * 1024;
static unsigned int wait_timeout_ms = 5000;

module_param(weights_size, uint, 0644);
MODULE_PARM_DESC(weights_size, "coherent weights/bias buffer size in bytes");

module_param(input_size, uint, 0644);
MODULE_PARM_DESC(input_size, "coherent input buffer size in bytes");

module_param(output_size, uint, 0644);
MODULE_PARM_DESC(output_size, "coherent output buffer size in bytes");

module_param(ocm_size, uint, 0644);
MODULE_PARM_DESC(ocm_size, "coherent OCM bank buffer size in bytes");

module_param(wait_timeout_ms, uint, 0644);
MODULE_PARM_DESC(wait_timeout_ms, "wait timeout for CGRA completion in ms");

static int cgra4ml_open(struct inode *inode, struct file *file)
{
    struct miscdevice *misc = file->private_data;
    struct cgra4ml_dev *cdev = container_of(misc, struct cgra4ml_dev, miscdev);

    file->private_data = cdev;
    return 0;
}

static int cgra4ml_release(struct inode *inode, struct file *file)
{
    return 0;
}

static long cgra4ml_ioctl(struct file *file, unsigned int cmd, unsigned long arg)
{
    struct cgra4ml_dev *cdev = file->private_data;
    struct cgra4ml_reg_access reg;
    struct cgra4ml_buf_info info;
    struct cgra4ml_start_config start_cfg;
    u32 status;
    int ret = 0;

    mutex_lock(&cdev->lock);

    switch (cmd) {
    case CGRA4ML_IOC_READ_REG:
        if (copy_from_user(&reg, (void __user *)arg, sizeof(reg))) {
            ret = -EFAULT;
            break;
        }
        reg.value = cgra4ml_read_reg(cdev, reg.offset);
        if (copy_to_user((void __user *)arg, &reg, sizeof(reg)))
            ret = -EFAULT;
        break;

    case CGRA4ML_IOC_WRITE_REG:
        if (copy_from_user(&reg, (void __user *)arg, sizeof(reg))) {
            ret = -EFAULT;
            break;
        }
        cgra4ml_write_reg(cdev, reg.offset, reg.value);
        break;

    case CGRA4ML_IOC_GET_BUFS:
        cgra4ml_dma_fill_info(cdev, &info);
        if (copy_to_user((void __user *)arg, &info, sizeof(info)))
            ret = -EFAULT;
        break;

    case CGRA4ML_IOC_HW_RESET:
        cgra4ml_hw_reset(cdev);
        break;

    case CGRA4ML_IOC_HW_START:
        if (copy_from_user(&start_cfg, (void __user *)arg, sizeof(start_cfg))) {
            ret = -EFAULT;
            break;
        }
        cgra4ml_hw_start(cdev, start_cfg.n_bundles);
        break;

    case CGRA4ML_IOC_WAIT_DONE:
        ret = cgra4ml_hw_wait_done(cdev, wait_timeout_ms);
        status = cgra4ml_hw_status(cdev);
        if (copy_to_user((void __user *)arg, &status, sizeof(status)))
            ret = -EFAULT;
        break;

    case CGRA4ML_IOC_DUMP_STATUS:
        status = cgra4ml_hw_status(cdev);
        if (copy_to_user((void __user *)arg, &status, sizeof(status)))
            ret = -EFAULT;
        break;

    default:
        ret = -ENOTTY;
        break;
    }

    mutex_unlock(&cdev->lock);
    return ret;
}

static int cgra4ml_mmap(struct file *file, struct vm_area_struct *vma)
{
    struct cgra4ml_dev *cdev = file->private_data;

    return cgra4ml_dma_mmap(cdev, vma);
}

static const struct file_operations cgra4ml_fops = {
    .owner          = THIS_MODULE,
    .open           = cgra4ml_open,
    .release        = cgra4ml_release,
    .unlocked_ioctl = cgra4ml_ioctl,
    .mmap           = cgra4ml_mmap,
};

static int cgra4ml_probe(struct platform_device *pdev)
{
    struct cgra4ml_dev *cdev;
    struct resource *res;
    int ret;

    cdev = devm_kzalloc(&pdev->dev, sizeof(*cdev), GFP_KERNEL);
    if (!cdev)
        return -ENOMEM;

    cdev->dev = &pdev->dev;
    mutex_init(&cdev->lock);
    init_waitqueue_head(&cdev->waitq);

    ret = dma_set_mask_and_coherent(&pdev->dev, DMA_BIT_MASK(32));
    if (ret) {
        dev_err(&pdev->dev, "failed to set 32-bit DMA mask: %d\n", ret);
        return ret;
    }

    res = platform_get_resource(pdev, IORESOURCE_MEM, 0);
    if (!res) {
        dev_err(&pdev->dev, "missing AXI-Lite register resource\n");
        return -ENODEV;
    }

    cdev->regs_phys = res->start;
    cdev->regs_size = resource_size(res);

    cdev->regs = devm_ioremap_resource(&pdev->dev, res);
    if (IS_ERR(cdev->regs))
        return PTR_ERR(cdev->regs);

    ret = cgra4ml_dma_alloc_all(cdev, weights_size, input_size,
                    output_size, ocm_size);
    if (ret)
        return ret;

    cdev->miscdev.minor = MISC_DYNAMIC_MINOR;
    cdev->miscdev.name  = CGRA4ML_DEV_NAME;
    cdev->miscdev.fops  = &cgra4ml_fops;
    cdev->miscdev.parent = &pdev->dev;

    ret = misc_register(&cdev->miscdev);
    if (ret) {
        dev_err(&pdev->dev, "failed to register misc device: %d\n", ret);
        goto err_free_dma;
    }

    platform_set_drvdata(pdev, cdev);

    cgra4ml_hw_reset(cdev);
    cgra4ml_hw_program_base_addrs(cdev);

    dev_info(&pdev->dev,
         "CGRA4ML driver loaded: regs=%pa size=0x%pa dev=/dev/%s\n",
         &cdev->regs_phys, &cdev->regs_size, CGRA4ML_DEV_NAME);

    return 0;

err_free_dma:
    cgra4ml_dma_free_all(cdev);
    return ret;
}

static void cgra4ml_remove(struct platform_device *pdev)
{
    struct cgra4ml_dev *cdev = platform_get_drvdata(pdev);

    misc_deregister(&cdev->miscdev);
    cgra4ml_dma_free_all(cdev);

    dev_info(&pdev->dev, "CGRA4ML driver removed\n");
}

static const struct of_device_id cgra4ml_of_match[] = {
    { .compatible = "xlnx,axi-cgra4ml-1.0" },
    { .compatible = "ucsd,cgra4ml-1.0" },
    { .compatible = "kastner,cgra4ml-1.0" },
    { }
};
MODULE_DEVICE_TABLE(of, cgra4ml_of_match);

static struct platform_driver cgra4ml_platform_driver = {
    .probe  = cgra4ml_probe,
    .remove = cgra4ml_remove,
    .driver = {
        .name = CGRA4ML_DRV_NAME,
        .of_match_table = cgra4ml_of_match,
    },
};

module_platform_driver(cgra4ml_platform_driver);

MODULE_AUTHOR("Yi-yang Chen / CSE237D CGRA4ML Driver");
MODULE_DESCRIPTION("Linux platform driver for CGRA4ML AXI-Lite control and coherent buffers");
MODULE_LICENSE("GPL");
