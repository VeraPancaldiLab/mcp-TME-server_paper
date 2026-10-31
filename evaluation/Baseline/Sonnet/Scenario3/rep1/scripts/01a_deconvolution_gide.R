## Step 1a: Compute TME cell-type deconvolution for Gide (training cohort)
suppressMessages({
  library(multideconv)
})

setwd("/home/marcelo.hurtado/Documents/tme_analysis/f8657832ef/work")
dir.create("results", showWarnings = FALSE)

deconv_methods <- c("Quantiseq", "Epidish", "DeconRNASeq", "DWLS")

log2tpm_to_tpm <- function(path) {
  m <- read.table(path, header = TRUE, sep = "\t", check.names = FALSE,
                   row.names = 1, quote = "")
  tpm <- 2^m - 1
  tpm[tpm < 0] <- 0
  as.matrix(tpm)
}

cat("Loading and delogging Gide cohort...\n")
gide_tpm <- log2tpm_to_tpm("data/Gide_log2TPM.txt")
cat("Gide dim:", dim(gide_tpm), "\n")

cat("\n=== Deconvolution: Gide (training cohort) ===\n")
t0 <- Sys.time()
deconv_gide <- compute.deconvolution(
  raw.counts = gide_tpm,
  methods = deconv_methods,
  normalized = FALSE,
  doParallel = TRUE,
  workers = 2,
  return = TRUE,
  file_name = "Gide"
)
cat("Elapsed:", as.numeric(difftime(Sys.time(), t0, units = "mins")), "min\n")
saveRDS(deconv_gide, "results/deconv_gide.rds")
cat("Gide deconvolution dim:", dim(deconv_gide), "\n")
cat("DONE_GIDE\n")
