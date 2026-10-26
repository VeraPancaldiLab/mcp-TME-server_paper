## TME composition -> immunotherapy response prediction
## Train on Gide et al. cohort, validate on Riaz et al. cohort (independent cohorts)
## Pipeline: multideconv (cell-type deconvolution + leakage-free subgroup folds) + pipeML (ML training/prediction/SHAP)

suppressPackageStartupMessages({
  library(multideconv)
  library(pipeML)
  library(dplyr)
})

work_dir    <- "/home/marcelo.hurtado/Documents/tme_analysis/d91d50f6b3/work"
data_dir    <- file.path(work_dir, "data")
results_dir <- file.path(work_dir, "results")

setwd(results_dir)  # package functions write to "Results/" relative to the working directory

set.seed(123)

## ---------------------------------------------------------------------------
## 1. Load data
## ---------------------------------------------------------------------------

coldata <- read.table(file.path(data_dir, "colData_all.txt"), header = TRUE, sep = " ", quote = "\"")
rownames(coldata) <- coldata$rna_id

gide <- read.delim(file.path(data_dir, "Gide_log2TPM.txt"), check.names = FALSE, row.names = 1)
riaz <- read.delim(file.path(data_dir, "Riaz_log2TPM.txt"), check.names = FALSE, row.names = 1)

# Values are log2(TPM + 1); multideconv expects linear-scale (TPM) counts
gide_tpm <- 2^gide - 1
riaz_tpm <- 2^riaz - 1
gide_tpm[gide_tpm < 0] <- 0
riaz_tpm[riaz_tpm < 0] <- 0

coldata_gide <- coldata[coldata$Cohort == "Gide", ]
coldata_riaz <- coldata[coldata$Cohort == "Riaz", ]

coldata_gide <- coldata_gide[colnames(gide_tpm), ]
coldata_riaz <- coldata_riaz[colnames(riaz_tpm), ]

stopifnot(all(rownames(coldata_gide) == colnames(gide_tpm)))
stopifnot(all(rownames(coldata_riaz) == colnames(riaz_tpm)))

cat("Gide (training cohort): ", ncol(gide_tpm), " samples - Response: ", paste(names(table(coldata_gide$Response)), table(coldata_gide$Response), sep = "=", collapse = ", "), "\n")
cat("Riaz (test cohort): ", ncol(riaz_tpm), " samples - Response: ", paste(names(table(coldata_riaz$Response)), table(coldata_riaz$Response), sep = "=", collapse = ", "), "\n")

## ---------------------------------------------------------------------------
## 2. Cell type deconvolution (first-generation methods, multideconv)
## ---------------------------------------------------------------------------

deconv_methods <- c("Quantiseq", "Epidish", "DeconRNASeq", "DWLS")

deconv_train <- multideconv::compute.deconvolution(
  raw.counts  = gide_tpm,
  methods     = deconv_methods,
  normalized  = FALSE,   # input is already TPM-normalized (not raw counts)
  doParallel  = TRUE,
  workers     = 4,
  return      = TRUE,
  file_name   = "Gide"
)

deconv_test <- multideconv::compute.deconvolution(
  raw.counts  = riaz_tpm,
  methods     = deconv_methods,
  normalized  = FALSE,
  doParallel  = TRUE,
  workers     = 4,
  return      = TRUE,
  file_name   = "Riaz"
)

# compute.deconvolution() sanitizes sample names via data.frame() (e.g. digit-leading
# Gide IDs like "10_PD1_PRE" become "X10_PD1_PRE"); match clinical data on make.names()
rownames(coldata_gide) <- make.names(rownames(coldata_gide))
rownames(coldata_riaz) <- make.names(rownames(coldata_riaz))

# Keep clinical data in the same sample order as the deconvolution tables
traitData_train <- coldata_gide[rownames(deconv_train), , drop = FALSE]
traitData_test  <- coldata_riaz[rownames(deconv_test), , drop = FALSE]

stopifnot(all(rownames(traitData_train) == rownames(deconv_train)), !anyNA(traitData_train$Response))
stopifnot(all(rownames(traitData_test) == rownames(deconv_test)), !anyNA(traitData_test$Response))

saveRDS(list(deconv_train = deconv_train, deconv_test = deconv_test,
             traitData_train = traitData_train, traitData_test = traitData_test),
        file.path(results_dir, "deconvolution_tables.rds"))

## ---------------------------------------------------------------------------
## 3. Train classification model with leakage-free cross-validation
##    (deconvolution subgroups rebuilt inside every CV fold, via multideconv::prepare_multideconv_folds)
## ---------------------------------------------------------------------------

res <- pipeML::compute_features.training.ML(
  features_train = deconv_train,
  target_var      = traitData_train$Response,
  task_type        = "classification",
  trait.positive   = "R",
  metric           = "AUROC",
  k_folds          = 5,
  n_rep            = 10,
  ncores           = NULL,
  return           = TRUE,
  file_name        = "Gide_training",
  fold_construction_fun       = multideconv::prepare_multideconv_folds,
  fold_construction_args_fixed = list(ncores = 4)
)

saveRDS(res, file.path(results_dir, "training_result.rds"))

cat("\n==== Cross-validation performance (Gide, training cohort) ====\n")
print(res$AUROC_median)
print(res$AUPRC_median)
cat("\nSelected model: ", res$Model$method, "\n")

## ---------------------------------------------------------------------------
## 4. Predict on the independent Riaz cohort
## ---------------------------------------------------------------------------

