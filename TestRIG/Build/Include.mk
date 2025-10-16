# WARNING: This Makefile is 'include'd from other Makefiles. It should not be used by itself.

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  b_compile b_link b_run   bsc-compile, link and run for Bluesim"
	@echo "  v_compile v_link v_run   bsc-compile, link and run for Verilator"
	@echo ""
	@echo "  b_all = b_compile b_link b_run"
	@echo "  v_all = v_compile v_link v_run"
	@echo ""
	@echo "  clean                    Remove temporary intermediate files"
	@echo "  full_clean               Restore to pristine state"

.PHONY: all
b_all: b_compile b_link b_run
v_all: v_compile v_link v_run

# ****************************************************************
# Config

EXEFILE ?= exe_$(CPU)_$(RV)

# ****************************************************************
# Common bsc args

REPO = ../../..

SRC_CPU    = $(REPO)/Code/src_$(CPU)
SRC_COMMON = $(REPO)/Code/src_Common

SRC_TOP         = $(REPO)/Code/src_Top
SRC_TOP_TESTRIG = $(REPO)/TestRIG/src_Top_TestRIG

TOPFILE   ?= $(SRC_TOP_TESTRIG)/Top_TestRIG.bsv
TOPMODULE ?= mkTop_TestRIG

MISC_LIBS  = $(REPO)/Code/vendor/bsc-contrib_Misc
MISC_LIBS2 = $(REPO)/TestRIG/vendor/BSV-RVFI-DII

BSCFLAGS = -D $(RV) \
	-use-dpi \
	-keep-fires \
	-aggressive-conditions \
	-no-warn-action-shadowing \
	-show-range-conflict \
        -opt-undetermined-vals \
	-unspecified-to X \
	-show-schedule

C_FILES  = $(SRC_TOP)/C_Mems_Devices.c
C_FILES += $(SRC_TOP)/UART_model.c
C_FILES += $(REPO)/TestRIG/vendor/SocketPacketUtils/socket_packet_utils.c

# Only needed if we import C code
BSC_C_FLAGS += -Xl -v  -Xc -O3  -Xc++ -O3

ifdef DRUM_RULES
BSCFLAGS += -D DRUM_RULES
endif

# ----------------
# bsc's directory search path

BSCPATH = $(SRC_TOP_TESTRIG):$(SRC_TOP):$(SRC_CPU):$(SRC_COMMON):$(MISC_LIBS):$(MISC_LIBS2):+

# ****************************************************************
# FOR VERILATOR

VSIM      = verilator

BSCDIRS_V = -bdir build_v  -info-dir build_v  -vdir verilog

BSCPATH_V = $(BSCPATH)

build_v:
	mkdir -p $@

verilog:
	mkdir -p $@

.PHONY: v_compile
v_compile: build_v verilog
	@echo "Compiling for Verilog (Verilog generation) ..."
	bsc -u -elab -verilog  $(BSCDIRS_V)  $(BSCFLAGS)  -p $(BSCPATH_V)  $(TOPFILE)
	@echo "Verilog generation finished"

.PHONY: v_link
v_link: build_v verilog
	@echo "Linking for Verilog simulation (simulator: $(VSIM)) ..."
	bsc -verilog  -vsim $(VSIM)  -use-dpi  -keep-fires  -v  $(BSCDIRS_V) \
		-e $(TOPMODULE) -o ./$(EXEFILE)_$(VSIM) \
		$(BSC_C_FLAGS) \
		$(C_FILES)
	@echo "Linking for Verilog simulation finished"

.PHONY: v_run
v_run:
	@echo "INFO: Simulation ..."
	./$(EXEFILE)_verilator
	@echo "INFO: Finished Simulation"

# ****************************************************************
# FOR BLUESIM

BSCDIRS_BSIM_c = -bdir build_b -info-dir build_b
BSCDIRS_BSIM_l = -simdir C_for_bsim

BSCPATH_BSIM = $(BSCPATH)

build_b:
	mkdir -p $@

C_for_bsim:
	mkdir -p $@

.PHONY: b_compile
b_compile: build_b
	@echo Compiling for Bluesim ...
	bsc -u -sim $(BSCDIRS_BSIM_c)  $(BSCFLAGS)  -p $(BSCPATH_BSIM)  $(TOPFILE)
	@echo Compilation for Bluesim finished

.PHONY: b_link
b_link: build_b C_for_bsim
	@echo Linking for Bluesim ...
	bsc  -sim  -parallel-sim-link 8\
		$(BSCDIRS_BSIM_c)  $(BSCDIRS_BSIM_l)  -p $(BSCPATH_BSIM) \
		-e $(TOPMODULE) -o ./$(EXEFILE)_bsim \
		-keep-fires \
		$(BSC_C_FLAGS)  $(C_FILES)
	@echo Linking for Bluesim finished

.PHONY: b_run
b_run:
	@echo "INFO: Simulation ..."
	./$(EXEFILE)_bsim
	@echo "INFO: Finished Simulation"

# ****************************************************************

.PHONY: clean
clean:
	rm -r -f  *~  .*~  src_*/*~  build*  C_for_bsim  $(VERILATOR_MAKE_DIR)

.PHONY: full_clean
full_clean: clean
	rm -r -f  exe_*  verilog  log*  $(SRC_TOP)/*.o  $(SRC_TOP_TESTRIG)/*.o  obj_dir_*

# ****************************************************************
