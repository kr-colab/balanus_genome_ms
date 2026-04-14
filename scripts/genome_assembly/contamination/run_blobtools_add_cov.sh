#!/bin/bash

thr=8

work=/sietch_colab/ariverac/balanus_genome/assemblies/20230817.3cell.hifiasm.def/blobtools
blobdir=${work}/balGla_def.BlobDir
bam=${work}/alignments/balGla.def.hifi_3cell.bam

cmd=(
    blobtools add
    --cov ${bam}
    --cov "${bam}=def_3cell"
    --threads $thr
    $blobdir
)

echo "${cmd[@]}"
"${cmd[@]}"
