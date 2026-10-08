# FPGA-Projects

A collection of FPGA projects for learning, development, and hardware verification.

---

## 📖 项目总览 · Project Overview

| 项目 Project | 开发平台 Platform | 开发环境 Dev Env | HDL / 核心技术 Tech |
|---|---|---|---|
| [1. 双脉冲测试 · Double-Pulse Test](./01-Double-Pulse-Test/) | FPGA | Vivado | Verilog · Double-Pulse · PWM · VIO / ILA |
| [2. SPI通信 · SPI Communication](./02-SPI%20Communication/) | FPGA | Vivado | VHDL · SPI · 80 MHz · External Loopback · Block Design · VIO / ILA |

---

## 📡 SPI项目 · SPI Projects

| 项目 Project | 开发环境 Dev Env | 核心技术 Tech |
|---|---|---|
| [02-01. SPI 80M External Loopback](./02-SPI%20Communication/01-SPI_80M_EXTERNAL_LOOPBACK/) | Vivado | VHDL · SPI · 80 MHz · External Loopback · VIO / ILA |
| [02-02. SPI 80M Block Design](./02-SPI%20Communication/02-SPI_80M_BLOCK_DESIGN/) | Vivado | VHDL · SPI · 80 MHz · Block Design |

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
├── .github/
│   └── workflows/
│       └── update-spi-zip.yml
│
├── 01-Double-Pulse-Test/
│   ├── README.md
│   ├── double_pulse_project/
│   └── results/
│
└── 02-SPI Communication/
    │
    ├── 01-SPI_80M_EXTERNAL_LOOPBACK/
    │   ├── README.md
    │   ├── spi_project/
    │   └── results/
    │
    └── 02-SPI_80M_BLOCK_DESIGN/
```

---

## 📦 工程下载 · Project Downloads

各项目的源码可通过项目目录查看。已经发布的独立工程压缩包可通过 GitHub Releases 下载。

| 项目 Project | Download |
|---|---|
| SPI 80M External Loopback | [Download ZIP](https://github.com/Nemophillst/FPGA-Projects/releases/download/01-SPI_80M_EXTERNAL_LOOPBACK/01-SPI_80M_EXTERNAL_LOOPBACK.zip) |
| SPI 80M Block Design | 待发布 |
| Double-Pulse Test | 待发布 |

---

