#!/bin/bash

# Master directory
work=/sietch_colab/data_share/balanus/popgen/202503-analysis/genotyping/ref_indv/snpeff
cd $work

invcf=./in_variants/Bgland_all.varSites.vcf.gz
dbdir=./BalGla
config=./snpEff.config
outstats=./Bgland_all.snpEff_stats.csv
outvcf=./Bgland_all.varSites.snpEff_annotated.vcf

# Run snpEff
cmd=(
    snpEff
    eff
    -verbose
    -csvStats $outstats
    BalGla
    $invcf
)
echo "${cmd[@]}"
"${cmd[@]}" > $outvcf

# Compress the output
bgzip $outvcf
