# Makefile for MESI Cache Coherence Controller
# Supports multiple simulators

# Default simulator
SIM ?= iverilog

# File lists
RTL_FILES = rtl/mesi_types_pkg.sv \
            rtl/cache_line.sv \
            rtl/l1_cache_controller.sv \
            rtl/coherence_controller.sv \
            rtl/shared_bus.sv \
            rtl/memory_model.sv \
            rtl/mesi_system_top.sv \
            rtl/mesi_system_wrapper.sv

TB_FILES = tb/mesi_tb.sv

ALL_FILES = $(RTL_FILES) $(TB_FILES)

# Output directories
SIM_DIR = sim
VCD_FILE = $(SIM_DIR)/mesi_tb.vcd

# Simulation executable
SIM_EXE = $(SIM_DIR)/mesi_sim

.PHONY: all clean sim waves lint help

all: sim

# Create sim directory
$(SIM_DIR):
	mkdir -p $(SIM_DIR)

#------------------------------------------------------------------------------
# iverilog (limited SystemVerilog support)
#------------------------------------------------------------------------------
ifeq ($(SIM),iverilog)
sim: $(SIM_DIR)
	@echo "WARNING: iverilog has limited SystemVerilog support"
	@echo "Consider using VCS, Questa, or Verilator instead"
	iverilog -g2012 -o $(SIM_EXE) $(ALL_FILES) && vvp $(SIM_EXE)
endif

#------------------------------------------------------------------------------
# Verilator
#------------------------------------------------------------------------------
ifeq ($(SIM),verilator)
sim: $(SIM_DIR)
	verilator --cc --exe --build -j 4 \
		--top-module mesi_tb \
		--language 1800-2017 \
		--Mdir $(SIM_DIR)/verilator \
		-Wno-fatal \
		--trace \
		$(ALL_FILES) \
		-o mesi_sim
	./$(SIM_DIR)/verilator/mesi_sim
endif

#------------------------------------------------------------------------------
# VCS
#------------------------------------------------------------------------------
ifeq ($(SIM),vcs)
sim: $(SIM_DIR)
	cd $(SIM_DIR) && vcs -full64 -sverilog +v2k \
		-timescale=1ns/1ps \
		-debug_all \
		$(addprefix ../,$(ALL_FILES)) \
		-o mesi_sim
	./$(SIM_EXE)
endif

#------------------------------------------------------------------------------
# Questa/ModelSim
#------------------------------------------------------------------------------
ifeq ($(SIM),questa)
sim: $(SIM_DIR)
	cd $(SIM_DIR) && \
	vlib work && \
	vlog -sv $(addprefix ../,$(ALL_FILES)) && \
	vsim -c mesi_tb -do "run -all; quit -f"
endif

#------------------------------------------------------------------------------
# Syntax check only (no simulation)
#------------------------------------------------------------------------------
lint: $(SIM_DIR)
	@echo "Checking RTL syntax..."
	@for f in $(RTL_FILES); do \
		echo "Checking $$f"; \
		iverilog -g2012 -t null $$f 2>&1 | head -5 || true; \
	done

#------------------------------------------------------------------------------
# View waveforms
#------------------------------------------------------------------------------
waves: $(VCD_FILE)
	gtkwave $(VCD_FILE) &

#------------------------------------------------------------------------------
# Clean
#------------------------------------------------------------------------------
clean:
	rm -rf $(SIM_DIR)/*
	rm -f *.vcd
	rm -rf work

#------------------------------------------------------------------------------
# Help
#------------------------------------------------------------------------------
help:
	@echo "MESI Cache Coherence Controller Makefile"
	@echo ""
	@echo "Usage: make [target] [SIM=simulator]"
	@echo ""
	@echo "Targets:"
	@echo "  sim     - Run simulation (default)"
	@echo "  lint    - Syntax check only"
	@echo "  waves   - Open waveform viewer"
	@echo "  clean   - Remove generated files"
	@echo "  help    - Show this help"
	@echo ""
	@echo "Simulators (SIM=):"
	@echo "  iverilog  - Icarus Verilog (limited SV support)"
	@echo "  verilator - Verilator"
	@echo "  vcs       - Synopsys VCS"
	@echo "  questa    - Mentor Questa/ModelSim"
	@echo ""
	@echo "Example:"
	@echo "  make sim SIM=vcs"
