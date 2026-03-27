#!/bin/bash

reads=/sietch_colab/ariverac/balanus_genome/data/hifi/read_links
outdir=/sietch_colab/ariverac/balanus_genome/assemblies/20230817.3cell.hifiasm.def
name=$outdir/balGla.def
log=$outdir/hifiasm.log

cmd=(
    hifiasm
    -o $name
    -t 24
    $reads/m64047_230524_205253.ccs.fastq.gz
    $reads/m64047_230531_210842.ccs.fastq.gz
    $reads/m64047_230602_080338.ccs.fastq.gz
)

echo "${cmd[@]}"
#"${cmd[@]}" > $log 2>&1


# Convert the GFA to fasta
cat ${name}.bp.p_ctg.gfa | awk '/^S/{print ">"$2;print $3}' | gzip > ${name}.p_ctg.fasta.gz
