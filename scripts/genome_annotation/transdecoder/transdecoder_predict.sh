#!/bin/bash

# Put bash in strict mode
set -e
set -o pipefail

# Main working directory
work=/sietch_colab/data_share/balanus/genome_annot/braker_annotation/SQANTI3/20241207.SQANTI3_out/transdecoder_processing

# Input genome and annotation
in_gtf=$work/in/BalGla_BKR_TRD_SQN_rescued.gtf
in_fa=$work/in/BalGla_tigmint_breaktg_v2.corr.fasta

# Transdecoding analysis directory and outputs
transd=$work/transdecoder
transd_cds=$transd/BalGla.transdecoder.cds.fa
transd_gff=$transd/BalGla.transdecoder.gff

# Homology data
blast=$transd/homology/blastp.BalGla_UniprotSprot.tsv
hmmer=$transd/homology/hmmsearch.BalGla_PfamA.domtblout

# Transdecoder.Predict output
predict_out=$transd/BalGla.transdecoder.cds.fa.transdecoder

# Processed outputs
out_gff=$transd/BalGla.transdecoder.out.gff3

cd $transd

# Run the final predictions including the homology data
cmd=(
    TransDecoder.Predict
    -t $transd_cds
    --retain_pfam_hits $hmmer
    --retain_blastp_hits $blast
    --single_best_only
)
echo "${cmd[@]}"
"${cmd[@]}"

# Convert from transcript-specific to genome-specific coordinates
src=/home/ariverac/local/mambaforge/envs/rnaseq_annot/opt/transdecoder/util

cmd=(
    $src/cdna_alignment_orf_to_genome_orf.pl
    ${predict_out}.gff3
    $transd_gff
    $transd_cds
)
echo "${cmd[@]}"
"${cmd[@]}" > $out_gff

