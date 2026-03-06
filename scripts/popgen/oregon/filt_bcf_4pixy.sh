#!/bin/bash
set -e
set -o pipefail
THR=8
NPR=4

# General paths
work=/sietch_colab/data_share/balanus/popgen/202503-analysis
scaffs=$work/ref_genome/scaff_list_1mb.txt
raw_dir=$work/genotyping/normalized
repeats=$work/ref_genome/BalGla.repeats.bed

# Parameters for output
qual=30
dp=10
gq=30
types=snp
ratio=0.3
miss=0.5

# Create a new output directory
out_dir=$work/genotyping/filt_Q${qual}_FMTDP${dp}_GQ${gq}_t${types}_fm${miss}_noReps_4pixy
mkdir -p $out_dir

# Final bgzipped VCF with all variants
outvcf=$out_dir/Bgland_all.filtered.vcf.gz

# File with all the BCF ids for merging
bcfs_f=$out_dir/bcf_list.txt
> $bcfs_f

# Quick check for the filtering types
if [ $types == 'all' ]; then
    types='snps,indels,mnps'
fi

# Loop over the desired sequences and run
cat $scaffs | grep -v '^#' | #head -n3 |
while read scaff; do
    # Set the inputs/outputs for that sequence
    inbcf=$raw_dir/Bgland_${scaff}.norm.bcf
    outbcf=$out_dir/Bgland_${scaff}.soft-flt.bcf

    # Add to the BCF list
    echo $outbcf >> $bcfs_f

    # Subset the bed to extract the repeats of that chromosome
    chr_bed=$out_dir/${scaff}.repeats.tsv
    cat $repeats | grep -w "^${scaff}\b" | awk '{print $1, $2+1, $3}' | tr ' ' '\t' > $chr_bed

    # Run Bcftools
    bcftools filter \
            -Ou \
            --threads $NPR \
            --soft-filter "LowQual" \
            --SnpGap 3 \
            --IndelGap 5 \
            --exclude "QUAL<${qual}" \
            $inbcf | \
        bcftools filter \
            -Ou \
            --set-GTs '.' \
            --exclude "FORMAT/DP<${dp} | FORMAT/GQ<${gq} | (GT=='het') & %MAX(FMT/AD)/(FMT/DP)<${ratio}" | \
        bcftools filter \
            -Ou \
            --soft-filter "NonSnpVariant" \
            --exclude "TYPE='indel' | TYPE='mnp'" | \
        bcftools filter \
            -Ou \
            --soft-filter "HighMissing" \
            --exclude "F_MISSING>=${miss}" | \
        bcftools filter \
            -Ou \
            --soft-filter "NonAccessible" \
            --mask-file $chr_bed | \
        bcftools view \
            --threads $NPR \
            --trim-alt-alleles \
            --exclude-uncalled \
            --output-type b \
            --output $outbcf
    # Index the new BCF
    bcftools index --threads $NPR $outbcf
    # Remove the repeats intervals file
    rm $chr_bed
done

# Concatenate the bcfs
# Filter based on the soft-filters applied
# Remove all missing data
# Compress
bcftools concat \
        --output-type u \
        --file-list $bcfs_f \
        --threads $NPR \
        --allow-overlaps \
        --remove-duplicates | \
    bcftools view \
        -g ^miss \
        --apply-filters "PASS" \
        --threads $NPR \
        --output-type v | \
    bgzip -c > $outvcf
# Index the VCF
tabix $outvcf

# Remove the list
rm $bcfs_f
