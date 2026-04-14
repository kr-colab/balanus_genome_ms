#!/bin/bash

work=/sietch_colab/ariverac/balanus_genome/assemblies/20240226.3cell_Thecostraca.hifiasm_0.19.8.s25_D10_ONT_HiC_hmc68_hgs800_dualScaff/hi-c
bam=$work/hic-alns/balGla_hic.GC3F-SS-8331-7549_S1.processed.bam
fasta=$work/genome/balGla.3c_Thc.ONT_HiC_D10_s25.purged.fa
outp=$work/yahs-scaffolding/balGla.3c_Thc.ONT_HiC_D10_s25.yahs
log=$work/yahs-scaffolding/yahs.log

cmd=(
    yahs
    -o $outp
    -q 10
    -r 1000,5000,10000,20000,50000,100000,200000,500000,1000000,2000000,5000000,10000000,20000000,50000000,100000000,200000000,500000000
    $fasta
    $bam
)

echo "${cmd[@]}"
"${cmd[@]}" > $log 2>&1
