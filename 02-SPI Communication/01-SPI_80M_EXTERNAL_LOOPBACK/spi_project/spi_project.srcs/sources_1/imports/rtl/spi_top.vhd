library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity spi_top is
    port (
        -- Board 50 MHz clock
        sys_clk   : in std_logic;

        -- Physical reset button, active low
        sys_rst_n : in std_logic;


        -- =============================================================
        -- External SPI loopback pins
        -- =============================================================

        -- Master -> external wire -> Slave
        j2_sclk_out : out std_logic;
        j2_cs_n_out : out std_logic;
        j2_mosi_out : out std_logic;

        -- Slave -> external wire -> Master
        j2_miso_in  : in  std_logic;

        -- External wire -> Slave
        j3_sclk_in  : in  std_logic;
        j3_cs_n_in  : in  std_logic;
        j3_mosi_in  : in  std_logic;

        -- Slave -> external wire
        j3_miso_out : out std_logic
    );
end entity spi_top;



architecture Behavioral of spi_top is


    -- =================================================================
    -- VIO
    --
    -- Input probes:
    --
    -- probe_in0 : Master RX
    -- probe_in1 : Slave RX
    -- probe_in2 : Master busy
    -- probe_in3 : Master done
    -- probe_in4 : Slave RX valid
    -- probe_in5 : Slave frame error
    --
    -- probe_in6 : Total frame count
    -- probe_in7 : Master RX error count
    -- probe_in8 : Slave RX error count
    -- probe_in9 : Timeout count
    --
    -- Output probes remain unchanged.
    -- =================================================================
    component vio_0
        port (
            clk : in std_logic;

            probe_in0 : in std_logic_vector(7 downto 0);
            probe_in1 : in std_logic_vector(7 downto 0);

            probe_in2 : in std_logic_vector(0 downto 0);
            probe_in3 : in std_logic_vector(0 downto 0);
            probe_in4 : in std_logic_vector(0 downto 0);
            probe_in5 : in std_logic_vector(0 downto 0);

            probe_in6 : in std_logic_vector(31 downto 0);
            probe_in7 : in std_logic_vector(31 downto 0);
            probe_in8 : in std_logic_vector(31 downto 0);
            probe_in9 : in std_logic_vector(31 downto 0);


            probe_out0 : out std_logic_vector(0 downto 0);
            probe_out1 : out std_logic_vector(1 downto 0);
            probe_out2 : out std_logic_vector(0 downto 0);

            probe_out3 : out std_logic_vector(7 downto 0);
            probe_out4 : out std_logic_vector(7 downto 0);

            probe_out5 : out std_logic_vector(1 downto 0);
            probe_out6 : out std_logic_vector(15 downto 0)
        );
    end component;



    -- =================================================================
    -- ILA
    --
    -- 20 probes
    -- =================================================================
    component ila_0
        port (
            clk : in std_logic;

            -- Physical SPI
            probe0  : in std_logic_vector(0 downto 0);
            probe1  : in std_logic_vector(0 downto 0);
            probe2  : in std_logic_vector(0 downto 0);
            probe3  : in std_logic_vector(0 downto 0);

            -- MISO timing observation
            probe4  : in std_logic_vector(0 downto 0);
            probe5  : in std_logic_vector(0 downto 0);

            -- Control/status
            probe6  : in std_logic_vector(0 downto 0);
            probe7  : in std_logic_vector(0 downto 0);
            probe8  : in std_logic_vector(0 downto 0);
            probe9  : in std_logic_vector(0 downto 0);
            probe10 : in std_logic_vector(0 downto 0);

            -- Data
            probe11 : in std_logic_vector(7 downto 0);
            probe12 : in std_logic_vector(7 downto 0);
            probe13 : in std_logic_vector(7 downto 0);
            probe14 : in std_logic_vector(7 downto 0);
            probe15 : in std_logic_vector(7 downto 0);

            -- Error information
            probe16 : in std_logic_vector(0 downto 0);
            probe17 : in std_logic_vector(0 downto 0);
            probe18 : in std_logic_vector(0 downto 0);
            probe19 : in std_logic_vector(0 downto 0)
        );
    end component;



    -- =================================================================
    -- VIO control signals
    -- =================================================================
    signal vio_rst_n_v :
        std_logic_vector(0 downto 0);

    signal vio_work_mode :
        std_logic_vector(1 downto 0);

    signal vio_start_v :
        std_logic_vector(0 downto 0);

    signal vio_master_tx :
        std_logic_vector(7 downto 0);

    signal vio_slave_tx :
        std_logic_vector(7 downto 0);

    signal vio_spi_mode :
        std_logic_vector(1 downto 0);

    signal vio_clk_div :
        std_logic_vector(15 downto 0);



    -- =================================================================
    -- Clock Wizard
    -- =================================================================

    -- 160 MHz / 0 degree
    signal clk_spi_160 :
        std_logic;

    -- 160 MHz / 180 degree
    --
    -- Relative offset:
    -- 3.125 ns
    signal clk_spi_160_shift :
        std_logic;

    signal clk_locked :
        std_logic;

    signal clk_wiz_reset :
        std_logic;



    -- =================================================================
    -- Reset
    -- =================================================================
    signal rst_160_async_n :
        std_logic;

    signal rst_160_ff1 :
        std_logic := '0';

    signal rst_160_ff2 :
        std_logic := '0';

    signal core_rst_n_160 :
        std_logic;



    -- =================================================================
    -- VIO START edge
    -- =================================================================
    signal vio_start_rise_160 :
        std_logic;



    -- =================================================================
    -- Actual pulse sent to SPI Master
    --
    -- Always one 160 MHz clock wide.
    -- =================================================================
    signal master_start :
        std_logic := '0';



    -- =================================================================
    -- Manual mode start bookkeeping
    -- =================================================================
    signal start_pending :
        std_logic := '0';



    -- =================================================================
    -- Active SPI configuration
    -- =================================================================
    signal master_tx_cfg :
        std_logic_vector(7 downto 0) := (others => '0');

    signal slave_tx_cfg :
        std_logic_vector(7 downto 0) := (others => '0');

    signal spi_mode_cfg :
        std_logic_vector(1 downto 0) := "00";

    signal clk_div_cfg :
        unsigned(15 downto 0) := to_unsigned(1, 16);



    -- =================================================================
    -- Continuous test controller
    -- =================================================================

    type auto_state_t is (
        AUTO_IDLE,
        AUTO_WAIT_FRAME,
        AUTO_GAP,
        AUTO_RECOVER
    );

    signal auto_state :
        auto_state_t := AUTO_IDLE;



    -- Current frame sequence number.
    --
    -- Master TX:
    --
    -- 00, 01, 02, 03 ... FF, 00 ...
    --
    -- Slave TX:
    --
    -- FF, FE, FD, FC ... 00, FF ...
    -- =================================================================
    signal auto_sequence :
        unsigned(7 downto 0) := (others => '0');



    -- =================================================================
    -- Completion flags
    --
    -- master_done and slave_rx_valid may not occur on the same
    -- 160 MHz clock cycle.
    --
    -- Therefore each event is remembered separately.
    -- =================================================================
    signal auto_master_done_seen :
        std_logic := '0';

    signal auto_slave_done_seen :
        std_logic := '0';



    -- =================================================================
    -- Inter-frame gap
    --
    -- 4 x 160 MHz clock periods
    --
    -- = 4 x 6.25 ns
    -- = 25 ns
    -- =================================================================
    signal auto_gap_count :
        unsigned(2 downto 0) := (others => '0');



    -- =================================================================
    -- Per-frame timeout timer
    --
    -- Maximum waiting time:
    --
    -- 256 x 6.25 ns
    -- = 1.6 us
    --
    -- A normal 80 MHz 8-bit frame is far shorter than this.
    -- =================================================================
    signal frame_wait_count :
        unsigned(7 downto 0) := (others => '0');



    -- =================================================================
    -- 32-bit continuous-test statistics
    -- =================================================================

    -- Number of test frames that have been processed.
    --
    -- Includes:
    --     normally completed frames
    --     timeout frames
    signal total_count :
        unsigned(31 downto 0) := (others => '0');


    -- Master received wrong MISO byte
    signal master_error_count :
        unsigned(31 downto 0) := (others => '0');


    -- Slave received wrong MOSI byte
    signal slave_error_count :
        unsigned(31 downto 0) := (others => '0');


    -- Frame did not finish within allowed time
    signal timeout_count :
        unsigned(31 downto 0) := (others => '0');



    -- =================================================================
    -- One-clock error pulses
    --
    -- These are mainly for ILA triggering.
    -- =================================================================
    signal master_error_pulse :
        std_logic := '0';

    signal slave_error_pulse :
        std_logic := '0';

    signal timeout_pulse :
        std_logic := '0';



    -- =================================================================
    -- SPI Master signals
    -- =================================================================
    signal master_sclk :
        std_logic;

    signal master_cs_n :
        std_logic;

    signal master_mosi :
        std_logic;

    signal master_rx_data :
        std_logic_vector(7 downto 0);

    signal master_busy :
        std_logic;

    signal master_done :
        std_logic;



    -- =================================================================
    -- SPI Slave signals
    -- =================================================================
    signal slave_miso :
        std_logic;

    signal slave_rx_data :
        std_logic_vector(7 downto 0);

    signal slave_rx_valid :
        std_logic;

    signal frame_error :
        std_logic;



    -- =================================================================
    -- Slave internal debug bus
    -- =================================================================
    signal slave_debug :
        std_logic_vector(7 downto 0);



    -- =================================================================
    -- MISO observation registers
    -- =================================================================
    signal miso_sample_0 :
        std_logic := '0';

    signal miso_sample_180 :
        std_logic := '0';



    -- =================================================================
    -- Reset synchronizer attributes
    -- =================================================================
    attribute ASYNC_REG : string;

    attribute ASYNC_REG of rst_160_ff1 :
        signal is "TRUE";

    attribute ASYNC_REG of rst_160_ff2 :
        signal is "TRUE";



