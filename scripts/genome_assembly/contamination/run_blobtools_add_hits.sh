#!/bin/bash

thr=8

work=/sietch_colab/ariverac/balanus_genome/assemblies/20230817.3cell.hifiasm.def/blobtools
taxdump=/sietch_colab/data_share/blobtools_database/taxdump
blobdir=${work}/balGla_def.BlobDir
blast=${work}/blasts/blast_balGla.def_nt.tsv.gz

cmd=(
    blobtools add
    --hits $blast
    --taxdump $taxdump
    --taxrule bestsumorder
    --threads $thr
    $blobdir
)

echo "${cmd[@]}"
"${cmd[@]}"
