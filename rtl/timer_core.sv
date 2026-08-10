`include "bug_defines.svh"
//=============================================================================
// timer_core.sv
//
// Lives entirely in the timer_clk domain (asynchronous to s_axi_aclk).
// Receives its configuration (EN, MODE, LOAD) as one atomic bundle via a
// toggle-synchronized "config update" pulse from the AXI domain, so EN/MODE
// and the LOAD value are never sampled half-updated.
//
// MODE = 0 : periodic  - reloads automatically and keeps counting
// MODE = 1 : one-shot  - counts once, asserts irq_pulse, then stops (EN drops)
//=============================================================================

module timer_core #(
  parameter int WIDTH = 32
) (
  input  logic             timer_clk,
  input  logic             timer_rst_n,

  input  logic             cfg_update_pulse,   // one cycle, config below is valid
  input  logic             cfg_en,
  input  logic             cfg_mode,           // 0 = periodic, 1 = one-shot
  input  logic [WIDTH-1:0] cfg_load,

  output logic [WIDTH-1:0] count_q,            // free-running current count
  output logic             irq_pulse           // one-cycle pulse on expiry
);

  logic             en_q;
  logic             mode_q;
  logic [WIDTH-1:0] load_q;

  always_ff @(posedge timer_clk or negedge timer_rst_n) begin
    if (!timer_rst_n) begin
      en_q   <= 1'b0;
      mode_q <= 1'b0;
      load_q <= '0;
    end else if (cfg_update_pulse) begin
      en_q   <= cfg_en;
      mode_q <= cfg_mode;
      load_q <= cfg_load;
    end else if (mode_q && irq_pulse) begin
      en_q <= 1'b0;   // one-shot: auto-disable after expiry
    end
  end

`ifndef BUG6_FUNC_OFFBYONE
  // ---- correct countdown ----
  always_ff @(posedge timer_clk or negedge timer_rst_n) begin
    if (!timer_rst_n) begin
      count_q   <= '0;
      irq_pulse <= 1'b0;
    end else if (cfg_update_pulse) begin
      count_q   <= cfg_load;
      irq_pulse <= 1'b0;
    end else if (en_q) begin
      if (count_q == '0) begin
        irq_pulse <= 1'b1;                      // exactly one cycle at expiry
        count_q   <= mode_q ? count_q : load_q; // one-shot holds at 0, periodic reloads
      end else begin
        count_q   <= count_q - 1'b1;
        irq_pulse <= 1'b0;
      end
    end else begin
      irq_pulse <= 1'b0;
    end
  end
`else
  // ---- BUG6: off-by-one ----
  // The decrement and the zero-check happen against the SAME cycle instead
  // of the check gating the decrement, so irq_pulse fires one cycle early
  // (when count_q==1, not count_q==0). This is a pure sequential/arithmetic
  // error: no width mismatch, no latch, no multi-driven net, and it touches
  // only one already-synchronized clock domain, so neither lint nor CDC
  // checks have any structural basis to flag it. Only a scoreboard that
  // predicts exact expiry timing catches it.
  always_ff @(posedge timer_clk or negedge timer_rst_n) begin
    if (!timer_rst_n) begin
      count_q   <= '0;
      irq_pulse <= 1'b0;
    end else if (cfg_update_pulse) begin
      count_q   <= cfg_load;
      irq_pulse <= 1'b0;
    end else if (en_q) begin
      count_q   <= (count_q == '0) ? load_q : (count_q - 1'b1);
      irq_pulse <= (count_q == 32'h1);          // fires one cycle too early
    end else begin
      irq_pulse <= 1'b0;
    end
  end
`endif

endmodule
