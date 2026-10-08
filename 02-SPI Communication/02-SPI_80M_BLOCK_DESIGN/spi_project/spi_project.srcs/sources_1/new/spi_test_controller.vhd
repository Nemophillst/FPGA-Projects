library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


-- =====================================================================
-- SPI Test Controller
--
-- 功能：
-- 1. 手动单帧测试
-- 2. 自动连续测试
-- 3. 产生 SPI Master START
-- 4. 配置 Master / Slave TX 数据
-- 5. 检查 Master / Slave RX 数据
-- 6. 错误统计
-- 7. Timeout 检测
--
-- 注意：
-- 本模块只负责控制。
-- 真正的 SPI 时序仍然由：
--
--     spi_master_core.vhd
--     spi_slave_core.vhd
--
-- 完成。
-- =====================================================================

entity spi_test_controller is
    port (

        -- =============================================================
        -- Clock / Reset
        -- =============================================================
        i_clk   : in std_logic;
        i_rst_n : in std_logic;


        -- =============================================================
        -- VIO / User Control
        -- =============================================================

        -- "00" = 手动单帧
        -- "01" = 自动连续测试
        i_work_mode :
            in std_logic_vector(1 downto 0);


        -- START 当前电平
        --
        -- 自动连续测试时：
        -- 1 = 继续运行
        -- 0 = 停止
        i_start_level :
            in std_logic;


        -- START 上升沿脉冲
        i_start_rise :
            in std_logic;


        -- 手动模式 Master TX 数据
        i_master_tx :
            in std_logic_vector(7 downto 0);


        -- 手动模式 Slave TX 数据
        i_slave_tx :
            in std_logic_vector(7 downto 0);


        -- SPI Mode
        i_spi_mode :
            in std_logic_vector(1 downto 0);


        -- SPI Clock Divider
        i_clk_div :
            in std_logic_vector(15 downto 0);


        -- =============================================================
        -- Feedback from SPI Master
        -- =============================================================

        i_master_rx_data :
            in std_logic_vector(7 downto 0);

        i_master_busy :
            in std_logic;

        i_master_done :
            in std_logic;


        -- =============================================================
        -- Feedback from SPI Slave
        -- =============================================================

        i_slave_rx_data :
            in std_logic_vector(7 downto 0);

        i_slave_rx_valid :
            in std_logic;


        -- =============================================================
        -- Outputs to SPI cores
        -- =============================================================

        o_master_start :
            out std_logic;

        o_master_tx_cfg :
            out std_logic_vector(7 downto 0);

        o_slave_tx_cfg :
            out std_logic_vector(7 downto 0);

        o_spi_mode_cfg :
            out std_logic_vector(1 downto 0);

        o_clk_div_cfg :
            out unsigned(15 downto 0);


        -- =============================================================
        -- Continuous test statistics
        -- =============================================================

        o_total_count :
            out unsigned(31 downto 0);

        o_master_error_count :
            out unsigned(31 downto 0);

        o_slave_error_count :
            out unsigned(31 downto 0);

        o_timeout_count :
            out unsigned(31 downto 0);


        -- =============================================================
        -- Error pulses
        -- Mainly used by ILA
        -- =============================================================

        o_master_error_pulse :
            out std_logic;

        o_slave_error_pulse :
            out std_logic;

        o_timeout_pulse :
            out std_logic

    );
end entity spi_test_controller;



