#!/bin/bash

set -e
set -o pipefail
thr=12

work=/sietch_colab/data_share/balanus/genome_annot/20240521.balGla.4c_Thc.hifiasm_s45_D10_ONT.tigmint.yahs/alignments
bam1=$work/Balanus-mRNA_S1_L001.bam
bam2=$work/Balanus-mRNA_S1_L002.bam
bam3=$work/Balanus-mRNA_S1.L1_L2.merged.bam.tmp
bam4=$work/Balanus-mRNA_S1.L1_L2.merged.bam

cd $work

# Merge the BAMs into a temporary bam file
samtools merge --threads $thr -o $bam3 $bam1 $bam2

# Filter into the final merged BAM
# view uses sam flags:
# -F (remove) 4=unmapped, 256=secondary, 2048=supplementary
# -q 30 is min mapping quality of 30
samtools view -bh --threads $thr -q 30 -F 4 -F 256 -F 2048 $bam3 | \
    samtools sort --threads $thr -o $bam4

# Get stats
samtools index $bam4
samtools flagstat $bam4 > $work/Balanus-mRNA_S1.L1_L2.merged.stats.tsv

# Remove tmp BAM
rm $bam3
