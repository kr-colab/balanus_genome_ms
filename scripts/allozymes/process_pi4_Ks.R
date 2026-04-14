#!/usr/bin/env Rscript

# Plot synonymous substitution rate/nucleotide diversity for the allozymes
library(dplyr)
library(ggplot2)
library(slider)
library(purrr)
library(cowplot)
library(gridExtra)

setwd("/sietch_colab/data_share/balanus/comp_genomics/dnds/20250820.dnds_pairwise/pairwise_ks")

# Input files
bed_f <- './transcripts.bed'
degen_df <- './degeneracy-all-sites.bed'
pi_f <- './BalGla_degen4_pi.txt'
ks_f <- './silent_substitutions_BalGla.tsv'
map_f <- './sco_rename_map.tsv'

# General parameters for windows
window_size <- 99
window_step <- 24
codon_size <- 3

# Jukes-Cantor correction for synonymous substitutions.
# Suppress warnings from invalid log inputs (e.g., D outside domain).
jc_correct <- function(D) {
  suppressWarnings((-(3/4) * log(1 - (4/3) * D)))
}

# Synonymous substitution rate: substitutions / sites.
# Suppress warnings from numerical errors (e.g., division by zero).
calc_syn_subs_rate <- function(n_subs, n_sites) {
  suppressWarnings(n_subs / n_sites)
}

# Pi/Ks ratio with Inf -> NaN guard.
# Suppress warnings from numerical errors.
calc_pi_ks <- function(avg_pi, Ks) {
  piKs <- suppressWarnings(avg_pi / Ks)
  ifelse(is.infinite(piKs), NaN, piKs)
}

# Load the orthogroup - gene ID map
# Load this first because we will use it to filter out genes
# not among the ortholog set from downstream analyses
map_df <- read.delim(map_f, header=F)
colnames(map_df) <- c('OrthoGroupID', 'GeneID')
# For troubleshooting
# map_df <- map_df %>% slice_sample(n = 25) %>% arrange(OrthoGroupID)
message(paste('Loaded gene IDs for', nrow(map_df), 'orthologs.'))

# Load the exonic boundaries for each transcript
bed_df <- read.delim(bed_f, header=F)
colnames(bed_df) <- c('chromosome', 'startBP', 'endBP', 'cds', 'gene')
bed_df <- bed_df %>%
  mutate(exonLen = endBP-startBP) %>%
  # Filter out genes if they're not in the ortholog set
  filter(gene %in% map_df$GeneID) %>%
  # Add a running tally of the exons per gene
  group_by(gene) %>%
  mutate(exonN = row_number()) %>%
  ungroup() %>%
  # Create a new exon ID based on the gene ID
  mutate(exon = paste0(gene, '.', exonN)) %>%
  select(-cds)
message(paste('Loaded intervals for', nrow(bed_df), 'exons across',
              length(unique(bed_df$gene)), 'genes.'))

# Load the degeneracy at each coding site
degen_df <- read.delim(degen_df, header=F) %>%
  # Filter out genes if they're not in the ortholog set
  # Doing this early to avoid loading the large BED into memory
  filter(V4 %in% map_df$GeneID)
colnames(degen_df) <- c('chromosome', 'startBP', 'endBP', 'gene',
                        'position', 'degeneracy', 'nt', 'aa', 'substitutions')
# Map each single-base site to its exon
bed_intervals <- bed_df %>%
  select(chromosome, startBP, endBP, exon) %>%
  rename(exon_startBP = startBP, exon_endBP = endBP)
degen_df <- degen_df %>%
  select(-substitutions, -nt, -aa) %>%
  left_join(
    bed_intervals,
    by = join_by(
      chromosome,
      startBP >= exon_startBP,
      startBP < exon_endBP
    ),
    relationship = 'many-to-many'
  ) %>%
  select(-exon_startBP, -exon_endBP)
rm(bed_intervals)
message(paste('Loaded degeneracy for', nrow(degen_df), 'sites across',
              length(unique(degen_df$gene)), 'genes.'))

# Load the nucleotide diversity at each coding site
pi_df <- read.delim(pi_f) %>%
  select(chromosome, window_pos_1, avg_pi, count_diffs, count_comparisons) %>%
  rename('bp' = 'window_pos_1') %>%
  filter(!is.na(avg_pi))
message(paste('Loaded Pi for', nrow(pi_df), 'sites.'))

# Load synonymous substitution rate
ks_df <- read.delim(ks_f) %>%
  rename('OrthoGroupID' = 'GeneID') %>%
  # Add the right gene ID to the Ks dataframe
  inner_join(map_df,
    by = c('OrthoGroupID' = 'OrthoGroupID'),
    relationship = 'many-to-many') %>%
  select(-OrthoGroupID)
rm(map_df)
message(paste('Loaded Ks for', nrow(ks_df), 'sites across',
    length(unique(ks_df$GeneID)), 'genes.'))

# Add the degeneracy to the pi table
# Select only Pi_4 sites
pi_4dg_df <- inner_join(pi_df, degen_df,
  by = c('chromosome' = 'chromosome',
    'bp' = 'endBP'),
  relationship = 'many-to-many') %>%
  select(-startBP) %>%
  filter(degeneracy == 4)
rm(pi_df)
rm(degen_df)
message(paste('Merged 4-fold Pi for', nrow(pi_4dg_df),
    'sites across', length(unique(pi_4dg_df$gene)), 'genes.'))

