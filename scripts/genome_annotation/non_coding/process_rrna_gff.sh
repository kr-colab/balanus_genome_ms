#!/bin/bash

set -euo pipefail

work=/sietch_colab/data_share/balanus/genome_annot/non_coding/barrnap_out
in_gff=$work/BalGla_rRNA.barrnap.gff
in_genome=$work/../../in_genome/BalGla.fa

1. Run the base agat parser to standarize, add missing attributes,
and sort the annotations by chromosome coordinates.
agat_convert_sp_gxf2gxf.pl --gff $in_gff --output o1.standard.gff3

# 2. Extract and the attributes from the rRNAs will be used for
# future reformatting.
agat_sp_extract_attributes.pl \
    --gff o1.standard.gff3 \
    --p 'rRNA' \
    --merge \
    --att 'ID,Name,product' \
    --output rRNA_info.tsv

# 3. Remove the excess attributes.
agat_sp_manage_attributes.pl \
    --gff o1.standard.gff3 \
    --type 'gene,rRNA' \
    --att 'notes,note,product' \
    --output o3.no_rRNA_atts.gff3

# 4. Custom command to add missing gene and exon annotation
cat o3.no_rRNA_atts.gff3 | grep -vw 'AGAT' |
    awk '
    BEGIN { OFS="\t"; gene_counter=1 }
    /^#/ { print; next }
    $3 == "rRNA" {
        # Create a new gene feature for this rRNA
        gene_id = "rrna-gene-" gene_counter
        # Create a new exon feature for this rRNA
        exon_id = "rrna-exon-" gene_counter
        # Extract the ID
        match($9, /ID=([^;]*)/, arr)
        transcript_id = arr[1]
        # Extract the name
        match($9, /Name=([^;]*)/, arr)
        name_value = arr[1]

        # Print the gene feature
        print $1, $2, "gene", $4, $5, ".", $7, $8, "ID=" gene_id";Name=" name_value";gene_biotype=rRNA"

        # Print the tRNA/RNA feature with updated Parent
        gsub(/ID=[^;]*/, "ID=" transcript_id, $9)
        gsub(/Parent=[^;]*/, "Parent=" gene_id ";gene_biotype=rRNA", $9)
        print $0

        # Print the exon feature
        print $1, $2, "exon", $4, $5, ".", $7, $8, "ID=" exon_id ";Parent=" transcript_id

        gene_counter++
        next
    }
    { print }
    ' > o4.genes_and_exons.gff3

# 5. Add the missing attributes back
echo -e "ID\tName\tproduct" > rRNA_attributes.tsv
cat rRNA_info.tsv | \
    sed -E 's/(agat-rrna-[0-9]+)\t([0-9a-zA-Z_ ]+)\t(.+)+/\1\t\2\t\"\3\"/' >> rRNA_attributes.tsv
agat_sq_add_attributes_from_tsv.pl \
    --gff o4.genes_and_exons.gff3 \
    --tsv rRNA_attributes.tsv \
    --output o5.fixed_attributes.gff3

# 6. Standarize the names of transcripts
agat_sp_manage_IDs.pl \
    --gff o5.fixed_attributes.gff3 \
    -p  rRNA\
    --prefix 'rrna-' \
    --output o6.fixed_transcript_ids.gff3
