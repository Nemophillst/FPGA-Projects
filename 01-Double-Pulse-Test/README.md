# FPGA 单次可调双脉冲发生器

本项目用 FPGA 产生一组非周期的数字双脉冲：第一脉冲有五档可选，两脉冲之间保持低电平 5.00 µs，第二脉冲固定为 5.00 µs。可以通过开发板实体按键或 Vivado VIO 设置档位、预使能并单次触发；输出结束后自动取消预使能，`pulse_out` 保持低电平，直到再次预使能和触发。

本项目输出的是 FPGA 逻辑电平时序。用于功率器件双脉冲测试时，后级仍需数字隔离器和栅极驱动器，不能将 `pulse_out` 直接作为功率器件的栅极驱动。

## 时序指标

设计使用 50 MHz 时钟，每个时钟周期为 20 ns。当前 RTL 中第一脉冲的五档如下；此表以当前实现为准，替代早期任务文档中 5 / 10 / 15 / 20 / 25 µs 的标称值。

| `width_level` | 第一脉冲时钟周期数 | 第一脉冲宽度 |
| --- | ---: | ---: |
| 0（复位默认） | 252 | 5.04 µs |
| 1 | 504 | 10.08 µs |
| 2 | 756 | 15.12 µs |
| 3 | 1008 | 20.16 µs |
| 4 | 1260 | 25.20 µs |

两个脉冲之间的低电平间隔为 250 个时钟周期（5.00 µs），第二脉冲高电平为 250 个时钟周期（5.00 µs）。输出顺序为 `空闲低电平 → 第一脉冲高电平 → 间隔低电平 → 第二脉冲高电平 → 空闲低电平`；每次有效触发只输出一组。

这些时间是 FPGA 内部同步逻辑的设计值；外部引脚及后级电路的实际波形应以示波器测量为准。

## 控制方法

四个实体按键和四个 VIO 输出分别对应相同的操作：

| 操作 | 实体按键 | VIO 输出 | 作用 |
| --- | --- | --- | --- |
| 减小档位 | `KEY0` / `key0_n` | `probe_out0` | 第一脉冲宽度降低一档，最低为 0 |
| 增加档位 | `KEY1` / `key1_n` | `probe_out1` | 第一脉冲宽度增加一档，最高为 4 |
| 预使能或取消 | `KEY2` / `key2_n` | `probe_out2` | 切换 `armed` 状态 |
| 单次触发 | `KEY3` / `key3_n` | `probe_out3` | 在 `armed=1` 时输出一组双脉冲 |

使用顺序：复位后选择档位 → 预使能（`led0` 亮、`armed=1`）→ 单次触发 → 等待输出结束。输出结束时 `done` 产生一个时钟周期的完成信号，`armed` 自动清零；下一次输出需要重新预使能。只有在未预使能且空闲时才能改变档位。触发开始时，核心会锁存当前第一脉冲周期数，输出过程中不会改变本组波形。

实体按键为低电平按下，经过两级同步和默认 20 ms 消抖后，每次按下产生一个事件。VIO 使用 `0 → 1` 上升沿产生事件；每次操作后应将对应 `probe_out` 恢复为 `0`，再置 `1` 才能再次触发。VIO 的四个 `probe_in` 依次显示 `width_level`、`armed`、`busy` 和 `done`。两种控制输入在顶层合并，可交替使用。

## 工程打开与验证

1. 用 Vivado 2024.1 打开 [`double_pulse_project/double_pulse_project.xpr`](double_pulse_project/double_pulse_project.xpr)。工程器件为 `xc7a35tfgg484-2`，综合顶层为 `double_pulse_top`。
2. 在 **Run Simulation → Run Behavioral Simulation** 中运行仿真顶层 `tb_double_pulse_core`。测试平台依次触发五档，并打印第一脉冲、间隔和第二脉冲的时间。测试平台只验证 `double_pulse_core`，不覆盖实体按键消抖、VIO 或外部引脚。
3. 在连接对应硬件后生成或使用工程中的 bitstream，通过 Hardware Manager 下载。可用实体按键或 VIO 操作，用 ILA 查看 `state`、锁存的第一脉冲周期数、档位、控制事件和 `pulse_out`。`pulse_out` 的引脚位置及电平标准见约束文件；外部波形可用示波器测量。

当前工程已有 [`仿真日志`](double_pulse_project/double_pulse_project.sim/sim_1/behav/xsim/simulate.log)，其中五档第一脉冲分别为 5.040 / 10.080 / 15.120 / 20.160 / 25.200 µs，五次的间隔和第二脉冲均为 5.000 µs。项目中的 [`结果展示.docx`](结果展示.docx) 收录了仿真、ILA 调试和示波器展示材料；这些材料与仿真日志分别用于查看波形，不应把仿真打印值当作外部引脚实测值。

## 文件说明

| 文件 | 用途 |
| --- | --- |
| [`double_pulse_top.v`](double_pulse_project/double_pulse_project.srcs/sources_1/new/double_pulse_top.v) | 顶层接口，合并按键与 VIO 事件，连接 VIO、ILA 和输出 |
| [`double_pulse_core.v`](double_pulse_project/double_pulse_project.srcs/sources_1/new/double_pulse_core.v) | 五档选择、预使能、单次触发和双脉冲状态机 |
| [`key_debounce.v`](double_pulse_project/double_pulse_project.srcs/sources_1/new/key_debounce.v) | 实体按键同步、消抖和单次按下事件 |
| [`tb_double_pulse_core.v`](double_pulse_project/double_pulse_project.srcs/sim_1/new/tb_double_pulse_core.v) | 核心模块五档行为仿真 |
| [`double_pulse.xdc`](double_pulse_project/double_pulse_project.srcs/constrs_1/new/double_pulse.xdc) | 50 MHz 时钟、按键、LED 与输出引脚约束 |
| `ila_0.xci`、`vio_0.xci` | Vivado ILA 与 VIO IP 配置 |

外部接口约束为：`sys_clk` R4，`sys_rst_n` U2，`KEY0` T1，`KEY1` U1，`KEY2` W2，`KEY3` T3，`led0` R2，`pulse_out` M13（约束文件注释标为 J2 扩展口）；上述端口均使用 `LVCMOS33`。复位 `sys_rst_n` 为低电平有效，复位时默认档位为 0、预使能关闭、输出为低电平。
