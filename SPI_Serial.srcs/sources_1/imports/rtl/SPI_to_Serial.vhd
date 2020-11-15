
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity spi_to_serial is
  port ( 
        sysclk         : in  std_logic;
              
        btn0           : in std_logic;
        btn1           : in std_logic;

        led1           : out std_logic;
        led0           : out std_logic;

        -- SPI Interface
        o_SPI_Clk  : out std_logic;
        i_SPI_MISO : in std_logic;
        o_SPI_MOSI : out std_logic;
        o_SPI_CS_n : out std_logic;
        
        -- Serial Interface
        i_ser_rx         : in std_logic;
        o_ser_tx         : out std_logic
        );

end spi_to_serial;

architecture rtl of spi_to_serial is

  --types and signals for counter and blink led
  type BLINK is range 0 to 100000000;
  signal flag_1Hz : std_logic := '0';
  signal eight_bit_count : std_logic_vector(7 downto 0):= "00000000";
  
  type send_count_eight_state_type is (send_ready_1,
                                        send_end_1,
                                        send_ready_2,
                                        send_end_2);
                                        
  type wait_state_type is (wait_for_it,
                       wait_done);
                       
  signal count_eight_state : send_count_eight_state_type := send_ready_1;
  signal ila_test_MISO : std_logic_vector(0 downto 0):= "0";
  signal ila_test_CS_n : std_logic_vector(0 downto 0):= "0";
  signal ila_test_MOSI : std_logic_vector(0 downto 0):= "0";
  signal ila_test_SPI_CLK : std_logic_vector(0 downto 0):= "0";
  signal ila_test_tx_dv : std_logic_vector(0 downto 0):= "0";
  signal ila_test_rx_dv : std_logic_vector(0 downto 0):= "0";
  signal ila_test_clk_100 : std_logic_vector(0 downto 0):= "0";


  -- values for SPI interface--
  -- CPOL = 1 and CPHA = 1, based on ISM330DLC
  constant SPI_MODE : integer := 3;
   
  -- FPGA operates at 100 MHz, so divide by 50 to get to 2 MHz.
  -- This is clocks per half bit, so divide 50 by 2 to get 25.
  constant CLKS_PER_HALF_BIT_2MHZ : integer := 200;

  -- FPGA operates at 100 MHz, so divide by 100 to get to 1 MHz.
  -- This is clocks per half bit, so divide 100 by 2 to get 50.
  constant CLKS_PER_HALF_BIT_1MHZ : integer := 400;--400
  constant CLKS_PER_HALF_BIT_10MHZ : integer := 40;

  -- Number of clock cycles to leave CS high after transaction is done
  constant CS_INACTIVE_CLKS : integer := 100; --todo: not sure
  
  --max number of bytes per cs 
  constant MAX_BYTES_PER_CS : integer := 13; -- 6 times 2 bytes plus 1 bytes for address
  
 
  --read/write bit 
  constant SPI_READ_BIT     :  std_logic_vector(7 downto 0):= "10000000"; --80h
  constant SPI_WRITE_BIT    :  std_logic_vector(7 downto 0):= "00000000"; --00h

  --initilization adresses of the sensor
  constant CTRL9_XL     :  std_logic_vector(7 downto 0):= "00011000"; --18h
  constant CTRL1_XL     :  std_logic_vector(7 downto 0):= "00010000"; --10h
  constant CTRL2_G      :  std_logic_vector(7 downto 0):= "00010001"; --11h
  constant CTRL4_C      :  std_logic_vector(7 downto 0):= "00010011"; --13h
  constant CTRL3_C      :  std_logic_vector(7 downto 0):= "00010010"; --12h
  constant WHO_AM_I     :  std_logic_vector(7 downto 0):= "00001111"; --0Fh
  --initilization values for the sensor
  constant CTRL9_DEFAULT    :  std_logic_vector(7 downto 0):= "11100000"; --E0h
  constant DEVICE_CONF_ENA  :  std_logic_vector(7 downto 0):= "00000010"; --02h
  constant ODR_XL_52        :  std_logic_vector(7 downto 0):= "00110000"; --30h
  constant FS_XL_4G         :  std_logic_vector(7 downto 0):= "00001000"; --08h
  constant ODR_G_52         :  std_logic_vector(7 downto 0):= "00110000"; --30h
  constant FS_G_2000DPS     :  std_logic_vector(7 downto 0):= "00001100"; --0Ch
  constant I2C_disable      :  std_logic_vector(7 downto 0):= "00000100"; --04h
  constant F_INC            :  std_logic_vector(7 downto 0):= "00000100"; --04h no need cause default value is 1
  constant WHO_AM_I_VALUE   :  std_logic_vector(7 downto 0):= "01101010"; --6Ah
  --address to read sensor values
  constant OUTX_L_G     :  std_logic_vector(7 downto 0):= "00100010"; --22h

  component SPI_Master_With_Single_CS is
  generic (
    SPI_MODE          : integer := SPI_MODE;
    CLKS_PER_HALF_BIT : integer := CLKS_PER_HALF_BIT_1MHZ;
    MAX_BYTES_PER_CS  : integer := MAX_BYTES_PER_CS;
    CS_INACTIVE_CLKS  : integer := CS_INACTIVE_CLKS 
    );
  port (
   -- Control/Data Signals,
   i_Rst_L : in std_logic;     -- FPGA Reset
   i_Clk   : in std_logic;     -- FPGA Clock
   
   -- TX (MOSI) Signals
   i_TX_Count : in  std_logic_vector;  -- # bytes per CS low
   i_TX_Byte  : in  std_logic_vector(7 downto 0);  -- Byte to transmit on MOSI
   i_TX_DV    : in  std_logic;     -- Data Valid Pulse with i_TX_Byte
   o_TX_Ready : out std_logic;     -- Transmit Ready for next byte
   
   -- RX (MISO) Signals
   o_RX_Count : out std_logic_vector(3 downto 0);  -- Index RX byte
   o_RX_DV    : out std_logic;  -- Data Valid pulse (1 clock cycle)
   o_RX_Byte  : out std_logic_vector(7 downto 0);   -- Byte received on MISO

   -- SPI Interface
   o_SPI_Clk  : out std_logic;
   i_SPI_MISO : in  std_logic;
   o_SPI_MOSI : out std_logic;
   o_SPI_CS_n : out std_logic
   );
  end component;
  
  component UART_RX is
  Generic (
    g_CLKS_PER_BIT : integer := 115     -- Needs to be set correctly
    );
  Port (
    i_Clk       : in  std_logic;
    i_RX_Serial : in  std_logic;
    o_RX_DV     : out std_logic;
    o_RX_Byte   : out std_logic_vector(7 downto 0)
    );
  end component;
  
    component ila_0 IS
    PORT (
    clk : IN STD_LOGIC;


    probe0 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe1 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe2 : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    probe3 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe5 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe6 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe7 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe8 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe9 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
    
    );
    END component;

  component UART_TRANSMITTER is
  Generic (
    g_CLKS_PER_BIT : integer := 115     -- Needs to be set correctly
    );
  Port (
    i_Clk       : in  std_logic;
    --i_rst_n     : in  std_logic;
    i_TX_DV     : in  std_logic;
    i_TX_Byte   : in  std_logic_vector(7 downto 0);
    --o_TX_Active : out std_logic;
    o_TX_Serial : out std_logic;
    o_TX_Done   : out std_logic
    );
  end component;
  
  constant serial_CLKS_PER_BIT : integer := 868;   -- 100.000.000 / 115200 = 868,055
  
  signal clk_12mhz     : std_logic;
  
  signal clk_100       : std_logic;
  signal clk_100_buf   : std_logic;
  signal clk_100_out   : std_logic;

  signal clk_fb        : std_logic;
  
  signal rst_n         : std_logic := '1'; -- no external reset
  signal rst           : std_logic := '0';
  
  
  signal ser_tx_dv     : std_logic := '0';
  signal ser_rx_dv     : std_logic := '0';
  signal ser_tx_byte   : std_logic_vector(7 downto 0) := (others => '0');
  signal ser_rx_byte   : std_logic_vector(7 downto 0) := (others => '0');
  signal ser_tx_pin    : std_logic := '0';
  signal ser_rx_pin    : std_logic := '0';
  signal ser_tx_act    : std_logic := '0';
  signal ser_tx_done   : std_logic := '0';
  
  signal number     : unsigned(3 downto 0) := "0000";
   
  signal change_spi_speed : std_logic := '0'; 
  signal change_spi_speed_done : std_logic := '0';
  
  signal spi_four_bit_count : std_logic_vector(3 downto 0):= "0000";

  --SPI states
  type spi_state_type is (spi_reset, 
                          spi_init,
                          spi_init_a_addr,
                          spi_init_a_addr_end,
                          spi_init_a_value,
                          spi_init_a_end,
                          
                          spi_init_b_addr,
                          spi_init_b_addr_end,
                          spi_init_b_value,
                          spi_init_b_end,
                          
                          spi_init_c_addr,
                          spi_init_c_addr_end,
                          spi_init_c_value,
                          spi_init_c_end,
                          
                          spi_init_d_addr,
                          spi_init_d_addr_end,
                          spi_init_d_value,
                          spi_init_d_end,
                          
                          spi_init_e_addr,
                          spi_init_e_addr_end,
                          spi_init_e_value,
                          spi_init_e_end,
                     
                          spi_init_done, 
                          spi_send_addr, 
                          spi_send_addr_end, 
                          spi_send_bulk, -- to set cs active while reading sensor data
                          spi_send_bulk_end, -- to set cs active while reading sensor data

                          spi_read);

  type spi_read_status is (read_init,
                           read_done);
  type send_serial_type is (  send_serial_data_valid,
                              send_serial_gyro_x_1,
                              send_serial_gyro_x_2,
                              send_serial_gyro_y_1,
                              send_serial_gyro_y_2,
                              send_serial_gyro_z_1,
                              send_serial_gyro_z_2,
                              send_serial_accel_x_1,
                              send_serial_accel_x_2,
                              send_serial_accel_y_1,
                              send_serial_accel_y_2,
                              send_serial_accel_z_1,
                              send_serial_accel_z_2,
                              send_serial_gyro_x_1_end,
                              send_serial_gyro_x_2_end,
                              send_serial_gyro_y_1_end,
                              send_serial_gyro_y_2_end,
                              send_serial_gyro_z_1_end,
                              send_serial_gyro_z_2_end,
                              send_serial_accel_x_1_end,
                              send_serial_accel_x_2_end,
                              send_serial_accel_y_1_end,
                              send_serial_accel_y_2_end,
                              send_serial_accel_z_1_end,
                              send_serial_accel_z_2_end,
                              send_serial_wait  );               
  --signals for SPI
  signal state_spi : spi_state_type := spi_init;
  signal state_spi_read : spi_read_status := read_init;
  signal state_serial_send : send_serial_type := send_serial_wait;

  signal spi_tx_count : std_logic_vector(3 downto 0):= "0010";  -- # bytes per CS low
  signal spi_tx_byte  : std_logic_vector(7 downto 0) := (others => '0');
  signal w_Master_RX_Count : std_logic_vector(3 downto 0);--todo:Cansu 3 yap
  signal w_Master_RX_DV    : std_logic;
  signal w_Master_RX_Byte  : std_logic_vector(7 downto 0):= "00000000";
  signal w_Master_TX_Ready : std_logic;
  signal r_Master_TX_DV    : std_logic;
  
  --in/out SPI signals
  signal sig_o_SPI_Clk   : std_logic := '1';
  signal sig_i_SPI_MISO  : std_logic := '1';
  signal sig_o_SPI_MOSI  : std_logic := '1';
  signal sig_o_SPI_CS_n  : std_logic := '1';
      
  signal gyro_x         : std_logic_vector(15 downto 0) := (others => '0');
  signal gyro_y         : std_logic_vector(15 downto 0) := (others => '0');
  signal gyro_z         : std_logic_vector(15 downto 0) := (others => '0');
  signal accel_x        : std_logic_vector(15 downto 0) := (others => '0');
  signal accel_y        : std_logic_vector(15 downto 0) := (others => '0');
  signal accel_z        : std_logic_vector(15 downto 0) := (others => '0');

  signal ser_gyro_x    : std_logic_vector(15 downto 0) := (others => '0');
  signal ser_gyro_y    : std_logic_vector(15 downto 0) := (others => '0');
  signal ser_gyro_z    : std_logic_vector(15 downto 0) := (others => '0');
  signal ser_accel_x   : std_logic_vector(15 downto 0) := (others => '0');
  signal ser_accel_y   : std_logic_vector(15 downto 0) := (others => '0');
  signal ser_accel_z   : std_logic_vector(15 downto 0) := (others => '0');
  
    signal wait_state: wait_state_type := wait_for_it;

    -- Sends a single byte from master. 
  procedure StartSendSingleByte (
    data          : in  std_logic_vector(7 downto 0);
    signal o_data : out std_logic_vector(7 downto 0);
    signal o_dv   : out std_logic
) is
  begin
        o_data <= data;
        o_dv <= '1';
  end procedure StartSendSingleByte;

