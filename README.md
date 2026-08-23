# APB Bus Functional Coverage using UVM

## Overview
This repository contains a Universal Verification Methodology (UVM) based testbench designed to analyze the functional coverage of an Advanced Peripheral Bus (APB) interface. The project demonstrates transaction-level modeling, passive monitoring, and coverage collection using a dedicated UVM subscriber.

## Architecture
* **Interface & DUT:** A standard APB interface with a mock dummy slave for response generation.
* **UVM Agent:** Contains a sequence, driver, and a passive monitor.
* **Coverage Subscriber:** A `uvm_subscriber` component that samples a custom `covergroup` capturing read/write operations and memory address distributions.

## Waveform & Simulation
The simulation is fully compliant with the APB state machine (SETUP $\rightarrow$ ACCESS phases). 

![Simulation Waveform](docs/waveform.png)

## Coverage Analysis & Missing Holes
Initial coverage reports highlighted the following untested scenarios which require further constrained-random sequences:
1. **Wait-State Injection:** The slave responds with 0 delay. Randomized `pready` toggling is required for 100% coverage.
2. **Error Handling:** `pslverr` remains unasserted. An error-injection sequence is required to verify fault-tolerance logic.

## Author
* **Syed Muhammad Ghayyoor Ali Naqvi**
* **Roll Number:** 2022f-bel-038
* Sir Syed University of Engineering and Technology (SSUET)
