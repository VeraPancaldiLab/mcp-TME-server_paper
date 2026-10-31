#!/usr/bin/env Rscript
# TME (immune/stromal) characterization of the Gide melanoma ICB cohort using multideconv.

suppressPackageStartupMessages({
  library(multideconv)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(pheatmap)
  library(RColorBrewer)
})

set.seed(1)

work_dir <- "/home/marcelo.hurtado/Documents/tme_analysis/85d224db4e/work"
data_dir <- file.path(work_dir, "data")
results_dir <- file.path(work_dir, "results")

## ---- 1. Load data ----------------------------------------------------------

log2tpm <- read.delim(file.path(data_dir, "Gide_log2TPM.txt"), check.names = FALSE, row.names = 1)
coldata <- read.table(file.path(data_dir, "colData_all.txt"), header = TRUE, sep = " ", stringsAsFactors = FALSE)

gide_clin <- coldata[coldata$Cohort == "Gide", ]
stopifnot(setequal(colnames(log2tpm), gide_clin$Sample_id))
gide_clin <- gide_clin[match(colnames(log2tpm), gide_clin$Sample_id), ]
rownames(gide_clin) <- gide_clin$Sample_id

## Reverse log2(TPM + 1) back to linear TPM scale (multideconv expects raw counts or linear TPM)
tpm <- (2^as.matrix(log2tpm)) - 1
tpm[tpm < 0] <- 0

## ---- 2. Run deconvolution (first-generation methods, no scRNA-seq reference available) ----

old_wd <- getwd()
setwd(results_dir)

deconv <- compute.deconvolution(
  raw.counts = tpm,
  methods = c("Quantiseq", "Epidish", "DeconRNASeq", "DWLS"),
  normalized = FALSE,
  doParallel = TRUE,
  workers = 4,
  return = TRUE,
  file_name = "Gide"
)

## compute.deconvolution() builds its internal TPM data.frame with check.names = TRUE,
## which prepends "X" to sample IDs starting with a digit (all Gide IDs do). Restore
## the original sample IDs so they match the clinical table downstream.
name_map <- setNames(colnames(tpm), make.names(colnames(tpm)))
rownames(deconv) <- name_map[rownames(deconv)]
write.csv(deconv, file.path(results_dir, "Deconvolution_Gide.csv"))

## ---- 3. Reduce redundancy / build per-cell-type subgroups ------------------

analysis <- compute.deconvolution.analysis(
  deconv,
  corr = 0.7,
  corr_type = "spearman",
  return = TRUE,
  verbose = TRUE,
  file_name = "Gide"
)

## Flatten the package's hardcoded Results/ subfolder into results/
if (dir.exists("Results")) {
  for (f in list.files("Results", full.names = TRUE)) {
    file.rename(f, file.path(results_dir, basename(f)))
  }
  unlink("Results", recursive = TRUE)
}

setwd(old_wd)

subgroup_mat <- analysis[["Deconvolution matrix"]]

## ---- 4. Classify cell types into Immune / Stromal / Other ------------------

immune_cells <- c(
  "B.cells", "B.naive.cells", "B.memory.cells", "Macrophages.cells", "Macrophages.M0",
  "Macrophages.M1", "Macrophages.M2", "Monocytes", "Neutrophils", "NK.cells",
  "NK.activated", "NK.resting", "NKT.cells", "CD4.cells", "CD4.memory.activated",
  "CD4.memory.resting", "CD4.naive", "CD8.cells", "CD4.regulatory", "CD4.non.regulatory",
  "T.cells.helper", "T.cells.gamma.delta", "Dendritic.cells", "Dendritic.activated.cells",
  "Dendritic.resting.cells", "Eosinophils", "Plasma", "Mast.cells", "Mast.activated.cells",
  "Mast.resting.cells", "Dendritic.plasmacytoid.cells", "Myeloid.cells", "Basophils",
  "T.cells.proliferative"
)
stromal_cells <- c("Endothelial", "Myocytes", "Fibroblasts", "CAF", "Pericytes", "Mural.cells")
other_cells <- c("Cancer", "Epithelial", "uncharacterized_cell")

## Columns are either "<CellType>_Subgroup.<i>" (grouped features) or the raw
## "<method>_<signature>_<CellType>" (ungrouped singleton features, cell type
## names never contain "_" per multideconv's nomenclature).
extract_celltype <- function(x) {
  is_subgroup <- grepl("_Subgroup\\.[0-9]+$", x)
  out <- character(length(x))
  out[is_subgroup] <- sub("_Subgroup\\.[0-9]+$", "", x[is_subgroup])
  out[!is_subgroup] <- sub(".*_", "", x[!is_subgroup])
  out
}
celltype_of_subgroup <- extract_celltype(colnames(subgroup_mat))
category <- case_when(
  celltype_of_subgroup %in% immune_cells ~ "Immune",
  celltype_of_subgroup %in% stromal_cells ~ "Stromal",
  celltype_of_subgroup %in% other_cells ~ "Other",
  TRUE ~ "Unassigned"
)

