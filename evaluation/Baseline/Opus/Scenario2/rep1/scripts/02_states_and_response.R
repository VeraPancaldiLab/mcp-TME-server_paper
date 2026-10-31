# Characterize the CellTFusion TME states (NMF latent factors) and test their association
# with immunotherapy response in the Gide cohort.
# Usage (from the project root, after 01_run_celltfusion.R): Rscript scripts/02_states_and_response.R
# CellTFusion plotting functions write to "Results/", so we run from inside results/.

suppressPackageStartupMessages({
  library(CellTFusion)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(pheatmap)
})

root <- normalizePath(".")
setwd(file.path(root, "results"))
out <- "response_analysis"
dir.create(out, showWarnings = FALSE)

res <- readRDS("CellTFusion_Gide.rds")
coldata <- readRDS("Gide_coldata.rds")
coldata$Response <- factor(coldata$Response, levels = c("NR", "R"))
coldata$Therapy <- factor(coldata$Therapy, levels = c("PD1", "CTLA4+PD1"))

latent <- res$Latent_spaces
Z <- latent$Z
colnames(Z) <- paste0("TME_state", seq_len(ncol(Z)))
stopifnot(identical(rownames(Z), rownames(coldata)))
modules <- res$TF_network[["TFs module matrix"]]
cell_groups <- res$Cell_groups$Cell_groups
pathways <- res$Pathways_scores
deconv <- res$Deconvolution

# ---------------------------------------------------------------------------
# 1. Characterization of the TME states
# ---------------------------------------------------------------------------

# Patient mixture: factor scores scaled by factor size, as proportions per sample
mix <- sweep(latent$Z, 2, latent$nmf_model$d, "*")
mix <- mix / rowSums(mix)
colnames(mix) <- colnames(Z)
dominant <- colnames(mix)[max.col(mix, ties.method = "first")]
state_tab <- data.frame(sample = rownames(Z), Z, mix_ = mix, dominant_state = dominant,
                        coldata[, c("Response", "Therapy")], check.names = FALSE)
colnames(state_tab) <- sub("^mix_\\.", "proportion_", colnames(state_tab))
write.csv(state_tab, file.path(out, "TME_state_scores_per_sample.csv"), row.names = FALSE)

# Weights of the cell groups in each state, with their TF module and composition
W <- latent$W
colnames(W) <- colnames(Z)
comp <- res$Cell_groups$Composition
w_tab <- data.frame(cell_group = rownames(W), W,
                    module = sub("^Dendrogram_(.*)_group_.*$", "\\1", rownames(W)),
                    top_state = colnames(W)[max.col(W)],
                    n_features = lengths(comp[rownames(W)]),
                    features = sapply(comp[rownames(W)], paste, collapse = "; "))
w_tab <- w_tab[order(w_tab$top_state, -apply(W, 1, max)), ]
write.csv(w_tab, file.path(out, "TME_state_cell_group_weights.csv"), row.names = FALSE)
write.csv(res$Cells_niches, file.path(out, "TME_state_cell_niches_top5.csv"), row.names = FALSE)

# Per-module mean weight in each state (which TF modules drive which state)
mod_w <- w_tab %>% group_by(module) %>%
  summarise(across(all_of(colnames(Z)), mean), n_cell_groups = n(), .groups = "drop") %>%
  arrange(desc(TME_state1 - TME_state2))
write.csv(mod_w, file.path(out, "TME_state_mean_weight_per_TF_module.csv"), row.names = FALSE)

# TF module membership and hub TFs
tf_mod <- res$TF_network[["TFs per module"]]
write.csv(data.frame(module = rep(names(tf_mod), lengths(tf_mod)), TF = unlist(tf_mod)),
          file.path(out, "TF_module_membership.csv"), row.names = FALSE)
hubs <- identify_hub_TFs(res$TF_network, mm_thresh = 0.8, degree_thresh = 0.9)
hub_tab <- data.frame(TF = rownames(hubs$detailedData), hubs$detailedData)
write.csv(hub_tab, file.path(out, "TF_module_hub_TFs.csv"), row.names = FALSE)

# Correlation of the states with PROGENy pathways, quanTIseq cell fractions and TF modules
quantiseq <- deconv[, grepl("^Quantiseq_", colnames(deconv)), drop = FALSE]
colnames(quantiseq) <- sub("^Quantiseq_TIL10_", "", colnames(quantiseq))
rel_path <- compute.modules.relationship(Z, pathways, file_name = "TME_states_vs_PROGENy",
                                         padj = TRUE, vertical = TRUE)
rel_qti <- compute.modules.relationship(Z, quantiseq, file_name = "TME_states_vs_quanTIseq",
                                        padj = TRUE, vertical = TRUE)
rel_mod <- compute.modules.relationship(Z, modules, file_name = "TME_states_vs_TF_modules",
                                        padj = TRUE, vertical = TRUE)
rel_modpath <- compute.modules.relationship(modules, pathways, file_name = "TF_modules_vs_PROGENy",
                                            padj = TRUE)
