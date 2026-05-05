# Barnacle genome paper

Working repository for the Pacific acorn barnacle (*Balanus glandula*) genome paper:

> Rivera-Colón, *et al*. (2026)
> **The genome of the Pacific acorn barnacle provides insights into the evolution of extremely large populations**
> *bioRxiv*. [DOI: 10.64898/2026.04.27.721231](https://doi.org/10.64898/2026.04.27.721231)

## Contents

### `docs/`

The `docs/` directory contains the necessary files to generate the manuscript LaTeX file.

### `scripts/`

The `scripts/` contains a copy and example of the scripts uses for the analysis of the
data. See the `scripts/METHODS.md` document for a file-by-file description of the contents
of this directory.

## Building

```sh
cd docs/
make             # generate PDF (main.pdf)
make submission  # generate the PDFs for journal submission (submission_main.pdf & submission_sups.pdf)
make clean       # remove build artifacts
```

## Authors

**Angel G. Rivera-Colon**  
Institute of Ecology and Evolution  
University of Oregon

**Scott Small**  
Institute of Ecology and Evolution  
University of Oregon

**Erin Jezuit**  
Institute of Molecular Biology  
Oregon Institute of Marine Biology  
University of Oregon

**John P. Wares**  
Odum School of Ecology  
Department of Genetics  
University of Georgia

**Andrew Kern**  
Department of Biology  
Institute of Ecology and Evolution  
University of Oregon
