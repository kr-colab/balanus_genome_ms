#!/bin/bash

thr=24

# Run Repeat Masker on a given genome
work=/sietch_colab/data_share/balanus/balanus_crenatus/annotation

# Existing starting databse
# This is the files extracted from Dfam 3.8
# 6657 is for Crustacea
taxid=6657
rep_db=/sietch_colab/data_share/balanus/repeat_annot/Repbase_db/dfam3.8_${taxid}.fa

# Set the input sequence
in_fasta=${work}/in_genome/BalCre.fasta

# Search term
term=arthropoda

# Make an output directory for run
outp=$(date +${work}/repeats/%y%m%d.earl_grey.${term}.${taxid})
mkdir -p $outp
cd $outp

# Repeat Masker command
cmd=(
    earlGrey
    -g $in_fasta
    -s BalCre
    -o $outp
    -t $thr
    -l $rep_db
    -r $term
    -c yes
    -d yes
)

echo "${cmd[@]}"
"${cmd[@]}"
