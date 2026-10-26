#!/usr/bin/env Rscript
suppressMessages(library(CellTFusion))

work_dir <- "/home/marcelo.hurtado/Documents/tme_analysis/2cbab8b568/work"
setwd(work_dir)

## ---- Load data ----
expr <- read.table("data/Gide_log2TPM.txt", header = TRUE, sep = "\t",
                    row.names = 1, check.names = FALSE)
expr <- as.matrix(expr)

coldata_all <- read.table("data/colData_all.txt", header = TRUE, sep = " ",
                           stringsAsFactors = FALSE)
coldata <- coldata_all[coldata_all$Cohort == "Gide", ]
rownames(coldata) <- make.names(coldata$Sample_id)

colnames(expr) <- make.names(colnames(expr))
expr <- expr[, rownames(coldata)]

# log2(TPM + 1) -> TPM (CellTFusion requires non-log TPM when normalized = FALSE)
tpm <- (2^expr) - 1
tpm[tpm < 0] <- 0

coldata$Response <- factor(coldata$Response, levels = c("NR", "R"))
coldata$Therapy  <- factor(coldata$Therapy)

## ---- Run CellTFusion pipeline (Gide cohort, melanoma) ----
setwd(file.path(work_dir, "results"))

res <- CellTFusion(
  raw_counts     = tpm,
  normalized     = FALSE,
  deconv_methods = c("Quantiseq", "Epidish", "DeconRNASeq"),
  do_parallel    = FALSE,
  file_name      = "Gide",
  seed           = 123
)

saveRDS(res, "CellTFusion_Gide_result.rds")

## ---- TME states = NMF latent factors, annotated by their cell niches ----
# (Latent_spaces$Z: samples x factors; Cells_niches: top contributing cell
# groups/deconvolution features of each factor, used to interpret/name it)
write.csv(res$Latent_spaces$Z, "TME_states_latent_factor_scores.csv")
write.csv(res$Cells_niches, "TME_states_cell_niches_composition.csv", row.names = FALSE)

## ---- Association of latent factors (TME states) with immunotherapy response ----
sig_factors <- scores.stat.analysis(
  scores  = res$Latent_spaces,
  coldata = coldata,
  trait   = "Response",
  test    = "wilcox",
  pval    = 0.05,
  padj    = TRUE
)

write.csv(sig_factors$Statistics, "LatentFactors_vs_Response_stats.csv", row.names = FALSE)
saveRDS(sig_factors, "LatentFactors_vs_Response.rds")

## ---- Combine TME state (cell niche) annotation with the Response statistics ----
niches <- res$Cells_niches
top_cells_per_factor <- do.call(rbind, lapply(split(niches, niches$factor), function(d) {
  data.frame(factor = d$factor[1],
             top_cell_groups = paste(unique(d$cell_group)[seq_len(min(3, length(unique(d$cell_group))))], collapse = "; "))
}))
stats_df <- sig_factors$Statistics
summary_tbl <- merge(top_cells_per_factor, stats_df, by.x = "factor", by.y = "feature", all.y = TRUE)
summary_tbl <- summary_tbl[order(summary_tbl$p_value), ]
write.csv(summary_tbl, "TME_states_vs_Response_summary.csv", row.names = FALSE)

## ---- Also relate the underlying TF modules to Response (supporting evidence) ----
tf_assoc <- compute.metadata.association(
  scores    = res$TF_network[[1]],
  coldata   = coldata[, c("Response", "Therapy")],
  pval      = 0.05,
  file_name = "Gide",
  plot_grid = TRUE
)
saveRDS(tf_assoc, "TFmodules_vs_clinical.rds")

cat("\n\n================ DONE ================\n")
cat("Latent factors (TME states) significantly associated with Response (wilcox, p<0.05):\n")
print(summary_tbl[!is.na(summary_tbl$p_value) & summary_tbl$p_value < 0.05,
                   c("factor", "top_cell_groups", "statistic", "p_value", "p_adjusted")])
