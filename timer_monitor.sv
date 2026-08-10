//=============================================================================
// timer_monitor.sv
//
// Publishes two kinds of events on ap:
//   - a timer_txn per completed write or read, mirroring what the driver did
//   - a timer_txn with addr==ADDR_STATUS and op==OP_READ whenever it detects
//     a rising edge on irq (used by the scoreboard to time interrupt
//     assertions independently of when the sequence happens to poll STATUS)
//=============================================================================
class timer_monitor extends uvm_monitor;
  `uvm_component_utils(timer_monitor)

  virtual timer_if.MON vif;
  uvm_analysis_port #(timer_txn) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual timer_if.MON)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "virtual interface not set for monitor")
  endfunction

  task run_phase(uvm_phase phase);
    fork
      watch_writes();
      watch_reads();
      watch_irq();
    join
  endtask

  task watch_writes();
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.awvalid && vif.mon_cb.awready) begin
        timer_txn t = timer_txn::type_id::create("mon_wr");
        bit [3:0] addr_cap = vif.mon_cb.awaddr;
        // wait for the matching write-data phase
        do @(vif.mon_cb); while (!(vif.mon_cb.wvalid && vif.mon_cb.wready));
        t.op    = timer_txn::OP_WRITE;
        t.addr  = addr_cap;
        t.wdata = vif.mon_cb.wdata;
        t.wstrb = vif.mon_cb.wstrb;
        ap.write(t);
      end
    end
  endtask

  task watch_reads();
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.arvalid && vif.mon_cb.arready) begin
        timer_txn t = timer_txn::type_id::create("mon_rd");
        bit [3:0] addr_cap = vif.mon_cb.araddr;
        do @(vif.mon_cb); while (!vif.mon_cb.rvalid);
        t.op    = timer_txn::OP_READ;
        t.addr  = addr_cap;
        t.rdata = vif.mon_cb.rdata;
        ap.write(t);
      end
    end
  endtask

  task watch_irq();
    bit irq_d = 0;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.irq && !irq_d) begin
        timer_txn t = timer_txn::type_id::create("mon_irq_edge");
        t.op   = timer_txn::OP_READ;
        t.addr = timer_txn::ADDR_STATUS;
        t.rdata = 32'h1; // synthetic marker: irq rising edge observed
        ap.write(t);
      end
      irq_d = vif.mon_cb.irq;
    end
  endtask

endclass
