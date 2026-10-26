# Immune / stromal characterization of the Gide cohort from multideconv harmonized subgroups.
# Input : results/03_harmonized_subgroups (analyze_deconvolution) + results/input/Gide_coldata.csv
# Output: results/04_immune_stromal_summary/
suppressPackageStartupMessages({
  library(ggplot2); library(dplyr); library(tidyr); library(ggpubr)
  library(ComplexHeatmap); library(circlize); library(patchwork)
})
set.seed(123)
base <- "/home/marcelo.hurtado/Documents/tme_analysis/b329c858ac/work/results"
out  <- file.path(base, "04_immune_stromal_summary"); dir.create(out, showWarnings = FALSE)

m  <- read.csv(file.path(base, "03_harmonized_subgroups/result_Deconvolution.matrix.csv"),
               row.names = 1, check.names = FALSE)
rownames(m) <- sub("^X", "", rownames(m))          # R added an 'X' prefix to sample names
cd <- read.csv(file.path(base, "input/Gide_coldata.csv"), row.names = 1, check.names = FALSE)
stopifnot(all(rownames(m) %in% rownames(cd)))
cd <- cd[rownames(m), ]

# ---- Compartment scores ------------------------------------------------------------------
# Only signatures that also model non-immune cells (HNSCC, Melanoma, Vanderbilt scRNAseq,
# and quanTIseq through its 'uncharacterized' fraction) give a true total immune fraction.
pct  <- function(x) rank(x, ties.method = "average") / length(x)   # within-cohort percentile
cons <- function(df) rowMeans(apply(df, 2, pct))                   # consensus = mean percentile
feat <- list(
  Immune      = c("Quantiseq_TIL10_Immune", paste0("Immune_Subgroup.", 1:3)),
  Lymphocytes = c("Quantiseq_TIL10_Lymphocytes", "Lymphocytes_Subgroup.1",
                  "DeconRNASeq_CBSX.HNSCC.scRNAseq_Lymphocytes",
                  "DeconRNASeq_CBSX.Melanoma.scRNAseq_Lymphocytes",
                  "DeconRNASeq_CBSX.Vanderbilt.scRNAseq_Lymphocytes"),
  Myeloid     = c("Quantiseq_TIL10_Myeloid.cells", "Myeloid.cells_Subgroup.1",
                  "Myeloid.cells_Subgroup.2", grep("Macrophages.cells_Subgroup", colnames(m), value = TRUE)),
  Stromal     = c("DeconRNASeq_CBSX.Vanderbilt.scRNAseq_Stromal", paste0("Stromal_Subgroup.", 1:3)),
  # HNSCC/Vanderbilt 'Cancer' profiles are non-melanocytic tumour cells (~0 in melanoma);
  # keep only the melanoma-reference subgroup (CBSX.Melanoma.scRNAseq, 4 methods)
  Cancer      = "Cancer_Subgroup.2",
  CD8         = grep("^CD8.cells_Subgroup|_CD8.cells$", colnames(m), value = TRUE),
  CAF         = grep("^CAF_|_CAF$|^Fibroblasts_|_Fibroblasts$", colnames(m), value = TRUE),
  Endothelial = grep("^Endothelial_|_Endothelial$", colnames(m), value = TRUE)
)
feat <- lapply(feat, function(f) intersect(f, colnames(m)))
sink(file.path(out, "compartment_feature_definitions.txt"))
for (n in names(feat)) cat(n, ":\n  ", paste(feat[[n]], collapse = "\n   "), "\n\n")
sink()

scores <- data.frame(row.names = rownames(m))
for (n in names(feat)) {
  scores[[paste0(n, "_score")]]   <- cons(m[, feat[[n]], drop = FALSE])
  scores[[paste0(n, "_fraction")]] <- apply(m[, feat[[n]], drop = FALSE], 1, median)
}
# Per-estimate agreement of the immune and stromal features
write.csv(round(cor(m[, feat$Immune], method = "spearman"), 3), file.path(out, "immune_estimates_spearman.csv"))
write.csv(round(cor(m[, feat$Stromal], method = "spearman"), 3), file.path(out, "stromal_estimates_spearman.csv"))

# ---- Patient classification --------------------------------------------------------------
q <- quantile(scores$Immune_score, c(1/3, 2/3))
scores$Immune_class <- cut(scores$Immune_score, c(-Inf, q, Inf),
                           labels = c("Immune-low", "Immune-intermediate", "Immune-high"))
scores$TME_class <- paste0(ifelse(scores$Immune_score  >= median(scores$Immune_score),  "Immune-high", "Immune-low"), " / ",
                           ifelse(scores$Stromal_score >= median(scores$Stromal_score), "Stroma-high", "Stroma-low"))
