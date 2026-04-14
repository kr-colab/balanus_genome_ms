#!/bin/bash

thr=24
work=/sietch_colab/ariverac/balanus_genome/assemblies/20230817.3cell.hifiasm.def/blobtools
reads=$work/in_reads/m64047_blaGla.merged.ccs.fastq.gz
fasta=$work/in_genome/balGla.def.p_ctg.fasta
alignments=$work/alignments/balGla.def.hifi_3cell.bam

# Align
minimap2 -x map-hifi -t $thr -a $fasta $reads | \
    samtools view -bh -@ $thr | \
    samtools sort -m 1G -@ $thr -o $alignments

# Index
cd $work/alignments
samtools index --csi --threads $thr $alignments

