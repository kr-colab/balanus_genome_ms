#!/bin/bash

# Set BCFTOOLS_PLUGINS environment variable for plugin access
# export BCFTOOLS_PLUGINS=/home/ariverac/local/opt/bcftools-1.18/plugins

work=/sietch_colab/data_share/balanus/popgen/20260121.dmel_pi_comparison

# Chromosomes to process
CHRS=(
    Chr2L
    Chr2R
    Chr3L
    Chr3R
    ChrX
)

# Samples to process
SAMPLES=$work/info/samples_RG.tsv

# Directory of input VCFs
IN_VCFS=$work/process_dpgp2/vcf_output/

# Directory of output VCFs
OUT_VCFS=$work/in_data

# Loop over the chromosomes
for chr in "${CHRS[@]}"; do
    # General inputs and outputs
    in_vcf=$IN_VCFS/dpgp2_${chr}_all_sites.vcf.gz
    out_vcf=$OUT_VCFS/dpgp2_${chr}_all_sites.RG.vcf.gz

    # Process the input VCF with BCFtools
    # bcftools view -S $SAMPLES $in_vcf | \
    #     bcftools +setGT -- -t q -n . -i 'ALT="*"' | \
    #     bcftools +fill-AN-AC | \
    #     bcftools view --trim-alt-alleles -Ou | \
    #     bcftools view --exclude 'F_MISSING > 0.1' -Ov | \
    #     bgzip -c > $out_vcf

    bcftools view -S $SAMPLES $in_vcf | \
        $work/scripts/recode_deletions.awk | 
        bcftools +fill-AN-AC | \
        bcftools view --trim-alt-alleles -Ou | \
        bcftools view --exclude 'F_MISSING >= 0.25' -Ov | \
        bgzip -c > $out_vcf

    # Index
    tabix $out_vcf

done
