set_property SRC_FILE_INFO {cfile:C:/Users/cansuge/Documents/FPGA/SPI/SPI_Serial/SPI_Serial.srcs/constrs_1/imports/test_2.srcs/Cmod-A7-Master.xdc rfile:../../../SPI_Serial.srcs/constrs_1/imports/test_2.srcs/Cmod-A7-Master.xdc id:1} [current_design]
set_property src_info {type:XDC file:1 line:7 export:INPUT save:INPUT read:READ} [current_design]
set_property -dict {PACKAGE_PIN L17 IOSTANDARD LVCMOS33} [get_ports sysclk]
set_property src_info {type:XDC file:1 line:112 export:INPUT save:INPUT read:READ} [current_design]
set_property PACKAGE_PIN J3 [get_ports o_SPI_CS_n]
set_property src_info {type:XDC file:1 line:114 export:INPUT save:INPUT read:READ} [current_design]
set_property PACKAGE_PIN L1 [get_ports o_SPI_Clk]
set_property src_info {type:XDC file:1 line:115 export:INPUT save:INPUT read:READ} [current_design]
set_property PACKAGE_PIN K2 [get_ports o_SPI_MOSI]
set_property src_info {type:XDC file:1 line:119 export:INPUT save:INPUT read:READ} [current_design]
set_property PACKAGE_PIN N2 [get_ports o_ser_tx]
set_property src_info {type:XDC file:1 line:120 export:INPUT save:INPUT read:READ} [current_design]
set_property PACKAGE_PIN P1 [get_ports i_ser_rx]
set_property src_info {type:XDC file:1 line:124 export:INPUT save:INPUT read:READ} [current_design]
set_property PACKAGE_PIN A17 [get_ports led0]
set_property src_info {type:XDC file:1 line:126 export:INPUT save:INPUT read:READ} [current_design]
set_property PACKAGE_PIN C16 [get_ports led1]
set_property src_info {type:XDC file:1 line:128 export:INPUT save:INPUT read:READ} [current_design]
set_property PACKAGE_PIN B18 [get_ports btn1]
set_property src_info {type:XDC file:1 line:130 export:INPUT save:INPUT read:READ} [current_design]
set_property PACKAGE_PIN A18 [get_ports btn0]
set_property src_info {type:XDC file:1 line:135 export:INPUT save:INPUT read:READ} [current_design]
set_property PACKAGE_PIN J1 [get_ports i_SPI_MISO]
set_property src_info {type:XDC file:1 line:136 export:INPUT save:INPUT read:READ} [current_design]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property src_info {type:XDC file:1 line:137 export:INPUT save:INPUT read:READ} [current_design]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property src_info {type:XDC file:1 line:138 export:INPUT save:INPUT read:READ} [current_design]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
set_property src_info {type:XDC file:1 line:139 export:INPUT save:INPUT read:READ} [current_design]
connect_debug_port dbg_hub/clk [get_nets ila_test_clk_100]
