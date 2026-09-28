# SPI 80 MHz External Loopback FPGA Project

## 1. 项目简介

本工程用于验证 FPGA 上 **80 MHz SPI 全双工通信**，并重点解决高速 SPI 下 **MISO 采样时序裕量不足**的问题。

工程在同一块 FPGA 内同时实现：

- SPI Master
- SPI Slave
- VIO 在线控制
- ILA 在线抓波
- 连续压力测试
- 错误计数与 Timeout 统计

Master 和 Slave **不是直接在 FPGA 内部连线**，而是通过 FPGA IO 引脚引出，再使用外部杜邦线连接，从而让测试包含真实的：

- FPGA 输出 IO 延迟
- FPGA 输入 IO 延迟
- 外部连线传播延迟
- SCLK / MOSI / MISO 实际物理路径

当前稳定版本采用 **静态 Clock Wizard 相位配置**，最终选定的 MISO 采样相位为：

```text
Actual Phase = 236.25°
```

该相位位于当前已验证稳定区的中间附近。

---

## 2. 当前最终状态

### SPI 参数

| 项目 | 当前配置 |
|---|---|
| 系统输入时钟 | 50 MHz |
| SPI 内部工作时钟 | 160 MHz |
| SPI SCLK | 80 MHz |
| 数据宽度 | 8 bit |
| 通信方式 | Full Duplex |
| 默认 SPI Mode | `00` |
| 连续测试帧间隔 | 25 ns |
| 单帧 Timeout | 约 1.6 us |
| 最终 MISO 静态采样相位 | **236.25° Actual** |

80 MHz SPI 的一个 bit 周期为：

```text
Tbit = 1 / 80 MHz = 12.5 ns
```

---

## 3. 最终验证结果

### MISO 静态相位扫描

目前得到的主要结果：

| Actual Phase | 测试结果 |
|---:|---|
| 207.00° | 不稳定，出现 Master RX 错误 |
| 213.75° | 稳定 |
| 225°附近 | 稳定 |
| 236.25° | 稳定，最终候选 |
| 245°附近 | 稳定 |
| 252.00° | 稳定 |
| 261.00° | 稳定 |
| 270.00° | Implementation Setup Timing Fail |

因此当前能够确认：

```text
最后一个已验证错误点：207.00°

第一个已验证稳定点：213.75°

已验证稳定区域：
213.75° ～ 261.00°
```

注意：

```text
270°不是“MISO实测错误点”
```

而是 FPGA 内部跨时钟路径首先出现 Implementation Timing Fail，因此不能把 270°直接当成真实 MISO 数据眼右边界。

### 为什么最终选 236.25°

使用已验证稳定区域：

```text
213.75° ～ 261.00°
```

几何中心约为：

```text
(213.75 + 261.00) / 2
= 237.375°
```

Clock Wizard 在当前配置下可实现的中心附近 Actual Phase 为：

```text
236.25°
```

它距离已验证稳定区域两侧分别约为：

```text
左侧：236.25 - 213.75 = 22.50°

右侧：261.00 - 236.25 = 24.75°
```

因此 236.25°具有较均衡的左右裕量。

### 长时间压力测试

在：

```text
Actual Phase = 236.25°
SPI SCLK     = 80 MHz
```

条件下，已经完成至少以下连续压力测试：

```text
Run 1:
total_count        = 107,220,340
master_error_count = 0
slave_error_count  = 0
timeout_count      = 0

Run 2:
total_count        = 51,982,445
master_error_count = 0
slave_error_count  = 0
timeout_count      = 0
```

因此当前版本在现有开发板、接线和工程实现条件下，已经达到 **上亿帧级连续零错误验证**。

---

## 4. 外部 SPI 接线

当前逻辑关系：

```text
Master                         Slave

J2 SCLK OUT  ----------------> J3 SCLK IN

J2 CS_N OUT  ----------------> J3 CS_N IN

J2 MOSI OUT  ----------------> J3 MOSI IN

J2 MISO IN   <---------------- J3 MISO OUT
```

另外需要连接 GND，使两端具有共同参考地。

