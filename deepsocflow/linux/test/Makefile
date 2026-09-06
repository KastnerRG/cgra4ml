CC ?= gcc

CFLAGS += -Wall -Wextra -O2 \
	  -I../driver \
	  -I../../c \
	  -I../../firebridge \
	  -I../../.. \
	  -I../../../run/work
LDFLAGS += -lm

TARGETS := reg_test ioctl_test dma_buf_test
LIBS    := libinference.so

all: $(TARGETS)

reg_test: reg_test.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

ioctl_test: ioctl_test.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

dma_buf_test: dma_buf_test.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

libinference.so: ../host.c
	$(CC) $(CFLAGS) -shared -fPIC -o $@ $< $(LDFLAGS)

clean:
	rm -f $(TARGETS) $(LIBS)
