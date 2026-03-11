#!/bin/bash

# Put bash in strict mode
set -e
set -o pipefail

THR=8

work=/sietch_colab/data_share/balanus/genome_annot/braker_annotation/taco_merged
ref_gtf=$work/in_files/braker_td.gtf

# Taco outputs
taco_dir=$work/20241212.taco_run
taco_gtf=$taco_dir/assembly.gtf
cd $taco_dir

# Run TacoRNA
cmd=(
    taco_refcomp
    --num-processes $THR
    --ref-gtf $ref_gtf
    --test-gtf $taco_gtf
)
echo "${cmd[@]}"
"${cmd[@]}"