实际 FPGA Package Pin、Bank、电平标准请以工程中的 **XDC 文件和开发板原理图**为准，不要根据本 README 猜测具体引脚。

### 硬件连接注意事项

连接前确认：

- J2 与 J3 GND 共地
- IO 电平兼容
- FPGA Bank Voltage 正确
- SCLK / MOSI / MISO / CS_N 方向正确
- 不要把两个输出引脚直接互相连接
- 杜邦线尽量短
- 高速测试时不要随意改变接线长度和位置

---

## 5. 工程主要模块

### `spi_top.vhd`

顶层模块，主要负责：

- Clock Wizard 时钟连接
- Reset 同步
- SPI Master / Slave 实例化
- VIO 控制
- ILA 观察
- 手动单帧测试
- 自动连续压力测试
- 数据比较
- 错误计数
- Timeout 处理

---

### `spi_master_core.vhd`

SPI Master 核。

主要负责：

```text
TX Data
  ↓
按 bit 串行输出 MOSI
  ↓
产生 SCLK / CS_N
  ↓
从 MISO 采样数据
  ↓
组合成 8-bit RX Data
```

80 MHz 下 MISO 是整个工程最敏感的时序路径。

当前最终版本通过 **相移 160 MHz 时钟**调整 MISO 的实际采样位置。

---

### `spi_slave_core.vhd`

SPI Slave 核。

主要负责：

- 接收外部 SCLK
- 接收 MOSI
- 输出 MISO
- 8-bit 串并转换
- RX Valid
- Frame Error
- Slave TX 数据准备

高速 MISO 调试过程中，Slave 的下一位数据准备时刻曾进行过提前调整，以增大 Master 端采样裕量。

---

### `edge_detect.vhd`

用于检测 VIO START：

```text
0 → 1
```

产生单周期启动事件。

---

### `clk_wiz_0`

Clock Wizard。

当前核心作用：

```text
50 MHz sys_clk
      ↓
Clock Wizard
      ├── 160 MHz / 0°
      └── 160 MHz / 236.25° Actual
```

其中：

- `clk_out1`：SPI 主逻辑时钟
- `clk_out2`：MISO 相移采样相关时钟

当前最终工程使用 **静态相位配置**。

---

### `vio_0`

用于 Hardware Manager 中在线修改：

- Reset
- Work Mode
- Start
- Master TX
- Slave TX
- SPI Mode
- Clock Divider

并观察：

- Master RX
- Slave RX
- Busy / Done
- RX Valid
- Frame Error
- Total Count
- Master Error Count
- Slave Error Count
- Timeout Count

---

### `ila_0`

用于实时观察 SPI 内部和外部时序。

主要观察：

```text
Physical SPI:
SCLK
CS_N
MOSI
MISO

Timing:
MISO sample signals

Control:
master_busy
master_done
slave_rx_valid

Data:
master_tx
slave_tx
master_rx
slave_rx

Error:
frame_error
master_error_pulse
slave_error_pulse
timeout_pulse
```

ILA 自身会使用 FPGA 内部存储资源保存抓取波形，但 SPI 用户数据路径本身没有使用 FIFO / BRAM 作为大容量数据缓存。

---

## 6. 两种测试模式

`vio_work_mode`：

### Mode `00`：Manual Single Frame

```text
vio_work_mode = 0
```

用于手动发送单帧数据。

操作方式：

1. 设置 `vio_master_tx`
2. 设置 `vio_slave_tx`
3. 设置 `vio_spi_mode`
4. 设置 `vio_clk_div`
5. `vio_start_v` 做一次 `0 → 1`
6. 查看 `master_rx_data`
7. 查看 `slave_rx_data`

例如：

```text
Master TX = AA
Slave TX  = 55

正确结果：

Master RX = 55
Slave RX  = AA
```

---

### Mode `01`：Automatic Continuous Stress Test

```text
vio_work_mode = 1
```

用于长时间压力测试。

每次新的连续测试从：

```text
Master TX = 00
Slave TX  = FF
```

开始。

之后：

