TEX = main
INTERMEDIATES = $(TEX).aux $(TEX).bbl $(TEX).blg $(TEX).log $(TEX).out \
                $(TEX).run.xml $(TEX).bcf $(TEX).toc $(TEX).lof $(TEX).lot

.PHONY: all clean

all: $(TEX).pdf

$(TEX).pdf: $(TEX).tex references/references.bib
	pdflatex -interaction=nonstopmode $(TEX).tex
	bibtex $(TEX)
	pdflatex -interaction=nonstopmode $(TEX).tex
	pdflatex -interaction=nonstopmode $(TEX).tex
	rm -f $(INTERMEDIATES)

clean:
	rm -f $(INTERMEDIATES) $(TEX).pdf
