#!/bin/bash

thr=8
work=/sietch_colab/data_share/balanus/genome_annot/20240521.balGla.4c_Thc.hifiasm_s45_D10_ONT.tigmint.yahs/in_genome
fasta=$work/balGla.softmasked.fasta
index=$work/balGla.softmasked.idx

cmd=(
    hisat2-build
    -p $thr
    $fasta
    $index
)
echo "${cmd[@]}"
"${cmd[@]}"

