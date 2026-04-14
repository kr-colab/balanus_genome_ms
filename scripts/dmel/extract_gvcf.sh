#!/bin/bash

NPR=4

WORK=/sietch_colab/data_share/balanus/popgen/20260121.dmel_pi_comparison/process_dpgp2

# Chromosomes to process
CHRS=(
    Chr2L
    Chr2R
    Chr3L
    Chr3R
    ChrX
)

# Path to input multispecies FASTA
FASTA_DIR=$WORK/multifasta

# Path to output all-sites VCF
VCF_DIR=$WORK/vcf_output

# First, extract the sequences into raw VCFs.
for chr in "${CHRS[@]}"; do
    # Inputs and outputs
    fasta=$FASTA_DIR/dpgp2_${chr}_all_samples.fasta
    vcf=$VCF_DIR/dpgp2_${chr}_all_sites.raw.vcf.gz
    cmd=(
        snp-sites
        -v
        -b
        $fasta
    )
    echo "${cmd[@]} | bgzip -c > $vcf"
done | parallel -j $NPR

# Then, do some light prpcessing
for chr in "${CHRS[@]}"; do
    # Inputs and outputs
    in_vcf=$VCF_DIR/dpgp2_${chr}_all_sites.raw.vcf.gz
    out_vcf=$VCF_DIR/dpgp2_${chr}_all_sites.vcf.gz

    # First, create a new chromosome map file
    chr_map=$VCF_DIR/${chr}.namemap.tsv
    echo -e "1\t${chr}" > $chr_map

    # Rename chromosome, remove sites with Ns as REF
    bcftools view -Ou -e 'REF="N"' $in_vcf | \
        bcftools annotate -Ou --rename-chrs $chr_map | \
        bcftools view -Ov | \
        bgzip -c > $out_vcf

    # Index
    tabix $out_vcf
    rm $chr_map
done


