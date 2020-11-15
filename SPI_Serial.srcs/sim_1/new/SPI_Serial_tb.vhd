-- Testbench automatically generated online
-- at https://vhdl.lapinoo.net
-- Generation date : 12.11.2020 14:02:55 UTC

library ieee;
use ieee.std_logic_1164.all;

entity tb_spi_to_serial is
end tb_spi_to_serial;

architecture tb of tb_spi_to_serial is

    component spi_to_serial
        port (sysclk     : in std_logic;
              btn0       : in std_logic;
              btn1       : in std_logic;
              led1       : out std_logic;
              led0       : out std_logic;
              o_SPI_Clk  : out std_logic;
              i_SPI_MISO : in std_logic;
              o_SPI_MOSI : out std_logic;
              o_SPI_CS_n : out std_logic;
              i_ser_rx   : in std_logic;
              o_ser_tx   : out std_logic);
    end component;

    signal sysclk     : std_logic;
    signal btn0       : std_logic;
    signal btn1       : std_logic;
    signal led1       : std_logic;
    signal led0       : std_logic;
    signal o_SPI_Clk  : std_logic;
    signal i_SPI_MISO : std_logic;
    signal o_SPI_MOSI : std_logic;
    signal o_SPI_CS_n : std_logic;
    signal i_ser_rx   : std_logic;
    signal o_ser_tx   : std_logic;

    constant TbPeriod : time := 10 ns; -- EDIT Put right period here
    signal TbClock : std_logic := '0';
    signal TbSimEnded : std_logic := '0';

begin

    dut : spi_to_serial
    port map (sysclk     => sysclk,
              btn0       => btn0,
              btn1       => btn1,
              led1       => led1,
              led0       => led0,
              o_SPI_Clk  => o_SPI_Clk,
              i_SPI_MISO => o_SPI_MOSI,
              o_SPI_MOSI => o_SPI_MOSI,
              o_SPI_CS_n => o_SPI_CS_n,
              i_ser_rx   => i_ser_rx,
              o_ser_tx   => o_ser_tx);

    -- Clock generation
    TbClock <= not TbClock after TbPeriod/2 when TbSimEnded /= '1' else '0';

    -- EDIT: Check that sysclk is really your main clock signal
    sysclk <= TbClock;

    stimuli : process
    begin
        -- EDIT Adapt initialization as needed
        btn0 <= '0';
        btn1 <= '0';
        i_SPI_MISO <= '0';
        i_ser_rx <= '0';

        -- Reset generation
        --  EDIT: Replace YOURRESETSIGNAL below by the name of your reset as I haven't guessed it
    btn0 <= '1';
    wait for 100 ns;
    btn0 <= '0';
    wait for 100 ns;

        -- EDIT Add stimuli here
        wait for 1000000 * TbPeriod;

        -- Stop the clock and hence terminate the simulation
        TbSimEnded <= '1';
        wait;
    end process;

end tb;

-- Configuration block below is required by some simulators. Usually no need to edit.

configuration cfg_tb_spi_to_serial of tb_spi_to_serial is
    for tb
    end for;
end cfg_tb_spi_to_serial;