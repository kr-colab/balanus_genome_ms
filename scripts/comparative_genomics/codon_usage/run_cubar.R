#
# Calculate codon bias on a set of coding sequences using
# the cubar software
#

# Load the packages
suppressPackageStartupMessages(library(optparse))
library(ggplot2)
library(cubar)
suppressPackageStartupMessages(library(Biostrings))
suppressPackageStartupMessages(library(data.table))

# Pin data.table to a single thread.
setDTthreads(1)

# Parse command line arguments
option_list <- list(
    make_option(c("-i", "--input"), type = "character", default = NULL,
                metavar = "FILE",
                help = "Input CDS FASTA file (nucleotide sequences). [required]"),
    make_option(c("-o", "--output"), type = "character", default = NULL,
                metavar = "DIR",
                help = "Output directory; created if it does not exist. [required]"),
    make_option(c("-s", "--species"), type = "character", default = NULL,
                metavar = "TAG",
                help = paste0("Species tag used as a suffix on the output file ",
                              "names (e.g. BalGla). [required]"))
)
opt <- parse_args(OptionParser(option_list = option_list))

# Validate the required arguments
if (is.null(opt$input) || is.null(opt$output) || is.null(opt$species)) {
    stop("All of --input, --output and --species are required. ",
         "Use --help for details.", call. = FALSE)
}

# Resolve the input path before changing directories so that relative
# paths are interpreted from the launch directory.
cds_f <- normalizePath(opt$input, mustWork = TRUE)
species <- opt$species

# Set up the output directory
work <- opt$output
if (!dir.exists(work)) {
    dir.create(work, recursive = TRUE)
}
setwd(work)

# Load and process the input sequences
cds <- readDNAStringSet(cds_f)
# cds <- readDNAStringSet(cds_f,
#                         nrec = 100)
message(paste0("Loaded ",
               length(cds),
               " sequences from the input CDS fasta."))

# Keep only the main sequence ID (everything before the first whitespace).
names(cds) <- sub("\\s.*$", "", names(cds))

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
message(paste0("    Median GC: ", median(gc_prop)))
message(paste0("    SD GC: ", sd(gc_prop)))

# Calculate the GC content at 3rd codon synonymous positions
message("Calculating GC content at synonymous 3rd codons positions.")
gc3s_prop <- cubar::get_gc3s(codons)
gc3s_df <- data.frame(transcript=names(gc3s_prop),
                      gc3s_prop=gc3s_prop)
message(paste0("    Mean GC3s: ", mean(gc3s_prop, na.rm = TRUE)))
message(paste0("    Median GC3s: ", median(gc3s_prop, na.rm = TRUE)))
message(paste0("    SD GC3s: ", sd(gc3s_prop, na.rm = TRUE)))
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
message(paste0("    Median GC4d: ", median(gc4d_prop, na.rm = TRUE)))
message(paste0("    SD GC4d: ", sd(gc4d_prop, na.rm = TRUE)))
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
message(paste0("    Median ENC: ", median(enc_sf)))
message(paste0("    SD ENC: ", sd(enc_sf)))
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
message(paste0("    Median ENC: ", median(enc_aa)))
message(paste0("    SD ENC: ", sd(enc_aa)))
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
message(paste0("    Median FOP: ", median(fop)))
message(paste0("    SD FOP: ", sd(fop)))
fop_df <- data.frame(transcript=names(fop),
                     fop=fop,
                     row.names=NULL)
out_df <- dplyr::inner_join(out_df,
                            fop_df,
                            by = 'transcript')
rm(fop_df)

# Calculate the ENC deviation from Wright's expected curve.
# Under pure mutational pressure (no selection) ENC is a function of GC3s:
#   ENC_exp = 2 + s + 29 / (s^2 + (1 - s)^2),   where s = GC3s (proportion).
message("Calculating the ENC deviation from Wright's expected curve.")
enc_expected <- function(s) 2 + s + 29 / (s^2 + (1 - s)^2)
enc_exp <- enc_expected(out_df$gc3s_prop)
out_df$enc_dev <- (enc_exp - out_df$enc_subfam) / enc_exp
message(paste0("    Mean ENC deviation: ",
               mean(out_df$enc_dev, na.rm = TRUE)))
