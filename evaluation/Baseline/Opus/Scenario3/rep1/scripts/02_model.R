## Step 2 - Train a response classifier on Gide TME features (pipeML), validate on Riaz,
## and explain it with SHAP values.
## Run from the results/ directory: package side outputs are written to ./Results/

suppressPackageStartupMessages({
  library(pipeML)
  library(multideconv)
  library(ggplot2)
})

out_dir <- "model"
dir.create(out_dir, showWarnings = FALSE)
set.seed(123)

## ---- Data -------------------------------------------------------------------
coldata <- read.table("../data/colData_all.txt", header = TRUE)
rownames(coldata) <- coldata$rna_id

deconv_gide <- readRDS("deconvolution/deconvolution_Gide.rds")
deconv_riaz <- readRDS("deconvolution/deconvolution_Riaz.rds")

## multideconv passes the data through data.frame(), which prefixes IDs starting
## with a digit with "X" (Gide): restore the original sample IDs
restore_ids <- function(deconv) {
  ids <- coldata$rna_id[match(rownames(deconv), make.names(coldata$rna_id))]
  stopifnot(!anyNA(ids))
  rownames(deconv) <- ids
  deconv
}
deconv_gide <- restore_ids(deconv_gide)
deconv_riaz <- restore_ids(deconv_riaz)

clin_gide <- coldata[rownames(deconv_gide), ]
clin_riaz <- coldata[rownames(deconv_riaz), ]
stopifnot(!anyNA(clin_gide$Response), !anyNA(clin_riaz$Response))
cat("Gide:", nrow(deconv_gide), "samples |", paste(names(table(clin_gide$Response)), table(clin_gide$Response), collapse = " "), "\n")
cat("Riaz:", nrow(deconv_riaz), "samples |", paste(names(table(clin_riaz$Response)), table(clin_riaz$Response), collapse = " "), "\n")

## ---- Training on Gide -------------------------------------------------------
## Cell subgroups (correlated deconvolution features merged by multideconv) are
## learned inside each CV fold on the training part only, then projected onto the
## held-out part, so the CV estimate is not inflated by feature construction.
res <- compute_features.training.ML(
  features_train = deconv_gide,
  target_var = clin_gide$Response,
  task_type = "classification",
  trait.positive = "R",
  metric = "AUROC",
  k_folds = 5,
  n_rep = 10,
  fold_construction_fun = prepare_multideconv_folds,
  fold_construction_args_fixed = list(ncores = 3, corr = 0.7),
  file_name = "Gide",
  return = TRUE,
  seed = 123)
saveRDS(res, file.path(out_dir, "pipeML_training_Gide.rds"))

write.csv(res$AUROC_median, file.path(out_dir, "cv_AUROC_Gide.csv"))
write.csv(res$AUPRC_median, file.path(out_dir, "cv_AUPRC_Gide.csv"))
cat("\nSelected model:", res$Model$method, "\n")
print(res$Model$bestTune)
print(res$AUROC_median)

## Subgroup definitions learned on all Gide samples (used for the final model)
subgroups <- res$Custom_output
saveRDS(subgroups, file.path(out_dir, "deconvolution_subgroups_Gide.rds"))
comp <- subgroups[["Deconvolution subgroups composition"]]
comp_df <- do.call(rbind, lapply(names(comp), function(cell) {
  do.call(rbind, lapply(names(comp[[cell]]), function(sg)
    data.frame(cell_type = cell, subgroup = sg, members = paste(comp[[cell]][[sg]], collapse = "; "))))
}))
write.csv(comp_df, file.path(out_dir, "subgroup_composition_Gide.csv"), row.names = FALSE)

## ---- Testing on Riaz --------------------------------------------------------
features_riaz <- replicate_deconvolution_subgroups(subgroups, deconv_riaz)
model_features <- setdiff(colnames(res$Model$trainingData), ".outcome")
cat("\nModel features:", length(model_features), "| missing in Riaz:",
    sum(!model_features %in% colnames(features_riaz)), "| NA values in Riaz:",
    sum(is.na(features_riaz[, model_features])), "\n")
write.csv(features_riaz, file.path(out_dir, "features_Riaz.csv"))

pred <- compute_prediction(model = res$Model, test_data = features_riaz,
                           target_var = clin_riaz$Response, trait.positive = "R",
                           task_type = "classification", file.name = "Riaz", return = TRUE)
saveRDS(pred, file.path(out_dir, "prediction_Riaz.rds"))
get_curves(data = pred$Metrics, color = "model",
           auc_roc = pred$AUC$AUROC, auc_prc = pred$AUC$AUPRC,
           roc_band = pred$Curve_bands$ROC, prc_band = pred$Curve_bands$PRC,
           file.name = "Riaz_test")

auc_tab <- data.frame(metric = c("AUROC", "AUPRC"),
                      estimate = c(pred$AUC$AUROC$estimate, pred$AUC$AUPRC$estimate),
                      lower_95CI = c(pred$AUC$AUROC$lower, pred$AUC$AUPRC$lower),
                      upper_95CI = c(pred$AUC$AUROC$upper, pred$AUC$AUPRC$upper),
                      chance_level = c(0.5, mean(clin_riaz$Response == "R")))
