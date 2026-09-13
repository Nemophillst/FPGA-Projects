# FPGA-Projects

A collection of FPGA projects for learning, development, and hardware verification.

---

## 📖 项目总览 · Project Overview

| 项目 Project | 开发平台 Platform | 开发环境 Dev Env | 核心技术 Tech |
|---|---|---|---|
| [1. 双脉冲测试 · Double-Pulse Test](./01-Double-Pulse-Test/) | FPGA | Vivado | PWM · 时序控制 · 双脉冲测试 |
| 2. UART通信 · UART Communication | FPGA | Vivado | UART · FSM · 串行通信 |
| 3. 异步FIFO · Asynchronous FIFO | FPGA | Vivado | FIFO · CDC · Gray Code |
| 4. Zynq PS-PL通信 · Zynq PS-PL Communication | Zynq SoC | Vivado / Vitis | AXI · PS-PL · Embedded Linux |

---

## 🛠️ 开发环境 · Development Environment

| 开发工具 Tool | 用途 Purpose |
|---|---|
| Vivado | FPGA设计、综合、实现和仿真 |
| Verilog / SystemVerilog | RTL设计 |
| ModelSim / Vivado Simulator | 功能仿真 |
| ILA | FPGA在线逻辑调试 |
| Vitis | Zynq软件开发 |

---

## 🔧 硬件平台 · Hardware Platform

| 硬件 Hardware | 型号 Model | 用途 Purpose |
|---|---|---|
| FPGA开发板 | 待填写 | FPGA项目开发 |
| FPGA芯片 | 待填写 | RTL逻辑实现 |
| USB-UART | 待填写 | 串口通信测试 |
| 逻辑分析仪 | 待填写 | SPI / UART时序测试 |

---

## 📂 仓库结构 · Repository Structure

```text
FPGA-Projects/
│
├── README.md
│
├── 01-SPI-High-Speed-Loopback/
│   ├── README.md
│   ├── rtl/
│   ├── tb/
│   ├── constraints/
│   └── docs/
│
├── 02-UART/
│
├── 03-Asynchronous-FIFO/
│
└── 04-Zynq-PS-PL/
