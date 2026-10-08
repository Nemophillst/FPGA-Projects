
# FPGA-Projects

A collection of FPGA projects for learning, development, and hardware verification.

---

## 📖 项目总览 · Project Overview

| 项目 Project | 开发平台 Platform | 开发环境 Dev Env | HDL / 核心技术 Tech |
|---|---|---|---|
| [1. 双脉冲测试 · Double-Pulse Test](./01-Double-Pulse-Test/) | FPGA | Vivado | Verilog · Double-Pulse · PWM · VIO / ILA |
| [2. SPI通信 · SPI Communication](./02-SPI%20Communication/) | FPGA | Vivado | VHDL · SPI · 80 MHz · External Loopback · Block Design · VIO / ILA |

---

## 🛠️ 开发环境 · Development Environment

| Tool | Purpose |
|---|---|
| Vivado | FPGA设计、综合、实现和时序分析 |
| Verilog / VHDL | RTL设计 |
| Vivado Simulator | 功能仿真 |
| ILA | FPGA在线逻辑调试 |
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
│       └── update-fpga-zips.yml
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

各项目的源码可通过项目目录查看。

独立 Vivado 工程压缩包可通过 GitHub Releases 下载，无需下载整个仓库。

| 项目 Project | Download |
|---|---|
| 01. Double-Pulse Test | [Download ZIP](https://github.com/Nemophillst/FPGA-Projects/releases/download/01-Double-Pulse-Test/01-Double-Pulse-Test.zip) |
| 02-01. SPI 80M External Loopback | [Download ZIP](https://github.com/Nemophillst/FPGA-Projects/releases/download/02-01-SPI_80M_EXTERNAL_LOOPBACK/01-SPI_80M_EXTERNAL_LOOPBACK.zip) |
| 02-02. SPI 80M Block Design | [Download ZIP](https://github.com/Nemophillst/FPGA-Projects/releases/download/02-02-SPI_80M_BLOCK_DESIGN/02-SPI_80M_BLOCK_DESIGN.zip) |

[View All Releases](https://github.com/Nemophillst/FPGA-Projects/releases)

---

## 🔄 自动更新 · Automatic ZIP Updates

本仓库使用 GitHub Actions 自动更新工程压缩包。

当项目文件更新并推送到 `main` 分支时，GitHub Actions 将：

1. 检测发生变化的 FPGA 项目。
2. 从最新仓库文件生成对应工程 ZIP。
3. 检查 ZIP 文件完整性。
4. 更新对应 GitHub Release 的 ZIP 附件。

各工程使用固定下载链接，方便独立下载最新打包内容。

**注意：** 自动打包不代表工程已通过 Vivado 仿真、综合或硬件验证。

---

## 📝 使用说明 · Usage

1. 通过上方 Download ZIP 下载所需工程。
2. 解压 ZIP 文件。
3. 使用兼容版本的 Vivado 打开对应 `.xpr` 工程文件。
4. 必要时重新生成 IP Output Products。
5. 根据项目 README 完成仿真、综合、实现和硬件验证。

Vivado 自动生成的缓存、仿真及实现中间文件由 `.gitignore` 过滤，不包含在 GitHub 下载包中。

---
