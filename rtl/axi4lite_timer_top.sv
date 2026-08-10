`include "bug_defines.svh"
//=============================================================================
// axi4lite_timer_top.sv
//
// Top-level programmable timer peripheral with AXI4-Lite slave port and a
// level interrupt output. Two independent, asynchronous clocks:
//   s_axi_aclk : AXI bus clock
//   timer_clk  : timer counting clock
//=============================================================================

module axi4lite_timer_top #(
  parameter int ADDR_WIDTH = 4,
  parameter int DATA_WIDTH = 32
) (
  // AXI domain
  input  logic                    s_axi_aclk,
  input  logic                    s_axi_aresetn,

  input  logic [ADDR_WIDTH-1:0]   s_axi_awaddr,
  input  logic                    s_axi_awvalid,
  output logic                    s_axi_awready,

  input  logic [DATA_WIDTH-1:0]   s_axi_wdata,
  input  logic [DATA_WIDTH/8-1:0] s_axi_wstrb,
  input  logic                    s_axi_wvalid,
  output logic                    s_axi_wready,

  output logic [1:0]              s_axi_bresp,
  output logic                    s_axi_bvalid,
  input  logic                    s_axi_bready,

  input  logic [ADDR_WIDTH-1:0]   s_axi_araddr,
  input  logic                    s_axi_arvalid,
  output logic                    s_axi_arready,

  output logic [DATA_WIDTH-1:0]   s_axi_rdata,
  output logic [1:0]              s_axi_rresp,
  output logic                    s_axi_rvalid,
  input  logic                    s_axi_rready,

  output logic                    irq,          // level interrupt = STATUS.INTR & CTRL.IE

  // timer domain
  input  logic                    timer_clk,
  input  logic                    timer_rst_n
);

  // config bundle, AXI domain -> timer domain
  logic                  cfg_update_pulse_axi;
  logic                  cfg_en, cfg_mode, cfg_ie;
  logic [DATA_WIDTH-1:0] cfg_load;
  logic                  intr_status;

  logic                  cfg_update_pulse_tclk;
  logic                  cfg_en_tclk, cfg_mode_tclk;
  logic [DATA_WIDTH-1:0] cfg_load_tclk;

  // count / irq, timer domain -> AXI domain
  logic [DATA_WIDTH-1:0] count_tclk;
  logic [DATA_WIDTH-1:0] count_sync_axi;
  logic                  irq_pulse_tclk;
  logic                  irq_pulse_sync_axi;

  assign irq = intr_status && cfg_ie;

  //--------------------------------------------------------------------------
  // Register bank (AXI domain)
  //--------------------------------------------------------------------------
  register_bank #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) u_regs (
    .s_axi_aclk       (s_axi_aclk),
    .s_axi_aresetn    (s_axi_aresetn),
    .s_axi_awaddr     (s_axi_awaddr),
    .s_axi_awvalid    (s_axi_awvalid),
    .s_axi_awready    (s_axi_awready),
    .s_axi_wdata      (s_axi_wdata),
    .s_axi_wstrb      (s_axi_wstrb),
    .s_axi_wvalid     (s_axi_wvalid),
    .s_axi_wready     (s_axi_wready),
    .s_axi_bresp      (s_axi_bresp),
    .s_axi_bvalid     (s_axi_bvalid),
    .s_axi_bready     (s_axi_bready),
    .s_axi_araddr     (s_axi_araddr),
    .s_axi_arvalid    (s_axi_arvalid),
    .s_axi_arready    (s_axi_arready),
    .s_axi_rdata      (s_axi_rdata),
    .s_axi_rresp      (s_axi_rresp),
    .s_axi_rvalid     (s_axi_rvalid),
    .s_axi_rready     (s_axi_rready),
    .cfg_update_pulse (cfg_update_pulse_axi),
    .cfg_en           (cfg_en),
    .cfg_mode         (cfg_mode),
    .cfg_ie           (cfg_ie),
    .cfg_load         (cfg_load),
    .count_sync       (count_sync_axi),
    .irq_pulse_sync   (irq_pulse_sync_axi),
    .intr_status      (intr_status)
  );

  //--------------------------------------------------------------------------
  // CDC: AXI domain -> timer domain (config bundle, atomic via toggle sync)
  //--------------------------------------------------------------------------
  toggle_sync u_cfg_sync (
    .src_clk   (s_axi_aclk),
    .src_rst_n (s_axi_aresetn),
    .pulse_in  (cfg_update_pulse_axi),
    .dst_clk   (timer_clk),
    .dst_rst_n (timer_rst_n),
    .pulse_out (cfg_update_pulse_tclk)
  );

  // cfg_en/cfg_mode/cfg_load are only sampled by timer_core on
  // cfg_update_pulse_tclk, and register_bank holds them stable from the
  // moment cfg_update_pulse_axi fires until well past when the toggle has
  // propagated (it never changes them again until the next write), so a
  // plain 2FF level sync on each is safe here.
  sync2ff #(.WIDTH(1)) u_en_sync (
    .clk(timer_clk), .rst_n(timer_rst_n), .d_async(cfg_en), .q_sync(cfg_en_tclk));
  sync2ff #(.WIDTH(1)) u_mode_sync (
    .clk(timer_clk), .rst_n(timer_rst_n), .d_async(cfg_mode), .q_sync(cfg_mode_tclk));
  sync2ff #(.WIDTH(DATA_WIDTH)) u_load_sync (
    .clk(timer_clk), .rst_n(timer_rst_n), .d_async(cfg_load), .q_sync(cfg_load_tclk));

  //--------------------------------------------------------------------------
  // Timer core (timer_clk domain)
  //--------------------------------------------------------------------------
  timer_core #(.WIDTH(DATA_WIDTH)) u_timer (
    .timer_clk        (timer_clk),
    .timer_rst_n      (timer_rst_n),
    .cfg_update_pulse (cfg_update_pulse_tclk),
    .cfg_en           (cfg_en_tclk),
    .cfg_mode         (cfg_mode_tclk),
    .cfg_load         (cfg_load_tclk),
    .count_q          (count_tclk),
    .irq_pulse        (irq_pulse_tclk)
  );

  //--------------------------------------------------------------------------
  // CDC: timer domain -> AXI domain (live count via Gray sync, irq via toggle sync)
  //--------------------------------------------------------------------------
  gray_ctr_sync #(.WIDTH(DATA_WIDTH)) u_count_sync (
    .src_clk       (timer_clk),
    .src_rst_n     (timer_rst_n),
    .bin_in        (count_tclk),
    .dst_clk       (s_axi_aclk),
    .dst_rst_n     (s_axi_aresetn),
    .bin_out_sync  (count_sync_axi)
  );

  toggle_sync u_irq_sync (
    .src_clk   (timer_clk),
    .src_rst_n (timer_rst_n),
    .pulse_in  (irq_pulse_tclk),
    .dst_clk   (s_axi_aclk),
    .dst_rst_n (s_axi_aresetn),
    .pulse_out (irq_pulse_sync_axi)
  );

endmodule
