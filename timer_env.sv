//=============================================================================
// timer_env.sv
//=============================================================================
class timer_env extends uvm_env;
  `uvm_component_utils(timer_env)

  timer_agent      agent;
  timer_scoreboard scoreboard;
  timer_coverage   coverage;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent      = timer_agent::type_id::create("agent", this);
    scoreboard = timer_scoreboard::type_id::create("scoreboard", this);
    coverage   = timer_coverage::type_id::create("coverage", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.monitor.ap.connect(scoreboard.analysis_export);
    agent.monitor.ap.connect(coverage.analysis_export);
  endfunction

endclass
