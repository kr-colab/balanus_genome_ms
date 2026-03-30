#!/bin/bash

src=/home/ariverac/local/opt/quast-5.2.0
work=/sietch_colab/data_share/balanus/balanus_crenatus/assemblies/20241003.hifiasm_0.19.8.s25_D10_hmc40_hgs800_dualScaff/quast
fasta=$work/balCre.hmc40_D10_s25.p_ctg.fasta.gz

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
