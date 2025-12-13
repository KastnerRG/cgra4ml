# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Generate a baremetal application

# Name of the program $(PROGRAM).c will be added as a source file
PROGRAM = hello_test
PROGRAM_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
SA_ROOT := $(abspath $(PROGRAM_DIR)/../../../../..)
# Any extra source files to include in the build. Use the upper case .S
# extension for assembly files
EXTRA_SRCS :=

include ${PROGRAM_DIR}/../common/common.mk

INCS += -I${SA_ROOT}/deepsocflow/c
INCS += -I${SA_ROOT}/deepsocflow/firebridge
INCS += -I${SA_ROOT}/run/work
CFLAGS += -DRISCV