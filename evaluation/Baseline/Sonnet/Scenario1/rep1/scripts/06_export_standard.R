#!/usr/bin/env Rscript
# Convert already-produced results into a standard, comparable format.
# Reads only existing RDS/CSV outputs; computes nothing new.
suppressMessages(library(jsonlite))

work_dir <- "/home/marcelo.hurtado/Documents/tme_analysis/9012cf463c/work"
out_dir <- file.path(work_dir, "results", "standard")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

fix_names <- function(x) sub("^X", "", x)

# ---- deconvolution_raw.csv ----
raw <- readRDS(file.path(work_dir, "run_tmp", "gide_deconv_raw.rds"))
raw_df <- data.frame(patient = fix_names(rownames(raw)), raw, check.names = FALSE, row.names = NULL)
write.csv(raw_df, file.path(out_dir, "deconvolution_raw.csv"), row.names = FALSE)

# ---- deconvolution_harmonized.csv (main harmonized result: detailed cell-type subgroups) ----
ct <- readRDS(file.path(work_dir, "run_tmp", "gide_subgroups_celltypes.rds"))
mat <- ct[["Deconvolution matrix"]]
harm_df <- data.frame(patient = fix_names(rownames(mat)), mat, check.names = FALSE, row.names = NULL)
write.csv(harm_df, file.path(out_dir, "deconvolution_harmonized.csv"), row.names = FALSE)

# ---- subgroups_composition.csv ----
comp <- ct[["Deconvolution subgroups composition"]]
rows <- list()
for (celltype in names(comp)) {
  subgroups <- comp[[celltype]]
  for (sg_name in names(subgroups)) {
    feats <- subgroups[[sg_name]]
    rows[[length(rows) + 1]] <- data.frame(subgroup = sg_name, feature = feats, stringsAsFactors = FALSE)
  }
}
comp_df <- do.call(rbind, rows)
write.csv(comp_df, file.path(out_dir, "subgroups_composition.csv"), row.names = FALSE)

# ---- immune_score.csv (main presented ranking: Immune/Stromal composite z-scores) ----
scores <- read.csv(file.path(work_dir, "results", "immune_stromal_scores_per_sample.csv"), check.names = FALSE)
score_df <- data.frame(
  patient = scores$Sample_id,
  immune_score = scores$Immune_score,
  stromal_score = scores$Stromal_score
)
write.csv(score_df, file.path(out_dir, "immune_score.csv"), row.names = FALSE)

# ---- info.json ----
methods_ran <- sort(unique(sub("_.*", "", colnames(raw))))
info <- list(
  input_scale = "linear TPM",
  methods = methods_ran,
  cibersortx = FALSE
)
write(toJSON(info, auto_unbox = TRUE, pretty = TRUE), file.path(out_dir, "info.json"))

cat("Rows written - raw:", nrow(raw_df), "harmonized:", nrow(harm_df),
    "composition:", nrow(comp_df), "scores:", nrow(score_df), "\n")
cat("Methods in info.json:", paste(methods_ran, collapse = ", "), "\n")
