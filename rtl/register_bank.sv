`include "bug_defines.svh"
//=============================================================================
// register_bank.sv
//
// Address map (word-aligned, addr[3:2] selects the register):
//   0x0  CTRL    [0]=EN  [1]=MODE(0=periodic,1=oneshot)  [2]=IE   RW
//   0x4  LOAD    [31:0] reload value                               RW
//   0x8  COUNT   [31:0] live count, synchronized from timer domain RO
//   0xC  STATUS  [0]=INTR (sticky, write-1-to-clear)                W1C on write
//
// Implements the AXI4-Lite write and read channel handshakes. Every write to
// CTRL or LOAD raises cfg_update_pulse for exactly one s_axi_aclk cycle,
// which the top level toggle-syncs into the timer domain as one atomic bundle.
//=============================================================================

module register_bank #(
  parameter int ADDR_WIDTH = 4,
  parameter int DATA_WIDTH = 32
) (
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

  output logic                    cfg_update_pulse,
  output logic                    cfg_en,
  output logic                    cfg_mode,
  output logic                    cfg_ie,
  output logic [DATA_WIDTH-1:0]   cfg_load,

  input  logic [DATA_WIDTH-1:0]   count_sync,
  input  logic                    irq_pulse_sync,

  output logic                    intr_status    // sticky INTR bit, exported for irq level gen
);

  localparam logic [1:0] AXI_OKAY = 2'b00;

  //--------------------------------------------------------------------------
  // Address decode (rd_sel is declared here, but assigned further down once
  // araddr_q exists - see the comment right above the Read data mux)
  //--------------------------------------------------------------------------
  logic [1:0] rd_sel;

  localparam logic [1:0] SEL_CTRL   = 2'b00;
  localparam logic [1:0] SEL_LOAD   = 2'b01;
  localparam logic [1:0] SEL_COUNT  = 2'b10;
  localparam logic [1:0] SEL_STATUS = 2'b11;

  //--------------------------------------------------------------------------
  // Registers
  //--------------------------------------------------------------------------
  logic                  ctrl_en_q, ctrl_mode_q, ctrl_ie_q;
  logic [DATA_WIDTH-1:0] load_q;
  logic                  intr_status_q;

  assign cfg_en      = ctrl_en_q;
  assign cfg_mode    = ctrl_mode_q;
  assign cfg_ie      = ctrl_ie_q;
  assign cfg_load    = load_q;
  assign intr_status = intr_status_q;

  //--------------------------------------------------------------------------
  // Write FSM
  //--------------------------------------------------------------------------
  typedef enum logic [1:0] {W_IDLE, W_DATA, W_RESP} wr_state_t;
  wr_state_t wr_state;

  logic [ADDR_WIDTH-1:0] awaddr_q;
  logic                  do_write;

  always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
    if (!s_axi_aresetn) begin
      wr_state      <= W_IDLE;
      s_axi_awready <= 1'b0;
      s_axi_wready  <= 1'b0;
      s_axi_bvalid  <= 1'b0;
      s_axi_bresp   <= AXI_OKAY;
      awaddr_q      <= '0;
      do_write      <= 1'b0;
    end else begin
      do_write <= 1'b0;
      case (wr_state)
        W_IDLE: begin
          s_axi_bvalid <= 1'b0;
          if (s_axi_awvalid) begin
            s_axi_awready <= 1'b1;
            awaddr_q      <= s_axi_awaddr;
            wr_state      <= W_DATA;
          end else begin
            s_axi_awready <= 1'b0;
          end
        end
        W_DATA: begin
          s_axi_awready <= 1'b0;
          if (s_axi_wvalid) begin
            s_axi_wready <= 1'b1;
            do_write     <= 1'b1;
            wr_state     <= W_RESP;
          end
        end
        W_RESP: begin
          s_axi_wready <= 1'b0;
          s_axi_bvalid <= 1'b1;
          s_axi_bresp  <= AXI_OKAY;
          if (s_axi_bready) wr_state <= W_IDLE;
        end
        default: wr_state <= W_IDLE;
      endcase
    end
  end

  //--------------------------------------------------------------------------
  // Register writes + config-update pulse generation
  //--------------------------------------------------------------------------
  logic wr_sel_is_ctrl_or_load;
  assign wr_sel_is_ctrl_or_load = do_write &&
         ((awaddr_q[3:2] == SEL_CTRL) || (awaddr_q[3:2] == SEL_LOAD));

  always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
    if (!s_axi_aresetn) begin
      ctrl_en_q        <= 1'b0;
      ctrl_mode_q      <= 1'b0;
      ctrl_ie_q        <= 1'b0;
      load_q           <= '0;
      cfg_update_pulse <= 1'b0;
    end else begin
      cfg_update_pulse <= 1'b0;
      if (do_write) begin
        case (awaddr_q[3:2])
          SEL_CTRL: begin
            if (s_axi_wstrb[0]) begin
              ctrl_en_q   <= s_axi_wdata[0];
              ctrl_mode_q <= s_axi_wdata[1];
              ctrl_ie_q   <= s_axi_wdata[2];
            end
          end
          SEL_LOAD: begin
            if (s_axi_wstrb[0]) load_q[7:0]   <= s_axi_wdata[7:0];
            if (s_axi_wstrb[1]) load_q[15:8]  <= s_axi_wdata[15:8];
            if (s_axi_wstrb[2]) load_q[23:16] <= s_axi_wdata[23:16];
            if (s_axi_wstrb[3]) load_q[31:24] <= s_axi_wdata[31:24];
          end
          default: ; // STATUS write handled separately below
        endcase
        if (wr_sel_is_ctrl_or_load) cfg_update_pulse <= 1'b1;
      end
    end
  end

  //--------------------------------------------------------------------------
  // STATUS.INTR : sticky flag set by the synchronized irq pulse from the
  // timer domain, write-1-to-clear from the AXI domain.
  //--------------------------------------------------------------------------
`ifndef BUG5_LINT_MULTIDRIVEN
  logic status_write_clear;
  assign status_write_clear = do_write && (awaddr_q[3:2] == SEL_STATUS) &&
                               s_axi_wstrb[0]
