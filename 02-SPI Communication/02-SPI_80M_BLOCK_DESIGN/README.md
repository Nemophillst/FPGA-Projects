# 02-SPI_80M_BLOCK_DESIGN

基于 Vivado IP Integrator 的 **80 MHz SPI 外部回环工程**。同一颗 FPGA 内实现 SPI Master 和 SPI Slave，通过 J2、J3 对应的外部 IO 和杜邦线完成全双工通信，使用 VIO 控制测试、ILA 观察波形。

本版本将 `01-SPI_80M_EXTERNAL_LOOPBACK` 的 RTL 顶层集成迁移到 Block Design。当前综合顶层为 **`spi_bd_wrapper`**，Block Design 为 **`spi_bd`**。原 `spi_top.vhd` 仍在工程中保留，供对照使用。


## 1. 当前配置

| 项目 | 配置 |
| --- | --- |
| Vivado | 2024.1，原工程在 Windows 下构建 |
| FPGA | `xc7a35tfgg484-2` |
| 工程入口 | `spi_project/spi_project.xpr` |
| 综合顶层 | `spi_bd_wrapper` |
| Block Design | `spi_bd`，共 12 个模块 |
| 输入时钟 | 50 MHz |
| 主逻辑时钟 | 160 MHz，0° |
| MISO 采样相关时钟 | 160 MHz，实际相位 236.25° |
| Clock Wizard 请求相位 | 237°；实现值为 236.25° |
| SPI 数据宽度 | 8 bit，全双工 |
| 已验证 SPI 模式 | SPI Mode 0，`i_spi_mode = 00` |
| SPI SCLK | 分频值 1 时为 80 MHz |
| 自动测试间隔设置 | 4 个主时钟周期，即 25 ns；实际片选间隔还包含控制状态转换开销 |
| 自动测试 Timeout | 256 个主时钟周期，约 1.6 μs |
| VIO | 7 路输出，10 路输入 |
| ILA | 20 路探针，采样深度 2048，输入流水级数 0，采样时钟 160 MHz |

SPI 时钟关系为 `f_SCLK = 160 MHz / (2 × clk_div)`，80 MHz 测试使用 `clk_div = 1`。测试控制器会将输入分频值 0 修正为 1。

本版本采用静态相位设置。修改 Clock Wizard 相位后，需要重新生成输出产物、综合、实现和上板测试。

## 2. 与原 RTL 工程的区别

| 项目 | 原 RTL 工程 | 本 Block Design 工程 |
| --- | --- | --- |
| 顶层 | `spi_top` | `spi_bd_wrapper` |
| 顶层连接 | 在 VHDL 中实例化和连线 | 在 `spi_bd.bd` 中连接模块和 IP |
| SPI Master / Slave | VHDL 核心 | 通过 Module Reference 使用相同核心 |
| 复位、边沿检测、测试控制 | VHDL 模块 | 通过 Module Reference 使用相同模块 |
| MISO 两路观察采样 | 写在原顶层内 | 拆为 `miso_observer.vhd`，实例 `miso_observer_0` |
| Clock Wizard / VIO / ILA | 独立 IP 实例 | BD 内 IP 实例 |
| XDC 内部层级 | 原顶层实例层级 | `spi_bd_i/...` 层级 |
| SPI 外部回环 | 通过 IO 和外部连线 | 保持相同方式 |

本版本复用原工程的 `spi_master_core.vhd`、`spi_slave_core.vhd`、`reset_sync.vhd`、`edge_detect.vhd` 和 `spi_test_controller.vhd`，主要调整顶层集成方式、观察模块封装以及约束层级。

`miso_observer` 的两路采样分别使用 0° 主时钟和 236.25° 相移时钟，用于 ILA 观察。原工程已有这两路观察逻辑；本版本将它们封装成独立模块。

## 3. 工程结构

### 主要文件

以下路径相对于项目根目录：

| 文件 | 作用 |
| --- | --- |
| `spi_project/spi_project.xpr` | Vivado 工程入口 |
| `spi_project/spi_project.srcs/sources_1/bd/spi_bd/spi_bd.bd` | 顶层 Block Design |
| `spi_project/spi_project.srcs/sources_1/imports/rtl/spi_master_core.vhd` | SPI Master 核心 |
| `spi_project/spi_project.srcs/sources_1/imports/rtl/spi_slave_core.vhd` | SPI Slave 核心 |
| `spi_project/spi_project.srcs/sources_1/imports/rtl/edge_detect.vhd` | START 上升沿检测 |
| `spi_project/spi_project.srcs/sources_1/new/reset_sync.vhd` | 复位同步 |
| `spi_project/spi_project.srcs/sources_1/new/spi_test_controller.vhd` | 测试控制与错误统计 |
| `spi_project/spi_project.srcs/sources_1/new/miso_observer.vhd` | 两路 MISO 观察采样 |
| `spi_project/spi_project.srcs/constrs_1/new/spi_top.xdc` | IO 与时序约束 |

