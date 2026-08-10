#=============================================================================
# Makefile - compile and run the UVM testbench with Synopsys VCS
#
#   make run                 # clean bug config, no bug injected
#   make run BUG=BUG6_FUNC_OFFBYONE
#   make lint                # (delegates to ../static/run_static.sh, lint only)
#   make cdc                 # (delegates to ../static/run_static.sh, cdc only)
#   make clean
#
# BUG selection here does NOT edit bug_defines.svh for you - it passes a
# +define+ on the VCS command line instead, which OVERRIDES whatever is
# commented in bug_defines.svh for THIS compile only. This lets sim/Makefile
# and static/*.tcl each select bugs independently without stepping on each
# other, though for a clean apples-to-apples comparison you generally want
# both flows pointed at the identical bug_defines.svh state - see the manual.
#=============================================================================

RTL_DIR := ../rtl
TB_DIR  := ../tb

RTL_SRCS := \
    $(RTL_DIR)/cdc_sync.sv \
    $(RTL_DIR)/timer_core.sv \
    $(RTL_DIR)/register_bank.sv \
    $(RTL_DIR)/axi4lite_timer_top.sv

TB_SRCS := \
    $(TB_DIR)/timer_if.sv \
    $(TB_DIR)/timer_pkg.sv \
    $(TB_DIR)/tb_top.sv

BUG ?=
BUGDEF := $(if $(BUG),+define+$(BUG),)

VCS_OPTS := -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps \
            +incdir+$(RTL_DIR) +incdir+$(TB_DIR) \
            -debug_access+all -kdb

.PHONY: run compile lint cdc clean

compile:
	vcs $(VCS_OPTS) $(BUGDEF) $(RTL_SRCS) $(TB_SRCS) -o simv

run: compile
	./simv +UVM_TESTNAME=timer_base_test +UVM_VERBOSITY=UVM_MEDIUM | tee run.log
	@echo "----"
	@echo "grep the log for the summary lines:"
	@echo "  grep SCOREBOARD run.log"
	@echo "  grep COVERAGE  run.log"
	@echo "  grep UVM_ERROR run.log"

lint:
	cd ../static && vcst -f lint.tcl

cdc:
	cd ../static && vcst -f cdc.tcl

clean:
	rm -rf simv simv.daidir csrc DVEfiles ucli.key vc_hdrs.h *.vpd *.vcd \
	       run.log reports .vlogansetup.env verdiLog novas.* AN.DB
