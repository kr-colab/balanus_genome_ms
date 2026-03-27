#!/bin/bash

work=/sietch_colab/data_share/balanus/rna-seq
in_dir=$work/raw
out_dir=$work/processed/7699
name=Balanus-mRNA_S1_L002
log=$out_dir/${name}.fastp.log

cd $out_dir

cmd=(
    fastp
    --in1 ${in_dir}/${name}_R1_001.fastq.gz
    --in2 ${in_dir}/${name}_R2_001.fastq.gz
    --out1 ${out_dir}/${name}.1.fq.gz
    --out2 ${out_dir}/${name}.2.fq.gz
    --length_required 25
    --detect_adapter_for_pe
    --thread 6
)

echo "${cmd[@]}"
"${cmd[@]}" > $log 2>&1

