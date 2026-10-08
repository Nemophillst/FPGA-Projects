library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity spi_master_core is
    port (
        -- =============================================================
        -- Main clock
        --
        -- 160 MHz / 0 degree
        -- =============================================================
        i_clk       : in  std_logic;


        -- =============================================================
        -- Shifted sampling clock
        --
        -- 160 MHz / 180 degree
        --
        -- Relative to i_clk:
        --     3.125 ns
        --
        -- Used only for delayed MISO sampling at 80 MHz.
        -- =============================================================
        i_clk_shift : in  std_logic;


        -- Active-low reset
        i_rst_n     : in  std_logic;


        -- Start pulse
        i_start     : in  std_logic;


        -- SPI Mode
        --
        -- Current version supports Mode 0.
        i_spi_mode  : in  std_logic_vector(1 downto 0);


        -- =============================================================
        -- SPI divider
        --
        -- Main clock = 160 MHz
        --
        -- CLK_DIV = 1 -> 80 MHz SPI
        -- CLK_DIV = 2 -> 40 MHz SPI
        -- CLK_DIV = 4 -> 20 MHz SPI
        -- =============================================================
        i_clk_div   : in  unsigned(15 downto 0);


        -- Master transmit byte
        i_tx_data   : in  std_logic_vector(7 downto 0);


        -- Physical returned MISO
        i_miso      : in  std_logic;


        -- SPI outputs
        o_sclk      : out std_logic;
        o_cs_n      : out std_logic;
        o_mosi      : out std_logic;


        -- Received byte
        o_rx_data   : out std_logic_vector(7 downto 0);


        -- Status
        o_busy      : out std_logic;
        o_done      : out std_logic
    );
end entity spi_master_core;



architecture Behavioral of spi_master_core is


    -- =================================================================
    -- SPI output registers
    -- =================================================================
    signal sclk_reg :
        std_logic := '0';

    signal cs_n_reg :
        std_logic := '1';

    signal mosi_reg :
        std_logic := '0';



    -- =================================================================
    -- Status registers
    -- =================================================================
    signal busy_reg :
        std_logic := '0';

    signal done_reg :
        std_logic := '0';



    -- =================================================================
    -- Receive registers
    --
    -- 20 / 40 MHz:
    --     sample MISO directly on SCLK rising edge.
    --
    -- 80 MHz:
    --     MISO is sampled by i_clk_shift after the Master-generated
    --     SCLK falling edge.
    -- =================================================================
    signal rx_shift_reg :
        std_logic_vector(7 downto 0) := (others => '0');


    signal rx_data_reg :
        std_logic_vector(7 downto 0) := (others => '0');



    -- =================================================================
    -- TX byte register
    -- =================================================================
    signal tx_data_reg :
        std_logic_vector(7 downto 0) := (others => '0');



    -- =================================================================
    -- SPI bit counter
    --
    -- 0 -> bit7
    -- 1 -> bit6
    -- ...
    -- 7 -> bit0
    -- =================================================================
    signal bit_count :
        integer range 0 to 7 := 0;



    -- =================================================================
    -- Divider counter
    -- =================================================================
    signal div_count :
        unsigned(15 downto 0) := (others => '0');



    -- =================================================================
    -- CS setup interval
    --
    -- At 80 MHz:
    -- keep CS low before first SCLK rising edge.
    -- =================================================================
    signal cs_setup_active :
        std_logic := '0';


    signal cs_setup_count :
        unsigned(15 downto 0) := (others => '0');



    -- =================================================================
    -- 80 MHz shifted-clock sampler
    --
    -- This is the ONLY register owned by i_clk_shift.
    --
    -- It continuously samples the physical MISO line.
    -- =================================================================
    signal rx80_sample_bit :
        std_logic := '0';



    -- =================================================================
    -- 80 MHz sample bookkeeping
    --
    -- Current experiment:
    --
    -- Master SCLK falling edge
    --         ↓
    -- mark sample pending
    --         ↓
    -- wait 3.125 ns
    --         ↓
    -- i_clk_shift captures physical MISO
    --         ↓
    -- following i_clk edge
    --         ↓
    -- save sampled bit into RX register
    -- =================================================================
    signal rx80_sample_pending :
        std_logic := '0';


    signal rx80_sample_index :
        integer range 0 to 7 := 0;



    -- =================================================================
    -- Final 80 MHz bit handling
    --
    -- After the final SCLK falling edge:
    --
    -- do NOT immediately raise CS.
    --
    -- Wait until i_clk_shift captures final bit0.
    -- Then finish the transaction on the following main-clock edge.
    -- =================================================================
    signal rx80_last_pending :
        std_logic := '0';



