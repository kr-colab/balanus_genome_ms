# The .aux and .bbl files are deliberately NOT swept up after a build, so that
# rebuilding a document on its own (e.g. an editor's build-on-save, or a bare
# pdflatex run) still produces a complete PDF. Every pdflatex pass reads the
# .bbl for the bibliography, and for the submission pair the .aux files are also
# the xr-hyper label exchange between the two documents. Delete them and a lone
# pdflatex run degrades silently -- no error, just a PDF whose citations and
# supplement cross-references have all vanished. Only `make clean` removes them.

TEX = main
INTERMEDIATES = $(TEX).blg $(TEX).log $(TEX).out \
                $(TEX).run.xml $(TEX).bcf $(TEX).toc $(TEX).lof $(TEX).lot
MAIN_AUX = $(TEX).aux $(TEX).bbl

# Everything a document is built from. These are prerequisites of $(TEX).pdf so
# that editing a section, the shared preamble, or a figure actually triggers a
# rebuild -- listing only $(TEX).tex made make report "up to date" and leave a
# stale PDF behind, since the real content lives in the \input files.
BIB = references/references.bib
SOURCES = preamble.tex title_authors.tex $(wildcard sections/*.tex) \
          $(wildcard figures/*.pdf) $(wildcard figures/*.png)

SUBMISSION_DOCS = submission_main submission_sups
SUBMISSION_INTERMEDIATES = $(foreach d,$(SUBMISSION_DOCS),\
                           $(d).blg $(d).log $(d).out \
                           $(d).run.xml $(d).bcf $(d).toc $(d).lof $(d).lot)
SUBMISSION_AUX = $(foreach d,$(SUBMISSION_DOCS),$(d).aux $(d).bbl)
SUBMISSION_PDFS = $(addsuffix .pdf,$(SUBMISSION_DOCS))

.PHONY: all clean submission

all: $(TEX).pdf

$(TEX).pdf: $(TEX).tex $(SOURCES) $(BIB)
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
	rm -f $(INTERMEDIATES) $(MAIN_AUX) $(TEX).pdf \
	      $(SUBMISSION_INTERMEDIATES) $(SUBMISSION_AUX) $(SUBMISSION_PDFS)
