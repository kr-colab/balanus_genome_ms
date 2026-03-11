#!/bin/bash

set -e
set -o pipefail
THR=8
NPR=4

# General paths
work=/sietch_colab/data_share/balanus/popgen/202503-analysis
fa=$work/ref_genome/BalGla.fa
gff=$work/ref_genome/BalGla.gff
scaffs=$work/ref_genome/scaff_list_1mb.txt
indir=$work/genotyping/ref_indv/raw
outdir=$work/genotyping/ref_indv/normalized

# Loop over the desired sequences
cat $scaffs | grep -v '^#' | #head -n1 |
while read scaff; do
    # Set the inputs/outputs for that sequence
    inbcf=$indir/Bgland_${scaff}.raw.bcf
    outbcf=$outdir/Bgland_${scaff}.norm.bcf
    # Run Bcftools
    cmd=(
        bcftools norm
        --output-type b
        --output $outbcf
        --threads $NPR
        --fasta-ref $fa
        --multiallelics +both
        $inbcf
    )
    echo "${cmd[@]}"
done | parallel -j $THR
