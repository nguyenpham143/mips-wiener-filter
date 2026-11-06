# Signal Filtering & Prediction with Wiener Filter in MIPS Assembly (CO2008)

An implementation of the **Wiener Filter** for discrete signal estimation, noise filtering, and Minimum Mean-Square Error (MMSE) optimization written in **MIPS32 Assembly** (simulated via MARS) with an accompanying **C++17** verification model. Developed for the **Computer Architecture Lab (CO2008)** course at Ho Chi Minh City University of Technology (HCMUT - VNU-HCM), Semester 251.

## Overview

The Wiener filter is an optimal linear estimation technique designed to filter additive noise disturbance $w(n)$ from an observed signal $x(n) = s(n) + w(n)$ to reconstruct the desired signal $d(n)$.

This project implements the end-to-end Wiener filter pipeline at the assembly level using MIPS32 instructions and Coprocessor 1 (FPU):

1. **Statistical Correlation Computation:**
   - Computes autocorrelation sequence $\gamma_{xx}(k)$ of the input sequence.
   - Computes cross-correlation vector $\gamma_{dx}(k)$ between desired and input sequences.
2. **Toeplitz Matrix Formulation:**
   - Constructs the symmetric Toeplitz autocorrelation matrix $R_M$ of size $M \times M$.
3. **Wiener-Hopf Equation Solver:**
   - Solves the linear system $R_M h_{\text{opt}} = \gamma_d$ using Gaussian elimination with partial pivoting in assembly to compute optimal filter coefficients $h_{\text{opt}}$.
4. **Signal Convolution & MMSE Evaluation:**
   - Filters the noisy signal via finite impulse response convolution $y(n) = \sum_{k=0}^{M-1} h_k x(n-k)$.
   - Evaluates the Minimum Mean-Square Error: $\text{MMSE}_M = \sigma_d^2 - \sum_{k=0}^{M-1} h_{\text{opt}}(k) \gamma_{dx}(k)$.
5. **Low-Level File I/O & String Parsing:**
   - Reads floating-point sequences from `input.txt` and `desired.txt` using MIPS system calls (`syscall` 13, 14, 16).
   - Custom ASCII-to-float parsing and float-to-ASCII serialization to write results into `output.txt`.

## Project Structure

```text
.
├── src/
│   ├── wiener_filter.asm               # Main MIPS32 Assembly implementation
│   └── wiener_filter.cpp               # High-level C++17 reference & verification model
├── specs/
│   └── CA_Assignment_251.pdf           # Assignment specification document
├── report/
│   └── wiener_filter.pdf               # Comprehensive technical report & architecture design
├── tools/
│   └── Mars4_5.jar                     # MARS (MIPS Assembler and Runtime Simulator) v4.5
├── tests/
│   ├── desired.txt                     # Desired reference signal
│   ├── input_1.txt ... input_10.txt    # 10 benchmark test inputs
│   └── output_1.txt ... output_10.txt  # 10 expected benchmark outputs
├── input.txt                           # Default input signal
├── desired.txt                         # Default desired signal
├── .gitignore                          # Git ignore rules
├── LICENSE                             # MIT License
└── README.md                           # Project documentation
```

## Getting Started

### Prerequisites

- **Java Runtime Environment (JRE 8+)**: Required to run the MARS simulator (`Mars4_5.jar`).
- **C++ Compiler (Optional)**: Supporting C++17 (e.g., `g++` or `clang++`) to run the reference model.

### Running with MARS Simulator

#### Command Line Interface (CLI)
Run the MIPS assembly code headlessly using MARS CLI:

```bash
java -jar tools/Mars4_5.jar nc src/wiener_filter.asm
```

#### Graphical User Interface (GUI)
Launch the MARS GUI:
```bash
java -jar tools/Mars4_5.jar
```
Open `src/wiener_filter.asm`, assemble (`F3`), and run (`F5`).

### Running the C++ Reference Model

Compile and run the verification program:
```bash
g++ -o wiener_filter src/wiener_filter.cpp -std=c++17
./wiener_filter
```

## Contributors

Developed by **Group 06** (Class CC06) — Faculty of Computer Science and Engineering, Ho Chi Minh City University of Technology (HCMUT - VNU-HCM):

| Name | Student ID | Workload & Primary Responsibilities |
| :--- | :---: | :--- |
| **Pham Gia Hung** | 2452431 | Input handling, file I/O, data loading, memory layout for MIPS, and MMSE computation. |
| **Pham Vu Khoi Nguyen** | 2412372 | Correlation computation module (autocorrelation & cross-correlation) in C++ and MIPS. |
| **Dinh Phuc Khang** | 2452453 | Linear system solver, Wiener filter coefficient computation, integration, and debugging. |
| **Nguyen Xuan An** | 2452023 | Technical report writing, system flowcharts, diagram preparation, and documentation. |

## License

This project is licensed under the [MIT License](LICENSE).
