create_clock -name {clk} -period 20.833 -waveform {0.000 10.416} [get_ports {clk}]
create_clock -name {bclk} -period 333.333 -waveform {0.000 166.666} [get_ports {bclk}]

