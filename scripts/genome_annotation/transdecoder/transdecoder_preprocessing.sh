#!/bin/bash

# Put bash in strict mode
set -e
set -o pipefail

work=/sietch_colab/data_share/balanus/genome_annot/braker_annotation/SQANTI3/20241207.SQANTI3_out/transdecoder_processing
in_gtf=$work/in/BalGla_BKR_TRD_SQN_rescued.gtf
in_fa=$work/in/BalGla_tigmint_breaktg_v2.corr.fasta

# Use transdecoder to generate the transcripts from the annotation
src=/home/ariverac/local/mambaforge/envs/rnaseq_annot/opt/transdecoder/util
out_dir=$work/transdecoder
out_cds=$out_dir/BalGla.transdecoder.cds.fa
out_gff=$out_dir/BalGla.transdecoder.gff
cd $out_dir

# Extract coding sequences from FASTA based on GTF coordinates
$src/gtf_genome_to_cdna_fasta.pl $in_gtf $in_fa > $out_cds

# Generate a matches GFF from the coding sequences
$src/gtf_to_alignment_gff3.pl $in_gtf > $out_gff

# Extract the longest isoforms to generate the genes
TransDecoder.LongOrfs -t $out_cds