# Add the Ks to the Pi_4 table
pi4_ks_df <- inner_join(pi_4dg_df, ks_df,
  by = c('gene' = 'GeneID',
         'position' = 'InGrpPos')) %>%
  select(-InGrpSite, -OutGrpSite, -degeneracy)
message(paste('Merged Pi4 and Ks', nrow(pi4_ks_df), 'sites across',
    length(unique(pi4_ks_df$gene)), 'genes.'))
rm(ks_df)
rm(pi_4dg_df)

# Genes to process
gene_ids <- unique(pi4_ks_df$gene)

message('Summarising across windows...')
# Create a dataframe with window summaries across all genes
all_window_dat <- purrr::map_dfr(gene_ids, function(gene_id) {

  # First, we do a pass and aggregate Pi and Ks per codon
  codon_rows <- pi4_ks_df %>%
    filter(gene == gene_id) %>%
    select(-chromosome, -bp, -gene) %>%
    mutate(window = ((position %/% codon_size) * codon_size)) %>%
    group_by(window) %>%
    summarise(
      position = max(position, na.rm = TRUE),
      cnt.diffs = sum(count_diffs, na.rm = TRUE),
      cnt.comps = sum(count_comparisons, na.rm = TRUE),
      avg.pi4 = (cnt.diffs / cnt.comps),
      diffs.n = sum(DiffsInSite, na.rm = TRUE),
      syn.sites.n = sum(SynSitesN, na.rm = TRUE),
      syn.subs.n = sum(SynSubsN, na.rm = TRUE),
      syn.subs.rate = calc_syn_subs_rate(syn.subs.n, syn.sites.n),
      codon.sites.n = n()
    )

  if (nrow(codon_rows) < 1) return(NULL)

  # Then, we do a second pass where we aggregate these values over larger
  # windows. We also apply the JC correction once we see more sites
  max_pos <- max(codon_rows$position, na.rm = TRUE)
  if (!is.finite(max_pos)) return(NULL)
  starts <- seq(0, max_pos, by = window_step)
  purrr::map_dfr(starts, function(s) {
    window_rows <- codon_rows %>%
      filter(position >= s & position < s + window_size)
    if (nrow(window_rows) < 1) return(NULL)
    summarise(window_rows,
      gene_id = gene_id,
      start = s,
      end = s + window_size,
      mean.position = mean(position, na.rm = TRUE),
      cnt.diffs = sum(cnt.diffs, na.rm = TRUE),
      cnt.comps = sum(cnt.comps, na.rm = TRUE),
      avg.pi4 = (cnt.diffs / cnt.comps),
      diffs.n = sum(diffs.n, na.rm = TRUE),
      syn.sites.n = sum(syn.sites.n, na.rm = TRUE),
      syn.subs.n = sum(syn.subs.n, na.rm = TRUE),
      syn.subs.rate = calc_syn_subs_rate(syn.subs.n, syn.sites.n),
      Ks.adj = jc_correct(syn.subs.rate),
      pi4.Ks = calc_pi_ks(avg.pi4, Ks.adj),
      codon.sites.n = n(),
      .groups = 'drop'
    )
  })
})

message(paste('    Processed', nrow(all_window_dat), 'windows across',
              length(unique(all_window_dat$gene_id)), 'genes.'))
write.table(all_window_dat, file = 'all_window_Pi4Ks.tsv', sep = '\t',
  row.names = FALSE, quote = FALSE)

message('Summarising across exons...')
# Create exon-level summary across all genes
all_exon_dat <- purrr::map_dfr(gene_ids, function(gene_id) {
  # Get positional information for the exons of the target gene
  gene_bed <- bed_df %>%
    filter(gene == gene_id) %>%
    arrange(exonN)

  # Subset once per gene, then summarise each exon and row-bind
  gene_pi4_ks <- pi4_ks_df %>%
    filter(gene == gene_id)

  purrr::map_dfr(seq_len(nrow(gene_bed)), function(i) {
    # Get the info specific for that exon
    exon_id <- gene_bed[[i, 'exon']]
    chromosome <- gene_bed[[i, 'chromosome']]
    exon_start <- gene_bed[[i, 'startBP']]
    exon_end <- gene_bed[[i, 'endBP']]
    # Get filtered data for this exon
    exon_pi4_ks <- gene_pi4_ks %>%
      filter(exon == exon_id)
    # Apply the per-exon stats
    summarise(exon_pi4_ks,
      gene_id = first(gene_id),
      exon_id = first(exon_id),
      chromosome = first(chromosome),
      start = first(exon_start),
      end = first(exon_end),
      cnt.diffs = sum(count_diffs, na.rm = TRUE),
      cnt.comps = sum(count_comparisons, na.rm = TRUE),
      avg.pi4 = (cnt.diffs / cnt.comps),
      diffs.n = sum(DiffsInSite, na.rm = TRUE),
      syn.sites.n = sum(SynSitesN, na.rm = TRUE),
      syn.subs.n = sum(SynSubsN, na.rm = TRUE),
      syn.subs.rate = calc_syn_subs_rate(syn.subs.n, syn.sites.n),
      Ks.adj = jc_correct(syn.subs.rate),
      pi4.Ks = calc_pi_ks(avg.pi4, Ks.adj),
      n.sites = n(),
      .groups = 'drop'
    )
  })
})

message(paste('    Processed', nrow(all_exon_dat), 'exons across',
              length(unique(all_exon_dat$gene_id)), 'genes.'))

write.table(all_exon_dat, file = 'all_exon_Pi4Ks.tsv', sep = '\t',
  row.names = FALSE, quote = FALSE)


