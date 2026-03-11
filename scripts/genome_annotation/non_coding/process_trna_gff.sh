#!/bin/bash

set -euo pipefail

work=/sietch_colab/data_share/balanus/genome_annot/non_coding/tRNAscan_SE
in_gff=$work/BalGla_tRNA.gff
in_genome=$work/../../in_genome/BalGla.fa

# 1. Run the base agat parser to standarize, add missing attributes,
# and sort the annotations by chromosome coordinates.
agat_convert_sp_gxf2gxf.pl --gff $in_gff --output o1.standard.gff3

# 2. Remove the pseudogenes
agat_sp_filter_feature_by_attribute_value.pl \
    --gff o1.standard.gff3 \
    --att 'gene_biotype' \
    --value 'pseudogene' \
    --output o2.no_pseudo.gff3

# 3. Assign a new gene per tRNA transcript. This modifies all existing
# transcript and gene IDs.
cat o2.no_pseudo.gff3 | grep -vw 'AGAT' |
    awk '
    BEGIN { OFS="\t"; gene_counter=1 }
    /^#/ { print; next }
    $3 == "tRNA" {
        # Create a new gene feature for this tRNA
        gene_id = "trna-gene-" gene_counter
        transcript_id = "trna-" gene_counter

        # Print the gene feature
        print $1, $2, "gene", $4, $5, $6, $7, $8, "ID=" gene_id ";Name=" gene_id";gene_biotype=tRNA"

        # Print the tRNA/RNA feature with updated Parent
        gsub(/ID=[^;]*/, "ID=" transcript_id, $9)
        gsub(/Parent=[^;]*/, "Parent=" gene_id, $9)
        print $0

        gene_counter++
        next
    }
    $3 == "exon" {
        # Update exon parent to match the transcript
        transcript_num = gene_counter - 1
        transcript_id = "trna-" transcript_num
        gsub(/Parent=[^;]*/, "Parent=" transcript_id, $9)
        print $0
        next
    }
    $3 == "gene" || $3 == "pseudogene" {
        # Skip original gene/pseudogene features
        next
    }
    { print }
    ' > o3.one_gene_per_tRNA.gff3

# 4. Edit the transcript IDs.
# First, extract the relevant information.
agat_sp_extract_attributes.pl \
    --gff o3.one_gene_per_tRNA.gff3 \
    --p tRNA \
    --merge \
    --att ID,Name,anticodon,isotype \
    --output tRNA_info.tsv
# Create a new file with the name changes
echo -e 'ID\tName\tanticodon\tisotype\tgene_biotype' > transcript_attributes.tsv
cat tRNA_info.tsv | cut -f 1,3,4 | \
    sed -E 's/(tRNA\-[0-9]+)\t([A-Z]{3})\t([a-zA-Z]+)$/\1\t\1\-\3\2\t\2\t\3\ttRNA/' >> transcript_attributes.tsv

# 4. Remove the excess attributes from the existing tRNAs
agat_sp_manage_attributes.pl --gff o3.one_gene_per_tRNA.gff3\
    --type tRNA \
    --att 'all_attributes' \
    --output o4.no_tRNA_atts.gff3

# 5. Once clear, add these new attribues
agat_sq_add_attributes_from_tsv.pl \
    --gff o4.no_tRNA_atts.gff3 \
    --tsv transcript_attributes.tsv \
    --output o5.fixed_transcript_ids.gff3

# 6. Standarize the names of exons
agat_sp_manage_IDs.pl \
    --gff o5.fixed_transcript_ids.gff3 \
    -p exon \
    --prefix 'trna-exon-' \
    --output o6.fixed_exons_ids.gff3
