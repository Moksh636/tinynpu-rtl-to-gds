# TinyPC-NPU v0.5-A CPU primitive regression rules

CPU_FOUNDATION_RTL_SRCS := \
	rtl/tinypc_regfile.sv \
	rtl/tinypc_alu.sv \
	rtl/tinypc_imm_gen.sv \
	rtl/tinypc_decoder.sv

.PHONY: cpu-foundation cpu-foundation-test lint-cpu-foundation synth-cpu-foundation clean-cpu-foundation

cpu-foundation: cpu-foundation-test lint-cpu-foundation synth-cpu-foundation

# Extend the CI entrypoints already used by .github/workflows/ci.yml.
test: cpu-foundation-test
lint: lint-cpu-foundation
synth-check: synth-cpu-foundation
clean: clean-cpu-foundation

cpu-foundation-test:
	@mkdir -p sim waves
	@echo "===== TINYPC REGISTER FILE TEST ====="
	$(IVERILOG) $(SVFLAGS) -Irtl \
		-s tinypc_regfile_tb \
		-o sim/tinypc_regfile_tb.vvp \
		rtl/tinypc_regfile.sv \
		tb/tinypc_regfile_tb.sv
	$(VVP) sim/tinypc_regfile_tb.vvp
	@echo "===== TINYPC ALU TEST ====="
	$(IVERILOG) $(SVFLAGS) -Irtl \
		-s tinypc_alu_tb \
		-o sim/tinypc_alu_tb.vvp \
		rtl/tinypc_alu.sv \
		tb/tinypc_alu_tb.sv
	$(VVP) sim/tinypc_alu_tb.vvp
	@echo "===== TINYPC IMMEDIATE GENERATOR TEST ====="
	$(IVERILOG) $(SVFLAGS) -Irtl \
		-s tinypc_imm_gen_tb \
		-o sim/tinypc_imm_gen_tb.vvp \
		rtl/tinypc_imm_gen.sv \
		tb/tinypc_imm_gen_tb.sv
	$(VVP) sim/tinypc_imm_gen_tb.vvp
	@echo "===== TINYPC DECODER TEST ====="
	$(IVERILOG) $(SVFLAGS) -Irtl \
		-s tinypc_decoder_tb \
		-o sim/tinypc_decoder_tb.vvp \
		rtl/tinypc_decoder.sv \
		tb/tinypc_decoder_tb.sv
	$(VVP) sim/tinypc_decoder_tb.vvp

lint-cpu-foundation:
	@echo "===== VERILATOR CPU FOUNDATION LINT ====="
	$(VERILATOR) --lint-only --Wall -Irtl --top-module tinypc_regfile rtl/tinypc_regfile.sv
	$(VERILATOR) --lint-only --Wall -Irtl --top-module tinypc_alu rtl/tinypc_alu.sv
	$(VERILATOR) --lint-only --Wall -Irtl --top-module tinypc_imm_gen rtl/tinypc_imm_gen.sv
	$(VERILATOR) --lint-only --Wall -Irtl --top-module tinypc_decoder rtl/tinypc_decoder.sv

synth-cpu-foundation:
	@echo "===== YOSYS CPU FOUNDATION SYNTHESIS CHECK ====="
	$(YOSYS) -q -p 'read_verilog -sv rtl/tinypc_regfile.sv; hierarchy -check -top tinypc_regfile; proc; opt; check; stat'
	$(YOSYS) -q -p 'read_verilog -sv -Irtl rtl/tinypc_alu.sv; hierarchy -check -top tinypc_alu; proc; opt; check; stat'
	$(YOSYS) -q -p 'read_verilog -sv -Irtl rtl/tinypc_imm_gen.sv; hierarchy -check -top tinypc_imm_gen; proc; opt; check; stat'
	$(YOSYS) -q -p 'read_verilog -sv -Irtl rtl/tinypc_decoder.sv; hierarchy -check -top tinypc_decoder; proc; opt; check; stat'

clean-cpu-foundation:
	rm -f sim/tinypc_regfile_tb.vvp
	rm -f sim/tinypc_alu_tb.vvp
	rm -f sim/tinypc_imm_gen_tb.vvp
	rm -f sim/tinypc_decoder_tb.vvp
