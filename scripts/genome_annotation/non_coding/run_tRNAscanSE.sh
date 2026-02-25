#!/bin/bash
THR=12
work=/sietch_colab/data_share/balanus/ncRNAs
genome=$work/in_genome/BalGla.fa
outdir=$work/tRNAscan_SE
prefix=$outdir/BalGla_tRNA

cmd=(
    tRNAscan-SE
    -E
    --hitsrc
    --output ${prefix}.tRNAscan_SE.out
    --stats ${prefix}.stats
    --gff ${prefix}.gff
    --prefix $prefix
    --thread $THR
    $genome
)
echo "${cmd[@]}"
"${cmd[@]}"
