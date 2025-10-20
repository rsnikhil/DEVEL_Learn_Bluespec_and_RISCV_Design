.PHONY: help
help:
	@echo "Targets:"
	@echo "  all    Produces image (.jpg, .png) files"

# ================================================================

DIAGRAMS_0000 = $(HOME)/Diagrams/0000
DIAGRAMS_2025 = $(HOME)/Diagrams/2025
BOOK_DIR   = $(HOME)/Git/DEVEL_Learn_Bluespec_and_RISCV_Design/Book/Figures

IMGS += Bluespec_Logo_2022-10.jpg

FIGS += RSN_2025-07-25.000.00_Tutorial_Plan.png
FIGS += RSN_2025-09-01.000.00_FifeDrum_Stages_Multilayer_L1.png
# FROM_BOOK += Fig_Instr_Exec_w_structs.png
FIGS += RSN_2025-09-01.000.00_FifeDrum_Stages_Multilayer_L1_L3.png
# FROM_BOOK += Fig_Instr_Exec_w_FIFOs.png
FIGS += RSN_2025-09-01.000.00_FifeDrum_Stages_Multilayer_L1_L2_L3.png
FIGS += RSN_2025-06-28.000.00_TestRIG_Fife.png
# FROM_BOOK += Fig_RISCV_Epochs.png
FIGS += RSN_2025-09-15.000.00_Fife_Epochs.png
# FROM_BOOK += Fig_RISCV_Scoreboard.png
FIGS += RSN_2025-10-07.000.00_Scoreboard.png
# FROM_BOOK += Fig_RISCV_Store_Buffer.png
FIGS += RSN_2025-10-07.002.00_Store_Buffer.png
FIGS += RSN_2025-10-07.001.00_Concurrent_Exec_Pipes.png

FIGS += RSN_2025-10-14.000.00_TestRIG_Setup.png
FIGS += RSN_2025-10-15.000.00_CPU_Verif_Complexity.png
FIGS += RSN_2025-10-15.001.00_Symmetric_Tandem_Verification.png
FIGS += RSN_2025-05-27.023.00_BLang_Build_Flows.png
FIGS += RSN_2025-10-16.000.00_RISCV_Tutorial_Resources.png
FIGS += RSN_2025-10-13.001.00_Fife_Retire_L1.png
FIGS += RSN_2025-10-13.001.00_Fife_Retire_L1_L2.png

%.png: $(DIAGRAMS_2025)/%.svg
	inkscape --export-filename=$@  --export-area-drawing  -d 300 -y 0.0 $<

LAYER_1 = 'select-all:layers; object-set-attribute:style, display:none; select-clear; select-by-id:layer1; object-set-attribute:style, display:inline'

%_L1.png: $(DIAGRAMS_2025)/%.svg
	inkscape --actions=$(LAYER_1) \
		--export-filename=$@ --export-area-drawing  -d 300 -y 0.0 $<

LAYERS_1_2 = 'select-all:layers; object-set-attribute:style, display:none; select-clear; select-by-id:layer1,layer2; object-set-attribute:style, display:inline'

%_L1_L2.png: $(DIAGRAMS_2025)/%.svg
	inkscape --actions=$(LAYERS_1_2) \
		--export-filename=$@ --export-area-drawing  -d 300 -y 0.0 $<

Bluespec_Logo_2022-10.jpg: $(DIAGRAMS_0000)/Bluespec_Logo_2022-10.jpg
	cp -p  $<  $@

Fig_%.png: $(BOOK_DIR)/Fig_%.png
	cp -p  $<  $@

all: $(IMGS) $(FIGS) $(FROM_BOOK)

# ================================================================
# Rules to extract selected layers of SVG into separate PNGs

LAYER_1 = 'select-all:layers; object-set-attribute:style, display:none; select-clear; select-by-id:layer1; object-set-attribute:style, display:inline'

