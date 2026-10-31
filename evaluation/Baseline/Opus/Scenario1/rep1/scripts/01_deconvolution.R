# Step 1: multi-method / multi-signature deconvolution of the Gide cohort with multideconv
# Input:  data/Gide_log2TPM.txt (genes x samples, log2(TPM + 1))
# Output: results/Results/Deconvolution_Gide.csv (+ multideconv cache)

suppressPackageStartupMessages(library(multideconv))

proj_dir <- normalizePath(".")
expr <- as.matrix(read.delim(file.path(proj_dir, "data/Gide_log2TPM.txt"),
                             check.names = FALSE, row.names = 1))

# Back-transform log2(TPM + 1) -> TPM; data are already normalised, so normalized = FALSE
tpm <- 2^expr - 1
tpm[tpm < 0] <- 0
cat("Samples:", ncol(tpm), " Genes:", nrow(tpm), "\n")

# multideconv writes to a hard-coded "Results/" folder relative to the working directory
dir.create(file.path(proj_dir, "results"), showWarnings = FALSE)
setwd(file.path(proj_dir, "results"))

set.seed(123)
deconv <- compute.deconvolution(
  tpm,
  methods    = c("Quantiseq", "Epidish", "DeconRNASeq", "DWLS"),  # CBSX needs CIBERSORTx credentials
  normalized = FALSE,
  doParallel = FALSE,  # parallel DWLS ran out of memory (15 GB machine); sequential runs are also cached

  return     = TRUE,
  file_name  = "Gide"
)

cat("Deconvolution matrix:", dim(deconv), "\n")
saveRDS(deconv, "deconvolution_raw.rds")
