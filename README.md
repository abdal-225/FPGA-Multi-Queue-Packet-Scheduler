# FPGA-Based Multi-Queue Packet Scheduler

An FPGA-based packet scheduling system implementing **Priority Scheduling, Round-Robin (RR), and Weighted Round-Robin (WRR)** algorithms using Verilog HDL. The system manages multiple packet queues, performs packet scheduling, and monitors performance metrics through UART-based telemetry and a Python GUI dashboard.

## Overview

The project implements a hardware-based multi-queue packet scheduler on an **Artix-7 FPGA (Digilent Nexys 4 DDR)**.

It consists of four independent packet queues, a queue management unit, configurable scheduling algorithms, performance monitoring modules, and a Python-based dashboard for real-time visualization.

The system allows users to select different scheduling policies and observe packet transmission behavior, queue occupancy, latency, and throughput.

## Key Features

- Four independent packet queues.
- FIFO-based packet buffering and flow control.
- Three scheduling algorithms:
  - Priority Scheduling
  - Round-Robin Scheduling
  - Weighted Round-Robin Scheduling
- Configurable traffic generation.
- Queue occupancy and status monitoring.
- Packet latency measurement.
- Throughput measurement.
- UART-based telemetry communication.
- Python GUI dashboard for monitoring and visualization.
- FPGA implementation on Artix-7.

## System Architecture

The system consists of the following major hardware modules:

1. **Traffic Generator:** Generates packet traffic for the four queues.
2. **FIFO Buffers:** Store incoming packets independently.
3. **Queue Manager:** Manages queue status, occupancy, and packet buffering.
4. **Priority Scheduler:** Selects packets based on predefined queue priority.
5. **Round-Robin Scheduler:** Provides cyclic access to non-empty queues.
6. **Weighted Round-Robin Scheduler:** Allocates service opportunities according to configured queue weights.
7. **Scheduler Controller:** Controls the scheduling operation.
8. **Scheduler Multiplexer:** Selects the output of the active scheduling algorithm.
9. **Performance Monitoring:** Measures packet latency, throughput, and queue statistics.
10. **UART Telemetry:** Transmits system information to the Python dashboard.

## Scheduling Algorithms

### 1. Priority Scheduling

Queues are assigned fixed priorities. The scheduler selects the highest-priority non-empty queue.

### 2. Round-Robin Scheduling

The scheduler cycles through the four queues and serves the next non-empty queue, providing fair access to resources.

### 3. Weighted Round-Robin Scheduling

Each queue is assigned a configurable weight. The scheduler distributes service opportunities according to these weights.

Configured weights:

| Queue | Weight |
|---|---:|
| Q0 | 4 |
| Q1 | 3 |
| Q2 | 2 |
| Q3 | 1 |

This allows different queues to receive different levels of service.

## Hardware Platform

| Component | Specification |
|---|---|
| FPGA Board | Digilent Nexys 4 DDR |
| FPGA Device | Artix-7 XC7A100T |
| HDL | Verilog |
| Clock Frequency | 100 MHz |
| UART Baud Rate | 115200 |
| Number of Queues | 4 |
| FIFO Depth | 16 packets per queue |
| Packet Width | 16 bits |

## Python Dashboard

A Python-based GUI dashboard communicates with the FPGA through UART.

The dashboard provides:
- Scheduling mode monitoring.
- Queue occupancy visualization.
- Packet generation and transmission statistics.
- Latency monitoring.
- Throughput monitoring.
- Queue status and event information.

The dashboard uses Python and Tkinter, with serial communication handled using PySerial.

## Repository Structure

```text
FPGA-Multi-Queue-Packet-Scheduler/
│
├── RTL/
│   ├── fifo.v
│   ├── queue_manager.v
│   ├── priority_scheduler.v
│   ├── round_robin_scheduler.v
│   ├── weighted_rr_scheduler.v
│   ├── scheduler_controller.v
│   ├── scheduler_mux.v
│   ├── traffic_generator.v
│   ├── packet_sink.v
│   ├── performance_counter.v
│   ├── latency_counter.v
│   ├── throughput_counter.v
│   ├── uart_telemetry.v
│   └── top_scheduler.v
│
├── Dash/
│   ├── main.py
│   ├── protocol.py
│   ├── queue_model.py
│   ├── serial_receiver.py
│   ├── requirements.txt
│   └── README.txt
│
├── Constraints/
│   └── nexys4_ddr.xdc
│
├── Testbenches/
│
├── Simulation/
│
├── Results/
│
├── .gitignore
└── README.md
```

## Getting Started

### 1. FPGA Implementation

1. Open the project in Xilinx Vivado.
2. Add the Verilog source files from the `RTL/` directory.
3. Add the Nexys 4 DDR constraint file from `Constraints/`.
4. Set `top_scheduler` as the top-level module.
5. Run synthesis and implementation.
6. Generate the FPGA bitstream.
7. Program the Nexys 4 DDR board.

### 2. Running the Python Dashboard

Install the required Python dependencies:

```bash
pip install -r Dash/requirements.txt
```

Run the dashboard:

```bash
python Dash/main.py
```

Connect the FPGA board to the computer through USB-UART and select the appropriate serial port and baud rate.

## FPGA Control Interface

The system uses FPGA switches and buttons for control.

| Input | Function |
|---|---|
| SW[1:0] | Scheduling algorithm selection |
| SW[3:2] | Traffic generation mode |
| SW[4] | Start control |
| BTN[0] | Reset |

Scheduling mode selection:

| Switch value | Algorithm |
|---|---|
| 00 | Priority |
| 01 | Round-Robin |
| 10 | Weighted Round-Robin |
| 11 | Reserved |

## Applications

- Network packet scheduling.
- Router buffer management.
- FPGA-based networking systems.
- Communication infrastructure.
- Quality of Service (QoS) resource allocation.
- High-speed digital communication systems.

## Technologies Used

- Verilog HDL
- Xilinx Vivado
- Artix-7 FPGA
- UART Serial Communication
- Python
- Tkinter
- PySerial

## Future Improvements

- Support for additional scheduling algorithms.
- Dynamic queue weight configuration.
- Advanced traffic generation patterns.
- Performance comparison under different traffic loads.
- Enhanced real-time performance visualization.

## Authors

**Abdal Ahmad**  
B.Tech – Electronics and Communication Engineering  
National Institute of Technology, Warangal

**Project:** FPGA-Based Multi-Queue Packet Scheduler