tidy_rel <- function(rel, what) {
  data.frame(state = rep(rownames(rel$correlation), ncol(rel$correlation)),
             feature = rep(colnames(rel$correlation), each = nrow(rel$correlation)),
             type = what, rho = as.vector(rel$correlation),
             p_value = as.vector(rel$p_value), p_adjusted = as.vector(rel$p_adjusted))
}
char_tab <- rbind(tidy_rel(rel_path, "PROGENy"), tidy_rel(rel_qti, "quanTIseq"),
                  tidy_rel(rel_mod, "TF_module"))
write.csv(char_tab, file.path(out, "TME_state_characterization_correlations.csv"), row.names = FALSE)
write.csv(tidy_rel(rel_modpath, "PROGENy"), file.path(out, "TF_module_vs_PROGENy_correlations.csv"),
          row.names = FALSE)

# ---------------------------------------------------------------------------
# 2. Association with response
# ---------------------------------------------------------------------------

# 2a. Built-in CellTFusion tests (Wilcoxon, BH across features) at each level
stat_states <- scores.stat.analysis(list(Z), coldata, trait = "Response", test = "wilcox", padj = TRUE)
stat_groups <- scores.stat.analysis(res$Cell_groups, coldata, trait = "Response", test = "wilcox",
                                    padj = TRUE)
stat_modules <- scores.stat.analysis(modules, coldata, trait = "Response", test = "wilcox", padj = TRUE)
stat_paths <- scores.stat.analysis(pathways, coldata, trait = "Response", test = "wilcox", padj = TRUE)
write.csv(stat_states$Statistics, file.path(out, "Response_wilcox_TME_states.csv"), row.names = FALSE)
write.csv(stat_groups$Statistics, file.path(out, "Response_wilcox_cell_groups.csv"), row.names = FALSE)
write.csv(stat_modules$Statistics, file.path(out, "Response_wilcox_TF_modules.csv"), row.names = FALSE)
write.csv(stat_paths$Statistics, file.path(out, "Response_wilcox_PROGENy.csv"), row.names = FALSE)

# TF modules vs Response and Therapy (ANOVA + boxplots)
md <- coldata[, c("Response", "Therapy")]
compute.metadata.association(modules, md, file_name = "Gide", plot_grid = TRUE, padj = TRUE)

