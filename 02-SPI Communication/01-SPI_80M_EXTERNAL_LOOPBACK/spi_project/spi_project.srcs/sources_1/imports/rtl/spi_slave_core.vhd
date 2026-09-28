library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity spi_slave_core is
    port (
        -- 160 MHz system clock
        -- Used for status/data transfer back to the main FPGA domain
        i_clk         : in  std_logic;

        -- Active-low reset
        i_rst_n       : in  std_logic;

        -- SPI signals
        i_sclk        : in  std_logic;
        i_cs_n        : in  std_logic;
        i_mosi        : in  std_logic;

        -- Current version supports Mode 0 only
        i_spi_mode    : in  std_logic_vector(1 downto 0);

        -- Slave transmit byte
        -- Must remain stable during one SPI frame
        i_tx_data     : in  std_logic_vector(7 downto 0);

        -- SPI MISO
        o_miso        : out std_logic;

        -- Received byte transferred to 160 MHz domain
        o_rx_data     : out std_logic_vector(7 downto 0);

        -- One i_clk-cycle pulse after a complete byte
        o_rx_valid    : out std_logic;

        -- HIGH if CS ends without a complete byte
        o_frame_error : out std_logic;

        -- =============================================================
        -- DEBUG OUTPUT
        --
        -- [2:0] = rx_count_sclk
        -- [3]   = rx_done_toggle_sclk
        -- [4]   = done_meta
        -- [5]   = done_sync
        -- [6]   = done_sync_d
        -- [7]   = frame_complete_seen
        -- =============================================================
        o_debug       : out std_logic_vector(7 downto 0)
    );
end entity spi_slave_core;



architecture Behavioral of spi_slave_core is


    --------------------------------------------------------------------
    -- SPI SCLK domain: RX
    --------------------------------------------------------------------
    signal rx_shift_sclk :
        std_logic_vector(7 downto 0) := (others => '0');

    signal rx_count_sclk :
        integer range 0 to 7 := 0;

    -- Completed byte remains stable while crossing clock domains.
    signal rx_data_hold_sclk :
        std_logic_vector(7 downto 0) := (others => '0');

    -- Toggle once for every completed byte.
    signal rx_done_toggle_sclk :
        std_logic := '0';



    --------------------------------------------------------------------
    -- SPI SCLK domain: TX
    --
    -- 0 -> bit7
    -- 1 -> bit6
    -- ...
    -- 7 -> bit0
    --------------------------------------------------------------------
    signal tx_index_sclk :
        integer range 0 to 7 := 0;



    --------------------------------------------------------------------
    -- 160 MHz domain:
    -- synchronize byte-complete toggle
    --------------------------------------------------------------------
    signal done_meta :
        std_logic := '0';

    signal done_sync :
        std_logic := '0';

    signal done_sync_d :
        std_logic := '0';



    --------------------------------------------------------------------
    -- 160 MHz domain:
    -- synchronize CS for frame monitoring
    --------------------------------------------------------------------
    signal cs_meta :
        std_logic := '1';

    signal cs_sync :
        std_logic := '1';

    signal cs_sync_d :
        std_logic := '1';



    --------------------------------------------------------------------
    -- 160 MHz output registers
    --------------------------------------------------------------------
    signal rx_data_reg :
        std_logic_vector(7 downto 0) := (others => '0');

    signal rx_valid_reg :
        std_logic := '0';

    signal frame_error_reg :
        std_logic := '0';

    signal frame_complete_seen :
        std_logic := '0';



    --------------------------------------------------------------------
    -- Tell Vivado these registers form synchronization chains
    --------------------------------------------------------------------
    attribute ASYNC_REG : string;

    attribute ASYNC_REG of done_meta :
        signal is "TRUE";

    attribute ASYNC_REG of done_sync :
        signal is "TRUE";

    attribute ASYNC_REG of cs_meta :
        signal is "TRUE";

    attribute ASYNC_REG of cs_sync :
        signal is "TRUE";


