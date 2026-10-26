# Convert already-produced results into a standard format (no recomputation).
suppressMessages(library(jsonlite))
res <- "results"
out <- file.path(res, "standard")
dir.create(out, showWarnings = FALSE, recursive = TRUE)

input_ids <- function(co) {
  h <- readLines(sprintf("data/%s_log2TPM.txt", co), n = 1)
  strsplit(h, "\t")[[1]][-1]
}
with_patient <- function(df, ids_expected) {
  stopifnot(setequal(rownames(df), ids_expected))
  cbind(patient = rownames(df), df, stringsAsFactors = FALSE)
}
gide_ids <- input_ids("Gide"); riaz_ids <- input_ids("Riaz")

# Raw deconvolution (Gide: copy with original IDs restored from the deconvolution step's output)
d <- read.csv(file.path(res, "inputs/Gide_deconvolution_raw.csv"), row.names = 1, check.names = FALSE)
write.csv(with_patient(d, gide_ids), file.path(out, "deconvolution_raw_Gide.csv"), row.names = FALSE)
d <- read.csv(file.path(res, "01_deconvolution/Riaz/result.csv"), row.names = 1, check.names = FALSE)
write.csv(with_patient(d, riaz_ids), file.path(out, "deconvolution_raw_Riaz.csv"), row.names = FALSE)

# Subgroup composition of the final model (fold-construction refit on all Gide training samples)
comp <- readRDS(file.path(res, "03_model_training_Gide/final_model_subgroups.rds"))[["Deconvolution subgroups composition"]]
rows <- do.call(rbind, unname(lapply(comp, function(ct) {
  if (is.null(ct) || !length(ct)) return(NULL)
  do.call(rbind, lapply(names(ct), function(s) data.frame(subgroup = s, feature = ct[[s]])))
})))
write.csv(rows, file.path(out, "subgroups_composition.csv"), row.names = FALSE)

# CV performance
a <- read.csv(file.path(res, "03_model_training_Gide/result_AUROC_median.csv"))
write.csv(data.frame(algorithm = a$model, cv_auroc = a$Median_AUROC), file.path(out, "cv_performance.csv"), row.names = FALSE)

# Test predictions (Riaz)
p <- read.csv(file.path(res, "04_external_test_Riaz/prediction/result_Predictions.csv"), row.names = 1, check.names = FALSE)
stopifnot(setequal(rownames(p), riaz_ids))
write.csv(data.frame(patient = rownames(p), probability_R = p$yes), file.path(out, "test_predictions.csv"), row.names = FALSE)

# Feature importance (mean |SHAP|)
fi <- read.csv(file.path(res, "06_feature_drivers_summary/SHAP_feature_importance_ranked.csv"), check.names = FALSE)
write.csv(data.frame(feature = fi$feature, cell_type = fi$cell_type, importance = fi$mean_abs_SHAP),
          file.path(out, "feature_importance.csv"), row.names = FALSE)

# SHAP values (Gide training samples)
s <- read.csv(file.path(res, "05_SHAP_feature_importance/result.csv"), row.names = 1, check.names = FALSE)
write.csv(with_patient(s, gide_ids), file.path(out, "shap_values.csv"), row.names = FALSE)

# Run info
info <- list(selected_algorithm = "RF", training_cohort = "Gide", test_cohort = "Riaz",
             features_built_inside_cv_folds = TRUE, cv_folds = 5, cv_repeats = 10,
             metric = "AUROC", cibersortx = TRUE)
write_json(info, file.path(out, "info.json"), auto_unbox = TRUE, pretty = TRUE)

for (f in list.files(out, full.names = TRUE)) cat(basename(f), if (grepl("csv$", f)) paste(dim(read.csv(f, check.names = FALSE)), collapse = "x"), "\n")
