#
# Calculate codon bias on a set of coding sequences using
# the cubar software
#

# Load the packages
library(ggplot2)
library(cubar)
suppressPackageStartupMessages(library(Biostrings))
suppressPackageStartupMessages(library(data.table))

# Input data
work <- '/sietch_colab/data_share/balanus/codon_usage/dmel'
setwd(work)
cds_f <- 'in_data/dmel.cds.clean.fa'

# Load and process the input sequences
cds <- readDNAStringSet(cds_f)
# cds <- readDNAStringSet(cds_f,
#                         nrec = 100)
message(paste0("Loaded ",
               length(cds),
               " sequences from the input CDS fasta."))

cds <- cubar::check_cds(cds)
# cds <- cubar::check_cds(cds,
#                         check_stop = FALSE,
#                         check_start = FALSE)
message(paste0("Kept ",
               length(cds),
               " sequences after filtering the CDS sequences."))

# Obtain some general stats on the input
seq_lens <- data.frame(transcript=names(cds),
                       len_bp=width(cds))

# Count the codons
codons <- cubar::count_codons(cds)

# Calculate GC content across all positions
message("Calculating GC content across all positions.")
gc_prop <- cubar::get_gc(codons)
gc_df <- data.frame(transcript=names(gc_prop),
                    gc_prop=gc_prop)
message(paste0("    Mean GC: ", mean(gc_prop)))
message(paste0("    Mean GC: ", median(gc_prop)))
message(paste0("    Mean GC: ", sd(gc_prop)))

# Calculate the GC content at 3rd codon synonymous positions
message("Calculating GC content at synonymous 3rd codons positions.")
gc3s_prop <- cubar::get_gc3s(codons)
gc3s_df <- data.frame(transcript=names(gc3s_prop),
                      gc3s_prop=gc3s_prop)
message(paste0("    Mean GC3s: ", mean(gc3s_prop, na.rm = TRUE)))
message(paste0("    Mean GC3s: ", median(gc3s_prop, na.rm = TRUE)))
message(paste0("    Mean GC3s: ", sd(gc3s_prop, na.rm = TRUE)))
gc_df <- dplyr::inner_join(gc_df,
                           gc3s_df,
                           by = 'transcript')
rm(gc3s_df)

# Calculate the GC content at 4-fold degenerate positions
message("Calculating GC content at 4-fold degenerate positions.")
gc4d_prop <- cubar::get_gc4d(codons)
gc4d_df <- data.frame(transcript=names(gc4d_prop),
                      gc4d_prop=gc4d_prop)
message(paste0("    Mean GC4d: ", mean(gc4d_prop, na.rm = TRUE)))
message(paste0("    Mean GC4d: ", median(gc4d_prop, na.rm = TRUE)))
message(paste0("    Mean GC4d: ", sd(gc4d_prop, na.rm = TRUE)))
gc_df <- dplyr::inner_join(gc_df,
                           gc4d_df,
                           by = 'transcript')
rm(gc4d_df)

# Start preparing the output
out_df <- dplyr::inner_join(seq_lens,
                            gc_df,
                            by = 'transcript')
rm(gc_df)

# Calculate the effective number of codons
message("Calculating the effective number of codons at the subfamily level:")
enc_sf <- cubar::get_enc(codons,
                         level = 'subfam')
message(paste0("    Mean ENC: ", mean(enc_sf)))
message(paste0("    Mean ENC: ", median(enc_sf)))
message(paste0("    Mean ENC: ", sd(enc_sf)))
# Transpose the ENC results into a dataframe.
enc_sf_df <- data.frame(transcript=names(enc_sf),
                        enc_subfam=enc_sf,
                        row.names=NULL)
# And add to main output
out_df <- dplyr::inner_join(out_df,
                            enc_sf_df,
                            by = 'transcript')
rm(enc_sf_df)

message("Calculating the effective number of codons at the amino acid level:")
enc_aa <- cubar::get_enc(codons,
                         level = 'amino_acid')
message(paste0("    Mean ENC: ", mean(enc_aa)))
message(paste0("    Mean ENC: ", median(enc_aa)))
message(paste0("    Mean ENC: ", sd(enc_aa)))
enc_aa_df <- data.frame(transcript=names(enc_aa),
                        enc_aa=enc_aa,
                        row.names=NULL)
out_df <- dplyr::inner_join(out_df,
                            enc_aa_df,
                            by = 'transcript')
rm(enc_aa_df)


# Calculate the fractin of optimal codons
message("Calculating the fraction of optimal codons")
# op_codons <- est_optimal_codons(codons,
#                                 codon_table = get_codon_table(),
#                                 level = "subfam",
#                                 gene_score = NULL,
#                                 fdr = 0.05
#                                 )
# print(op_codons)

fop <- cubar::get_fop(codons,
                      op = NULL,
                      codon_table = get_codon_table(),
                      fdr = 0.001)
message(paste0("    Mean FOP: ", mean(fop)))
message(paste0("    Mean FOP: ", median(fop)))
message(paste0("    Mean FOP: ", sd(fop)))
fop_df <- data.frame(transcript=names(fop),
                     fop=fop,
                     row.names=NULL)
out_df <- dplyr::inner_join(out_df,
                            fop_df,
                            by = 'transcript')
rm(fop_df)

# Save the final table into a file
write.table(out_df,
            file = './codon_bias.tsv',
            quote = FALSE,
            sep = '\t',
            row.names = FALSE)

# Make quick plot of ENC
plt <- ggplot(out_df, aes(x=enc_subfam)) +
    geom_histogram(fill="lightblue",
                   color="dodgerblue4",
                   alpha=0.8,
                   binwidth = 1) +
    geom_vline(xintercept = mean(out_df$enc_subfam),
               color = "firebrick",
               linetype = "dashed") +
    geom_vline(xintercept = median(out_df$enc_subfam),
               color = "mediumseagreen",
               linetype = "dotted") +
    labs(x = "Effective number of codons",
         y = "Number of transcripts") +
    theme_bw()

ggsave('./enc.pdf', plot=plt, width=4, height=4)
