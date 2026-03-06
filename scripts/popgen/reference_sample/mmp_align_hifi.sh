#!/bin/bash

set -e
set -o pipefail
THR=24
NPR=$(($THR/4))

# General paths
work=/sietch_colab/data_share/balanus/popgen/202503-analysis
# BalGla hifi reads (for testing)
hifi=/sietch_colab/data_share/balanus/hifi/merged_reads/m64047_blaGla.merged.ccs.fastq.gz
# Alignments
align=$work/alignments
# Genome
db=$work/ref_genome/BalGla
fa=$work/ref_genome/BalGla.fa
# basename of outputs
name=Bgland_00
rg="@RG\tID:${name}\tSM:${name}\tPL:PACBIO\tPU:HiFi"
echo $rg

# Outputs
preset=map-hifi
bam=$align/${name}.${preset}.bam
stats=$align/${name}.${preset}.aln_stats.tsv
out=$align/${name}.${preset}.dp_stats

# Align
minimap2 -a -x $preset -t $THR -R $rg $fa $hifi | \
    samtools view -b -h -@ $THR | \
    samtools sort -@ $THR -o $bam

# Get stats
samtools flagstat --threads $THR \
    --output-fmt tsv $bam > $stats

# Index
samtools index --threads $THR $bam

# Calculate depth stats
mosdepth --threads $THR \
    --fasta $fa --no-per-base \
    --by 10000 --flag 3844 \
    --thresholds "1,3,5,10,20" \
    $out $bam
