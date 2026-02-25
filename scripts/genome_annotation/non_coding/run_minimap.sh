#!/bin/bash

THR=24
NPR=6

work=/sietch_colab/data_share/balanus/genome_annot/non_coding
reads=$work/in_reads/m64047_231004_192515.ccs.fastq.gz
reference=$work/in_genome/BalGla.fa
bam=$work/alignments/m64047_231004_192515.ccs.bam

minimap2 -t ${THR} -ax splice:hq -uf $reference $reads | \
    samtools view -bhS -F4 --threads ${NPR} | \
    samtools sort --threads ${NPR} -o $bam

