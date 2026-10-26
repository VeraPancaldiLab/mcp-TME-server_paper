#!/usr/bin/env Rscript
suppressMessages(library(multideconv))

work_dir <- "/home/marcelo.hurtado/Documents/tme_analysis/9012cf463c/work"
run_dir <- file.path(work_dir, "run_tmp", "dwls")
dir.create(run_dir, showWarnings = FALSE, recursive = TRUE)
setwd(run_dir)

tpm <- readRDS(file.path(work_dir, "run_tmp", "gide_tpm.rds"))

t0 <- Sys.time()
deconv_dwls <- compute.deconvolution(
  raw.counts = tpm,
  methods = c("DWLS"),
  signatures_select = NULL,
  normalized = FALSE,
  doParallel = FALSE,
  return = TRUE,
  file_name = "Gide_dwls"
)
cat("Elapsed:", as.numeric(Sys.time() - t0, units = "mins"), "min\n")
cat("Dim:", dim(deconv_dwls), "\n")
saveRDS(deconv_dwls, file.path(work_dir, "run_tmp", "gide_deconv_dwls.rds"))
cat("DONE\n")
