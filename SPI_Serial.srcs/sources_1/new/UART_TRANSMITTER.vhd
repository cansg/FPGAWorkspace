----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Cansu Gencoglu
-- 
-- Create Date: 11/14/2020 06:07:01 PM
-- Design Name: 
-- Module Name: UART_TRANSMITTER - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;


--use IEEE.NUMERIC_STD.ALL;

--library UNISIM;
--use UNISIM.VComponents.all;

entity UART_TRANSMITTER is
  generic (
    g_CLKS_PER_BIT : integer := 115     -- Needs to be set correctly
    );
  port (
    i_Clk       : in  std_logic;
    i_TX_DV     : in  std_logic;
    i_TX_Byte   : in  std_logic_vector(7 downto 0);
    --o_TX_Active : out std_logic;
    o_TX_Serial : out std_logic;
    o_TX_Done   : out std_logic
    );
end UART_TRANSMITTER;

architecture Behavioral of UART_TRANSMITTER is

    constant tx_start_bit : std_logic := '0';
    constant tx_idle_bit  : std_logic := '1';

    signal sig_tx_byte   : std_logic_vector(7 downto 0) := (others => '0');
    signal sig_tx_done   : std_logic := '0';
    signal sig_clk_count : integer range 0 to g_CLKS_PER_BIT-1 := 0;
    signal sig_bit_loc  : integer range 0 to 7 := 0;  
    
    type UART_State_Type is (uart_idle, uart_start, uart_send_byte,
                     uart_stop, uart_clean);
                     
    signal uart_state: UART_State_Type := uart_idle;
  
begin

uart: process(i_Clk)
  begin
        if rising_edge(i_Clk) then 
        case uart_state is
     
            when uart_idle =>

                o_TX_Serial   <= tx_idle_bit;         -- always 1 on idle state
                sig_tx_done   <= '0';
                sig_bit_loc   <= 0;
                sig_clk_count <= 0;
                if i_TX_DV = '1' then
                    sig_tx_byte <= i_TX_Byte;
                    uart_state <= uart_start;      
                end if;
                
            when uart_start => --start uart byte transmission
                o_TX_Serial <= tx_start_bit;

                if sig_clk_count < g_CLKS_PER_BIT-1 then --wait for valid baud rate
                    sig_clk_count <= sig_clk_count + 1;
                else
                    sig_clk_count <= 0;
                    uart_state   <= uart_send_byte;
                end if;
                
            when uart_send_byte =>
               o_TX_Serial <= sig_tx_byte(sig_bit_loc);
           
              if sig_clk_count < g_CLKS_PER_BIT-1 then
                sig_clk_count <= sig_clk_count + 1;
                uart_state   <= uart_send_byte;
              else
                sig_clk_count <= 0;
                 
                if sig_bit_loc < 7 then
                  sig_bit_loc <= sig_bit_loc + 1;
                  uart_state   <= uart_send_byte;
                else
                  sig_bit_loc <= 0;
                  uart_state   <= uart_stop;
                end if;
               end if;
            
            when uart_stop =>
            
          o_TX_Serial <= '1';
                if sig_clk_count < g_CLKS_PER_BIT-1 then --wait for valid baud rate
                    sig_clk_count <= sig_clk_count + 1;
                else
                    sig_clk_count <= 0;
                    sig_tx_done   <= '1';
                    uart_state   <= uart_clean;
                end if;
                    -- Stay here 1 clock
--        when uart_clean =>
--          sig_tx_done   <= '1';
--          uart_state   <= uart_idle;
          
            when others =>
                uart_state <= uart_idle;
        end case;
    end if;
    o_TX_Done <= sig_tx_done;

  end process;
  
end Behavioral;
