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
# Path to the default filtering rules
json=$SRC/utilities/filter/filter_default.json

# Main working directory
work=/sietch_colab/data_share/balanus/genome_annot/braker_annotation/SQANTI3

# General SQANTI directory
sq_dir=$work/20241207.SQANTI3_out

# Reference files
ref_dir=$work/in_annotation/
ref_fa=$ref_dir/BalGla_tigmint_breaktg_v2.corr.fasta
ref_gtf=$ref_dir/braker_transdecoder.corr.gtf

# Previous SQANTI QC run
sq_qc=${sq_dir}/SQANTI3_QC
qc_iso=$sq_qc/isoforms.corr_corrected.fasta
# qc_gtf=$sq_qc/isoforms.corr_corrected.gtf
qc_class=$sq_qc/isoforms.corr_classification.txt

# Previous SQANTI Filter run
sq_flt=${sq_dir}/SQANTI3_FILTER
flt_class=${sq_flt}/BalGla_BKR_TRD_SQN_RulesFilter_result_classification.txt
flt_gtf=${sq_flt}/BalGla_BKR_TRD_SQN.filtered.gtf

# Output to current SQANTI recover run
sq_rec=${sq_dir}/SQANTI3_RECOVER
mkdir -p $sq_rec
cd $sq_rec

# Basename of all outputs
name=BalGla_BKR_TRD_SQN

# Prepare command and run
cmd=(
    $SRC/sqanti3_rescue.py
    rules
    # Rescue all isoform types
    --mode "full"
    # Reference genome and annotation
    --refGenome $ref_fa
    --refGTF $ref_gtf
    # QC'ed annotation
    --isoforms $qc_iso
    --refClassif $qc_class
    # Filtered annotation and rules
    --gtf $flt_gtf
    --json $json
    # Output settings
    --output $name
    --dir $sq_rec
    # Filtered classification
    $flt_class
)
echo "${cmd[@]}"
"${cmd[@]}"
