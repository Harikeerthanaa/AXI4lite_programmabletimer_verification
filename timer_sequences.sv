//=============================================================================
// timer_sequences.sv
//
// reg_write_seq / reg_read_seq  - single-register primitives, used as
//                                  building blocks by every other sequence
// oneshot_seq                   - programs one-shot mode with a known LOAD,
//                                  waits for the irq to assert, then checks
//                                  it clears correctly (catches BUG6, BUG7)
// periodic_seq                  - programs periodic mode, lets several
//                                  reload periods elapse, clearing the
//                                  interrupt each time (catches BUG6, BUG7,
//                                  incidentally exercises BUG3/4/5 registers)
// w1c_negative_seq              - explicitly proves that writing 0 to
//                                  STATUS does NOT clear INTR (catches BUG7
//                                  directly and unambiguously)
// reg_readback_seq              - writes then reads back CTRL/LOAD to sanity
//                                  check the register bank's basic plumbing
//=============================================================================

class reg_write_seq extends uvm_sequence #(timer_txn);
  `uvm_object_utils(reg_write_seq)
  rand bit [3:0]  addr;
  rand bit [31:0] wdata;

  function new(string name = "reg_write_seq");
    super.new(name);
  endfunction

  task body();
    timer_txn t = timer_txn::type_id::create("t");
    start_item(t);
    if (!t.randomize() with { op == timer_txn::OP_WRITE; addr == local::addr; wdata == local::wdata; })
      `uvm_error(get_type_name(), "randomize failed")
    finish_item(t);
  endtask
endclass


class reg_read_seq extends uvm_sequence #(timer_txn);
  `uvm_object_utils(reg_read_seq)
  rand bit [3:0] addr;
  bit [31:0]     rdata; // result, valid after body() returns

  function new(string name = "reg_read_seq");
    super.new(name);
  endfunction

  task body();
    timer_txn t = timer_txn::type_id::create("t");
    start_item(t);
    if (!t.randomize() with { op == timer_txn::OP_READ; addr == local::addr; })
      `uvm_error(get_type_name(), "randomize failed")
    finish_item(t);
    rdata = t.rdata;
  endtask
endclass


class reg_readback_seq extends uvm_sequence #(timer_txn);
  `uvm_object_utils(reg_readback_seq)

  function new(string name = "reg_readback_seq");
    super.new(name);
  endfunction

  task body();
    reg_write_seq wr;
    reg_read_seq  rd;

    wr = reg_write_seq::type_id::create("wr");
    wr.addr  = timer_txn::ADDR_LOAD;
    wr.wdata = 32'h0000_1234;
    wr.start(m_sequencer);

    rd = reg_read_seq::type_id::create("rd");
    rd.addr = timer_txn::ADDR_LOAD;
    rd.start(m_sequencer);

    if (rd.rdata !== 32'h0000_1234)
      `uvm_error(get_type_name(),
        $sformatf("LOAD readback mismatch: wrote 0x1234, read 0x%08h", rd.rdata))
  endtask
endclass


class oneshot_seq extends uvm_sequence #(timer_txn);
  `uvm_object_utils(oneshot_seq)
  rand bit [31:0] load_val;
  constraint c_reasonable_load { load_val inside {[10:200]}; }

  function new(string name = "oneshot_seq");
    super.new(name);
  endfunction

  task body();
    reg_write_seq wr;
    reg_read_seq  rd;

    // LOAD
    wr = reg_write_seq::type_id::create("wr_load");
    wr.addr  = timer_txn::ADDR_LOAD;
    wr.wdata = load_val;
    wr.start(m_sequencer);

    // CTRL: EN=1, MODE=1(oneshot), IE=1
    wr = reg_write_seq::type_id::create("wr_ctrl");
    wr.addr  = timer_txn::ADDR_CTRL;
    wr.wdata = 32'b0000_0111;
    wr.start(m_sequencer);

    // poll STATUS until INTR sets (test-level timeout guards against hangs)
    fork
      begin : poll
        bit done = 0;
        while (!done) begin
          rd = reg_read_seq::type_id::create("rd_status");
          rd.addr = timer_txn::ADDR_STATUS;
          rd.start(m_sequencer);
          if (rd.rdata[0]) done = 1;
        end
      end
    join_none
    wait fork;

    // clear it (write 1)
    wr = reg_write_seq::type_id::create("wr_clear");
    wr.addr  = timer_txn::ADDR_STATUS;
    wr.wdata = 32'h1;
    wr.start(m_sequencer);

    // confirm it cleared
    rd = reg_read_seq::type_id::create("rd_confirm");
    rd.addr = timer_txn::ADDR_STATUS;
    rd.start(m_sequencer);
    if (rd.rdata[0])
      `uvm_error(get_type_name(), "STATUS.INTR did not clear after write-1")
  endtask
endclass


