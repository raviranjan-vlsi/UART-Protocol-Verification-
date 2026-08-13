# 🔌 UART RTL Design & Verification using SystemVerilog

<p align="center">

![SystemVerilog](https://img.shields.io/badge/Language-SystemVerilog-blue)
![Domain](https://img.shields.io/badge/Domain-VLSI%20%2F%20Design%20Verification-orange)
![Protocol](https://img.shields.io/badge/Protocol-UART-green)
![Methodology](https://img.shields.io/badge/Methodology-SystemVerilog%20OOP-purple)
![Assertions](https://img.shields.io/badge/Assertions-SVA-red)
![Coverage](https://img.shields.io/badge/Functional%20Coverage-Enabled-yellow)
![UVM](https://img.shields.io/badge/UVM-Not%20Used-lightgrey)
![Simulator](https://img.shields.io/badge/Simulator-Questa%20%2F%20VCS-blue)
![License](https://img.shields.io/badge/License-MIT-brightgreen)

</p>

<p align="center">
<b>A self-checking, class-based SystemVerilog verification environment for UART RTL</b><br>
covering functional operation, parity modes, baud-rate behavior, error injection,
assertion-based checking, functional coverage, and automated regression.
</p>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Key Features](#-key-features)
- [Problem Addressed](#-problem-addressed)
- [UART Protocol Overview](#-uart-protocol-overview)
- [System Architecture](#-system-architecture)
- [Verification Architecture](#-verification-architecture)
- [Core Testbench Components](#-core-testbench-components)
- [DUT: UART RTL](#-dut-uart-rtl)
- [TX/RX Verification Flow](#-txrx-verification-flow)
- [Verification Strategy](#-verification-strategy)
- [Test Scenarios](#-test-scenarios)
- [Simulation Results](#-simulation-results)
- [Waveform Evidence](#-waveform-evidence)
- [Functional Coverage](#-functional-coverage)
- [Assertions](#-assertions)
- [Error Injection](#-error-injection)
- [Regression](#-regression)
- [Project Structure](#-project-structure)
- [Design / Verification Parameters](#-design--verification-parameters)
- [Example Verification Flow](#-example-verification-flow)
- [How to Run](#%EF%B8%8F-how-to-run)
- [Running a Specific Test](#-running-a-specific-test)
- [Debugging Notes](#-debugging-notes)
- [Verification Philosophy](#-verification-philosophy)
- [Skills Demonstrated](#-skills-demonstrated)
- [Documentation](#-documentation)
- [Future Improvements](#-future-improvements)
- [Author](#-author)
- [Connect](#-connect)
- [Support](#-support)

---

## 🚀 Overview

This project implements a **UART RTL design** together with a
**self-checking, class-based SystemVerilog verification environment**.

The objective is not only to verify that UART data can be transmitted
and received, but to demonstrate a structured Design Verification
workflow consisting of:

- Transaction-based stimulus generation
- Object-oriented SystemVerilog classes
- Virtual interface based DUT connectivity
- Driver and monitor separation
- Scoreboard-based checking
- Constrained-random verification
- Directed verification scenarios
- Error injection
- SystemVerilog Assertions
- Functional coverage
- Automated regression

The verification environment is intentionally built without UVM to
demonstrate the underlying SystemVerilog verification concepts directly.

The project is organized so that a reviewer can follow the complete
verification flow from:

```text
Stimulus
   ↓
Transaction
   ↓
Generator
   ↓
Driver
   ↓
UART DUT
   ↓
Monitor
   ↓
Scoreboard
   ↓
PASS / FAIL

       ┌───────────────┐
       │               │
       ▼               ▼
   Assertions      Coverage
```

---

## 🎯 Key Features

✔ Class-based SystemVerilog OOP verification environment

✔ Transaction-oriented stimulus generation

✔ Mailbox-based communication between verification components

✔ Virtual interface based DUT connectivity

✔ Directed and constrained-random verification

✔ Self-checking scoreboard

✔ UART TX and RX verification

✔ Multiple parity configurations

✔ Baud-rate verification

✔ Random data testing

✔ Boundary data testing

✔ Back-to-back transaction testing

✔ TX busy behavior verification

✔ Parity error injection

✔ Framing error injection

✔ Combined error testing

✔ Stress testing

✔ SystemVerilog Assertions

✔ Functional coverage

✔ Automated regression using shell scripting

✔ Questa / VCS execution support

✔ Per-test PASS/FAIL result extraction

✔ Packet-count extraction from simulation logs

✔ Coverage-result extraction from simulation logs

---

## 🧠 Problem Addressed

A UART design can appear correct during a few simple simulations while
still containing functional bugs that only appear under specific
configuration, timing, data, or error conditions.

For example, a basic test such as:

```text
TX data → UART → RX data
```

may pass while corner cases involving:

* parity configuration,
* parity errors,
* framing errors,
* busy conditions,
* boundary data,
* back-to-back transactions,
* baud-rate configuration,

remain unverified.

This project addresses that problem by building a verification
environment that does not depend only on manually inspecting
waveforms.

Instead, the environment combines:

```text
                 ┌──────────────────┐
                 │    Testcases     │
                 └────────┬─────────┘
                          ↓
                 ┌──────────────────┐
                 │    Generator     │
                 └────────┬─────────┘
                          ↓
                 ┌──────────────────┐
                 │     Driver       │
                 └────────┬─────────┘
                          ↓
                 ┌──────────────────┐
                 │     UART DUT     │
                 └────────┬─────────┘
                          ↓
                 ┌──────────────────┐
                 │     Monitor      │
                 └────────┬─────────┘
                          ↓
                 ┌──────────────────┐
                 │    Scoreboard    │
                 └──────────────────┘

                  + Assertions
                  + Coverage
                  + Regression
```

This allows the project to verify both **what the DUT produced** and
**whether the verification environment has exercised the intended
functional space**.

---

## 📡 UART Protocol Overview

UART is an asynchronous serial communication protocol in which data is
transmitted sequentially using a serial line without a shared clock
between transmitter and receiver.

A typical UART frame consists of:

```text
Idle      Start       Data             Parity       Stop
  │          │          │                 │           │
  ▼          ▼          ▼                 ▼           ▼

───────┐   ┌───┐   ┌───────────────┐   ┌───┐   ┌────────
       └───┘   └───┴───────────────┴───┘   └───┘
```

The exact frame configuration supported by this project should be
referenced from the RTL implementation.

<!--
IMAGE PLACEHOLDER

Create the UART frame/protocol diagram manually.

Recommended file:
docs/images/protocol/uart-frame-format.png

The diagram should show the actual frame configuration supported by
this implementation, including:
- Idle
- Start bit
- Data bits
- Optional parity
- Stop bit
- Bit timing / baud relationship if useful
-->

<p align="center">
<img src="docs/images/protocol/uart-frame-format.png" width="750">
</p>

---

## 🏗 System Architecture

The UART design is organized around dedicated transmit and receive
logic integrated at the top level.

<!--
IMAGE PLACEHOLDER

Create the actual UART RTL block diagram.

Recommended file:
docs/images/architecture/uart-dut-architecture.png

Suggested blocks:

                  UART TOP
              ┌──────────────┐
              │              │
  TX Control ─►│ UART TX     │──► TX Serial
              │              │
              │              │
  RX Serial ─►│ UART RX     │──► RX Data
              │              │
              └──────────────┘

Add clock, reset, configuration and status signals according to
the actual RTL.
-->

<p align="center">
<img src="docs/images/architecture/uart-dut-architecture.png" width="750">
</p>

### Design Components

| Component  | Role                                                        |
| ---------- | ----------------------------------------------------------- |
| `uart_tx`  | UART transmit logic                                         |
| `uart_rx`  | UART receive logic                                          |
| `uart_top` | Top-level UART integration                                  |
| `uart_if`  | SystemVerilog interface used for DUT/testbench connectivity |

---

## 🔬 Verification Architecture

The verification environment is implemented using SystemVerilog
classes and separates stimulus generation from observation and checking.

The major verification path is:

```text
                         TEST
                          │
                          ▼
                     GENERATOR
                          │
                          │ transaction
                          ▼
                       DRIVER
                          │
                          │ interface signals
                          ▼
                    ┌───────────┐
                    │ UART DUT  │
                    └─────┬─────┘
                          │
                          │ DUT activity
                          ▼
                       MONITOR
                          │
                          │ observed transaction
                          ▼
                     SCOREBOARD
                          │
                          ▼
                       CHECK
```

Additional verification mechanisms operate alongside the scoreboard:

```text
                         UART DUT
                            │
                 ┌──────────┼──────────┐
                 │          │          │
                 ▼          ▼          ▼
             Monitor   Assertions   Coverage
                 │
                 ▼
             Scoreboard
                 │
                 ▼
              Result
```

<!--
IMAGE PLACEHOLDER

Create the final professional verification environment diagram.

Recommended file:
docs/images/architecture/uart-verification-environment.png

Show the actual relationships between:
- Test
- Environment
- Generator
- Driver
- DUT
- Monitor
- Scoreboard
- Coverage
- Assertions
- Mailboxes
- Virtual interface
-->

<p align="center">
<img src="docs/images/architecture/uart-verification-environment.png" width="850">
</p>

---

## ⚙ Core Testbench Components

### Transaction

The transaction class represents the information required to describe
a UART verification operation.

It acts as the data object passed between verification components.

The transaction layer allows the generator, driver, monitor and
scoreboard to communicate using higher-level transaction information
rather than directly sharing implementation-specific signal activity.

---

### Generator

The generator creates UART verification transactions.

The test suite uses both:

* Directed stimulus
* Constrained-random stimulus

This allows deterministic testing for specific scenarios while also
providing randomized data and conditions for broader exploration.

---

### Driver

The driver converts transactions into DUT interface activity.

Its responsibility is to translate the transaction-level description
into the actual signals required by the UART interface.

The driver communicates with the DUT through the SystemVerilog
virtual interface.

```text
Transaction
     │
     ▼
  Driver
     │
     ▼
Virtual Interface
     │
     ▼
   UART DUT
```

---

### Monitor

The monitor is responsible for observing DUT activity.

It does not generate stimulus for the DUT.

Instead, it samples relevant UART activity and reconstructs
transaction-level information for downstream checking and coverage.

```text
UART DUT
   │
   ▼
Monitor
   │
   ├──────────► Scoreboard
   │
   └──────────► Coverage
```

---

### Scoreboard

The scoreboard provides automated checking.

Expected and observed transaction information is compared to identify
functional mismatches.

A mismatch is reported explicitly so that the failure can be traced
back to the relevant transaction and simulation.

The scoreboard is therefore the primary transaction-level
self-checking mechanism in the environment.

---

### Environment

The environment connects the verification components and provides the
overall structure for the testbench.

Conceptually:

```text
             ┌───────────────────────────────┐
             │            ENVIRONMENT         │
             │                               │
             │  Generator → Driver → DUT     │
             │                   │           │
             │                   ▼           │
             │                Monitor        │
             │                 │   │         │
             │                 ▼   ▼         │
             │            Scoreboard Coverage│
             │                               │
             └───────────────────────────────┘
```

---

### Coverage

The coverage component measures whether important verification
scenarios have been exercised.

Coverage is used as a complement to simulation PASS/FAIL checking.

A test passing does not necessarily mean that the verification space
is complete.

Coverage helps answer:

> "Which intended scenarios have actually been exercised?"

---

### Assertions

Assertions provide an independent mechanism for checking temporal and
protocol-related behavior.

They operate concurrently with the functional testbench and can
identify violations that may not necessarily appear as scoreboard
mismatches.

---

## 🧩 DUT: UART RTL

The Design Under Test consists of the UART transmitter, UART receiver,
and top-level integration.

### UART Transmitter

The transmitter converts parallel transmit information into serial
UART waveform activity.

Conceptually:

```text
TX Data
   │
   ▼
┌─────────────┐
│ UART TX     │
│             │
│ Frame       │
│ Generation  │
└──────┬──────┘
       │
       ▼
   Serial TX
```

<!--
IMAGE PLACEHOLDER

Add a waveform showing an actual TX transaction.

Recommended file:
docs/images/simulation/uart-tx-waveform.png
-->

<p align="center">
<img src="docs/images/simulation/uart-tx-waveform.png" width="850">
</p>

---

### UART Receiver

The receiver observes the serial UART input and reconstructs the
received data.

Conceptually:

```text
Serial RX
    │
    ▼
┌─────────────┐
│ UART RX     │
│             │
│ Sampling    │
│ Frame       │
│ Detection   │
│ Error Check │
└──────┬──────┘
       │
       ▼
   RX Data
```

<!--
IMAGE PLACEHOLDER

Add a waveform showing an actual RX transaction.

Recommended file:
docs/images/simulation/uart-rx-waveform.png
-->

<p align="center">
<img src="docs/images/simulation/uart-rx-waveform.png" width="850">
</p>

---

## 🔄 TX/RX Verification Flow

A typical functional verification sequence can be represented as:

```text
Test
 │
 ▼
Generate Transaction
 │
 ▼
Drive TX / RX Interface
 │
 ▼
UART DUT
 │
 ├───────────────┐
 │               │
 ▼               ▼
TX/RX Activity  Status/Error
 │               │
 └───────┬───────┘
         ▼
       Monitor
         │
         ▼
     Scoreboard
         │
    ┌────┴────┐
    ▼         ▼
  PASS       FAIL
```

---

## 🧪 Verification Strategy

The verification strategy is divided into four major areas.

### 1. Basic Functional Verification

The basic tests establish that the UART operates correctly under
normal conditions.

Examples:

* Reset
* Single TX/RX transaction
* Basic data transfer

---

### 2. Configuration Verification

Different UART operating configurations are exercised.

The current test suite includes:

* No parity
* Even parity
* Odd parity
* Baud-rate verification

---

### 3. Data and Traffic Verification

The environment exercises a range of data and transaction sequences.

These include:

* Random data
* Boundary data
* Back-to-back traffic
* Stress testing

---

### 4. Error Verification

The environment intentionally introduces invalid conditions.

The current suite includes:

* TX busy behavior
* Parity error
* Framing error
* Combined parity and framing error

---

## 🧪 Test Scenarios

The current regression suite contains **14 verification scenarios**:

|  # | Test                  | Category        |
| -: | --------------------- | --------------- |
|  1 | `TEST_RESET`          | Basic           |
|  2 | `TEST_SINGLE_TX_RX`   | Functional      |
|  3 | `TEST_NO_PARITY`      | Configuration   |
|  4 | `TEST_EVEN_PARITY`    | Configuration   |
|  5 | `TEST_ODD_PARITY`     | Configuration   |
|  6 | `TEST_BAUD_RATE`      | Timing          |
|  7 | `TEST_RANDOM_DATA`    | Randomized      |
|  8 | `TEST_BOUNDARY_DATA`  | Corner Case     |
|  9 | `TEST_BACK_TO_BACK`   | Traffic         |
| 10 | `TEST_TX_BUSY_IGNORE` | Corner Case     |
| 11 | `TEST_PARITY_ERROR`   | Error Injection |
| 12 | `TEST_FRAMING_ERROR`  | Error Injection |
| 13 | `TEST_BOTH_ERRORS`    | Error Injection |
| 14 | `TEST_STRESS`         | Stress          |

The regression script executes these tests automatically and extracts
the result, packet count and coverage percentage from each simulation
log.

---

## 📊 Simulation Results

> The images and numerical results in this section are intentionally
> placeholders. Replace them with the actual results produced by your
> simulator.

### Regression Summary

<!--
IMAGE PLACEHOLDER

Add a screenshot of the final regression summary.

Recommended file:
docs/images/results/regression-summary.png
-->

<p align="center">
<img src="docs/images/results/regression-summary.png" width="850">
</p>

### Console Result

```text
========================================
UART REGRESSION RESULTS
========================================

Test                    Result    Packets    Coverage
------------------------------------------------------
TEST_RESET              [INSERT]  [INSERT]  [INSERT]%
TEST_SINGLE_TX_RX       [INSERT]  [INSERT]  [INSERT]%
TEST_NO_PARITY          [INSERT]  [INSERT]  [INSERT]%
TEST_EVEN_PARITY        [INSERT]  [INSERT]  [INSERT]%
TEST_ODD_PARITY         [INSERT]  [INSERT]  [INSERT]%
TEST_BAUD_RATE          [INSERT]  [INSERT]  [INSERT]%
TEST_RANDOM_DATA        [INSERT]  [INSERT]  [INSERT]%
TEST_BOUNDARY_DATA      [INSERT]  [INSERT]  [INSERT]%
TEST_BACK_TO_BACK       [INSERT]  [INSERT]  [INSERT]%
TEST_TX_BUSY_IGNORE     [INSERT]  [INSERT]  [INSERT]%
TEST_PARITY_ERROR       [INSERT]  [INSERT]  [INSERT]%
TEST_FRAMING_ERROR      [INSERT]  [INSERT]  [INSERT]%
TEST_BOTH_ERRORS        [INSERT]  [INSERT]  [INSERT]%
TEST_STRESS             [INSERT]  [INSERT]  [INSERT]%

========================================
REGRESSION RESULT: [INSERT]
========================================
```

---

## 🌊 Waveform Evidence

### TX/RX Functional Transaction

<!--
IMAGE PLACEHOLDER

Recommended file:
docs/images/simulation/uart-tx-rx-waveform.png

Use a clean waveform with only the relevant signals visible.
Add annotations if useful.
-->

<p align="center">
<img src="docs/images/simulation/uart-tx-rx-waveform.png" width="900">
</p>

---

### Back-to-Back Transactions

<!--
IMAGE PLACEHOLDER

Recommended file:
docs/images/simulation/uart-back-to-back-waveform.png
-->

<p align="center">
<img src="docs/images/simulation/uart-back-to-back-waveform.png" width="900">
</p>

---

### Error Injection Waveform

<!--
IMAGE PLACEHOLDER

Recommended file:
docs/images/simulation/uart-error-injection-waveform.png

Show one meaningful parity or framing error transaction.
-->

<p align="center">
<img src="docs/images/simulation/uart-error-injection-waveform.png" width="900">
</p>

---

## 📈 Functional Coverage

Functional coverage is used to measure the verification space exercised
by the test suite.

The coverage model targets important UART configuration, data,
traffic and error scenarios.

<!--
IMAGE PLACEHOLDER

Add your actual Questa coverage report screenshot.

Recommended file:
docs/images/coverage/functional-coverage-report.png
-->

<p align="center">
<img src="docs/images/coverage/functional-coverage-report.png" width="850">
</p>

### Coverage Summary

| Coverage Metric     |      Result |
| -------------------- | ----------: |
| Functional Coverage | `[INSERT]%` |
| Code Coverage       | `[INSERT]%` |
| Assertion Coverage  | `[INSERT]%` |
| Overall Coverage    | `[INSERT]%` |

> Only populate metrics that are actually generated by the project.

<details>
<summary><b>Coverage Model</b></summary>

The detailed coverage model includes coverage of the important
verification dimensions implemented in the UART environment.

Examples include:

| Coverage Area           | Purpose                                   |
| ------------------------ | ------------------------------------------ |
| UART data               | Exercise different data patterns          |
| Parity configuration    | Verify supported parity modes             |
| Baud-rate configuration | Exercise timing configurations            |
| Traffic pattern         | Exercise single and back-to-back activity |
| Error conditions        | Exercise parity/framing error scenarios   |
| Boundary conditions     | Exercise edge-case values                 |
| Stress scenarios        | Exercise repeated/random activity         |

The exact coverpoints and crosses should be documented according to
the implementation in `uart_coverage.sv`.

</details>

---

## ✅ Assertions

SystemVerilog Assertions are used as an additional verification layer.

Assertions allow protocol and temporal conditions to be monitored
continuously during simulation.

<!--
IMAGE PLACEHOLDER

Add actual assertion result screenshot.

Recommended file:
docs/images/results/assertion-results.png
-->

<p align="center">
<img src="docs/images/results/assertion-results.png" width="850">
</p>

### Assertion Results

| Metric                 |      Result |
| ----------------------- | ----------: |
| Assertions Implemented |  `[INSERT]` |
| Assertions Passed      |  `[INSERT]` |
| Assertions Failed      |  `[INSERT]` |
| Assertion Coverage     | `[INSERT]%` |

> Replace the placeholders with actual simulator results.

Detailed assertion documentation:

**→ [`docs/assertions.md`](docs/assertions.md)**

---

## 🚨 Error Injection

A significant part of the verification environment is dedicated to
negative testing.

Instead of verifying only valid UART frames, the testbench intentionally
creates invalid conditions to determine whether the DUT responds
correctly.

### Parity Error

```text
Expected UART frame
        │
        ▼
 ┌───────────────┐
 │ Correct Data  │
 │ Correct Parity│
 └───────────────┘

             ↓ Error Injection

 ┌───────────────┐
 │ Data          │
 │ Incorrect     │
 │ Parity        │
 └───────────────┘
```

<!--
IMAGE PLACEHOLDER

Recommended file:
docs/images/simulation/parity-error-waveform.png
-->

<p align="center">
<img src="docs/images/simulation/parity-error-waveform.png" width="850">
</p>

---

### Framing Error

The framing-error test exercises an invalid UART frame condition.

<!--
IMAGE PLACEHOLDER

Recommended file:
docs/images/simulation/framing-error-waveform.png
-->

<p align="center">
<img src="docs/images/simulation/framing-error-waveform.png" width="850">
</p>

---

### Combined Errors

The test suite also contains a scenario where parity and framing
error conditions are exercised together.

<!--
IMAGE PLACEHOLDER

Recommended file:
docs/images/simulation/combined-error-waveform.png
-->

<p align="center">
<img src="docs/images/simulation/combined-error-waveform.png" width="850">
</p>

---

## 🔁 Regression

The project includes an automated `regression.sh` script.

The script:

1. Selects the simulator.
2. Compiles the design and verification environment.
3. Iterates through the complete test list.
4. Runs each test independently.
5. Captures the simulator output.
6. Searches the log for scoreboard mismatches.
7. Extracts packet counts.
8. Extracts coverage.
9. Determines PASS/FAIL.
10. Generates a consolidated regression result.

Conceptually:

```text
              regression.sh
                    │
                    ▼
             Compile Project
                    │
                    ▼
          ┌───────────────────┐
          │   Test 01         │
          │   Test 02         │
          │   Test 03         │
          │       ...         │
          │   Test 14         │
          └─────────┬─────────┘
                    │
                    ▼
              Simulation Logs
                    │
        ┌───────────┼────────────┐
        │           │            │
        ▼           ▼            ▼
    Scoreboard   Packets     Coverage
     Mismatch     Count       Result
        │           │            │
        └───────────┼────────────┘
                    ▼
             Regression Table
                    │
                    ▼
               PASS / FAIL
```

The current regression script supports Questa by default and provides
a VCS execution path through the `SIMULATOR` selection.

---

## 📁 Project Structure

<details>
<summary><b>Click to expand project structure</b></summary>

```text
uart_verification/
│
├── rtl/
│   ├── uart_tx.sv
│   ├── uart_rx.sv
│   └── uart_top.sv
│
├── tb/
│   ├── uart_if.sv
│   ├── uart_pkg.sv
│   ├── transaction.sv
│   ├── generator.sv
│   ├── driver.sv
│   ├── monitor.sv
│   ├── scoreboard.sv
│   ├── environment.sv
│   ├── coverage.sv
│   └── test.sv
│
├── assertions/
│   └── uart_assertions.sv
│
├── tests/
│   ├── directed/
│   ├── error_injection/
│   └── stress/
│
├── sim/
│   ├── filelist.f
│   ├── run.do
│   ├── regression.sh
│   └── regression_results.txt
│
├── docs/
│   ├── design.md
│   ├── verification-architecture.md
│   ├── verification-plan.md
│   ├── test-plan.md
│   ├── test-cases.md
│   ├── coverage-plan.md
│   ├── assertions.md
│   ├── simulation.md
│   ├── regression.md
│   ├── results.md
│   ├── debugging.md
│   ├── how-to-run.md
│   │
│   └── images/
│       ├── architecture/
│       ├── protocol/
│       ├── simulation/
│       ├── coverage/
│       ├── results/
│       └── debug/
│
├── README.md
├── LICENSE
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
├── SECURITY.md
└── CHANGELOG.md
```

</details>

---

## ⚡ Design / Verification Parameters

The exact parameter values should always match the RTL and testbench
implementation.

| Parameter / Configuration | Description                    | Value      |
| -------------------------- | ------------------------------- | ---------- |
| Data Width                | UART payload width             | `[INSERT]` |
| Baud Rate                 | Serial communication rate      | `[INSERT]` |
| Clock Frequency           | DUT simulation clock           | `[INSERT]` |
| Parity                    | Supported parity configuration | `[INSERT]` |
| Stop Bits                 | UART stop-bit configuration    | `[INSERT]` |
| Reset                     | Reset behavior                 | `[INSERT]` |
| Test Randomization        | Randomized stimulus            | Enabled    |
| Functional Coverage       | Coverage collection            | Enabled    |
| Assertions                | SVA checking                   | Enabled    |

---

## 💻 Example Verification Flow

A typical transaction passes through the environment as follows:

```text
1. TEST
   │
   ▼
2. GENERATOR
   │
   │ Creates transaction
   ▼
3. DRIVER
   │
   │ Drives DUT interface
   ▼
4. UART DUT
   │
   │ Generates TX/RX behavior
   ▼
5. MONITOR
   │
   │ Captures actual behavior
   ▼
6. SCOREBOARD
   │
   ├── Expected
   └── Actual
          │
          ▼
       Compare
          │
      ┌───┴───┐
      ▼       ▼
    PASS     FAIL
```

At the same time:

```text
UART DUT
   │
   ├──────────► Assertions
   │
   └──────────► Coverage
```

This allows the same simulation to provide:

* Functional result
* Protocol checking
* Coverage measurement
* Debug information

---

## ▶️ How to Run

### Questa / ModelSim

From the simulation directory:

```bash
cd sim
./regression.sh
```

For a single simulation using the project run script:

```bash
vsim -do run.do
```

For command-line execution:

```bash
vsim -c -do run.do
```

---

### VCS

The regression script provides a VCS execution option:

```bash
cd sim

SIMULATOR=vcs ./regression.sh
```

The simulator must support the SystemVerilog constructs used by this
verification environment, including:

* Classes
* Mailboxes
* Constraints
* Covergroups
* Virtual interfaces
* Concurrent assertions

---

## 🧪 Running a Specific Test

The regression infrastructure passes the selected test name to the
simulation through a test-selection mechanism.

Example:

```bash
vsim -c -voptargs=+acc top_tb +TESTNAME=TEST_RANDOM_DATA \
     -do "run -all; quit -sim"
```

Use the exact command documented in:

**→ [`docs/how-to-run.md`](docs/how-to-run.md)**

---

## 🐛 Debugging Notes

A useful verification repository should document not only successful
runs but also meaningful debugging experiences.

During development, failures should be investigated using:

```text
                 Test Failure
                      │
          ┌───────────┼───────────┐
          │           │           │
          ▼           ▼           ▼
       Log File    Scoreboard   Assertion
                       │           │
                       └─────┬─────┘
                             ▼
                          Waveform
                             │
                             ▼
                       Root Cause
                             │
                             ▼
                           Fix
                             │
                             ▼
                         Regression
```

Recommended debugging evidence:

<!--
IMAGE PLACEHOLDER

Add a real failure/debug waveform only if the project contains a
meaningful bug that was detected and fixed.

Recommended file:
docs/images/debug/bug-detection-waveform.png
-->

<p align="center">
<img src="docs/images/debug/bug-detection-waveform.png" width="900">
</p>

### Debugging Checklist

When a test fails:

1. Identify the failing test.
2. Check the simulation log.
3. Inspect scoreboard mismatch information.
4. Check assertion failures.
5. Inspect the relevant waveform.
6. Compare expected and observed transactions.
7. Identify the RTL or testbench root cause.
8. Apply the correction.
9. Re-run the failing test.
10. Run the complete regression again.

---

## 🧠 Verification Philosophy

The project follows a simple principle:

> **A passing test is evidence of correctness for the tested scenario,
> not proof that the design is fully verified.**

Therefore the verification environment combines multiple independent
mechanisms:

```text
             Functional Checking
                     │
                     ▼
                 Scoreboard
                     │
                     │
     ┌───────────────┼────────────────┐
     │               │                │
     ▼               ▼                ▼
  Directed       Randomized       Error Tests
   Tests           Tests
     │               │                │
     └───────────────┼────────────────┘
                     │
                     ▼
               Assertions
                     │
                     ▼
                Coverage
                     │
                     ▼
                Regression
```

This provides a stronger verification strategy than relying solely
on directed waveform inspection.

---

## 🛠 Skills Demonstrated

This project demonstrates practical Design Verification concepts
including:

* SystemVerilog OOP
* Class-based testbench architecture
* Transaction-level modeling
* Mailbox communication
* Virtual interfaces
* Constraint-based randomization
* Directed stimulus
* Random stimulus
* Driver development
* Passive monitor development
* Scoreboard development
* Self-checking verification
* Functional coverage
* Coverage-driven verification
* SystemVerilog Assertions
* Error injection
* Negative testing
* Boundary testing
* Stress testing
* Regression automation
* Questa simulation
* VCS-compatible simulation flow
* Waveform-based debugging
* Verification result analysis

---

## 📚 Documentation

| Document                                                                 | Purpose                                |
| -------------------------------------------------------------------------- | ---------------------------------------- |
| [`docs/design.md`](docs/design.md)                                       | UART RTL architecture and operation    |
| [`docs/verification-architecture.md`](docs/verification-architecture.md) | Detailed testbench architecture        |
| [`docs/verification-plan.md`](docs/verification-plan.md)                 | Verification requirements and strategy |
| [`docs/test-plan.md`](docs/test-plan.md)                                 | Test categories and objectives         |
| [`docs/test-cases.md`](docs/test-cases.md)                               | Detailed test-case specification       |
| [`docs/coverage-plan.md`](docs/coverage-plan.md)                         | Functional coverage methodology        |
| [`docs/assertions.md`](docs/assertions.md)                               | SVA checks and verification intent     |
| [`docs/simulation.md`](docs/simulation.md)                               | Simulation and waveform analysis       |
| [`docs/regression.md`](docs/regression.md)                               | Automated regression methodology       |
| [`docs/results.md`](docs/results.md)                                     | Final verification results             |
| [`docs/debugging.md`](docs/debugging.md)                                 | Debugging and failure analysis         |
| [`docs/how-to-run.md`](docs/how-to-run.md)                               | Complete simulation instructions       |

---

## 🔮 Future Improvements

Possible future extensions include:

* UVM-based version of the verification environment
* More extensive constrained-random stimulus
* Expanded functional coverage
* Additional UART corner-case testing
* More protocol assertions
* Coverage-driven test refinement
* Automated coverage report generation
* CI-based regression
* Multi-simulator regression
* Automated waveform/result artifact collection
* Enhanced reference-model checking
* Formal verification of selected UART properties

---

## 👨‍💻 Author

**Raviranjan Kumar**

M.Tech — VLSI Design and Embedded Systems
National Institute of Technology Kurukshetra

### Areas of Interest

* Design Verification
* SystemVerilog
* UVM
* RTL Design
* Digital IC Design
* FPGA
* VLSI

---

## 🔗 Connect

* GitHub: `[ADD YOUR GITHUB PROFILE LINK]`
* LinkedIn: `[ADD YOUR LINKEDIN PROFILE LINK]`
* Email: `[ADD YOUR EMAIL]`

---

## ⭐ Support

If you find this project useful for learning SystemVerilog,
Design Verification, UART verification, or VLSI verification
methodology, consider giving the repository a ⭐.

---

<p align="center">

<b>RTL → Stimulus → DUT → Monitor → Scoreboard → Assertions → Coverage → Regression</b>

</p>
