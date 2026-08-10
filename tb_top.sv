//=============================================================================
// tb_top.sv
//
// AXI clock: 7ns period (~142.8 MHz)   -- deliberately NOT an integer
// multiple of the timer clock, so the two domains are genuinely and
// persistently out of phase, which is what actually exercises the CDC paths
// (and is exactly what BUG1/BUG2 rely on to ever have a chance of showing up
// even under simulation).
// Timer clock: 10ns period (100 MHz)
//=============================================================================
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import timer_pkg::*;

module tb_top;

  logic s_axi_aclk = 0;
  logic timer_clk   = 0;

  always #3.5 s_axi_aclk = ~s_axi_aclk; // 7ns period
  always #5.0 timer_clk  = ~timer_clk;  // 10ns period

  timer_if #(.ADDR_WIDTH(4), .DATA_WIDTH(32)) vif (
    .s_axi_aclk (s_axi_aclk),
    .timer_clk  (timer_clk)
  );

  axi4lite_timer_top #(
    .ADDR_WIDTH(4),
    .DATA_WIDTH(32)
  ) dut (
    .s_axi_aclk    (s_axi_aclk),
    .s_axi_aresetn (vif.s_axi_aresetn),
    .s_axi_awaddr  (vif.awaddr),
    .s_axi_awvalid (vif.awvalid),
    .s_axi_awready (vif.awready),
    .s_axi_wdata   (vif.wdata),
    .s_axi_wstrb   (vif.wstrb),
    .s_axi_wvalid  (vif.wvalid),
    .s_axi_wready  (vif.wready),
    .s_axi_bresp   (vif.bresp),
    .s_axi_bvalid  (vif.bvalid),
    .s_axi_bready  (vif.bready),
    .s_axi_araddr  (vif.araddr),
    .s_axi_arvalid (vif.arvalid),
    .s_axi_arready (vif.arready),
    .s_axi_rdata   (vif.rdata),
    .s_axi_rresp   (vif.rresp),
    .s_axi_rvalid  (vif.rvalid),
    .s_axi_rready  (vif.rready),
    .irq           (vif.irq),
    .timer_clk     (timer_clk),
    .timer_rst_n   (vif.timer_rst_n)
  );

  initial begin
    uvm_config_db#(virtual timer_if.DRV)::set(null, "*", "vif", vif);
    uvm_config_db#(virtual timer_if.MON)::set(null, "*", "vif", vif);
    run_test();
  end

  // waveform dump for debug
  initial begin
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
  end
  initial begin
    $fsdbDumpfile("tb_top.fsdb");
    $fsdbDumpvars(0, tb_top, "+all");
  end
  // global safety timeout
  initial begin
    #100000;
    `uvm_fatal("TB_TOP", "global timeout - a sequence likely hung waiting on an interrupt")
  end

endmodule
