# Modular-32-bit-RISC-V-Processor

A modular, synthesizable implementation of a 32-bit RISC-V processor architecture (RV32I). This project focuses on a clean separation of functional hardware units, making it an excellent resource for students and engineers interested in digital design and computer architecture.

Features
•	Instruction Set: Implements the core RISC-V RV32I base integer instruction set.
•	Modular Design: Datapath and Control Unit are decoupled to simplify debugging and architectural scaling.
•	Synthesizable: Code is written in synthesizable HDL, suitable for FPGA implementation.
•	Scalable: Structure allows for easy integration of additional RISC-V extensions (e.g., M, A, F, D).

Architecture
•	The processor follows a standard modular pipeline design, consisting of the following key stages:
•	1. Instruction Fetch (IF): Logic for the Program Counter (PC) and instruction memory retrieval.
•	2. Instruction Decode (ID): Logic for register file access and immediate value generation.
•	3. Execute (EX): Arithmetic Logic Unit (ALU) operations and jump/branch target resolution.
•	4. Memory (MEM): Interfacing with data memory for load/store operations.
•	5. Write Back (WB): Logic for updating the register file.

Project Structure
•	src/ - Verilog/SystemVerilog hardware source files
•	tb/ - Testbenches for module-level and system-level verification
•	README.md - Project documentation
