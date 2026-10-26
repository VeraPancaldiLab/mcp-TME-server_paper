#!/usr/bin/env Rscript
# Prepare Gide TPM matrix + clinical data for multideconv

args <- commandArgs(trailingOnly = TRUE)
work_dir <- "/home/marcelo.hurtado/Documents/tme_analysis/9012cf463c/work"

expr_file <- file.path(work_dir, "data", "Gide_log2TPM.txt")
coldata_file <- file.path(work_dir, "data", "colData_all.txt")

log2tpm <- read.delim(expr_file, check.names = FALSE, row.names = 1)
coldata <- read.table(coldata_file, header = TRUE, row.names = 1, check.names = FALSE)

coldata <- coldata[coldata$Cohort == "Gide", ]
stopifnot(all(coldata$Sample_id %in% colnames(log2tpm)))
stopifnot(length(coldata$Sample_id) == ncol(log2tpm))

# align column order to coldata order
log2tpm <- log2tpm[, coldata$Sample_id]

# back-transform log2(TPM+1) -> linear TPM (multideconv expects normalized, linear-scale TPM when normalized = FALSE)
tpm <- (2^log2tpm) - 1
tpm[tpm < 0] <- 0
tpm <- as.matrix(tpm)

cat("Expression matrix:", nrow(tpm), "genes x", ncol(tpm), "samples\n")
cat("Clinical samples:", nrow(coldata), "\n")
cat("Response distribution:\n")
print(table(coldata$Response))
cat("Therapy distribution:\n")
print(table(coldata$Therapy))

saveRDS(tpm, file.path(work_dir, "run_tmp", "gide_tpm.rds"))
saveRDS(coldata, file.path(work_dir, "run_tmp", "gide_coldata.rds"))