message(paste0("    Median ENC deviation: ",
               median(out_df$enc_dev, na.rm = TRUE)))

# Curve-aware regression of observed ENC on the composition-expected ENC.
message("Regressing observed ENC on the composition-expected ENC.")
enc_fit <- lm(out_df$enc_subfam ~ enc_exp)
enc_reg_slope     <- unname(coef(enc_fit)[2])
enc_reg_intercept <- unname(coef(enc_fit)[1])
enc_reg_r2        <- summary(enc_fit)$r.squared
enc_reg_n         <- sum(!is.na(enc_exp) & !is.na(out_df$enc_subfam))
message(paste0("    Slope: ", enc_reg_slope))
message(paste0("    Intercept: ", enc_reg_intercept))
message(paste0("    R2: ", enc_reg_r2))

# Save the final per-gene table into a file
write.table(out_df,
            file = paste0('./codon_bias_', species, '.tsv'),
            quote = FALSE,
            sep = '\t',
            row.names = FALSE)

# Write a genome-wide summary of the per-gene statistics.
num_cols <- names(out_df)[vapply(out_df, is.numeric, logical(1))]
summary_df <- do.call(rbind, lapply(num_cols, function(col) {
    x <- out_df[[col]]
    data.frame(
        metric  = col,
        n_genes = sum(!is.na(x)),
        mean    = mean(x, na.rm = TRUE),
        median  = median(x, na.rm = TRUE),
        sd      = sd(x, na.rm = TRUE),
        min     = min(x, na.rm = TRUE),
        q25     = stats::quantile(x, 0.25, na.rm = TRUE),
        q75     = stats::quantile(x, 0.75, na.rm = TRUE),
        max     = max(x, na.rm = TRUE),
        row.names = NULL
    )
}))

# Append the ENC ~ expected-ENC regression results as extra rows.
reg_rows <- data.frame(
    metric  = c("enc_reg_slope", "enc_reg_intercept", "enc_reg_R2"),
    n_genes = enc_reg_n,
    mean    = c(enc_reg_slope, enc_reg_intercept, enc_reg_r2),
    median  = NA_real_, sd = NA_real_, min = NA_real_,
    q25     = NA_real_, q75 = NA_real_, max = NA_real_,
    row.names = NULL
)
summary_df <- rbind(summary_df, reg_rows)

write.table(summary_df,
            file = paste0('./genome_summary_', species, '.tsv'),
            quote = FALSE,
            sep = '\t',
            row.names = FALSE)
message(paste0("Wrote genome-wide summary for ", nrow(out_df),
               " genes to genome_summary_", species, ".tsv"))

# Plot the ENC distribution
plt <- ggplot(out_df, aes(x=enc_subfam)) +
    geom_histogram(fill="grey85",
                   color="black",
                   binwidth = 1) +
    geom_vline(xintercept = mean(out_df$enc_subfam),
               color = "firebrick",
               linetype = "dashed") +
    geom_vline(xintercept = median(out_df$enc_subfam),
               color = "mediumseagreen",
               linetype = "dotted") +
    labs(x = "Effective number of codons",
         y = "Number of transcripts",
         caption = paste0("n = ", nrow(out_df), " genes; ",
                          "mean ENC = ", round(mean(out_df$enc_subfam), 2),
                          "; median ENC = ",
                          round(median(out_df$enc_subfam), 2))) +
    theme_bw()

ggsave(paste0('./enc_', species, '.pdf'), plot=plt, width=4, height=4)
ggsave(paste0('./enc_', species, '.png'), plot=plt, width=4, height=4, dpi=300)

# Gene length vs ENC.
message("Making the gene length vs ENC scatter plot.")
plt_len <- ggplot(out_df, aes(x = len_bp, y = enc_subfam)) +
    geom_point(alpha = 0.3, size = 1) +
    geom_smooth(method = "loess", color = "firebrick", se = FALSE) +
    scale_x_log10() +
    labs(x = "Gene length (bp, log10 scale)",
         y = "Effective number of codons",
         title = paste0("Gene length vs ENC: ", species)) +
    theme_bw()

ggsave(paste0('./len_enc_', species, '.pdf'), plot=plt_len, width=5, height=4)
ggsave(paste0('./len_enc_', species, '.png'), plot=plt_len, width=5, height=4,
       dpi=300)


