#!/usr/bin/env Rscript
# Identify TME states (latent factors) in the Gide bulk RNA-seq cohort with CellTFusion
# and relate them to clinical variables (immunotherapy response, therapy, timing).

suppressPackageStartupMessages(library(CellTFusion))

work_dir    <- "/home/marcelo.hurtado/Documents/tme_analysis/10d0ef4104/work"
data_dir    <- file.path(work_dir, "data")
results_dir <- file.path(work_dir, "results")
dir.create(results_dir, showWarnings = FALSE, recursive = TRUE)

## ---- Load data ----------------------------------------------------------

expr <- read.table(file.path(data_dir, "Gide_log2TPM.txt"), header = TRUE, sep = "\t",
                    row.names = 1, check.names = FALSE)
coldata_all <- read.table(file.path(data_dir, "colData_all.txt"), header = TRUE, sep = " ",
                           quote = "\"", stringsAsFactors = FALSE)

coldata <- coldata_all[coldata_all$Cohort == "Gide", ]
rownames(coldata) <- coldata$rna_id

stopifnot(setequal(colnames(expr), rownames(coldata)))
coldata <- coldata[colnames(expr), ]
stopifnot(identical(colnames(expr), rownames(coldata)))

## ---- Back-transform log2(TPM + 1) to linear TPM --------------------------
## CellTFusion(normalized = FALSE) expects TPM-normalized, NOT log-transformed values.
tpm <- 2^as.matrix(expr) - 1
tpm[tpm < 0] <- 0  # clip tiny negative values from floating-point round-trip

cat("Samples:", ncol(tpm), " Genes:", nrow(tpm), "\n")
cat("Response distribution:\n"); print(table(coldata$Response, coldata$Therapy))

## ---- Run CellTFusion pipeline --------------------------------------------

setwd(results_dir)  # package writes its outputs to "Results/" under the working directory

res <- CellTFusion(
  raw_counts     = tpm,
  normalized     = FALSE,
  deconv_methods = c("Quantiseq", "Epidish", "DeconRNASeq", "DWLS"),
  do_parallel    = FALSE,
  file_name      = "Gide",
  seed           = 123,
  return         = TRUE,
  verbose        = TRUE
)

saveRDS(res, file.path(results_dir, "CellTFusion_Gide_full_result.rds"))

cat("\n=== Pipeline finished ===\n")
cat("Latent factors (TME states):", ncol(res$Latent_spaces$Z), "\n")
print(colnames(res$Latent_spaces$Z))
