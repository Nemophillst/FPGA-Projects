library ieee;
use ieee.std_logic_1164.all;

entity miso_observer is
    port (
        i_clk          : in  std_logic;
        i_clk_shift    : in  std_logic;
        i_miso         : in  std_logic;

        o_sample_0     : out std_logic;
        o_sample_shift : out std_logic
    );
end entity miso_observer;

architecture rtl of miso_observer is

    signal sample_0_reg     : std_logic := '0';
    signal sample_shift_reg : std_logic := '0';

begin

    process(i_clk)
    begin
        if rising_edge(i_clk) then
            sample_0_reg <= i_miso;
        end if;
    end process;

    process(i_clk_shift)
    begin
        if rising_edge(i_clk_shift) then
            sample_shift_reg <= i_miso;
        end if;
    end process;

    o_sample_0     <= sample_0_reg;
    o_sample_shift <= sample_shift_reg;

end architecture rtl;