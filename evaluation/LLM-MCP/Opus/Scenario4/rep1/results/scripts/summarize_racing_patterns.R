# Summarize the most common cell-cell communication patterns from the RaCInG kernel output
# (Gide cohort). Inputs: racing_inputs/result.rds, racing_kernel/result.rds,
# sample_id_mapping.csv. Run from the results/ directory.
suppressPackageStartupMessages({ library(ggplot2); library(pheatmap) })

out_dir <- "patterns"
dir.create(out_dir, showWarnings = FALSE)

inputs <- readRDS("racing_inputs/result.rds")
kern <- readRDS("racing_kernel/result.rds")
map <- read.csv("sample_id_mapping.csv")

feat <- as.matrix(kern$features)
rownames(feat) <- map$original[match(rownames(feat), map$racing_id)]
stopifnot(!anyNA(rownames(feat)))
write.csv(feat, file.path(out_dir, "Gide_direct_communication_features.csv"))

# ---- map every feature to its two cell types -------------------------------------------
ct <- inputs$celltypes
pairs <- expand.grid(i = seq_along(ct), j = seq_along(ct))
pairs <- pairs[pairs$i <= pairs$j, ]
pairs$feature <- paste0("Dir_", ct[pairs$i], "_", ct[pairs$j])
pairs$feature_rev <- paste0("Dir_", ct[pairs$j], "_", ct[pairs$i])
idx <- match(colnames(feat), pairs$feature)
idx_rev <- match(colnames(feat), pairs$feature_rev)
idx[is.na(idx)] <- idx_rev[is.na(idx)]
stopifnot(!anyNA(idx))
cell_a <- ct[pairs$i[idx]]
cell_b <- ct[pairs$j[idx]]

# Cell-type label (subgroups -> their cell type; single features -> method_signature_<cell>)
label_of <- function(x) ifelse(grepl("_Subgroup\\.", x), sub("_Subgroup\\..*", "", x),
                               sapply(strsplit(x, "_"), function(p) paste(p[-(1:2)], collapse = "_")))
# Broad lineage
lineage_map <- c(
  B.cells = "B cells", B.memory.cells = "B cells", B.naive.cells = "B cells", Plasma = "Plasma cells",
  CAF = "Fibroblasts/CAF", Fibroblasts = "Fibroblasts/CAF", Cancer = "Cancer cells",
  CD4.cells = "CD4 T cells", CD4.memory.activated = "CD4 T cells", CD4.memory.resting = "CD4 T cells",
  CD4.naive = "CD4 T cells", CD4.non.regulatory = "CD4 T cells", T.cells.helper = "CD4 T cells",
  CD4.regulatory = "Tregs", CD8.cells = "CD8 T cells", T.cells.gamma.delta = "gd T cells",
  T.cells.proliferative = "Proliferating T cells", NKT.cells = "NKT cells",
  NK.activated = "NK cells", NK.cells = "NK cells", NK.resting = "NK cells",
  Dendritic.activated.cells = "Dendritic cells", Dendritic.cells = "Dendritic cells",
  Dendritic.resting.cells = "Dendritic cells",
  Macrophages.cells = "Macrophages", Macrophages.M0 = "Macrophages", Macrophages.M1 = "Macrophages",
  Macrophages.M2 = "Macrophages", Monocytes = "Monocytes", Myeloid.cells = "Myeloid cells",
  Mast.cells = "Mast cells", Mast.activated.cells = "Mast cells", Mast.resting.cells = "Mast cells",
  Neutrophils = "Neutrophils", Eosinophils = "Eosinophils",
  Endothelial = "Endothelial cells", Mural.cells = "Mural cells/pericytes", Pericytes = "Mural cells/pericytes",
  Myocytes = "Myocytes")
lab_a <- label_of(cell_a); lab_b <- label_of(cell_b)
stopifnot(all(c(lab_a, lab_b) %in% names(lineage_map)))
lin_a <- lineage_map[lab_a]; lin_b <- lineage_map[lab_b]
# order lineage pair alphabetically (features are direction-merged)
lin_pair <- ifelse(lin_a <= lin_b, paste(lin_a, "<->", lin_b), paste(lin_b, "<->", lin_a))