# 2b. Effect sizes and therapy-adjusted models for the states
# Response rates differ between PD1 and CTLA4+PD1 arms, so therapy is a potential confounder.
auc <- function(x, y) {  # P(score of R > score of NR)
  r <- rank(x); n1 <- sum(y == "R"); n0 <- sum(y == "NR")
  (sum(r[y == "R"]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}
state_models <- function(Zm, cd, label) {
  do.call(rbind, lapply(colnames(Zm), function(s) {
    d <- data.frame(score = as.numeric(scale(Zm[, s])), cd[, c("Response", "Therapy")])
    m0 <- glm(Response ~ score, data = d, family = binomial)
    m1 <- glm(Response ~ score + Therapy, data = d, family = binomial)
    m2 <- glm(Response ~ score * Therapy, data = d, family = binomial)
    strat <- sapply(levels(d$Therapy), function(t) {
      dd <- d[d$Therapy == t, ]
      c(auc = auc(dd$score, dd$Response),
        p = wilcox.test(score ~ Response, data = dd, exact = FALSE)$p.value)
    })
    c0 <- summary(m0)$coefficients["score", ]
    c1 <- summary(m1)$coefficients["score", ]
    data.frame(set = label, state = s, n = nrow(d),
               AUC = auc(d$score, d$Response),
               wilcox_p = wilcox.test(score ~ Response, data = d, exact = FALSE)$p.value,
               OR_per_SD = exp(c0[1]), OR_p = c0[4],
               OR_per_SD_adj_therapy = exp(c1[1]),
               OR_adj_lo95 = exp(c1[1] - 1.96 * c1[2]), OR_adj_hi95 = exp(c1[1] + 1.96 * c1[2]),
               OR_adj_p = c1[4],
               interaction_p = anova(m1, m2, test = "LRT")$`Pr(>Chi)`[2],
               AUC_PD1 = strat["auc", "PD1"], wilcox_p_PD1 = strat["p", "PD1"],
               AUC_ipiPD1 = strat["auc", "CTLA4+PD1"], wilcox_p_ipiPD1 = strat["p", "CTLA4+PD1"],
               row.names = NULL)
  }))
}
models <- state_models(Z, coldata, "all_samples")
# Sensitivity: drop the low-complexity sample (fewest expressed genes)
keep <- rownames(Z) != "8_PD1_PRE"
models <- rbind(models, state_models(Z[keep, , drop = FALSE], coldata[keep, ], "without_8_PD1_PRE"))
models$OR_adj_p_BH <- ave(models$OR_adj_p, models$set, FUN = function(p) p.adjust(p, "BH"))
write.csv(models, file.path(out, "Response_TME_states_logistic_models.csv"), row.names = FALSE)

# 2c. Dominant state vs response
tab <- table(Dominant = dominant, Response = coldata$Response)
ft <- fisher.test(tab)
cmh <- mantelhaen.test(table(dominant, coldata$Response, coldata$Therapy), exact = TRUE)
sink(file.path(out, "Response_dominant_state_tests.txt"))
cat("Dominant TME state (largest share of the patient mixture) vs response\n\n")
print(tab)
cat("\nResponse rate by dominant state:\n"); print(round(prop.table(tab, 1), 3))
cat("\nFisher exact test:\n"); print(ft)
cat("\nBy therapy:\n"); print(table(dominant, coldata$Response, coldata$Therapy))
cat("\nExact conditional (Mantel-Haenszel) test stratified by therapy:\n"); print(cmh)
sink()

# ---------------------------------------------------------------------------
# 3. Figures
# ---------------------------------------------------------------------------
cols_resp <- c(NR = "#B2182B", R = "#2166AC")
long <- state_tab %>%
  select(sample, Response, Therapy, all_of(colnames(Z))) %>%
  pivot_longer(all_of(colnames(Z)), names_to = "state", values_to = "score")
lab <- models %>% filter(set == "all_samples") %>%
  mutate(label = sprintf("AUC = %.2f\nWilcoxon p = %.3g\nTherapy-adj. OR/SD = %.2f (p = %.3g)",
                         AUC, wilcox_p, OR_per_SD_adj_therapy, OR_adj_p))
p1 <- ggplot(long, aes(Response, score, fill = Response)) +
  geom_boxplot(outlier.shape = NA, alpha = 0.6) +
  geom_jitter(aes(shape = Therapy), width = 0.15, size = 2) +
  facet_wrap(~state, scales = "free_y") +
  geom_text(data = lab, aes(x = 1.5, y = Inf, label = label), inherit.aes = FALSE,
            vjust = 1.1, size = 3) +
  scale_y_continuous(expand = expansion(mult = c(0.05, 0.35))) +
  scale_fill_manual(values = cols_resp) +
  labs(title = "CellTFusion TME states vs response (Gide, pre-treatment)",
       y = "NMF factor score (Z)") +
  theme_bw()
ggsave(file.path(out, "TME_states_by_response_boxplot.pdf"), p1, width = 9, height = 5.5)

p1b <- p1 + facet_grid(state ~ Therapy, scales = "free_y") + geom_blank()
p1b$layers[[3]] <- NULL
ggsave(file.path(out, "TME_states_by_response_and_therapy_boxplot.pdf"),
       p1b + labs(title = "TME states vs response, by therapy"), width = 8, height = 7)

mix_long <- state_tab %>%
  select(sample, Response, Therapy, starts_with("proportion_")) %>%
  pivot_longer(starts_with("proportion_"), names_to = "state", values_to = "proportion") %>%
  mutate(state = sub("proportion_", "", state))
ord <- state_tab %>% arrange(Response, proportion_TME_state1) %>% pull(sample)
mix_long$sample <- factor(mix_long$sample, levels = ord)
p2 <- ggplot(mix_long, aes(sample, proportion, fill = state)) +
  geom_col(width = 1) +
  facet_grid(~Response, scales = "free_x", space = "free_x") +
  scale_fill_manual(values = c(TME_state1 = "#E08214", TME_state2 = "#5E3C99")) +
  labs(title = "Patient mixture of TME states, split by response", x = NULL, y = "Proportion") +
  theme_bw() + theme(axis.text.x = element_text(angle = 90, size = 6, vjust = 0.5))
ggsave(file.path(out, "TME_state_mixture_by_response.pdf"), p2, width = 12, height = 4.5)

# Heatmap of the cell group scores, annotated with state weights, response and therapy
ann_col <- data.frame(Response = coldata$Response, Therapy = coldata$Therapy,
                      Dominant_state = dominant, row.names = rownames(coldata))
ann_row <- data.frame(Top_state = w_tab$top_state, TF_module = w_tab$module,
                      row.names = w_tab$cell_group)
hm <- t(scale(cell_groups[, w_tab$cell_group]))
hm[hm > 2.5] <- 2.5; hm[hm < -2.5] <- -2.5
pheatmap(hm, annotation_col = ann_col, annotation_row = ann_row, cluster_rows = FALSE,
         show_rownames = FALSE, fontsize_col = 6, clustering_method = "ward.D2",
         annotation_colors = list(Response = cols_resp,
                                  Dominant_state = c(TME_state1 = "#E08214", TME_state2 = "#5E3C99"),
                                  Top_state = c(TME_state1 = "#E08214", TME_state2 = "#5E3C99")),
         main = "Cell group scores (rows ordered by TME state weight)",
         filename = file.path(out, "Cell_group_scores_heatmap.pdf"), width = 12, height = 9)

writeLines(capture.output(sessionInfo()), file.path(out, "sessionInfo.txt"))
cat("Done\n")
