# Step 2 - Predict immunotherapy response from TME composition with pipeML
# Train (repeated CV, multideconv subgroups built inside each fold): Gide
# Independent test: Riaz
# Run from the project root: Rscript scripts/02_ml_model.R

suppressPackageStartupMessages({
  library(pipeML)
  library(multideconv)
  library(dplyr)
  library(ggplot2)
  library(shapviz)
})

root <- normalizePath(".")
out_dir <- file.path(root, "results")
model_dir <- file.path(out_dir, "model")
dir.create(model_dir, recursive = TRUE, showWarnings = FALSE)

# pipeML / multideconv read and write a hard-coded "Results/" folder relative to the working directory
setwd(out_dir)

seed <- 123
n_cores <- 3  # memory limit (~6 GB) of this machine

# ---------------------------------------------------------------- data
coldata <- read.table(file.path(root, "data/colData_all.txt"), header = TRUE)
rownames(coldata) <- coldata$rna_id

deconv_train <- read.csv(file.path(out_dir, "deconvolution/Deconvolution_Gide.csv"), row.names = 1, check.names = FALSE)
deconv_test <- read.csv(file.path(out_dir, "deconvolution/Deconvolution_Riaz.csv"), row.names = 1, check.names = FALSE)
stopifnot(identical(colnames(deconv_train), colnames(deconv_test)))

y_train <- coldata[rownames(deconv_train), "Response"]
y_test <- coldata[rownames(deconv_test), "Response"]
stopifnot(!anyNA(y_train), !anyNA(y_test))
message("Train (Gide): ", paste(names(table(y_train)), table(y_train), collapse = ", "))
message("Test (Riaz): ", paste(names(table(y_test)), table(y_test), collapse = ", "))

# ---------------------------------------------------------------- training
# multideconv groups highly correlated deconvolution features into cell subgroups.
# Running it as the fold construction function rebuilds the subgroups on the
# training part of every fold and projects the held-out part onto them.
res <- compute_features.training.ML(features_train = deconv_train,
                                    target_var = y_train,
                                    trait.positive = "R",
                                    task_type = "classification",
                                    metric = "AUROC",
                                    k_folds = 5,
                                    n_rep = 10,
                                    fold_construction_fun = prepare_multideconv_folds,
                                    fold_construction_args_fixed = list(ncores = n_cores),
                                    file_name = "Gide_CV",
                                    return = TRUE,
                                    seed = seed)
saveRDS(res, file.path(model_dir, "pipeML_training_result.rds"))

cv_auroc <- res$AUROC_median %>% data.frame(check.names = FALSE)
cv_auprc <- res$AUPRC_median %>% data.frame(check.names = FALSE)
write.csv(cv_auroc, file.path(model_dir, "CV_AUROC_per_model_Gide.csv"))
write.csv(cv_auprc, file.path(model_dir, "CV_AUPRC_per_model_Gide.csv"))
best_model <- res$Model
message("Selected model: ", best_model$method)
print(best_model$bestTune)

# Features built by multideconv on all Gide samples (used by the final model)
deconv_full <- res$Custom_output
saveRDS(deconv_full, file.path(model_dir, "multideconv_subgroups_Gide.rds"))
features_train <- deconv_full[["Deconvolution matrix"]]
write.csv(features_train, file.path(model_dir, "Features_train_Gide.csv"))
subgroups <- do.call(c, unname(deconv_full[["Deconvolution subgroups composition"]]))
write.csv(data.frame(subgroup = names(subgroups),
                     n_members = lengths(subgroups),
                     members = sapply(subgroups, paste, collapse = "; ")),
          file.path(model_dir, "Subgroup_composition.csv"), row.names = FALSE)

# ---------------------------------------------------------------- independent test
features_test <- replicate_deconvolution_subgroups(deconv_full, deconv_test)
write.csv(features_test, file.path(model_dir, "Features_test_Riaz.csv"))

pred <- compute_prediction(model = best_model,
                           test_data = features_test,
                           target_var = y_test,
                           trait.positive = "R",
                           task_type = "classification")
saveRDS(pred, file.path(model_dir, "prediction_Riaz.rds"))
write.csv(pred$Metrics, file.path(model_dir, "Test_metrics_Riaz.csv"), row.names = FALSE)
write.csv(data.frame(sample = rownames(features_test), response = y_test,
                     prob_R = pred$Predictions$yes),
          file.path(model_dir, "Test_predictions_Riaz.csv"), row.names = FALSE)

get_curves(data = pred$Metrics,
           color = "model",
           auc_roc = pred$AUC$AUROC,
           auc_prc = pred$AUC$AUPRC,
           roc_band = pred$Curve_bands$ROC,
           prc_band = pred$Curve_bands$PRC,
           file.name = "Riaz_test")

# Test performance of every trained model (descriptive only: the model used is
# the one selected by cross-validation in Gide)
all_test <- lapply(names(res$ML_Models), function(m) {
  p <- tryCatch(compute_prediction(model = res$ML_Models[[m]], test_data = features_test,
                                   target_var = y_test, trait.positive = "R",
                                   task_type = "classification"),
                error = function(e) NULL)
  if (is.null(p)) return(NULL)
  data.frame(model = m,
             test_AUROC = p$AUC$AUROC$estimate, AUROC_lower = p$AUC$AUROC$lower, AUROC_upper = p$AUC$AUROC$upper,
             test_AUPRC = p$AUC$AUPRC$estimate, AUPRC_lower = p$AUC$AUPRC$lower, AUPRC_upper = p$AUC$AUPRC$upper)
}) %>% bind_rows()
write.csv(all_test, file.path(model_dir, "Test_performance_all_models_Riaz.csv"), row.names = FALSE)

