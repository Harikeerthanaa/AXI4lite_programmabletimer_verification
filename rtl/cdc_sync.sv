`include "bug_defines.svh"
//=============================================================================
// cdc_sync.sv
//
// Three reusable CDC primitives crossing the AXI clock domain (s_axi_aclk)
// and the timer clock domain (timer_clk), which are asynchronous to each
// other.
//
//   sync2ff        - generic 2-flop synchronizer for a control bit / bus
//   gray_ctr_sync  - multi-bit binary counter synchronized via Gray code
//                    (only one bit ever toggles per source clock, so a 2FF
//                    sync can never sample a torn/bogus value)
//   toggle_sync    - single-event pulse synchronizer: source domain toggles
//                    a flop instead of pulsing it (a pulse can be swallowed
//                    by a slower destination clock; a toggle cannot);
//                    destination domain 2FF-syncs the toggle and
//                    edge-detects it back into a one-cycle pulse
//=============================================================================

module sync2ff #(
  parameter int WIDTH = 1
) (
  input  logic             clk,
  input  logic             rst_n,
  input  logic [WIDTH-1:0] d_async,
  output logic [WIDTH-1:0] q_sync
);
`ifdef BUG1_CDC_NO_SYNC
  // BUG1: no synchronizer at all - straight combinational passthrough of an
  // asynchronous signal into a synchronous domain. A CDC tool must flag this
  // as an unsynchronized crossing. A logic simulator, which does not model
  // metastability, will very likely show NO functional difference on most
  // seeds - that gap is exactly what this experiment measures.
  assign q_sync = d_async;
`elsif BUG2_CDC_SINGLE_FF
  // BUG2: only one flop of synchronization instead of two, reducing the
  // resynchronization time available for a metastable value to resolve.
  // A CDC tool flags "insufficient synchronizer depth"; simulation is blind
  // to it for the same reason as BUG1.
  logic [WIDTH-1:0] ff1;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) ff1 <= '0;
    else        ff1 <= d_async;
  end
  assign q_sync = ff1;
`else
  logic [WIDTH-1:0] ff1, ff2;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ff1 <= '0;
      ff2 <= '0;
    end else begin
      ff1 <= d_async;
      ff2 <= ff1;
    end
  end
  assign q_sync = ff2;
`endif
endmodule


module gray_ctr_sync #(
  parameter int WIDTH = 32
) (
  input  logic             src_clk,
  input  logic             src_rst_n,
  input  logic [WIDTH-1:0] bin_in,
  input  logic             dst_clk,
  input  logic             dst_rst_n,
  output logic [WIDTH-1:0] bin_out_sync
);

  // source domain: binary -> gray
  logic [WIDTH-1:0] gray_src;
  always_comb gray_src = bin_in ^ (bin_in >> 1);

  logic [WIDTH-1:0] gray_src_r;
  always_ff @(posedge src_clk or negedge src_rst_n) begin
    if (!src_rst_n) gray_src_r <= '0;
    else            gray_src_r <= gray_src;
  end

  // CDC: gray value only ever changes one bit per src_clk edge
  logic [WIDTH-1:0] gray_dst_sync;
  sync2ff #(.WIDTH(WIDTH)) u_gray_sync (
    .clk     (dst_clk),
    .rst_n   (dst_rst_n),
    .d_async (gray_src_r),
    .q_sync  (gray_dst_sync)
  );

  // destination domain: gray -> binary
  always_comb begin
    bin_out_sync[WIDTH-1] = gray_dst_sync[WIDTH-1];
    for (int i = WIDTH-2; i >= 0; i--) begin
      bin_out_sync[i] = gray_dst_sync[i] ^ bin_out_sync[i+1];
    end
  end

endmodule


module toggle_sync (
  input  logic src_clk,
  input  logic src_rst_n,
  input  logic pulse_in,
  input  logic dst_clk,
  input  logic dst_rst_n,
  output logic pulse_out
);

  logic toggle_src;
  always_ff @(posedge src_clk or negedge src_rst_n) begin
    if (!src_rst_n) toggle_src <= 1'b0;
    else if (pulse_in) toggle_src <= ~toggle_src;
  end

  logic toggle_dst_sync;
  sync2ff #(.WIDTH(1)) u_toggle_sync (
    .clk     (dst_clk),
    .rst_n   (dst_rst_n),
    .d_async (toggle_src),
    .q_sync  (toggle_dst_sync)
  );

  logic toggle_dst_sync_d;
  always_ff @(posedge dst_clk or negedge dst_rst_n) begin
    if (!dst_rst_n) toggle_dst_sync_d <= 1'b0;
    else            toggle_dst_sync_d <= toggle_dst_sync;
  end

  assign pulse_out = toggle_dst_sync ^ toggle_dst_sync_d;

endmodule
