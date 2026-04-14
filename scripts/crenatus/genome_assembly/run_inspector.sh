#!/bin/bash

thr=24

work=/sietch_colab/data_share/balanus/balanus_crenatus/assemblies/20241003.hifiasm_0.19.8.s25_D10_hmc40_hgs800_dualScaff/inspector_1
fasta=$work/in/balCre.2c_Thc.D10_s25.purged.fa

# Make output dir
outdir=$(date +$work/%Y%m%d.inspector_hifi/)
mkdir -p $outdir

# Input reads to test
hifi=/sietch_colab/data_share/balanus/balanus_crenatus/hifi_reads/read_links/m64047_balCre.merged.ccs.fastq.gz

cmd=(
    inspector.py
    --contig $fasta
    --read $hifi
    --thread $thr
    --outpath $outdir
    --datatype "hifi"
)
echo "${cmd[@]}"
"${cmd[@]}"

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
