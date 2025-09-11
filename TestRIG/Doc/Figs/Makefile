# This Makefile has a generic rule to convert an .svg file into a .png file using Inkscape

.PHONY: help
help:
	@echo "Available 'make' targets:"
	@echo "  <file>.png    generate '<file>.png' from '<file>.svg' using inkscape"
	@echo ""
	@echo "  all           $(ALL)"
	@echo "  help          show this help text"
	@echo "  clean         remove temporary intermediate files"
	@echo "  full_clean    restore directory to pristine state"

# ================================================================
# RULES

DIAGS_2025 = $(HOME)/Diagrams/2025

%.png: %.svg
	inkscape --export-filename=$@  --export-area-drawing  -d 300 -y 0.0 $<

%.png: $(DIAGS_2025)/%.svg
	inkscape --export-filename=$@  --export-area-drawing  -d 300 -y 0.0 $<

# ================================================================

ALL1 += TestRIG_Setup.png
ALL2 += RSN_2025-06-28.000.00_TestRIG_Fife.png

.PHONY: all
all: $(ALL1) $(ALL2)

# ================================================================

.PHONY: clean
clean:
	rm -r -f *~

.PHONY: full_clean
full_clean: clean
