`ifndef BUG_DEFINES_SVH
`define BUG_DEFINES_SVH
//=============================================================================
// bug_defines.svh
//
// One `define per injected bug. Uncomment EXACTLY ONE at a time (comment the
// rest out) before a run. Never enable more than one simultaneously - the
// whole point of the experiment is isolating one root cause per run so a
// detection (or miss) can be attributed to a single bug.
//
// Detection-category hypothesis (this is what your experiment should
// confirm or refute with real data, not assume):
//
//   BUG1_CDC_NO_SYNC          -> expected: caught by CDC tool, missed by UVM
//   BUG2_CDC_SINGLE_FF        -> expected: caught by CDC tool, missed by UVM
//   BUG3_LINT_WIDTH_MISMATCH  -> expected: caught by lint, UVM may or may not
//   BUG4_LINT_INFERRED_LATCH  -> expected: caught by lint, UVM likely misses
//   BUG5_LINT_MULTIDRIVEN     -> expected: caught by lint (or refuses to
//                                 compile), UVM may miss it entirely
//   BUG6_FUNC_OFFBYONE        -> expected: caught by UVM scoreboard, invisible
//                                 to lint/CDC (pure sequential/arithmetic bug)
//   BUG7_FUNC_W1C_BROKEN      -> expected: caught by UVM scoreboard, invisible
//                                 to lint/CDC
//=============================================================================

// `define BUG1_CDC_NO_SYNC
// `define BUG2_CDC_SINGLE_FF
// `define BUG3_LINT_WIDTH_MISMATCH
// `define BUG4_LINT_INFERRED_LATCH
// `define BUG5_LINT_MULTIDRIVEN
// `define BUG6_FUNC_OFFBYONE
// `define BUG7_FUNC_W1C_BROKEN

`endif