begin


    -- =================================================================
    -- Outputs
    -- =================================================================
    o_sclk <=
        sclk_reg;

    o_cs_n <=
        cs_n_reg;

    o_mosi <=
        mosi_reg;

    o_rx_data <=
        rx_data_reg;

    o_busy <=
        busy_reg;

    o_done <=
        done_reg;



    -- =================================================================
    -- 80 MHz MISO SAMPLER
    --
    -- i_clk_shift:
    --     160 MHz / 180°
    --
    -- The clock rises 3.125 ns after each i_clk rising edge.
    --
    -- In the current 80 MHz scheme:
    --
    -- i_clk edge generates SCLK falling
    --         ↓
    -- 3.125 ns
    --         ↓
    -- i_clk_shift captures MISO
    -- =================================================================
    P_RX80_SAMPLE : process(i_clk_shift)
    begin

        if rising_edge(i_clk_shift) then

            rx80_sample_bit <=
                i_miso;

        end if;

    end process;



    -- =================================================================
    -- MAIN SPI MASTER
    --
    -- Clock:
    --     160 MHz / 0°
    -- =================================================================
    P_SPI_MASTER : process(i_clk)
    begin

        if rising_edge(i_clk) then


            -- =========================================================
            -- RESET
            -- =========================================================
            if i_rst_n = '0' then

                sclk_reg <=
                    '0';

                cs_n_reg <=
                    '1';

                mosi_reg <=
                    '0';


                busy_reg <=
                    '0';

                done_reg <=
                    '0';


                rx_shift_reg <=
                    (others => '0');

                rx_data_reg <=
                    (others => '0');

                tx_data_reg <=
                    (others => '0');


                bit_count <=
                    0;

                div_count <=
                    (others => '0');


                cs_setup_active <=
                    '0';

                cs_setup_count <=
                    (others => '0');


                rx80_sample_pending <=
                    '0';

                rx80_sample_index <=
                    0;

                rx80_last_pending <=
                    '0';



            else


                -- =====================================================
                -- DONE pulse defaults LOW every main-clock cycle
                -- =====================================================
                done_reg <=
                    '0';



                -- =====================================================
                -- IDLE
                -- =====================================================
                if busy_reg = '0' then

                    sclk_reg <=
                        '0';

                    cs_n_reg <=
                        '1';

                    mosi_reg <=
                        '0';


                    div_count <=
                        (others => '0');


                    cs_setup_active <=
                        '0';

                    cs_setup_count <=
                        (others => '0');


                    rx80_sample_pending <=
                        '0';

                    rx80_sample_index <=
                        0;

                    rx80_last_pending <=
                        '0';



                    -- =================================================
                    -- START NEW TRANSACTION
                    -- =================================================
                    if (i_start = '1') and
                       (i_spi_mode = "00") then


                        busy_reg <=
                            '1';


                        -- Select Slave
                        cs_n_reg <=
                            '0';


                        -- Mode-0 idle level
                        sclk_reg <=
                            '0';


                        -- Latch TX data
                        tx_data_reg <=
                            i_tx_data;


                        -- Clear RX shift register
                        rx_shift_reg <=
                            (others => '0');


                        -- Start from SPI bit7
                        bit_count <=
                            0;


                        -- Mode 0:
                        -- MOSI bit7 is valid before first SCLK rising edge.
                        mosi_reg <=
                            i_tx_data(7);


                        -- CS setup interval
                        cs_setup_active <=
                            '1';

                        cs_setup_count <=
                            (others => '0');


                        rx80_sample_pending <=
                            '0';

                        rx80_sample_index <=
                            0;

                        rx80_last_pending <=
                            '0';

                    end if;



                -- =====================================================
                -- BUSY
                -- =====================================================
                else


                    -- =================================================
                    -- FINAL 80 MHz SAMPLE
                    --
                    -- Previous main-clock edge generated the final
                    -- SCLK falling edge.
                    --
                    -- i_clk_shift then captured MISO bit0.
                    --
                    -- We now save bit0 and finish.
                    -- =================================================
                    if rx80_last_pending = '1' then


                        rx_shift_reg(0) <=
                            rx80_sample_bit;


                        -- Publish the complete received byte.
                        rx_data_reg <=
                            rx_shift_reg(7 downto 1) &
                            rx80_sample_bit;


                        -- Return interface to idle.
                        cs_n_reg <=
                            '1';

                        sclk_reg <=
                            '0';

                        mosi_reg <=
                            '0';


                        busy_reg <=
                            '0';

                        done_reg <=
                            '1';


                        rx80_sample_pending <=
                            '0';

                        rx80_last_pending <=
                            '0';



                    -- =================================================
                    -- CS SETUP INTERVAL
                    -- =================================================
                    elsif cs_setup_active = '1' then


                        sclk_reg <=
                            '0';


                        div_count <=
                            (others => '0');


                        -- ------------------------------------------------
                        -- 80 MHz
                        --
                        -- Keep the existing longer CS setup interval.
                        -- ------------------------------------------------
                        if i_clk_div <=
                           to_unsigned(1, 16) then


                            if cs_setup_count =
                               to_unsigned(2, 16) then

                                cs_setup_active <=
                                    '0';

                                cs_setup_count <=
                                    (others => '0');

                            else

                                cs_setup_count <=
                                    cs_setup_count + 1;

                            end if;



                        -- ------------------------------------------------
                        -- 20 / 40 MHz
                        -- ------------------------------------------------
                        elsif cs_setup_count =
                              (i_clk_div - 1) then


                            cs_setup_active <=
                                '0';

                            cs_setup_count <=
                                (others => '0');


                        else

                            cs_setup_count <=
                                cs_setup_count + 1;

                        end if;



                    -- =================================================
                    -- NORMAL SPI TRANSFER
                    -- =================================================
                    else


                        -- =================================================
                        -- 80 MHz
                        --
                        -- CLK_DIV = 1
                        -- =================================================
                        if i_clk_div <=
                           to_unsigned(1, 16) then


                            div_count <=
                                (others => '0');


                            -- ------------------------------------------------
                            -- If the previous main-clock edge generated
                            -- SCLK falling, the shifted clock has already
                            -- captured the delayed MISO value.
                            --
                            -- Copy it into rx_shift_reg now.
                            -- ------------------------------------------------
                            if rx80_sample_pending = '1' then

                                rx_shift_reg(
                                    7 - rx80_sample_index
                                ) <=
                                    rx80_sample_bit;


                                rx80_sample_pending <=
                                    '0';

                            end if;



                            -- ------------------------------------------------
                            -- SCLK LOW -> HIGH
                            --
                            -- Mode-0 active sampling edge on MOSI/Slave side.
                            --
                            -- For this experiment we do NOT capture MISO
                            -- here. We intentionally wait until after the
                            -- following falling edge.
                            -- ------------------------------------------------
                            if sclk_reg = '0' then

                                sclk_reg <=
                                    '1';



                            -- ------------------------------------------------
                            -- SCLK HIGH -> LOW
                            --
                            -- Arm the delayed MISO capture.
                            --
                            -- 3.125 ns after this edge:
                            --
                            --     i_clk_shift samples i_miso
                            -- ------------------------------------------------
                            else

                                sclk_reg <=
                                    '0';


                                -- Remember which SPI bit the sample
                                -- belongs to.
                                rx80_sample_index <=
                                    bit_count;


                                rx80_sample_pending <=
                                    '1';


                                -- -----------------------------------------
                                -- Final bit
                                -- -----------------------------------------
                                if bit_count = 7 then


                                    -- Do not immediately release CS.
                                    --
                                    -- Wait for shifted-clock sample bit0.
                                    rx80_last_pending <=
                                        '1';


                                    mosi_reg <=
                                        '0';



                                -- -----------------------------------------
                                -- Prepare next MOSI bit
                                -- -----------------------------------------
                                else

                                    bit_count <=
                                        bit_count + 1;


                                    mosi_reg <=
                                        tx_data_reg(
                                            6 - bit_count
                                        );

                                end if;

                            end if;



                        -- =================================================
                        -- 20 / 40 MHz
                        --
                        -- Keep original logic unchanged.
                        --
                        -- MISO is sampled directly on SCLK rising edge.
                        -- =================================================
                        elsif div_count =
                              (i_clk_div - 1) then


                            div_count <=
                                (others => '0');


                            -- ---------------------------------------------
                            -- SCLK LOW -> HIGH
                            -- ---------------------------------------------
                            if sclk_reg = '0' then

                                sclk_reg <=
                                    '1';


                                rx_shift_reg(
                                    7 - bit_count
                                ) <=
                                    i_miso;



                            -- ---------------------------------------------
                            -- SCLK HIGH -> LOW
                            -- ---------------------------------------------
                            else

                                sclk_reg <=
                                    '0';


                                -- -----------------------------------------
                                -- Final bit
                                -- -----------------------------------------
                                if bit_count = 7 then


                                    cs_n_reg <=
                                        '1';


                                    busy_reg <=
                                        '0';


                                    done_reg <=
                                        '1';


                                    rx_data_reg <=
                                        rx_shift_reg;


                                    mosi_reg <=
                                        '0';



                                -- -----------------------------------------
                                -- Prepare next MOSI bit
                                -- -----------------------------------------
                                else

                                    bit_count <=
                                        bit_count + 1;


                                    mosi_reg <=
                                        tx_data_reg(
                                            6 - bit_count
                                        );

                                end if;

                            end if;



                        -- =================================================
                        -- Divider has not reached half-period
                        -- =================================================
                        else

                            div_count <=
                                div_count + 1;

                        end if;

                    end if;

                end if;

            end if;

        end if;

    end process;


end architecture Behavioral;