//=============================================================================
// timer_coverage.sv
//
// Functional coverage measures stimulus completeness (did we exercise every
// register, every CTRL field value, both modes, both W1C outcomes) - it is
// a separate concern from bug detection. Report it alongside the scoreboard
// pass/fail counts and the static-tool findings in your final comparison,
// it's the piece that answers "how thoroughly did the dynamic side actually
// look before concluding it missed something."
//=============================================================================
class timer_coverage extends uvm_subscriber #(timer_txn);
  `uvm_component_utils(timer_coverage)

  timer_txn last_txn;

  covergroup cg_reg_access;
    option.per_instance = 1;
    cp_addr: coverpoint last_txn.addr {
      bins ctrl   = {timer_txn::ADDR_CTRL};
      bins load   = {timer_txn::ADDR_LOAD};
      bins count  = {timer_txn::ADDR_COUNT};
      bins status = {timer_txn::ADDR_STATUS};
    }
    cp_op: coverpoint last_txn.op {
      bins rd = {timer_txn::OP_READ};
      bins wr = {timer_txn::OP_WRITE};
    }
    cx_addr_op: cross cp_addr, cp_op;
  endgroup

  covergroup cg_ctrl_fields;
    option.per_instance = 1;
    cp_en:   coverpoint last_txn.wdata[0];
    cp_mode: coverpoint last_txn.wdata[1];
    cp_ie:   coverpoint last_txn.wdata[2];
    cx_mode_en: cross cp_mode, cp_en;
  endgroup

  covergroup cg_status_w1c;
    option.per_instance = 1;
    cp_w1c_bit: coverpoint last_txn.wdata[0] {
      bins clear_write   = {1};
      bins no_clear_write = {0};
    }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_reg_access  = new();
    cg_ctrl_fields = new();
    cg_status_w1c  = new();
  endfunction

  function void write(timer_txn t);
    last_txn = t;
    cg_reg_access.sample();
    if (t.op == timer_txn::OP_WRITE && t.addr == timer_txn::ADDR_CTRL)
      cg_ctrl_fields.sample();
    if (t.op == timer_txn::OP_WRITE && t.addr == timer_txn::ADDR_STATUS)
      cg_status_w1c.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
      $sformatf("COVERAGE SUMMARY: reg_access=%0.1f%% ctrl_fields=%0.1f%% status_w1c=%0.1f%%",
                 cg_reg_access.get_coverage(), cg_ctrl_fields.get_coverage(),
                 cg_status_w1c.get_coverage()),
      UVM_LOW)
  endfunction

endclass