%_L1.png: $(DIAGRAMS_2025)/%.svg
	inkscape --actions=$(LAYER_1) \
		--export-filename=$@ --export-area-drawing  -d 300 -y 0.0 $<

LAYER_2 = 'select-all:layers; object-set-attribute:style, display:none; select-clear; select-by-id:layer2; object-set-attribute:style, display:inline'

%_L2.png: $(DIAGRAMS_2025)/%.svg
	inkscape --actions=$(LAYER_2) \
		--export-filename=$@ --export-area-drawing  -d 300 -y 0.0 $<

LAYER_3 = 'select-all:layers; object-set-attribute:style, display:none; select-clear; select-by-id:layer3; object-set-attribute:style, display:inline'

%_L3.png: $(DIAGRAMS_2025)/%.svg
	inkscape --actions=$(LAYER_3) \
		--export-filename=$@ --export-area-drawing  -d 300 -y 0.0 $<

LAYER_4 = 'select-all:layers; object-set-attribute:style, display:none; select-clear; select-by-id:layer4; object-set-attribute:style, display:inline'

%_L4.png: $(DIAGRAMS_2025)/%.svg
	inkscape --actions=$(LAYER_4) \
		--export-filename=$@ --export-area-drawing  -d 300 -y 0.0 $<

LAYERS_1_2 = 'select-all:layers; object-set-attribute:style, display:none; select-clear; select-by-id:layer1,layer2; object-set-attribute:style, display:inline'

%_L1_L2.png: $(DIAGRAMS_2025)/%.svg
	inkscape --actions=$(LAYERS_1_2) \
		--export-filename=$@ --export-area-drawing  -d 300 -y 0.0 $<

LAYERS_1_3 = 'select-all:layers; object-set-attribute:style, display:none; select-clear; select-by-id:layer1,layer3; object-set-attribute:style, display:inline'

%_L1_L3.png: $(DIAGRAMS_2025)/%.svg
	inkscape --actions=$(LAYERS_1_3) \
		--export-filename=$@ --export-area-drawing  -d 300 -y 0.0 $<

LAYERS_1_4 = 'select-all:layers; object-set-attribute:style, display:none; select-clear; select-by-id:layer1,layer4; object-set-attribute:style, display:inline'

%_L1_L4.png: $(DIAGRAMS_2025)/%.svg
	inkscape --actions=$(LAYERS_1_4) \
		--export-filename=$@ --export-area-drawing  -d 300 -y 0.0 $<

LAYERS_2_3 = 'select-all:layers; object-set-attribute:style, display:none; select-clear; select-by-id:layer2,layer3; object-set-attribute:style, display:inline'

%_L2_L3.png: $(DIAGRAMS_2025)/%.svg
	inkscape --actions=$(LAYERS_2_3) \
		--export-filename=$@ --export-area-drawing  -d 300 -y 0.0 $<

LAYERS_1_2_3 = 'select-all:layers; object-set-attribute:style, display:none; select-clear; select-by-id:layer1,layer2,layer3; object-set-attribute:style, display:inline'

%_L1_L2_L3.png: $(DIAGRAMS_2025)/%.svg
	inkscape --actions=$(LAYERS_1_2_3) \
		--export-filename=$@ --export-area-drawing  -d 300 -y 0.0 $<

LAYERS_1_2_3_4 = 'select-all:layers; object-set-attribute:style, display:none; select-clear; select-by-id:layer1,layer2,layer3,layer4; object-set-attribute:style, display:inline'

%_L1_L2_L3_L4.png: $(DIAGRAMS_2025)/%.svg
	inkscape --actions=$(LAYERS_1_2_3_4) \
		--export-filename=$@ --export-area-drawing  -d 300 -y 0.0 $<

# ================================================================

.PHONY: png
png: $(FIGS)

.PHONY: clean
clean:
	rm -r -f  *~

.PHONY: full_clean
full_clean: clean
	rm -r -f  $(FIGS)
