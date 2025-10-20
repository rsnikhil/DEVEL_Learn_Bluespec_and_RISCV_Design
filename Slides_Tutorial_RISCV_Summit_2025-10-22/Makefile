SLIDES     = Slides.tex
SLIDES_PDF = Slides.pdf

.PHONY: pdf
pdf: $(SLIDES_PDF)

%.pdf: %.tex  Preamble.tex  Postamble.tex
	mkdir -p tmp_latex
	pdflatex -output-directory=tmp_latex $<
	cp  tmp_latex/$@  .

.PHONY: p
p:
	mkdir -p tmp_latex
	pdflatex -output-directory=tmp_latex  $(SLIDES)
	cp  tmp_latex/$(SLIDES_PDF) .

.PHONY: figs
figs:
	make -C Figures png

Placeholder.pdf: Placeholder.tex  Preamble.tex
	mkdir -p tmp_latex
	pdflatex -output-directory=tmp_latex $<
	cp  tmp_latex/$@  .

# ================================================================

.PHONY: clean
clean:
	rm -r -f  *~

.PHONY: full_clean
full_clean: clean
	rm -r -f  tmp_latex  $(SLIDES_PDF)
