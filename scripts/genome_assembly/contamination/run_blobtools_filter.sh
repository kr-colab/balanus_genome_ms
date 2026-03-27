#!/bin/bash

work=/sietch_colab/ariverac/balanus_genome/assemblies/20230817.3cell.hifiasm.def/blobtools
taxdump=/sietch_colab/data_share/blobtools_database/taxdump
blobdir=${work}/balGla_def.BlobDir

# Files to filter
bam=${work}/alignments/balGla.def.hifi_3cell.bam
fasta=${work}/in_genome/balGla.def.p_ctg.fasta
fastq=${work}/in_reads/m64047_blaGla.merged.ccs.fastq.gz

# Output directory for the specific filter ()
lvl=class
# lvl=order
filt=Thecostraca
# filt=Balanomorpha
rule=bestsumorder
suffix=filtered_${lvl}-${filt}
outd=$(date +${work}/%Y%m%d.balGla_def.filter_${lvl}-${filt}.BlobDir)
log=${outd}/${suffix}.log
tbl=${outd}/${suffix}.tbl
param=${rule}_${lvl}--Keys=${filt}
mkdir -p $outd

cmd=(
    blobtools filter
    --param $param
    --fasta $fasta
    --fastq $fastq
    --cov $bam
    --taxdump $taxdump
    --taxrule $rule
    --output $outd
    --suffix $suffix
    # --summary $log
    # --summary-rank $lvl
    # --table $tbl
    --invert # since we are keeping the matches to the filter
    $blobdir
)

echo "${cmd[@]}"
"${cmd[@]}" > $log
