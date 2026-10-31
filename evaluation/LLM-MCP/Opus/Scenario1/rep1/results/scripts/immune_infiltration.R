# Immune / stromal composition and immune-infiltration ranking for the Gide cohort,
# built from multideconv output (results/01_deconvolution, results/02_harmonized_subgroups).
suppressPackageStartupMessages({
  library(ggplot2); library(tidyr); library(dplyr); library(ComplexHeatmap); library(circlize)
})
setwd("/home/marcelo.hurtado/Documents/tme_analysis/0760e3f28f/work")
out <- "results/03_immune_infiltration"; dir.create(out, showWarnings = FALSE, recursive = TRUE)

raw  <- read.csv("results/01_deconvolution/result.csv", row.names = 1, check.names = FALSE)
harm <- read.csv("results/02_harmonized_subgroups/result_Deconvolution.matrix.csv", row.names = 1, check.names = FALSE)
cd   <- read.csv("results/input/Gide_coldata.csv", row.names = 1, check.names = FALSE)
# R prefixed sample names starting with a digit with "X": restore the original IDs
fix_ids <- function(x) sub("^X(?=[0-9])", "", x, perl = TRUE)
rownames(raw) <- fix_ids(rownames(raw)); rownames(harm) <- fix_ids(rownames(harm))
stopifnot(setequal(rownames(raw), rownames(cd)), identical(rownames(raw), rownames(harm)))

# ---- Compartment annotation of every method_signature_celltype feature ----
parts  <- strsplit(colnames(raw), "_")
combo  <- sapply(parts, function(z) paste(z[1:2], collapse = "_"))
ctype  <- sapply(parts, function(z) paste(z[-(1:2)], collapse = "_"))
stromal_types <- c("Endothelial", "CAF", "Fibroblasts", "Myocytes", "Mural.cells", "Pericytes")
tumor_types   <- c("Cancer", "Epithelial", "uncharacterized.cell")
compartment <- ifelse(ctype %in% stromal_types, "Stromal",
               ifelse(ctype %in% tumor_types, "Tumor/other", "Immune"))
lineage <- case_when(
  compartment == "Stromal" & ctype == "Endothelial" ~ "Endothelial",
  compartment == "Stromal" ~ "Fibroblasts/CAF/mural",
  compartment == "Tumor/other" ~ "Tumor/other",
  grepl("^CD4|^CD8|^T\\.cells|^NKT", ctype) ~ "T cells",
  grepl("^B\\.|^Plasma", ctype) ~ "B/plasma cells",
  grepl("^NK", ctype) ~ "NK cells",
  TRUE ~ "Myeloid cells")
annot <- data.frame(feature = colnames(raw), combo, cell_type = ctype, compartment, lineage)
write.csv(annot, file.path(out, "feature_compartment_annotation.csv"), row.names = FALSE)

# Only combinations whose signature includes non-immune compartments can measure infiltration
# (in immune-only signatures such as LM22 the immune fractions always sum to 1).
informative <- unique(annot$combo[annot$compartment != "Immune"])
frac_by <- function(comp) sapply(informative, function(cb) {
  cols <- annot$feature[annot$combo == cb & annot$compartment == comp]
  if (length(cols) == 0) return(rep(NA_real_, nrow(raw)))
  rowSums(raw[, cols, drop = FALSE])
})
immune  <- frac_by("Immune");  rownames(immune)  <- rownames(raw)
stromal <- frac_by("Stromal"); rownames(stromal) <- rownames(raw)
stromal <- stromal[, colSums(!is.na(stromal)) > 0, drop = FALSE]
write.csv(immune,  file.path(out, "immune_fraction_per_method_signature.csv"))
write.csv(stromal, file.path(out, "stromal_fraction_per_method_signature.csv"))

# Cross-method agreement on the immune fraction
agree <- cor(immune, method = "spearman")
write.csv(agree, file.path(out, "immune_fraction_cross_method_spearman.csv"))
pdf(file.path(out, "immune_fraction_cross_method_agreement.pdf"), width = 9, height = 8)
draw(Heatmap(agree, name = "Spearman", col = colorRamp2(c(-1, 0, 1), c("#2166AC", "white", "#B2182B")),
             column_title = "Agreement of total immune fraction across method x signature",
             cell_fun = function(j, i, x, y, w, h, f) grid.text(sprintf("%.2f", agree[i, j]), x, y, gp = gpar(fontsize = 6))))
dev.off()

