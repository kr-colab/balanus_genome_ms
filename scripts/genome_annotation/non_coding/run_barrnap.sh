#!/bin/bash
THR=12

work=/sietch_colab/data_share/balanus/genome_annot/non_coding
genome=$work/in_genome/BalGla.fa
outdir=$work/barrnap_out
outgff=$outdir/BalGla.rRNA.gff
outfa=$outdir/BalGla.rRNA.fa
outlog=$outdir/barrnap.log

mkdir -p $outdir
cd $outdir

cmd=(
    barrnap
    --threads $THR
    --kingdom euk
    --outseq $outfa
    $genome
)
echo "${cmd[@]}"
"${cmd[@]}" 1> $outgff 2> $outlog

