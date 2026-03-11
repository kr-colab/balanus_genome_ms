#!/bin/bash

set -e
set -o pipefail
THR=12
NPR=4

# General paths
work=/sietch_colab/data_share/balanus/popgen/202503-analysis
align=$work/alignments
fa=$work/ref_genome/BalGla.fa
scaffs=$work/ref_genome/scaff_list_1mb.txt
bam=$align/Bgland_00.bam
outp=$work/genotyping/ref_indv/raw

# Go to alignments to preseve the right IDs of the samples
cd $align

# Loop over the desired sequences
cat $scaffs | grep -v '^#' |
while read scaff; do
    # Set the output for that sequence
    bcf=$outp/Bgland_${scaff}.raw.bcf
    # Run bcftools
    cmd=(
        bcftools mpileup
            --output-type u
            --threads $THR
            --annotate "FORMAT/AD,FORMAT/DP,INFO/AD"
            --regions $scaff
            --max-depth 250
            --fasta-ref $fa
            $bam
        \|
        bcftools call
            --multiallelic-caller
            --ploidy 2
            --threads $THR
            --annotate "GQ,GP"
            --output-type b
            --output $bcf
    )
    echo "${cmd[@]}"
done | parallel -j $NPR
