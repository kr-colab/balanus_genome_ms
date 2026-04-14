#!/bin/bash

#
# Align and process Hi-C reads
# Taken from: https://omni-c.readthedocs.io/en/latest/fastq_to_bam.html
#

timestamp=$(date +%F_%T)
echo "Started on $timestamp"

thr=36 # Threads
npr=$(($thr/2))

# Hi-C working directory
work=/sietch_colab/ariverac/balanus_genome/assemblies/20240226.3cell_Thecostraca.hifiasm_0.19.8.s25_D10_ONT_HiC_hmc68_hgs800_dualScaff/hi-c

# Basename of files
name=balGla_hic.GC3F-SS-8331-7549_S1

# Hi-C reads input
reads=$work/hic-reads
r1=$reads/${name}.1.fq.gz
r2=$reads/${name}.2.fq.gz

# Reference genome info
ref=$work/genome/balGla.3c_Thc.ONT_HiC_D10_s25.purged
fasta=${ref}.fa
db=${ref}.db
geno=${ref}.genome.tsv

# Index the reference genome
echo "Indexing reference..."
bwa index -p $db $fasta

# Align and and store the "base" alignment
# They don't do this in the official docs, but I am keeping here as a temp stop.
base_bam=$work/hic-alns/${name}.base.bam

#echo "Aligning reads..."
bwa mem -5SP -T0 -t $thr $db $r1 $r2 | \
    samtools view -bh -@ $thr -o $base_bam

# Process the alignment pairs
echo "Processing alignment pairs..."
# Prepare temp dirs
tmp=$(date +$work/hic-alns/%y%m%d.tmp)
mkdir -p $tmp
# Library Dup stats
dups=$work/hic-alns/${name}.dups.stats
# Read pairs
pairs=$work/hic-alns/${name}.pairs.gz
# Main output
proc_bam=$work/hic-alns/${name}.processed.bam

samtools view -h $base_bam | \
    pairtools parse --min-mapq 40 --walks-policy 5unique --max-inter-align-gap 30 \
        --nproc-in $npr --nproc-out $npr --chroms-path $geno | \
    pairtools sort --tmpdir $tmp --nproc $npr | \
    pairtools dedup --nproc-in $npr --nproc-out $npr --mark-dups --output-stats $dups | \
    pairtools split --nproc-in $npr --nproc-out $npr --output-pairs $pairs --output-sam - | \
    samtools view -bS -@ $npr | \
    samtools sort -@ $npr -o $proc_bam

# Index the final bam
echo "Indexing BAM..."
samtools index -@ $thr $proc_bam

timestamp=$(date +%F_%T)
echo "Finished on $timestamp"
