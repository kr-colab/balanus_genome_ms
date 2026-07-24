#!/usr/bin/env Rscript
suppressMessages({
  library(topGO)
  library(GO.db)
  library(dplyr)
  library(tidyr)
})

# ---- Parameters -----------------------------------------------------------
mk_file     <- "mkado_mkTest.out.tsv"
entap_file  <- "entap_out.no_contam.tsv"
node_size   <- 5       # prune GO terms with < node_size annotated genes
elim_cut    <- 0.05    # significance cutoff for the "significant" table (elim p)
ontologies  <- c("BP", "CC", "MF")
out_results <- "topgo_enrichment_results.tsv"
out_sig     <- "topgo_enrichment_significant.tsv"
out_log     <- "topgo_enrichment.log"

# ---- Logging helper (echo to console + collect for a log file) ------------
log_lines <- character(0)
logmsg <- function(...) {
  msg <- sprintf(...)
  cat(msg, "\n")
  log_lines[[length(log_lines) + 1]] <<- msg
}
logmsg("=== topGO enrichment run (core) ===")

# Load the MK test results
mkt.raw <- read.delim(mk_file, stringsAsFactors = FALSE)
n_mkt_total <- nrow(mkt.raw)
bonf <- 0.05 / n_mkt_total     # Bonferroni cutoff from the full file's gene count

mkt.df <- mkt.raw %>%
  drop_na() %>%                # remove rows with any NA
  filter(NI > 0) %>%           # remove NI = 0 to avoid log issues
  mutate(summary = case_when(
    p_value < bonf & -log10(NI) > 0.0 ~ "PosSignif",
    p_value < bonf & -log10(NI) < 0.0 ~ "NegSignif",
    TRUE                              ~ "Neutral"
  ))

candidates <- mkt.df$gene[mkt.df$summary == "PosSignif"]

logmsg("MK test file: %s", mk_file)
logmsg("  Total genes in MKT file            : %d", n_mkt_total)
logmsg("  Bonferroni cutoff (0.05/%d)         : %.3g", n_mkt_total, bonf)
logmsg("  Genes retained (drop_na & NI>0)    : %d", nrow(mkt.df))
for (cat_lbl in c("PosSignif", "NegSignif", "Neutral")) {
  logmsg("    %-10s                       : %d", cat_lbl, sum(mkt.df$summary == cat_lbl))
}
logmsg("  Candidates for enrichment (PosSignif): %d", length(candidates))

# Load EnTAP and map genes to GO annotations
en <- read.delim(entap_file, stringsAsFactors = FALSE,
  quote = "", check.names = FALSE)
go_cols <- grep("GO_", colnames(en), value = TRUE)
logmsg("")
logmsg("EnTAP file: %s", entap_file)
logmsg("  Pooling GO from %d columns: %s", length(go_cols), paste(go_cols, collapse = ", "))

extract_go <- function(...) {
  vals <- unlist(list(...))
  ids  <- unlist(regmatches(vals, gregexpr("GO:[0-9]{7}", vals)))
  unique(ids)
}
gene2GO <- lapply(seq_len(nrow(en)), function(i) {
  do.call(extract_go, as.list(en[i, go_cols]))
})
names(gene2GO) <- en$Query_Sequence
gene2GO <- gene2GO[lengths(gene2GO) > 0]          # keep annotated genes only

logmsg("  Genes seen in EnTAP                : %d", nrow(en))
logmsg("  Genes with >=1 GO term             : %d", length(gene2GO))

# Define the gene subsets
# universe = all genes with GO annotation
# background = significant MKT genes with GO annotation
universe        <- intersect(mkt.df$gene, names(gene2GO))
candidates_ann  <- intersect(candidates, universe)
logmsg("")
logmsg("Intersection (MK-tested & GO-annotated):")
logmsg("  Universe / background genes        : %d", length(universe))
logmsg("  MK-tested genes lacking GO (dropped): %d", length(setdiff(mkt.df$gene, names(gene2GO))))
logmsg("  Candidates (PosSignif) total       : %d", length(candidates))
logmsg("  Candidates with GO (used)          : %d", length(candidates_ann))
logmsg("  Candidates lacking GO (dropped)    : %d", length(setdiff(candidates, names(gene2GO))))
candidates <- candidates_ann

geneList <- factor(as.integer(universe %in% candidates), levels = c(0, 1))
names(geneList) <- universe

# Run topGO for each ontology class
run_ontology <- function(ont) {
  logmsg("")
  logmsg("=== Ontology %s ===", ont)
  GOdata <- new("topGOdata",
                ontology    = ont,
                allGenes    = geneList,
                annot       = annFUN.gene2GO,
                gene2GO     = gene2GO,
                nodeSize    = node_size)

  resClassic <- runTest(GOdata, algorithm = "classic", statistic = "fisher")
  resElim    <- runTest(GOdata, algorithm = "elim",    statistic = "fisher")

  all_go  <- usedGO(GOdata)
  tab <- GenTable(GOdata,
                  classicFisher = resClassic,
                  elimFisher    = resElim,
                  orderBy   = "elimFisher",
                  topNodes  = length(all_go),
                  numChar   = 1000)

  # numeric p-values
  pc <- score(resClassic); pe <- score(resElim)
  tab$classic_p <- pc[tab$GO.ID]
  tab$elim_p    <- pe[tab$GO.ID]
  # BH-FDR for both algorithms so any threshold can be applied downstream.
  # (topGO authors caution elim p-values are not independent; reported for
  #  completeness/filtering, not as a strict FDR guarantee.)
  tab$classic_fdr <- p.adjust(pc, method = "BH")[tab$GO.ID]
  tab$elim_fdr    <- p.adjust(pe, method = "BH")[tab$GO.ID]
  tab$Ontology  <- ont
  logmsg("  GO terms tested (nodeSize>=%d)      : %d", node_size, length(all_go))
  logmsg("  Enriched at elim p<%.2f (obs>exp)   : %d", elim_cut,
         sum(pe[tab$GO.ID] < elim_cut & tab$Significant > tab$Expected))
  tab
}

results <- bind_rows(lapply(ontologies, run_ontology))

# Format outputs and save
results <- results %>%
  transmute(Ontology, GO.ID, Term,
            Annotated, Significant, Expected,
            FoldEnrichment = Significant / Expected,
            classic_p, classic_fdr, elim_p, elim_fdr) %>%
  arrange(Ontology, elim_p)

write.table(results, out_results, sep = "\t", quote = FALSE, row.names = FALSE)
logmsg("")
logmsg("Wrote full results: %s (%d terms)", out_results, nrow(results))

# Enriched & significant: elim p < cutoff AND observed > expected
sig <- results %>% filter(elim_p < elim_cut, Significant > Expected)
write.table(sig, out_sig, sep = "\t", quote = FALSE, row.names = FALSE)
logmsg("Wrote significant enriched terms: %s (%d terms)", out_sig, nrow(sig))

# Write log
writeLines(log_lines, out_log)
cat(sprintf("\nWrote log: %s\nDone.\n", out_log))
