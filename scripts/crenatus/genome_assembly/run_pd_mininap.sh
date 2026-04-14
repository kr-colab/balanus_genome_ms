#!/bin/bash

work=/sietch_colab/data_share/balanus/balanus_crenatus/assemblies/20241003.hifiasm_0.19.8.s25_D10_hmc40_hgs800_dualScaff/purge_dups
alns_out=$work/alignments
genome=$work/in_genome/balCre_116172_ctgs.fasta
reads=/sietch_colab/data_share/balanus/balanus_crenatus/hifi_reads/read_links/m64047_balCre.merged.ccs.fastq.gz
paf=$alns_out/m64047_blaCre.merged.ccs.paf.gz
split=$alns_out/64047_blaCre.merged.split
self=$alns_out/64047_blaCre.merged.self.asm20.paf.gz

cd $alns_out

# Align the reads to the reference
minimap2 -x map-hifi -t 16 $genome $reads | gzip -c - > $paf

# Calculate read-depth histogram
pbcstat -O $alns_out $paf

# Calculate base-level depth
calcuts PB.stat > cutoffs 2>calcults.log

# Do an assembly self-alignment
split_fa $genome > $split
minimap2 -x asm20 -t 16 -DP $split $split | gzip -c - > $self
#minimap2 -x asm10 -t 16 -DP $split $split | gzip -c - > $self
#minimap2 -x asm5 -t 16 -DP $split $split | gzip -c - > $self
