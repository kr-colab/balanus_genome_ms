#!/bin/bash

THR=8
BLAST_SRC=/path/to/blast/bin

# Information for the cache
SYN_CACHE=/path/to/synolog/cache

orgs=(
    AmpAmp.refseq
    BalGla.bg1
    PolPol.refseq
)
org_lst=$(echo "${orgs[@]}" | tr ' ' ',')

cmd=(
    synolog_blastctl.py
    --path $SYN_CACHE
    --org "$org_lst"
    --blast-type blastp
    --blast-path $BLAST_SRC
    --queue-bin bash
    --queue-cpus $THR
    --force
    --keep-files
    # --dry-run
)
echo "${cmd[@]}"
"${cmd[@]}"
