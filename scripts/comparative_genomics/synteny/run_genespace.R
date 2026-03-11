#!/usr/bin/env Rscript

library(GENESPACE)
library(ggplot2)

# Working dir
work <- '/sietch_colab/data_share/balanus/comp_genomics/genespace/20250715.orthofinder_barnacles.N3'
setwd(work)

# MCScanX executables
mcscanx_path <- '/home/ariverac/local/mambaforge/envs/genespace/MCScanX'

# Set the target species
spps <- c(
  'PolPol',
  'BalGla',
  'AmpAmp'
)
ref <- 'AmpAmp'

min_len <- 5e6
blk_size <- 2             # default is 5
blk_radius <- blk_size*2  # blk_size*5

# Set GENESPACE
gpar <- init_genespace(genomeIDs = spps,
                       path2mcscanx = mcscanx_path,
                       blkSize = blk_size,
                       blkRadius = blk_radius,
                       nCores = 8,
                       wd = work)

out <- run_genespace(gpar)


# Edit plots
palette <- c("#4575B4", "#D53E4F", "#FDAE61",
             "#1f9186", "#8073AC", "#FF7F00",
             "#DE77AE", "#919090")
customPal <- colorRampPalette(palette)

ggthemes <- ggplot2::theme(
  panel.background = ggplot2::element_rect(fill = "white"),
  axis.text.y = element_text(face="italic",size = 8))
useOrder <- FALSE

# pdf('Synteny.pdf', width = 6,height = 4)
ripPlt <- plot_riparian(
  gsParam = gsParam,
  refGenome = ref,
  genomeIDs = spps,
  palette = customPal,
  addThemes = ggthemes,
  reorderBySynteny = TRUE,
  useRegions = TRUE,
  useOrder = useOrder,
  braidAlpha = 0.75,
  minChrLen2plot = ifelse(useOrder, 100, min_len),
  chrFill = "grey90",
  forceRecalcBlocks = TRUE,
  xlabel = '',
  chrExpand = 0.2
)

pdf_f <- paste0('Synteny.ref_', ref, '.N', length(spps), '.pdf')
p1 <- ripPlt$plotData$ggplotObj
ggsave(pdf_f, p1, width = 8,height = 4)

