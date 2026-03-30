#!/bin/bash

thr=8
lineage=/sietch_colab/ariverac/busco_lineages/busco_downloads/lineages
work=/sietch_colab/data_share/balanus/balanus_crenatus/assemblies/20241003.hifiasm_0.19.8.s25_D10_hmc40_hgs800_dualScaff/compleasm
fasta=$work/balCre.hmc40_D10_s25.p_ctg.fasta
outd=$work/balCre.compleasm.arthropoda_odb10
log=$outd/compleasm.log
mkdir -p $outd
cd $outd

cmd=(
    compleasm
    run
    --assembly_path $fasta
    #--autolineage
    --lineage arthropoda_odb10
    #--library_path $lineage
    --output_dir $outd
    --mode busco
    --threads $thr
)

# run command
echo "${cmd[@]}"
"${cmd[@]}" > $log 2>&1
