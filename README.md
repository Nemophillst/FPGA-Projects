# FPGA-Projects

A collection of FPGA projects for learning, development, and hardware verification.

---

## 📖 项目总览 · Project Overview

| 项目 Project | 开发平台 Platform | 开发环境 Dev Env | HDL / 核心技术 Tech |
|---|---|---|---|
| [1. 双脉冲测试 · Double-Pulse Test](./01-Double-Pulse-Test/) | FPGA | Vivado | Verilog · Double-Pulse · PWM · VIO / ILA |
| [2. SPI通信 · SPI Communication](./02-SPI%20Communication/) | FPGA | Vivado | VHDL · SPI · 80 MHz · External Loopback · VIO / ILA |

---

## 🛠️ 开发环境 · Development Environment

| Tool | Purpose |
|---|---|
| Vivado | FPGA设计、综合、实现和时序分析 |
| Verilog / VHDL | RTL设计 |
| Vivado Simulator | 功能仿真 |
| ILA | 在线逻辑调试 |
| VIO | 在线控制与状态观察 |

---

## 📂 仓库结构 · Repository Structure

```text
FPGA-Projects/
│
├── README.md
├── .gitignore
│
├── 01-Double-Pulse-Test/
│   ├── README.md
│   ├── double_pulse_project/
│   └── results/
│
└── 02-SPI Communication/
    └── 01-SPI_80M_EXTERNAL_LOOPBACK/
        ├── README.md
        ├── spi_project/
        └── results/
