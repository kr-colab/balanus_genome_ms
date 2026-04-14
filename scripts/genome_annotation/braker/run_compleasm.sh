#!/bin/bash

thr=8
lineage=/sietch_colab/ariverac/busco_lineages/busco_downloads/lineages
hmmsearch_path=/home/ariverac/local/mambaforge/envs/compleasm/bin/hmmsearch
lineages_path=/sietch_colab/ariverac/busco_lineages/busco_downloads/lineages

work=/sietch_colab/data_share/balanus/genome_annot/20240521.balGla.4c_Thc.hifiasm_s45_D10_ONT.tigmint.yahs/braker/20240613.braker3_rnaseq_arthropoda_odb11.masked/stats
fasta=$work/../braker.aa
outd=$work/balGla_annot.compleasm.arthropoda_odb10
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

