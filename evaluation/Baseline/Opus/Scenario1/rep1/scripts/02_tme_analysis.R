# Step 2: subgrouping of deconvolution features (multideconv), immune / stromal scoring,
# patient stratification and association with response for the Gide cohort.
# Input:  results/deconvolution_raw.rds (from 01_deconvolution.R), data/Gide_log2TPM.txt, data/colData_all.txt
# Output: results/*.csv, results/figures/*.pdf, results/Results/ (multideconv outputs)

suppressPackageStartupMessages({
  library(multideconv)
  library(ComplexHeatmap)
  library(circlize)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
})

proj_dir <- normalizePath(".")
res_dir  <- file.path(proj_dir, "results")
fig_dir  <- file.path(res_dir, "figures")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

# ---------------------------------------------------------------- inputs
expr <- as.matrix(read.delim(file.path(proj_dir, "data/Gide_log2TPM.txt"),
                             check.names = FALSE, row.names = 1))
clin <- read.table(file.path(proj_dir, "data/colData_all.txt"), header = TRUE)
clin <- clin[clin$Cohort == "Gide", ]
rownames(clin) <- clin$rna_id
clin <- clin[colnames(expr), ]

deconv <- readRDS(file.path(res_dir, "deconvolution_raw.rds"))
# multideconv passes the matrix through data.frame(), which prefixes names starting with a digit
rownames(deconv) <- colnames(expr)[match(rownames(deconv), make.names(colnames(expr)))]
stopifnot(!anyNA(rownames(deconv)), all(rownames(deconv) == rownames(clin)))
write.csv(deconv, file.path(res_dir, "deconvolution_all_methods_signatures.csv"))

# ---------------------------------------------------------------- cell type compartments
immune_types <- c("B.cells", "B.naive.cells", "B.memory.cells", "Plasma",
                  "Macrophages.cells", "Macrophages.M0", "Macrophages.M1", "Macrophages.M2",
                  "Monocytes", "Myeloid.cells", "Dendritic.cells", "Dendritic.activated.cells",
                  "Dendritic.resting.cells", "Dendritic.plasmacytoid.cells",
                  "Neutrophils", "Eosinophils", "Basophils",
                  "Mast.cells", "Mast.activated.cells", "Mast.resting.cells",
                  "NK.cells", "NK.activated", "NK.resting", "NKT.cells",
                  "CD4.cells", "CD4.memory.activated", "CD4.memory.resting", "CD4.naive",
                  "CD4.regulatory", "CD4.non.regulatory", "T.cells.helper", "T.cells.gamma.delta",
                  "CD8.cells", "T.cells.proliferative")
stromal_types <- c("Fibroblasts", "CAF", "Endothelial", "Pericytes", "Mural.cells", "Myocytes")
cancer_types  <- c("Cancer", "uncharacterized.cell")

compartment_of <- function(ct) {
  ifelse(ct %in% immune_types, "Immune",
         ifelse(ct %in% stromal_types, "Stromal",
                ifelse(ct %in% cancer_types, "Cancer/other", "Unassigned")))
}

# ---------------------------------------------------------------- 1. consensus compartment fractions
# Only method-signature combinations that model the whole tissue (cancer + stroma + immune)
# give absolute fractions; immune-only signatures (TIL10, LM22, PBMC, Zilionis) always sum to 1.
feat_ct    <- sub(".*_", "", colnames(deconv))
feat_combo <- sub("_[^_]+$", "", colnames(deconv))
whole_tissue <- unique(feat_combo[feat_ct == "Cancer"])
cat("Whole-tissue combinations:", paste(whole_tissue, collapse = ", "), "\n")

