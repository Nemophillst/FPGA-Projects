############################################################
# 50 MHz系统时钟
############################################################

set_property PACKAGE_PIN R4 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk]

create_clock -period 20.000 -name sys_clk [get_ports sys_clk]


############################################################
# 复位按键
# 低电平有效
############################################################

set_property PACKAGE_PIN U2 [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports sys_rst_n]


############################################################
# KEY0
# 第一脉冲宽度减小
############################################################

set_property PACKAGE_PIN T1 [get_ports key0_n]
set_property IOSTANDARD LVCMOS33 [get_ports key0_n]


############################################################
# KEY1
# 第一脉冲宽度增加
############################################################

set_property PACKAGE_PIN U1 [get_ports key1_n]
set_property IOSTANDARD LVCMOS33 [get_ports key1_n]


############################################################
# KEY2
# 预使能
############################################################

set_property PACKAGE_PIN W2 [get_ports key2_n]
set_property IOSTANDARD LVCMOS33 [get_ports key2_n]


############################################################
# KEY3
# 单次双脉冲触发
############################################################

set_property PACKAGE_PIN T3 [get_ports key3_n]
set_property IOSTANDARD LVCMOS33 [get_ports key3_n]


############################################################
# LED0
# 显示预使能状态
############################################################

set_property PACKAGE_PIN R2 [get_ports led0]
set_property IOSTANDARD LVCMOS33 [get_ports led0]


############################################################
# 双脉冲输出
# J2扩展口对应FPGA引脚M13
############################################################

set_property PACKAGE_PIN M13 [get_ports pulse_out]
set_property IOSTANDARD LVCMOS33 [get_ports pulse_out]


