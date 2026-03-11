#!/bin/bash

THR=8
NPR=6
work=/sietch_colab/data_share/balanus/popgen/202503-analysis/pixy_stats
invcf=$work/in_vcfs/Bgland_all.filtered_noMiss.vcf.gz
sites=$work/in_vcfs/Bgland_all.filtered_noMiss.sites.tsv
info=$work/info
popmap=$info/popmap.tsv

# Generate output dir
outdir=$(date +$work/%Y%m%d.pixy.featuresBED)
mkdir -p $outdir

stats=(
    pi
    tajima_d
    watterson_theta
)

features=(
    # cds
    # intron
    # 5utr
    # 3utr
    # intergenic
    # lncrna
    # rrna
    # trna
    gwide
)

# Loop over the stats to run
for stat in "${stats[@]}"; do
    # Loop over the features
    for feature in "${features[@]}"; do
        # Select the target BED file
        bed=$info/${feature}.bed
        # Output prefix
        outprefix=BalGla_${feature}
        # Pixy command
        cmd=(
            pixy
            --stats $stat
            --vcf $invcf
            --populations $popmap
            --bed_file $bed
            --n_cores $THR
            --sites_file $sites
            --output_folder $outdir
            --output_prefix $outprefix
            --include_multiallelic_snps
        )
        echo "${cmd[@]}"
    done
done | parallel -j $NPR
