.PHONY: help
help:
	@echo "Targets:"
	@echo "  TestRIG_setup.pdf"
	@echo ""
	@echo "  help          show this help text"
	@echo "  all           $(ALL)"
	@echo "  clean         remove temporary intermediate files"
	@echo "  full_clean    restore directory to pristine state"

# ================================================================
# RULES

%.pdf: %.adoc
	asciidoctor-pdf  $<

%.html: %.adoc
	asciidoctor  $<

# ================================================================

ALL += TestRIG_Setup.html

.PHONY: all
all: $(ALL)

# ================================================================

.PHONY: clean
clean:
	rm -r -f *~

.PHONY: full_clean
full_clean: clean
	rm -r -f  $(ALL)
