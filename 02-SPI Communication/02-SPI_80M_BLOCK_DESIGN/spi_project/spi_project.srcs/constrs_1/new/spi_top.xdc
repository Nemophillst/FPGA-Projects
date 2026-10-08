# ============================================================
# SPI 80 MHz External Loopback - Block Design
#
# Top: spi_bd_wrapper
# FPGA: xc7a35tfgg484-2
#
# Input clock: 50 MHz
# clk_out1: 160 MHz / 0 degree
# clk_out2: 160 MHz / actual 236.25 degrees
#
# Clock Wizard supplies the input clock constraint.
# ============================================================


# ============================================================
# 1. Board clock and active-low reset
# ============================================================

set_property -dict {
    PACKAGE_PIN R4
    IOSTANDARD LVCMOS33
} [get_ports sys_clk]

set_property -dict {
    PACKAGE_PIN U2
    IOSTANDARD LVCMOS33
} [get_ports sys_rst_n]


# ============================================================
# 2. J2 - Master physical interface
# ============================================================

set_property -dict {
    PACKAGE_PIN E19
    IOSTANDARD LVCMOS33
} [get_ports j2_sclk_out]

set_property -dict {
    PACKAGE_PIN H22
    IOSTANDARD LVCMOS33
} [get_ports j2_cs_n_out]

set_property -dict {
    PACKAGE_PIN G22
    IOSTANDARD LVCMOS33
} [get_ports j2_mosi_out]

set_property -dict {
    PACKAGE_PIN G21
    IOSTANDARD LVCMOS33
} [get_ports j2_miso_in]


# ============================================================
# 3. J3 - Slave physical interface
# ============================================================

set_property -dict {
    PACKAGE_PIN V18
    IOSTANDARD LVCMOS33
} [get_ports j3_sclk_in]

set_property -dict {
    PACKAGE_PIN AB6
    IOSTANDARD LVCMOS33
} [get_ports j3_cs_n_in]

set_property -dict {
    PACKAGE_PIN AB8
    IOSTANDARD LVCMOS33
} [get_ports j3_mosi_in]

set_property -dict {
    PACKAGE_PIN AA8
    IOSTANDARD LVCMOS33
} [get_ports j3_miso_out]


# ============================================================
# 4. FPGA configuration voltage
# ============================================================

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]


# ============================================================
# 5. Master SPI generated clock
#
# Timing model for CLK_DIV = 1:
# 160 MHz / 2 = 80 MHz
# ============================================================

create_generated_clock \
    -name spi_sclk_clk \
    -source [get_pins spi_bd_i/spi_master_core_0/i_clk] \
    -divide_by 2 \
    [get_pins spi_bd_i/spi_master_core_0/o_sclk]


# ============================================================
# 6. SCLK returned through the external loopback wire
# ============================================================

create_clock \
    -period 12.500 \
    -name spi_sclk_return_clk \
    [get_ports j3_sclk_in]


# ============================================================
# 7. Slave bundled-data CDC exception
#
# Limit queries to the slave instance.
# Allow an intermediate wrapper hierarchy, if present.
# ============================================================

set_false_path \
    -from [get_cells -hier -regexp \
        {^spi_bd_i/spi_slave_core_0(/.*)?/rx_data_hold_sclk_reg\[[0-7]\]$}] \
    -to [get_cells -hier -regexp \
        {^spi_bd_i/spi_slave_core_0(/.*)?/rx_data_reg_reg\[[0-7]\]$}]


# ============================================================
# 8. Slave completion-toggle CDC exception
#
# Exclude only the path into the first synchronization FF.
# ============================================================

set_false_path \
    -from [get_cells -hier -regexp \
        {^spi_bd_i/spi_slave_core_0(/.*)?/rx_done_toggle_sclk_reg$}] \
    -to [get_cells -hier -regexp \
        {^spi_bd_i/spi_slave_core_0(/.*)?/done_meta_reg$}]


# ============================================================
# 9. Clock domain relationship
#
# Keep the two related 160 MHz clocks in the same group.
# Preserve the original asynchronous returned-SCLK model.
# Query clocks through the Clock Wizard output pins.
# ============================================================

set_clock_groups -asynchronous \
    -group [get_clocks -of_objects [get_pins {
        spi_bd_i/clk_wiz_0/clk_out1
        spi_bd_i/clk_wiz_0/clk_out2
    }]] \
    -group [get_clocks spi_sclk_return_clk]