begin


    -- =================================================================
    -- Clock Wizard reset
    -- =================================================================
    clk_wiz_reset <=
        not sys_rst_n;



    -- =================================================================
    -- Clock Wizard
    --
    -- Input:
    --     50 MHz
    --
    -- Output:
    --     160 MHz / 0°
    --     160 MHz / 180°
    -- =================================================================
    U_CLK_WIZ : entity work.clk_wiz_0
        port map (
            clk_in1 =>
                sys_clk,

            reset =>
                clk_wiz_reset,

            clk_out1 =>
                clk_spi_160,

            clk_out2 =>
                clk_spi_160_shift,

            locked =>
                clk_locked
        );



    -- =================================================================
    -- Raw reset
    -- =================================================================
    rst_160_async_n <=
        sys_rst_n and
        vio_rst_n_v(0) and
        clk_locked;



    -- =================================================================
    -- Reset synchronizer
    -- =================================================================
    P_RESET_160 : process(
        clk_spi_160,
        rst_160_async_n
    )
    begin

        if rst_160_async_n = '0' then

            rst_160_ff1 <=
                '0';

            rst_160_ff2 <=
                '0';

        elsif rising_edge(clk_spi_160) then

            rst_160_ff1 <=
                '1';

            rst_160_ff2 <=
                rst_160_ff1;

        end if;

    end process;


    core_rst_n_160 <=
        rst_160_ff2;



    -- =================================================================
    -- Detect VIO START rising edge
    --
    -- 0 -> 1
    -- =================================================================
    U_EDGE_DETECT : entity work.edge_detect
        port map (
            i_clk =>
                clk_spi_160,

            i_rst_n =>
                core_rst_n_160,

            i_sig =>
                vio_start_v(0),

            o_rise =>
                vio_start_rise_160
        );



    -- =================================================================
    -- MAIN TEST CONTROLLER
    --
    -- work_mode = 00:
    --     original manual single-frame mode
    --
    -- work_mode = 01:
    --     automatic continuous stress test
    -- =================================================================
    P_CONTROL : process(clk_spi_160)

        variable expected_slave_rx_v :
            std_logic_vector(7 downto 0);

        variable expected_master_rx_v :
            std_logic_vector(7 downto 0);

    begin

        if rising_edge(clk_spi_160) then


            -- =========================================================
            -- RESET
            -- =========================================================
            if core_rst_n_160 = '0' then

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
                if vio_work_mode = "00" then


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


                    -- -------------------------------------------------
                    -- Capture VIO settings on START rising edge
                    -- -------------------------------------------------
                    if vio_start_rise_160 = '1' then

                        master_tx_cfg <=
                            vio_master_tx;

                        slave_tx_cfg <=
                            vio_slave_tx;

                        spi_mode_cfg <=
                            vio_spi_mode;


                        if unsigned(vio_clk_div) =
                           to_unsigned(0, 16) then

                            clk_div_cfg <=
                                to_unsigned(1, 16);

                        else

                            clk_div_cfg <=
                                unsigned(vio_clk_div);

                        end if;


                        start_pending <=
                            '1';



                    -- -------------------------------------------------
                    -- Send one-cycle START pulse
                    -- -------------------------------------------------
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
                elsif vio_work_mode = "01" then


                    start_pending <=
                        '0';


                    case auto_state is


                        -- =================================================
                        -- IDLE
                        --
                        -- Wait for START 0 -> 1.
                        --
                        -- Each new continuous-test run resets all counters.
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



                            if vio_start_rise_160 = '1' then


                                -- -----------------------------------------
                                -- Reset test statistics
                                -- -----------------------------------------
                                total_count <=
                                    (others => '0');

                                master_error_count <=
                                    (others => '0');

                                slave_error_count <=
                                    (others => '0');

                                timeout_count <=
                                    (others => '0');



                                -- -----------------------------------------
                                -- First frame
                                --
                                -- Master TX = 00
                                -- Slave TX  = FF
                                -- -----------------------------------------
                                auto_sequence <=
                                    to_unsigned(0, 8);

                                master_tx_cfg <=
                                    x"00";

                                slave_tx_cfg <=
                                    x"FF";


                                spi_mode_cfg <=
                                    vio_spi_mode;


                                if unsigned(vio_clk_div) =
                                   to_unsigned(0, 16) then

                                    clk_div_cfg <=
                                        to_unsigned(1, 16);

                                else

                                    clk_div_cfg <=
                                        unsigned(vio_clk_div);

                                end if;


                                -- Start first frame
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
                        -- WAIT FRAME
                        --
                        -- Wait for both:
                        --
                        --     master_done
                        --     slave_rx_valid
                        --
                        -- Then perform strict data comparison.
                        -- =================================================
                        when AUTO_WAIT_FRAME =>


                            -- ---------------------------------------------
                            -- Remember completion events
                            -- ---------------------------------------------
                            if master_done = '1' then

                                auto_master_done_seen <=
                                    '1';

                            end if;


                            if slave_rx_valid = '1' then

                                auto_slave_done_seen <=
                                    '1';

                            end if;



                            -- =============================================
                            -- FRAME COMPLETE
                            --
                            -- Both sides have completed.
                            -- =============================================
                            if
                                (
                                    (auto_master_done_seen = '1') or
                                    (master_done = '1')
                                )
                                and
                                (
                                    (auto_slave_done_seen = '1') or
                                    (slave_rx_valid = '1')
                                )
                            then


                                -- -----------------------------------------
                                -- Expected receive values for CURRENT frame
                                --
                                -- Master TX = sequence
                                -- Slave RX  must equal sequence
                                --
                                -- Slave TX = NOT sequence
                                -- Master RX must equal NOT sequence
                                -- -----------------------------------------
                                expected_slave_rx_v :=
                                    std_logic_vector(
                                        auto_sequence
                                    );

                                expected_master_rx_v :=
                                    not std_logic_vector(
                                        auto_sequence
                                    );


                                -- -----------------------------------------
                                -- One more frame has been tested
                                -- -----------------------------------------
                                total_count <=
                                    total_count +
                                    to_unsigned(1, 32);



                                -- -----------------------------------------
                                -- Strict Master RX comparison
                                --
                                -- One incorrect bit counts as one
                                -- erroneous frame.
                                -- -----------------------------------------
                                if master_rx_data /=
                                   expected_master_rx_v then

                                    master_error_count <=
                                        master_error_count +
                                        to_unsigned(1, 32);

                                    master_error_pulse <=
                                        '1';

                                end if;



                                -- -----------------------------------------
                                -- Strict Slave RX comparison
                                -- -----------------------------------------
                                if slave_rx_data /=
                                   expected_slave_rx_v then

                                    slave_error_count <=
                                        slave_error_count +
                                        to_unsigned(1, 32);

                                    slave_error_pulse <=
                                        '1';

                                end if;



                                -- -----------------------------------------
                                -- Current frame finished
                                -- -----------------------------------------
                                auto_master_done_seen <=
                                    '0';

                                auto_slave_done_seen <=
                                    '0';

                                frame_wait_count <=
                                    (others => '0');



                                -- -----------------------------------------
                                -- Continue?
                                -- -----------------------------------------
                                if vio_start_v(0) = '1' then


                                    -- Next sequence byte
                                    auto_sequence <=
                                        auto_sequence +
                                        to_unsigned(1, 8);


                                    -- Next Master TX
                                    master_tx_cfg <=
                                        std_logic_vector(
                                            auto_sequence +
                                            to_unsigned(1, 8)
                                        );


                                    -- Next Slave TX = NOT sequence
                                    slave_tx_cfg <=
                                        not std_logic_vector(
                                            auto_sequence +
                                            to_unsigned(1, 8)
                                        );


                                    -- Add 25 ns inter-frame gap
                                    auto_gap_count <=
                                        (others => '0');

                                    auto_state <=
                                        AUTO_GAP;



                                -- -----------------------------------------
                                -- START has returned to 0
                                -- -----------------------------------------
                                else

                                    auto_state <=
                                        AUTO_IDLE;

                                end if;



                            -- =============================================
                            -- TIMEOUT
                            --
                            -- 256 x 6.25 ns ≈ 1.6 us
                            -- =============================================
                            elsif frame_wait_count =
                                  to_unsigned(255, 8) then


                                -- Count this failed frame
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



                                -- -----------------------------------------
                                -- User asked to stop
                                -- -----------------------------------------
                                if vio_start_v(0) = '0' then

                                    auto_state <=
                                        AUTO_IDLE;



                                -- -----------------------------------------
                                -- Master is already idle:
                                -- safely prepare next frame.
                                -- -----------------------------------------
                                elsif master_busy = '0' then


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



                                -- -----------------------------------------
                                -- Master is still busy.
                                --
                                -- Do NOT change slave TX data while the
                                -- current frame may still be active.
                                -- Wait until the Master becomes idle.
                                -- -----------------------------------------
                                else

                                    auto_state <=
                                        AUTO_RECOVER;

                                end if;



                            -- =============================================
                            -- Normal waiting
                            -- =============================================
                            else

                                frame_wait_count <=
                                    frame_wait_count +
                                    to_unsigned(1, 8);

                            end if;



                        -- =================================================
                        -- RECOVER AFTER TIMEOUT
                        --
                        -- Wait until Master is no longer busy.
                        -- =================================================
                        when AUTO_RECOVER =>


                            if vio_start_v(0) = '0' then

                                auto_state <=
                                    AUTO_IDLE;


                            elsif master_busy = '0' then


                                -- Prepare next frame
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
                        -- INTER-FRAME GAP
                        --
                        -- 4 x 6.25 ns = 25 ns
                        -- =================================================
                        when AUTO_GAP =>


                            -- ---------------------------------------------
                            -- Stop requested
                            -- ---------------------------------------------
                            if vio_start_v(0) = '0' then

                                auto_gap_count <=
                                    (others => '0');

                                auto_state <=
                                    AUTO_IDLE;



                            -- ---------------------------------------------
                            -- Gap complete
                            -- ---------------------------------------------
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


                                -- Start next frame
                                master_start <=
                                    '1';


                                auto_state <=
                                    AUTO_WAIT_FRAME;



                            else

                                auto_gap_count <=
                                    auto_gap_count +
                                    to_unsigned(1, 3);

                            end if;


                    end case;



                -- =====================================================
                -- Other work modes currently unused
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



    -- =================================================================
    -- VIO
    -- =================================================================
    U_VIO : vio_0
        port map (
            clk =>
                clk_spi_160,


            -- =========================================================
            -- FPGA -> VIO
            -- =========================================================

            probe_in0 =>
                master_rx_data,

            probe_in1 =>
                slave_rx_data,


            probe_in2(0) =>
                master_busy,

            probe_in3(0) =>
                master_done,

            probe_in4(0) =>
                slave_rx_valid,

            probe_in5(0) =>
                frame_error,


            -- ---------------------------------------------------------
            -- Continuous-test statistics
            -- ---------------------------------------------------------
            probe_in6 =>
                std_logic_vector(total_count),

            probe_in7 =>
                std_logic_vector(master_error_count),

            probe_in8 =>
                std_logic_vector(slave_error_count),

            probe_in9 =>
                std_logic_vector(timeout_count),



            -- =========================================================
            -- VIO -> FPGA
            -- =========================================================

            probe_out0 =>
                vio_rst_n_v,

            probe_out1 =>
                vio_work_mode,

            probe_out2 =>
                vio_start_v,

            probe_out3 =>
                vio_master_tx,

            probe_out4 =>
                vio_slave_tx,

            probe_out5 =>
                vio_spi_mode,

            probe_out6 =>
                vio_clk_div
        );



    -- =================================================================
    -- Physical SPI pins
    -- =================================================================
    j2_sclk_out <=
        master_sclk;

    j2_cs_n_out <=
        master_cs_n;

    j2_mosi_out <=
        master_mosi;

    j3_miso_out <=
        slave_miso;



    -- =================================================================
    -- MISO timing observation
    -- 160 MHz / 0°
    -- =================================================================
    P_MISO_SAMPLE_0 : process(clk_spi_160)
    begin

        if rising_edge(clk_spi_160) then

            miso_sample_0 <=
                j2_miso_in;

        end if;

    end process;



    -- =================================================================
    -- MISO timing observation
    -- 160 MHz / 180°
    -- =================================================================
    P_MISO_SAMPLE_180 : process(clk_spi_160_shift)
    begin

        if rising_edge(clk_spi_160_shift) then

            miso_sample_180 <=
                j2_miso_in;

        end if;

    end process;



    -- =================================================================
    -- Existing SPI Master
    --
    -- IMPORTANT:
    -- This is the already verified 80 MHz version.
    -- Do not modify its internal timing here.
    -- =================================================================
    U_SPI_MASTER : entity work.spi_master_core
        port map (
            i_clk =>
                clk_spi_160,

            i_clk_shift =>
                clk_spi_160_shift,

            i_rst_n =>
                core_rst_n_160,

            i_start =>
                master_start,

            i_spi_mode =>
                spi_mode_cfg,

            i_clk_div =>
                clk_div_cfg,

            i_tx_data =>
                master_tx_cfg,

            i_miso =>
                j2_miso_in,

            o_sclk =>
                master_sclk,

            o_cs_n =>
                master_cs_n,

            o_mosi =>
                master_mosi,

            o_rx_data =>
                master_rx_data,

            o_busy =>
                master_busy,

            o_done =>
                master_done
        );



    -- =================================================================
    -- Existing SPI Slave
    --
    -- IMPORTANT:
    -- This is the already verified 80 MHz version.
    -- =================================================================
    U_SPI_SLAVE : entity work.spi_slave_core
        port map (
            i_clk =>
                clk_spi_160,

            i_rst_n =>
                core_rst_n_160,

            i_sclk =>
                j3_sclk_in,

            i_cs_n =>
                j3_cs_n_in,

            i_mosi =>
                j3_mosi_in,

            i_spi_mode =>
                spi_mode_cfg,

            i_tx_data =>
                slave_tx_cfg,

            o_miso =>
                slave_miso,

            o_rx_data =>
                slave_rx_data,

            o_rx_valid =>
                slave_rx_valid,

            o_frame_error =>
                frame_error,

            o_debug =>
                slave_debug
        );



    -- =================================================================
    -- ILA
    --
    -- Recommended waveform order:
    --
    -- Physical
    -- Timing samples
    -- Control
    -- Data
    -- Error
    -- =================================================================
    U_ILA : ila_0
        port map (
            clk =>
                clk_spi_160,


            -- =========================================================
            -- Physical SPI signals
            -- =========================================================
            probe0(0) =>
                j3_sclk_in,

            probe1(0) =>
                j3_cs_n_in,

            probe2(0) =>
                j3_mosi_in,

            probe3(0) =>
                j2_miso_in,


            -- =========================================================
            -- MISO timing observation
            -- =========================================================
            probe4(0) =>
                miso_sample_0,

            probe5(0) =>
                miso_sample_180,


            -- =========================================================
            -- Control / status
            -- =========================================================
            probe6(0) =>
                master_sclk,

            probe7(0) =>
                master_cs_n,

            probe8(0) =>
                master_busy,

            probe9(0) =>
                master_done,

            probe10(0) =>
                slave_rx_valid,


            -- =========================================================
            -- TX / RX data
            -- =========================================================
            probe11 =>
                master_tx_cfg,

            probe12 =>
                slave_tx_cfg,

            probe13 =>
                master_rx_data,

            probe14 =>
                slave_rx_data,

            probe15 =>
                slave_debug,


            -- =========================================================
            -- Error signals
            -- =========================================================
            probe16(0) =>
                frame_error,

            probe17(0) =>
                master_error_pulse,

            probe18(0) =>
                slave_error_pulse,

            probe19(0) =>
                timeout_pulse
        );


end architecture Behavioral;