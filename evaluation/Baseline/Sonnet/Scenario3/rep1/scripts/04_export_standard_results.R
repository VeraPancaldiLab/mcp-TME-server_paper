## Step 4: Export already-computed results in a standard, comparable format.
## This script does NOT rerun or recompute anything: it only reads the objects
## already saved under results/ and reshapes/relabels them into results/standard/.
suppressMessages({
  library(jsonlite)
})

setwd("/home/marcelo.hurtado/Documents/tme_analysis/f8657832ef/work")
out_dir <- "results/standard"
dir.create(out_dir, showWarnings = FALSE)

res  <- readRDS("results/model_Gide.rds")
pred <- readRDS("results/prediction_Riaz.rds")
shap <- readRDS("results/shap_values_Gide.rds")
coldata <- read.table("data/colData_all.txt", header = TRUE, sep = " ",
                       stringsAsFactors = FALSE)

## --- subgroups_composition.csv ---
comp <- res$Custom_output[["Deconvolution subgroups composition"]]
rows <- list()
for (cell_type in names(comp)) {
  subs <- comp[[cell_type]]
  for (subgroup_name in names(subs)) {
    members <- subs[[subgroup_name]]
    rows[[length(rows) + 1]] <- data.frame(subgroup = subgroup_name,
                                            feature = members,
                                            stringsAsFactors = FALSE)
  }
}
subgroups_composition <- do.call(rbind, rows)
write.csv(subgroups_composition, file.path(out_dir, "subgroups_composition.csv"), row.names = FALSE)

## --- cv_performance.csv ---
cv_auroc <- read.csv("results/CV_AUROC_median_Gide.csv")
cv_performance <- data.frame(algorithm = cv_auroc$model, cv_auroc = cv_auroc$Median_AUROC)
write.csv(cv_performance, file.path(out_dir, "cv_performance.csv"), row.names = FALSE)

## --- test_predictions.csv ---
riaz_predictions <- read.csv("results/Riaz_predictions.csv")
test_predictions <- data.frame(patient = riaz_predictions$sample,
                                probability_R = riaz_predictions$pred.R)
write.csv(test_predictions, file.path(out_dir, "test_predictions.csv"), row.names = FALSE)

## --- feature_importance.csv ---
shap_importance <- read.csv("results/shap_importance_Gide.csv")
subgroup_pattern <- "^(.+)_Subgroup\\.[0-9]+$"
raw_pattern <- "^[^_]+_[^_]+_(.+)$"
cell_type <- ifelse(
  grepl(subgroup_pattern, shap_importance$feature),
  sub(subgroup_pattern, "\\1", shap_importance$feature),
  sub(raw_pattern, "\\1", shap_importance$feature)
)
feature_importance <- data.frame(feature = shap_importance$feature,
                                  cell_type = cell_type,
                                  importance = shap_importance$mean_abs_shap)
write.csv(feature_importance, file.path(out_dir, "feature_importance.csv"), row.names = FALSE)

## --- shap_values.csv ---
gide_cd <- coldata[coldata$Cohort == "Gide", ]
id_map <- setNames(gide_cd$rna_id, make.names(gide_cd$rna_id))
stopifnot(all(rownames(shap) %in% names(id_map)))
shap_out <- cbind(patient = id_map[rownames(shap)], as.data.frame(shap))
write.csv(shap_out, file.path(out_dir, "shap_values.csv"), row.names = FALSE)

## --- info.json ---
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

cat("Files written to", out_dir, ":\n")
print(list.files(out_dir))
