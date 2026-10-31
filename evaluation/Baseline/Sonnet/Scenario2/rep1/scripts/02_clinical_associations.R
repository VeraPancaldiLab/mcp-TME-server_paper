#!/usr/bin/env Rscript
# Test whether the Gide TME states (CellTFusion latent factors) and their underlying
# TF co-activity modules relate to clinical variables, in particular immunotherapy response.

suppressPackageStartupMessages(library(CellTFusion))

work_dir    <- "/home/marcelo.hurtado/Documents/tme_analysis/10d0ef4104/work"
data_dir    <- file.path(work_dir, "data")
results_dir <- file.path(work_dir, "results")

res <- readRDS(file.path(results_dir, "CellTFusion_Gide_full_result.rds"))

coldata_all <- read.table(file.path(data_dir, "colData_all.txt"), header = TRUE, sep = " ",
                           quote = "\"", stringsAsFactors = FALSE)
coldata <- coldata_all[coldata_all$Cohort == "Gide", ]
rownames(coldata) <- coldata$rna_id
coldata <- coldata[rownames(res$Latent_spaces$Z), ]
stopifnot(identical(rownames(coldata), rownames(res$Latent_spaces$Z)))

setwd(results_dir)

## ---- 1. Latent factors (TME states) vs Response (R vs NR) ----------------

cat("\n================ Latent factors vs Response (wilcox) ================\n")
resp_wilcox <- scores.stat.analysis(
  scores = res$Latent_spaces, coldata = coldata, trait = "Response",
  test = "wilcox", pval = 0.05, padj = TRUE
)
print(resp_wilcox$Statistics)
write.csv(resp_wilcox$Statistics, "Results/LatentFactors_vs_Response_wilcox_stats_Gide.csv", row.names = FALSE)

cat("\n================ Latent factors vs Response (fisher, median split) ================\n")
resp_fisher <- scores.stat.analysis(
  scores = res$Latent_spaces, coldata = coldata, trait = "Response",
  test = "fisher", pval = 0.05, padj = TRUE
)
print(resp_fisher$Statistics)
write.csv(resp_fisher$Statistics, "Results/LatentFactors_vs_Response_fisher_stats_Gide.csv", row.names = FALSE)

## ---- 2. Latent factors vs Therapy (anti-PD1 vs anti-CTLA4+PD1) -----------

cat("\n================ Latent factors vs Therapy (wilcox) ================\n")
therapy_wilcox <- scores.stat.analysis(
  scores = res$Latent_spaces, coldata = coldata, trait = "Therapy",
  test = "wilcox", pval = 0.05, padj = TRUE
)
print(therapy_wilcox$Statistics)
write.csv(therapy_wilcox$Statistics, "Results/LatentFactors_vs_Therapy_wilcox_stats_Gide.csv", row.names = FALSE)

## ---- 3. TF co-activity modules vs all clinical traits at once ------------

cat("\n================ TF modules vs clinical traits ================\n")
module_assoc <- compute.metadata.association(
  scores    = res$TF_network[[1]],
  coldata   = coldata[, c("Response", "Therapy"), drop = FALSE],
  pval      = 0.05,
  padj      = TRUE,
  file_name = "Gide_modules_vs_traits",
  plot_grid = TRUE
)
cat("ANOVA of TF modules vs Response/Therapy:\n")
print(module_assoc$anova)
write.csv(module_assoc$anova, "Results/TFmodules_vs_traits_anova_Gide.csv", row.names = FALSE)

## ---- 4. Save latent factor scores + coldata together for convenience -----

factor_table <- cbind(coldata[, c("Sample_id", "Response", "Therapy")],
                       data.frame(res$Latent_spaces$Z))
write.csv(factor_table, "Results/LatentFactors_scores_with_clinical_Gide.csv", row.names = FALSE)

cat("\n=== Clinical association analysis finished ===\n")
