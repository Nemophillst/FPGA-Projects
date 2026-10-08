--Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
--Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2024.1 (win64) Build 5076996 Wed May 22 18:37:14 MDT 2024
--Date        : Wed Sep 30 17:11:00 2026
--Host        : FLY running 64-bit major release  (build 9200)
--Command     : generate_target spi_bd_wrapper.bd
--Design      : spi_bd_wrapper
--Purpose     : IP block netlist
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity spi_bd_wrapper is
  port (
    j2_cs_n_out : out STD_LOGIC;
    j2_miso_in : in STD_LOGIC;
    j2_mosi_out : out STD_LOGIC;
    j2_sclk_out : out STD_LOGIC;
    j3_cs_n_in : in STD_LOGIC;
    j3_miso_out : out STD_LOGIC;
    j3_mosi_in : in STD_LOGIC;
    j3_sclk_in : in STD_LOGIC;
    sys_clk : in STD_LOGIC;
    sys_rst_n : in STD_LOGIC
  );
end spi_bd_wrapper;

architecture STRUCTURE of spi_bd_wrapper is
  component spi_bd is
  port (
    sys_clk : in STD_LOGIC;
    sys_rst_n : in STD_LOGIC;
    j2_sclk_out : out STD_LOGIC;
    j2_cs_n_out : out STD_LOGIC;
    j2_mosi_out : out STD_LOGIC;
    j2_miso_in : in STD_LOGIC;
    j3_sclk_in : in STD_LOGIC;
    j3_cs_n_in : in STD_LOGIC;
    j3_mosi_in : in STD_LOGIC;
    j3_miso_out : out STD_LOGIC
  );
  end component spi_bd;
begin
spi_bd_i: component spi_bd
     port map (
      j2_cs_n_out => j2_cs_n_out,
      j2_miso_in => j2_miso_in,
      j2_mosi_out => j2_mosi_out,
      j2_sclk_out => j2_sclk_out,
      j3_cs_n_in => j3_cs_n_in,
      j3_miso_out => j3_miso_out,
      j3_mosi_in => j3_mosi_in,
      j3_sclk_in => j3_sclk_in,
      sys_clk => sys_clk,
      sys_rst_n => sys_rst_n
    );
end STRUCTURE;
