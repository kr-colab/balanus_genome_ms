#!/bin/bash

# Put bash in strict mode
set -e
set -o pipefail

THR=24
NPR=$(($THR/6))

work=/sietch_colab/data_share/balanus/comp_genomics
in_data=$work/species_database
of_runs=$work/orthofinder

# List of species for the run
spps=(
    AmpAmp
    AmpImp
    BalCre
    BalGla
    # CapMit
    PolPol
    # SacCar
)

# Prepare output directory
N=$(echo ${#spps[@]})
outd=$(date +${of_runs}/%Y%m%d.orthofinder_barnacles.N${N})
mkdir -p $outd
cd $outd

# Link the specific input FASTA sequences
pep_dir=$outd/peptide
bed_dir=$outd/bed
cds_dir=$outd/cds
mkdir -p $pep_dir
mkdir -p $bed_dir
mkdir -p $cds_dir
orgs=$outd/orgs.txt
> $orgs
for sp in ${spps[@]}; do
    # Link the peptides
    ln -s ${in_data}/${sp}/${sp}.peptide.fa ${pep_dir}/${sp}.fa
    # Link the beds
    ln -s ${in_data}/${sp}/${sp}.annotation.bed ${bed_dir}/${sp}.bed
    # Link the CDSs
    ln -s ${in_data}/${sp}/${sp}.cds.fa ${cds_dir}/${sp}.fa
    # Add to the organism list
    echo $sp >> $orgs
done

# Run OrthoFinder
cmd=(
    orthofinder
    -t $THR
    -a $NPR
    # -M "msa"
    # -S "diamond"  # Default
    # -A "mafft"    # Default
    # -T "fasttree" # Default
    -o "$outd/orthofinder"
    -y # Split paralogs below root
    -f $pep_dir
)
echo "${cmd[@]}"
"${cmd[@]}"
