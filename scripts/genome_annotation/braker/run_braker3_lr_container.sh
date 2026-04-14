#!/bin/bash

THR=16
export BRAKER_SIF=/home/ariverac/local/containers/braker3_lr.sif

# My vars
work=/sietch_colab/data_share/balanus/genome_annot/20240521.balGla.4c_Thc.hifiasm_s45_D10_ONT.tigmint.yahs
fasta=${work}/in_genome/balGla.softmasked.fasta
bam=${work}/alignments/bamGla_isoseq.bam
peptide=${work}/peptide_seqs/Arthropoda_odb11.ampAmp.peptide.fa
outdir=$(date +${work}/braker/%Y%m%d.braker3_isoseq_arthropoda_odb11.masked)
mkdir -p $outdir
cd $outdir

AUGUSTUS_CONFIG_PATH=$outdir

cmd=(
    # Set up singularityls
    singularity exec
    # Bind all needed inputs
    --bind ${fasta}:${fasta}
    --bind ${bam}:${bam}
    --bind ${peptide}:${peptide}
    --bind ${outdir}:${PWD}
    # Specify container
    ${BRAKER_SIF}
    # Braker3 call
    braker.pl
    --genome=$fasta
    --species=balGla.IsoSeq.ArthroOdb11
    --bam=$bam
    --threads=$THR
    --prot_seq=$peptide
    --workingdir=./
    --AUGUSTUS_CONFIG_PATH=./augustus_config/
    --busco_lineage=arthropoda_odb10
    --useexisting
)
echo "${cmd[@]}"
"${cmd[@]}"

