#!/bin/bash

set -euo pipefail
in_gff=$1
in_fa=$2

#
# Process an annotation using AGAT
#

# 1. Initial processing and filtering.
# Makes all the IDs and parent/offspring features consistent.
agat_convert_sp_gxf2gxf.pl \
    --gff $in_gff \
    --output o1.fu.gff3

# 2. Select the longest isoform
agat_sp_keep_longest_isoform.pl \
    --gff o1.fu.gff3 \
    --output o2.long.gff3

# 3. Fix duplicated genes
agat_sp_fix_features_locations_duplicated.pl \
    --gff o2.long.gff3 \
    --output o3.dup.gff3

# 4. Fix the phase of the CDSs
agat_sp_fix_cds_phases.pl \
    --gff o3.dup.gff3 \
    --fasta $in_fa \
    --output o4.phase.gff3

# 5. Remove overlaps
agat_sp_fix_overlaping_genes.pl \
    --gff o4.phase.gff3 \
    --output o5.noOlaps.gff3

# 6. Add Introns
agat_sp_add_introns.pl \
    --gff o5.noOlaps.gff3 \
    --output o6.withIntrons.gff3

# 7. Add start and stop codons
agat_sp_add_start_and_stop.pl \
    --gff o6.withIntrons.gff3 \
    --fasta $in_fa \
    --output o7.startstop.gff3

# 8. Remove unwanted attributes
agat_sp_manage_attributes.pl \
    --gff o7.startstop.gff3 \
    --type "all" \
    --att "all_attributes" \
    --outfile o8.cleanAtts.gff3

# 9. Re-sort the file for re-naming
agat_convert_sp_gxf2gxf.pl \
    --gff o8.cleanAtts.gff3\
    --output o9.reSorted.gff3

# 10. Clean the IDs
agat_sp_manage_IDs.pl \
    --gff o9.reSorted.gff3 \
    --type_dependent \
    -p "all" \
    --output o10.cleanIDs.gff3

# 11. Extract the gene/mRNA attribute IDs
agat_sp_extract_attributes.pl \
    --gff o10.cleanIDs.gff3 \
    -p "gene,mRNA,transcript" \
    --att "ID" \
    --output o11.gene_mRNA.txt

# 12. Convert the IDs into an attribute table
echo -e "ID\tName\tgene_biotype" > o12.attributes.tsv
cat o11.gene_mRNA_ID.txt | \
    sed -E 's/^(.+)$/\1\t\1\tprotein_coding/' >> o12.attributes.tsv

# 13. Add the attributes into a new, final GFF
agat_sq_add_attributes_from_tsv.pl \
    --gff o10.cleanIDs.gff3 \
    --tsv o12.attributes.tsv \
    --output final.gff3

# 13. Extract the peptide sequences
agat_sp_extract_sequences.pl \
    --gff final.gff3 \
    --fasta $in_fa \
    --asc \
    --cfs \
    --cis \
    -t "cds" \
    --protein \
    --output final.peptide.fa

# 14. Extract the CDS sequences
agat_sp_extract_sequences.pl \
    --gff final.gff3 \
    --fasta $in_fa \
    --asc \
    --cfs \
    --cis \
    -t "cds" \
    --output final.cds.fa

# 15. Calculate the basic AGAT stats
agat_sq_stat_basic.pl \
    --gff final.gff3 \
    --genome $in_fa \
    --output final.agat_basic_stats.tsv

# 16. Calculate some more detailed stats
agat_sp_statistics.pl \
    --gff final.gff3 \
    -f $in_fa \
    --output final.agat_stats.tsv

