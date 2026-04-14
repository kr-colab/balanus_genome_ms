#!/bin/bash

thr=24
work=/sietch_colab/ariverac/balanus_genome/assemblies/20240226.3cell_Thecostraca.hifiasm_0.19.8.s25_D10_ONT_HiC_hmc68_hgs800_dualScaff/hi-c/20250129.curation/inspector
fasta=$work/balGla.3c_Thc.ONT_HiC_D10_s25.yahs_juicer.curated_v2.FINAL.fa

# Input reads
hifi=/sietch_colab/ariverac/balanus_genome/data/hifi/cleaned_reads/m64047_blaGla.merged.ccs.filtered_class-Thecostraca.fastq.gz

# Make output dir
outdir=$(date +$work/%Y%m%d.inspector_hifi_r2/)
mkdir -p $outdir

cmd=(
    inspector.py
    --contig $fasta
    --read $hifi
    --thread $thr
    --outpath $outdir
    --datatype "hifi"
)
#echo "${cmd[@]}"
#"${cmd[@]}"

# Inspector correct
cordir=$outdir/correct_out
mkdir -p $cordir

cmd=(
    inspector-correct.py
    --inspector $outdir
    --outpath $cordir
    --datatype "pacbio-hifi"
    --thread $thr
)
echo "${cmd[@]}"
"${cmd[@]}"