begin


    --------------------------------------------------------------------
    -- Normal outputs
    --------------------------------------------------------------------
    o_rx_data <=
        rx_data_reg;

    o_rx_valid <=
        rx_valid_reg;

    o_frame_error <=
        frame_error_reg;



    --------------------------------------------------------------------
    -- DEBUG OUTPUT
    --------------------------------------------------------------------

    o_debug(2 downto 0) <=
        std_logic_vector(
            to_unsigned(rx_count_sclk, 3)
        );

    o_debug(3) <=
        rx_done_toggle_sclk;

    o_debug(4) <=
        done_meta;

    o_debug(5) <=
        done_sync;

    o_debug(6) <=
        done_sync_d;

    o_debug(7) <=
        frame_complete_seen;



    --------------------------------------------------------------------
    -- MISO OUTPUT
    --
    -- Before the first SPI clock:
    --
    --     tx_index_sclk = 0
    --
    -- therefore:
    --
    --     o_miso = i_tx_data(7)
    --
    -- so bit7 is already present before the first SCLK rising edge.
    --------------------------------------------------------------------
    o_miso <=
        '0'
        when (i_cs_n = '1') or
             (i_spi_mode /= "00")
        else
        i_tx_data(7 - tx_index_sclk);



    --------------------------------------------------------------------
    -- RX SHIFT LOGIC
    --
    -- SPI Mode 0:
    --
    -- MOSI is sampled on the returned SCLK rising edge.
    --
    -- This receive path is already working correctly at 80 MHz:
    --
    --     Master TX = 55
    --     Slave RX  = 55
    --
    -- Therefore this block is NOT changed.
    --------------------------------------------------------------------
    P_RX_SHIFT : process(
        i_sclk,
        i_rst_n,
        i_cs_n
    )
    begin

        if (i_rst_n = '0') or
           (i_cs_n = '1') then

            rx_shift_sclk <=
                (others => '0');

            rx_count_sclk <=
                0;


        elsif rising_edge(i_sclk) then

            if i_spi_mode = "00" then

                ----------------------------------------------------
                -- MSB first
                --
                -- count 0 -> bit7
                -- count 1 -> bit6
                -- ...
                -- count 7 -> bit0
                ----------------------------------------------------
                rx_shift_sclk(
                    7 - rx_count_sclk
                ) <=
                    i_mosi;


                ----------------------------------------------------
                -- After bit0:
                -- prepare for possible next byte.
                ----------------------------------------------------
                if rx_count_sclk = 7 then

                    rx_count_sclk <=
                        0;

                else

                    rx_count_sclk <=
                        rx_count_sclk + 1;

                end if;

            end if;

        end if;

    end process;



    --------------------------------------------------------------------
    -- CAPTURE COMPLETED BYTE
    --
    -- This block is also unchanged.
    --
    -- When bit0 arrives, save the complete byte and toggle
    -- rx_done_toggle_sclk so that the 160 MHz domain knows a
    -- byte has completed.
    --------------------------------------------------------------------
    P_RX_COMPLETE : process(
        i_sclk,
        i_rst_n
    )
    begin

        if i_rst_n = '0' then

            rx_data_hold_sclk <=
                (others => '0');

            rx_done_toggle_sclk <=
                '0';


        elsif rising_edge(i_sclk) then

            if (i_cs_n = '0') and
               (i_spi_mode = "00") and
               (rx_count_sclk = 7) then

                ----------------------------------------------------
                -- bit0 is sampled on this edge.
                --
                -- bits7..1 are already stored.
                ----------------------------------------------------
                rx_data_hold_sclk <=
                    rx_shift_sclk(7 downto 1) &
                    i_mosi;


                ----------------------------------------------------
                -- Complete-byte event
                ----------------------------------------------------
                rx_done_toggle_sclk <=
                    not rx_done_toggle_sclk;

            end if;

        end if;

    end process;



    --------------------------------------------------------------------
    -- TX BIT SELECTION
    --
    -- IMPORTANT CHANGE FOR THE 80 MHz EXTERNAL LOOPBACK TEST
    --
    -- OLD VERSION:
    --
    --     falling_edge(i_sclk)
    --         ->
    --     select next MISO bit
    --
    --
    -- NEW VERSION:
    --
    --     rising_edge(i_sclk)
    --         ->
    --     select next MISO bit
    --
    --
    -- WHY:
    --
    -- The returned SCLK already arrives at the Slave later than
    -- the Master's internal SCLK.
    --
    -- If we wait for the returned SCLK falling edge before
    -- selecting the next MISO bit, the new MISO bit reaches the
    -- Master too late.
    --
    -- Moving the TX index at the returned SCLK rising edge gives
    -- the NEXT MISO bit approximately half an SPI period more time
    -- to propagate back to the Master.
    --
    --
    -- IMPORTANT:
    --
    -- bit7 is still prepared before the first rising edge because
    -- tx_index_sclk is reset to 0 while CS_N is HIGH.
    --
    -- At the first returned rising edge:
    --
    --     bit7 has already been presented
    --
    -- then tx_index advances:
    --
    --     0 -> 1
    --
    -- and MISO immediately begins presenting bit6 for the NEXT
    -- Master sampling interval.
    --------------------------------------------------------------------
    P_TX_INDEX : process(
        i_sclk,
        i_rst_n,
        i_cs_n
    )
    begin

        ------------------------------------------------------------
        -- Reset / inactive frame
        --
        -- tx_index = 0 means:
        --
        --     MISO = i_tx_data(7)
        --
        -- Therefore bit7 is prepared before the first clock.
        ------------------------------------------------------------
        if (i_rst_n = '0') or
           (i_cs_n = '1') then

            tx_index_sclk <=
                0;


        ------------------------------------------------------------
        -- NEW:
        -- advance TX data on returned SCLK rising edge
        ------------------------------------------------------------
        elsif rising_edge(i_sclk) then

            if i_spi_mode = "00" then

                ----------------------------------------------------
                -- Current bit has reached its returned-SCLK
                -- sampling edge.
                --
                -- Immediately prepare the next bit.
                ----------------------------------------------------
                if tx_index_sclk < 7 then

                    tx_index_sclk <=
                        tx_index_sclk + 1;

                end if;

            end if;

        end if;

    end process;



    --------------------------------------------------------------------
    -- CLOCK DOMAIN CROSSING
    --
    -- SPI returned-SCLK domain
    --              ↓
    --        160 MHz domain
    --
    -- This block is unchanged.
    --------------------------------------------------------------------
    P_SYS_DOMAIN : process(i_clk)

        variable done_event_v :
            std_logic;

        variable cs_fall_v :
            std_logic;

        variable cs_rise_v :
            std_logic;

    begin

        if rising_edge(i_clk) then

            if i_rst_n = '0' then

                done_meta <=
                    '0';

                done_sync <=
                    '0';

                done_sync_d <=
                    '0';


                cs_meta <=
                    '1';

                cs_sync <=
                    '1';

                cs_sync_d <=
                    '1';


                rx_data_reg <=
                    (others => '0');

                rx_valid_reg <=
                    '0';


                frame_error_reg <=
                    '0';

                frame_complete_seen <=
                    '0';


            else

                ----------------------------------------------------
                -- Synchronize complete-byte toggle
                ----------------------------------------------------
                done_meta <=
                    rx_done_toggle_sclk;

                done_sync <=
                    done_meta;

                done_sync_d <=
                    done_sync;


                ----------------------------------------------------
                -- Synchronize CS
                ----------------------------------------------------
                cs_meta <=
                    i_cs_n;

                cs_sync <=
                    cs_meta;

                cs_sync_d <=
                    cs_sync;


                ----------------------------------------------------
                -- RX valid defaults LOW
                ----------------------------------------------------
                rx_valid_reg <=
                    '0';


                ----------------------------------------------------
                -- Detect events using OLD register values
                ----------------------------------------------------
                done_event_v :=
                    done_sync xor done_sync_d;


                if (cs_sync = '0') and
                   (cs_sync_d = '1') then

                    cs_fall_v :=
                        '1';

                else

                    cs_fall_v :=
                        '0';

                end if;


                if (cs_sync = '1') and
                   (cs_sync_d = '0') then

                    cs_rise_v :=
                        '1';

                else

                    cs_rise_v :=
                        '0';

                end if;



                ----------------------------------------------------
                -- Completed SPI byte arrived
                ----------------------------------------------------
                if done_event_v = '1' then

                    rx_data_reg <=
                        rx_data_hold_sclk;

                    rx_valid_reg <=
                        '1';

                end if;



                ----------------------------------------------------
                -- Frame monitor
                ----------------------------------------------------
                if cs_rise_v = '1' then

                    ------------------------------------------------
                    -- If completion has already been seen,
                    -- or completion arrives in this same cycle,
                    -- the frame is valid.
                    ------------------------------------------------
                    if (frame_complete_seen = '1') or
                       (done_event_v = '1') then

                        frame_error_reg <=
                            '0';

                    else

                        frame_error_reg <=
                            '1';

                    end if;


                    frame_complete_seen <=
                        '0';


                elsif cs_fall_v = '1' then

                    ------------------------------------------------
                    -- Start a new frame
                    ------------------------------------------------
                    frame_complete_seen <=
                        '0';

                    frame_error_reg <=
                        '0';


                elsif done_event_v = '1' then

                    frame_complete_seen <=
                        '1';

                end if;

            end if;

        end if;

    end process;


end architecture Behavioral;