`spi_bd_wrapper` 由 Vivado 根据 BD 生成。原 `spi_top.vhd` 保留为 RTL 集成参考，当前综合使用 BD 顶层。

### BD 实例

| 实例 | 作用 |
| --- | --- |
| `clk_wiz_0` | 从 50 MHz 产生两路 160 MHz 时钟 |
| `util_vector_logic_0` | 对外部低有效复位取反，连接 Clock Wizard 的高有效复位 |
| `util_vector_logic_1` | 合并外部 `sys_rst_n` 和 VIO 低有效复位控制 |
| `util_vector_logic_2` | 将上述复位条件与 Clock Wizard `locked` 合并 |
| `reset_sync_0` | 复位异步置位、同步释放 |
| `edge_detect_0` | 检测 START 的上升沿 |
| `spi_test_controller_0` | 手动单帧、自动连续测试、数据比较和统计 |
| `spi_master_core_0` | 输出 SCLK、CS_N、MOSI，并接收 MISO |
| `spi_slave_core_0` | 根据外部返回的 SCLK、CS_N、MOSI 接收数据并输出 MISO |
| `miso_observer_0` | 两路 MISO 观察采样 |
| `vio_0` | 在线控制和状态、计数显示 |
| `ila_0` | 捕获 SPI 和测试控制波形 |

`clk_out1` 连接主逻辑、VIO、ILA 和观察模块的主时钟输入；`clk_out2` 连接 Master 的 `i_clk_shift` 和观察模块的相移时钟输入。

逻辑复位的释放条件为：`sys_rst_n = 1`、VIO `probe_out0 = 1`、Clock Wizard `locked = 1`，再由 `reset_sync_0` 同步释放。VIO 输出初始值为 0，因此下载后先将 `probe_out0` 设置为 1。

## 4. 外部连接与 FPGA 引脚

Master 和 Slave 的 SPI 信号经过外部连线返回 FPGA。连接如下：

| 信号 | 输出端 | 输入端 |
| --- | --- | --- |
| SCLK | `j2_sclk_out` | `j3_sclk_in` |
| CS_N | `j2_cs_n_out` | `j3_cs_n_in` |
| MOSI | `j2_mosi_out` | `j3_mosi_in` |
| MISO | `j3_miso_out` | `j2_miso_in` |

共用地参考，使用短连线。连接器针脚位置需对照开发板原理图；下表中的 FPGA Package Pin 不是连接器排针序号。

| 顶层端口 | 方向 | FPGA Package Pin |
| --- | --- | --- |
| `sys_clk` | 输入 | R4 |
| `sys_rst_n` | 输入，低有效 | U2 |
| `j2_sclk_out` | 输出 | E19 |
| `j2_cs_n_out` | 输出 | H22 |
| `j2_mosi_out` | 输出 | G22 |
| `j2_miso_in` | 输入 | G21 |
| `j3_sclk_in` | 输入 | V18 |
| `j3_cs_n_in` | 输入 | AB6 |
| `j3_mosi_in` | 输入 | AB8 |
| `j3_miso_out` | 输出 | AA8 |

当前 XDC 对上述端口使用 `LVCMOS33`，并设置 `CFGBVS = VCCO`、`CONFIG_VOLTAGE = 3.3`。约束文件为 `spi_project/spi_project.srcs/constrs_1/new/spi_top.xdc`；文件名保留历史名称，内容已适配 BD 顶层。

## 5. 打开、构建与下载

1. 克隆或下载仓库，使用 Vivado 2024.1 打开 `spi_project/spi_project.xpr`。
2. 确认器件为 `xc7a35tfgg484-2`，Design Sources 顶层为 `spi_bd_wrapper`。
3. 打开 `spi_bd`，执行 **Validate Design**，保存。
4. 右键 `spi_bd` 执行 **Generate Output Products**。如果缺少顶层 wrapper，执行 **Create HDL Wrapper**，选择 **Let Vivado manage wrapper and auto-update**，将 `spi_bd_wrapper` 设置为顶层。
5. 执行 **Run Synthesis**、**Run Implementation**，检查 **Report Timing Summary**。
6. 执行 **Generate Bitstream**。
7. 在 **Hardware Manager → Program Device** 中选择同一次实现产生的 `.bit` 和 `.ltx`。

