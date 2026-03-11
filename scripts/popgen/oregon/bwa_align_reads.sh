#!/bin/bash

set -e
set -o pipefail
THR=48
NPR=$(($THR/4))

# General paths
work=/sietch_colab/data_share/balanus/popgen/202503-analysis
reads=$work/trimmed_reads/illumina
align=$work/alignments
samples=$work/info/wgs-samples.txt
db=$work/ref_genome/BalGla
fa=$work/ref_genome/BalGla.fa

# Function to align and process reads
align_and_process () {
    # Set up the inputs and outputs
    sample="$1"
    fq1=$reads/${sample}.r1.fq.gz
    fq2=$reads/${sample}.r2.fq.gz
    bam1=$align/${sample}.bam.tmp1
    bam2=$align/${sample}.bam.tmp2
    bam3=$align/${sample}.bam.tmp3
    bam4=$align/${sample}.bam
    stats=$align/${sample}.aln_stats.tsv
    dups=$align/${sample}.dup_stats.tsv
    
    # Report
    echo "Working on ${sample}..."

    # Construct read group info
    rg="@RG\tID:${sample}\tSM:${sample}\tPL:Illumina\tPU:NovaSeq"

    # Align
    bwa mem -t $THR -R $rg $db $fq1 $fq2 | \
        samtools view -b -h -@ $THR | \
        samtools sort -@ $THR -o $bam1

    # Mark duplicates
    picard MarkDuplicates \
        --INPUT $bam1 --OUTPUT $bam2 \
        --METRICS_FILE $dups

    # Left align indels
    gatk LeftAlignIndels \
        -R ${fa} -I $bam2 -O $bam3

    # Get stats
    samtools flagstat --threads $THR \
        --output-fmt tsv $bam3 > $stats

    # Apply basic filters (for size, mainly)
    # -F (remove) 4=unmapped, 256=secondary,
    #    1024=PCRdup, 2048=supplementary
    # -q 30 is min mapping quality of 30
    samtools view -b -h -@ $NPR \
        -q 30 -F 4 -F 256 -F 1024 -F 2048 $bam3 | \
        samtools sort -@ $NPR -o $bam4

    # Index
    samtools index --threads $THR $bam3

    # Remove the temporary bams
    rm $bam1 $bam2 $bam3
}

# Loop over the samples and process
cat $samples | grep -v '^#' |
while read sample; do
    # echo $sample
    align_and_process $sample
done
