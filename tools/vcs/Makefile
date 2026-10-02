PROJ_ROOT:=../..
SIM_ROOT:=$(PROJ_ROOT)/sim
VCS_ARGS:=-full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps -debug_access+all -kdb -l compile.log 


clean:
	rm -rf work

selftest:
	mkdir -p work && cd work && vcs -F $(SIM_ROOT)/selftest.f $(VCS_ARGS)
	cd work && ./simv -l run.log +UVM_TESTNAME=spw_selftest_test +UVM_VERBOSITY=UVM_LOW

.PHONY: clean
