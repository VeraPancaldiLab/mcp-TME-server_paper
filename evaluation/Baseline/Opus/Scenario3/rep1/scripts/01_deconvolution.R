# Step 1 - TME cell-type deconvolution of Gide and Riaz cohorts with multideconv
# Run from the project root: Rscript scripts/01_deconvolution.R

suppressPackageStartupMessages({
  library(multideconv)
})

root <- normalizePath(".")
out_dir <- file.path(root, "results")
dir.create(file.path(out_dir, "deconvolution"), recursive = TRUE, showWarnings = FALSE)

# multideconv writes to a hard-coded "Results/" folder relative to the working directory
setwd(out_dir)

read_log2tpm <- function(path) {
  x <- read.delim(path, check.names = FALSE, row.names = 1)
  as.matrix(x)
}

coldata <- read.table(file.path(root, "data/colData_all.txt"), header = TRUE)

cohorts <- c(Gide = "data/Gide_log2TPM.txt", Riaz = "data/Riaz_log2TPM.txt")
methods <- c("Quantiseq", "Epidish", "DeconRNASeq", "DWLS")

for (cohort in names(cohorts)) {
  message("\n==== Deconvolving ", cohort, " ====")
  log2tpm <- read_log2tpm(file.path(root, cohorts[[cohort]]))
  stopifnot(all(colnames(log2tpm) %in% coldata$rna_id))

  # Back-transform to linear TPM and re-close to 1e6 on the shared gene set:
  # deconvolution methods expect linear-scale data, and the Gide/Riaz column
  # sums differ (~0.5M vs ~0.94M) because the gene list was filtered after TPM.
  tpm <- 2^log2tpm - 1
  tpm[tpm < 0] <- 0
  tpm <- sweep(tpm, 2, colSums(tpm), "/") * 1e6

  deconv <- compute.deconvolution(tpm,
                                  methods = methods,
                                  normalized = FALSE,
                                  doParallel = TRUE,
                                  workers = 3,
                                  return = FALSE)
  # multideconv converts sample names with data.frame() (e.g. "10_PD1_PRE" -> "X10_PD1_PRE")
  stopifnot(identical(rownames(deconv), make.names(colnames(tpm))))
  rownames(deconv) <- colnames(tpm)

  write.csv(deconv, file.path(out_dir, "deconvolution", paste0("Deconvolution_", cohort, ".csv")))
  message(cohort, ": ", nrow(deconv), " samples x ", ncol(deconv), " deconvolution features")
}