begin

  --IBUFG: Single-ended Global Clock Input Buffer, 7Series, Xilinx HDL Libraries Guide, version 14.7
  IBUFG_clk: IBUFG
  generic map (
    IBUF_LOW_PWR=>TRUE,
    IOSTANDARD=>"DEFAULT")
  port map (
    O => clk_12mhz,
    I => sysclk
  );
  
  --MMCME2_BASE: Base Mixed Mode Clock Manager, 7Series, Xilinx HDL Libraries Guide, version 14.7
  -- configured for sysclk = 12 MHz (CMOD A7), a 100 MHz internal clock and a 1 MHz internal clock
  MMCME2_BASE_inst: MMCME2_BASE
  generic map(
    BANDWIDTH=>"OPTIMIZED",    --Jitterprogramming(OPTIMIZED,HIGH,LOW)
    CLKFBOUT_MULT_F    => 50.0,--MultiplyvalueforallCLKOUT(2.000-64.000).
    CLKFBOUT_PHASE     => 0.0, --PhaseoffsetindegreesofCLKFB(-360.000-360.000).
    CLKIN1_PERIOD      => 83.333,--Inputclockperiodinnstopsresolution(i.e.33.333is30MHz).
    --CLKOUT0_DIVIDE-CLKOUT6_DIVIDE:DivideamountforeachCLKOUT(1-128)
    CLKOUT1_DIVIDE     => 6,
    CLKOUT2_DIVIDE     => 6,
    CLKOUT3_DIVIDE     => 6,
    CLKOUT4_DIVIDE     => 6,
    CLKOUT5_DIVIDE     => 6,
    CLKOUT6_DIVIDE     => 6,
    CLKOUT0_DIVIDE_F   => 6.0,  --DivideamountforCLKOUT0(1.000-128.000).
    --CLKOUT0_DUTY_CYCLE-CLKOUT6_DUTY_CYCLE:DutycycleforeachCLKOUT(0.01-0.99).
    CLKOUT0_DUTY_CYCLE => 0.5,
    CLKOUT1_DUTY_CYCLE => 0.5,
    CLKOUT2_DUTY_CYCLE => 0.5,
    CLKOUT3_DUTY_CYCLE => 0.5,
    CLKOUT4_DUTY_CYCLE => 0.5,
    CLKOUT5_DUTY_CYCLE => 0.5,
    CLKOUT6_DUTY_CYCLE => 0.5,
    --CLKOUT0_PHASE-CLKOUT6_PHASE:PhaseoffsetforeachCLKOUT(-360.000-360.000).
    CLKOUT0_PHASE     => 0.0,
    CLKOUT1_PHASE     => 0.0,
    CLKOUT2_PHASE     => 0.0,
    CLKOUT3_PHASE     => 0.0,
    CLKOUT4_PHASE     => 0.0,
    CLKOUT5_PHASE     => 0.0,
    CLKOUT6_PHASE     => 0.0,
    CLKOUT4_CASCADE   => TRUE, --CascadeCLKOUT4counterwithCLKOUT6(FALSE,TRUE)
    DIVCLK_DIVIDE     => 1,     --Masterdivisionvalue(1-106)
    REF_JITTER1       => 0.0,   --ReferenceinputjitterinUI(0.000-0.999).
    STARTUP_WAIT      => FALSE  --DelaysDONEuntilMMCMislocked(FALSE,TRUE)
  )
  port map(
    --ClockOutputs:1-bit(each)output:Userconfigurableclockoutputs
    CLKOUT0           => clk_100_buf, --1-bitoutput:CLKOUT0
    CLKOUT0B          => open,  --1-bitoutput:Inverted CLKOUT0
    CLKOUT1           => open,  --1-bitoutput:CLKOUT1
    CLKOUT1B          => open,  --1-bitoutput: Inverted CLKOUT1
    CLKOUT2           => open,  --1-bitoutput: CLKOUT2
    CLKOUT2B          => open,  --1-bitoutput: Inverted CLKOUT2
    CLKOUT3           => open,  --1-bitoutput: CLKOUT3
    CLKOUT3B          => open,  --1-bitoutput: Inverted CLKOUT3
    CLKOUT4           => open, --1-bitoutput: CLKOUT4
    CLKOUT5           => open,  --1-bitoutput: CLKOUT5
    CLKOUT6           => open,  --1-bitoutput: CLKOUT6
    --FeedbackClocks:1-bit(each)output:Clockfeedbackports
    CLKFBOUT          => clk_fb,--1-bitoutput: Feedbackclock
    CLKFBOUTB         => open,  --1-bitoutput: InvertedCLKFBOUT
    --StatusPorts:1-bit(each)output:MMCMstatusports
    LOCKED            => open,  --1-bitoutput: LOCK
    --ClockInputs:1-bit(each)input:Clockinput
    CLKIN1            => clk_12mhz, --1-bitinput: Clock
    --ControlPorts:1-bit(each)input:MMCMcontrolports
    PWRDWN            => '0',   --1-bitinput: Power-down
    RST               => '0',   --1-bitinput: Reset
    --FeedbackClocks:1-bit(each)input:Clockfeedbackports
    CLKFBIN           => clk_fb --1-bitinput: eedbackclock
  );
  
  
  BUFG_clk100: BUFG
  port map(
    O => clk_100,
    I => clk_100_buf
  );
  
  
  Serial_RX: UART_RX
  Generic map(
    g_CLKS_PER_BIT => serial_CLKS_PER_BIT									-- ************** Needs to be set correctly !!!!! ************     					
    )
  Port map(
    i_Clk       => clk_100,
    i_RX_Serial => ser_rx_pin,
    o_RX_DV     => ser_rx_dv,
    o_RX_Byte   => ser_rx_byte
    );

	ILA :ila_0 
    PORT map(
    clk => clk_100,

    probe0 => w_Master_RX_Byte,
    probe1 => ser_tx_byte,
    probe2 => spi_tx_byte,
    probe3 => ila_test_SPI_CLK,
    probe4 => ila_test_CS_n,
    probe5 => ila_test_MOSI, 
    probe6 => ila_test_MISO, 
    probe7 => ila_test_tx_dv,
    probe8 => ila_test_rx_dv,
    probe9 => ila_test_clk_100
    );
    
  Serial_TX: UART_TRANSMITTER
  Generic map(
    g_CLKS_PER_BIT => serial_CLKS_PER_BIT  								-- ************** Needs to be set correctly !!!!! ************   
    )
  Port map(
    i_Clk       => clk_100,
    --i_rst_n     => rst_n,
    i_TX_DV     => ser_tx_dv,
    i_TX_Byte   => ser_tx_byte,
    --o_TX_Active => ser_tx_act,
    o_TX_Serial => ser_tx_pin,
    o_TX_Done   => ser_tx_done
    );
  
  SPI_Master: SPI_Master_With_Single_CS
  Generic map (
      SPI_MODE          => SPI_MODE,
      CLKS_PER_HALF_BIT => CLKS_PER_HALF_BIT_1MHZ,
      MAX_BYTES_PER_CS  => MAX_BYTES_PER_CS,           -- max 13 bytes per CS
      CS_INACTIVE_CLKS  => CS_INACTIVE_CLKS)
  port map (
      i_Rst_L    => rst_n,                  -- FPGA Reset (push button)
      i_Clk      => clk_100,                -- FPGA Clock
      -- TX (MOSI Signals)
      i_TX_Count => spi_TX_Count,           -- Always 1 bytes transmit for address per CS, changes if sets registers
      i_TX_Byte  => spi_tx_byte,            -- Can stuff with zeros
      i_TX_DV    => r_Master_TX_DV,         -- Data valid pulse with i_TX_Byte
      o_TX_Ready => w_Master_TX_Ready,      -- Transmit ready for byte
      -- RX (MISO) Signals
      o_RX_Count => w_Master_RX_Count,      -- Index of RX'd byte
      o_RX_DV    => w_Master_RX_DV,         -- Data valid pulse (1 clock cycle)
      o_RX_Byte  => w_Master_RX_Byte,       -- Byte received on MISO
      -- SPI Interface
      o_SPI_Clk  => sig_o_SPI_Clk,
      i_SPI_MISO => i_SPI_MISO,
      o_SPI_MOSI => sig_o_SPI_MOSI,
      o_SPI_CS_n => sig_o_SPI_CS_n
      );
