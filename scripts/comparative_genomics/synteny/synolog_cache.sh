
!/bin/bash

WORK=/path/to/working/dir

# Create a new Synolog cache and load it with the species of interest
CACHE_DIR=$(date +$WORK/%Y%m%d.synolog)
# synolog_cctl.py new -p $CACHE_DIR

# Adding species
SPP=BalGla
REF_DIR=/path/to/assembly

# Add BalGla
synolog_cctl.py species \
    --path $CACHE_DIR \
    --id $SPP \
    --name "Balanus glandula" \
    --common "Pacific acorn barnacle"

# Add the annotation
synolog_cctl.py annotation \
    --path $CACHE_DIR \
    --id $SPP \
    --ann-id 'bg1' \
    --gff $REF_DIR/BalGla.gff \
    --agp $REF_DIR/BalGla.agp

# Add the genes
synolog_cctl.py genes \
    --path $CACHE_DIR \
    --id $SPP \
    --genes-id 'bg1' \
    --aa $REF_DIR/BalGla.peptide.fa

# Add an annotation/integration
synolog_cctl.py integration \
    --path $CACHE_DIR \
    --id $SPP \
    --genes-id 'bg1' \
    --ann-id 'bg1' \
    --desc "KR-lab custom assembly and annotation for B. glandula"
