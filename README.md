# RISC-V Single-Cycle Processor — Vivado / Verilog

A single-cycle RISC-V CPU built incrementally across Computer Architecture labs 5–7. Implemented in Verilog using Xilinx Vivado targeted at an FPGA dev board, with on-board seven-segment display and switch I/O wiring.

## Datapath modules
- **ALU** (`alu.v`, `ALU_Wrapper.v`) — arithmetic + logic ops, branch comparisons
- **Register file** (`RegisterFile.v`) — 32-register file, synchronous write / asynchronous read
- **FSM controller** (`fsm_counter.v`) — orchestrates lab demonstrations
- **Onehot decoder** (`onehot_decoder.v`) — switch-encoded instruction selection
- **Seven-segment display** (`seven_segment.v`) — hex-to-7seg with multiplexed output
- **Debouncer + clock divider** (`debouncer.v`, `clock_divider.v`) — board housekeeping

## Top-level
`top_rf_alu.v` wires the ALU and register file together with switch and 7-seg I/O for the lab 5/6 demo. Constraints in `CAlab5.srcs/constrs_1/new/*.xdc` map signals to the dev board.

## Testbenches
`CAlab5.srcs/sim_1/new/` contains testbenches for the ALU, register file, and the integrated `top_rf_alu` design, runnable via Vivado xsim.

## Repo layout
```
CAlab5+6+7/CAlab5+6+7/CAlab5/        # Vivado project
├── CAlab5.xpr                       # Vivado project file (open this)
├── CAlab5.srcs/sources_1/new/       # synthesizable Verilog
├── CAlab5.srcs/sim_1/new/           # testbenches
├── CAlab5.srcs/constrs_1/new/       # board constraints (.xdc)
└── ...                              # generated build artifacts (ignored)
RISCV_Lab_Report_ABC (1).pdf         # write-up
project_1/                           # earlier scratch project
```

## Open in Vivado
1. Launch Vivado 2020.x+ (the project was generated with the Vivado 2020 series).
2. **File → Open Project…** → select `CAlab5+6+7/CAlab5+6+7/CAlab5/CAlab5.xpr`.
3. To simulate: pick a `*_tb.v` source in the Sources panel → **Run Simulation → Behavioral Simulation**.
4. To synthesize/implement: **Run Synthesis → Run Implementation → Generate Bitstream**.

## Tech stack
Verilog · Xilinx Vivado · RISC-V ISA (subset)

## License
MIT — see [LICENSE](LICENSE).