--  wait_for_init_sensor: process is
--  begin
--   if(wait_state /= wait_done) then
--       --wait for 5000 ms; --close for test
--       wait_state <= wait_done;
--   end if;
--  end process;
  
  init_sensor: process(clk_100, rst_n, flag_1Hz, wait_state)
  begin
  
    if rst_n = '0' then
        state_spi <= spi_reset;
        r_Master_TX_DV <= '0';
        spi_tx_count <= "0010"; --for init process sending address + value
        spi_four_bit_count <= "0000";
    elsif rising_edge(clk_100) then 
    if (wait_state =   wait_for_it) then
        case state_spi is
            when spi_reset =>
                spi_tx_count <= "0010";
                state_spi <= spi_init_a_addr;

            when spi_init_a_addr =>
                if(w_Master_TX_Ready = '1') then
                    StartSendSingleByte(SPI_WRITE_BIT or CTRL9_XL,spi_tx_byte, r_Master_TX_DV);                  
                    state_spi <= spi_init_a_addr_end;
                 end if;
                 
             when spi_init_a_addr_end =>
                    r_Master_TX_DV <= '0';
                    state_spi <= spi_init_a_value;
                    
             when spi_init_a_value =>
                 if(w_Master_TX_Ready = '1') then
                    StartSendSingleByte(CTRL9_DEFAULT xor DEVICE_CONF_ENA, spi_tx_byte, r_Master_TX_DV);            
                    state_spi <= spi_init_a_end;
                 end if;
                 
             when spi_init_a_end =>
                    r_Master_TX_DV <= '0';
                    state_spi <= spi_init_b_addr;
                    
            when spi_init_b_addr =>
                if(w_Master_TX_Ready = '1') then
                    StartSendSingleByte(SPI_WRITE_BIT or CTRL1_XL ,spi_tx_byte, r_Master_TX_DV);                  
                    state_spi <= spi_init_b_addr_end;
                 end if;
                 
             when spi_init_b_addr_end =>
                    r_Master_TX_DV <= '0';
                    state_spi <= spi_init_b_value;
                    
             when spi_init_b_value =>
                 if(w_Master_TX_Ready = '1') then
                    StartSendSingleByte(ODR_XL_52 xor FS_XL_4G, spi_tx_byte, r_Master_TX_DV);            
                    state_spi <= spi_init_b_end;
                 end if;
                 
             when spi_init_b_end =>
                    r_Master_TX_DV <= '0';
                    state_spi <= spi_init_c_addr;
                    
             when spi_init_c_addr =>
                if(w_Master_TX_Ready = '1') then
                    StartSendSingleByte(SPI_WRITE_BIT or CTRL2_G,spi_tx_byte, r_Master_TX_DV);                  
                    state_spi <= spi_init_c_addr_end;
                 end if;
                 
             when spi_init_c_addr_end =>
                    r_Master_TX_DV <= '0';
                    state_spi <= spi_init_c_value;
                    
             when spi_init_c_value =>
                 if(w_Master_TX_Ready = '1') then
                    StartSendSingleByte(ODR_G_52 xor FS_G_2000DPS, spi_tx_byte, r_Master_TX_DV);            
                    state_spi <= spi_init_c_end;
                 end if;
                 
             when spi_init_c_end =>
                    r_Master_TX_DV <= '0';
                    state_spi <= spi_init_d_addr;
                    
             when spi_init_d_addr =>
                if(w_Master_TX_Ready = '1') then
                    StartSendSingleByte(SPI_WRITE_BIT or CTRL4_C, spi_tx_byte, r_Master_TX_DV);                  
                    state_spi <= spi_init_d_addr_end;
                 end if;
                 
             when spi_init_d_addr_end =>
                    r_Master_TX_DV <= '0';
                    state_spi <= spi_init_d_value;
                    
             when spi_init_d_value =>
                 if(w_Master_TX_Ready = '1') then
                    StartSendSingleByte(I2C_disable, spi_tx_byte, r_Master_TX_DV);            
                    state_spi <= spi_init_d_end;
                 end if;
                 
             when spi_init_d_end =>
                    r_Master_TX_DV <= '0';
                    state_spi <= spi_init_e_addr;
                    
             when spi_init_e_addr =>
                if(w_Master_TX_Ready = '1') then
                    StartSendSingleByte(SPI_WRITE_BIT or CTRL9_XL, spi_tx_byte, r_Master_TX_DV);                  
                    state_spi <= spi_init_e_addr_end;
                 end if;
                 
             when spi_init_e_addr_end =>
                    r_Master_TX_DV <= '0';
                    state_spi <= spi_init_e_value;
                    
             when spi_init_e_value =>
                 if(w_Master_TX_Ready = '1') then
                    StartSendSingleByte(CTRL9_DEFAULT, spi_tx_byte, r_Master_TX_DV);            
                    state_spi <= spi_init_e_end;
                 end if;
                 
             when spi_init_e_end =>
                    r_Master_TX_DV <= '0';
                    state_spi <= spi_init_done;
                    
             when spi_init_done => 
                    spi_tx_count <= "1101"; --only to send register reading address
                    state_spi <= spi_send_addr;
                   
            when spi_send_addr =>
                 if(w_Master_TX_Ready = '1') then
                    StartSendSingleByte(SPI_READ_BIT or OUTX_L_G , spi_tx_byte, r_Master_TX_DV);    
                    --StartSendSingleByte(SPI_READ_BIT or WHO_AM_I , spi_tx_byte, r_Master_TX_DV);   
        
                    state_spi <= spi_send_addr_end;
                 end if; 
                 
            when spi_send_addr_end =>
                    r_Master_TX_DV <= '0';
                    spi_tx_count <= "1101";
                    state_spi <= spi_send_bulk;
                    
            when spi_send_bulk =>
                 if(w_Master_TX_Ready = '1') then
                    StartSendSingleByte((SPI_READ_BIT or OUTX_L_G) + 1+ spi_four_bit_count , spi_tx_byte, r_Master_TX_DV);  
                    --StartSendSingleByte(SPI_READ_BIT or WHO_AM_I , spi_tx_byte, r_Master_TX_DV);        
                   
                    state_spi <= spi_send_bulk_end;
                 end if; 
                    
             when spi_send_bulk_end =>
                    r_Master_TX_DV <= '0';
                    if( spi_four_bit_count = "1011") then    
                        if (state_spi_read = read_done) then                         
                            state_spi <= spi_send_addr;
                            spi_four_bit_count <= "0000";
                        end if;
                    else 
                        spi_four_bit_count <= spi_four_bit_count + 1;
                        state_spi <= spi_send_bulk;
                    end if;

            when others => 
                state_spi <= spi_reset;
        end case;
        end if;
    end if;
  end process;
  
  
