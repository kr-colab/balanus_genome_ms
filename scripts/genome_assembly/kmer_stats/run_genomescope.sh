#!/bin/bash

THR=12

work=/sietch_colab/data_share/balanus/kmers

# Set inputs
k=21
histo=$work/BalGla_${k}-mers.histo

# Outputs
outdir=$work/genoscope_k${k}_out
name=BalGla_${k}-mers.genomescope
mkdir -p $outdir

cmd=(
    genomescope2
    --input $histo
    --ploidy 2
    --kmer_length $k
    --output $outdir
    --name_prefix $name
)
echo s"${cmd[@]}"
"${cmd[@]}"
