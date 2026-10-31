## Step 2: Train a classifier on Gide TME composition and predict on Riaz
suppressMessages({
  library(pipeML)
  library(multideconv)
})

setwd("/home/marcelo.hurtado/Documents/tme_analysis/f8657832ef/work")

set.seed(123)

## --- Load deconvolution matrices and clinical data ---
deconv_gide <- readRDS("results/deconv_gide.rds")
deconv_riaz <- readRDS("results/deconv_riaz.rds")

coldata <- read.table("data/colData_all.txt", header = TRUE, sep = " ",
                       stringsAsFactors = FALSE)

gide_cd <- coldata[coldata$Cohort == "Gide", ]
riaz_cd <- coldata[coldata$Cohort == "Riaz", ]

rownames(gide_cd) <- make.names(gide_cd$rna_id)
rownames(riaz_cd) <- make.names(riaz_cd$rna_id)

gide_cd <- gide_cd[rownames(deconv_gide), ]
riaz_cd <- riaz_cd[rownames(deconv_riaz), ]

stopifnot(all(rownames(gide_cd) == rownames(deconv_gide)))
stopifnot(all(rownames(riaz_cd) == rownames(deconv_riaz)))

cat("Gide response counts:\n"); print(table(gide_cd$Response))
cat("Riaz response counts:\n"); print(table(riaz_cd$Response))

## --- Train: cross-validated model selection with leakage-safe fold construction ---
## prepare_multideconv_folds() builds the deconvolution subgroups separately within
## each CV fold's training samples, avoiding leakage from the correlation-based
## feature grouping into the held-out samples (see multideconv vignette a5).
cat("\n=== Training on Gide (5x10 repeated CV, leakage-safe folds) ===\n")
t0 <- Sys.time()
res <- compute_features.training.ML(
  features_train = data.frame(deconv_gide, check.names = FALSE),
  target_var = gide_cd$Response,
  task_type = "classification",
  trait.positive = "R",
  metric = "AUROC",
  k_folds = 5,
  n_rep = 10,
  ncores = NULL,
  return = TRUE,
  file_name = "Gide_training",
  fold_construction_fun = prepare_multideconv_folds,
  fold_construction_args_fixed = list(ncores = 6),
  seed = 123
)
cat("Training elapsed:", as.numeric(difftime(Sys.time(), t0, units = "mins")), "min\n")

saveRDS(res, "results/model_Gide.rds")

cat("\nSelected model:\n")
print(res$Model$method)
cat("\nCross-validation AUROC (median, MAD) per algorithm:\n")
print(res$AUROC_median)
cat("\nCross-validation AUPRC (median, MAD) per algorithm:\n")
print(res$AUPRC_median)

write.csv(res$AUROC_median, "results/CV_AUROC_median_Gide.csv", row.names = TRUE)
write.csv(res$AUPRC_median, "results/CV_AUPRC_median_Gide.csv", row.names = TRUE)

## --- Project Riaz onto the deconvolution subgroups learned on Gide ---
cat("\n=== Projecting Riaz onto Gide-derived deconvolution subgroups ===\n")
dt_riaz <- multideconv::replicate_deconvolution_subgroups(
  deconv_res = res$Custom_output,
  deconvolution_test = deconv_riaz
)
cat("Projected Riaz feature matrix dim:", dim(dt_riaz), "\n")
cat("NAs introduced by projection:", sum(is.na(dt_riaz)), "\n")
saveRDS(dt_riaz, "results/riaz_projected_features.rds")

## --- Predict on Riaz ---
cat("\n=== Predicting on Riaz (independent test cohort) ===\n")
pred <- compute_prediction(
  model = res$Model,
  test_data = dt_riaz,
  target_var = riaz_cd$Response,
  trait.positive = "R",
  task_type = "classification",
  file.name = "Riaz_test",
  return = TRUE
)
saveRDS(pred, "results/prediction_Riaz.rds")

cat("\nTest-set (Riaz) performance:\n")
print(pred$AUC)

predictions_out <- data.frame(
  sample = rownames(dt_riaz),
  true_response = riaz_cd$Response,
  pred.R = pred$Predictions$yes,
  pred.NR = pred$Predictions$no
)
write.csv(predictions_out, "results/Riaz_predictions.csv", row.names = FALSE)
write.csv(as.data.frame(t(unlist(pred$AUC))), "results/Riaz_AUC.csv", row.names = FALSE)
write.csv(pred$Metrics, "results/Riaz_threshold_metrics.csv", row.names = FALSE)

get_curves(data = pred$Metrics,
           color = "model",
           auc_roc = pred$AUC$AUROC,
           auc_prc = pred$AUC$AUPRC,
           roc_band = pred$Curve_bands$ROC,
           prc_band = pred$Curve_bands$PRC,
           file.name = "Riaz_test")

## --- SHAP values: which features drive the predictions? ---
cat("\n=== Computing SHAP values on the final model (training samples) ===\n")
shap <- compute_shap_values(model_trained = res$Model, task_type = "classification", seed = 123)
saveRDS(shap, "results/shap_values_Gide.rds")

shap_importance <- sort(colMeans(abs(shap)), decreasing = TRUE)
write.csv(data.frame(feature = names(shap_importance),
                      mean_abs_shap = as.numeric(shap_importance)),
          "results/shap_importance_Gide.csv", row.names = FALSE)

cat("\nTop 15 features driving the prediction (mean |SHAP|):\n")
print(head(shap_importance, 15))

cat("\nDONE_TRAIN_PREDICT\n")
