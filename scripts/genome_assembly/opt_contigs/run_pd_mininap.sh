#!/bin/bash

work=/sietch_colab/ariverac/balanus_genome/assemblies/20240226.3cell_Thecostraca.hifiasm_0.19.8.s25_D10_ONT_HiC_hmc68_hgs800_dualScaff/purge_dups
alns_out=$work/alignments
genome=$work/in_genome/balGla.3c_Thc.ONT_HiC_D10_s25.p_ctg.filtered_class-Thecostraca.fasta
reads=/sietch_colab/ariverac/balanus_genome/data/hifi/cleaned_reads/m64047_blaGla.merged.ccs.filtered_class-Thecostraca.fastq.gz
paf=$alns_out/m64047_blaGla.merged.ccs.paf.gz
split=$alns_out/64047_blaGla.merged.split
self=$alns_out/64047_blaGla.merged.self.asm5.paf.gz

cd $alns_out

# Align the reads to the reference
minimap2 -x map-hifi -t 16 $genome $reads | gzip -c - > $paf

# Calculate read-depth histogram
pbcstat -O $alns_out $paf

# Calculate base-level depth
calcuts PB.stat > cutoffs 2>calcults.log

# Do an assembly self-alignment
split_fa $genome > $split
minimap2 -x asm5 -t 16 -DP $split $split | gzip -c - > $self
