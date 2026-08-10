//=============================================================================
// timer_if.sv
// Bundles the AXI4-Lite slave port + irq + the timer_clk domain reset so
// the driver/monitor only need one virtual interface handle.
//=============================================================================
interface timer_if #(
  parameter int ADDR_WIDTH = 4,
  parameter int DATA_WIDTH = 32
) (
  input logic s_axi_aclk,
  input logic timer_clk
);

  logic                    s_axi_aresetn;
  logic [ADDR_WIDTH-1:0]   awaddr;
  logic                    awvalid;
  logic                    awready;
  logic [DATA_WIDTH-1:0]   wdata;
  logic [DATA_WIDTH/8-1:0] wstrb;
  logic                    wvalid;
  logic                    wready;
  logic [1:0]               bresp;
  logic                    bvalid;
  logic                    bready;
  logic [ADDR_WIDTH-1:0]   araddr;
  logic                    arvalid;
  logic                    arready;
  logic [DATA_WIDTH-1:0]   rdata;
  logic [1:0]               rresp;
  logic                    rvalid;
  logic                    rready;
  logic                    irq;
  logic                    timer_rst_n;

  clocking drv_cb @(posedge s_axi_aclk);
    output awaddr, awvalid, wdata, wstrb, wvalid, bready, araddr, arvalid, rready;
    input  awready, wready, bresp, bvalid, arready, rdata, rresp, rvalid, irq;
  endclocking

  clocking mon_cb @(posedge s_axi_aclk);
    input awaddr, awvalid, awready, wdata, wstrb, wvalid, wready,
          bresp, bvalid, bready, araddr, arvalid, arready,
          rdata, rresp, rvalid, rready, irq;
  endclocking

  modport DRV (clocking drv_cb, output s_axi_aresetn, timer_rst_n);
  modport MON (clocking mon_cb, input s_axi_aresetn, timer_rst_n, irq);

endinterface
