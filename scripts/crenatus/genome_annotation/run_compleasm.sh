#!/bin/bash

thr=8
lineage=/sietch_colab/ariverac/busco_lineages/busco_downloads/lineages
hmmsearch_path=/home/ariverac/local/mambaforge/envs/compleasm/bin/hmmsearch
lineages_path=/sietch_colab/ariverac/busco_lineages/busco_downloads/lineages
work=/sietch_colab/data_share/balanus/balanus_crenatus/annotation/lifton/20250226.lifton_f0.25_a0.25_s0.25_sc0.8_mpj1_asm20/20250328.PROCESSED/stats
fasta=$work/peptides.fa
outd=$work/balCre_annot.compleasm.arthropoda_odb10
mkdir -p $outd
cd $outd

cmd=(
    compleasm
    protein
    --protein $fasta
    --lineage arthropoda_odb10
    --thr $thr
    --outdir $outd
    --hmmsearch_execute_path $hmmsearch_path
    --library_path $lineages_path
)

# run command
echo "${cmd[@]}"
"${cmd[@]}"
