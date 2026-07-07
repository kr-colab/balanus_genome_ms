#!/bin/bash

THR=8

# Information for the cache
SYN_CACHE=/path/to/synolog/cache

orgs=(
    BalGla.bg1.bg1
    AmpAmp.refseq.han24
    PolPol.refseq.refseq
)
org_lst=$(echo "${orgs[@]}" | tr ' ' ',')

# Create output
N="${#orgs[@]}"
outd=$(date +%Y%m%d.synolog_out.N${N})
mkdir -p $outd

# Run the Synolog inference algorithm
cmd=(
    synolog_run.py
    --path $SYN_CACHE
    --out-path $outd
    --org "$org_lst"
    --threads $THR
)
echo "${cmd[@]}"
"${cmd[@]}"

# Make a genome-wide plot
cmd=(
    synolog_plot.py
    genome
    --path $outd
    --orgs "$org_lst"
    --span
    --min 5e6
    --color 0
    --out "gw_synteny.N${N}"
)
echo "${cmd[@]}"
"${cmd[@]}"