write.csv(auc_tab, file.path(out_dir, "test_performance_Riaz.csv"), row.names = FALSE)
write.csv(pred$Metrics, file.path(out_dir, "test_threshold_metrics_Riaz.csv"), row.names = FALSE)
write.csv(data.frame(sample = rownames(features_riaz), response = clin_riaz$Response,
                     prob_responder = pred$Predictions$yes),
          file.path(out_dir, "test_predictions_Riaz.csv"), row.names = FALSE)
print(auc_tab)

## Sensitivity analysis (NOT used for model selection): Riaz AUROC of every model
## trained by pipeML, to see how much the test result depends on the selected algorithm.
sens <- do.call(rbind, lapply(names(res$ML_Models), function(m) {
  p <- tryCatch(compute_prediction(res$ML_Models[[m]], features_riaz, clin_riaz$Response, "R"),
                error = function(e) NULL)
  if (is.null(p)) return(NULL)
  data.frame(model = m, Riaz_AUROC = unname(p$AUC$AUROC$estimate),
             lower = unname(p$AUC$AUROC$lower), upper = unname(p$AUC$AUROC$upper))
}))
write.csv(sens, file.path(out_dir, "sensitivity_all_models_Riaz_AUROC.csv"), row.names = FALSE)
print(sens)

## ---- Feature importance (SHAP on the final model) ----------------------------
shap <- compute_shap_values(res$Model, task_type = "classification", seed = 123)
saveRDS(shap, file.path(out_dir, "shap_values_Gide.rds"))
X_train <- res$Model$trainingData[, colnames(shap), drop = FALSE]

## Direction: Spearman correlation between a feature's value and its SHAP value
## (> 0: higher abundance pushes the prediction towards response).
## Univariate R vs NR Wilcoxon tests in each cohort check whether the effect replicates.
wilcox_dir <- function(x, y) {
  p <- suppressWarnings(stats::wilcox.test(x[y == "R"], x[y == "NR"])$p.value)
  c(diff = median(x[y == "R"], na.rm = TRUE) - median(x[y == "NR"], na.rm = TRUE), p = p)
}
importance <- do.call(rbind, lapply(colnames(shap), function(f) {
  g <- wilcox_dir(X_train[[f]], clin_gide$Response)
  r <- wilcox_dir(features_riaz[[f]], clin_riaz$Response)
  data.frame(feature = f,
             mean_abs_shap = mean(abs(shap[[f]])),
             shap_direction_rho = suppressWarnings(cor(X_train[[f]], shap[[f]], method = "spearman")),
             Gide_median_diff_R_minus_NR = g[["diff"]], Gide_wilcox_p = g[["p"]],
             Riaz_median_diff_R_minus_NR = r[["diff"]], Riaz_wilcox_p = r[["p"]])
}))
importance <- importance[order(-importance$mean_abs_shap), ]
importance$direction <- ifelse(importance$shap_direction_rho > 0, "higher -> response", "higher -> non-response")
importance$same_sign_in_Riaz <- sign(importance$Gide_median_diff_R_minus_NR) == sign(importance$Riaz_median_diff_R_minus_NR)
write.csv(importance, file.path(out_dir, "feature_importance_SHAP.csv"), row.names = FALSE)
print(head(importance, 20))

## Plots: global importance bar plot and SHAP beeswarm of the top features
top <- head(importance, 20)
p_bar <- ggplot(top, aes(x = reorder(feature, mean_abs_shap), y = mean_abs_shap, fill = direction)) +
  geom_col() + coord_flip() +
  scale_fill_manual(values = c("higher -> response" = "#1b7837", "higher -> non-response" = "#c51b7d")) +
  labs(x = NULL, y = "mean |SHAP| (probability of response)",
       title = paste0("Top TME features - ", res$Model$method, " trained on Gide")) +
  theme_bw(base_size = 10)
ggsave(file.path(out_dir, "SHAP_importance_barplot.pdf"), p_bar, width = 9, height = 6)

long <- do.call(rbind, lapply(top$feature, function(f) {
  v <- X_train[[f]]
  data.frame(feature = f, shap = shap[[f]],
             scaled_value = (rank(v) - 1) / max(1, length(v) - 1))
}))
long$feature <- factor(long$feature, levels = rev(top$feature))
p_bee <- ggplot(long, aes(x = shap, y = feature, colour = scaled_value)) +
  geom_vline(xintercept = 0, colour = "grey60") +
  geom_jitter(height = 0.15, size = 1.3, alpha = 0.8) +
  scale_colour_gradient(low = "#2166ac", high = "#b2182b", name = "Feature value\n(rank)") +
  labs(x = "SHAP value (impact on probability of response)", y = NULL) +
  theme_bw(base_size = 10)
ggsave(file.path(out_dir, "SHAP_beeswarm.pdf"), p_bee, width = 9, height = 6)

writeLines(capture.output(sessionInfo()), file.path(out_dir, "sessionInfo.txt"))
