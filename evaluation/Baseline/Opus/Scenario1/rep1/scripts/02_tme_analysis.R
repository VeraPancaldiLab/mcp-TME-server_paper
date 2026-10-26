# Step 2: process multideconv output, build cell-type / compartment scores,
# rank patients by immune infiltration and relate to clinical data.
suppressMessages({
  library(multideconv); library(ggplot2); library(pheatmap); library(dplyr); library(tidyr)
})

proj <- "/home/marcelo.hurtado/Documents/tme_analysis/548819f72e/work"
out  <- file.path(proj, "results")
fig  <- file.path(out, "figures"); dir.create(fig, showWarnings = FALSE)
setwd(out)   # multideconv's own outputs go to results/Results/

zs <- function(x) { s <- sd(x); if (is.na(s) || s == 0) x * 0 else (x - mean(x)) / s }

# ---------------------------------------------------------------- inputs
deconv <- readRDS(file.path(out, "deconvolution_raw.rds"))
logtpm <- read.delim(file.path(proj, "data/Gide_log2TPM.txt"), row.names = 1, check.names = FALSE)

clin <- read.table(file.path(proj, "data/colData_all.txt"), header = TRUE, stringsAsFactors = FALSE)
clin <- clin[clin$Cohort == "Gide", ]
id_map <- setNames(colnames(logtpm), make.names(colnames(logtpm)))   # multideconv adds "X" prefix
stopifnot(all(rownames(deconv) %in% names(id_map)), setequal(id_map, clin$rna_id))
rownames(deconv) <- id_map[rownames(deconv)]
clin <- clin[match(rownames(deconv), clin$rna_id), ]
rownames(clin) <- clin$rna_id

# ---------------------------------------------------------------- multideconv processing
set.seed(123)
proc <- compute.deconvolution.analysis(deconv, corr = 0.7, return = TRUE, file_name = "Gide")
dmat <- proc[["Deconvolution matrix"]]
per_ct <- proc[["Deconvolution subgroups per cell types"]]
comp   <- proc[["Deconvolution subgroups composition"]]

write.csv(dmat, file.path(out, "deconvolution_processed_features.csv"))
sub_tab <- do.call(rbind, lapply(names(comp), function(ct) do.call(rbind, lapply(names(comp[[ct]]), function(sg)
  data.frame(cell_type = ct, subgroup = sg, feature = comp[[ct]][[sg]])))))
write.csv(sub_tab, file.path(out, "deconvolution_subgroups_composition.csv"), row.names = FALSE)
feat_names <- function(x) if (is.null(x)) character(0) else if (is.character(x)) x else colnames(data.frame(x, check.names = FALSE))
writeLines(c("# Features discarded (>90% zeros)", feat_names(proc[[4]]), "",
             "# Features discarded (CV < 0.1)", feat_names(proc[[5]]), "",
             "# Cell types discarded (not in multideconv nomenclature)", feat_names(proc[[6]])),
           file.path(out, "deconvolution_discarded_features.txt"))

# ---------------------------------------------------------------- cell-type consensus scores
immune_ct  <- c("B.cells","B.naive.cells","B.memory.cells","Plasma","Macrophages.cells","Macrophages.M0",
                "Macrophages.M1","Macrophages.M2","Monocytes","Neutrophils","Eosinophils","Basophils",
                "NK.cells","NK.activated","NK.resting","NKT.cells","CD4.cells","CD4.memory.activated",
                "CD4.memory.resting","CD4.naive","CD8.cells","CD4.regulatory","CD4.non.regulatory",
                "T.cells.helper","T.cells.gamma.delta","T.cells.proliferative","Dendritic.cells",
                "Dendritic.activated.cells","Dendritic.resting.cells","Dendritic.plasmacytoid.cells",
                "Mast.cells","Mast.activated.cells","Mast.resting.cells","Myeloid.cells")
stromal_ct <- c("CAF","Fibroblasts","Endothelial","Mural.cells","Pericytes","Myocytes")
tumor_ct   <- c("Cancer","Epithelial")
compartment_of <- function(ct) ifelse(ct %in% immune_ct, "Immune", ifelse(ct %in% stromal_ct, "Stromal",
                                 ifelse(ct %in% tumor_ct, "Tumor", "Other")))

ct_scores <- list(); ct_info <- list()
for (ct in names(per_ct)) {
  m <- as.matrix(per_ct[[ct]]); m <- m[, colnames(m) %in% colnames(dmat), drop = FALSE]
  if (ncol(m) == 0) next
  ct_scores[[ct]] <- rowMeans(apply(m, 2, zs))
  cc <- if (ncol(m) > 1) cor(m, method = "spearman") else matrix(1)
  ct_info[[ct]] <- data.frame(cell_type = ct, compartment = compartment_of(ct), n_features = ncol(m),
                              mean_pairwise_spearman = if (ncol(m) > 1) mean(cc[upper.tri(cc)]) else NA)
}
ct_scores <- do.call(cbind, ct_scores)
ct_info <- do.call(rbind, ct_info)
write.csv(ct_scores, file.path(out, "celltype_consensus_scores_zscore.csv"))
write.csv(ct_info, file.path(out, "celltype_consensus_info.csv"), row.names = FALSE)

