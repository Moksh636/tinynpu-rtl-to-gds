IVERILOG ?= iverilog
VVP       ?= vvp
VERILATOR ?= verilator
YOSYS     ?= yosys
PYTHON    ?= python3
SVFLAGS   ?= -g2012

RANDOM_CASES ?= 25
RANDOM_SEED  ?= 20260711

RTL_SRCS := rtl/mac_unit.sv rtl/tinynpu_core.sv

.PHONY: mac core random model test lint synth-check check clean

mac: sim/mac_unit_tb.vvp
	$(VVP) sim/mac_unit_tb.vvp

core: sim/tinynpu_core_tb.vvp
	$(VVP) sim/tinynpu_core_tb.vvp

random: sim/random_vectors.txt sim/tinynpu_random_tb.vvp
	$(VVP) sim/tinynpu_random_tb.vvp

model:
	$(PYTHON) -m pytest -q model

test: mac core random model

lint:
	$(VERILATOR) \
		--lint-only \
		-Wall \
		--top-module tinynpu_core \
		$(RTL_SRCS)

synth-check:
	$(YOSYS) -q -p 'read_verilog -sv $(RTL_SRCS); hierarchy -check -top tinynpu_core; proc; opt; check; stat'

check: test lint synth-check

sim/random_vectors.txt: model/generate_vectors.py model/golden_model.py
	mkdir -p sim
	$(PYTHON) model/generate_vectors.py \
		--output $@ \
		--random-cases $(RANDOM_CASES) \
		--seed $(RANDOM_SEED)

sim/mac_unit_tb.vvp: rtl/mac_unit.sv tb/mac_unit_tb.sv
	mkdir -p sim waves
	$(IVERILOG) $(SVFLAGS) -o $@ rtl/mac_unit.sv tb/mac_unit_tb.sv

sim/tinynpu_core_tb.vvp: rtl/mac_unit.sv rtl/tinynpu_core.sv tb/tinynpu_core_tb.sv
	mkdir -p sim waves
	$(IVERILOG) $(SVFLAGS) -o $@ rtl/mac_unit.sv rtl/tinynpu_core.sv tb/tinynpu_core_tb.sv

sim/tinynpu_random_tb.vvp: rtl/mac_unit.sv rtl/tinynpu_core.sv tb/tinynpu_assertions.sv tb/tinynpu_coverage.sv tb/tinynpu_random_tb.sv
	mkdir -p sim waves
	$(IVERILOG) $(SVFLAGS) -o $@ \
		rtl/mac_unit.sv \
		rtl/tinynpu_core.sv \
		tb/tinynpu_assertions.sv \
		tb/tinynpu_coverage.sv \
		tb/tinynpu_random_tb.sv

clean:
	rm -rf sim waves .pytest_cache model/__pycache__

# TinyNPU APB/MMIO verification and synthesis rules
-include mk/apb.mk