scores$Immune_rank <- rank(-scores$Immune_score, ties.method = "min")
# QC flag: very low library-equivalent TPM total (see 00 input checks)
tpm_tot <- colSums(read.csv(file.path(base, "input/Gide_TPM_linear.csv"), row.names = 1, check.names = FALSE))
scores$TPM_total <- round(tpm_tot[rownames(scores)])
scores$QC_flag <- ifelse(scores$TPM_total < 0.25 * median(tpm_tot), "low total TPM - interpret with caution", "")

res <- cbind(Sample = rownames(scores), cd[rownames(scores), c("Response", "Therapy")], scores)
res <- res[order(res$Immune_rank), ]
num <- sapply(res, is.numeric) & !names(res) %in% c("Immune_rank", "TPM_total")
res[num] <- lapply(res[num], round, 4)
write.csv(res, file.path(out, "patient_immune_stromal_scores.csv"), row.names = FALSE)

# ---- Association with clinical variables -------------------------------------------------
test_vars <- grep("_score$", colnames(scores), value = TRUE)
assoc <- do.call(rbind, lapply(c("Response", "Therapy"), function(v) {
  do.call(rbind, lapply(test_vars, function(s) {
    g <- cd[[v]]; lv <- sort(unique(g))
    w <- wilcox.test(scores[[s]] ~ g)
    data.frame(variable = v, score = s,
               group1 = lv[1], median1 = median(scores[[s]][g == lv[1]]),
               group2 = lv[2], median2 = median(scores[[s]][g == lv[2]]), p = w$p.value)
  }))
}))
assoc$padj_BH <- ave(assoc$p, assoc$variable, FUN = function(p) p.adjust(p, "BH"))
write.csv(assoc, file.path(out, "compartment_scores_vs_clinical_wilcoxon.csv"), row.names = FALSE)

tab <- table(scores$Immune_class, cd$Response)
fis <- fisher.test(tab)
sink(file.path(out, "immune_class_vs_response.txt"))
print(tab); cat("\nFisher's exact test p =", signif(fis$p.value, 3), "\n\n")
print(table(scores$TME_class, cd$Response)); cat("\nFisher p =", signif(fisher.test(table(scores$TME_class, cd$Response))$p.value, 3), "\n")
sink()

# All harmonized features vs response (exploratory, BH-corrected)
fr <- do.call(rbind, lapply(colnames(m), function(f) {
  data.frame(feature = f, median_NR = median(m[cd$Response == "NR", f]), median_R = median(m[cd$Response == "R", f]),
             p = suppressWarnings(wilcox.test(m[, f] ~ cd$Response)$p.value))
}))
fr$padj_BH <- p.adjust(fr$p, "BH"); fr <- fr[order(fr$p), ]
write.csv(fr, file.path(out, "all_harmonized_features_vs_response_wilcoxon.csv"), row.names = FALSE)

# ---- Figures -----------------------------------------------------------------------------
ord <- rownames(scores)[order(scores$Immune_score, decreasing = TRUE)]
# 1. Ranked immune score with response
p1 <- ggplot(res, aes(x = reorder(Sample, -Immune_score), y = Immune_score, fill = Immune_class)) +
  geom_col() + geom_point(aes(y = -0.04, shape = Response), size = 2) +
  scale_fill_manual(values = c("Immune-low" = "#4575b4", "Immune-intermediate" = "#fee090", "Immune-high" = "#d73027")) +
  labs(x = NULL, y = "Consensus immune score (mean percentile)", title = "Gide cohort: ranked immune infiltration") +
  theme_bw() + theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1, size = 6))
ggsave(file.path(out, "immune_score_ranked.pdf"), p1, width = 14, height = 5)

# 2. Stacked composition from the melanoma scRNAseq reference (one coherent composition):
#    median across its 4 methods (CBSX, DWLS, EpiDISH, DeconRNASeq), renormalized to 1
raw <- read.csv(file.path(base, "01_deconvolution/result.csv"), row.names = 1, check.names = FALSE)
rownames(raw) <- sub("^X", "", rownames(raw))
mel_ct <- c("CD8.cells", "CD4.cells", "NK.cells", "B.cells", "Macrophages.cells", "CAF", "Endothelial", "Cancer")
comp <- sapply(mel_ct, function(ct) apply(raw[, grep(paste0("_CBSX\\.Melanoma\\.scRNAseq_", ct, "$"), colnames(raw))], 1, median))
comp <- comp / rowSums(comp)
write.csv(round(comp, 4), file.path(out, "melanoma_reference_composition_median4methods.csv"))
cl <- as.data.frame(comp) %>% mutate(Sample = rownames(comp)) %>% pivot_longer(-Sample, names_to = "Cell_type", values_to = "Fraction") %>%
  mutate(Sample = factor(Sample, levels = ord), Cell_type = factor(Cell_type, levels = mel_ct))
