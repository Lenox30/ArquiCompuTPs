##==============================================================================
## Archivo de Constraints para UART ALU Top
## Placa: Digilent Basys 3 (Artix-7 XC7A35T-1CPG236C)
## TP2 - Diseño de Arquitectura de Computadoras
##==============================================================================

##==============================================================================
## CLOCK - 100 MHz oscilador interno
##==============================================================================
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

##==============================================================================
## RESET - Switch 15 (extremo derecho)
##==============================================================================
set_property -dict { PACKAGE_PIN R2   IOSTANDARD LVCMOS33 } [get_ports reset]

##==============================================================================
## UART - USB Serial (conectado al CP2102 de la Basys 3)
##==============================================================================
# RX - Recepción desde PC
set_property -dict { PACKAGE_PIN B18  IOSTANDARD LVCMOS33 } [get_ports rx]

# TX - Transmisión hacia PC
set_property -dict { PACKAGE_PIN A18  IOSTANDARD LVCMOS33 } [get_ports tx]

##==============================================================================
## LEDs - Visualización de resultados y debug
##==============================================================================
# LED[0] - Bit 0 del resultado
set_property -dict { PACKAGE_PIN U16  IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
# LED[1] - Bit 1 del resultado
set_property -dict { PACKAGE_PIN E19  IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
# LED[2] - Bit 2 del resultado
set_property -dict { PACKAGE_PIN U19  IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
# LED[3] - Bit 3 del resultado
set_property -dict { PACKAGE_PIN V19  IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
# LED[4] - Bit 4 del resultado
set_property -dict { PACKAGE_PIN W18  IOSTANDARD LVCMOS33 } [get_ports {led[4]}]
# LED[5] - Bit 5 del resultado
set_property -dict { PACKAGE_PIN U15  IOSTANDARD LVCMOS33 } [get_ports {led[5]}]
# LED[6] - Bit 6 del resultado
set_property -dict { PACKAGE_PIN U14  IOSTANDARD LVCMOS33 } [get_ports {led[6]}]
# LED[7] - Bit 7 del resultado (MSB)
set_property -dict { PACKAGE_PIN V14  IOSTANDARD LVCMOS33 } [get_ports {led[7]}]

# LED[8] - Flag Zero
set_property -dict { PACKAGE_PIN V13  IOSTANDARD LVCMOS33 } [get_ports {led[8]}]
# LED[9] - Flag Overflow
set_property -dict { PACKAGE_PIN V3   IOSTANDARD LVCMOS33 } [get_ports {led[9]}]
# LED[10] - Flag Carry
set_property -dict { PACKAGE_PIN W3   IOSTANDARD LVCMOS33 } [get_ports {led[10]}]

# LED[11] - Estado RECV_A (debug)
set_property -dict { PACKAGE_PIN U3   IOSTANDARD LVCMOS33 } [get_ports {led[11]}]
# LED[12] - Estado RECV_B (debug)
set_property -dict { PACKAGE_PIN P3   IOSTANDARD LVCMOS33 } [get_ports {led[12]}]
# LED[13] - Estado RECV_OP (debug)
set_property -dict { PACKAGE_PIN N3   IOSTANDARD LVCMOS33 } [get_ports {led[13]}]

# LED[14] - RX done (debug)
set_property -dict { PACKAGE_PIN P1   IOSTANDARD LVCMOS33 } [get_ports {led[14]}]
# LED[15] - TX done (debug)
set_property -dict { PACKAGE_PIN L1   IOSTANDARD LVCMOS33 } [get_ports {led[15]}]

##==============================================================================
## CONFIGURACIÓN DE BITSTREAM
##==============================================================================
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]

##==============================================================================
## TIMING CONSTRAINTS ADICIONALES
##==============================================================================
# Relajar timing en el path del UART (no crítico)
set_false_path -from [get_pins {uart_rx_inst/rx_done_tick_reg/C}] -to [get_pins {state_reg_reg[*]/D}]
set_false_path -from [get_pins {uart_tx_inst/tx_done_tick_reg/C}] -to [get_pins {state_reg_reg[*]/D}]

# Timing del baud rate generator (no crítico)
set_false_path -from [get_pins {baud_gen/tick_reg/C}]