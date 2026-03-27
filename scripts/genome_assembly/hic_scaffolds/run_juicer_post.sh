#!/bin/bash

work=/sietch_colab/ariverac/balanus_genome/assemblies/20240226.3cell_Thecostraca.hifiasm_0.19.8.s25_D10_ONT_HiC_hmc68_hgs800_dualScaff/hi-c/20250129.curation
assm=$work/balGla.3c_Thc.ONT_HiC_D10_s25.yahs_juicer.jbat.review2.assembly
agp=$work/balGla.3c_Thc.ONT_HiC_D10_s25.yahs_juicer.jbat.liftover.agp
ctgs=$work/balGla.3c_Thc.ONT_HiC_D10_s25.purged.fa
name=$work/balGla.3c_Thc.ONT_HiC_D10_s25.yahs_juicer.curated_v2

cmd=(
    juicer post
    -o $name
    $assm
    $agp
    $ctgs
)
echo "${cmd[@]}"
"${cmd[@]}"

