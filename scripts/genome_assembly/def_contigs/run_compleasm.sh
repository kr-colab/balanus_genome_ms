#!/bin/bash

thr=8
work=/sietch_colab/ariverac/balanus_genome/assemblies/20230817.3cell.hifiasm.def/compleasm
fasta=$work/balGla.def.p_ctg.fasta
outd=$work/balGla.def_compleasm.arthropoda_odb10
log=$outd/compleasm.log
mkdir -p $outd
cd $outd

cmd=(
    compleasm
    run
    --assembly_path $fasta
    #--autolineage
    --lineage arthropoda_odb10
    --output_dir $outd
    --mode busco
    --threads $thr
)

# run command
echo "${cmd[@]}"
"${cmd[@]}" > $log 2>&1
