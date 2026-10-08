library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


-- ================================================================
-- Reset Synchronizer
--
-- 作用：
-- 将异步复位信号同步到当前时钟域。
--
-- 特点：
-- 1. 复位可以异步立即拉低
-- 2. 解除复位时经过两个时钟触发器同步
-- ================================================================

entity reset_sync is
    port (
        -- 当前逻辑所在时钟域
        i_clk     : in  std_logic;

        -- 异步低有效复位输入
        i_async_n : in  std_logic;

        -- 同步后的低有效复位输出
        o_sync_n  : out std_logic
    );
end entity reset_sync;


architecture Behavioral of reset_sync is


    -- 第一级同步触发器
    signal rst_ff1 :
        std_logic := '0';


    -- 第二级同步触发器
    signal rst_ff2 :
        std_logic := '0';


    -- 告诉 Vivado：
    -- 这两个触发器属于异步信号同步链
    attribute ASYNC_REG : string;

    attribute ASYNC_REG of rst_ff1 :
        signal is "TRUE";

    attribute ASYNC_REG of rst_ff2 :
        signal is "TRUE";


begin


    -- ============================================================
    -- 两级复位同步器
    --
    -- i_async_n = 0：
    --     两级触发器立即清零
    --
    -- i_async_n = 1：
    --     在 i_clk 上升沿逐级释放复位
    -- ============================================================
    P_RESET_SYNC : process(
        i_clk,
        i_async_n
    )
    begin

        if i_async_n = '0' then

            rst_ff1 <=
                '0';

            rst_ff2 <=
                '0';


        elsif rising_edge(i_clk) then

            rst_ff1 <=
                '1';

            rst_ff2 <=
                rst_ff1;

        end if;

    end process;


    -- 输出第二级触发器
    o_sync_n <=
        rst_ff2;


end architecture Behavioral;