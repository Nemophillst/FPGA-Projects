# FPGA-Projects

A collection of FPGA projects for learning, development, and hardware verification.

---

## 📖 项目总览 · Project Overview

| 项目 Project | 开发平台 Platform | 开发环境 Dev Env | 核心技术 Tech |
|---|---|---|---|
| [1. 双脉冲测试 · Double-Pulse Test](./01-Double-Pulse-Test/) | FPGA | Vivado | Double-Pulse · PWM · Timing Control |
| [2. SPI通信 · SPI Communication](./02-SPI-Communication/) | FPGA | Vivado | SPI · FSM · 时序设计 · 数据收发 |

---

## 🛠️ 开发环境 · Development Environment

| 开发工具 Tool | 用途 Purpose |
|---|---|
| Vivado | FPGA设计、综合、实现和仿真 |
| Verilog / SystemVerilog | RTL设计 |
| Vivado Simulator / ModelSim | 功能仿真 |
| ILA | FPGA在线逻辑调试 |

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
│   ├── 结果展示.docx
│   └── double_pulse_project/
│
└── 02-SPI-Communication/
    ├── README.md
    ├── 01-SPI-Basic/
    ├── 02-SPI-25M/
    ├── 03-SPI-80M/
    └── 04-SPI-80M-External-Loopback/
