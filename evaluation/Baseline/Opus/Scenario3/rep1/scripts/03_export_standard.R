## Step 3 - Export existing results to a standard format (no recomputation)
## Run from the results/ directory

suppressPackageStartupMessages(library(jsonlite))

out_dir <- "standard"
dir.create(out_dir, showWarnings = FALSE)

res <- readRDS("model/pipeML_training_Gide.rds")
model_features <- setdiff(colnames(res$Model$trainingData), ".outcome")

## Subgroups of the final model: one row per member feature
comp <- read.csv("model/subgroup_composition_Gide.csv")
comp <- comp[comp$subgroup %in% model_features, ]
subgroups <- do.call(rbind, lapply(seq_len(nrow(comp)), function(i)
  data.frame(subgroup = comp$subgroup[i], feature = strsplit(comp$members[i], "; ")[[1]])))
write.csv(subgroups, file.path(out_dir, "subgroups_composition.csv"), row.names = FALSE)

cv <- read.csv("model/cv_AUROC_Gide.csv")
write.csv(data.frame(algorithm = cv$model, cv_auroc = cv$Median_AUROC),
          file.path(out_dir, "cv_performance.csv"), row.names = FALSE)

pred <- read.csv("model/test_predictions_Riaz.csv")
write.csv(data.frame(patient = pred$sample, probability_R = pred$prob_responder),
          file.path(out_dir, "test_predictions.csv"), row.names = FALSE)

## Cell type: subgroups are named <cell type>_Subgroup.N, raw features <method>_<signature>_<cell type>
imp <- read.csv("model/feature_importance_SHAP.csv")
parts <- strsplit(imp$feature, "_")
cell_type <- ifelse(grepl("_Subgroup\\.", imp$feature),
                    sapply(parts, `[`, 1), sapply(parts, function(p) p[length(p)]))
write.csv(data.frame(feature = imp$feature, cell_type = cell_type, importance = imp$mean_abs_shap),
          file.path(out_dir, "feature_importance.csv"), row.names = FALSE)

shap <- readRDS("model/shap_values_Gide.rds")
write.csv(data.frame(patient = rownames(shap), shap, check.names = FALSE),
          file.path(out_dir, "shap_values.csv"), row.names = FALSE)

info <- list(selected_algorithm = res$Model$method, training_cohort = "Gide", test_cohort = "Riaz",
             features_built_inside_cv_folds = TRUE, cv_folds = 5, cv_repeats = 10,
             metric = "AUROC", cibersortx = FALSE)
write_json(info, file.path(out_dir, "info.json"), auto_unbox = TRUE, pretty = TRUE)
