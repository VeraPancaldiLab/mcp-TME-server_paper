## Step 1 - TME cell composition by multi-method deconvolution (multideconv)
## Run from the results/ directory: package side outputs are written to ./Results/

suppressPackageStartupMessages(library(multideconv))

data_dir <- "../data"
out_dir <- "deconvolution"
dir.create(out_dir, showWarnings = FALSE)

methods <- c("Quantiseq", "Epidish", "DeconRNASeq", "DWLS")

## Inputs are log2(TPM + 1) restricted to a shared gene set. Back-transform to TPM
## and rescale each sample to 1e6 over these genes so both cohorts are on the same scale.
load_tpm <- function(file) {
  x <- as.matrix(read.delim(file.path(data_dir, file), row.names = 1, check.names = FALSE))
  tpm <- 2^x - 1
  tpm[tpm < 0] <- 0
  sweep(tpm, 2, colSums(tpm), "/") * 1e6
}

for (cohort in c("Gide", "Riaz")) {
  tpm <- load_tpm(paste0(cohort, "_log2TPM.txt"))
  cat("\n#####", cohort, ":", nrow(tpm), "genes x", ncol(tpm), "samples\n")
  deconv <- compute.deconvolution(tpm, methods = methods, normalized = FALSE,
                                  doParallel = TRUE, workers = 3,
                                  return = FALSE, file_name = cohort)
  saveRDS(deconv, file.path(out_dir, paste0("deconvolution_", cohort, ".rds")))
  write.csv(deconv, file.path(out_dir, paste0("deconvolution_", cohort, ".csv")))
  cat(cohort, "deconvolution:", nrow(deconv), "samples x", ncol(deconv), "features\n")
}
