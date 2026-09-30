library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity spi_top is
    port (

        -- =============================================================
        -- Board clock / reset
        -- =============================================================

        -- 50 MHz board clock
        sys_clk :
            in std_logic;

        -- Physical reset button
        -- Active low
        sys_rst_n :
            in std_logic;


        -- =============================================================
        -- External SPI loopback pins
        -- =============================================================

        -- Master -> external wire -> Slave
        j2_sclk_out :
            out std_logic;

        j2_cs_n_out :
            out std_logic;

        j2_mosi_out :
            out std_logic;


        -- Slave -> external wire -> Master
        j2_miso_in :
            in std_logic;


        -- External wire -> Slave
        j3_sclk_in :
            in std_logic;

        j3_cs_n_in :
            in std_logic;

        j3_mosi_in :
            in std_logic;


        -- Slave -> external wire
        j3_miso_out :
            out std_logic

    );
end entity spi_top;



architecture Behavioral of spi_top is


    -- =================================================================
    -- VIO IP
    -- =================================================================

    component vio_0
        port (

            clk :
                in std_logic;


            -- FPGA -> VIO

            probe_in0 :
                in std_logic_vector(7 downto 0);

            probe_in1 :
                in std_logic_vector(7 downto 0);

            probe_in2 :
                in std_logic_vector(0 downto 0);

            probe_in3 :
                in std_logic_vector(0 downto 0);

            probe_in4 :
                in std_logic_vector(0 downto 0);

            probe_in5 :
                in std_logic_vector(0 downto 0);

            probe_in6 :
                in std_logic_vector(31 downto 0);

            probe_in7 :
                in std_logic_vector(31 downto 0);

            probe_in8 :
                in std_logic_vector(31 downto 0);

            probe_in9 :
                in std_logic_vector(31 downto 0);


            -- VIO -> FPGA

            probe_out0 :
                out std_logic_vector(0 downto 0);

            probe_out1 :
                out std_logic_vector(1 downto 0);

            probe_out2 :
                out std_logic_vector(0 downto 0);

            probe_out3 :
                out std_logic_vector(7 downto 0);

            probe_out4 :
                out std_logic_vector(7 downto 0);

            probe_out5 :
                out std_logic_vector(1 downto 0);

            probe_out6 :
                out std_logic_vector(15 downto 0)

        );
    end component;



    -- =================================================================
    -- ILA IP
    -- =================================================================

    component ila_0
        port (

            clk :
                in std_logic;


            -- Physical SPI

            probe0 :
                in std_logic_vector(0 downto 0);

            probe1 :
                in std_logic_vector(0 downto 0);

            probe2 :
                in std_logic_vector(0 downto 0);

            probe3 :
                in std_logic_vector(0 downto 0);


            -- MISO timing observation

            probe4 :
                in std_logic_vector(0 downto 0);

            probe5 :
                in std_logic_vector(0 downto 0);


            -- Control / Status

            probe6 :
                in std_logic_vector(0 downto 0);

            probe7 :
                in std_logic_vector(0 downto 0);

            probe8 :
                in std_logic_vector(0 downto 0);

            probe9 :
                in std_logic_vector(0 downto 0);

            probe10 :
                in std_logic_vector(0 downto 0);


            -- Data

            probe11 :
                in std_logic_vector(7 downto 0);

            probe12 :
                in std_logic_vector(7 downto 0);

            probe13 :
                in std_logic_vector(7 downto 0);

            probe14 :
                in std_logic_vector(7 downto 0);

            probe15 :
                in std_logic_vector(7 downto 0);


            -- Error information

            probe16 :
                in std_logic_vector(0 downto 0);

            probe17 :
                in std_logic_vector(0 downto 0);

            probe18 :
                in std_logic_vector(0 downto 0);

            probe19 :
                in std_logic_vector(0 downto 0)

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
    -- Clock Wizard signals
    -- =================================================================

    -- 160 MHz / 0 degree
    signal clk_spi_160 :
        std_logic;


    -- 160 MHz / 180 degree
    --
    -- 160 MHz period = 6.25 ns
    --
    -- 180 degree offset = 3.125 ns
    signal clk_spi_160_shift :
        std_logic;


    signal clk_locked :
        std_logic;


    signal clk_wiz_reset :
        std_logic;



    -- =================================================================
    -- Reset signals
    -- =================================================================

    -- Raw asynchronous reset condition
    signal rst_160_async_n :
        std_logic;


    -- Reset synchronized to clk_spi_160
    signal core_rst_n_160 :
        std_logic;



    -- =================================================================
    -- VIO START edge
    -- =================================================================

    signal vio_start_rise_160 :
        std_logic;



    -- =================================================================
    -- spi_test_controller -> SPI cores
    -- =================================================================

    -- One-clock START pulse for Master
    signal master_start :
        std_logic := '0';


    -- Actual Master TX data
    signal master_tx_cfg :
        std_logic_vector(7 downto 0) :=
        (others => '0');


    -- Actual Slave TX data
    signal slave_tx_cfg :
        std_logic_vector(7 downto 0) :=
        (others => '0');


    -- Actual SPI mode
    signal spi_mode_cfg :
        std_logic_vector(1 downto 0) :=
        "00";


    -- Actual SPI clock divider
    signal clk_div_cfg :
        unsigned(15 downto 0) :=
        to_unsigned(1, 16);



    -- =================================================================
    -- Continuous test statistics
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
    -- ILA trigger pulses
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


    signal slave_debug :
        std_logic_vector(7 downto 0);



    -- =================================================================
    -- MISO timing observation
    -- =================================================================

    signal miso_sample_0 :
        std_logic := '0';


    signal miso_sample_180 :
        std_logic := '0';



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
    -- Outputs:
    --     160 MHz / 0 degree
    --     160 MHz / 180 degree
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
    --
    -- FPGA can leave reset only when:
    --
    -- sys_rst_n      = 1
    -- VIO reset      = 1
    -- Clock Wizard locked = 1
    -- =================================================================

    rst_160_async_n <=
        sys_rst_n and
        vio_rst_n_v(0) and
        clk_locked;



    -- =================================================================
    -- Reset synchronizer
    --
    -- The original P_RESET_160 logic has been moved to:
    --
    -- reset_sync.vhd
    -- =================================================================

    U_RESET_SYNC : entity work.reset_sync
        port map (

            i_clk =>
                clk_spi_160,

            i_async_n =>
                rst_160_async_n,

            o_sync_n =>
                core_rst_n_160

        );



    -- =================================================================
    -- VIO START rising-edge detector
    --
    -- Detect:
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
    -- SPI Test Controller
    --
    -- The original P_CONTROL logic has now been moved to:
    --
    -- spi_test_controller.vhd
    --
    -- This module handles:
    --
    -- Manual single-frame mode
    -- Automatic continuous mode
    -- TX data configuration
    -- START generation
    -- RX comparison
    -- Error counters
    -- Timeout
    -- =================================================================

    U_TEST_CONTROLLER : entity work.spi_test_controller
        port map (

            -- =========================================================
            -- Clock / Reset
            -- =========================================================

            i_clk =>
                clk_spi_160,

            i_rst_n =>
                core_rst_n_160,


            -- =========================================================
            -- VIO / User control
            -- =========================================================

            i_work_mode =>
                vio_work_mode,

            i_start_level =>
                vio_start_v(0),

            i_start_rise =>
                vio_start_rise_160,

            i_master_tx =>
                vio_master_tx,

            i_slave_tx =>
                vio_slave_tx,

            i_spi_mode =>
                vio_spi_mode,

            i_clk_div =>
                vio_clk_div,


            -- =========================================================
            -- Feedback from SPI Master
            -- =========================================================

            i_master_rx_data =>
                master_rx_data,

            i_master_busy =>
                master_busy,

            i_master_done =>
                master_done,


            -- =========================================================
            -- Feedback from SPI Slave
            -- =========================================================

            i_slave_rx_data =>
                slave_rx_data,

            i_slave_rx_valid =>
                slave_rx_valid,


            -- =========================================================
            -- Outputs to SPI cores
            -- =========================================================

            o_master_start =>
                master_start,

            o_master_tx_cfg =>
                master_tx_cfg,

            o_slave_tx_cfg =>
                slave_tx_cfg,

            o_spi_mode_cfg =>
                spi_mode_cfg,

            o_clk_div_cfg =>
                clk_div_cfg,


            -- =========================================================
            -- Continuous-test statistics
            -- =========================================================

            o_total_count =>
                total_count,

            o_master_error_count =>
                master_error_count,

            o_slave_error_count =>
                slave_error_count,

            o_timeout_count =>
                timeout_count,


            -- =========================================================
            -- ILA error / timeout pulses
            -- =========================================================

            o_master_error_pulse =>
                master_error_pulse,

            o_slave_error_pulse =>
                slave_error_pulse,

            o_timeout_pulse =>
                timeout_pulse

        );



    -- =================================================================
    -- VIO
    --
    -- Probe mapping remains unchanged.
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


            -- =========================================================
            -- Continuous-test statistics
            -- =========================================================

            probe_in6 =>
                std_logic_vector(
                    total_count
                ),


            probe_in7 =>
                std_logic_vector(
                    master_error_count
                ),


            probe_in8 =>
                std_logic_vector(
                    slave_error_count
                ),


            probe_in9 =>
                std_logic_vector(
                    timeout_count
                ),


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
    -- Physical SPI outputs
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
    -- MISO observation
    --
    -- Sample at:
    --
    -- 160 MHz / 0 degree
    -- =================================================================

    P_MISO_SAMPLE_0 : process(
        clk_spi_160
    )
    begin

        if rising_edge(clk_spi_160) then

            miso_sample_0 <=
                j2_miso_in;

        end if;

    end process;



    -- =================================================================
    -- MISO observation
    --
    -- Sample at:
    --
    -- 160 MHz / 180 degree
    --
    -- Relative to 0 degree:
    --
    -- 3.125 ns
    -- =================================================================

    P_MISO_SAMPLE_180 : process(
        clk_spi_160_shift
    )
    begin

        if rising_edge(clk_spi_160_shift) then

            miso_sample_180 <=
                j2_miso_in;

        end if;

    end process;



    -- =================================================================
    -- SPI Master
    --
    -- IMPORTANT:
    --
    -- The internal 80 MHz timing logic of spi_master_core
    -- has NOT been changed.
    --
    -- Keep instance name:
    --
    -- U_SPI_MASTER
    --
    -- because existing XDC constraints may depend on this hierarchy.
    -- =================================================================

    U_SPI_MASTER : entity work.spi_master_core
        port map (

            -- Main 160 MHz clock
            i_clk =>
                clk_spi_160,


            -- Shifted 160 MHz clock
            i_clk_shift =>
                clk_spi_160_shift,


            -- Reset
            i_rst_n =>
                core_rst_n_160,


            -- Start pulse
            i_start =>
                master_start,


            -- SPI configuration
            i_spi_mode =>
                spi_mode_cfg,


            i_clk_div =>
                clk_div_cfg,


            -- TX data
            i_tx_data =>
                master_tx_cfg,


            -- Physical MISO input
            i_miso =>
                j2_miso_in,


            -- SPI outputs
            o_sclk =>
                master_sclk,


            o_cs_n =>
                master_cs_n,


            o_mosi =>
                master_mosi,


            -- Received byte
            o_rx_data =>
                master_rx_data,


            -- Status
            o_busy =>
                master_busy,


            o_done =>
                master_done

        );



    -- =================================================================
    -- SPI Slave
    --
    -- IMPORTANT:
    --
    -- The internal 80 MHz timing logic of spi_slave_core
    -- has NOT been changed.
    --
    -- Keep instance name:
    --
    -- U_SPI_SLAVE
    --
    -- because existing XDC constraints may depend on this hierarchy.
    -- =================================================================

    U_SPI_SLAVE : entity work.spi_slave_core
        port map (

            -- Internal 160 MHz clock
            i_clk =>
                clk_spi_160,


            -- Reset
            i_rst_n =>
                core_rst_n_160,


            -- Physical SPI inputs
            i_sclk =>
                j3_sclk_in,


            i_cs_n =>
                j3_cs_n_in,


            i_mosi =>
                j3_mosi_in,


            -- SPI configuration
            i_spi_mode =>
                spi_mode_cfg,


            -- Slave TX data
            i_tx_data =>
                slave_tx_cfg,


            -- Physical MISO output
            o_miso =>
                slave_miso,


            -- Received byte
            o_rx_data =>
                slave_rx_data,


            -- Receive complete
            o_rx_valid =>
                slave_rx_valid,


            -- Error
            o_frame_error =>
                frame_error,


            -- Internal debug
            o_debug =>
                slave_debug

        );



    -- =================================================================
    -- ILA
    --
    -- Probe mapping remains the same as the original project.
    -- =================================================================

    U_ILA : ila_0
        port map (

            clk =>
                clk_spi_160,


            -- =========================================================
            -- Physical SPI
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
            -- Master control / status
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