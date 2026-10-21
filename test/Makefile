# This file is public domain, it can be freely copied without restrictions.
# SPDX-License-Identifier: CC0-1.0

# Makefile

# defaults
SIM ?= verilator
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(PWD)/../v2/lib/**.sv
VERILOG_SOURCES += $(PWD)/../v2/**.sv
VERILOG_SOURCES += $(PWD)/dut.sv
# use VHDL_SOURCES for VHDL files

COMPILE_ARGS += -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC
COMPILE_ARGS += --trace-fst

# COCOTB_TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
COCOTB_TOPLEVEL = dut

# COCOTB_TEST_MODULES is the basename of the Python test file(s)
COCOTB_TEST_MODULES = main

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
