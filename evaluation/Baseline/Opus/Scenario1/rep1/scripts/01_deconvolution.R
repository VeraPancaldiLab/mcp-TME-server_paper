# Step 1: multideconv deconvolution of the Gide cohort (log2 TPM -> linear TPM)
suppressMessages(library(multideconv))

proj <- "/home/marcelo.hurtado/Documents/tme_analysis/548819f72e/work"
out  <- file.path(proj, "results")
dir.create(out, showWarnings = FALSE)
# multideconv writes caches/plots to ./Results; keep them inside results/
setwd(out)

logtpm <- read.delim(file.path(proj, "data/Gide_log2TPM.txt"), row.names = 1, check.names = FALSE)
tpm <- 2^as.matrix(logtpm) - 1          # data are log2(TPM + 1)
tpm[tpm < 0] <- 0

set.seed(123)
deconv <- compute.deconvolution(
  tpm,
  normalized = FALSE,                     # input is already TPM (TRUE would re-normalise raw counts)
  methods = c("Quantiseq", "Epidish", "DeconRNASeq", "DWLS"),
  doParallel = FALSE,                     # parallel DWLS exceeded available RAM
  return = FALSE
)

saveRDS(deconv, file.path(out, "deconvolution_raw.rds"))
write.csv(deconv, file.path(out, "deconvolution_raw_features.csv"))
cat("Deconvolution features:", ncol(deconv), "x samples:", nrow(deconv), "\n")