feature_annot <- data.frame(
  Subgroup = colnames(subgroup_mat),
  Cell_type = celltype_of_subgroup,
  Category = category,
  row.names = colnames(subgroup_mat),
  check.names = FALSE
)
write.csv(feature_annot, file.path(results_dir, "Feature_cell_type_annotation_Gide.csv"), row.names = FALSE)

## ---- 5. Composite Immune / Stromal scores per sample ------------------------
## Two-level z-scoring: subgroups of the same cell type are first averaged (so a
## cell type estimated by many correlated method-signature combinations does not
## dominate), then cell types are averaged uniformly within each category.

z_subgroups <- scale(as.matrix(subgroup_mat))

celltype_z <- sapply(split(colnames(subgroup_mat), celltype_of_subgroup), function(cols) {
  rowMeans(z_subgroups[, cols, drop = FALSE])
})
rownames(celltype_z) <- rownames(subgroup_mat)

celltype_category <- case_when(
  colnames(celltype_z) %in% immune_cells ~ "Immune",
  colnames(celltype_z) %in% stromal_cells ~ "Stromal",
  colnames(celltype_z) %in% other_cells ~ "Other",
  TRUE ~ "Unassigned"
)

scores <- data.frame(
  Sample_id = rownames(celltype_z),
  Immune_Score = rowMeans(celltype_z[, celltype_category == "Immune", drop = FALSE]),
  Stromal_Score = rowMeans(celltype_z[, celltype_category == "Stromal", drop = FALSE]),
  Other_Score = rowMeans(celltype_z[, celltype_category == "Other", drop = FALSE]),
  check.names = FALSE
)
scores$Immune_minus_Stromal <- scores$Immune_Score - scores$Stromal_Score

scores <- merge(scores, gide_clin[, c("Sample_id", "Response", "Therapy")], by = "Sample_id")
scores <- scores[, c("Sample_id", "Immune_Score", "Stromal_Score", "Other_Score", "Immune_minus_Stromal", "Response", "Therapy")]

scores <- scores[order(-scores$Immune_Score), ]
scores$Immune_Rank <- seq_len(nrow(scores))

write.csv(scores, file.path(results_dir, "Immune_Stromal_scores_Gide.csv"), row.names = FALSE)

## ---- 6. Plots ---------------------------------------------------------------

## 6a. Ranked barplot of Immune Score per patient, colored by Response
plot_df <- scores
plot_df$Sample_id <- factor(plot_df$Sample_id, levels = plot_df$Sample_id[order(plot_df$Immune_Score)])

p_rank <- ggplot(plot_df, aes(x = Sample_id, y = Immune_Score, fill = Response)) +
  geom_col() +
  coord_flip() +
  scale_fill_manual(values = c(R = "#1b9e77", NR = "#d95f02")) +
  labs(title = "Gide cohort - immune infiltration ranking", x = NULL,
       y = "Immune Score (mean z-score across immune cell types)") +
  theme_minimal(base_size = 8) +
  theme(axis.text.y = element_text(size = 5))

ggsave(file.path(results_dir, "Immune_score_ranking_Gide.pdf"), p_rank, width = 7, height = 14)
ggsave(file.path(results_dir, "Immune_score_ranking_Gide.png"), p_rank, width = 7, height = 14, dpi = 300)

## 6b. Immune vs Stromal score scatter, colored by Response
p_scatter <- ggplot(scores, aes(x = Stromal_Score, y = Immune_Score, color = Response)) +
  geom_point(size = 2) +
  scale_color_manual(values = c(R = "#1b9e77", NR = "#d95f02")) +
  labs(title = "Immune vs stromal composite score - Gide cohort",
       x = "Stromal Score", y = "Immune Score") +
  theme_minimal(base_size = 11)

ggsave(file.path(results_dir, "Immune_vs_Stromal_scatter_Gide.pdf"), p_scatter, width = 6, height = 5)
ggsave(file.path(results_dir, "Immune_vs_Stromal_scatter_Gide.png"), p_scatter, width = 6, height = 5, dpi = 300)

