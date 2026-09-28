# ============================================================
# SPI 80 MHz External Loopback Constraints
#
# FPGA:
#   xc7a35tfgg484-2
#
# Clock Wizard:
#
#   Input:
#       50 MHz
#
#   clk_out1:
#       160 MHz / 0 degree
#
#   clk_out2:
#       160 MHz / 180 degree
#
# No 320 MHz clock is used in this version.
# ============================================================



# ============================================================
# 1. Board 50 MHz system clock
#
# 50 MHz period = 20 ns
# ============================================================

create_clock -period 20.000 \
    -name sys_clk \
    [get_ports sys_clk]



# ============================================================
# 2. Board 50 MHz clock pin
#
# sys_clk = FPGA R4
# ============================================================

set_property -dict {
    PACKAGE_PIN R4
    IOSTANDARD LVCMOS33
} [get_ports sys_clk]



# ============================================================
# 3. Active-low reset button
#
# sys_rst_n = FPGA U2
# ============================================================

set_property -dict {
    PACKAGE_PIN U2
    IOSTANDARD LVCMOS33
} [get_ports sys_rst_n]



# ============================================================
# 4. J2 -- Master physical interface
# ============================================================


# ------------------------------------------------------------
# Master SCLK output
#
# FPGA E19
# ------------------------------------------------------------

set_property -dict {
    PACKAGE_PIN E19
    IOSTANDARD LVCMOS33
} [get_ports j2_sclk_out]



# ------------------------------------------------------------
# Master CS_N output
#
# FPGA H22
# ------------------------------------------------------------

set_property -dict {
    PACKAGE_PIN H22
    IOSTANDARD LVCMOS33
} [get_ports j2_cs_n_out]



# ------------------------------------------------------------
# Master MOSI output
#
# FPGA G22
# ------------------------------------------------------------

set_property -dict {
    PACKAGE_PIN G22
    IOSTANDARD LVCMOS33
} [get_ports j2_mosi_out]



# ------------------------------------------------------------
# Master MISO input
#
# FPGA G21
# ------------------------------------------------------------

set_property -dict {
    PACKAGE_PIN G21
    IOSTANDARD LVCMOS33
} [get_ports j2_miso_in]



# ============================================================
# 5. J3 -- Slave physical interface
# ============================================================


# ------------------------------------------------------------
# Slave SCLK input
#
# FPGA V18
# ------------------------------------------------------------

set_property -dict {
    PACKAGE_PIN V18
    IOSTANDARD LVCMOS33
} [get_ports j3_sclk_in]



# ------------------------------------------------------------
# Slave CS_N input
#
# FPGA AB6
# ------------------------------------------------------------

set_property -dict {
    PACKAGE_PIN AB6
    IOSTANDARD LVCMOS33
} [get_ports j3_cs_n_in]



# ------------------------------------------------------------
# Slave MOSI input
#
# FPGA AB8
# ------------------------------------------------------------

set_property -dict {
    PACKAGE_PIN AB8
    IOSTANDARD LVCMOS33
} [get_ports j3_mosi_in]



# ------------------------------------------------------------
# Slave MISO output
#
# FPGA AA8
# ------------------------------------------------------------

set_property -dict {
    PACKAGE_PIN AA8
    IOSTANDARD LVCMOS33
} [get_ports j3_miso_out]



# ============================================================
# 6. FPGA configuration voltage
# ============================================================

set_property CFGBVS VCCO [current_design]

set_property CONFIG_VOLTAGE 3.3 [current_design]



# ============================================================
# 7. Master SPI generated clock
#
# Master working clock:
#
#     160 MHz
#
# SCLK relationship:
#
#     f_SCLK = 160 MHz / (2 * CLK_DIV)
#
# At:
#
#     CLK_DIV = 1
#
# SCLK:
#
#     160 MHz / 2 = 80 MHz
#
# Period:
#
#     12.5 ns
# ============================================================

create_generated_clock \
    -name spi_sclk_clk \
    -source [get_pins U_SPI_MASTER/i_clk] \
    -divide_by 2 \
    [get_pins U_SPI_MASTER/o_sclk]



# ============================================================
# 8. SPI SCLK returned through external loopback
#
# Master SCLK leaves the FPGA:
#
#     j2_sclk_out
#
# travels through the external wire and returns through:
#
#     j3_sclk_in
#
# Vivado cannot automatically understand the external wire.
#
# Therefore constrain the returned input as an 80 MHz clock.
# ============================================================

create_clock \
    -period 12.500 \
    -name spi_sclk_return_clk \
    [get_ports j3_sclk_in]



# ============================================================
# 9. Slave bundled-data CDC exception
#
# rx_data_hold_sclk[7:0]
#
# is produced in the returned SPI SCLK domain.
#
# rx_data_reg[7:0]
#
# belongs to the internal 160 MHz domain.
#
# The complete byte is held stable while the completion toggle
# crosses through the synchronizer.
#
# Therefore this direct bundled-data path is not treated as a
# normal single-cycle synchronous path.
# ============================================================

set_false_path \
    -from [get_cells -hier -regexp {.*U_SPI_SLAVE/rx_data_hold_sclk_reg\[[0-7]\]$}] \
    -to   [get_cells -hier -regexp {.*U_SPI_SLAVE/rx_data_reg_reg\[[0-7]\]$}]



# ============================================================
# 10. Slave DONE toggle CDC exception
#
# rx_done_toggle_sclk:
#
#     returned SPI SCLK domain
#
# done_meta:
#
#     first synchronization register in 160 MHz domain
#
# Only the asynchronous path INTO the first synchronizer FF
# is excluded.
#
# done_meta -> done_sync -> done_sync_d
#
# remains normally timed.
# ============================================================

set_false_path \
    -from [get_cells -hier -regexp {.*U_SPI_SLAVE/rx_done_toggle_sclk_reg$}] \
    -to   [get_cells -hier -regexp {.*U_SPI_SLAVE/done_meta_reg$}]



# ============================================================
# 11. Clock domain relationship
#
# Internal MMCM clocks:
#
#     CLKOUT0 = 160 MHz / 0 degree
#     CLKOUT1 = 160 MHz / 180 degree
#
# These two clocks come from the SAME MMCM.
#
# Therefore they are related to each other and MUST remain
# together in the same clock group.
#
# spi_sclk_return_clk has travelled outside the FPGA and back
# through the external loopback wiring.
#
# We therefore treat the returned SCLK domain as asynchronous
# relative to the internal MMCM clock group.
# ============================================================

set_clock_groups -asynchronous \
    -group [get_clocks -of_objects \
        [get_pins {
            U_CLK_WIZ/inst/mmcm_adv_inst/CLKOUT0
            U_CLK_WIZ/inst/mmcm_adv_inst/CLKOUT1
        }]] \
    -group [get_clocks spi_sclk_return_clk]