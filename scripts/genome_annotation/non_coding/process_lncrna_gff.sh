#!/bin/bash

set -euo pipefail

work=/sietch_colab/data_share/balanus/genome_annot/non_coding/feelnc_out/process_out
in_gff=$work/candidate_lncRNA.gtf.lncRNA.gtf
in_genome=$work/../../in_genome/BalGla.fa

# 0. Run the base agat parser to standarize, add missing attributes,
# and sort the annotations by chromosome coordinates.
agat_convert_sp_gxf2gxf.pl --gff $in_gff --output o0.standard.gff3

# 1. Filter to keep the longest isoforms only
agat_sp_keep_longest_isoform.pl \
    --gff o0.standard.gff3 \
    --out o1.longest.gff3

# 2. Edit the source of the annotations and the RNA features
# To convert RNA to lncRNA
cat o1.longest.gff3 | \
    sed -E 's/\bRNA\b/lncRNA/' | \
    sed -E 's/\bStringTie\b/FEELnc/' > o2.fixed_feats.gff3

# 3. Remove excess attributes.
agat_sp_manage_attributes.pl \
    --gff o2.fixed_feats.gff3 \
    --type 'all' \
    --att 'all_attributes' \
    --output o3.fixed_atts.gff3

# 4. Standarize the names of genes.
agat_sp_manage_IDs.pl \
    --gff o3.fixed_atts.gff3 \
    -p gene \
    --prefix 'lncrna-gene-' \
    --output o4.fixed_gene_ids.gff3

# 5. Standarize the names of transcripts
agat_sp_manage_IDs.pl \
    --gff o4.fixed_gene_ids.gff3 \
    -p lncRNA \
    --prefix 'lncrna-' \
    --output o5.fixed_transcript_ids.gff3

# 6. Standarize the names of exons
agat_sp_manage_IDs.pl --gff o5.fixed_transcript_ids.gff3 \
    -p exon \
    --prefix 'lncrna-exon-' \
    --output o6.fixed_exons_ids.gff3

# 7. Add the corresponding biotype for gene and transcripts
echo -e "ID\tName\tgene_biotype" > gene_attributes.tsv
agat_sp_extract_attributes.pl --gff o6.fixed_exons_ids.gff3 \
    --att 'ID' \
    -p 'gene,lncRNA' \
    --out lncrna-gene
cat lncrna-gene_ID | sed -E 's/^(.*)$/\1\t\1\tlncRNA/' >> gene_attributes.tsv
agat_sq_add_attributes_from_tsv.pl \
    --gff o6.fixed_exons_ids.gff3 \
    --tsv gene_attributes.tsv \
    --output o7.fixed_biotype.gff3

# 8. Add introns
agat_sp_add_introns.pl \
    --gff o7.fixed_biotype.gff3 \
    --out o8.withIntrons.gff3

# 9. Standarize the intron IDs
agat_sp_manage_IDs.pl \
    --gff o8.withIntrons.gff3 \
    --prefix 'lncrna-intron-' \
    -p 'intron' \
    --output o9.fixed_intron_ids.gff3