生成后的下载文件位于：

- `spi_project/spi_project.runs/impl_1/spi_bd_wrapper.bit`
- `spi_project/spi_project.runs/impl_1/spi_bd_wrapper.ltx`

下载时使用同一次实现生成的 `spi_bd_wrapper.bit` 和 `spi_bd_wrapper.ltx`，后者用于匹配 VIO / ILA 调试探针。

工程的硬件验证使用 VIO / ILA。目前尚未配置针对 BD 顶层的独立仿真 testbench。

如果打开工程后提示旧增量综合参考 `spi_top.dcp` 缺失，清除 `synth_1` 的历史检查点设置，再执行普通综合。

## 6. VIO 探针与操作

以下表格按 BD 探针编号列出，Hardware Manager 的显示顺序可以自行调整。综合后的网名可能带有 `spi_bd_i/` 前缀、总线范围或数字后缀，以探针编号和所连信号识别。

### 控制输出

| VIO 探针 | 位宽 | 含义 | 手动测试设置 |
| --- | ---: | --- | --- |
| `probe_out0` | 1 | 逻辑复位 `reset_n` | 1：释放；0：复位 |
| `probe_out1` | 2 | 工作模式 | `00`：手动；`01`：自动 |
| `probe_out2` | 1 | START | 初始为 0 |
| `probe_out3` | 8 | Master TX | `A5`，十六进制 |
| `probe_out4` | 8 | Slave TX | `3C`，十六进制 |
| `probe_out5` | 2 | SPI Mode | `00` |
| `probe_out6` | 16 | Clock Divider | `0001`，十六进制 |

START 同时连接 `edge_detect_0/i_sig` 和测试控制器的 `i_start_level`。Hardware Manager 中它可能显示为 `spi_bd_i/i_sig`。

### 状态输入

| VIO 探针 | 位宽 | 含义 |
| --- | ---: | --- |
| `probe_in0` | 8 | Master RX |
| `probe_in1` | 8 | Slave RX |
| `probe_in2` | 1 | Master Busy |
| `probe_in3` | 1 | Master Done |
| `probe_in4` | 1 | Slave RX Valid |
| `probe_in5` | 1 | Slave Frame Error |
| `probe_in6` | 32 | `total_count` |
| `probe_in7` | 32 | `master_error_count` |
| `probe_in8` | 32 | `slave_error_count` |
| `probe_in9` | 32 | `timeout_count` |

TX / RX 建议显示为 Hexadecimal，计数器显示为 Unsigned Decimal。推荐排列：7 路控制、2 路 RX、4 路状态、4 路计数。

### 手动单帧测试

1. 将 START 设置为 0，释放复位，将工作模式设置为 `00`。
2. 设置 Master TX = `A5`、Slave TX = `3C`、SPI Mode = `00`、Divider = `0001`。
3. 将 START 从 0 改为 1，触发一帧；再改回 0，为下一次触发准备。
4. 正确结果为 **Master RX = `3C`，Slave RX = `A5`**。

手动模式不执行自动测试的比较、累计统计。Done 和 RX Valid 是短脉冲，VIO 刷新时经常看见 0；需要用 ILA 观察这些脉冲。

### 自动连续测试

1. 保持 START = 0，释放复位，将工作模式设为 `01`，SPI Mode = `00`、Divider = `0001`。
2. 将 START 从 0 改为 1，并保持 1。新的自动测试会清零四个计数器。
3. Master TX 从 `00` 递增到 `FF` 后循环；Slave TX 为逐位取反的 `FF` 到 `00` 循环。自动模式不采用 VIO 设置的固定 TX 字节。
4. 查看总帧数和三项错误计数。自动运行中两路 RX 的 VIO 显示可能来自不同帧，应以控制器统计判断。
5. 将 START 设为 0，等待当前帧处理结束、Busy 回到 0、总数停止变化，再保存最终计数。

Master 和 Slave 完成脉冲分别锁存，收齐后比较数据。Master / Slave 错误计数统计的是错误帧数；一个字节中多个 bit 出错仍计为一帧错误。`total_count` 包括正常处理完成以及超时处理的帧。

Timeout 后，如果 Master 仍 Busy，控制器等待恢复空闲。Timeout 固定约 1.6 μs；大幅降低 SPI 频率时，需检查正常帧耗时是否超过该值。

## 7. ILA 探针与排列