```text
Master TX:
00, 01, 02, 03 ... FF, 00 ...

Slave TX:
FF, FE, FD, FC ... 00, FF ...
```

也就是：

```text
Slave TX = NOT(Master TX)
```

因此连续测试会不断遍历整个 8-bit 数据空间，而不是一直发送固定的 `AA / 55`。

---

## 7. 连续测试的数据检查机制

每一帧结束后：

```text
Expected Slave RX = Master TX

Expected Master RX = Slave TX
                   = NOT(sequence)
```

代码立即比较：

```text
Master RX == Expected Master RX ?

Slave RX  == Expected Slave RX ?
```

如果正确：

```text
total_count += 1
```

如果 Master 接收错误：

```text
master_error_count += 1
master_error_pulse = 1
```

如果 Slave 接收错误：

```text
slave_error_count += 1
slave_error_pulse = 1
```

如果一帧在规定时间内没有完成：

```text
timeout_count += 1
timeout_pulse = 1
```

### 错误统计单位

`master_error_count` 和 `slave_error_count` 统计的是：

```text
错误帧数量
```

不是错误 bit 数。

例如一个 8-bit Byte 只错 1 bit，也记为：

```text
1 erroneous frame
```

---

## 8. 连续测试状态机

自动模式主要包含：

```text
AUTO_IDLE
    ↓
AUTO_WAIT_FRAME
    ↓
AUTO_GAP
    ↓
下一帧
```

异常时进入：

```text
AUTO_RECOVER
```

### `AUTO_IDLE`

等待：

```text
vio_start_v : 0 → 1
```

并初始化：

```text
Master TX = 00
Slave TX  = FF
```

同时清零：

```text
total_count
master_error_count
slave_error_count
timeout_count
```

---

### `AUTO_WAIT_FRAME`

等待：

```text
master_done
+
slave_rx_valid
```

两者可能不在同一个 160 MHz 周期出现，因此分别用标志保存。

两端都完成后进行严格数据比较。

---

### `AUTO_GAP`

连续帧之间保留：

```text
4 × 160 MHz Clock
= 4 × 6.25 ns
= 25 ns
```

的帧间隔。

---

### `AUTO_RECOVER`

如果发生 Timeout，并且 Master 仍然处于 Busy：

```text
等待 Master 回到 idle
```

再安全开始下一帧。

---

## 9. Timeout

每帧最大等待：

```text
256 × 6.25 ns
≈ 1.6 us
```

正常 80 MHz、8-bit SPI Frame 明显短于该值。

因此：

```text
timeout_count > 0
```

通常意味着：

- Master 未正常结束
- Slave 未正常产生 RX Valid
- 时序错误影响了状态机
- SPI 帧发生异常

最终稳定版本的长时间测试中：

```text
timeout_count = 0
```

---

## 10. VIO 推荐显示顺序

Hardware Manager 中建议按如下顺序排列。

### 基本控制

```text
vio_rst_n_v
vio_start_v
vio_work_mode
```

### SPI 参数

```text
vio_clk_div
vio_spi_mode
vio_master_tx
vio_slave_tx
```

### SPI 状态

```text
master_busy
master_done
slave_rx_valid
frame_error
```

### RX 数据

```text
master_rx_data
slave_rx_data
```

### 连续测试统计

```text
total_count
master_error_count
slave_error_count
timeout_count
```

计数器建议设置为：

```text
Radix = Unsigned Decimal
```

TX / RX 数据可根据需要使用：

```text
Hexadecimal
```

或：

```text
Unsigned Decimal
```

---

## 11. ILA 推荐信号顺序

建议 Wave 窗口从上到下：

```text
j3_sclk_in
j3_cs_n_in
j3_mosi_in
j2_miso_in

miso_sample_0
miso_sample_shift

master_sclk
master_cs_n
master_busy
master_done
slave_rx_valid

master_tx_cfg
slave_tx_cfg
master_rx_data
slave_rx_data
slave_debug

frame_error
master_error_pulse
slave_error_pulse
timeout_pulse
```

调试错误时，可以将：

```text
master_error_pulse
```

设置为 ILA Trigger，从而直接抓住 Master RX 出错的帧。

