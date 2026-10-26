# Initial 200 MHz target, not a timing-closure claim.
create_clock -name core_clk -period 5.000 [get_ports clk]
# No I/O delays: this standalone core is synthesized for internal timing/resource estimates.
# Interface timing belongs to the later AXI or board-level integration.
