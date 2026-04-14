#!/bin/bash

THR=16

work=/sietch_colab/data_share/balanus/balanus_crenatus/annotation

# BalCre genome
target_fa=$work/in_genome/BalCre.fasta

# BalGla annotation
ref_fa=$work/balGla_annotation/BalGla.fa
ref_gff=$work/balGla_annotation/BalGla.gff3

# Parameters
f=0.1   # Distance
d=2.5   # Scaling distance
c=0.25  # Feature coverage
s=0.25  # Feature sequence identity
sc=0.5  # Copy sequence identity

# Output directory
outd=$(date +$work/lifton/%Y%m%d.lifton_f${f}_a${c}_s${s}_sc${sc}_mpj1)
mkdir -p $outd
cd $outd

# Outputs
out_gff=$outd/BalCre.gff3
out_ump=$outd/BalCre.unmapped_features.txt
int_dir=$outd/intermediate_files

# LiftOff
cmd=(
    lifton
    --reference-annotation $ref_gff
    --output $out_gff
    -u $out_ump
    --threads $THR
    --write_chains
    -copies
    -polish
    -flank $f
    -mp_options="-j 1"
    #-mm2_options="-x asm20"
    -a $c
    -s $s
    -sc $sc
    $target_fa
    $ref_fa
)
echo "${cmd[@]}"
"${cmd[@]}"
