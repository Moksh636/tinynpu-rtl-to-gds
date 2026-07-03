IVERILOG = iverilog
VVP      = vvp
SVFLAGS  = -g2012

.PHONY: mac core clean

mac: sim/mac_unit_tb.vvp
	$(VVP) sim/mac_unit_tb.vvp

core: sim/tinynpu_core_tb.vvp
	$(VVP) sim/tinynpu_core_tb.vvp

sim/mac_unit_tb.vvp: rtl/mac_unit.sv tb/mac_unit_tb.sv
	mkdir -p sim waves
	$(IVERILOG) $(SVFLAGS) -o sim/mac_unit_tb.vvp rtl/mac_unit.sv tb/mac_unit_tb.sv

sim/tinynpu_core_tb.vvp: rtl/mac_unit.sv rtl/tinynpu_core.sv tb/tinynpu_core_tb.sv
	mkdir -p sim waves
	$(IVERILOG) $(SVFLAGS) -o sim/tinynpu_core_tb.vvp rtl/mac_unit.sv rtl/tinynpu_core.sv tb/tinynpu_core_tb.sv

clean:
	rm -rf sim waves
