# TinyNPU APB3 regression rules
#
# This file extends the main Makefile without replacing the existing
# v0.2 simulation, Python-model, lint, or synthesis rules.

IVERILOG ?= iverilog
VVP       ?= vvp
VERILATOR ?= verilator
YOSYS     ?= yosys

SIM_DIR   ?= sim
WAVE_DIR  ?= waves

APB_RTL_SRCS := \
	rtl/mac_unit.sv \
	rtl/tinynpu_core.sv \
	rtl/tinynpu_apb.sv

APB_MONITOR_SRCS := \
	tb/tinynpu_apb_assertions.sv \
	tb/tinynpu_apb_coverage.sv

APB_SMOKE_SRCS := \
	$(APB_RTL_SRCS) \
	$(APB_MONITOR_SRCS) \
	tb/tinynpu_apb_smoke_tb.sv

APB_COMPUTE_SRCS := \
	$(APB_RTL_SRCS) \
	$(APB_MONITOR_SRCS) \
	tb/tinynpu_apb_compute_tb.sv

.PHONY: apb apb-check apb-smoke apb-compute
.PHONY: lint-apb synth-apb clean-apb

clean: clean-apb

# Running the project's normal check target now also runs the complete
# APB regression. Multiple Make rules for the same target accumulate
# prerequisites, so the original check recipe remains intact.
check: apb-check

apb: apb-smoke apb-compute

apb-check: apb-smoke apb-compute lint-apb synth-apb
	@echo
	@echo "TinyNPU APB regression passed."

$(SIM_DIR) $(WAVE_DIR):
	mkdir -p $@

apb-smoke: | $(SIM_DIR) $(WAVE_DIR)
	@echo "===== APB SMOKE TEST ====="
	$(IVERILOG) \
		-g2012 \
		-s tinynpu_apb_smoke_tb \
		-o $(SIM_DIR)/tinynpu_apb_smoke_tb.vvp \
		$(APB_SMOKE_SRCS)
	$(VVP) $(SIM_DIR)/tinynpu_apb_smoke_tb.vvp

apb-compute: | $(SIM_DIR) $(WAVE_DIR)
	@echo "===== APB COMPUTATION TEST ====="
	$(IVERILOG) \
		-g2012 \
		-s tinynpu_apb_compute_tb \
		-o $(SIM_DIR)/tinynpu_apb_compute_tb.vvp \
		$(APB_COMPUTE_SRCS)
	$(VVP) $(SIM_DIR)/tinynpu_apb_compute_tb.vvp

lint-apb:
	@echo "===== VERILATOR APB LINT ====="
	$(VERILATOR) \
		--lint-only \
		--Wall \
		-Wno-fatal \
		--top-module tinynpu_apb \
		$(APB_RTL_SRCS)

synth-apb:
	@echo "===== YOSYS APB SYNTHESIS CHECK ====="
	$(YOSYS) -q -p 'read_verilog -sv $(APB_RTL_SRCS); hierarchy -check -top tinynpu_apb; proc; opt; check; stat'

clean-apb:
	rm -f $(SIM_DIR)/tinynpu_apb_smoke_tb.vvp
	rm -f $(SIM_DIR)/tinynpu_apb_compute_tb.vvp
	rm -f $(WAVE_DIR)/tinynpu_apb_smoke.vcd
	rm -f $(WAVE_DIR)/tinynpu_apb_compute.vcd
