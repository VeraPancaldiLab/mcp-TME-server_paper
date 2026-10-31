## Step 1b: Compute TME cell-type deconvolution for Riaz (test cohort)
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

cat("Loading and delogging Riaz cohort...\n")
riaz_tpm <- log2tpm_to_tpm("data/Riaz_log2TPM.txt")
cat("Riaz dim:", dim(riaz_tpm), "\n")

cat("\n=== Deconvolution: Riaz (test cohort) ===\n")
t0 <- Sys.time()
deconv_riaz <- compute.deconvolution(
  raw.counts = riaz_tpm,
  methods = deconv_methods,
  normalized = FALSE,
  doParallel = TRUE,
  workers = 2,
  return = TRUE,
  file_name = "Riaz"
)
cat("Elapsed:", as.numeric(difftime(Sys.time(), t0, units = "mins")), "min\n")
saveRDS(deconv_riaz, "results/deconv_riaz.rds")
cat("Riaz deconvolution dim:", dim(deconv_riaz), "\n")
cat("DONE_RIAZ\n")