summary_tbl <- data.frame(
  selected_model = best_model$method,
  hyperparameters = paste(names(best_model$bestTune), unlist(best_model$bestTune), sep = "=", collapse = ", "),
  n_features = ncol(best_model$trainingData) - 1,
  test_AUROC = pred$AUC$AUROC$estimate, test_AUROC_CI = sprintf("%.3f-%.3f", pred$AUC$AUROC$lower, pred$AUC$AUROC$upper),
  test_AUPRC = pred$AUC$AUPRC$estimate, test_AUPRC_CI = sprintf("%.3f-%.3f", pred$AUC$AUPRC$lower, pred$AUC$AUPRC$upper),
  test_prevalence_R = mean(y_test == "R"))
write.csv(summary_tbl, file.path(model_dir, "Summary_selected_model.csv"), row.names = FALSE)
print(summary_tbl)

# ---------------------------------------------------------------- interpretation
shap_dir <- file.path(out_dir, "interpretation")
dir.create(shap_dir, showWarnings = FALSE)

shap <- compute_shap_values(best_model, task_type = "classification", seed = seed)
X_shap <- best_model$trainingData[, colnames(shap), drop = FALSE]
write.csv(shap, file.path(shap_dir, "SHAP_values_Gide.csv"))

importance <- data.frame(feature = colnames(shap),
                         mean_abs_SHAP = colMeans(abs(shap)),
                         # sign of the effect: > 0 means higher values push towards response
                         spearman_value_vs_SHAP = sapply(colnames(shap), function(f)
                           suppressWarnings(cor(X_shap[[f]], shap[[f]], method = "spearman")))) %>%
  arrange(desc(mean_abs_SHAP))

# Model-independent check: univariate association with response in each cohort
uni <- function(X, y, f) {
  if (!f %in% colnames(X) || all(is.na(X[[f]]))) return(c(NA, NA))
  w <- suppressWarnings(wilcox.test(X[[f]][y == "R"], X[[f]][y == "NR"]))
  auc <- w$statistic / (sum(y == "R") * sum(y == "NR"))  # P(R > NR)
  c(unname(auc), w$p.value)
}
uni_train <- t(sapply(importance$feature, function(f) uni(features_train, y_train, f)))
uni_test <- t(sapply(importance$feature, function(f) uni(features_test, y_test, f)))
importance <- importance %>%
  mutate(Gide_AUC_R_vs_NR = uni_train[, 1], Gide_wilcox_p = uni_train[, 2],
         Riaz_AUC_R_vs_NR = uni_test[, 1], Riaz_wilcox_p = uni_test[, 2],
         Gide_FDR = p.adjust(Gide_wilcox_p, "BH"), Riaz_FDR = p.adjust(Riaz_wilcox_p, "BH"))
write.csv(importance, file.path(shap_dir, "Feature_importance_SHAP.csv"), row.names = FALSE)
print(head(importance, 15))

sv <- shapviz(as.matrix(shap), X = X_shap, baseline = attr(shap, "baseline"))
top_n <- min(15, ncol(shap))
p_bar <- sv_importance(sv, kind = "bar", max_display = top_n) +
  ggtitle(paste0("Global importance (", best_model$method, ", Gide)")) + theme_bw()
p_bee <- sv_importance(sv, kind = "beeswarm", max_display = top_n) +
  ggtitle("SHAP values: positive = towards response") + theme_bw()
ggsave(file.path(shap_dir, "SHAP_importance_bar.pdf"), p_bar, width = 8, height = 6)
ggsave(file.path(shap_dir, "SHAP_beeswarm.pdf"), p_bee, width = 9, height = 6)

top_feats <- head(importance$feature, 6)
for (f in top_feats) {
  p <- sv_dependence(sv, v = f, color_var = NULL) + theme_bw()
  ggsave(file.path(shap_dir, paste0("SHAP_dependence_", f, ".pdf")), p, width = 5, height = 4)
}

# Distribution of the top features by response in both cohorts
long <- bind_rows(
  data.frame(cohort = "Gide (train)", response = y_train, features_train[, top_feats, drop = FALSE], check.names = FALSE),
  data.frame(cohort = "Riaz (test)", response = y_test, features_test[, top_feats, drop = FALSE], check.names = FALSE)) %>%
  tidyr::pivot_longer(all_of(top_feats), names_to = "feature", values_to = "value") %>%
  mutate(feature = factor(feature, levels = top_feats))
p_box <- ggplot(long, aes(response, value, fill = response)) +
  geom_boxplot(outlier.shape = NA, alpha = 0.6) +
  geom_jitter(width = 0.15, size = 0.8) +
  facet_grid(cohort ~ feature, scales = "free_y") +
  scale_fill_manual(values = c(NR = "#999999", R = "#D55E00")) +
  theme_bw() + theme(strip.text.x = element_text(size = 6), legend.position = "none") +
  labs(x = NULL, y = "Cell fraction (subgroup)")
ggsave(file.path(shap_dir, "Top_features_by_response.pdf"), p_box, width = 14, height = 6)

writeLines(capture.output(sessionInfo()), file.path(out_dir, "logs/sessionInfo.txt"))
message("Done.")
