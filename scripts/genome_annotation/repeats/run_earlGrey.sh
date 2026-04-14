#!/bin/bash

thr=24

# Run Repeat Masker on a given genome
work=/sietch_colab/ariverac/balanus_genome/assemblies/20240226.3cell_Thecostraca.hifiasm_0.19.8.s25_D10_ONT_HiC_hmc68_hgs800_dualScaff/hi-c/20250129.curation/repeats

# Existing starting databse
# This is the files extracted from Dfam 3.8
# 6657 is for Crustacea
taxid=6657
rep_db=/sietch_colab/data_share/balanus/repeat_annot/Repbase_db/dfam3.8_${taxid}.fa

# Set the input sequence
in_fasta=${work}/in_genome/BalGla.fasta

# Search term
term=arthropoda

# Target Species name
name="BalGla"

# Make an output directory for run
outp=$(date +${work}/%y%m%d.earl_grey.${term}.${taxid})
mkdir -p $outp
cd $outp

# Repeat Masker command
cmd=(
    earlGrey
    -g $in_fasta
    -s $name
    -o $outp
    -t $thr
    -l $rep_db
    -r $term
    -c yes
    -d yes
)

echo "${cmd[@]}"
"${cmd[@]}"

