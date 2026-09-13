# 5-Stage-Pipelined-Prime-Processor
Verilog HDL implementation of a 5-stage pipelined processor for prime number detection.

## Overview
A Verilog HDL implementation of a 5-stage pipelined processor designed to detect whether a given number is prime. The processor uses Instruction Fetch (IF), Instruction Decode (ID), Execute (EX), Memory (MEM), and Write Back (WB) stages. Implement this same logic on FPGA board.

## Key Features
- 5-stage pipelined processor architecture
- Prime number detection using modulus operation
- Program Counter, Instruction Memory, Register File and ALU
- Pipeline registers for instruction flow
- Verilog HDL implementation
- Simulation and waveform verification using Cadence tools

## Tools & Technologies
- Verilog HDL
- Cadence NCLaunch / Xcelium
- SimVision
- FPGA Hardware output

## Working
Input Number → Instruction Execution → Modulus Operation → Prime Check → Prime/Not Prime

## Results
The processor was successfully designed and simulated. Waveforms verified the operation of the pipeline, program counter, pipeline registers, register file, and ALU.

## Project Structure
- `rtl/` – Processor RTL source code
- `testbench/` – Verilog testbench
- `images/` – Simulation and project images
- `docs/` – Project report
