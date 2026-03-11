#!/bin/bash

# Put bash in strict mode
set -e
set -o pipefail

THR=16
PRC=$((${THR}/4))

# Set up the SOURCE
# Needed for things being in the PATH or not
SRC=/home/ariverac/local/opt/SQANTI3-5.2.2
export PYTHONPATH="$PYTHONPATH:${SRC}/utilities/cupcake/sequence"
export PYTHONPATH="$PYTHONPATH:${SRC}/utilities/cupcake"
export PATH="${SRC}:$PATH"
# cd $SRC

# Main working directory
work=/sietch_colab/data_share/balanus/genome_annot/braker_annotation/SQANTI3

# Reference annotation and genome
# genome=$work/in_annotation/BalGla_tigmint_breaktg_v2.fasta
# ref_annot=$work/in_annotation/braker_transdecoder.gff3
genome=$work/in_annotation/BalGla_tigmint_breaktg_v2.corr.fasta
#ref_annot=$work/in_annotation/braker_transdecoder.corr.gff3
ref_annot=$work/in_annotation/braker_transdecoder.corr.gtf

# Isoform annotation
# isoforms=$work/in_isoforms/isoforms.gtf
isoforms=$work/in_isoforms/isoforms.corr.gtf

# Short read data
# The input files is a file of file names with all the paths to the short reads
short_reads=$work/in_rnaseq/read_paths.fofn

# Outputs
outd=$(date +$work/%Y%m%d.SQANTI3_out)
mkdir -p $outd
# outd=$work/20241205.SQANTI3_out
name=BalGla_BKR_TRD_SQN

# Prepare command and run
cmd=(
    $SRC/sqanti3_qc.py
    --force_id_ignore # Since it was not processed using IsoSeq3, IDs will be different.
    --cpus $THR
    # --chunks $PRC
    --isoAnnotLite
    --isoform_hits
    --aligner_choice minimap2
    --output $name
    --dir $outd
    --short_reads $short_reads
    $isoforms
    $ref_annot
    $genome
)
echo "${cmd[@]}"
"${cmd[@]}"
