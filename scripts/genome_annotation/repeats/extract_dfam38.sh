#!/bin/bash

# Location of Dfam 3.8 libraries
db=/home/ariverac/local/mambaforge/envs/repeat_masker/share/RepeatMasker/Libraries

# Search term to use
# term=6656   # 6656 is the NCBI Tax ID for Arthropods
# term=116172 # 116172 is the NCBI Tax ID for Thecostraca
term=6657   # 6657 is the NCBI Tax ID for Crustacea

# Run famdb

famdb.py --db_dir $db \
    families --ancestors --descendants \
    --include-class-in-name \
    --format fasta_name \
    $term > dfam3.8_${term}.fa
