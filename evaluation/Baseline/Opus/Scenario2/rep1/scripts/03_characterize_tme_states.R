# Biological characterization of the NMF latent factors (TME states): TF modules of their cell
# groups, correlated deconvolution features, PROGENy pathways and TFs
# Usage: Rscript scripts/03_characterize_tme_states.R   (from the project root, after 01 and 02)

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(pheatmap)
})

root <- normalizePath(".")
out_dir <- file.path(root, "results")
char_dir <- file.path(out_dir, "tme_states_characterization")
dir.create(char_dir, showWarnings = FALSE)

res <- readRDS(file.path(out_dir, "CellTFusion_Gide.rds"))
Z <- res$Latent_spaces$Z
colnames(Z) <- paste0("Factor", seq_len(ncol(Z)))
samples <- rownames(res$TF_network[[1]])
Z <- Z[samples, , drop = FALSE]

# Share of each TF module in the NMF weights of every factor
W <- res$Latent_spaces$W
colnames(W) <- colnames(Z)
module <- sub("^Dendrogram_(.*)_group_.*$", "\\1", rownames(W))
module_share <- sapply(colnames(W), function(f) tapply(W[, f], module, sum) / sum(W[, f]))
write.csv(round(module_share, 4), file.path(char_dir, "Factor_TF_module_weight_share.csv"))
cat("Share of NMF weight per TF module:\n"); print(round(module_share, 3))

# Spearman correlation of factor scores with a feature matrix; top hits per factor
cor_top <- function(mat, name, n = 15) {
  mat <- as.matrix(as.data.frame(mat)[samples, , drop = FALSE])
  mat <- mat[, apply(mat, 2, sd) > 0, drop = FALSE]
  out <- do.call(rbind, lapply(colnames(Z), function(f) {
    r <- apply(mat, 2, function(x) suppressWarnings(cor.test(Z[, f], x, method = "spearman")))
    data.frame(factor = f, feature = colnames(mat),
               rho = sapply(r, `[[`, "estimate"), p = sapply(r, `[[`, "p.value"))
  }))
  out$padj <- p.adjust(out$p, "BH")
  out <- out[order(out$factor, -out$rho), ]
  rownames(out) <- NULL
  write.csv(out, file.path(char_dir, paste0("Factor_correlation_", name, ".csv")), row.names = FALSE)
  out
}
cor_deconv <- cor_top(res$Processed_deconvolution[[1]], "deconvolution_subgroups")
cor_path <- cor_top(res$Pathways_scores, "PROGENy")
cor_tf <- cor_top(res$TFs_matrix, "TFs")

for (f in colnames(Z)) {
  cat("\n=====", f, "=====\n")
  cat("Top positively correlated deconvolution features:\n")
  print(head(cor_deconv[cor_deconv$factor == f, c("feature", "rho", "padj")], 12), digits = 2)
  cat("Top positively correlated TFs:\n")
  print(head(cor_tf[cor_tf$factor == f, c("feature", "rho")], 15)$feature)
  cat("PROGENy (|rho| ordered):\n")
  pf <- cor_path[cor_path$factor == f, ]
  print(pf[order(-abs(pf$rho)), c("feature", "rho", "padj")][1:6, ], digits = 2)
}

# TFs of the modules driving the factors
tf_modules <- res$TF_network[[3]]
write.csv(data.frame(module = rep(names(tf_modules), lengths(tf_modules)), TF = unlist(tf_modules)),
          file.path(char_dir, "TF_module_membership.csv"), row.names = FALSE)

# Heatmap: factor vs PROGENy and the cell types correlated with the factors
deconv_top <- unique(unlist(lapply(colnames(Z), function(f)
  head(cor_deconv$feature[cor_deconv$factor == f], 8))))
rho_mat <- function(cr, feats) {
  m <- tidyr::pivot_wider(cr[cr$feature %in% feats, c("factor", "feature", "rho")],
                          names_from = factor, values_from = rho)
  m <- as.data.frame(m); rownames(m) <- m$feature; as.matrix(m[feats, -1])
}
hm <- rbind(rho_mat(cor_path, unique(cor_path$feature)), rho_mat(cor_deconv, deconv_top))
pheatmap(hm, cluster_cols = FALSE, cluster_rows = FALSE, display_numbers = TRUE, number_format = "%.2f",
         color = colorRampPalette(c("#2166AC", "white", "#B2182B"))(100), breaks = seq(-1, 1, length.out = 101),
         gaps_row = ncol(res$Pathways_scores), main = "Spearman rho: TME states vs pathways / cell types",
         filename = file.path(char_dir, "Factor_characterization_heatmap.pdf"), width = 7.5, height = 10)

sessionInfo()