---

## 12. Vivado 构建流程

推荐始终按照：

```text
RTL
↓
Behavioral Simulation
↓
Run Synthesis
↓
Run Implementation
↓
Report Timing Summary
↓
Generate Bitstream
↓
Hardware Manager
↓
Program Device
↓
VIO / ILA
```

### Implementation 后必须检查

至少确认：

```text
WNS > 0
TNS = 0

WHS > 0
THS = 0

Failing Endpoints = 0
```

如果 Timing 未通过，不建议直接把该 Bitstream 当成可靠高速测试结果。

---

## 13. MISO 时序问题的调试过程

80 MHz 最初的问题主要集中在：

```text
Slave MISO 准备太晚
+
Master MISO 采样太早
```

结果容易读到上一 bit 或错误 bit。

解决思路：

```text
Slave 更早准备下一位 MISO
        +
Master 使用相移时钟重新选择采样位置
```

单帧能够成功后，又进一步加入：

```text
Continuous Stress Test
+
Error Counter
+
Phase Sweep
```

避免仅根据一次 `AA / 55` 成功就认为整个接口稳定。

---

## 14. 为什么使用“稳定区域”，而不是追求唯一中心点

真实硬件会受到：

- FPGA IO 延迟
- 路由延迟
- 时钟抖动
- 温度变化
- 电压变化
- 连线传播延迟
- 工艺差异

影响。

因此工程目标不是寻找一个绝对唯一的“数学中心点”，而是：

```text
找到一段连续稳定区域
        ↓
尽量选择该区域内部
        ↓
远离左右边界
```

当前已验证稳定区域：

```text
213.75° ～ 261.00°
```

最终选择：

```text
236.25°
```

作为保守中心附近的工作相位。

---

## 15. Dynamic Phase Shift 实验

项目过程中曾尝试 Clock Wizard：

```text
Dynamic Phase Shift
```

实现上板后通过 VIO 实时改变 `clk_out2` 相位。

动态移相控制本身已经验证：

```text
+1 step  OK
-1 step  OK
PSDONE   OK
LOCKED   OK
```

但该方案最终 **没有作为当前正式版本使用**。

原因是：

```text
clk_out2
↓
MISO采样寄存器
↓
clk_out1主逻辑
```

存在真实跨时钟路径。

运行时动态改变 `clk_out2` 后：

```text
clk_out2 与 clk_out1 的内部 Setup/Hold 关系也同时变化
```

因此动态扫描得到的错误可能同时包含：

1. 外部 MISO 数据眼错误
2. FPGA 内部跨时钟 Timing 错误

二者无法干净区分。

所以当前正式版本回到：

```text
Static Clock Wizard Phase
+
每个相位重新 Synthesis / Implementation
+
检查 Timing
+
上板压力测试
```

虽然速度较慢，但测试结果更可信。

---



## 16. 当前项目结论

当前工程已经实现：

```text
50 MHz系统时钟
↓
160 MHz内部时钟
↓
80 MHz SPI
↓
外部IO回环
↓
Master / Slave双向通信
↓
VIO控制
↓
ILA抓波
↓
自动连续压力测试
↓
错误统计
↓
MISO静态相位扫描
```

最终稳定配置：

```text
SPI SCLK           = 80 MHz
MISO Actual Phase  = 236.25°
Data Width         = 8 bit
Continuous Pattern = 00→FF / FF→00 complementary sequence
```

已完成上亿帧量级连续零错误验证。

---


## 17. 重要说明

本工程中的：

```text
236.25°
213.75°～261°
```

都是在当前：

- FPGA 器件
- Vivado 工程
- Place & Route
- IO 配置
- 杜邦线连接
- 电源与测试环境

条件下得到的实测结果。

如果修改：

- FPGA 开发板
- FPGA Part
- XDC
- Clock Wizard
- RTL
- ILA / VIO
- IO 引脚
- 外部线长
- Implementation 结果

都应该重新执行：

```text
Timing Check
+
Hardware Stress Test
```

不要直接假定原来的最佳相位仍然有效。
