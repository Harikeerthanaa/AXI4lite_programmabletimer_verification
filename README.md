# AXI4-Lite Programmable Timer Verification

## Overview

This project focuses on the functional and structural verification of a
dual-clock AXI4-Lite programmable timer peripheral with a level-sensitive
interrupt output.

The design contains:

- AXI4-Lite slave interface
- Programmable timer
- Periodic and one-shot modes
- Write-1-to-clear interrupt status
- Dual asynchronous clock domains
- CDC synchronization mechanisms

## Verification Methodology

The design was verified using:

- SystemVerilog
- UVM 1.2
- Synopsys VCS
- Synopsys Verdi
- SpyGlass Lint
- SpyGlass CDC

Both dynamic and static verification methods were used.

## DUT Architecture

The design consists of:

- AXI4-Lite register interface
- Register bank
- Timer core
- CDC synchronization logic
- Interrupt generation

## Register Map

| Offset | Register | Access |
|--------|----------|--------|
| 0x00 | CTRL | RW |
| 0x04 | LOAD | RW |
| 0x08 | COUNT | RO |
| 0x0C | STATUS | W1C |

## UVM Environment

The UVM environment contains:

- Agent
- Driver
- Monitor
- Sequencer
- Scoreboard
- Functional coverage
- Virtual interface

### Test Sequences

- Register write
- Register read
- Register readback
- Timer smoke
- Periodic mode
- One-shot mode
- W1C negative testing

## CDC Verification

The design uses:

- Two-flop synchronizers
- Toggle synchronizers
- Gray-code counter synchronization
- Atomic configuration transfer

## Static Verification

SpyGlass was used for:

- RTL lint
- Clock-domain-crossing verification

## Bug Injection Study

Seven bugs were intentionally injected and analyzed individually.

| Bug | Category | Detection |
|-----|----------|-----------|
| BUG1 | CDC | UVM + CDC |
| BUG2 | CDC | UVM + CDC |
| BUG3 | Lint | Lint |
| BUG4 | Lint | Lint |
| BUG5 | Lint | Compiler + Lint |
| BUG6 | Functional | UVM |
| BUG7 | Functional | UVM |

## Results

The clean baseline achieved:

- 16/16 scoreboard checks passed
- 0 UVM errors
- 79.2% register-access coverage
- 93.8% CTRL-field coverage
- 100% STATUS W1C coverage

## Tools

- SystemVerilog
- UVM
- VCS
- Verdi
- SpyGlass
- Linux
- Git
