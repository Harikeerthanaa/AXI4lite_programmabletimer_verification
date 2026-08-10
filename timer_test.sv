//=============================================================================
// timer_test.sv
//=============================================================================
class timer_base_test extends uvm_test;
  `uvm_component_utils(timer_base_test)

  timer_env env;
  virtual timer_if.DRV drv_vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = timer_env::type_id::create("env", this);
    if (!uvm_config_db#(virtual timer_if.DRV)::get(this, "", "vif", drv_vif))
      `uvm_fatal(get_type_name(), "virtual interface not set for test")
  endfunction

  task run_phase(uvm_phase phase);
    timer_smoke_seq seq;
    phase.raise_objection(this);

    apply_reset();

    seq = timer_smoke_seq::type_id::create("seq");
    seq.start(env.agent.sequencer);

    // small settle window so the final periodic_seq's ctrl-off write and
    // any trailing CDC pulses fully drain before we tear down
    repeat (20) @(drv_vif.drv_cb);

    phase.drop_objection(this);
  endtask

  task apply_reset();
    drv_vif.s_axi_aresetn <= 0;
    drv_vif.timer_rst_n   <= 0;
    repeat (10) @(drv_vif.drv_cb);
    drv_vif.s_axi_aresetn <= 1;
    drv_vif.timer_rst_n   <= 1;
    repeat (5) @(drv_vif.drv_cb);
  endtask

endclass