p2 <- ggplot(cl, aes(Sample, Fraction, fill = Cell_type)) + geom_col(width = 1) +
  scale_fill_manual(values = c(CD8.cells = "#a50026", CD4.cells = "#f46d43", NK.cells = "#fdae61", B.cells = "#fee090",
                               Macrophages.cells = "#e0a3c8", CAF = "#1a9850", Endothelial = "#91cf60", Cancer = "#5e3c99")) +
  labs(x = "Samples (ordered by consensus immune score)", y = "Fraction",
       title = "Cell composition - melanoma scRNAseq reference (median of CBSX, DWLS, EpiDISH, DeconRNASeq)") +
  theme_bw() + theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1, size = 6))
ggsave(file.path(out, "compartment_composition_stacked.pdf"), p2, width = 14, height = 5)

# 3. Immune vs stromal scatter
p3 <- ggplot(res, aes(Stromal_score, Immune_score, colour = Response, shape = Therapy)) + geom_point(size = 2.5) +
  geom_vline(xintercept = median(res$Stromal_score), lty = 2) + geom_hline(yintercept = median(res$Immune_score), lty = 2) +
  stat_cor(aes(group = 1), method = "spearman", colour = "black") +
  labs(title = "Immune vs stromal consensus scores") + theme_bw()
ggsave(file.path(out, "immune_vs_stromal_scatter.pdf"), p3, width = 7, height = 6)

# 4. Scores by response
long <- res %>% select(Sample, Response, all_of(test_vars)) %>% pivot_longer(all_of(test_vars), names_to = "Score") %>%
  mutate(Score = sub("_score", "", Score))
p4 <- ggplot(long, aes(Response, value, fill = Response)) + geom_boxplot(outlier.shape = NA, alpha = .6) +
  geom_jitter(width = .15, size = 1) + facet_wrap(~Score, nrow = 2) +
  stat_compare_means(method = "wilcox.test", label = "p.format", label.x = 1.3) +
  labs(y = "Consensus score (mean percentile)", title = "Compartment scores by response") + theme_bw()
ggsave(file.path(out, "compartment_scores_by_response.pdf"), p4, width = 11, height = 6)

# 5. Heatmap of harmonized cell-type features (scaled), samples ordered by immune score
mat <- t(scale(m[ord, ])); mat[mat > 3] <- 3; mat[mat < -3] <- -3
ct <- sub("_Subgroup\\.[0-9]+$", "", rownames(mat)); ct <- ifelse(grepl("_", ct), sub(".*_", "", ct), ct)
top <- HeatmapAnnotation(Immune_score = scores[ord, "Immune_score"], Stromal_score = scores[ord, "Stromal_score"],
                         Immune_class = scores[ord, "Immune_class"], Response = cd[ord, "Response"], Therapy = cd[ord, "Therapy"],
                         col = list(Immune_score = colorRamp2(c(0, 1), c("white", "#d73027")),
                                    Stromal_score = colorRamp2(c(0, 1), c("white", "#1a9850")),
                                    Immune_class = c("Immune-low" = "#4575b4", "Immune-intermediate" = "#fee090", "Immune-high" = "#d73027"),
                                    Response = c(R = "#1b9e77", NR = "#d95f02"),
                                    Therapy = c(PD1 = "#7570b3", "CTLA4+PD1" = "#e7298a")))
pdf(file.path(out, "harmonized_features_heatmap.pdf"), width = 16, height = 30)
draw(Heatmap(mat, name = "z", top_annotation = top, cluster_columns = FALSE, row_split = ct, row_title_rot = 0,
             row_title_gp = gpar(fontsize = 7), row_names_gp = gpar(fontsize = 5), column_names_gp = gpar(fontsize = 6),
             cluster_row_slices = FALSE, col = colorRamp2(c(-3, 0, 3), c("#4575b4", "white", "#d73027"))))
dev.off()

# Console summary
cat("Immune class x response:\n"); print(tab); cat("Fisher p =", signif(fis$p.value, 3), "\n\n")
print(assoc, digits = 3)
cat("\nTop 10 immune-infiltrated:\n"); print(head(res[, c("Sample", "Response", "Therapy", "Immune_score", "Immune_fraction", "Stromal_score", "TME_class", "QC_flag")], 10))
cat("\nBottom 10:\n"); print(tail(res[, c("Sample", "Response", "Therapy", "Immune_score", "Immune_fraction", "Stromal_score", "TME_class", "QC_flag")], 10))
cat("\nTop features vs response:\n"); print(head(fr, 15), digits = 3)
cat("\nQC flagged:\n"); print(res[res$QC_flag != "", c("Sample", "Immune_rank", "TPM_total")])