frac_by_combo <- function(compartment) {
  sapply(whole_tissue, function(k) {
    idx <- feat_combo == k & compartment_of(feat_ct) == compartment
    rowSums(deconv[, idx, drop = FALSE])
  })
}
immune_frac  <- frac_by_combo("Immune")
stromal_frac <- frac_by_combo("Stromal")
cancer_frac  <- frac_by_combo("Cancer/other")
# quanTIseq: everything that is not one of its 10 immune types is "uncharacterized" (tumour + stroma)
immune_frac  <- cbind(immune_frac, Quantiseq_TIL10 = 1 - deconv[, "Quantiseq_TIL10_uncharacterized.cell"])
write.csv(immune_frac,  file.path(res_dir, "immune_fraction_per_method_signature.csv"))
write.csv(stromal_frac, file.path(res_dir, "stromal_fraction_per_method_signature.csv"))
write.csv(cancer_frac,  file.path(res_dir, "cancer_fraction_per_method_signature.csv"))

# Immune fraction: median of all 10 whole-tissue estimates (all contain immune references; this
# consensus agrees best with PTPRC / T cell / IFNG marker expression).
# Cancer and stromal fractions: only the melanoma scRNA-seq signature contains melanoma malignant
# cells; HNSCC / Vanderbilt (lung) references misassign tumour cells to other compartments
# (see signature_validation_vs_markers.csv), so these use the tissue-matched signature (3 methods).
tissue_matched <- grep("Melanoma", whole_tissue, value = TRUE)
fractions <- data.frame(
  sample                    = rownames(deconv),
  Immune_fraction           = apply(immune_frac, 1, median),
  Stromal_fraction          = apply(stromal_frac[, tissue_matched], 1, median),
  Cancer_fraction           = apply(cancer_frac[, tissue_matched], 1, median),
  Immune_fraction_Quantiseq = immune_frac[, "Quantiseq_TIL10"],
  Immune_fraction_melanoma_sig = apply(immune_frac[, tissue_matched], 1, median)
)

# agreement between methods on the immune fraction
imm_agree <- cor(immune_frac, method = "spearman")
write.csv(round(imm_agree, 3), file.path(res_dir, "immune_fraction_method_agreement_spearman.csv"))

# ---------------------------------------------------------------- 2. multideconv subgrouping
setwd(res_dir)  # multideconv writes into Results/
sub_res <- compute.deconvolution.analysis(deconv, corr = 0.7, corr_type = "spearman",
                                          zero_thr = 0.9, cv_thr = 0.1,
                                          file_name = "Gide", return = TRUE, verbose = TRUE)
setwd(proj_dir)
saveRDS(sub_res, file.path(res_dir, "deconvolution_subgroups.rds"))

sub_mat <- sub_res[["Deconvolution matrix"]]
groups  <- sub_res[["Deconvolution subgroups composition"]]
write.csv(sub_res[["Discarded features with high number of zeros"]],
          file.path(res_dir, "discarded_features_high_zeros.csv"))

# number of method-signature features summarised by each column (subgroups = median of members)
group_size <- unlist(lapply(groups, function(g) setNames(lengths(g), names(g))), use.names = FALSE)
names(group_size) <- unlist(lapply(groups, names), use.names = FALSE)
feat_n  <- ifelse(colnames(sub_mat) %in% names(group_size), group_size[colnames(sub_mat)], 1)
feat_ct_sub <- ifelse(grepl("_Subgroup\\.", colnames(sub_mat)),
                      sub("_Subgroup\\..*", "", colnames(sub_mat)),
                      sub(".*_", "", colnames(sub_mat)))

feature_info <- data.frame(feature = colnames(sub_mat), cell_type = feat_ct_sub,
                           compartment = compartment_of(feat_ct_sub), n_method_signatures = feat_n,
                           members = sapply(colnames(sub_mat), function(f) {
                             if (f %in% names(group_size))
                               paste(unlist(lapply(groups, function(g) g[[f]])), collapse = "; ")
                             else f
                           }))
write.csv(feature_info, file.path(res_dir, "subgrouped_feature_annotation.csv"), row.names = FALSE)

