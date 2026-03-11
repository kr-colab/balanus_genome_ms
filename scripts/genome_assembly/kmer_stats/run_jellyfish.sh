#!/bin/bash

THR=12

work=/sietch_colab/data_share/balanus/kmers
gzreads=$work/reads/m64047_blaGla.merged.ccs.fastq
reads=$work/reads/BalGla_hifi_3cell_merged.fastq
k=21

# Outputs
jf=$work/BalGla_${k}-mers.jf
histo=$work/BalGla_${k}-mers.histo

# First, de-compress reads
zcat $gzreads > $reads

# Run the k-mer counts
jellyfish count \
    --canonical \
    --mer-len $k \
    --size 1000000000 \
    --threads $THR \
    --output $jf \
    $reads

# Generate a k-mer histogram
jellyfish histo \
    --threads $THR \
    --output $histo \
    $jf

# Delete raw reads
# rm $reads
