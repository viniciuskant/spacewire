PROJ_ROOT:=../..
SIM_ROOT:=$(PROJ_ROOT)/sim
SEED?=1
IHP_V=/pdk/ihp/ihp130/ixc013g2ng_stdcell/verilog/ixc013g2ng_stdcell.v
UVM_VERBOSITY?=UVM_LOW
# uvm-ieee-2020: same UVM release the Verilator flow compiles (1800.2-2020)
VCS_ARGS:=-full64 -sverilog -ntb_opts uvm-ieee-2020 -timescale=1ns/1ps -debug_access+all -kdb
SIM_ARGS:=+ntb_random_seed=$(SEED) +UVM_VERBOSITY=$(UVM_VERBOSITY) +UVM_NO_RELNOTES

# $(1): test name, $(2): top module, $(3): filelist
define run_test
	mkdir -p work/$(1) && cd work && vcs $(VCS_ARGS) -top $(2) -F ../$(SIM_ROOT)/$(3) \
		-Mdir=$(1)/csrc -o $(1)/simv -l $(1)_compile.log
	cd work && ./$(1)/simv +UVM_TESTNAME=$(1) $(SIM_ARGS) -l $(1)_run.log
endef

selftest:
	$(call run_test,spw_selftest_test,tb_top,selftest.f)

host_selftest:
	$(call run_test,host_selftest_test,host_selftest_top,host_selftest.f)

# build once, then run any codec test: make codec TEST=codec_smoke_test
TEST?=codec_smoke_test
codec:
	mkdir -p work/$(1) && cd work && vcs $(VCS_ARGS) -top codec_top -F ../$(SIM_ROOT)/codec.f $(IHP_V) \
		-Mdir=codec/csrc -o codec/simv -l codec_compile.log
	cd work && ./codec/simv +UVM_TESTNAME=$(TEST) $(SIM_ARGS) -l $(TEST)_run.log

clean:
	rm -rf work

.PHONY: selftest host_selftest codec clean