| 探针 | 位宽 | 所连信号 |
| --- | ---: | --- |
| `probe0` | 1 | `j3_sclk_in`，外部返回 SCLK |
| `probe1` | 1 | `j3_cs_n_in`，外部返回 CS_N |
| `probe2` | 1 | `j3_mosi_in` |
| `probe3` | 1 | `j2_miso_in` |
| `probe4` | 1 | `miso_observer_0/o_sample_0` |
| `probe5` | 1 | `miso_observer_0/o_sample_shift` |
| `probe6` | 1 | Master `o_sclk` |
| `probe7` | 1 | Master `o_cs_n` |
| `probe8` | 1 | Master `o_busy` |
| `probe9` | 1 | Master `o_done` |
| `probe10` | 1 | Slave `o_rx_valid` |
| `probe11` | 8 | 控制器 `o_master_tx_cfg` |
| `probe12` | 8 | 控制器 `o_slave_tx_cfg` |
| `probe13` | 8 | Master `o_rx_data` |
| `probe14` | 8 | Slave `o_rx_data` |
| `probe15` | 8 | Slave `o_debug` |
| `probe16` | 1 | Slave `o_frame_error` |
| `probe17` | 1 | 控制器 `o_master_error_pulse` |
| `probe18` | 1 | 控制器 `o_slave_error_pulse` |
| `probe19` | 1 | 控制器 `o_timeout_pulse` |

推荐 Wave 窗口顺序：SCLK 输出与返回、CS_N 输出与返回、MOSI、MISO、两路 MISO 采样、Master TX 与 Slave RX、Slave TX 与 Master RX、Busy / Done / RX Valid、Frame Error / Debug、三路错误脉冲。

捕获单帧可用 CS_N 下降沿触发；定位错误可用 `o_master_error_pulse`、`o_slave_error_pulse` 或 `o_timeout_pulse` 触发。ILA 使用 160 MHz 时钟采样，波形用于逻辑调试，不用于测量模拟信号质量。

## 8. 时序约束与验证结果

### 时钟与 CDC

50 MHz 输入时钟约束由 Clock Wizard 提供。项目 XDC 定义 Master 80 MHz 生成时钟 `spi_sclk_clk`，并在 `j3_sclk_in` 定义返回时钟 `spi_sclk_return_clk`，周期均为 12.5 ns。

本工程保留原版本将返回 SCLK 与内部两路 160 MHz 时钟按异步关系处理的模型；内部 0° 和相移时钟保持相关关系。Slave 的 CDC 例外查询已适配 `spi_bd_i/spi_slave_core_0/...` 层级。

CDC 例外针对 Slave 接收数据保持寄存器到主时钟域数据寄存器的路径，以及接收完成 toggle 到第一级同步寄存器的路径。内部两路 160 MHz 时钟之间的路径仍参与时序分析。

### 实现后时序

实现结果，设计顶层为 `spi_bd_wrapper`，时序报告状态为 Routed：

| 指标 | 数值 |
| --- | ---: |
| WNS | +0.103 ns |
| TNS | 0.000 ns |
| Setup Failing Endpoints | 0 |
| WHS | +0.056 ns |
| THS | 0.000 ns |
| Hold Failing Endpoints | 0 |
| WPWS / TPWS | 0.000 / 0.000 ns |
| Pulse Width Failing Endpoints | 0 |

### 硬件测试

测试配置：80 MHz、SPI Mode 0、8-bit 全双工、MISO 实际相位 236.25°，使用外部 IO 回环。

- 手动测试：Master TX = `A5`、Slave TX = `3C`，收到 Master RX = `3C`、Slave RX = `A5`。
- 自动测试运行中的记录：`total_count = 58,145,536`，`master_error_count = 0`、`slave_error_count = 0`、`timeout_count = 0`。

上述结果对应当前开发板、接线和实现配置。

## 9. MISO 采样相位选择

80 MHz 下，一个 SPI bit 周期为 12.5 ns。Slave 输出 MISO 后，信号还需经过 IO 和外部连线返回 Master，采样位置会影响接收裕量。工程通过调整 Slave 下一位数据的准备时刻，并使用相移时钟采样 MISO，提高接收稳定性。

本版本沿用原 RTL 工程选定的 236.25° 静态相位。相位选择依据来自原 RTL 版本的扫描记录：

| 原版本 Actual Phase | 历史结果 |
| --- | --- |
| 207° | 出现 Master RX 错误 |
| 213.75°～261° | 多个已测相位点运行稳定 |
| 236.25° | 选定的静态工作相位 |
| 270° | 实现阶段 Setup Timing 不通过，不能作为外部 MISO 数据眼的实测右边界 |

相位选择与开发板、IO、外部连线和布局布线相关。修改硬件接线、RTL、时钟设置或调试资源后，应重新检查实现时序并进行上板验证。

