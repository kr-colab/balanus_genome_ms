#!/bin/bash

thr=18
work=/sietch_colab/ariverac/balanus_genome/assemblies/20230817.3cell.hifiasm.def/blobtools
genome=$work/in_genome/balGla.def.p_ctg.fasta
outf=$work/blasts/blast_balGla.def_nt.tsv.gz

# BLAST db
db=/sietch_colab/data_share/blobtools_database/nt/nt

# Run BLASTN
cmd=(
    blastn
    -query $genome
    -db $db
    -out -
    -evalue "1e-10"
    -outfmt "6 qseqid staxids bitscore std"
    -max_target_seqs 25
    -num_threads $thr
)

# Run BLASTN and compress output
"${cmd[@]}" | gzip > "${outf}"
