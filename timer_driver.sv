//=============================================================================
// timer_driver.sv
//=============================================================================
class timer_driver extends uvm_driver #(timer_txn);
  `uvm_component_utils(timer_driver)

  virtual timer_if.DRV vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual timer_if.DRV)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "virtual interface not set for driver")
  endfunction

  task run_phase(uvm_phase phase);
    reset_bus();
    forever begin
      timer_txn t;
      seq_item_port.get_next_item(t);
      if (t.op == timer_txn::OP_WRITE) drive_write(t);
      else                             drive_read(t);
      seq_item_port.item_done();
    end
  endtask

  task reset_bus();
    vif.drv_cb.awvalid <= 0;
    vif.drv_cb.wvalid  <= 0;
    vif.drv_cb.bready  <= 0;
    vif.drv_cb.arvalid <= 0;
    vif.drv_cb.rready  <= 0;
  endtask

  task drive_write(timer_txn t);
    @(vif.drv_cb);
    vif.drv_cb.awaddr  <= t.addr;
    vif.drv_cb.awvalid <= 1;
    vif.drv_cb.wdata   <= t.wdata;
    vif.drv_cb.wstrb   <= t.wstrb;
    vif.drv_cb.wvalid  <= 1;
    vif.drv_cb.bready  <= 1;

    do @(vif.drv_cb); while (!vif.drv_cb.awready);
    vif.drv_cb.awvalid <= 0;

    do @(vif.drv_cb); while (!vif.drv_cb.wready);
    vif.drv_cb.wvalid <= 0;

    do @(vif.drv_cb); while (!vif.drv_cb.bvalid);
    t.resp = vif.drv_cb.bresp;
    @(vif.drv_cb);
    vif.drv_cb.bready <= 0;
  endtask

  task drive_read(timer_txn t);
    @(vif.drv_cb);
    vif.drv_cb.araddr  <= t.addr;
    vif.drv_cb.arvalid <= 1;
    vif.drv_cb.rready  <= 1;

    do @(vif.drv_cb); while (!vif.drv_cb.arready);
    vif.drv_cb.arvalid <= 0;

    do @(vif.drv_cb); while (!vif.drv_cb.rvalid);
    t.rdata = vif.drv_cb.rdata;
    t.resp  = vif.drv_cb.rresp;
    @(vif.drv_cb);
    vif.drv_cb.rready <= 0;
  endtask

endclass
