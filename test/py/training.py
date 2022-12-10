import torch
import os
import shutil

def simple_train_test(model, trainloader, testloader, optim, lr, criterion, n_epochs):
    model.cuda()
    model.train() # prep model for training
    optimizer = optim(model.parameters(), lr=lr)

    for epoch in range(n_epochs):
        train_loss = 0.0
        for data, target in trainloader:
            data, target = data.cuda(), target.cuda() # loading to GPU
            optimizer.zero_grad() # clear the gradients of all optimized variables
            output = model(data) # Fwd pass
            loss = criterion(output, target) # loss calc
            loss.backward()
            optimizer.step()
            train_loss += loss.item()*data.size(0) # as loss is tensor, .item() needed to get the value
        train_loss = train_loss/len(trainloader.dataset) # average loss over an epoch
        print(f'Epoch: {epoch+1} \tTraining Loss: {train_loss:.6f}')

    # Test Accuracy
    model.cuda()
    model.eval()
    test_loss = 0
    correct = 0

    with torch.no_grad():
        for data, target in testloader:
            data, target = data.cuda(), target.cuda() # loading to GPU
            output = model(data)
            pred = output.argmax(dim=1, keepdim=True)  
            correct += pred.eq(target.view_as(pred)).sum().item()

    test_loss /= len(testloader.dataset)
    print(f'\nTest set: Accuracy: {correct}/{len(testloader.dataset)} ({100. *correct / len(testloader.dataset):.0f}%)\n')

    
def train_val_save(model, trainloader, testloader, optim, lr, criterion, start_epoch, n_epochs, adjust_list, print_freq, save_dir):
    best_prec = 0
    model.cuda()
    optimizer = optim(model.parameters(), lr=lr)
    
    for epoch in range(start_epoch, n_epochs):
        
        model.train()
        adjust_learning_rate(optimizer, epoch, adjust_list)
        
        losses = AverageMeter()
        top1 = AverageMeter()
        
        for i, (x, target) in enumerate(trainloader):
            
            x, target = x.cuda(), target.cuda()
            output = model(x)
            loss = criterion(output, target)
            prec = accuracy(output, target)[0]
            losses.update(loss.item(), x.size(0))
            top1.update(prec.item(), x.size(0))

            optimizer.zero_grad()
            loss.backward()
            optimizer.step()

            if i % print_freq == 0:
                print(f'Epoch: [{epoch}][{i}/{len(trainloader)}]\t'
                      f'Loss {losses.val:.4f} ({losses.avg:.4f})\t'
                      f'Prec {top1.val:.3f}% ({top1.avg:.3f}%)')

        # evaluate on test set
        print("Validation starts")
        prec = validate(testloader, model, criterion, print_freq)

        # remember best precision and save checkpoint
        is_best = prec > best_prec
        best_prec = max(prec,best_prec)
        print('best acc: {:1f}'.format(best_prec))
        os.makedirs(save_dir, exist_ok=True)
        save_checkpoint({
            'epoch': epoch,
            'state_dict': model.state_dict(),
            'best_prec': best_prec,
            'optimizer': optimizer.state_dict(),
        }, is_best, save_dir)

def validate(val_loader, model, criterion, print_freq):
    losses = AverageMeter()
    top1 = AverageMeter()

    model.eval()
    
    with torch.no_grad():
        for i, (x, target) in enumerate(val_loader):
            x, target = x.cuda(), target.cuda()

            output = model(x)
            loss = criterion(output, target)

            prec = accuracy(output, target)[0]
            losses.update(loss.item(), x.size(0))
            top1.update(prec.item(), x.size(0))


            if i % print_freq == 0:  
                print(f'Test: [{i}/{len(val_loader)}]\t'
                  f'Loss {losses.val:.4f} ({losses.avg:.4f})\t'
                  f'Prec {top1.val:.3f}% ({top1.avg:.3f}%)')
    print(' * Prec {top1.avg:.3f}% '.format(top1=top1))
    return top1.avg


def accuracy(output, target, topk=(1,)):
    """Computes the precision@k for the specified values of k"""
    maxk = max(topk)
    batch_size = target.size(0)

    _, pred = output.topk(maxk, 1, True, True)
    pred = pred.t()
    correct = pred.eq(target.view(1, -1).expand_as(pred))

    res = []
    for k in topk:
        correct_k = correct[:k].view(-1).float().sum(0)
        res.append(correct_k.mul_(100.0 / batch_size))
    return res


class AverageMeter(object):
    """Computes and stores the average and current value"""
    def __init__(self):
        self.reset()

    def reset(self):
        self.val = 0
        self.avg = 0
        self.sum = 0
        self.count = 0

    def update(self, val, n=1):
        self.val = val
        self.sum += val * n
        self.count += n
        self.avg = self.sum / self.count
        
def save_checkpoint(state, is_best, fdir):
    filepath = os.path.join(fdir, 'checkpoint.pth')
    torch.save(state, filepath)
    if is_best:
        shutil.copyfile(filepath, os.path.join(fdir, 'model_best.pth.tar'))

def adjust_learning_rate(optimizer, epoch, adjust_list):
    """For resnet, the lr starts from 0.1, and is divided by 10 at 80 and 120 epochs"""
    if epoch in adjust_list:
        for param_group in optimizer.param_groups:
            param_group['lr'] = param_group['lr'] * 0.1