--    Purpose: Handle data being countinuos read back from SPI
--    Pack up response in 8-bit and convert into 16-bit values for gyro and accel x,y,z.
  
  read_sensor_data: process(clk_100, rst_n)
  begin
    if rst_n = '0' then
        state_spi_read <= read_init;
    elsif rising_edge(clk_100) then 
      if w_Master_RX_DV = '1' then
       case w_Master_RX_Count is
            when "0000" =>
                state_spi_read <= read_init;
                gyro_x(7 downto 0)  <= w_Master_RX_Byte;
                --state_spi_read <= read_done;

            when "0001" =>
                gyro_x(15 downto 8) <= w_Master_RX_Byte;
            when "0010" =>
                gyro_y(7 downto 0)  <= w_Master_RX_Byte;
            when "0011" =>
                gyro_y(15 downto 8) <= w_Master_RX_Byte;
            when "0100" =>
                gyro_z(7 downto 0)  <= w_Master_RX_Byte;
            when "0101" =>
                gyro_z(15 downto 8) <= w_Master_RX_Byte;
            when "0110" =>
                accel_x(7 downto 0)  <= w_Master_RX_Byte;
            when "0111" =>
                accel_x(15 downto 8) <= w_Master_RX_Byte;
            when "1000" =>
                accel_y(7 downto 0)  <= w_Master_RX_Byte;
            when "1001" =>
                accel_y(15 downto 8) <= w_Master_RX_Byte;
            when "1010" =>
                accel_z(7 downto 0)  <= w_Master_RX_Byte;
            when "1011" =>
                accel_z(15 downto 8) <= w_Master_RX_Byte;
                state_spi_read <= read_done;

            when others => 
                state_spi_read <= read_init;

        end case;

       end if;
    end if;
  end process;  
  
  send_serial: process(clk_100, rst_n)
  begin
    if rst_n = '0' then
      state_serial_send <= send_serial_wait; 
      ser_tx_dv <= '0'; 
      ser_tx_byte <= "00000000";
    elsif rising_edge(clk_100) then
      case state_serial_send is
        when send_serial_wait =>
            if (state_spi_read = read_done) then
             ser_gyro_x <= gyro_x;
             ser_gyro_y <= gyro_y;
             ser_gyro_z <= gyro_z;
             ser_accel_x <= accel_x;
             ser_accel_y <= accel_y;
             ser_accel_z <= accel_z;
             state_serial_send <= send_serial_gyro_x_1;
            end if;
            
       when send_serial_gyro_x_1 =>
         ser_tx_byte <= ser_gyro_x(15 downto 8);
         ser_tx_dv <= '1'; 
         state_serial_send <= send_serial_gyro_x_1_end;
        
        when send_serial_gyro_x_1_end =>                               
         ser_tx_dv <= '0';
         if ser_tx_done = '1' then
           state_serial_send <= send_serial_gyro_x_2;                  
         end if;
         
        when send_serial_gyro_x_2 =>
         ser_tx_byte <= ser_gyro_x(7 downto 0);
         ser_tx_dv <= '1'; 
         state_serial_send <= send_serial_gyro_x_2_end;
        
        when send_serial_gyro_x_2_end =>                               
         ser_tx_dv <= '0';
         if ser_tx_done = '1' then
           state_serial_send <= send_serial_gyro_y_1;                  
         end if;
        
        when send_serial_gyro_y_1 =>
         ser_tx_byte <= ser_gyro_y(15 downto 8);
         ser_tx_dv <= '1'; 
         state_serial_send <= send_serial_gyro_y_1_end;
        
        when send_serial_gyro_y_1_end =>                               
         ser_tx_dv <= '0';
         if ser_tx_done = '1' then
           state_serial_send <= send_serial_gyro_y_2;                  
         end if;
         
        when send_serial_gyro_y_2 =>
         ser_tx_byte <= ser_gyro_y(7 downto 0);
         ser_tx_dv <= '1'; 
         state_serial_send <= send_serial_gyro_y_2_end;
        
        when send_serial_gyro_y_2_end =>                               
         ser_tx_dv <= '0';
         if ser_tx_done = '1' then
           state_serial_send <= send_serial_gyro_z_1;                  
         end if;
         
        when send_serial_gyro_z_1 =>
         ser_tx_byte <= ser_gyro_z(15 downto 8);
         ser_tx_dv <= '1'; 
         state_serial_send <= send_serial_gyro_z_1_end;
        
        when send_serial_gyro_z_1_end =>                               
         ser_tx_dv <= '0';
         if ser_tx_done = '1' then
           state_serial_send <= send_serial_gyro_z_2;                  
         end if;
         
         when send_serial_gyro_z_2 =>
         ser_tx_byte <= ser_gyro_z(7 downto 0);
         ser_tx_dv <= '1'; 
         state_serial_send <= send_serial_gyro_z_2_end;
        
        when send_serial_gyro_z_2_end =>                               
         ser_tx_dv <= '0';
         if ser_tx_done = '1' then
           state_serial_send <= send_serial_accel_x_1;                  
         end if;

        when send_serial_accel_x_1 =>
         ser_tx_byte <= ser_accel_x(15 downto 8);
         ser_tx_dv <= '1'; 
         state_serial_send <= send_serial_accel_x_1_end;
        
        when send_serial_accel_x_1_end =>                               
         ser_tx_dv <= '0';
         if ser_tx_done = '1' then
           state_serial_send <= send_serial_accel_x_2;                  
         end if;
         
        when send_serial_accel_x_2 =>
         ser_tx_byte <= ser_accel_x(7 downto 0);
         ser_tx_dv <= '1'; 
         state_serial_send <= send_serial_accel_x_2_end;
        
        when send_serial_accel_x_2_end =>                               
         ser_tx_dv <= '0';
         if ser_tx_done = '1' then
           state_serial_send <= send_serial_accel_y_1;                  
         end if;
        
        when send_serial_accel_y_1 =>
         ser_tx_byte <= ser_accel_y(15 downto 8);
         ser_tx_dv <= '1'; 
         state_serial_send <= send_serial_accel_y_1_end;
        
        when send_serial_accel_y_1_end =>                               
         ser_tx_dv <= '0';
         if ser_tx_done = '1' then
           state_serial_send <= send_serial_accel_y_2;                  
         end if;
         
        when send_serial_accel_y_2 =>
         ser_tx_byte <= ser_accel_y(7 downto 0);
         ser_tx_dv <= '1'; 
         state_serial_send <= send_serial_accel_y_2_end;
        
        when send_serial_accel_y_2_end =>                               
         ser_tx_dv <= '0';
         if ser_tx_done = '1' then
           state_serial_send <= send_serial_accel_z_1;                  
         end if;
         
        when send_serial_accel_z_1 =>
         ser_tx_byte <= ser_accel_z(15 downto 8);
         ser_tx_dv <= '1'; 
         state_serial_send <= send_serial_accel_z_1_end;
        
        when send_serial_accel_z_1_end =>                               
         ser_tx_dv <= '0';
         if ser_tx_done = '1' then
           state_serial_send <= send_serial_accel_z_2;                  
         end if;
         
        when send_serial_accel_z_2 =>
         ser_tx_byte <= ser_accel_z(7 downto 0);
         ser_tx_dv <= '1'; 
         state_serial_send <= send_serial_accel_z_2_end;
        
        when send_serial_accel_z_2_end =>                               
         ser_tx_dv <= '0';
         if ser_tx_done = '1' then
           state_serial_send <= send_serial_wait;                  
         end if;
         
       when others => 
          state_serial_send <= send_serial_wait;
          
      end case;
    end if;
  end process;
  