# ---------------------------------------------------------------- absolute compartment fractions
# Only method-signature combinations that model non-immune cells give absolute immune fractions.
combos <- c("Quantiseq_TIL10", paste0(rep(c("DeconRNASeq","Epidish","DWLS"), each = 3), "_CBSX.",
            rep(c("Melanoma","HNSCC","Vanderbilt"), 3), ".scRNAseq"))
frac <- list()
for (cb in combos) {
  cols <- grep(paste0("^", cb, "_"), colnames(deconv), value = TRUE)
  ct <- sub(paste0("^", cb, "_"), "", cols)
  x <- as.matrix(deconv[, cols, drop = FALSE])
  frac[[cb]] <- data.frame(sample = rownames(deconv), combo = cb,
    Immune  = rowSums(x[, ct %in% immune_ct, drop = FALSE]),
    Stromal = if (any(ct %in% stromal_ct)) rowSums(x[, ct %in% stromal_ct, drop = FALSE]) else NA,
    Tumor   = if (any(ct %in% tumor_ct)) rowSums(x[, ct %in% tumor_ct, drop = FALSE]) else NA,
    Other   = rowSums(x[, !(ct %in% c(immune_ct, stromal_ct, tumor_ct)), drop = FALSE]))
}
frac <- do.call(rbind, frac)
write.csv(frac, file.path(out, "compartment_fractions_per_method.csv"), row.names = FALSE)

wide <- function(var) { w <- pivot_wider(frac[, c("sample","combo",var)], names_from = combo, values_from = all_of(var))
                        w <- as.data.frame(w); rownames(w) <- w$sample; as.matrix(w[, -1]) }
imm <- wide("Immune"); str_ <- wide("Stromal")[, -1]; tum <- wide("Tumor")[, -1]
# Combinations that reach a near-constant estimate (e.g. everything assigned to one compartment) add noise
keep_imm <- colnames(imm)[apply(imm, 2, sd) > 0.01]
keep_str <- colnames(str_)[apply(str_, 2, sd) > 0.01]

pdf(file.path(fig, "method_concordance_immune_fraction.pdf"), 8, 7)
pheatmap(cor(imm, method = "spearman"), display_numbers = TRUE, number_format = "%.2f",
         main = "Spearman correlation of immune fraction across method-signature combinations")
pheatmap(cor(str_, method = "spearman"), display_numbers = TRUE, number_format = "%.2f",
         main = "Spearman correlation of stromal fraction across combinations")
dev.off()

# Consensus: mean z-score across retained combinations (+ mean absolute fraction for interpretability)
patient <- data.frame(
  sample = rownames(imm),
  immune_score  = rowMeans(apply(imm[, keep_imm], 2, zs)),
  stromal_score = rowMeans(apply(str_[, keep_str], 2, zs)),
  immune_fraction_mean  = rowMeans(imm[, keep_imm]),
  stromal_fraction_mean = rowMeans(str_[, keep_str]),
  tumor_fraction_mean   = rowMeans(tum),
  quantiseq_immune_fraction = imm[, "Quantiseq_TIL10"])

# Orthogonal sanity checks from expression (not deconvolution): pan-immune PTPRC and cytolytic activity
patient$PTPRC_log2TPM <- as.numeric(logtpm["PTPRC", patient$sample])
patient$CYT_score <- as.numeric(colMeans(logtpm[c("GZMA","PRF1"), patient$sample]))
patient$stromal_markers <- as.numeric(colMeans(logtpm[intersect(c("COL1A1","COL1A2","COL3A1","PECAM1","VWF","ACTA2"),
                                                                rownames(logtpm)), patient$sample]))

q <- quantile(patient$immune_score, c(1/3, 2/3))
patient$immune_group <- factor(ifelse(patient$immune_score > q[2], "Immune-high",
                               ifelse(patient$immune_score < q[1], "Immune-low", "Immune-intermediate")),
                               levels = c("Immune-high","Immune-intermediate","Immune-low"))
patient$TME_class <- paste0(ifelse(patient$immune_score > median(patient$immune_score), "Immune-high", "Immune-low"),
                            " / ", ifelse(patient$stromal_score > median(patient$stromal_score), "Stroma-high", "Stroma-low"))