# ---- Consensus scores: mean of per-combination z-scores (scale-free across methods) ----
consensus <- function(m) rowMeans(scale(m), na.rm = TRUE)
res <- data.frame(
  Sample = rownames(raw),
  Immune_score = consensus(immune),
  Immune_fraction_median = apply(immune, 1, median),
  Immune_fraction_IQR_low = apply(immune, 1, quantile, 0.25),
  Immune_fraction_IQR_high = apply(immune, 1, quantile, 0.75),
  Stromal_score = consensus(stromal),
  Stromal_fraction_median = apply(stromal, 1, median),
  Methods_agreeing_high = rowSums(sweep(immune, 2, apply(immune, 2, median), ">")) # n combos above their cohort median
)
res$Immune_rank <- rank(-res$Immune_score)
tert <- quantile(res$Immune_score, c(1/3, 2/3))
res$Infiltration_group <- factor(ifelse(res$Immune_score > tert[2], "High",
                                 ifelse(res$Immune_score <= tert[1], "Low", "Intermediate")),
                                 levels = c("High", "Intermediate", "Low"))
res <- cbind(res, cd[res$Sample, c("Therapy", "Response")])
res$Note <- ifelse(res$Sample == "8_PD1_PRE", "low total TPM in input matrix (~41k)", "")
res <- res[order(res$Immune_rank), ]
write.csv(res, file.path(out, "immune_infiltration_ranking.csv"), row.names = FALSE)

# ---- Lineage composition per patient (median across informative combos, renormalized) ----
lin_levels <- c("T cells", "B/plasma cells", "NK cells", "Myeloid cells", "Endothelial", "Fibroblasts/CAF/mural", "Tumor/other")
lin <- sapply(lin_levels, function(l) {
  per_combo <- sapply(informative, function(cb) {
    cols <- annot$feature[annot$combo == cb & annot$lineage == l]
    if (length(cols) == 0) rep(NA_real_, nrow(raw)) else rowSums(raw[, cols, drop = FALSE])
  })
  apply(per_combo, 1, median, na.rm = TRUE)
})
rownames(lin) <- rownames(raw); lin[is.na(lin)] <- 0
lin <- lin / rowSums(lin)
write.csv(lin, file.path(out, "lineage_composition_consensus.csv"))

ord <- res$Sample
lin_long <- as.data.frame(lin) %>% mutate(Sample = rownames(lin)) %>%
  pivot_longer(-Sample, names_to = "Lineage", values_to = "Fraction") %>%
  mutate(Sample = factor(Sample, levels = ord), Lineage = factor(Lineage, levels = rev(lin_levels)))
pal <- c("T cells" = "#D7301F", "B/plasma cells" = "#FC8D59", "NK cells" = "#FDCC8A", "Myeloid cells" = "#7B3294",
         "Endothelial" = "#1A9850", "Fibroblasts/CAF/mural" = "#91CF60", "Tumor/other" = "#BDBDBD")
grp_bounds <- cumsum(table(res$Infiltration_group))[1:2] + 0.5
p1 <- ggplot(lin_long, aes(Sample, Fraction, fill = Lineage)) + geom_col(width = 1) +
  geom_vline(xintercept = grp_bounds, linetype = "dashed") +
  scale_fill_manual(values = pal) + scale_y_continuous(labels = scales::percent, expand = c(0, 0)) +
  labs(title = "Gide cohort: consensus TME composition (median across 13 method x signature combinations)",
       subtitle = "Patients ordered by consensus immune score (High | Intermediate | Low tertiles)", x = NULL, y = "Fraction") +
  theme_classic(base_size = 10) + theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1, size = 6))
ggsave(file.path(out, "lineage_composition_stacked.pdf"), p1, width = 14, height = 5.5)

p2 <- ggplot(res, aes(reorder(Sample, -Immune_score), Immune_fraction_median, colour = Infiltration_group)) +
  geom_pointrange(aes(ymin = Immune_fraction_IQR_low, ymax = Immune_fraction_IQR_high), size = 0.25) +
  scale_colour_manual(values = c(High = "#B2182B", Intermediate = "#F4A582", Low = "#4393C3")) +
  scale_y_continuous(labels = scales::percent) +
  labs(title = "Total immune fraction per patient", subtitle = "Median and IQR across the 13 method x signature combinations",
       x = NULL, y = "Immune fraction", colour = "Infiltration") +
  theme_classic(base_size = 10) + theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1, size = 6))
ggsave(file.path(out, "immune_fraction_per_patient.pdf"), p2, width = 14, height = 5)

p3 <- ggplot(res, aes(Immune_score, Stromal_score, colour = Infiltration_group)) + geom_point(size = 2) +
  scale_colour_manual(values = c(High = "#B2182B", Intermediate = "#F4A582", Low = "#4393C3")) +
  labs(title = "Immune vs stromal consensus scores", x = "Immune score (mean z)", y = "Stromal score (mean z)", colour = "Infiltration") +
  theme_classic(base_size = 11)
ggsave(file.path(out, "immune_vs_stromal_score.pdf"), p3, width = 6, height = 5)