speed_switching: process(clk_100, rst_n)
   variable CLKS_PER_HALF_BIT : integer := CLKS_PER_HALF_BIT_2MHZ; --TODO: not finished yet

  begin
    if rst_n = '0' then
        change_spi_speed <= '0';
    elsif rising_edge(clk_100) then 
        if((change_spi_speed = '1') and (change_spi_speed_done /= '1')) then
            if( CLKS_PER_HALF_BIT = CLKS_PER_HALF_BIT_1MHZ) then
                CLKS_PER_HALF_BIT := CLKS_PER_HALF_BIT_2MHZ;
                change_spi_speed_done <= '1';
            else
                CLKS_PER_HALF_BIT := CLKS_PER_HALF_BIT_1MHZ;
                change_spi_speed_done <= '1';
            end if;
            
        elsif change_spi_speed = '0' then
            change_spi_speed_done <= '0';
        end if;
        
    end if;
end process;
  
  count_1Hz: process(clk_100, rst_n)
  variable var_blink_count : BLINK := 0;

  begin
    if rst_n = '0' then
        var_blink_count := 0;   
        eight_bit_count <= "00000000"; 
        flag_1Hz <= '0';
    elsif rising_edge(clk_100) then 
        if(var_blink_count = 100000000) then
            flag_1Hz <= not flag_1Hz;
            var_blink_count := 0;
            eight_bit_count <= eight_bit_count + 1;        
        else
            var_blink_count := var_blink_count +1;
        end if;
    end if;
  end process;
  
