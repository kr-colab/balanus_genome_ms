#!/bin/bash

THR=8
NPR=4

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
SAMPLES=$work/info/popmap_RG.tsv

# Directory of VCFs
VCFS=$work/in_data

# Output directory
OUT_DIR=$work/pixy_out

# Window size for calculations
WINDOW=10000

# Loop over the chromosomes
for chr in "${CHRS[@]}"; do
   # Inputs and outputs
   vcf=$VCFS/dpgp2_${chr}_all_sites.RG.vcf.gz
   name=dpgp2_${chr}.RG_${WINDOW}

   cmd=(
       pixy
       --stats pi
       --vcf $vcf
       --populations $SAMPLES
       --window_size $WINDOW
       --n_cores $THR
       --output_folder $OUT_DIR
       --output_prefix $name
       --chromosomes $chr
       --include_multiallelic_snps
       --bypass_invariant_check
   )
   echo "${cmd[@]}"
done | parallel -j $NPR

