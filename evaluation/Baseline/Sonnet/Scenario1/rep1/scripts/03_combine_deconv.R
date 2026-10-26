#!/usr/bin/env Rscript
work_dir <- "/home/marcelo.hurtado/Documents/tme_analysis/9012cf463c/work"

fast <- readRDS(file.path(work_dir, "run_tmp", "gide_deconv_fast.rds"))
dwls <- readRDS(file.path(work_dir, "run_tmp", "gide_deconv_dwls.rds"))

stopifnot(identical(rownames(fast), rownames(dwls)))

deconv <- cbind(fast, dwls)
cat("Combined dim:", dim(deconv), "\n")
cat("Methods present:\n")
print(table(sub("_.*", "", colnames(deconv))))

saveRDS(deconv, file.path(work_dir, "run_tmp", "gide_deconv_raw.rds"))
