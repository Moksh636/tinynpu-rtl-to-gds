IVERILOG ?= iverilog
VVP       ?= vvp
VERILATOR ?= verilator
YOSYS     ?= yosys
PYTHON    ?= python3
SVFLAGS   ?= -g2012

RTL_SRCS := rtl/mac_unit.sv rtl/tinynpu_core.sv

.PHONY: mac core model test lint synth-check check clean

mac: sim/mac_unit_tb.vvp
	$(VVP) sim/mac_unit_tb.vvp

core: sim/tinynpu_core_tb.vvp
	$(VVP) sim/tinynpu_core_tb.vvp

model:
	$(PYTHON) -m pytest -q model

test: mac core model

lint:
	$(VERILATOR) \
		--lint-only \
		-Wall \
		--top-module tinynpu_core \
		$(RTL_SRCS)

synth-check:
	$(YOSYS) -q -p 'read_verilog -sv $(RTL_SRCS); hierarchy -check -top tinynpu_core; proc; opt; check; stat'

check: test lint synth-check

sim/mac_unit_tb.vvp: rtl/mac_unit.sv tb/mac_unit_tb.sv
	mkdir -p sim waves
	$(IVERILOG) $(SVFLAGS) -o $@ rtl/mac_unit.sv tb/mac_unit_tb.sv

sim/tinynpu_core_tb.vvp: rtl/mac_unit.sv rtl/tinynpu_core.sv tb/tinynpu_core_tb.sv
	mkdir -p sim waves
	$(IVERILOG) $(SVFLAGS) -o $@ rtl/mac_unit.sv rtl/tinynpu_core.sv tb/tinynpu_core_tb.sv

clean:
	rm -rf sim waves .pytest_cache model/__pycache__