# ---- Heatmap of harmonized multideconv features (z-scored), patients ordered by immune score ----
hz <- t(scale(harm[ord, ])); hz[hz > 3] <- 3; hz[hz < -3] <- -3
feat_ct <- sub("_Subgroup\\.[0-9]+$", "", rownames(hz))
feat_ct <- ifelse(grepl("_", feat_ct), sapply(strsplit(feat_ct, "_"), function(z) paste(z[-(1:2)], collapse = "_")), feat_ct)
feat_comp <- ifelse(feat_ct %in% stromal_types, "Stromal", ifelse(feat_ct %in% tumor_types, "Tumor/other", "Immune"))
ha <- HeatmapAnnotation(Immune_score = res$Immune_score, Group = res$Infiltration_group,
                        col = list(Group = c(High = "#B2182B", Intermediate = "#F4A582", Low = "#4393C3"),
                                   Immune_score = colorRamp2(range(res$Immune_score), c("white", "#B2182B"))))
pdf(file.path(out, "harmonized_subgroups_heatmap.pdf"), width = 14, height = 26)
draw(Heatmap(hz, name = "z-score", top_annotation = ha, cluster_columns = FALSE,
             row_split = feat_comp, cluster_row_slices = FALSE, row_names_gp = gpar(fontsize = 5),
             column_names_gp = gpar(fontsize = 6), col = colorRamp2(c(-3, 0, 3), c("#2166AC", "white", "#B2182B")),
             column_title = "multideconv harmonized features (194), patients ordered by immune score"))
dev.off()

# Cohort-level summary of lineage composition
summ <- data.frame(Lineage = lin_levels, Median = apply(lin, 2, median), Q1 = apply(lin, 2, quantile, .25), Q3 = apply(lin, 2, quantile, .75))
write.csv(summ, file.path(out, "cohort_lineage_summary.csv"), row.names = FALSE)
print(summ, digits = 3)
cat("\nMedian pairwise Spearman of immune fraction across combos:", round(median(agree[upper.tri(agree)]), 2), "\n")
print(round(sort(colMeans(agree)), 2))
cat("\nCorrelation immune vs stromal score:", round(cor(res$Immune_score, res$Stromal_score, method = "spearman"), 2), "\n")
print(head(res[, c("Sample","Immune_score","Immune_fraction_median","Stromal_fraction_median","Infiltration_group")], 15), digits = 3)
print(tail(res[, c("Sample","Immune_score","Immune_fraction_median","Stromal_fraction_median","Infiltration_group")], 10), digits = 3)
print(table(res$Infiltration_group))

# ---- Tissue-matched view: CBSX Melanoma scRNAseq signature (mean of its 4 methods) ----
# Non-melanoma signatures lack a melanocytic tumor reference, so their absolute stromal/tumor
# fractions are biased; the melanoma signature gives more realistic absolute proportions.
mel_combos <- grep("CBSX.Melanoma", informative, value = TRUE)
mel_types <- unique(annot$cell_type[annot$combo %in% mel_combos])
mel <- sapply(mel_types, function(ct) rowMeans(raw[, annot$feature[annot$combo %in% mel_combos & annot$cell_type == ct], drop = FALSE]))
rownames(mel) <- rownames(raw)
write.csv(mel, file.path(out, "melanoma_signature_composition.csv"))
mel_long <- as.data.frame(mel) %>% mutate(Sample = rownames(mel)) %>%
  pivot_longer(-Sample, names_to = "Cell_type", values_to = "Fraction") %>%
  mutate(Sample = factor(Sample, levels = ord),
         Cell_type = factor(Cell_type, levels = rev(c("CD8.cells", "CD4.cells", "NK.cells", "B.cells", "Macrophages.cells", "Endothelial", "CAF", "Cancer"))))
pal_mel <- c(CD8.cells = "#B2182B", CD4.cells = "#EF8A62", NK.cells = "#FDDBC7", B.cells = "#F1B6DA", Macrophages.cells = "#7B3294",
             Endothelial = "#1A9850", CAF = "#91CF60", Cancer = "#BDBDBD")
p4 <- ggplot(mel_long, aes(Sample, Fraction, fill = Cell_type)) + geom_col(width = 1) +
  geom_vline(xintercept = grp_bounds, linetype = "dashed") +
  scale_fill_manual(values = pal_mel) + scale_y_continuous(labels = scales::percent, expand = c(0, 0)) +
  labs(title = "Gide cohort: composition with the melanoma scRNAseq signature (mean of CBSX, DWLS, EpiDISH, DeconRNASeq)",
       subtitle = "Patients ordered by consensus immune score (High | Intermediate | Low tertiles)", x = NULL, y = "Fraction", fill = "Cell type") +
  theme_classic(base_size = 10) + theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1, size = 6))
ggsave(file.path(out, "melanoma_signature_composition_stacked.pdf"), p4, width = 14, height = 5.5)
cat("\nMelanoma signature, cohort median (Q1-Q3):\n")
print(round(t(apply(mel, 2, quantile, c(.25, .5, .75))), 3))
grp_mel <- aggregate(mel, list(Group = res[rownames(mel), "Infiltration_group"]), median)
print(grp_mel, digits = 2)
write.csv(grp_mel, file.path(out, "melanoma_signature_composition_by_group.csv"), row.names = FALSE)