patient <- cbind(patient, clin[patient$sample, c("Response","Therapy")])
patient$immune_rank <- rank(-patient$immune_score)
patient <- patient[order(patient$immune_rank), ]
cs <- ct_scores[patient$sample, ]
key_ct <- intersect(c("CD8.cells","CD4.cells","CD4.regulatory","B.cells","NK.cells","Macrophages.cells",
                      "Macrophages.M1","Macrophages.M2","Monocytes","Dendritic.cells","CAF","Endothelial","Cancer"),
                    colnames(cs))
patient <- cbind(patient, setNames(as.data.frame(cs[, key_ct]), paste0("z_", key_ct)))
write.csv(patient, file.path(out, "patient_immune_infiltration_ranking.csv"), row.names = FALSE)

validation <- data.frame(
  comparison = c("immune_score vs PTPRC", "immune_score vs CYT (GZMA/PRF1)", "stromal_score vs stromal markers",
                 "immune_score vs stromal_score", "immune_score vs Quantiseq immune fraction"),
  spearman_rho = c(cor(patient$immune_score, patient$PTPRC_log2TPM, method = "spearman"),
                   cor(patient$immune_score, patient$CYT_score, method = "spearman"),
                   cor(patient$stromal_score, patient$stromal_markers, method = "spearman"),
                   cor(patient$immune_score, patient$stromal_score, method = "spearman"),
                   cor(patient$immune_score, patient$quantiseq_immune_fraction, method = "spearman")))
write.csv(validation, file.path(out, "validation_correlations.csv"), row.names = FALSE)

# ---------------------------------------------------------------- association with response
assoc <- do.call(rbind, lapply(c("immune_score","stromal_score","tumor_fraction_mean", colnames(ct_scores)), function(v) {
  x <- if (v %in% colnames(patient)) patient[[v]] else ct_scores[patient$sample, v]
  data.frame(feature = v, median_R = median(x[patient$Response == "R"]), median_NR = median(x[patient$Response == "NR"]),
             wilcox_p = wilcox.test(x ~ patient$Response, exact = FALSE)$p.value)
}))
assoc$FDR <- p.adjust(assoc$wilcox_p, "BH")
assoc <- assoc[order(assoc$wilcox_p), ]
write.csv(assoc, file.path(out, "association_with_response.csv"), row.names = FALSE)
grp_tab <- as.data.frame.matrix(table(patient$immune_group, patient$Response))
grp_tab$fisher_p <- fisher.test(table(patient$immune_group, patient$Response))$p.value
write.csv(grp_tab, file.path(out, "immune_group_vs_response.csv"))

# ---------------------------------------------------------------- figures
ann <- data.frame(Immune_group = patient$immune_group, Response = patient$Response, Therapy = patient$Therapy,
                  row.names = patient$sample)
ann_cols <- list(Immune_group = c(`Immune-high` = "#B2182B", `Immune-intermediate` = "#F4A582", `Immune-low` = "#2166AC"),
                 Response = c(R = "#1B9E77", NR = "#D95F02"), Therapy = c(PD1 = "grey70", `CTLA4+PD1` = "grey30"))
row_ann <- data.frame(Compartment = ct_info$compartment, row.names = ct_info$cell_type)
mat <- t(cs); mat[mat > 2.5] <- 2.5; mat[mat < -2.5] <- -2.5
pdf(file.path(fig, "heatmap_celltype_consensus.pdf"), 16, 11)
pheatmap(mat, cluster_cols = FALSE, annotation_col = ann, annotation_row = row_ann, annotation_colors = ann_cols,
         color = colorRampPalette(c("#2166AC","white","#B2182B"))(100), fontsize_col = 7,
         main = "multideconv cell-type consensus scores (z) - samples ordered by immune score")
pheatmap(mat, cluster_cols = TRUE, clustering_method = "ward.D2", annotation_col = ann, annotation_row = row_ann,
         annotation_colors = ann_cols, color = colorRampPalette(c("#2166AC","white","#B2182B"))(100),
         fontsize_col = 7, main = "multideconv cell-type consensus scores (z) - hierarchical clustering")
dev.off()

patient$sample <- factor(patient$sample, levels = patient$sample)
g1 <- ggplot(patient, aes(sample, immune_score, fill = Response)) + geom_col() +
  geom_hline(yintercept = q, linetype = "dashed") +
  scale_fill_manual(values = ann_cols$Response) + theme_bw() +
  theme(axis.text.x = element_text(angle = 90, vjust = .5, size = 6)) +
  labs(x = NULL, y = "Consensus immune infiltration score (mean z)", title = "Gide cohort - immune infiltration ranking",
       subtitle = "Dashed lines: tertile cut-offs")
ggsave(file.path(fig, "immune_score_ranking.pdf"), g1, width = 14, height = 5)