architecture Behavioral of spi_test_controller is


    -- =================================================================
    -- Master START
    -- =================================================================

    signal master_start :
        std_logic := '0';


    -- 手动模式下：
    -- 先锁存参数，再下一拍产生 START
    signal start_pending :
        std_logic := '0';



    -- =================================================================
    -- Active SPI configuration
    -- =================================================================

    signal master_tx_cfg :
        std_logic_vector(7 downto 0) :=
        (others => '0');

    signal slave_tx_cfg :
        std_logic_vector(7 downto 0) :=
        (others => '0');

    signal spi_mode_cfg :
        std_logic_vector(1 downto 0) :=
        "00";

    signal clk_div_cfg :
        unsigned(15 downto 0) :=
        to_unsigned(1, 16);



    -- =================================================================
    -- Automatic test state machine
    -- =================================================================

    type auto_state_t is (
        AUTO_IDLE,
        AUTO_WAIT_FRAME,
        AUTO_GAP,
        AUTO_RECOVER
    );


    signal auto_state :
        auto_state_t :=
        AUTO_IDLE;



    -- =================================================================
    -- Automatic TX sequence
    --
    -- Master:
    -- 00 01 02 03 ... FF
    --
    -- Slave:
    -- FF FE FD FC ... 00
    -- =================================================================

    signal auto_sequence :
        unsigned(7 downto 0) :=
        (others => '0');



    -- =================================================================
    -- Completion event memory
    --
    -- Master done 和 Slave valid 不一定同一拍出现，
    -- 所以分别记住。
    -- =================================================================

    signal auto_master_done_seen :
        std_logic := '0';

    signal auto_slave_done_seen :
        std_logic := '0';



    -- =================================================================
    -- Inter-frame gap
    --
    -- 160 MHz:
    --
    -- 一个周期 = 6.25 ns
    --
    -- 4 个周期 = 25 ns
    -- =================================================================

    signal auto_gap_count :
        unsigned(2 downto 0) :=
        (others => '0');



    -- =================================================================
    -- Frame timeout
    --
    -- 256 × 6.25 ns
    -- ≈ 1.6 us
    -- =================================================================

    signal frame_wait_count :
        unsigned(7 downto 0) :=
        (others => '0');



    -- =================================================================
    -- Statistics
    -- =================================================================

    signal total_count :
        unsigned(31 downto 0) :=
        (others => '0');

    signal master_error_count :
        unsigned(31 downto 0) :=
        (others => '0');

    signal slave_error_count :
        unsigned(31 downto 0) :=
        (others => '0');

    signal timeout_count :
        unsigned(31 downto 0) :=
        (others => '0');



    -- =================================================================
    -- Error pulses
    -- =================================================================

    signal master_error_pulse :
        std_logic := '0';

    signal slave_error_pulse :
        std_logic := '0';

    signal timeout_pulse :
        std_logic := '0';



