#!/bin/bash

THR=4
work=/sietch_colab/data_share/balanus/comp_genomics/allozymes/pi
invcf=$work/in_vcf/allozymes.vcf.gz
popmap=$work/info/popmap.tsv
sites=$work/in_vcf/allozyme_sites.tsv

window_size=1
prefix=allozymes

# Generate output dir
outdir=$(date +$work/%Y%m%d.BalGla_allozymes)
mkdir -p $outdir

# Pixy command
cmd=(
    pixy
    --stats pi
    --vcf $invcf
    --populations $popmap
    --window_size ${window_size}
    --sites_file $sites
    --n_cores $THR
    --output_folder $outdir
    --output_prefix $prefix
    --include_multiallelic_snps
)
echo "${cmd[@]}"
"${cmd[@]}"
