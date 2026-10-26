RUN_DIR <- "/home/marcelo.hurtado/Documents/tme_analysis/2bf9b0464f/mcp-tme-servers/celltfusion/runs/sessions/Gide_melanoma_ICI_20261017-012349_e7c3c1/Gide_melanoma_ICI/run_celltfusion_20261017-012415_120b44"
SCRATCH <- "/home/marcelo.hurtado/Documents/tme_analysis/2bf9b0464f/work/scratch"

cg <- read.csv(file.path(RUN_DIR, "Results", "Cell.groups.scores_Gide_CellTFusion.csv"), row.names = 1, check.names = FALSE)
z  <- read.csv(file.path(SCRATCH, "Gide_NMF_latent_factors.csv"), row.names = 1, check.names = FALSE)
coldata <- read.csv(file.path(SCRATCH, "coldata_gide.csv"), row.names = 1)

stopifnot(all(rownames(cg) == rownames(coldata)))
stopifnot(all(rownames(z) == rownames(coldata)))

response <- factor(coldata$Response)

test_matrix <- function(mat, label) {
  out <- data.frame(
    feature = colnames(mat),
    type = label,
    median_R = NA_real_, median_NR = NA_real_,
    p_value = NA_real_
  )
  for (i in seq_len(ncol(mat))) {
    x <- mat[[i]]
    out$median_R[i]  <- median(x[response == "R"])
    out$median_NR[i] <- median(x[response == "NR"])
    out$p_value[i] <- tryCatch(wilcox.test(x ~ response)$p.value, error = function(e) NA_real_)
  }
  out
}

res_cg <- test_matrix(cg, "Cell_group")
res_z  <- test_matrix(z, "NMF_latent_factor")

res <- rbind(res_z, res_cg)
res$padj_BH <- p.adjust(res$p_value, method = "BH")
res <- res[order(res$p_value), ]

write.csv(res, file.path(SCRATCH, "Response_association_stats.csv"), row.names = FALSE)

cat("Latent factors:\n")
print(res_z)
cat("\nTotal cell groups tested:", nrow(res_cg), "\n")
cat("Nominally significant (p<0.05):", sum(res_cg$p_value < 0.05, na.rm = TRUE), "\n")
cat("BH-significant (padj<0.05) overall:", sum(res$padj_BH < 0.05, na.rm = TRUE), "\n")
cat("\nTop 15 by p-value:\n")
print(head(res, 15))
