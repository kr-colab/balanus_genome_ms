#!/bin/bash

THR=12
PRC=6

work=/sietch_colab/data_share/balanus/genome_annot/20240521.balGla.4c_Thc.hifiasm_s45_D10_ONT.tigmint.yahs
reads=$work/raw/m64047_231004_192515.ccs.fastq.gz
bam=$work/alignments/bamGla_isoseq.bam
genome=$work/in_genome/balGla.softmasked.fasta

minimap2 -t ${THR} -ax splice:hq -uf $genome $reads | \
    samtools view -bS -F4 --threads ${PRC} | \
    samtools sort --threads ${PRC} -o $bam