# ---------------------------------------------------------------- 3. consensus cell type scores
# z-score every feature across patients, then average per cell type weighting each feature by the
# number of method-signature estimates it summarises (consensus subgroups weigh more than singletons)
z <- scale(as.matrix(sub_mat))
z[is.na(z)] <- 0
cell_types <- unique(feat_ct_sub)
ct_scores <- sapply(cell_types, function(ct) {
  idx <- feat_ct_sub == ct
  as.vector(z[, idx, drop = FALSE] %*% feat_n[idx]) / sum(feat_n[idx])
})
rownames(ct_scores) <- rownames(sub_mat)
ct_comp <- compartment_of(colnames(ct_scores))
write.csv(ct_scores, file.path(res_dir, "cell_type_consensus_scores_z.csv"))

# compartment-level relative scores (mean of cell type z-scores, weighted by supporting features)
ct_weight <- tapply(feat_n, feat_ct_sub, sum)[colnames(ct_scores)]
comp_score <- function(comp) {
  idx <- ct_comp == comp
  as.vector(ct_scores[, idx, drop = FALSE] %*% ct_weight[idx]) / sum(ct_weight[idx])
}
scores <- data.frame(sample = rownames(ct_scores),
                     Immune_score  = comp_score("Immune"),
                     Stromal_score = comp_score("Stromal"))

# ---------------------------------------------------------------- 4. marker gene validation
markers <- list(
  Immune_PTPRC      = "PTPRC",
  T_cells           = c("CD3D", "CD3E", "CD2"),
  CD8_T             = c("CD8A", "CD8B"),
  Cytolytic         = c("GZMA", "PRF1"),
  B_cells           = c("CD19", "MS4A1", "CD79A"),
  Myeloid           = c("CD68", "CD163", "CD14"),
  IFNG_signature    = c("IFNG", "STAT1", "CXCL9", "CXCL10", "IDO1", "HLA-DRA"),
  Fibroblasts       = c("COL1A1", "COL1A2", "COL3A1", "DCN", "FAP"),
  Endothelial       = c("PECAM1", "VWF", "CDH5"),
  Melanoma          = c("MLANA", "PMEL", "TYR", "MITF"),
  Lymph_node        = c("CCR7", "SELL", "CR2", "LTB")
)
marker_scores <- sapply(markers, function(g) {
  g <- intersect(g, rownames(expr))
  colMeans(expr[g, , drop = FALSE])
})
write.csv(marker_scores, file.path(res_dir, "marker_gene_scores_log2TPM.csv"))

# per method-signature validation of the compartment fractions against marker genes
sig_valid <- rbind(
  data.frame(compartment = "Immune", combination = colnames(immune_frac),
             rho_marker = cor(immune_frac, marker_scores[, "Immune_PTPRC"], method = "spearman")[, 1],
             marker = "PTPRC", median_fraction = apply(immune_frac, 2, median)),
  data.frame(compartment = "Cancer", combination = colnames(cancer_frac),
             rho_marker = cor(cancer_frac, marker_scores[, "Melanoma"], method = "spearman")[, 1],
             marker = "MLANA/PMEL/TYR/MITF", median_fraction = apply(cancer_frac, 2, median)),
  data.frame(compartment = "Stromal", combination = colnames(stromal_frac),
             rho_marker = cor(stromal_frac, marker_scores[, "Fibroblasts"], method = "spearman")[, 1],
             marker = "COL1A1/COL1A2/COL3A1/DCN/FAP", median_fraction = apply(stromal_frac, 2, median)))
sig_valid$used_in_consensus <- sig_valid$compartment == "Immune" | sig_valid$combination %in% tissue_matched
write.csv(sig_valid, file.path(res_dir, "signature_validation_vs_markers.csv"), row.names = FALSE)

