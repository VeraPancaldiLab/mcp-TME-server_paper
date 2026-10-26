# Association of CellTFusion features (TF modules, cell groups, NMF latent factors / TME states)
# with immunotherapy response in the Gide cohort
# Usage: Rscript scripts/02_response_association.R   (from the project root, after 01_run_celltfusion.R)

suppressPackageStartupMessages({
  library(CellTFusion)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
})

root <- normalizePath(".")
out_dir <- file.path(root, "results")
assoc_dir <- file.path(out_dir, "response_association")
dir.create(assoc_dir, showWarnings = FALSE)

res <- readRDS(file.path(out_dir, "CellTFusion_Gide.rds"))

coldata <- read.table(file.path(root, "data/colData_all.txt"), header = TRUE)
coldata <- coldata[coldata$Cohort == "Gide", ]
rownames(coldata) <- coldata$rna_id
samples <- rownames(res$TF_network[[1]])
stopifnot(all(samples %in% rownames(coldata)))
coldata <- coldata[samples, ]
coldata$Response <- factor(coldata$Response, levels = c("NR", "R"))
coldata$Therapy <- factor(coldata$Therapy, levels = c("PD1", "CTLA4+PD1"))
traits <- coldata[, c("Response", "Therapy")]

cat("Response by therapy:\n"); print(table(traits$Therapy, traits$Response))
cat("Fisher test response vs therapy: p =",
    signif(fisher.test(table(traits$Therapy, traits$Response))$p.value, 3), "\n")

# Feature sets to test (samples x features)
tf_modules <- res$TF_network[[1]]
colnames(tf_modules) <- sub("^ME", "", colnames(tf_modules))
latent <- res$Latent_spaces$Z
colnames(latent) <- paste0("Factor", seq_len(ncol(latent)))
feature_sets <- list(
  TF_modules = tf_modules,
  Cell_groups = res$Cell_groups$Cell_groups,
  Latent_factors = latent,
  PROGENy_pathways = res$Pathways_scores
)

