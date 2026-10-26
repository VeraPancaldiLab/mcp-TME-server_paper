#!/usr/bin/env Rscript
suppressMessages(library(multideconv))

work_dir <- "/home/marcelo.hurtado/Documents/tme_analysis/9012cf463c/work"
run_dir <- file.path(work_dir, "run_tmp", "analysis")
dir.create(run_dir, showWarnings = FALSE, recursive = TRUE)
setwd(run_dir)

deconv <- readRDS(file.path(work_dir, "run_tmp", "gide_deconv_raw.rds"))

# ---- 1. Detailed cell-type subgroup analysis (full nomenclature) ----
deconv_subgroups <- compute.deconvolution.analysis(
  deconvolution = deconv,
  corr = 0.7,
  corr_type = "spearman",
  file_name = "Gide_celltypes",
  return = TRUE,
  verbose = TRUE
)
saveRDS(deconv_subgroups, file.path(work_dir, "run_tmp", "gide_subgroups_celltypes.rds"))
cat("Cell-type subgroup matrix dim:", dim(deconv_subgroups[["Deconvolution matrix"]]), "\n")

# ---- 2. Immune vs Stromal aggregation ----
immune_cells <- c(
  "B.cells", "B.naive.cells", "B.memory.cells",
  "Macrophages.cells", "Macrophages.M0", "Macrophages.M1", "Macrophages.M2",
  "Monocytes", "Neutrophils", "Eosinophils", "Basophils",
  "Mast.cells", "Mast.activated.cells", "Mast.resting.cells",
  "NK.cells", "NK.activated", "NK.resting", "NKT.cells",
  "CD4.cells", "CD4.memory.activated", "CD4.memory.resting", "CD4.naive",
  "CD4.regulatory", "CD4.non.regulatory", "CD8.cells",
  "T.cells.helper", "T.cells.gamma.delta", "T.cells.proliferative",
  "Dendritic.cells", "Dendritic.activated.cells", "Dendritic.resting.cells",
  "Dendritic.plasmacytoid.cells", "Plasma", "Myeloid.cells"
)
stromal_cells <- c("Endothelial", "Fibroblasts", "CAF", "Pericytes", "Mural.cells", "Myocytes")

groups <- list(Immune = immune_cells, Stromal = stromal_cells)
deconv_groups <- aggregate_cell_groups(deconv, cell_groups = groups, min_types = 2, verbose = TRUE)

deconv_groups_subgroups <- compute.deconvolution.analysis(
  deconvolution = deconv_groups,
  corr = 0.7,
  corr_type = "spearman",
  cells_extra = c("Immune", "Stromal"),
  file_name = "Gide_immune_stromal",
  return = TRUE,
  verbose = TRUE
)
saveRDS(deconv_groups_subgroups, file.path(work_dir, "run_tmp", "gide_subgroups_immune_stromal.rds"))

final_mat <- deconv_groups_subgroups[["Deconvolution matrix"]]
cat("Immune/Stromal matrix dim:", dim(final_mat), "\n")
cat("Columns:\n")
print(grep("Immune|Stromal", colnames(final_mat), value = TRUE))
