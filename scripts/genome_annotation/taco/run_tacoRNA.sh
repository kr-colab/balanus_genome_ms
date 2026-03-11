#!/bin/bash

# Put bash in strict mode
set -e
set -o pipefail

THR=8

work=/sietch_colab/data_share/balanus/genome_annot/braker_annotation/taco_merged

# Input GTFs
gtfs=(
    $work/in_files/braker_td.gtf
    $work/in_files/isoseq_sqanti_td.gtf
)

# Create new output
outd=$(date +$work/%Y%m%d.taco_run)

# Create the annotation file and add the target files
annotations=$work/in_files/gtf_files.txt
for gtf in ${gtfs[@]}; do
    echo $gtf
done > $annotations

# Run TacoRNA
cmd=(
    taco_run
    --num-processes $THR
    --output-dir $outd
    --gtf-expr-attr "fpkm"
    --filter-min-expr "0.0"
    $annotations
)
echo "${cmd[@]}"
"${cmd[@]}"