begin


    -- =================================================================
    -- Internal signals -> module outputs
    -- =================================================================

    o_master_start <=
        master_start;


    o_master_tx_cfg <=
        master_tx_cfg;

    o_slave_tx_cfg <=
        slave_tx_cfg;

    o_spi_mode_cfg <=
        spi_mode_cfg;

    o_clk_div_cfg <=
        clk_div_cfg;


    o_total_count <=
        total_count;

    o_master_error_count <=
        master_error_count;

    o_slave_error_count <=
        slave_error_count;

    o_timeout_count <=
        timeout_count;


    o_master_error_pulse <=
        master_error_pulse;

    o_slave_error_pulse <=
        slave_error_pulse;

    o_timeout_pulse <=
        timeout_pulse;



    -- =================================================================
    -- Main Controller
    -- =================================================================

    P_CONTROL : process(i_clk)

        -- 当前帧 Slave 应该收到的数据
        variable expected_slave_rx_v :
            std_logic_vector(7 downto 0);


        -- 当前帧 Master 应该收到的数据
        variable expected_master_rx_v :
            std_logic_vector(7 downto 0);

    begin


        if rising_edge(i_clk) then


            -- =========================================================
            -- RESET
            -- =========================================================

            if i_rst_n = '0' then


                master_tx_cfg <=
                    (others => '0');

                slave_tx_cfg <=
                    (others => '0');


                spi_mode_cfg <=
                    "00";

                clk_div_cfg <=
                    to_unsigned(1, 16);


                start_pending <=
                    '0';

                master_start <=
                    '0';


                auto_state <=
                    AUTO_IDLE;

                auto_sequence <=
                    (others => '0');


                auto_master_done_seen <=
                    '0';

                auto_slave_done_seen <=
                    '0';


                auto_gap_count <=
                    (others => '0');

                frame_wait_count <=
                    (others => '0');


                total_count <=
                    (others => '0');

                master_error_count <=
                    (others => '0');

                slave_error_count <=
                    (others => '0');

                timeout_count <=
                    (others => '0');


                master_error_pulse <=
                    '0';

                slave_error_pulse <=
                    '0';

                timeout_pulse <=
                    '0';



            else


                -- =====================================================
                -- Default one-clock pulses
                -- =====================================================

                master_start <=
                    '0';

                master_error_pulse <=
                    '0';

                slave_error_pulse <=
                    '0';

                timeout_pulse <=
                    '0';



                -- =====================================================
                -- MODE 00
                --
                -- Manual single-frame mode
                -- =====================================================

                if i_work_mode = "00" then


                    auto_state <=
                        AUTO_IDLE;


                    auto_master_done_seen <=
                        '0';

                    auto_slave_done_seen <=
                        '0';


                    auto_gap_count <=
                        (others => '0');

                    frame_wait_count <=
                        (others => '0');



                    -- =================================================
                    -- START 上升沿
                    --
                    -- 先锁存 VIO 设置
                    -- =================================================

                    if i_start_rise = '1' then


                        master_tx_cfg <=
                            i_master_tx;


                        slave_tx_cfg <=
                            i_slave_tx;


                        spi_mode_cfg <=
                            i_spi_mode;



                        -- ---------------------------------------------
                        -- clk_div = 0 不允许
                        --
                        -- 自动强制改为 1
                        -- ---------------------------------------------

                        if unsigned(i_clk_div) =
                           to_unsigned(0, 16) then


                            clk_div_cfg <=
                                to_unsigned(1, 16);


                        else


                            clk_div_cfg <=
                                unsigned(i_clk_div);


                        end if;



                        -- 下一拍产生 START
                        start_pending <=
                            '1';



                    -- =================================================
                    -- 下一拍给 Master 一个周期 START
                    -- =================================================

                    elsif start_pending = '1' then


                        master_start <=
                            '1';


                        start_pending <=
                            '0';


                    end if;



                -- =====================================================
                -- MODE 01
                --
                -- Automatic continuous test
                -- =====================================================

                elsif i_work_mode = "01" then


                    -- 自动模式不使用 manual start_pending
                    start_pending <=
                        '0';



                    case auto_state is



                        -- =================================================
                        -- AUTO_IDLE
                        --
                        -- 等待 START 0 -> 1
                        -- =================================================

                        when AUTO_IDLE =>


                            auto_master_done_seen <=
                                '0';

                            auto_slave_done_seen <=
                                '0';


                            auto_gap_count <=
                                (others => '0');

                            frame_wait_count <=
                                (others => '0');



                            if i_start_rise = '1' then


                                -- =========================================
                                -- 每次重新开始连续测试
                                -- 清零统计计数器
                                -- =========================================

                                total_count <=
                                    (others => '0');

                                master_error_count <=
                                    (others => '0');

                                slave_error_count <=
                                    (others => '0');

                                timeout_count <=
                                    (others => '0');



                                -- =========================================
                                -- 第一帧
                                --
                                -- Master TX = 00
                                -- Slave TX  = FF
                                -- =========================================

                                auto_sequence <=
                                    to_unsigned(0, 8);


                                master_tx_cfg <=
                                    x"00";


                                slave_tx_cfg <=
                                    x"FF";


                                spi_mode_cfg <=
                                    i_spi_mode;



                                if unsigned(i_clk_div) =
                                   to_unsigned(0, 16) then


                                    clk_div_cfg <=
                                        to_unsigned(1, 16);


                                else


                                    clk_div_cfg <=
                                        unsigned(i_clk_div);


                                end if;



                                -- 第一帧立即开始
                                master_start <=
                                    '1';


                                auto_master_done_seen <=
                                    '0';

                                auto_slave_done_seen <=
                                    '0';


                                frame_wait_count <=
                                    (others => '0');


                                auto_state <=
                                    AUTO_WAIT_FRAME;


                            end if;



                        -- =================================================
                        -- AUTO_WAIT_FRAME
                        --
                        -- 等待：
                        --
                        -- Master done
                        -- Slave RX valid
                        --
                        -- 两者都完成后比较数据
                        -- =================================================

                        when AUTO_WAIT_FRAME =>



                            -- ---------------------------------------------
                            -- 记住 Master done
                            -- ---------------------------------------------

                            if i_master_done = '1' then


                                auto_master_done_seen <=
                                    '1';


                            end if;



                            -- ---------------------------------------------
                            -- 记住 Slave valid
                            -- ---------------------------------------------

                            if i_slave_rx_valid = '1' then


                                auto_slave_done_seen <=
                                    '1';


                            end if;



                            -- =================================================
                            -- 当前帧完成
                            -- =================================================

                            if
                                (
                                    (auto_master_done_seen = '1') or
                                    (i_master_done = '1')
                                )
                                and
                                (
                                    (auto_slave_done_seen = '1') or
                                    (i_slave_rx_valid = '1')
                                )
                            then


                                -- =========================================
                                -- 当前帧预期数据
                                --
                                -- Master TX = sequence
                                --
                                -- 所以：
                                -- Slave RX = sequence
                                --
                                -- Slave TX = NOT sequence
                                --
                                -- 所以：
                                -- Master RX = NOT sequence
                                -- =========================================

                                expected_slave_rx_v :=
                                    std_logic_vector(
                                        auto_sequence
                                    );


                                expected_master_rx_v :=
                                    not std_logic_vector(
                                        auto_sequence
                                    );



                                -- 当前完成一帧
                                total_count <=
                                    total_count +
                                    to_unsigned(1, 32);



                                -- =========================================
                                -- Master RX 比较
                                -- =========================================

                                if i_master_rx_data /=
                                   expected_master_rx_v then


                                    master_error_count <=
                                        master_error_count +
                                        to_unsigned(1, 32);


                                    master_error_pulse <=
                                        '1';


                                end if;



                                -- =========================================
                                -- Slave RX 比较
                                -- =========================================

                                if i_slave_rx_data /=
                                   expected_slave_rx_v then


                                    slave_error_count <=
                                        slave_error_count +
                                        to_unsigned(1, 32);


                                    slave_error_pulse <=
                                        '1';


                                end if;



                                -- 当前帧完成
                                auto_master_done_seen <=
                                    '0';

                                auto_slave_done_seen <=
                                    '0';


                                frame_wait_count <=
                                    (others => '0');



                                -- =========================================
                                -- START 仍然保持 1
                                --
                                -- 继续下一帧
                                -- =========================================

                                if i_start_level = '1' then


                                    -- sequence + 1
                                    auto_sequence <=
                                        auto_sequence +
                                        to_unsigned(1, 8);



                                    -- 下一帧 Master TX
                                    master_tx_cfg <=
                                        std_logic_vector(
                                            auto_sequence +
                                            to_unsigned(1, 8)
                                        );



                                    -- 下一帧 Slave TX
                                    slave_tx_cfg <=
                                        not std_logic_vector(
                                            auto_sequence +
                                            to_unsigned(1, 8)
                                        );



                                    -- 清零帧间隔计数
                                    auto_gap_count <=
                                        (others => '0');


                                    auto_state <=
                                        AUTO_GAP;



                                -- =========================================
                                -- START = 0
                                --
                                -- 停止连续测试
                                -- =========================================

                                else


                                    auto_state <=
                                        AUTO_IDLE;


                                end if;



                            -- =================================================
                            -- Timeout
                            --
                            -- 256 × 6.25 ns
                            -- ≈ 1.6 us
                            -- =================================================

                            elsif frame_wait_count =
                                  to_unsigned(255, 8) then


                                -- Timeout 也算处理过一帧
                                total_count <=
                                    total_count +
                                    to_unsigned(1, 32);


                                timeout_count <=
                                    timeout_count +
                                    to_unsigned(1, 32);


                                timeout_pulse <=
                                    '1';



                                auto_master_done_seen <=
                                    '0';

                                auto_slave_done_seen <=
                                    '0';


                                frame_wait_count <=
                                    (others => '0');



                                -- =========================================
                                -- 用户已经停止
                                -- =========================================

                                if i_start_level = '0' then


                                    auto_state <=
                                        AUTO_IDLE;



                                -- =========================================
                                -- Master 已经空闲
                                --
                                -- 可以安全准备下一帧
                                -- =========================================

                                elsif i_master_busy = '0' then


                                    auto_sequence <=
                                        auto_sequence +
                                        to_unsigned(1, 8);



                                    master_tx_cfg <=
                                        std_logic_vector(
                                            auto_sequence +
                                            to_unsigned(1, 8)
                                        );



                                    slave_tx_cfg <=
                                        not std_logic_vector(
                                            auto_sequence +
                                            to_unsigned(1, 8)
                                        );



                                    auto_gap_count <=
                                        (others => '0');


                                    auto_state <=
                                        AUTO_GAP;



                                -- =========================================
                                -- Master 仍然 busy
                                --
                                -- 不能直接改 Slave TX
                                --
                                -- 等 Master 真正 idle
                                -- =========================================

                                else


                                    auto_state <=
                                        AUTO_RECOVER;


                                end if;



                            -- =================================================
                            -- 正常等待
                            -- =================================================

                            else


                                frame_wait_count <=
                                    frame_wait_count +
                                    to_unsigned(1, 8);


                            end if;



                        -- =================================================
                        -- AUTO_RECOVER
                        --
                        -- Timeout 后等待 Master idle
                        -- =================================================

                        when AUTO_RECOVER =>


                            -- 用户停止
                            if i_start_level = '0' then


                                auto_state <=
                                    AUTO_IDLE;



                            -- Master 已经 idle
                            elsif i_master_busy = '0' then


                                auto_sequence <=
                                    auto_sequence +
                                    to_unsigned(1, 8);



                                master_tx_cfg <=
                                    std_logic_vector(
                                        auto_sequence +
                                        to_unsigned(1, 8)
                                    );



                                slave_tx_cfg <=
                                    not std_logic_vector(
                                        auto_sequence +
                                        to_unsigned(1, 8)
                                    );



                                auto_gap_count <=
                                    (others => '0');


                                auto_state <=
                                    AUTO_GAP;


                            end if;



                        -- =================================================
                        -- AUTO_GAP
                        --
                        -- 帧间隔：
                        --
                        -- 4 × 6.25 ns
                        -- = 25 ns
                        -- =================================================

                        when AUTO_GAP =>



                            -- =========================================
                            -- 用户停止
                            -- =========================================

                            if i_start_level = '0' then


                                auto_gap_count <=
                                    (others => '0');


                                auto_state <=
                                    AUTO_IDLE;



                            -- =========================================
                            -- Gap 完成
                            -- =========================================

                            elsif auto_gap_count =
                                  to_unsigned(3, 3) then


                                auto_gap_count <=
                                    (others => '0');


                                frame_wait_count <=
                                    (others => '0');


                                auto_master_done_seen <=
                                    '0';

                                auto_slave_done_seen <=
                                    '0';



                                -- 下一帧 START
                                master_start <=
                                    '1';


                                auto_state <=
                                    AUTO_WAIT_FRAME;



                            -- =========================================
                            -- Gap 计数
                            -- =========================================

                            else


                                auto_gap_count <=
                                    auto_gap_count +
                                    to_unsigned(1, 3);


                            end if;



                    end case;



                -- =====================================================
                -- 其他 Mode 暂时不用
                -- =====================================================

                else


                    start_pending <=
                        '0';


                    auto_state <=
                        AUTO_IDLE;


                    auto_master_done_seen <=
                        '0';

                    auto_slave_done_seen <=
                        '0';


                    auto_gap_count <=
                        (others => '0');


                    frame_wait_count <=
                        (others => '0');


                end if;


            end if;


        end if;


    end process;


end architecture Behavioral;