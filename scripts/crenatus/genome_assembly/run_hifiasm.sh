#!/bin/bash

reads=/sietch_colab/data_share/balanus/balCre_hifi/read_links
work=/sietch_colab/ariverac/balanus_genome/outgroups/balCre/assemblies/20240131.2cell.hifiasm.hmc40_s45
outdir=$work/hifiasm_out
name=$outdir/balCre.hmc40_s45
log=$outdir/hifiasm.log
mkdir -p $outdir


cmd=(
    hifiasm
    -o $name
    --hom-cov 40
    -t 24
    -s 0.45
    -u 1
    -l 3
    $reads/m64047_240125_175314.ccs.fastq.gz
    $reads/m64047_240127_045016.ccs.fastq.gz
)

echo "${cmd[@]}"
"${cmd[@]}" > $log 2>&1


# Convert the GFA to fasta
cat ${name}.bp.p_ctg.gfa | awk '/^S/{print ">"$2;print $3}' | gzip > ${name}.p_ctg.fasta.gz

# Make other useful dirs
mkdir -p quast busco compleasm
