#!/bin/bash

work=/sietch_colab/data_share/balanus/comp_genomics/whole_genome_alignments/BalanusAlignments/cactus_alignment
seqfile=$work/balanus.seqFile
hal=$work/balanus.hal
js=$work/balanus_aln.js

if [ -d $js ]; then
  echo "$js exists, removing it."
  rm -r $js
fi

cmd=(
    cactus
    --workDir $work
    $js
    $seqfile
    $hal
)
echo "${cmd[@]}"
"${cmd[@]}"
