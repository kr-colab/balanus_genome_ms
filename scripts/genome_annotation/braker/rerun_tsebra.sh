#!/bin/bash

# IsoSeq BRAKER run
isoseq_braker=/sietch_colab/data_share/balanus/genome_annot/20240521.balGla.4c_Thc.hifiasm_s45_D10_ONT.tigmint.yahs/braker/20240613.braker3_isoseq_arthropoda_odb11.masked

# RNAseq BRAKER run
rnaseq_braker=/sietch_colab/data_share/balanus/genome_annot/20240521.balGla.4c_Thc.hifiasm_s45_D10_ONT.tigmint.yahs/braker/20240613.braker3_rnaseq_arthropoda_odb11.masked

# Output directory
outdir=$isoseq_braker/rerun_tsebra
basename=$outdir/tsebra_isoseq_rnaseq

# Run TSEBRA to combine outputs from both brakers
cmd=(
    tsebra.py
    --gtf $isoseq_braker/braker.gtf,$rnaseq_braker/braker.gtf
    --keep_gtf $rnaseq_braker/braker.gtf
    --hintfiles $isoseq_braker/hintsfile.gff,$rnaseq_braker/hintsfile.gff
    #--filter_single_exon_genes
    #--cfg /home/ariverac/local/mambaforge/envs/braker3/bin/../config/braker3.cfg
    --out ${basename}.gtf
)
echo "${cmd[@]}"
"${cmd[@]}" 2> $outdir/tsebra.stderr

cmd=(
    getAnnoFastaFromJoingenes.py
    --genome $outdir/balGla.softmasked.fasta
    --gtf ${basename}.gtf
    --out $basename
)
echo "${cmd[@]}"
"${cmd[@]}" 1> $outdir/getAnnoFastaFromJoingenes.stdout 2> $outdir/getAnnoFastaFromJoingenes.stderr