`ifndef BUG7_FUNC_W1C_BROKEN
                               && s_axi_wdata[0];
`else
                               ;
  // BUG7: the write-1-to-clear qualifier (`&& s_axi_wdata[0]`) is dropped, so
  // ANY write to STATUS clears INTR, including a write of 0. Purely a
  // functional/behavioral error - the RTL is perfectly well-formed (single
  // driver, full widths, both clock domains correctly synchronized), so
  // lint and CDC tools have nothing to flag. Only a scoreboard that checks
  // "write 0 to STATUS must NOT clear INTR" catches it.
`endif

  always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
    if (!s_axi_aresetn)                intr_status_q <= 1'b0;
    else if (status_write_clear)       intr_status_q <= 1'b0;
    else if (irq_pulse_sync)           intr_status_q <= 1'b1;
  end
`else
  // BUG5: two separate always_ff blocks both drive intr_status_q. Some
  // simulators/lint tools refuse this outright (multiply-driven signal);
  // others let the last procedural block "win" per their event-ordering
  // rules - exactly the trap, since the design can look functionally fine
  // in simulation purely by luck of block ordering, while VC Static's
  // structural checker flags the multi-driver violation unconditionally,
  // independent of any particular test's stimulus.
  logic status_write_clear;
  assign status_write_clear = do_write && (awaddr_q[3:2] == SEL_STATUS) &&
                               s_axi_wstrb[0] && s_axi_wdata[0];

  always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
    if (!s_axi_aresetn)            intr_status_q <= 1'b0;
    else if (status_write_clear)   intr_status_q <= 1'b0;
  end

  always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
    if (!s_axi_aresetn)            intr_status_q <= 1'b0;
    else if (irq_pulse_sync)       intr_status_q <= 1'b1;
  end
