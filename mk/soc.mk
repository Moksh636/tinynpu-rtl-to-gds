# TinyPC-NPU v0.4 interconnect and memory regression rules

SOC_RTL_SRCS := \
	rtl/mac_unit.sv \
	rtl/tinynpu_core.sv \
	rtl/tinynpu_apb.sv \
	rtl/tinypc_boot_rom.sv \
	rtl/tinypc_ram.sv \
	rtl/tinypc_interconnect.sv

.PHONY: soc soc-test lint-soc synth-soc clean-soc

soc: soc-test lint-soc synth-soc

# Extend the CI entrypoints already used by .github/workflows/ci.yml.
test: soc-test
lint: lint-soc
synth-check: synth-soc
clean: clean-soc

soc-test: | sim waves
	@echo "===== TINYPC INTERCONNECT TEST ====="
	$(IVERILOG) \
		-g2012 \
		-s tinypc_interconnect_tb \
		-o sim/tinypc_interconnect_tb.vvp \
		$(SOC_RTL_SRCS) \
		tb/tinypc_interconnect_tb.sv
	$(VVP) sim/tinypc_interconnect_tb.vvp
	@echo "===== TINYPC NPU BUS COMPUTE TEST ====="
	$(IVERILOG) \
		-g2012 \
		-s tinypc_npu_bus_tb \
		-o sim/tinypc_npu_bus_tb.vvp \
		$(SOC_RTL_SRCS) \
		tb/tinypc_npu_bus_tb.sv
	$(VVP) sim/tinypc_npu_bus_tb.vvp

lint-soc:
	@echo "===== VERILATOR SOC LINT ====="
	$(VERILATOR) \
		--lint-only \
		--Wall \
		--top-module tinypc_interconnect \
		$(SOC_RTL_SRCS)

synth-soc:
	@echo "===== YOSYS SOC SYNTHESIS CHECK ====="
	$(YOSYS) -q -p 'read_verilog -sv $(SOC_RTL_SRCS); hierarchy -check -top tinypc_interconnect; proc; opt; check; stat'

clean-soc:
	rm -f sim/tinypc_interconnect_tb.vvp
	rm -f sim/tinypc_npu_bus_tb.vvp
	rm -f waves/tinypc_interconnect.vcd
	rm -f waves/tinypc_npu_bus.vcd
