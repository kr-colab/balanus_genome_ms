#!/bin/bash

THR=12

work=/sietch_colab/data_share/balanus/balanus_crenatus/kmers
gzreads=$work/reads/m64047_balCre.merged.ccs.fastq.gz
reads=$work/reads/BalCre_hifi_2cell_merged.fastq
k=21

# Outputs
jf=$work/BalCre_${k}-mers.jf
histo=$work/BalCre_${k}-mers.histo

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
rm $reads
