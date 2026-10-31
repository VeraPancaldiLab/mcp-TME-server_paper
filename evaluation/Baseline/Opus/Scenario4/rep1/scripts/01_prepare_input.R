# RaCInG input preparation for the Gide cohort
# Input: data/Gide_log2TPM.txt (log2(TPM+1), genes x samples)
suppressPackageStartupMessages({
  library(RaCInG)
  library(data.table)
})

out_dir <- "results"
in_dir  <- file.path(out_dir, "racing_input")
dir.create(in_dir, recursive = TRUE, showWarnings = FALSE)

expr <- fread("data/Gide_log2TPM.txt", data.table = FALSE)
rownames(expr) <- expr[[1]]
expr <- as.matrix(expr[, -1])
cat("Expression matrix:", nrow(expr), "genes x", ncol(expr), "samples\n")

# RaCInG expects linear-scale TPM when already_normalized = TRUE
tpm <- 2^expr - 1
tpm[tpm < 0] <- 0

# multideconv applies make.names() to sample IDs ("10_PD1_PRE" -> "X10_PD1_PRE"),
# which breaks the sample matching in prepare_input_files(); use syntactic names
# and strip the prefix again downstream.
stopifnot(!any(duplicated(colnames(tpm))))
colnames(tpm) <- paste0("Gide_", colnames(tpm))
stopifnot(identical(make.names(colnames(tpm)), colnames(tpm)))

# multideconv writes its deconvolution table to ./Results/; keep track of
# whether that folder existed so it can be moved into results/ afterwards
stray_dir <- "Results"
stray_existed <- dir.exists(stray_dir)

# quanTIseq deconvolution, same call prepare_input_files() makes internally.
# It is run here (and passed as `deconv`) because multideconv's subgroup analysis
# drops quanTIseq's "uncharacterized.cell" column (its nomenclature list spells it
# "uncharacterized_cell"), i.e. the non-immune/tumor compartment (~60% of cells),
# and the remaining immune fractions are then renormalized to sum to 1.
deconv_raw <- multideconv::compute.deconvolution(
  tpm, normalized = FALSE, methods = "Quantiseq", file_name = "Gide"
)
deconv_raw <- as.matrix(deconv_raw[colnames(tpm), , drop = FALSE])
colnames(deconv_raw) <- sub("^Quantiseq_TIL10_", "", colnames(deconv_raw))
# quanTIseq "other" = non-immune cells; in melanoma mostly tumor (as in the RaCInG paper)
colnames(deconv_raw)[colnames(deconv_raw) == "uncharacterized.cell"] <- "Cancer"
stopifnot(all(abs(rowSums(deconv_raw) - 1) < 1e-6))
write.csv(deconv_raw, file.path(in_dir, "quantiseq_fractions_Gide.csv"))

stray_file <- file.path(stray_dir, "Deconvolution_Gide.csv")
if (file.exists(stray_file)) {
  file.remove(stray_file)
  if (!stray_existed && length(list.files(stray_dir, all.files = TRUE, no.. = TRUE)) == 0)
    unlink(stray_dir, recursive = TRUE)
}

set.seed(1)
inp <- prepare_input_files(
  counts             = tpm,
  output_folder      = in_dir,
  deconv             = deconv_raw,
  already_normalized = TRUE,
  file_name          = "Gide"
)

saveRDS(inp, file.path(in_dir, "Gide_racing_input.rds"))
cat("\nCell types:", length(inp$celltypes), "\n"); print(inp$celltypes)
cat("Ligands:", length(unique(inp$ligands)), " Receptors:", length(unique(inp$receptors)),
    " LR pairs:", dim(inp$LRmatrix), "\n")
print(round(head(inp$Cmatrix), 3))
