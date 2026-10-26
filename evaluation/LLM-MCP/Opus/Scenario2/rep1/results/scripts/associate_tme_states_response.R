# Characterize CellTFusion TME states (NMF latent factors) in the Gide cohort and
# test their association (and that of the underlying cell groups) with ICB response.
# Usage: Rscript associate_tme_states_response.R <results_dir>
suppressPackageStartupMessages({ library(ggplot2); library(pheatmap) })

args <- commandArgs(trailingOnly = TRUE)
res_dir <- if (length(args)) args[1] else "results"
ctf_dir <- file.path(res_dir, "celltfusion")
out_dir <- file.path(res_dir, "association")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

r  <- readRDS(file.path(ctf_dir, "result.rds"))
cd <- read.csv(file.path(res_dir, "inputs", "Gide_coldata.csv"), row.names = 1)

Z   <- as.data.frame(r$Latent_spaces$Z)
CG  <- as.data.frame(r$Cell_groups$Cell_groups)
W   <- r$Latent_spaces$W
cd  <- cd[rownames(Z), ]
stopifnot(identical(rownames(cd), rownames(CG)))
cd$Response <- factor(cd$Response, levels = c("NR", "R"))
cd$Therapy  <- factor(cd$Therapy, levels = c("PD1", "CTLA4+PD1"))

## ---- 1. Characterize factors ------------------------------------------------
mods <- read.csv(file.path(ctf_dir, "Results", "TF_module_matrix_Gide.csv"), row.names = 1)[rownames(Z), ]
colnames(mods) <- paste0("TFmodule_", colnames(mods))
path <- as.data.frame(r$Pathways_scores)[rownames(Z), ]
colnames(path) <- paste0("PROGENy_", colnames(path))
dec  <- as.data.frame(r$Deconvolution)[rownames(Z), ]
qts  <- dec[, grep("^Quantiseq_TIL10_", colnames(dec)), drop = FALSE]
colnames(qts) <- sub("^Quantiseq_TIL10_", "quanTIseq_", colnames(qts))
key_tfs <- c("STAT1", "IRF1", "TBX21", "EOMES", "FOXP3", "NFKB1", "SOX10", "MITF",
             "E2F1", "MYC", "SMAD3", "TWIST1", "CTNNB1", "AP1", "HIF1A", "TP53", "YAP1")
tfs  <- as.data.frame(r$TFs_matrix)[rownames(Z), intersect(key_tfs, colnames(r$TFs_matrix))]
colnames(tfs) <- paste0("TF_", colnames(tfs))

feat <- cbind(mods, path, qts, tfs)
feat <- feat[, apply(feat, 2, sd) > 0]
cor_rho <- sapply(colnames(Z), function(f) sapply(feat, function(v) cor(Z[[f]], v, method = "spearman")))
cor_p   <- sapply(colnames(Z), function(f) sapply(feat, function(v)
  suppressWarnings(cor.test(Z[[f]], v, method = "spearman")$p.value)))
cor_padj <- matrix(p.adjust(cor_p, "BH"), nrow(cor_p), dimnames = dimnames(cor_p))
write.csv(cor_rho,  file.path(out_dir, "Factor_characterization_spearman_rho.csv"))
write.csv(cor_padj, file.path(out_dir, "Factor_characterization_spearman_padjBH.csv"))
stars <- ifelse(cor_padj < 0.001, "***", ifelse(cor_padj < 0.01, "**", ifelse(cor_padj < 0.05, "*", "")))
pdf(file.path(out_dir, "Factor_characterization_heatmap.pdf"), width = 6, height = 14)
pheatmap(cor_rho, cluster_cols = FALSE, display_numbers = stars, fontsize_row = 7,
         color = colorRampPalette(c("navy", "white", "firebrick"))(100), breaks = seq(-1, 1, length.out = 101),
         gaps_row = cumsum(c(ncol(mods), ncol(path), ncol(qts))),
         cluster_rows = FALSE, main = "Factor vs features (Spearman rho; BH *<.05)")
