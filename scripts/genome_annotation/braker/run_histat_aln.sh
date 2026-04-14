#!/bin/bash

set -e
set -o pipefail
thr=16
npr=$(($thr/4))

work=/sietch_colab/data_share/balanus/genome_annot/20240521.balGla.4c_Thc.hifiasm_s45_D10_ONT.tigmint.yahs
index=$work/in_genome/balGla.softmasked.idx
reads=$work/processed
alns=$work/alignments

# RNA seq sample lists
sams=(
    Balanus-mRNA_S1_L001
    Balanus-mRNA_S1_L002
)

# Loop over samples and process
for sam in "${sams[@]}" ; do
    echo "Working on ${sam}"
    # Prepare files
    fq1=$reads/${sam}.1.fq.gz
    fq2=$reads/${sam}.2.fq.gz
    bam=$alns/${sam}.bam
    # Align and process alignments
    hisat2 --threads $thr -x $index --dta -1 $fq1 -2 $fq2 | \
        samtools view -h -b | \
        samtools sort --threads $npr -o $bam
    # Index alns and get stats
    samtools index --threads $thr $bam
    samtools flagstat --threads $thr \
        --output-fmt tsv $bam > $alns/${sam}.stats.tsv
done

