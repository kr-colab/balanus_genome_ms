#!/bin/bash

work=/sietch_colab/ariverac/balanus_genome/assemblies/20240226.3cell_Thecostraca.hifiasm_0.19.8.s25_D10_ONT_HiC_hmc68_hgs800_dualScaff/purge_dups
alns=$work/alignments
geno=$work/in_genome/balGla.3c_Thc.ONT_HiC_D10_s25.p_ctg.filtered_class-Thecostraca.fasta
paf=$alns/64047_blaGla.merged.self.asm5.paf.gz
outd=$work/purge_dups.asm5
name=$outd/balGla.3c_Thc.ONT_HiC_D10_s25
mkdir -p $outd
cd $outd

# Mark the duplicates in a bed file
cmd=(
    purge_dups
    -2
    -T $alns/cutoffs
    -c $alns/PB.base.cov
    $paf
)
echo "${cmd[@]}"
"${cmd[@]}" > dups.bed 2> purge_dups.log


# Process the assembly
cmd=(
    get_seqs
    -e
    -s
    -p $name
    dups.bed
    $geno
)
echo "${cmd[@]}"
"${cmd[@]}" > get_seqs.log 2>&1
