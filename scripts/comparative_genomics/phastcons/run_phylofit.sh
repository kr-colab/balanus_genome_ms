#!/bin/bash

THR=1
work=/sietch_colab/data_share/balanus/comp_genomics

# Inputs
msa=$work/whole_genome_alignments/barnacle_n6.seqFile.maf
tree=$work/tree/barnacle_n6.tree

# Model
model=REV # Default

# Outputs
out=$work/phastCons/barnacle_n6.${model}
log=$work/phastCons/phyloFit.log

cmd=(
    phyloFit
    --tree $tree
    --subst-mod $model
    --log ${out}.mod.log
    --out-root $out
    --msa-format "MAF"
    $msa
)

echo "${cmd[@]}"
"${cmd[@]}" &> $log
