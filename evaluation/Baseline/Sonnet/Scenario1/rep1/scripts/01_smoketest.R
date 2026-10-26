#!/usr/bin/env Rscript
suppressMessages(library(multideconv))

work_dir <- "/home/marcelo.hurtado/Documents/tme_analysis/9012cf463c/work"
run_dir <- file.path(work_dir, "run_tmp", "smoke")
dir.create(run_dir, showWarnings = FALSE, recursive = TRUE)
setwd(run_dir)

tpm <- readRDS(file.path(work_dir, "run_tmp", "gide_tpm.rds"))

t0 <- Sys.time()
deconv <- compute.deconvolution(
  raw.counts = tpm,
  methods = c("Quantiseq"),
  normalized = FALSE,
  return = FALSE,
  file_name = "smoke"
)
cat("Elapsed:", as.numeric(Sys.time() - t0, units = "secs"), "s\n")
cat("Dim:", dim(deconv), "\n")
print(head(deconv[, 1:5]))