# quanTIseq has no stromal/tumour split, so use only the CBSX combinations to keep each bar summing to 1
lf <- frac %>% filter(combo %in% keep_str) %>% group_by(sample) %>%
  summarise(Immune = mean(Immune), Stromal = mean(Stromal[!is.na(Stromal)]), Tumor = mean(Tumor[!is.na(Tumor)])) %>%
  mutate(Other = pmax(0, 1 - Immune - Stromal - Tumor)) %>%
  pivot_longer(-sample, names_to = "Compartment", values_to = "Fraction") %>%
  mutate(sample = factor(sample, levels = levels(patient$sample)),
         Compartment = factor(Compartment, levels = c("Other","Tumor","Stromal","Immune")))
g2 <- ggplot(lf, aes(sample, Fraction, fill = Compartment)) + geom_col() + theme_bw() +
  scale_fill_manual(values = c(Immune = "#B2182B", Stromal = "#4DAF4A", Tumor = "#984EA3", Other = "grey80")) +
  theme(axis.text.x = element_text(angle = 90, vjust = .5, size = 6)) +
  labs(x = NULL, y = "Mean estimated fraction", title = "TME compartments (mean across DeconRNASeq/EpiDISH/DWLS x CBSX Melanoma/HNSCC/Vanderbilt)")
ggsave(file.path(fig, "compartment_fractions_stacked.pdf"), g2, width = 14, height = 5)

qs <- deconv[, grep("^Quantiseq_TIL10_", colnames(deconv))]; colnames(qs) <- sub("Quantiseq_TIL10_", "", colnames(qs))
qs_l <- data.frame(sample = rownames(qs), qs, check.names = FALSE) %>% pivot_longer(-sample, names_to = "Cell", values_to = "Fraction") %>%
  mutate(sample = factor(sample, levels = levels(patient$sample)))
g3 <- ggplot(qs_l, aes(sample, Fraction, fill = Cell)) + geom_col() + theme_bw() +
  scale_fill_manual(values = c(setNames(scales::hue_pal()(ncol(qs) - 1), setdiff(colnames(qs), "uncharacterized.cell")),
                               uncharacterized.cell = "grey85")) +
  theme(axis.text.x = element_text(angle = 90, vjust = .5, size = 6)) +
  labs(x = NULL, title = "quanTIseq (TIL10) absolute cell fractions", subtitle = "uncharacterized = non-immune cells")
ggsave(file.path(fig, "quantiseq_absolute_fractions.pdf"), g3, width = 14, height = 5)

g4 <- ggplot(patient, aes(immune_score, stromal_score, colour = immune_group, shape = Response)) + geom_point(size = 2.5) +
  geom_vline(xintercept = median(patient$immune_score), linetype = "dotted") +
  geom_hline(yintercept = median(patient$stromal_score), linetype = "dotted") +
  scale_colour_manual(values = ann_cols$Immune_group) + theme_bw() + labs(title = "Immune vs stromal consensus scores")
ggsave(file.path(fig, "immune_vs_stromal_scatter.pdf"), g4, width = 7, height = 5.5)

vl <- patient %>% select(sample, immune_score, PTPRC_log2TPM, CYT_score) %>% pivot_longer(c(PTPRC_log2TPM, CYT_score))
g5 <- ggplot(vl, aes(immune_score, value)) + geom_point() + geom_smooth(method = "lm", se = FALSE) +
  facet_wrap(~name, scales = "free_y") + theme_bw() + labs(title = "Immune score vs marker expression")
ggsave(file.path(fig, "validation_markers.pdf"), g5, width = 9, height = 4)

bl <- patient %>% select(Response, Therapy, immune_score, stromal_score, all_of(paste0("z_", c("CD8.cells","Macrophages.M2","CAF")))) %>%
  pivot_longer(-c(Response, Therapy))
g6 <- ggplot(bl, aes(Response, value, fill = Response)) + geom_boxplot(outlier.shape = NA) + geom_jitter(width = .15, size = .8) +
  facet_wrap(~name, scales = "free_y", nrow = 1) + scale_fill_manual(values = ann_cols$Response) + theme_bw() +
  labs(y = "score (z)", title = "Pre-treatment TME scores by response")
ggsave(file.path(fig, "scores_by_response.pdf"), g6, width = 13, height = 4)

cat("Retained immune combos:", keep_imm, "\nRetained stromal combos:", keep_str, "\n")
print(validation); print(head(assoc, 10)); print(grp_tab)
print(patient[1:15, c("sample","immune_score","immune_fraction_mean","quantiseq_immune_fraction","Response","Therapy")])
print(tail(patient[, c("sample","immune_score","immune_fraction_mean","quantiseq_immune_fraction","Response","Therapy")], 10))
print(ct_info)
