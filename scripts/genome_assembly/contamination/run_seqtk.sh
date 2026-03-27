#!/bin/bash

work=/sietch_colab/ariverac/balanus_genome/assemblies/20230817.3cell.hifiasm.def/blobtools/in_reads/out_reads/Thecostraca
infq=$work/../m64047_blaGla.merged.ccs.fastq.gz
outfq=$work/m64047_blaGla.merged.ccs.filtered_class-Thecostraca.fastq.gz
reads=$work/filtered_class-Thecostraca.reads.txts

seqtk subseq $infq $reads | gzip > $outfq