# sample QC flags: tumour-poor / lymph node-like biopsies and low-content libraries
lib_tpm <- colSums(2^expr - 1)
z_rob <- function(x) (x - median(x)) / mad(x)
flag <- character(ncol(expr)); names(flag) <- colnames(expr)
flag[z_rob(marker_scores[, "Melanoma"]) < -3] <- "tumour-poor"
ln <- z_rob(marker_scores[, "Lymph_node"]) > 3
flag[ln] <- ifelse(flag[ln] == "", "lymph-node-like", paste(flag[ln], "lymph-node-like", sep = "; "))
lowlib <- lib_tpm < 0.1 * median(lib_tpm)  # sums are < 1e6 because the matrix is gene-filtered
flag[lowlib] <- ifelse(flag[lowlib] == "", "low TPM sum", paste(flag[lowlib], "low TPM sum", sep = "; "))

all_scores <- merge(merge(fractions, scores, by = "sample"),
                    data.frame(sample = rownames(marker_scores), marker_scores), by = "sample")
all_scores <- merge(all_scores, data.frame(sample = rownames(ct_scores),
                                           CD8_score = ct_scores[, "CD8.cells"],
                                           Fibroblast_score = ct_scores[, "Fibroblasts"],
                                           CAF_score = ct_scores[, "CAF"]), by = "sample")
validation <- cor(all_scores[, c("Immune_fraction", "Immune_score", "CD8_score", "Stromal_fraction",
                                 "Stromal_score", "Fibroblast_score", "CAF_score", "Cancer_fraction")],
                  all_scores[, names(markers)], method = "spearman")
write.csv(round(validation, 3), file.path(res_dir, "score_vs_marker_genes_spearman.csv"))

# ---------------------------------------------------------------- 5. patient stratification
# Primary infiltration metric: consensus immune fraction (absolute, validated against PTPRC).
# Immune_score (weighted mean z of immune cell types) is kept as a secondary, relative index.
all_scores <- merge(all_scores, clin[, c("rna_id", "Response", "Therapy")],
                    by.x = "sample", by.y = "rna_id")
all_scores$QC_flag <- flag[all_scores$sample]
tert <- quantile(all_scores$Immune_fraction, c(1/3, 2/3))
all_scores$Immune_class <- cut(all_scores$Immune_fraction, c(-Inf, tert, Inf),
                               labels = c("Immune-low", "Immune-intermediate", "Immune-high"))
all_scores$Stromal_class <- ifelse(all_scores$Stromal_fraction > median(all_scores$Stromal_fraction),
                                   "Stroma-high", "Stroma-low")
all_scores$Immune_rank <- rank(-all_scores$Immune_fraction)

# unsupervised TME clusters on the consensus cell type scores
hc <- hclust(dist(ct_scores), method = "ward.D2")
tme_cluster <- cutree(hc, k = 3)
all_scores$TME_cluster <- paste0("C", tme_cluster[all_scores$sample])

all_scores <- all_scores[order(all_scores$Immune_rank), ]
write.csv(all_scores, file.path(res_dir, "patient_immune_stromal_scores.csv"), row.names = FALSE)

# ---------------------------------------------------------------- 6. association with response
test_vars <- cbind(ct_scores[all_scores$sample, ],
                   as.matrix(all_scores[, c("Immune_score", "Stromal_score", "Immune_fraction",
                                            "Stromal_fraction", "Cancer_fraction")]))
test_response <- function(keep) {
  resp <- all_scores$Response[keep]
  out <- do.call(rbind, lapply(colnames(test_vars), function(v) {
    x <- test_vars[keep, v]
    wt <- wilcox.test(x[resp == "R"], x[resp == "NR"], exact = FALSE)
    auc <- unname(wt$statistic) / (sum(resp == "R") * sum(resp == "NR"))
    data.frame(variable = v, compartment = ifelse(v %in% colnames(ct_scores), compartment_of(v), "Summary"),
               median_R = median(x[resp == "R"]), median_NR = median(x[resp == "NR"]),
               AUC_R_vs_NR = auc, p_value = wt$p.value)
  }))
  out$FDR <- p.adjust(out$p_value, "BH")
  out[order(out$p_value), ]
}
assoc <- test_response(rep(TRUE, nrow(all_scores)))
write.csv(assoc, file.path(res_dir, "association_with_response_wilcoxon.csv"), row.names = FALSE)
# sensitivity: exclude QC-flagged samples
assoc_qc <- test_response(all_scores$QC_flag == "")
write.csv(assoc_qc, file.path(res_dir, "association_with_response_wilcoxon_excl_flagged.csv"),
          row.names = FALSE)