# Project Riaz samples onto the deconvolution subgroups learned on Gide only
dt_test <- multideconv::replicate_deconvolution_subgroups(
  deconv_res         = res$Custom_output,
  deconvolution_test = deconv_test
)

pred <- pipeML::compute_prediction(
  model       = res$Model,
  test_data   = dt_test,
  target_var  = traitData_test$Response,
  task_type   = "classification",
  trait.positive = "R",
  file.name   = "Gide_to_Riaz",
  return      = TRUE
)

saveRDS(pred, file.path(results_dir, "test_prediction.rds"))

cat("\n==== Performance on the independent Riaz cohort ====\n")
print(pred$AUC)

## ---------------------------------------------------------------------------
## 5. SHAP values: which TME subgroups drive the prediction?
## ---------------------------------------------------------------------------

shap <- pipeML::compute_shap_values(
  model_trained = res$Model,
  task_type     = "classification",
  seed          = 123
)

saveRDS(shap, file.path(results_dir, "shap_values.rds"))

importance <- sort(colMeans(abs(shap)), decreasing = TRUE)
importance_df <- data.frame(Feature = names(importance), Mean_abs_SHAP = unname(importance))
write.csv(importance_df, file.path(results_dir, "shap_feature_importance.csv"), row.names = FALSE)

cat("\n==== Top features driving the prediction (mean |SHAP|) ====\n")
print(head(importance_df, 15))

# Composition of the top subgroups (which method-signature-cell type estimates were merged)
subgroup_composition <- res$Custom_output[["Deconvolution subgroups composition"]]
top_features <- head(importance_df$Feature, 10)
composition_txt <- file.path(results_dir, "top_feature_composition.txt")
sink(composition_txt)
for (feat in top_features) {
  cell_type <- NULL
  for (ct in names(subgroup_composition)) {
    if (feat %in% names(subgroup_composition[[ct]])) {
      cell_type <- ct
      break
    }
  }
  cat("Feature: ", feat, "\n", sep = "")
  if (!is.null(cell_type)) {
    cat("  Cell type: ", cell_type, "\n", sep = "")
    cat("  Composed of (method_signature estimates merged into this subgroup):\n")
    cat("   - ", paste(subgroup_composition[[cell_type]][[feat]], collapse = "\n   - "), "\n\n", sep = "")
  } else {
    cat("  (single feature, not part of a merged subgroup)\n\n")
  }
}
sink()

## ---------------------------------------------------------------------------
## 6. SHAP plots
## ---------------------------------------------------------------------------

suppressPackageStartupMessages(library(shapviz))

X_shap <- res$Model$trainingData[rownames(shap), colnames(shap)]
sv <- shapviz::shapviz(as.matrix(shap), X = X_shap, baseline = attr(shap, "baseline"))

pdf(file.path(results_dir, "SHAP_importance_bar.pdf"), width = 7, height = 6)
print(shapviz::sv_importance(sv, kind = "bar") + ggplot2::ggtitle("Global feature importance (mean |SHAP|)"))
dev.off()

pdf(file.path(results_dir, "SHAP_beeswarm.pdf"), width = 7, height = 6)
print(shapviz::sv_importance(sv, kind = "beeswarm") + ggplot2::ggtitle("SHAP values across training samples"))
dev.off()

top_feature <- importance_df$Feature[1]
pdf(file.path(results_dir, "SHAP_dependence_top_feature.pdf"), width = 6, height = 5)
print(shapviz::sv_dependence(sv, v = top_feature))
dev.off()

## ---------------------------------------------------------------------------
## 7. Written summary
## ---------------------------------------------------------------------------

summary_txt <- file.path(results_dir, "RESULTS_SUMMARY.txt")
sink(summary_txt)
cat("TME composition -> immunotherapy response prediction\n")
cat("======================================================\n\n")
cat("Training cohort: Gide et al. (n = ", ncol(gide_tpm), "; R = ", sum(traitData_train$Response == "R"),
    ", NR = ", sum(traitData_train$Response == "NR"), ")\n", sep = "")
cat("Test cohort:     Riaz et al. (n = ", ncol(riaz_tpm), "; R = ", sum(traitData_test$Response == "R"),
    ", NR = ", sum(traitData_test$Response == "NR"), ")\n\n", sep = "")

cat("Deconvolution methods: ", paste(deconv_methods, collapse = ", "), "\n")
cat("Number of raw deconvolution features (Gide): ", ncol(deconv_train), "\n")
cat("Number of deconvolution subgroup features used by the final model: ", ncol(res$Model$trainingData) - 1, "\n\n")

cat("Selected ML algorithm: ", res$Model$method, "\n")
cat("Best hyperparameters:\n")
print(res$Model$bestTune)

cat("\nCross-validation performance on Gide (median [MAD] across resamples):\n")
print(res$AUROC_median)
print(res$AUPRC_median)

cat("\nIndependent validation on Riaz:\n")
cat("  AUROC = ", round(pred$AUC$AUROC$estimate, 3),
    " [", round(pred$AUC$AUROC$lower, 3), "-", round(pred$AUC$AUROC$upper, 3), "]\n", sep = "")
cat("  AUPRC = ", round(pred$AUC$AUPRC$estimate, 3),
    " [", round(pred$AUC$AUPRC$lower, 3), "-", round(pred$AUC$AUPRC$upper, 3), "]\n", sep = "")

cat("\nTop features driving the prediction (mean |SHAP| on the training data):\n")
print(head(importance_df, 15))
sink()

cat("\n\nDone. Results saved in: ", results_dir, "\n")
