#!/bin/bash

taxdump=/sietch_colab/data_share/blobtools_database/taxdump
work=/sietch_colab/ariverac/balanus_genome/assemblies/20230817.3cell.hifiasm.def/blobtools
fasta=$work/in_genome/balGla.def.p_ctg.fasta
meta=$work/metadata/balGla.def.yaml
taxid=110520
blobdir=$work/balGla_def.BlobDir


cmd=(
    blobtools create
    --fasta $fasta
    --meta $meta
    --taxid $taxid
    --taxdump $taxdump
    $blobdir
)

echo "${cmd[@]}"
"${cmd[@]}"
