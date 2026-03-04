#!/bin/bash

work=/sietch_colab/data_share/balanus/comp_genomics/mk_test/mikado
msas=$work/msas
outdir=$(date +$work/%y%m%d.mkado)
mkdir -p $outdir
cd $outdir

cmd=(
    mkado
    batch
    $msas
    --volcano volcano.pdf
    --workers 4
    --ingroup-match "Bgland"
    --outgroup-match "Bcrena"
)

echo "${cmd[@]}"
"${cmd[@]}" > $outdir/mkado_mkTest.out.tsv


cmd=(
    mkado
    batch
    $msas
    --workers 4
    --asymptotic
    --bins 10
    --plot-asymptotic asymptotic_mk.pdf
    --ingroup-match "Bgland"
    --outgroup-match "Bcrena"
)

echo "${cmd[@]}"
"${cmd[@]}" > $outdir/mkado_asymptotic.out.tsv


cmd=(
    mkado
    batch
    $msas
    --workers 4
    --alpha-tg
    # --no-singletons
    # --bootstrap
    --ingroup-match "Bgland"
    --outgroup-match "Bcrena"
)

echo "${cmd[@]}"
"${cmd[@]}" > $outdir/mkado_alphaTG.out.tsv