# For every feature: Wilcoxon R vs NR, AUC, therapy-stratified Wilcoxon, and logistic regression
# adjusted for therapy (scores z-scored, so the odds ratio is per SD)
auc <- function(x, y) {
  r <- rank(x); n1 <- sum(y == "R"); n0 <- sum(y == "NR")
  (sum(r[y == "R"]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}
test_features <- function(mat, set_name) {
  mat <- as.data.frame(mat)[samples, , drop = FALSE]
  out <- lapply(colnames(mat), function(f) {
    x <- mat[[f]]
    y <- traits$Response
    strat_p <- sapply(levels(traits$Therapy), function(t) {
      i <- traits$Therapy == t
      suppressWarnings(wilcox.test(x[i & y == "R"], x[i & y == "NR"])$p.value)
    })
    z <- as.numeric(scale(x))
    fit <- glm(y ~ z + Therapy, data = traits, family = binomial)
    co <- summary(fit)$coefficients["z", ]
    data.frame(
      set = set_name, feature = f,
      median_R = median(x[y == "R"]), median_NR = median(x[y == "NR"]),
      AUC = auc(x, y),
      wilcox_p = suppressWarnings(wilcox.test(x[y == "R"], x[y == "NR"])$p.value),
      wilcox_p_PD1 = strat_p[["PD1"]],
      wilcox_p_CTLA4_PD1 = strat_p[["CTLA4+PD1"]],
      OR_per_SD_adj_therapy = exp(co[["Estimate"]]),
      logit_p_adj_therapy = co[["Pr(>|z|)"]]
    )
  })
  out <- do.call(rbind, out)
  # BH within each feature set
  out$wilcox_padj <- p.adjust(out$wilcox_p, "BH")
  out$logit_padj_adj_therapy <- p.adjust(out$logit_p_adj_therapy, "BH")
  out[order(out$wilcox_p), ]
}
stats <- do.call(rbind, Map(test_features, feature_sets, names(feature_sets)))
rownames(stats) <- NULL
write.csv(stats, file.path(assoc_dir, "Response_association_all_features.csv"), row.names = FALSE)

cat("\nTop features per set (Wilcoxon R vs NR):\n")
print(stats %>% group_by(set) %>% slice_min(wilcox_p, n = 5) %>%
        mutate(across(where(is.numeric), ~ signif(.x, 3))) %>% as.data.frame())

# CellTFusion built-in tests (plots saved to results/Results/)
setwd(out_dir)
meta_tf <- compute.metadata.association(tf_modules, traits, pval = 0.05, padj = TRUE,
                                        plot_grid = TRUE, file_name = "Gide_TFmodules")
write.csv(meta_tf$anova, file.path(assoc_dir, "TF_modules_ANOVA_Response_Therapy.csv"), row.names = FALSE)

sig_groups <- scores.stat.analysis(res$Cell_groups, traits, trait = "Response",
                                   test = "wilcox", pval = 0.05, padj = TRUE)
write.csv(sig_groups$Statistics, file.path(assoc_dir, "Cell_groups_wilcox_Response_CellTFusion.csv"),
          row.names = FALSE)
sig_latent <- scores.stat.analysis(res$Latent_spaces, traits, trait = "Response",
                                   test = "wilcox", pval = 0.05, padj = TRUE)
write.csv(sig_latent$Statistics, file.path(assoc_dir, "Latent_factors_wilcox_Response_CellTFusion.csv"),
          row.names = FALSE)

# TME state per patient: dominant NMF factor (patient mixture = factor scores scaled by factor size)
mix <- res$Latent_spaces$patient_mixture
mix_wide <- as.data.frame(pivot_wider(mix, names_from = 2, values_from = 3))
rownames(mix_wide) <- mix_wide[[1]]
mix_wide <- as.matrix(mix_wide[samples, -1])
mix_wide[is.na(mix_wide)] <- 0
state <- ifelse(rowSums(mix_wide) == 0, "None",
                colnames(mix_wide)[max.col(mix_wide, ties.method = "first")])
state_df <- data.frame(sample = samples, TME_state = state, mix_wide, traits, check.names = FALSE)
write.csv(state_df, file.path(assoc_dir, "TME_state_per_patient.csv"), row.names = FALSE)
state_tab <- table(state_df$TME_state, state_df$Response)
cat("\nDominant TME state vs response:\n"); print(state_tab)
state_fisher <- fisher.test(state_tab, simulate.p.value = TRUE, B = 1e5)
cat("Fisher test (simulated) p =", signif(state_fisher$p.value, 3), "\n")
# Each state vs the rest
state_each <- do.call(rbind, lapply(rownames(state_tab), function(s) {
  # rows: in state / others; columns: R / NR -> OR = odds of response in the state vs the others
  tt <- table(state_df$TME_state == s, state_df$Response)[c("TRUE", "FALSE"), c("R", "NR")]
  ft <- fisher.test(tt)
  data.frame(TME_state = s, n = sum(tt["TRUE", ]), n_R = tt["TRUE", "R"],
             response_rate = tt["TRUE", "R"] / sum(tt["TRUE", ]),
             response_rate_others = tt["FALSE", "R"] / sum(tt["FALSE", ]),
             OR = unname(ft$estimate), fisher_p = ft$p.value)
}))
state_each$fisher_padj <- p.adjust(state_each$fisher_p, "BH")
write.csv(state_each, file.path(assoc_dir, "TME_state_vs_response_fisher.csv"), row.names = FALSE)
print(state_each)

# Figures
pdf_box <- function(df, file, title, ncol = 4) {
  p <- ggplot(df, aes(Response, value, fill = Response)) +
    geom_boxplot(outlier.shape = NA, alpha = 0.7) +
    geom_jitter(aes(shape = Therapy), width = 0.15, size = 1.6) +
    facet_wrap(~ label, scales = "free_y", ncol = ncol) +
    scale_fill_manual(values = c(NR = "#B2182B", R = "#2166AC")) +
    theme_bw() + labs(title = title, y = "Score", x = NULL)
  n <- length(unique(df$label))
  ggsave(file, p, width = 3 * min(n, ncol), height = 3 * ceiling(n / ncol) + 0.8, limitsize = FALSE)
}
long_for <- function(set_name, feats) {
  m <- as.data.frame(feature_sets[[set_name]])[samples, feats, drop = FALSE]
  s <- stats[stats$set == set_name, ]
  lab <- setNames(sprintf("%s\nAUC=%.2f p=%.3g q=%.3g", s$feature, s$AUC, s$wilcox_p, s$wilcox_padj),
                  s$feature)
  m$sample <- samples
  m <- cbind(m, traits)
  long <- pivot_longer(m, all_of(feats), names_to = "feature", values_to = "value")
  long$label <- factor(lab[long$feature], levels = lab[feats])
  long
}
pdf_box(long_for("Latent_factors", colnames(latent)),
        file.path(assoc_dir, "Latent_factors_by_response.pdf"), "NMF latent factors (TME states)", ncol = 3)
pdf_box(long_for("TF_modules", colnames(tf_modules)),
        file.path(assoc_dir, "TF_modules_by_response.pdf"), "TF module eigengenes")
top_groups <- head(stats$feature[stats$set == "Cell_groups"], 12)
pdf_box(long_for("Cell_groups", top_groups),
        file.path(assoc_dir, "Top12_cell_groups_by_response.pdf"), "Top 12 cell groups (ranked by Wilcoxon p)")

p_mix <- ggplot(state_df, aes(TME_state, fill = Response)) + geom_bar(position = "fill") +
  geom_text(stat = "count", aes(label = after_stat(count)), position = position_fill(vjust = 0.5)) +
  scale_fill_manual(values = c(NR = "#B2182B", R = "#2166AC")) + theme_bw() +
  labs(y = "Proportion", x = "Dominant TME state (NMF factor)",
       title = sprintf("Dominant TME state vs response (Fisher p = %.3g)", state_fisher$p.value))
ggsave(file.path(assoc_dir, "TME_state_vs_response.pdf"), p_mix, width = 5.5, height = 4)

# Volcano-like overview of all cell groups
cg <- stats[stats$set == "Cell_groups", ]
cg$module <- sub("^Dendrogram_(.*)_group_.*$", "\\1", cg$feature)
p_v <- ggplot(cg, aes(AUC, -log10(wilcox_p), colour = module)) + geom_point(size = 2) +
  geom_hline(yintercept = -log10(0.05), linetype = 2) + geom_vline(xintercept = 0.5, linetype = 3) +
  scale_colour_identity(guide = "legend") + theme_bw() +
  labs(title = "Cell groups: response association (AUC > 0.5 = higher in responders)",
       y = "-log10 Wilcoxon p", colour = "TF module")
ggsave(file.path(assoc_dir, "Cell_groups_AUC_volcano.pdf"), p_v, width = 7, height = 5)

sessionInfo()
