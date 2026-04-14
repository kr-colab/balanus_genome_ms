#!/bin/bash

work=/sietch_colab/ariverac/balanus_genome/assemblies/20240226.3cell_Thecostraca.hifiasm_0.19.8.s25_D10_ONT_HiC_hmc68_hgs800_dualScaff/hi-c
yahs_out=$work/yahs-scaffolding
outd=$work/contact-map

# Format the YaHS file to the required juicer format
bin=$yahs_out/balGla.3c_Thc.ONT_HiC_D10_s25.yahs.bin
agp=$yahs_out/balGla.3c_Thc.ONT_HiC_D10_s25.yahs_scaffolds_final.agp
fai=$work/genome/balGla.3c_Thc.ONT_HiC_D10_s25.purged.fa.fai
outb=$outd/balGla.3c_Thc.ONT_HiC_D10_s25.yahs_juicer
hicout=$outd/balGla.3c_Thc.ONT_HiC_D10_s25.yahs_juicer
# chrom_sizes=$yahs_out/balGla.Thecostraca_s45_ONT_yahs_scaffolds_final.chrs.tsv
chrom_sizes=${outb}.scaffolds_final.chrs.tsv

#
# PART1: Do a first pass of juicer to generate the base *.hic file
#
log=${outb}.juicer_pre.log

# Juicer pre to  make the juicer input
juicer pre $bin $agp $fai 2> $log | \
    LC_ALL=C sort -k2,2d -k6,6d -T $outd --parallel=8 -S32G | \
    awk 'NF' > ${outb}.part
mv ${outb}.part ${outb}.sorted.txt

# Get the adjusted chr sizes
cat $log | grep "PRE_C_SIZE" | cut -d' ' -f2- > $chrom_sizes

# Run the actual juicer tools
juicer_tools pre \
    ${outb}.sorted.txt \
    ${outb}.hic.part \
    $chrom_sizes
mv ${outb}.hic.part ${outb}.out.hic

#
# PART2: Do a second pass to generate the *.assembly file
#

# Prepare the juicer pre run with assembly (-a) mode
outf=${outb}.jbat
log=${outf}.log
juicer pre -a -o $outf $bin $agp $fai > $log 2>&1

# Extract the adjusted assembly size
asm_size=${outb}.assembly_size.tsv
cat $log | grep "PRE_C_SIZE" | cut -d' ' -f2- > $asm_size

# Rerun juicer_tools with the new files
juicer_tools pre ${outf}.txt ${outf}.hic.part $asm_size
mv ${outf}.hic.part ${outf}.hic
