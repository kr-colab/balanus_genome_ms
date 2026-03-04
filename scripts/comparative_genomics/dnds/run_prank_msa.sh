#!/bin/bash
# Put bash in strict mode
set -e
set -o pipefail

THR=24
work=/sietch_colab/data_share/balanus/comp_genomics/mk_test/translated_msas.20260223
tree=$work/SpeciesTree_rooted.txt
indir=$work/sco_cds
sco_list=$work/sco_transcripts.tsv
outdir=$work/sco_codon_msa_prank
mkdir -p $outdir

# Align the single copy ortholog sequences with Prank
cat $sco_list | grep -v '^#' | cut -f1 | sort -u |
while read og_id; do
    in_fasta=$indir/${og_id}.cds.fa
    # Outputs
    out_msa=$outdir/${og_id}.msa
    log=$outdir/${og_id}.log
    cmd=(
        prank
        -d=$in_fasta
        -o=$out_msa
        -t=$tree
        -F
        -codon
        -iterate=3
        -quiet
	-prunetree
    )
    echo "${cmd[@]} > $log"
done | parallel -j $THR
