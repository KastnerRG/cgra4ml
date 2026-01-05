.PHONY: image start kill enter ibuild irun iclean

# Testing

TEST := param_test
WORKDIR := run/work

clean:
	rm -rf $(WORKDIR)

$(WORKDIR):
	mkdir -p $(WORKDIR)

smoke_test: $(WORKDIR)
	cd $(WORKDIR) && python -m pytest -s ../$(TEST).py

verify_ibex: $(WORKDIR)
	cd ibex-soc && python check_output.py

smoke_ibex: $(WORKDIR)
	make TEST=ibex_test smoke_test iclean ibuild irun verify_ibex

# Docker

USR       := $(shell id -un)
UID       := $(shell id -u)
GID       := $(shell id -g)
IMAGE     := $(USR)/cgra4ml-ibex:dev
CONTAINER := cgra4ml-ibex-$(USR)
HOSTNAME  := cgraibex
SHORTUSR  := $(shell id -un | cut -c1-4)

image:
	docker build \
		-f Dockerfile \
		--build-arg UID=$(UID) \
		--build-arg GID=$(GID) \
		--build-arg USERNAME=$(SHORTUSR) \
		-t $(IMAGE) .

start:
	docker run -d --name $(CONTAINER) \
		-h $(HOSTNAME) \
		--tty --interactive \
		-v $(PWD):/work \
		-w /work \
		$(IMAGE) bash -lc 'fusesoc library add sa_ip /work || true; tail -f /dev/null'

enter:
	docker exec -it $(CONTAINER) bash

kill:
	docker kill $(CONTAINER) || true
	docker rm   $(CONTAINER) || true

# Ibex

ibuild:
	${MAKE} -C ibex-soc build

irun:
	${MAKE} -C ibex-soc run

iclean:
	${MAKE} -C ibex-soc clean

iprint:
	${MAKE} -C ibex-soc print