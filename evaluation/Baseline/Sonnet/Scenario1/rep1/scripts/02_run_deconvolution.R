#!/usr/bin/env Rscript
suppressMessages(library(multideconv))

work_dir <- "/home/marcelo.hurtado/Documents/tme_analysis/9012cf463c/work"
run_dir <- file.path(work_dir, "run_tmp", "full")
dir.create(run_dir, showWarnings = FALSE, recursive = TRUE)
setwd(run_dir)

tpm <- readRDS(file.path(work_dir, "run_tmp", "gide_tpm.rds"))

t0 <- Sys.time()
deconv <- compute.deconvolution(
  raw.counts = tpm,
  methods = c("Quantiseq", "Epidish", "DeconRNASeq", "DWLS"),
  signatures_select = NULL,
  normalized = FALSE,
  doParallel = TRUE,
  workers = 6,
  return = TRUE,
  file_name = "Gide"
)
cat("Elapsed:", as.numeric(Sys.time() - t0, units = "mins"), "min\n")
cat("Dim:", dim(deconv), "\n")
saveRDS(deconv, file.path(work_dir, "run_tmp", "gide_deconv_raw.rds"))
