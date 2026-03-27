#!/bin/bash

work=/sietch_colab/ariverac/balanus_genome/assemblies/20240226.3cell_Thecostraca.hifiasm_0.19.8.s25_D10_ONT_HiC_hmc68_hgs800_dualScaff
hifidir=/sietch_colab/ariverac/balanus_genome/data/hifi/cleaned_reads
outdir=$work/hifiasm_out
name=$outdir/balGla.3c_Thc.ONT_HiC_D10_s25
log=$outdir/hifiasm.log
mkdir -p $outdir

# Nanopore Ultralong reads
ul=/sietch_colab/data_share/balanus/ONT/cleaned_reads/balGla_Thecostraca.ONT.merged.fastq.gz
# Hi-C data
hicdir=/sietch_colab/ariverac/balanus_genome/data/hi-c/processed
hc1=$hicdir/balGla_hic.GC3F-SS-8331-7549_S1.1.fq.gz
hc2=$hicdir/balGla_hic.GC3F-SS-8331-7549_S1.2.fq.gz

# Main hifiasm command
cmd=(
    hifiasm
    -o $name
    -t 36
    -s 0.25
    --hom-cov 68
    --hg-size 800m
    --dual-scaf
    --purge-max 68
    -D 10.0
    --ul $ul
    --h1 $hc1
    --h2 $hc2
    $hifidir/m64047_blaGla.merged.ccs.filtered_class-Thecostraca.fastq.gz
)

echo "${cmd[@]}"
"${cmd[@]}" > $log 2>&1


# Convert the GFA to fasta
cat ${name}.hic.p_ctg.gfa | awk '/^S/{print ">"$2;print $3}' | \
    gzip > ${name}.p_ctg.fasta.gz

# Make other useful dirs
mkdir -p quast busco compleasm
