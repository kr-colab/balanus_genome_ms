#!/bin/bash

thr=24

# Run TEsorter on the resulting repeat library from EarlGrey

library=/path/to/library.clean.fasta
db=/path/to/rexdb-metazoa
out=/path/to/output/BalGla.tesorter

cmd=(TEsorter
    $library
    -db $db
    -p $thr
    -pre $out
)
echo "${cmd[@]}"
"${cmd[@]}"