class_tab <- table(all_scores$Immune_class, all_scores$Response)
write.csv(as.data.frame.matrix(class_tab), file.path(res_dir, "immune_class_vs_response.csv"))
fisher_p <- fisher.test(class_tab)$p.value
class_by_therapy <- table(all_scores$Immune_class, all_scores$Response, all_scores$Therapy)
write.csv(as.data.frame(class_by_therapy), file.path(res_dir, "immune_class_vs_response_by_therapy.csv"),
          row.names = FALSE)
cluster_tab <- table(all_scores$TME_cluster, all_scores$Response)
write.csv(as.data.frame.matrix(cluster_tab), file.path(res_dir, "tme_cluster_vs_response.csv"))

# ---------------------------------------------------------------- 7. figures
resp_col  <- c(R = "#1b9e77", NR = "#d95f02")
class_col <- c("Immune-low" = "#4575b4", "Immune-intermediate" = "#ffffbf", "Immune-high" = "#d73027")
comp_col  <- c(Immune = "#e41a1c", Stromal = "#4daf4a", "Cancer/other" = "#377eb8")
ther_col  <- c(PD1 = "#7570b3", "CTLA4+PD1" = "#e7298a")
clus_col  <- setNames(c("#66a61e", "#e6ab02", "#a6761d"), paste0("C", 1:3))

ord <- all_scores$sample
top_ann <- HeatmapAnnotation(
  Immune_fraction = anno_barplot(all_scores$Immune_fraction, gp = gpar(fill = "grey40")),
  Stromal_fraction = all_scores$Stromal_fraction,
  Immune_class   = all_scores$Immune_class,
  TME_cluster    = all_scores$TME_cluster,
  Response       = all_scores$Response,
  Therapy        = all_scores$Therapy,
  QC_flag        = ifelse(all_scores$QC_flag == "", "ok", "flagged"),
  col = list(Immune_class = class_col, Response = resp_col, Therapy = ther_col, TME_cluster = clus_col,
             QC_flag = c(ok = "white", flagged = "black"),
             Stromal_fraction = colorRamp2(c(0, 0.5, 1), c("white", "#4daf4a", "darkgreen"))),
  annotation_height = unit(c(1.5, rep(0.4, 6)), "cm"))
row_split <- factor(ct_comp, levels = c("Immune", "Stromal", "Cancer/other"))
hm <- Heatmap(t(ct_scores[ord, ]), name = "z-score",
              col = colorRamp2(c(-2, 0, 2), c("#2166ac", "white", "#b2182b")),
              top_annotation = top_ann, row_split = row_split, cluster_row_slices = FALSE,
              cluster_columns = FALSE, column_split = all_scores$Immune_class,
              row_names_gp = gpar(fontsize = 8), column_names_gp = gpar(fontsize = 6),
              column_title = "Consensus cell type scores (multideconv subgroups), patients ordered by immune fraction")
pdf(file.path(fig_dir, "heatmap_cell_type_scores.pdf"), width = 16, height = 11)
draw(hm, merge_legend = TRUE)
dev.off()

hm2 <- Heatmap(t(ct_scores), name = "z-score",
               col = colorRamp2(c(-2, 0, 2), c("#2166ac", "white", "#b2182b")),
               cluster_columns = hc, column_split = 3, row_split = row_split, cluster_row_slices = FALSE,
               top_annotation = HeatmapAnnotation(
                 Response = clin[rownames(ct_scores), "Response"],
                 Therapy = clin[rownames(ct_scores), "Therapy"],
                 col = list(Response = resp_col, Therapy = ther_col)),
               row_names_gp = gpar(fontsize = 8), column_names_gp = gpar(fontsize = 6),
               column_title = "Unsupervised TME clusters (Ward.D2 on consensus cell type scores)")
