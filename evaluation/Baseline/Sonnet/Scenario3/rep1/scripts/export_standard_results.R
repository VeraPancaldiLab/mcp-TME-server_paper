## Convert already-produced results into standard, comparable CSV/JSON files.
## Reads only existing saved objects; computes nothing new, reruns no method.

suppressPackageStartupMessages({
  library(multideconv)
  library(jsonlite)
})

results_dir  <- "/home/marcelo.hurtado/Documents/tme_analysis/d91d50f6b3/work/results"
out_dir      <- file.path(results_dir, "standard")
dir.create(out_dir, showWarnings = FALSE)

# De-sanitize sample names mangled by data.frame()'s make.names() inside compute.deconvolution()
# (digit-leading Gide IDs got an "X" prefix; verified this recovers the exact original input names)
restore_names <- function(x) sub("^X([0-9])", "\\1", x)

## ---------------------------------------------------------------------------
## deconvolution_raw_Gide.csv / deconvolution_raw_Riaz.csv
## ---------------------------------------------------------------------------

dt <- readRDS(file.path(results_dir, "deconvolution_tables.rds"))

write_raw <- function(mat, file) {
  df <- data.frame(patient = restore_names(rownames(mat)), mat, check.names = FALSE, row.names = NULL)
  write.csv(df, file, row.names = FALSE)
}

write_raw(dt$deconv_train, file.path(out_dir, "deconvolution_raw_Gide.csv"))
write_raw(dt$deconv_test,  file.path(out_dir, "deconvolution_raw_Riaz.csv"))

## ---------------------------------------------------------------------------
## subgroups_composition.csv
## ---------------------------------------------------------------------------

res <- readRDS(file.path(results_dir, "training_result.rds"))
final_features <- setdiff(colnames(res$Model$trainingData), ".outcome")

comp <- res$Custom_output[["Deconvolution subgroups composition"]]

rows <- list()
for (cell_type in names(comp)) {
  for (subgroup in names(comp[[cell_type]])) {
    if (subgroup %in% final_features) {
      members <- comp[[cell_type]][[subgroup]]
      rows[[length(rows) + 1]] <- data.frame(subgroup = subgroup, feature = members, stringsAsFactors = FALSE)
    }
  }
}
subgroups_composition <- do.call(rbind, rows)
write.csv(subgroups_composition, file.path(out_dir, "subgroups_composition.csv"), row.names = FALSE)

## ---------------------------------------------------------------------------
## cv_performance.csv  (metric used for model selection: AUROC)
## ---------------------------------------------------------------------------

cv_perf <- data.frame(
  algorithm = res$AUROC_median$model,
  cv_auroc  = res$AUROC_median$Median_AUROC
)
write.csv(cv_perf, file.path(out_dir, "cv_performance.csv"), row.names = FALSE)

## ---------------------------------------------------------------------------
## test_predictions.csv
## ---------------------------------------------------------------------------

pred <- readRDS(file.path(results_dir, "test_prediction.rds"))
test_predictions <- data.frame(
  patient         = restore_names(rownames(pred$Predictions)),
  probability_R   = pred$Predictions$yes
)
write.csv(test_predictions, file.path(out_dir, "test_predictions.csv"), row.names = FALSE)

## ---------------------------------------------------------------------------
## feature_importance.csv  (feature, cell_type, importance = mean |SHAP|)
## ---------------------------------------------------------------------------

importance_df <- read.csv(file.path(results_dir, "shap_feature_importance.csv"), stringsAsFactors = FALSE)

# cell_type of merged subgroup features: from the composition list keys
subgroup_to_celltype <- character(0)
for (cell_type in names(comp)) {
  for (subgroup in names(comp[[cell_type]])) {
    subgroup_to_celltype[subgroup] <- cell_type
  }
}

# cell_type of singleton (pass-through) raw features: longest matching suffix
# in multideconv's own cell type nomenclature (static package metadata)
nomenclature <- multideconv::get_cell_type_nomenclature()
nomenclature <- nomenclature[order(-nchar(nomenclature))]

match_celltype_suffix <- function(feature) {
  for (ct in nomenclature) {
    if (endsWith(feature, paste0("_", ct))) return(ct)
  }
  NA_character_
}

cell_type <- sapply(importance_df$Feature, function(f) {
  if (!is.na(subgroup_to_celltype[f])) return(unname(subgroup_to_celltype[f]))
  match_celltype_suffix(f)
})

feature_importance <- data.frame(
  feature    = importance_df$Feature,
  cell_type  = unname(cell_type),
  importance = importance_df$Mean_abs_SHAP
)
write.csv(feature_importance, file.path(out_dir, "feature_importance.csv"), row.names = FALSE)

## ---------------------------------------------------------------------------
## shap_values.csv  (one row per training-cohort patient, one column per feature)
## ---------------------------------------------------------------------------

shap <- readRDS(file.path(results_dir, "shap_values.rds"))
shap_out <- data.frame(patient = restore_names(rownames(shap)), as.data.frame(shap), check.names = FALSE, row.names = NULL)
write.csv(shap_out, file.path(out_dir, "shap_values.csv"), row.names = FALSE)

## ---------------------------------------------------------------------------
## info.json
## ---------------------------------------------------------------------------

info <- list(
  selected_algorithm = res$Model$method,
  training_cohort = "Gide",
  test_cohort = "Riaz",
  features_built_inside_cv_folds = TRUE,
  cv_folds = 5,
  cv_repeats = 10,
  metric = "AUROC",
  cibersortx = FALSE
)
writeLines(jsonlite::toJSON(info, auto_unbox = TRUE, pretty = TRUE), file.path(out_dir, "info.json"))

cat("Done.\n")
cat(paste(list.files(out_dir), collapse = "\n"), "\n")
