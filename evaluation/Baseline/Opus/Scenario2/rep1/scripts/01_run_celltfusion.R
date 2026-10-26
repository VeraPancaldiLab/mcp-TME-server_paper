# Run the CellTFusion pipeline on the Gide cohort (pre-treatment melanoma, anti-PD1 / anti-PD1+CTLA4)
# Usage: Rscript scripts/01_run_celltfusion.R   (from the project root)

suppressPackageStartupMessages(library(CellTFusion))

root <- normalizePath(".")
out_dir <- file.path(root, "results")
dir.create(out_dir, showWarnings = FALSE)

# Input: log2(TPM + 1), genes x samples
log_tpm <- as.matrix(read.delim(file.path(root, "data/Gide_log2TPM.txt"),
                                row.names = 1, check.names = FALSE))

# CellTFusion expects raw counts or non-log TPM: undo the log2(x + 1) transform.
# The file holds ~19k genes only, so TPM no longer sum to 1e6 per sample; re-close
# them over the retained genes so that every sample is on the same scale.
tpm <- 2^log_tpm - 1
tpm[tpm < 0] <- 0
tpm <- sweep(tpm, 2, colSums(tpm), "/") * 1e6

# The package writes to "Results/" relative to the working directory
setwd(out_dir)

res <- CellTFusion(
  raw_counts = tpm,
  normalized = FALSE,
  deconv_methods = c("Quantiseq", "Epidish", "DeconRNASeq", "DWLS"),
  do_parallel = TRUE,
  workers = 4,
  file_name = "Gide",
  TF.collection = "CollecTRI",
  seed = 123
)

saveRDS(res, file.path(out_dir, "CellTFusion_Gide.rds"))
sessionInfo()
