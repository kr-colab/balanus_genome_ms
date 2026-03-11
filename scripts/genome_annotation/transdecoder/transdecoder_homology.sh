#!/bin/bash

# Put bash in strict mode
set -e
set -o pipefail

THR=12
work=/sietch_colab/data_share/balanus/genome_annot/braker_annotation/SQANTI3/20241207.SQANTI3_out/transdecoder_processing/transdecoder
in_faa=$work/BalGla.transdecoder.cds.fa.transdecoder_dir/longest_orfs.pep

# Run BLAST
db=/sietch_colab/data_share/blast_db/uniprot/uniprot_sprot.fasta
outf=$work/homology/blastp.BalGla_UniprotSprot.tsv

cmd=(
    blastp
    -query $in_faa
    -db $db
    -max_target_seqs 1
    -outfmt 6
    -evalue 1e-5
    -num_threads $THR
    -out $outf
)
echo "${cmd[@]}"
"${cmd[@]}"


# Run HMMSEARCH
db=/sietch_colab/data_share/blast_db/pfam/Pfam-A.hmm
outf=$work/homology/hmmsearch.BalGla_PfamA.domtblout

cmd=(
    hmmsearch
    --cpu $THR
    -E 1e-10
    --domtblout $outf
    $db
    $in_faa
)
echo "${cmd[@]}"
"${cmd[@]}"
