#!/bin/bash

work=/sietch_colab/data_share/balanus/balanus_crenatus/assemblies/20241003.hifiasm_0.19.8.s25_D10_hmc40_hgs800_dualScaff/purge_dups
alns=$work/alignments
geno=$work/in_genome/balCre_116172_ctgs.fasta
paf=$alns/64047_blaCre.merged.self.asm20.paf.gz
outd=$work/purge_dups.asm20
name=$outd/balCre.2c_Thc.D10_s25
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