pdf(file.path(fig_dir, "heatmap_tme_clusters.pdf"), width = 16, height = 10)
draw(hm2, merge_legend = TRUE)
dev.off()

# compartment composition (consensus absolute fractions)
comp_long <- all_scores |>
  transmute(sample, Immune = Immune_fraction, Stromal = Stromal_fraction, `Cancer/other` = Cancer_fraction) |>
  mutate(across(-sample, ~ .x / (Immune + Stromal + `Cancer/other`))) |>
  pivot_longer(-sample, names_to = "Compartment", values_to = "Fraction") |>
  mutate(sample = factor(sample, levels = ord),
         Compartment = factor(Compartment, levels = c("Cancer/other", "Stromal", "Immune")))
p <- ggplot(comp_long, aes(sample, Fraction, fill = Compartment)) +
  geom_col(width = 0.9) + scale_fill_manual(values = comp_col) +
  labs(x = NULL, y = "Consensus fraction (rescaled to 1)",
       title = "TME compartments per patient (immune: 10 whole-tissue estimates; cancer/stroma: CBSX-Melanoma x 3 methods)") +
  theme_bw() + theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5, size = 6))
ggsave(file.path(fig_dir, "compartment_fractions_per_patient.pdf"), p, width = 14, height = 5)

# quanTIseq immune composition
q <- deconv[, grepl("^Quantiseq_", colnames(deconv))]
colnames(q) <- sub("Quantiseq_TIL10_", "", colnames(q))
q_long <- data.frame(sample = rownames(q), q, check.names = FALSE) |>
  pivot_longer(-sample, names_to = "Cell_type", values_to = "Fraction") |>
  mutate(sample = factor(sample, levels = ord))
p <- ggplot(q_long, aes(sample, Fraction, fill = Cell_type)) + geom_col(width = 0.9) +
  scale_fill_brewer(palette = "Paired") + theme_bw() +
  labs(x = NULL, title = "quanTIseq (TIL10) cell fractions, ordered by immune fraction") +
  theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5, size = 6))
ggsave(file.path(fig_dir, "quantiseq_composition.pdf"), p, width = 14, height = 5)

# ranked immune fraction
rank_df <- all_scores |>
  mutate(label = paste0(sample, ifelse(QC_flag == "", "", " *")))
p <- ggplot(rank_df, aes(reorder(label, Immune_fraction), Immune_fraction, fill = Immune_class)) +
  geom_col() + coord_flip() + scale_fill_manual(values = class_col) +
  geom_text(aes(label = Response, y = Immune_fraction + 0.03), size = 2.2) +
  labs(x = NULL, y = "Consensus immune fraction",
       title = "Patients ranked by immune infiltration", caption = "* QC-flagged sample") +
  theme_bw() + theme(axis.text.y = element_text(size = 6))
ggsave(file.path(fig_dir, "immune_fraction_ranking.pdf"), p, width = 7, height = 11)

# immune fraction vs marker genes
val_long <- all_scores |>
  select(sample, Immune_fraction, Immune_PTPRC, CD8_T, Cytolytic, IFNG_signature) |>
  pivot_longer(c(Immune_PTPRC, CD8_T, Cytolytic, IFNG_signature), names_to = "Marker", values_to = "log2TPM")
rho_lab <- val_long |> group_by(Marker) |>
  summarise(label = sprintf("rho = %.2f", cor(Immune_fraction, log2TPM, method = "spearman")))
p <- ggplot(val_long, aes(Immune_fraction, log2TPM)) + geom_point(size = 1) +
  geom_smooth(method = "lm", se = FALSE, colour = "red", formula = y ~ x) +
  geom_text(data = rho_lab, aes(x = -Inf, y = Inf, label = label), hjust = -0.1, vjust = 1.5, size = 3) +
  facet_wrap(~Marker, scales = "free_y") + theme_bw() +
  labs(title = "Immune fraction vs immune marker expression (independent of deconvolution)")