dev.off()

## ---- helpers ----------------------------------------------------------------
test_scores <- function(S, cd) {
  do.call(rbind, lapply(colnames(S), function(f) {
    x <- S[[f]]
    one <- function(idx) {
      a <- x[idx & cd$Response == "R"]; b <- x[idx & cd$Response == "NR"]
      w <- suppressWarnings(wilcox.test(a, b, exact = FALSE))
      auc <- unname(w$statistic) / (length(a) * length(b))  # P(score_R > score_NR)
      c(median_R = median(a), median_NR = median(b), AUC = auc, p = w$p.value)
    }
    all <- one(rep(TRUE, nrow(cd)))
    pd1 <- one(cd$Therapy == "PD1")
    ipi <- one(cd$Therapy == "CTLA4+PD1")
    g <- glm(Response ~ scale(x) + Therapy, data = cd, family = binomial)
    co <- summary(g)$coefficients[2, ]
    data.frame(feature = f,
               median_R = all["median_R"], median_NR = all["median_NR"],
               AUC_all = all["AUC"], p_wilcox_all = all["p"],
               AUC_PD1 = pd1["AUC"], p_wilcox_PD1 = pd1["p"],
               AUC_ipiPD1 = ipi["AUC"], p_wilcox_ipiPD1 = ipi["p"],
               OR_perSD_adjTherapy = exp(co[1]), p_logit_adjTherapy = co[4],
               row.names = NULL)
  }))
}
add_fdr <- function(t) {
  for (p in grep("^p_", colnames(t), value = TRUE)) t[[sub("^p_", "padj_", p)]] <- p.adjust(t[[p]], "BH")
  t[order(t$p_wilcox_all), ]
}

## ---- 2. Latent factors vs response -----------------------------------------
fac_res <- add_fdr(test_scores(Z, cd))
write.csv(fac_res, file.path(out_dir, "LatentFactors_vs_Response.csv"), row.names = FALSE)

long <- data.frame(sample = rep(rownames(Z), ncol(Z)), factor = rep(colnames(Z), each = nrow(Z)),
                   score = unlist(Z), Response = rep(cd$Response, ncol(Z)), Therapy = rep(cd$Therapy, ncol(Z)))
long_all <- rbind(transform(long, arm = "All"), transform(long, arm = as.character(Therapy)))
long_all$arm <- factor(long_all$arm, levels = c("All", "PD1", "CTLA4+PD1"))
p <- ggplot(long_all, aes(Response, score, fill = Response)) +
  geom_boxplot(outlier.shape = NA, alpha = .6) + geom_jitter(width = .15, size = .8) +
  facet_grid(factor ~ arm, scales = "free_y") + theme_bw() +
  scale_fill_manual(values = c(NR = "grey60", R = "firebrick")) +
  labs(y = "NMF latent factor score (Z)", title = "CellTFusion TME states vs ICB response (Gide)")
ggsave(file.path(out_dir, "LatentFactors_vs_Response_boxplots.pdf"), p, width = 7, height = 9)

## ---- 3. Dominant TME state per patient -------------------------------------
mix <- as.data.frame(r$Latent_spaces$patient_mixture)
prop <- reshape(mix, idvar = "sample", timevar = "factor", direction = "wide")
rownames(prop) <- prop$sample; prop <- prop[rownames(Z), -1]
colnames(prop) <- sub("^proportion\\.", "", colnames(prop))
cd$Dominant_state <- factor(colnames(prop)[apply(prop, 1, which.max)], levels = colnames(Z))
write.csv(cbind(cd, prop), file.path(out_dir, "Patient_state_mixture_and_dominant_state.csv"))

