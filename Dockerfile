FROM python:3.11.5-slim

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    git curl wget \
    libelf-dev srecord \
    autoconf automake autotools-dev \
    libmpc-dev libmpfr-dev libgmp-dev \
    gawk bison flex texinfo patchutils libexpat1-dev \
    libfl2 libfl-dev \
    help2man perl \
    liblzma-dev libunwind-dev libgoogle-perftools-dev numactl \
    ccache \
    && rm -rf /var/lib/apt/lists/*

COPY ibex-soc/python-requirements.txt /tmp/python-requirements.txt
RUN python3 -m pip install --no-cache-dir -r /tmp/python-requirements.txt \
    && rm -rf /tmp/python-requirements.txt /tmp/vendor

ARG VERILATOR_VERSION=v5.024
RUN git clone https://github.com/verilator/verilator.git \
    && cd verilator && git checkout ${VERILATOR_VERSION} \
    && autoconf && ./configure \
    && make -j"$(nproc)" && make install \
    && cd .. && rm -rf verilator

WORKDIR /tmp/pybuild
COPY pyproject.toml .
COPY LICENSE .
COPY README.md .
COPY deepsocflow ./deepsocflow
RUN python3 -m pip install --no-cache-dir .

ARG RISCV_TOOLCHAIN_VERSION=20240206-1
RUN wget https://raw.githubusercontent.com/lowRISC/opentitan/master/util/get-toolchain.py -O /tmp/get-toolchain.py \
    && python3 /tmp/get-toolchain.py \
         --install-dir /opt/lowrisc-toolchain \
         --release-version ${RISCV_TOOLCHAIN_VERSION} \
         --update \
    && rm /tmp/get-toolchain.py

ENV RISCV_TOOLCHAIN=/opt/lowrisc-toolchain
ENV RISCV_GCC=${RISCV_TOOLCHAIN}/bin/riscv32-unknown-elf-gcc
ENV RISCV_OBJCOPY=${RISCV_TOOLCHAIN}/bin/riscv32-unknown-elf-objcopy
ENV PATH=${RISCV_TOOLCHAIN}/bin:${PATH}

# Create non-root user to match host UID/GID
ARG USERNAME=usr
ARG UID=1000
ARG GID=1000

RUN groupadd -g ${GID} ${USERNAME} \
    && useradd -m -u ${UID} -g ${GID} ${USERNAME}

USER ${USERNAME}
WORKDIR /work

RUN echo 'export PS1="\[\e[0;33m\][\u@\h \W]\$ \[\e[m\] "' >> /home/${USERNAME}/.bashrc
