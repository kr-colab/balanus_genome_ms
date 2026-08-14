#!/bin/bash

# Run DeepTE to re-classify the unknown repeats
SRC=/path/to/bin
RUN=/path/to/run_directory
library=$RUN/EarlGrey_out/library.unknown.fasta

# protein domain evidence (HMMER 3.4 against DeepTE's bundled minifam)
python $SRC/DeepTE_domain.py \
    -d  $RUN/domain/working_dir \
    -o  $RUN/domain \
    -i  $library \
    -s  $SRC/supfile_dir \
    --hmmscan $SRC/hmmscan

# classify, with the domain evidence fed back via -modify
CUDA_VISIBLE_DEVICES=0 python $SRC/DeepTE.py \
    -d  $RUN/working_dir \
    -o  $RUN/deepte_raw \
    -i  $library \
    -sp M \
    -m_dir $SRC/DeepTE_models/Metazoans_model \
    -prop_thr 0.8 \
    -modify $RUN/domain/te_domain_pattern.txt
