CC ?= gcc

CFLAGS += -Wall -Wextra -O2 -I../linux_driver

TARGETS := reg_test ioctl_test dma_buf_test

all: $(TARGETS)

reg_test: reg_test.c
	$(CC) $(CFLAGS) -o $@ $<

ioctl_test: ioctl_test.c
	$(CC) $(CFLAGS) -o $@ $<

dma_buf_test: dma_buf_test.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f $(TARGETS)
