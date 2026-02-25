#!/bin/bash

THR=12

work=/sietch_colab/data_share/balanus/genome_annot/non_coding
ref_gff=$work/in_genome/BalGla.gff
bam=$work/alignments/m64047_231004_192515.ccs.bam
out_gtf=$work/stringtie_out/BalGla_IsoSeq.stringtie.gtf

cmd=(
    stringtie
    -L
    -G $ref_gff
    -o $out_gtf
    -p $THR
    $bam
)
echo "${cmd[@]}"
"${cmd[@]}"

