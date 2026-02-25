#!/bin/bash

THR=6

work=/sietch_colab/data_share/balanus/genome_annot/non_coding
ref_gtf=$work/in_genome/BalGla.gtf
ref_fa=$work/in_genome/BalGla.fa
stringtie_gtf=$work/stringtie_out/BalGla_IsoSeq.stringtie.gtf
feelnc_out=$work/feelnc_out

# First, filter the stringtie GTF to get candidate ncRNAs
candidate=$feelnc_out/candidate_lncRNA.gtf
cmd=(
    FEELnc_filter.pl
    --proc=$THR
    --monoex=-1
    --infile=$stringtie_gtf
    --mRNAfile=$ref_gtf
)
# echo "${cmd[@]}"
# "${cmd[@]}" > $candidate

# Second, compute the coding potential score for the candidate ncRNAs.
# We don't have species-specific ncRNAs so we have to model based on the genome.
cmd=(
    FEELnc_codpot.pl
    --infile=$candidate
    --mRNAfile=$ref_gtf
    --genome=$ref_fa
    --mode=intergenic
    --outdir=$feelnc_out
)
# echo "${cmd[@]}"
# "${cmd[@]}"

# Lastly, classify the ncRNAs based on their location
# relative to nearby genes.
lncrna_gtf=$feelnc_out/candidate_lncRNA.gtf.lncRNA.gtf
log=$feelnc_out/candidate_lncRNA.classifier.log
classes=$feelnc_out/candidate_lncRNA.classes.txt

cmd=(
    FEELnc_classifier.pl
    --lncrna=$lncrna_gtf
    --mrna=$ref_gtf
    --biotype
    --log=$log
)
echo "${cmd[@]}"
"${cmd[@]}" > $classes

