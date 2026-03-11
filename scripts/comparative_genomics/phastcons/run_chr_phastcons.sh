#!/bin/bash

THR=12
work=/sietch_colab/data_share/balanus/comp_genomics

# Alignments
mafs=$work/whole_genome_alignments
# Model
mod=$work/phastCons/barnacle_n6.REV.mod
# Chromosome list
chroms=$work/phastCons/chr_list.txt
# Basename of outputs
outbase=$work/phastCons/barnacle_n6.REV

# Function to run
run_phastcons () {
    chrom=$1
    maf=$mafs/barnacle_n6.seqFile.${chrom}.maf
    wig=${outbase}.${chrom}.wig
    bed=${outbase}.${chrom}.conserved.bed
    tree=${outbase}.${chrom}.tree

    cmd=(
        phastCons
        --score
        --seqname $chrom
        --estimate-trees $tree
        --most-conserved $bed \
        --msa-format MAF 
        $maf
        $mod
        \> $wig
    )
    echo "${cmd[@]}"
    # "${cmd[@]}" > $wig
}

# Loop over the chromosomes
cat $chroms | grep -v '^#' |
while read chrom; do
    run_phastcons $chrom
done | parallel -j $THR
