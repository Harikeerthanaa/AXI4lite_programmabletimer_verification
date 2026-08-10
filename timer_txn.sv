//=============================================================================
// timer_txn.sv - one AXI4-Lite register access (read or write)
//=============================================================================
class timer_txn extends uvm_sequence_item;

  typedef enum {OP_READ, OP_WRITE} op_e;

  rand op_e            op;
  rand bit [3:0]       addr;
  rand bit [31:0]      wdata;
  rand bit [3:0]       wstrb;
       bit [31:0]      rdata;   // filled in by the driver/monitor on reads
       bit [1:0]       resp;

  // register address constants for readability in sequences
  localparam bit [3:0] ADDR_CTRL   = 4'h0;
  localparam bit [3:0] ADDR_LOAD   = 4'h4;
  localparam bit [3:0] ADDR_COUNT  = 4'h8;
  localparam bit [3:0] ADDR_STATUS = 4'hC;

  constraint c_addr_aligned { addr[1:0] == 2'b00; }
  constraint c_strb_default { wstrb == 4'hF; }

  `uvm_object_utils_begin(timer_txn)
    `uvm_field_enum(op_e, op, UVM_ALL_ON)
    `uvm_field_int(addr,  UVM_ALL_ON)
    `uvm_field_int(wdata, UVM_ALL_ON)
    `uvm_field_int(wstrb, UVM_ALL_ON)
    `uvm_field_int(rdata, UVM_ALL_ON)
    `uvm_field_int(resp,  UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "timer_txn");
    super.new(name);
  endfunction

  function string convert2str();
    if (op == OP_WRITE)
      return $sformatf("WR addr=0x%0h wdata=0x%08h wstrb=%0b", addr, wdata, wstrb);
    else
      return $sformatf("RD addr=0x%0h -> rdata=0x%08h", addr, rdata);
  endfunction

endclass