# Codon usage differences between high- and low-bias genes.
message("Estimating codon usage differences between low- and high-ENC genes.")
enc_rank <- sort(enc_sf[!is.na(enc_sf)])
n_set <- floor(0.10 * length(enc_rank))
low_enc_ids  <- names(head(enc_rank, n_set))   # strongest codon bias
high_enc_ids <- names(tail(enc_rank, n_set))   # weakest codon bias
message(paste0("    Contrasting ", n_set,
               " low-ENC genes vs ", n_set, " high-ENC genes."))

du_test <- cubar::codon_diff(cds[low_enc_ids], cds[high_enc_ids])

# Per-codon-family plot
du_test2 <- du_test[!amino_acid %in% c('Met', 'Trp'), ]
du_test2$codon <- factor(du_test2$codon,
                         levels = sort(unique(as.character(du_test2$codon))))

plt_diff <- ggplot(du_test2, aes(x = codon, y = log2(fam_or))) +
    geom_col() +
    labs(x = NULL, y = 'log2(OR)') +
    facet_grid(cols = vars(amino_acid), space = 'free',
               scales = 'free', drop = TRUE) +
    theme_light() +
    theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1))

ggsave(paste0('./codon_diff_', species, '.pdf'),
       plot = plt_diff, width = 10, height = 4)
ggsave(paste0('./codon_diff_', species, '.png'),
       plot = plt_diff, width = 10, height = 4, dpi = 300)


# ENC-plot: ENC vs GC3s, with Wright's expected curve.
message("Making the ENC vs GC3s plot with Wright's expected curve.")

# Summarise the deviation to annotate the plot.
mean_dev <- mean(out_df$enc_dev, na.rm = TRUE)
median_dev <- median(out_df$enc_dev, na.rm = TRUE)

plt_enc <- ggplot(out_df, aes(x = gc3s_prop, y = enc_subfam)) +
    stat_function(fun = enc_expected, color = "red", linewidth = 1,
                  xlim = c(0, 1)) +
    geom_point(aes(color = log10(len_bp)), alpha = 0.5, size = 1.4) +
    scale_color_viridis_c(name = "log10 gene\nlength (bp)") +
    coord_cartesian(xlim = c(0, 1), ylim = c(20, 61)) +
    labs(x = "GC proportion at 3rd codon position",
         y = "Effective number of codons",
         title = paste0("ENC-plot: ", species),
         subtitle = paste0("Red = Wright's expected curve (no selection)\n",
                           "ENC deviation: mean = ", round(mean_dev, 4),
                           ", median = ", round(median_dev, 4))) +
    theme_bw(base_size = 12)

ggsave(paste0('./enc_gc3s_', species, '.pdf'),
       plot = plt_enc, width = 6, height = 5)
ggsave(paste0('./enc_gc3s_', species, '.png'),
       plot = plt_enc, width = 6, height = 5, dpi = 300)

# ENC regression plot
message("Making the observed-vs-expected ENC regression plot.")
reg_df <- data.frame(enc_exp = enc_exp, enc_obs = out_df$enc_subfam,
                     len_bp = out_df$len_bp)

plt_reg <- ggplot(reg_df, aes(x = enc_exp, y = enc_obs)) +
    geom_abline(slope = 1, intercept = 0,
                linetype = "dashed", color = "grey50") +
    geom_point(aes(color = log10(len_bp)), alpha = 0.5, size = 1.4) +
    scale_color_viridis_c(name = "log10 gene\nlength (bp)") +
    geom_abline(slope = enc_reg_slope, intercept = enc_reg_intercept,
                color = "firebrick", linewidth = 1) +
    labs(x = "Expected ENC (Wright's curve)",
         y = "Effective number of codons",
         title = paste0("ENC regression: ", species),
         subtitle = paste0("Firebrick = fit, dashed = y = x\n",
                           "slope = ", round(enc_reg_slope, 3),
                           ", intercept = ", round(enc_reg_intercept, 2),
                           ", R2 = ", round(enc_reg_r2, 3))) +
    theme_bw(base_size = 12)

ggsave(paste0('./enc_regression_', species, '.pdf'),
       plot = plt_reg, width = 6, height = 5)
ggsave(paste0('./enc_regression_', species, '.png'),
       plot = plt_reg, width = 6, height = 5, dpi = 300)