class w1c_negative_seq extends uvm_sequence #(timer_txn);
  `uvm_object_utils(w1c_negative_seq)
  rand bit [31:0] load_val;
  constraint c_reasonable_load { load_val inside {[10:50]}; }

  function new(string name = "w1c_negative_seq");
    super.new(name);
  endfunction

  task body();
    reg_write_seq wr;
    reg_read_seq  rd;

    wr = reg_write_seq::type_id::create("wr_load");
    wr.addr  = timer_txn::ADDR_LOAD;
    wr.wdata = load_val;
    wr.start(m_sequencer);

    wr = reg_write_seq::type_id::create("wr_ctrl");
    wr.addr  = timer_txn::ADDR_CTRL;
    wr.wdata = 32'b0000_0111; // EN=1 MODE=oneshot IE=1
    wr.start(m_sequencer);

    // wait for INTR to set
    do begin
      rd = reg_read_seq::type_id::create("rd_status");
      rd.addr = timer_txn::ADDR_STATUS;
      rd.start(m_sequencer);
    end while (!rd.rdata[0]);

    // write 0 - must NOT clear
    wr = reg_write_seq::type_id::create("wr_zero");
    wr.addr  = timer_txn::ADDR_STATUS;
    wr.wdata = 32'h0;
    wr.start(m_sequencer);

    rd = reg_read_seq::type_id::create("rd_after_zero_write");
    rd.addr = timer_txn::ADDR_STATUS;
    rd.start(m_sequencer);
    if (!rd.rdata[0])
      `uvm_error(get_type_name(),
        "STATUS.INTR cleared on a write of 0 - W1C semantics violated (BUG7 signature)")

    // now actually clear with write 1, leave the DUT clean for the next sequence
    wr = reg_write_seq::type_id::create("wr_clear");
    wr.addr  = timer_txn::ADDR_STATUS;
    wr.wdata = 32'h1;
    wr.start(m_sequencer);
  endtask
endclass


class periodic_seq extends uvm_sequence #(timer_txn);
  `uvm_object_utils(periodic_seq)
  rand bit [31:0] load_val;
  rand int        num_periods;
  constraint c_reasonable   { load_val inside {[10:60]}; }
  constraint c_periods      { num_periods inside {[2:5]}; }

  function new(string name = "periodic_seq");
    super.new(name);
  endfunction

  task body();
    reg_write_seq wr;
    reg_read_seq  rd;

    wr = reg_write_seq::type_id::create("wr_load");
    wr.addr  = timer_txn::ADDR_LOAD;
    wr.wdata = load_val;
    wr.start(m_sequencer);

    wr = reg_write_seq::type_id::create("wr_ctrl");
    wr.addr  = timer_txn::ADDR_CTRL;
    wr.wdata = 32'b0000_0101; // EN=1 MODE=periodic(0) IE=1  -> bit1=0
    wr.start(m_sequencer);

    for (int i = 0; i < num_periods; i++) begin
      do begin
        rd = reg_read_seq::type_id::create("rd_status");
        rd.addr = timer_txn::ADDR_STATUS;
        rd.start(m_sequencer);
      end while (!rd.rdata[0]);

      wr = reg_write_seq::type_id::create("wr_clear");
      wr.addr  = timer_txn::ADDR_STATUS;
      wr.wdata = 32'h1;
      wr.start(m_sequencer);
    end

    // stop the timer so it doesn't keep firing under the next sequence
    wr = reg_write_seq::type_id::create("wr_ctrl_off");
    wr.addr  = timer_txn::ADDR_CTRL;
    wr.wdata = 32'h0;
    wr.start(m_sequencer);
  endtask
endclass


// Top-level sequence that chains all of the directed sequences above into
// one run: register readback sanity, one-shot timing + W1C positive check,
// W1C negative check, then a periodic burst. This is what timer_test.sv
// starts on the sequencer.
class timer_smoke_seq extends uvm_sequence #(timer_txn);
  `uvm_object_utils(timer_smoke_seq)

  function new(string name = "timer_smoke_seq");
    super.new(name);
  endfunction

  task body();
    reg_readback_seq   rb;
    oneshot_seq         os;
    w1c_negative_seq    w1c;
    periodic_seq         per;

    rb = reg_readback_seq::type_id::create("rb"); rb.start(m_sequencer);

    os = oneshot_seq::type_id::create("os");
    if (!os.randomize()) `uvm_error(get_type_name(), "randomize failed");
    os.start(m_sequencer);

    w1c = w1c_negative_seq::type_id::create("w1c");
    if (!w1c.randomize()) `uvm_error(get_type_name(), "randomize failed");
    w1c.start(m_sequencer);

    per = periodic_seq::type_id::create("per");
    if (!per.randomize()) `uvm_error(get_type_name(), "randomize failed");
    per.start(m_sequencer);
  endtask
endclass