tab_stats <- function(idx, lab) {
  tb <- table(cd$Dominant_state[idx], cd$Response[idx])
  per <- data.frame(arm = lab, state = rownames(tb), n = rowSums(tb), n_R = tb[, "R"],
                    response_rate = round(tb[, "R"] / pmax(rowSums(tb), 1), 3),
                    fisher_p_state_vs_rest = sapply(rownames(tb), function(s) {
                      x <- cd$Dominant_state[idx] == s
                      if (length(unique(x)) < 2) return(NA)
                      fisher.test(table(x, cd$Response[idx]))$p.value }))
  per$fisher_p_global <- fisher.test(tb[rowSums(tb) > 0, , drop = FALSE])$p.value
  per
}
dom <- rbind(tab_stats(rep(TRUE, nrow(cd)), "All"),
             tab_stats(cd$Therapy == "PD1", "PD1"),
             tab_stats(cd$Therapy == "CTLA4+PD1", "CTLA4+PD1"))
write.csv(dom, file.path(out_dir, "DominantState_vs_Response.csv"), row.names = FALSE)
dom$arm <- factor(dom$arm, levels = c("All", "PD1", "CTLA4+PD1"))
p <- ggplot(dom, aes(state, response_rate)) + geom_col(fill = "firebrick", alpha = .7) +
  geom_text(aes(label = paste0(n_R, "/", n)), vjust = -.3, size = 3) + facet_wrap(~arm) +
  geom_hline(yintercept = mean(cd$Response == "R"), linetype = 2) + ylim(0, 1.05) + theme_bw() +
  labs(x = "Dominant TME state", y = "Response rate", title = "Response rate by dominant TME state")
ggsave(file.path(out_dir, "DominantState_response_rate.pdf"), p, width = 8, height = 3.5)

## ---- 4. Cell groups vs response --------------------------------------------
cg_res <- test_scores(CG, cd)
cg_res$TF_module <- sub("^Dendrogram_(.*)_group_\\d+$", "\\1", cg_res$feature)
cg_res$top_factor <- colnames(W)[apply(W[cg_res$feature, , drop = FALSE], 1, which.max)]
cg_res$top_factor[rowSums(W[cg_res$feature, , drop = FALSE]) == 0] <- NA
cg_res$composition <- sapply(cg_res$feature, function(g) paste(r$Cell_groups$Composition[[g]], collapse = "; "))
cg_res <- add_fdr(cg_res)
write.csv(cg_res, file.path(out_dir, "CellGroups_vs_Response.csv"), row.names = FALSE)
p <- ggplot(cg_res, aes(AUC_all, -log10(p_wilcox_all), colour = TF_module)) + geom_point() +
  geom_hline(yintercept = -log10(0.05), linetype = 2) + geom_vline(xintercept = .5, linetype = 3) +
  theme_bw() + labs(x = "AUC (R vs NR, >0.5 = higher in responders)", y = "-log10 Wilcoxon p",
                    title = "122 CellTFusion cell groups vs response (all patients)")
ggsave(file.path(out_dir, "CellGroups_vs_Response_volcano.pdf"), p, width = 7, height = 5)

cat("\n== Latent factors ==\n"); print(fac_res, digits = 3, row.names = FALSE)
cat("\n== Dominant state ==\n"); print(dom, row.names = FALSE)
cat("\n== Cell groups: n with p<0.05 (all) =", sum(cg_res$p_wilcox_all < .05),
    "; FDR<0.05 =", sum(cg_res$padj_wilcox_all < .05), "; FDR<0.1 =", sum(cg_res$padj_wilcox_all < .1), "\n")
print(head(cg_res[, c("feature", "top_factor", "AUC_all", "p_wilcox_all", "padj_wilcox_all",
                      "AUC_PD1", "p_wilcox_PD1", "AUC_ipiPD1", "p_wilcox_ipiPD1",
                      "OR_perSD_adjTherapy", "p_logit_adjTherapy", "padj_logit_adjTherapy")], 15), digits = 3, row.names = FALSE)
