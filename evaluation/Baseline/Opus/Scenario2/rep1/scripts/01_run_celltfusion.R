# Run the full CellTFusion pipeline on the Gide cohort (pre-treatment melanoma, anti-PD1 +/- anti-CTLA4).
# Usage (from the project root): Rscript scripts/01_run_celltfusion.R
# CellTFusion writes its own outputs to "Results/" relative to the working directory,
# so we run from inside results/ -> package outputs land in results/Results/.

suppressPackageStartupMessages({
  library(CellTFusion)
})

root <- normalizePath(".")
expr_file <- file.path(root, "data/Gide_log2TPM.txt")
coldata_file <- file.path(root, "data/colData_all.txt")
out_dir <- file.path(root, "results")
dir.create(out_dir, showWarnings = FALSE)
setwd(out_dir)

# ---- Expression: log2(TPM + 1) -> TPM ----
# CellTFusion with normalized = FALSE expects non-log TPM (it computes log2(TPM + 1) itself).
log2tpm <- as.matrix(read.delim(expr_file, row.names = 1, check.names = FALSE))
tpm <- 2^log2tpm - 1
tpm[tpm < 0] <- 0
cat("Expression:", nrow(tpm), "genes x", ncol(tpm), "samples\n")

# ---- Clinical data ----
coldata <- read.table(coldata_file, header = TRUE, stringsAsFactors = FALSE)
coldata <- coldata[coldata$Cohort == "Gide", ]
rownames(coldata) <- coldata$rna_id
stopifnot(all(colnames(tpm) %in% rownames(coldata)))
coldata <- coldata[colnames(tpm), ]
saveRDS(coldata, "Gide_coldata.rds")

# ---- CellTFusion ----
# CIBERSORTx is skipped (no credentials); the remaining four methods are used.
res <- CellTFusion(
  raw_counts = tpm,
  normalized = FALSE,
  deconv_methods = c("Quantiseq", "Epidish", "DeconRNASeq", "DWLS"),
  do_parallel = TRUE,
  workers = 3,  # 6 GB container memory limit
  file_name = "Gide",
  TF.collection = "CollecTRI",
  method = "ulm",
  return = TRUE,
  verbose = TRUE,
  seed = 123
)

saveRDS(res, "CellTFusion_Gide.rds")
cat("Done. Elements:", paste(names(res), collapse = ", "), "\n")
