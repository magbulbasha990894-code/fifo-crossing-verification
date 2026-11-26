# FIFO Crossing Verification

A synthesizable dual-clock Verilog FIFO with a self-checking SystemVerilog simulation. The write clock and read clock are independent. Each domain synchronizes only the remote Gray pointer; data stays in a dual-port memory until a locally accepted transfer can read it.

## Run

With Icarus Verilog (`iverilog` and `vvp`) and Python 3.10+:

```sh
python run_test.py
```

CI runs the same entry point. For the simulator-free exploration of all reachable digital pointer and flag states at depths 4 and 8, run `python check_model.py`. This independent Python model covers noncoincident clock interleavings; it does not validate RTL compilation or payload data. The simulation tests depths 4 and 16. It initially fills the FIFO, then applies reproducible read and write stalls over 300 transfers per depth and drains it. An independent scoreboard checks order and data, prevents silent over/underflow, checks data stability while the reader stalls, and fails if full or empty behavior was never exercised.

## Interface

A transfer happens when both valid and ready are high at the rising edge of the corresponding clock. `w_valid` and `w_data` must be held while the writer is stalled. `r_data` is meaningful only while `r_valid` is high. The read is first-word fall-through; memory inference on a target device may use distributed rather than block RAM. Depth is `2**ADDR_BITS` with `ADDR_BITS >= 2`. `DATA_WIDTH` must be positive.

The local pointer has an extra wrap bit. Equal Gray pointers mean empty; full is recognized by comparing the next Gray write pointer with the synchronized read pointer with its two high bits inverted. Registered flags may deassert late after a remote transfer, which sacrifices availability, not safety.

## Integration limitations

- Apply a coordinated reset to both domains before use or after a fault. Release each reset synchronously to its respective clock externally. There is no protocol for resetting one active side independently.
- Digital simulation cannot measure metastability, physical timing or mean time between failure. In hardware, check synchronizer recognition, clock-domain crossings, and pointer bus skew constraints relative to the source-clock period. Validate the memory implementation and reset tree with target-specific tools.
- This project supplies bounded simulation, not a formal proof or implementation sign-off. The scoreboard intentionally samples write and read at noncoincident edges; that is a test design choice, not a FIFO protocol requirement.