ggsave(file.path(fig_dir, "immune_fraction_vs_markers.pdf"), p, width = 8, height = 6)

# response boxplots for the summary scores and top cell types
top_ct <- head(assoc$variable[assoc$compartment != "Summary"], 6)
box_vars <- c("Immune_fraction", "Stromal_fraction", "Cancer_fraction", top_ct)
box_long <- data.frame(sample = all_scores$sample, Response = all_scores$Response,
                       test_vars[, box_vars], check.names = FALSE) |>
  pivot_longer(all_of(box_vars), names_to = "Variable", values_to = "Value") |>
  mutate(Variable = factor(Variable, levels = box_vars))
lab <- assoc[match(box_vars, assoc$variable), ]
lab$label <- sprintf("p=%.3g\nFDR=%.2g", lab$p_value, lab$FDR)
lab$Variable <- factor(lab$variable, levels = box_vars)
p <- ggplot(box_long, aes(Response, Value, fill = Response)) +
  geom_boxplot(outlier.shape = NA, alpha = 0.7) + geom_jitter(width = 0.15, size = 0.8) +
  geom_text(data = lab, aes(x = 1.5, y = Inf, label = label), inherit.aes = FALSE,
            vjust = 1.2, size = 2.8) +
  facet_wrap(~Variable, scales = "free_y", ncol = 3) + scale_fill_manual(values = resp_col) +
  scale_y_continuous(expand = expansion(mult = c(0.05, 0.3))) + theme_bw() +
  labs(title = "Pre-treatment TME vs response (Wilcoxon)")
ggsave(file.path(fig_dir, "response_boxplots.pdf"), p, width = 10, height = 9)

# method agreement on immune fraction
pdf(file.path(fig_dir, "immune_fraction_method_agreement.pdf"), width = 8, height = 7)
draw(Heatmap(imm_agree, name = "Spearman", col = colorRamp2(c(-1, 0, 1), c("blue", "white", "red")),
             cell_fun = function(j, i, x, y, w, h, f) grid.text(sprintf("%.2f", imm_agree[i, j]), x, y,
                                                                  gp = gpar(fontsize = 7)),
             column_title = "Agreement of total immune fraction across method-signatures"))
dev.off()

# ---------------------------------------------------------------- summary to console
cat("\n=== Subgrouped features:", ncol(sub_mat), "| cell types:", ncol(ct_scores), "\n")
cat("\n=== Score validation (Spearman with marker genes)\n"); print(round(validation, 2))
cat("\n=== Median immune fraction:", round(median(all_scores$Immune_fraction), 3),
    " stromal:", round(median(all_scores$Stromal_fraction), 3),
    " cancer:", round(median(all_scores$Cancer_fraction), 3), "\n")
cat("\n=== Signature validation\n"); print(sig_valid[, -1], digits = 2)
cat("\n=== QC flags\n"); print(all_scores[all_scores$QC_flag != "", c("sample", "QC_flag")])
show_cols <- c("sample", "Immune_fraction", "Immune_score", "CD8_score", "Stromal_fraction",
               "Cancer_fraction", "Immune_class", "TME_cluster", "Response", "Therapy", "QC_flag")
cat("\n=== Immune-high patients\n")
print(all_scores[all_scores$Immune_class == "Immune-high", show_cols], digits = 3)
cat("\n=== Immune-low patients\n")
print(all_scores[all_scores$Immune_class == "Immune-low", show_cols], digits = 3)
cat("\n=== Immune class vs response (Fisher p =", signif(fisher_p, 3), ")\n"); print(class_tab)
print(class_by_therapy)
cat("\n=== Association excluding flagged samples (top 10)\n"); print(head(assoc_qc, 10), digits = 3)
cat("\n=== TME cluster vs response\n"); print(cluster_tab)
cat("\n=== Cluster mean cell type scores\n")
print(round(t(apply(ct_scores, 2, function(x) tapply(x, tme_cluster, mean))), 2))
cat("\n=== Association with response (top 15)\n"); print(head(assoc, 15), digits = 3)
