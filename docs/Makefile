TEX = main
INTERMEDIATES = $(TEX).aux $(TEX).bbl $(TEX).blg $(TEX).log $(TEX).out \
                $(TEX).run.xml $(TEX).bcf $(TEX).toc $(TEX).lof $(TEX).lot

SUBMISSION_DOCS = submission_main submission_sups
SUBMISSION_INTERMEDIATES = $(foreach d,$(SUBMISSION_DOCS),\
                           $(d).aux $(d).bbl $(d).blg $(d).log $(d).out \
                           $(d).run.xml $(d).bcf $(d).toc $(d).lof $(d).lot)
SUBMISSION_PDFS = $(addsuffix .pdf,$(SUBMISSION_DOCS))

.PHONY: all clean submission

all: $(TEX).pdf

$(TEX).pdf: $(TEX).tex references/references.bib
	pdflatex -interaction=nonstopmode $(TEX).tex
	biber $(TEX)
	pdflatex -interaction=nonstopmode $(TEX).tex
	pdflatex -interaction=nonstopmode $(TEX).tex
	rm -f $(INTERMEDIATES)

# Build both submission_main.pdf and submission_sups.pdf. The two documents
# cross-reference each other via xr-hyper, so each pdflatex pass needs the
# other document's .aux file already on disk — hence the interleaved passes.
submission:
	pdflatex -interaction=nonstopmode submission_main.tex
	pdflatex -interaction=nonstopmode submission_sups.tex
	biber submission_main
	biber submission_sups
	pdflatex -interaction=nonstopmode submission_main.tex
	pdflatex -interaction=nonstopmode submission_sups.tex
	pdflatex -interaction=nonstopmode submission_main.tex
	pdflatex -interaction=nonstopmode submission_sups.tex
	rm -f $(SUBMISSION_INTERMEDIATES)

clean:
	rm -f $(INTERMEDIATES) $(TEX).pdf \
	      $(SUBMISSION_INTERMEDIATES) $(SUBMISSION_PDFS)
