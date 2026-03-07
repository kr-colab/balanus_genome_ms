#!/bin/bash
set -euo pipefail
THR=24

work=/sietch_colab/data_share/balanus/comp_genomics/dem_inference
cfg=$work/cfgs/Bgland_00.yml

cmd=(
    ./SRC/deminfhelper.py
    --config_file $cfg
    --msmc2
    --plot_msmc2
    --cpus $THR
)
echo "${cmd[@]}"
"${cmd[@]}"
