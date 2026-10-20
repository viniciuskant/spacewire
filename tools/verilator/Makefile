# the logs are written with tee: keep the exit status of the tool
SHELL:=/bin/bash
.SHELLFLAGS:=-o pipefail -c

PROJ_ROOT:=../..
SIM_ROOT:=$(PROJ_ROOT)/sim
UVM_HOME?=$(HOME)/.local/lib/uvm/src
SEED?=1
UVM_VERBOSITY?=UVM_LOW
VL_ARGS:=--binary --timing -j 0 -Wno-fatal -Wno-lint -Wno-style --timescale 1ns/1ps \
	+define+UVM_NO_DPI +incdir+$(UVM_HOME) $(UVM_HOME)/uvm_pkg.sv
SIM_ARGS:=+verilator+seed+$(SEED) +UVM_VERBOSITY=$(UVM_VERBOSITY) +UVM_NO_RELNOTES

# $(1): test name, $(2): top module, $(3): filelist
define run_test
	mkdir -p work && cd work && verilator $(VL_ARGS) --top-module $(2) -F ../$(SIM_ROOT)/$(3) \
		--Mdir $(1) -o simv 2>&1 | tee $(1)_compile.log
	cd work && ./$(1)/simv +UVM_TESTNAME=$(1) $(SIM_ARGS) 2>&1 | tee $(1)_run.log
endef

selftest:
	$(call run_test,spw_selftest_test,tb_top,selftest.f)

host_selftest:
	$(call run_test,host_selftest_test,host_selftest_top,host_selftest.f)

clean:
	rm -rf work

.PHONY: selftest host_selftest clean
