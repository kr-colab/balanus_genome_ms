#!/bin/bash

THR=16
work=/sietch_colab/data_share/balanus/popgen/202503-analysis/pixy_stats
invcf=$work/in_vcfs/Bgland_all.filtered.vcf.gz
# sites=$work/in_vcfs/Bgland_all.filtered.sites.tsv
popmap=$work/info/popmap.tsv

window_size=5000
prefix="BalGla_gwide_${window_size}"

# Generate output dir
outdir=$(date +$work/%Y%m%d.pixy.${window_size})
mkdir -p $outdir

# Pixy command
cmd=(
    pixy
    --stats pi
    # tajima_d watterson_theta
    --vcf $invcf
    --populations $popmap
    --window_size ${window_size}
    # --sites_file $sites
    --n_cores $THR
    --output_folder $outdir
    --output_prefix $prefix
    --include_multiallelic_snps
)
echo "${cmd[@]}"
"${cmd[@]}"
