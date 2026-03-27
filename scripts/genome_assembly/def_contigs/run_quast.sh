#!/bin/bash

src=/home/ariverac/local/opt/quast-5.2.0
work=/sietch_colab/ariverac/balanus_genome/assemblies/20230817.3cell.hifiasm.def/quast
fasta=$work/../balGla.def.p_ctg.fasta.gz
outdir=$(date +$work/%Y%m%d.quast/)
mkdir -p $outdir

cmd=(
    python3
    $src/quast.py
    --fast
    --output-dir $outdir
    --threads 4
    --split-scaffolds
    --eukaryote
    --est-ref-size 800000000
    $fasta
)

echo "${cmd[@]}"
"${cmd[@]}"
