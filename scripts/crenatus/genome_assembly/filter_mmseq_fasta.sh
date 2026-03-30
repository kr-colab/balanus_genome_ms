#!/bin/bash
work=/sietch_colab/data_share/balanus/balanus_crenatus/assemblies/20241003.hifiasm_0.19.8.s25_D10_hmc40_hgs800_dualScaff/mmseqs2/filter_asm
cd $work

# Input FASTA (must be indexed)
in_fasta=$work/in_genome/balCre.hmc40_D10_s25.p_ctg.fasta

# Taxonomy output table from MMSeqs2
tsv=$work/balCre_tax.tsv

# NCBI taxonomy category for checking
tax=116172 # Thecostraca

# Filter the contig IDs in TSV to only include those matching the target ID
matches=$work/${tax}_ctgs.tsv
cat $tsv | grep "\b${tax}\b" | cut -f1 | sort -u > $matches

# Select the subset of matching sequences from the FASTA
out_fasta=$work/out_genome/balCre_${tax}_ctgs.fasta
samtools faidx --region-file $matches $in_fasta | \
    fold -w 60 > $out_fasta

# Index the resulting genome
samtools faidx $out_genome

