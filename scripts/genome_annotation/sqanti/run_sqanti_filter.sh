#!/bin/bash

# Put bash in strict mode
set -e
set -o pipefail

THR=24
PRC=$((${THR}/4))

# Set up the SOURCE
# Needed for things being in the PATH or not
SRC=/home/ariverac/local/opt/SQANTI3-5.2.2
export PYTHONPATH="$PYTHONPATH:${SRC}/utilities/cupcake/sequence"
export PYTHONPATH="$PYTHONPATH:${SRC}/utilities/cupcake"
export PATH="${SRC}:$PATH"

# Main working directory
work=/sietch_colab/data_share/balanus/genome_annot/braker_annotation/SQANTI3

# General SQANTI directory
sq_dir=$work/20241207.SQANTI3_out

# Previous SQANTI QC run
sq_qc=${sq_dir}/SQANTI3_QC
class=${sq_qc}/isoforms.corr_classification.txt
gtf=${sq_qc}/isoforms.corr_corrected.gtf
faa=${sq_qc}/isoforms.corr_corrected.faa

# Current output directoru for SQANTI filter
sq_flt=${sq_dir}/SQANTI3_FILTER
mkdir -p $sq_flt
cd $sq_flt

# Basename of all outputs
name=BalGla_BKR_TRD_SQN

# Prepare command and run
cmd=(
    $SRC/sqanti3_filter.py
    rules
    --gtf $gtf
    --faa $faa
    --output $name
    --dir $sq_flt
    $class

)
echo "${cmd[@]}"
"${cmd[@]}"