--  send_count_eight: process(clk_100, rst_n, flag_1Hz)

--  begin
--    if rst_n = '0' then
--        count_eight_state <= send_ready_1; 
--    elsif rising_edge(clk_100) then 
--       case count_eight_state is 
--        when send_ready_1 =>
--           if(flag_1Hz = '1') then
--                ser_tx_byte <= eight_bit_count;
--                ser_tx_dv <= '1'; 
--                count_eight_state <= send_end_1;
--           end if;
           
--        when send_end_1 =>
--                ser_tx_dv <= '0';
--                if ser_tx_done = '1' then
--                    count_eight_state <= send_ready_2;                  
--                end if;
                
--        when send_ready_2 =>
--           if(flag_1Hz = '0') then
--                ser_tx_byte <= eight_bit_count;
--                ser_tx_dv <= '1'; 
--                count_eight_state <= send_end_2;
--           end if;
           
--        when send_end_2 =>
--                ser_tx_dv <= '0';
--                if ser_tx_done = '1' then
--                    count_eight_state <= send_ready_1;                  
--                end if;
                
--        when others =>
--            count_eight_state <= send_ready_1; 
--       end case;
--    end if;
--  end process;
  
  o_SPI_Clk         <= sig_o_SPI_Clk;
  --sig_i_SPI_MISO    <= i_SPI_MISO ;
  o_SPI_MOSI        <= sig_o_SPI_MOSI;
  o_SPI_CS_n        <= sig_o_SPI_CS_n;
  
  ila_test_MISO(0) <=  sig_i_SPI_MISO;
  ila_test_MOSI(0) <=  sig_o_SPI_MOSI;
  ila_test_CS_n(0) <=  sig_o_SPI_CS_n;
  ila_test_SPI_CLK(0) <=  sig_o_SPI_Clk;
  ila_test_rx_dv(0) <= w_Master_RX_DV;
  ila_test_tx_dv(0) <= r_Master_TX_DV;
  ila_test_clk_100(0) <= clk_100;
  o_ser_tx <= ser_tx_pin;
  ser_rx_pin <= i_ser_rx;
  
  rst_n <= not btn0;
  rst <= btn0;
  led0 <= flag_1Hz;
  led1 <= btn1;
  change_spi_speed <= btn1;      

end rtl;