## 6c. Immune / Stromal score by Response (boxplot + Wilcoxon test)
box_df <- scores %>%
  select(Sample_id, Response, Immune_Score, Stromal_Score) %>%
  pivot_longer(cols = c(Immune_Score, Stromal_Score), names_to = "Score_type", values_to = "Score")

wilcox_immune <- wilcox.test(Immune_Score ~ Response, data = scores)
wilcox_stromal <- wilcox.test(Stromal_Score ~ Response, data = scores)

p_box <- ggplot(box_df, aes(x = Response, y = Score, fill = Response)) +
  geom_boxplot(outlier.shape = NA) +
  geom_jitter(width = 0.15, size = 1, alpha = 0.6) +
  facet_wrap(~Score_type) +
  scale_fill_manual(values = c(R = "#1b9e77", NR = "#d95f02")) +
  labs(title = "Immune / stromal scores by response to ICB - Gide cohort",
       subtitle = sprintf("Wilcoxon p (Immune) = %.3g | p (Stromal) = %.3g",
                           wilcox_immune$p.value, wilcox_stromal$p.value),
       y = "Composite z-score") +
  theme_minimal(base_size = 11)

ggsave(file.path(results_dir, "Immune_Stromal_by_Response_Gide.pdf"), p_box, width = 7, height = 5)
ggsave(file.path(results_dir, "Immune_Stromal_by_Response_Gide.png"), p_box, width = 7, height = 5, dpi = 300)

## 6d. Heatmap of all cell-type level z-scores, samples ordered by Immune Score
sample_order <- scores$Sample_id
heat_mat <- t(celltype_z[sample_order, , drop = FALSE])

col_annot <- data.frame(
  Response = gide_clin[sample_order, "Response"],
  Therapy = gide_clin[sample_order, "Therapy"],
  row.names = sample_order
)
row_annot <- data.frame(
  Category = celltype_category,
  row.names = colnames(celltype_z)
)

ann_colors <- list(
  Response = c(R = "#1b9e77", NR = "#d95f02"),
  Category = c(Immune = "#377eb8", Stromal = "#984ea3", Other = "#999999", Unassigned = "#e0e0e0")
)

heat_mat[heat_mat > 3] <- 3
heat_mat[heat_mat < -3] <- -3

pheatmap(
  heat_mat,
  annotation_col = col_annot,
  annotation_row = row_annot,
  annotation_colors = ann_colors,
  cluster_cols = FALSE,
  cluster_rows = TRUE,
  show_colnames = FALSE,
  color = colorRampPalette(rev(brewer.pal(11, "RdBu")))(100),
  fontsize_row = 7,
  main = "Cell-type composite z-scores - Gide cohort (samples ranked by Immune Score)",
  filename = file.path(results_dir, "Heatmap_celltypes_Gide.pdf"),
  width = 12,
  height = 9
)
pheatmap(
  heat_mat,
  annotation_col = col_annot,
  annotation_row = row_annot,
  annotation_colors = ann_colors,
  cluster_cols = FALSE,
  cluster_rows = TRUE,
  show_colnames = FALSE,
  color = colorRampPalette(rev(brewer.pal(11, "RdBu")))(100),
  fontsize_row = 7,
  main = "Cell-type composite z-scores - Gide cohort (samples ranked by Immune Score)",
  filename = file.path(results_dir, "Heatmap_celltypes_Gide.png"),
  width = 12,
  height = 9,
  res = 300
)

## ---- 7. Run parameters log --------------------------------------------------

log_lines <- c(
  "Gide cohort TME characterization with multideconv",
  sprintf("Date: %s", Sys.Date()),
  sprintf("Samples: %d", nrow(scores)),
  "Input: data/Gide_log2TPM.txt, converted log2(TPM+1) -> linear TPM via 2^x - 1",
  "compute.deconvolution(methods = c('Quantiseq','Epidish','DeconRNASeq','DWLS'), normalized = FALSE, doParallel = TRUE, workers = 4)",
  "  (CBSX skipped: no CIBERSORTx credentials/Docker; MOMF skipped: no scRNA-seq reference available)",
  "compute.deconvolution.analysis(corr = 0.7, corr_type = 'spearman')",
  sprintf("Wilcoxon Immune Score R vs NR: p = %.4g", wilcox_immune$p.value),
  sprintf("Wilcoxon Stromal Score R vs NR: p = %.4g", wilcox_stromal$p.value),
  "Immune/Stromal/Other Score = mean of per-cell-type z-scores (cell types first averaged across their correlated subgroups, then averaged uniformly within category)"
)
writeLines(log_lines, file.path(results_dir, "analysis_log_Gide.txt"))

cat("Done. Results written to:", results_dir, "\n")