`endif

  //--------------------------------------------------------------------------
  // Read FSM
  //--------------------------------------------------------------------------
  typedef enum logic [0:0] {R_IDLE, R_DATA} rd_state_t;
  rd_state_t rd_state;
  logic [ADDR_WIDTH-1:0] araddr_q;

  always_ff @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
    if (!s_axi_aresetn) begin
      rd_state      <= R_IDLE;
      s_axi_arready <= 1'b0;
      s_axi_rvalid  <= 1'b0;
      s_axi_rresp   <= AXI_OKAY;
      araddr_q      <= '0;
    end else begin
      case (rd_state)
        R_IDLE: begin
          s_axi_rvalid <= 1'b0;
          if (s_axi_arvalid) begin
            s_axi_arready <= 1'b1;
            araddr_q      <= s_axi_araddr;
            rd_state      <= R_DATA;
          end else begin
            s_axi_arready <= 1'b0;
          end
        end
        R_DATA: begin
          s_axi_arready <= 1'b0;
          s_axi_rvalid  <= 1'b1;
          s_axi_rresp   <= AXI_OKAY;
          if (s_axi_rvalid && s_axi_rready) begin
            s_axi_rvalid <= 1'b0;
            rd_state     <= R_IDLE;
          end
        end
        default: rd_state <= R_IDLE;
      endcase
    end
  end

  //--------------------------------------------------------------------------
  // rd_sel assignment - deferred to here because it depends on araddr_q,
  // declared just above in the Read FSM block.
  //--------------------------------------------------------------------------
`ifndef BUG3_LINT_WIDTH_MISMATCH
  assign rd_sel = araddr_q[3:2];
`else
  // BUG3: destination is 2 bits wide but the RHS slice is 3 bits wide - the
  // top bit is silently truncated, a classic width-mismatch lint violation.
  // Functionally invisible as long as araddr[4] is always 0 (true for this
  // small address map), which is exactly why it can sail through directed
  // functional tests untouched.
  assign rd_sel = araddr_q[4:2];
`endif

  //--------------------------------------------------------------------------
  // Read data mux
  //--------------------------------------------------------------------------
`ifndef BUG4_LINT_INFERRED_LATCH
  always_comb begin
    unique case (rd_sel)
      SEL_CTRL:   s_axi_rdata = {{(DATA_WIDTH-3){1'b0}}, ctrl_ie_q, ctrl_mode_q, ctrl_en_q};
      SEL_LOAD:   s_axi_rdata = load_q;
      SEL_COUNT:  s_axi_rdata = count_sync;
      SEL_STATUS: s_axi_rdata = {{(DATA_WIDTH-1){1'b0}}, intr_status_q};
      default:    s_axi_rdata = '0;
    endcase
  end
`else
  // BUG4: no default branch, plain `case` (not `unique case`), inside an
  // always_comb driving s_axi_rdata. Because SEL_* covers all 4 values of a
  // 2-bit selector this happens to be functionally full in THIS design -
  // exactly why it is a good lint bug: simulation never exercises a
  // "missing" branch (there isn't one reachable), so nothing ever
  // mismatches functionally, yet the lint tool still flags the
  // inferred-latch pattern structurally because it cannot prove case
  // completeness the way `unique case` can.
  always_comb begin
    case (rd_sel)
      SEL_CTRL:   s_axi_rdata = {{(DATA_WIDTH-3){1'b0}}, ctrl_ie_q, ctrl_mode_q, ctrl_en_q};
      SEL_LOAD:   s_axi_rdata = load_q;
      SEL_COUNT:  s_axi_rdata = count_sync;
      SEL_STATUS: s_axi_rdata = {{(DATA_WIDTH-1){1'b0}}, intr_status_q};
    endcase
  end
`endif

endmodule
