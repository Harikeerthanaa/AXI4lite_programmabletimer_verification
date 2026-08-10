//=============================================================================
// timer_pkg.sv - compile this package AFTER timer_if.sv, before tb_top.sv
//=============================================================================
package timer_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "timer_txn.sv"
  `include "timer_sequencer.sv"
  `include "timer_sequences.sv"
  `include "timer_driver.sv"
  `include "timer_monitor.sv"
  `include "timer_scoreboard.sv"
  `include "timer_coverage.sv"
  `include "timer_agent.sv"
  `include "timer_env.sv"
  `include "timer_test.sv"

endpackage