# ---- 1. cell-type pair level ------------------------------------------------------------
top_n <- 50
rank_in_patient <- t(apply(-feat, 1, rank, ties.method = "min"))
pair_stats <- data.frame(
  feature = colnames(feat), cell_A = cell_a, cell_B = cell_b,
  lineage_A = unname(lin_a), lineage_B = unname(lin_b), lineage_pair = unname(lin_pair),
  median_score = apply(feat, 2, median), mean_score = colMeans(feat),
  sd_score = apply(feat, 2, sd),
  frac_patients_nonzero = colMeans(feat > 0),
  frac_patients_in_top50 = colMeans(rank_in_patient <= top_n),
  median_rank_in_patient = apply(rank_in_patient, 2, median))
pair_stats <- pair_stats[order(-pair_stats$median_score), ]
pair_stats$cohort_rank <- seq_len(nrow(pair_stats))
write.csv(pair_stats, file.path(out_dir, "celltype_pair_statistics.csv"), row.names = FALSE)

# ---- 2. lineage pair level --------------------------------------------------------------
# Per patient: mean score over all features of that lineage pair; then cohort summaries.
lp_levels <- unique(lin_pair)
lp_patient <- sapply(lp_levels, function(lp) rowMeans(feat[, lin_pair == lp, drop = FALSE]))
lp_rank <- t(apply(-lp_patient, 1, rank, ties.method = "min"))
top100 <- head(pair_stats$feature, 100)
lin_stats <- data.frame(
  lineage_pair = lp_levels,
  n_features = as.integer(table(lin_pair)[lp_levels]),
  median_score = apply(lp_patient, 2, median), mean_score = colMeans(lp_patient),
  frac_patients_in_top10 = colMeans(lp_rank <= 10),
  median_rank_in_patient = apply(lp_rank, 2, median),
  n_features_in_cohort_top100 = sapply(lp_levels, function(lp) sum(lin_pair[match(top100, colnames(feat))] == lp)))
lin_stats <- lin_stats[order(-lin_stats$median_score), ]
write.csv(lin_stats, file.path(out_dir, "lineage_pair_statistics.csv"), row.names = FALSE)
write.csv(lp_patient, file.path(out_dir, "lineage_pair_scores_per_patient.csv"))

# Lineage x lineage heatmap of cohort-median score (log10)
lins <- sort(unique(c(lin_a, lin_b)))
M <- matrix(NA, length(lins), length(lins), dimnames = list(lins, lins))
for (r in seq_len(nrow(lin_stats))) {
  p <- strsplit(lin_stats$lineage_pair[r], " <-> ")[[1]]
  M[p[1], p[2]] <- M[p[2], p[1]] <- lin_stats$median_score[r]
}
pdf(file.path(out_dir, "lineage_pair_heatmap.pdf"), width = 11, height = 10)
pheatmap(log10(M + 1e-6), main = "Gide: median direct communication (log10), lineage pairs",
         color = colorRampPalette(c("white", "orange", "darkred"))(100), na_col = "grey90")
dev.off()

# Top-25 cell-type pairs: per-patient distribution
top25 <- head(pair_stats, 25)
long <- data.frame(feature = rep(top25$feature, each = nrow(feat)),
                   score = as.vector(feat[, top25$feature]))
long$label <- factor(paste(top25$cell_A, "<->", top25$cell_B)[match(long$feature, top25$feature)],
                     levels = rev(paste(top25$cell_A, "<->", top25$cell_B)))
g <- ggplot(long, aes(label, score)) + geom_boxplot(outlier.size = 0.6, fill = "steelblue", alpha = 0.5) +
  coord_flip() + scale_y_log10() + theme_bw(base_size = 9) +
  labs(x = NULL, y = "Direct communication score (log10)", title = "Gide: top 25 cell-type pairs (cohort median)")
ggsave(file.path(out_dir, "top25_celltype_pairs_boxplot.pdf"), g, width = 11, height = 8)

top15l <- head(lin_stats, 15)
g2 <- ggplot(top15l, aes(reorder(lineage_pair, median_score), median_score)) +
  geom_col(fill = "darkorange") + coord_flip() + theme_bw(base_size = 10) +
  labs(x = NULL, y = "Cohort median of per-patient mean score", title = "Gide: top 15 lineage pairs")
ggsave(file.path(out_dir, "top15_lineage_pairs_barplot.pdf"), g2, width = 9, height = 6)

cat("Top 20 cell-type pairs:\n")
print(head(pair_stats[, c("cell_A", "cell_B", "median_score", "frac_patients_nonzero",
                          "frac_patients_in_top50")], 20), row.names = FALSE)
cat("\nTop 20 lineage pairs:\n")
print(head(lin_stats, 20), row.names = FALSE)
cat("\nLineage of the cohort top-100 cell-type pairs:\n")
print(sort(table(lin_pair[match(top100, colnames(feat))]), decreasing = TRUE))
