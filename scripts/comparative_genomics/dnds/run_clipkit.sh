#!/bin/bash
# Put bash in strict mode
set -e
set -o pipefail

THR=8
NPR=4
work=/sietch_colab/data_share/balanus/comp_genomics/mk_test/translated_msas.20260223
sco_list=$work/sco_transcripts.tsv
indir=$work/sco_codon_msa_prank
outdir=$work/sco_trimmed_msa
mkdir -p $outdir

# Trimmed the Prank MSA using ClipKit
cat $sco_list | grep -v '^#' | cut -f1 | sort -k1 -u |
while read og_id; do
    in_msa=$indir/${og_id}.msa.best.fas
    out_msa=$outdir/${og_id}.clk_trimmed_msa.fa
    log=$outdir/${og_id}.clipkit.log
    # Check if the input MSA exists and run.
    if [ -e "$in_msa" ]; then
        cmd=(
            clipkit
            $in_msa
            --output $out_msa
            --sequence_type nt
            --log
            # --mode smart-gap
            --mode gappy
            --gaps 0.25
            --codon
	    --threads $NPR
        )
        echo "${cmd[@]} &> $log"
    fi
done | parallel -j $THR
