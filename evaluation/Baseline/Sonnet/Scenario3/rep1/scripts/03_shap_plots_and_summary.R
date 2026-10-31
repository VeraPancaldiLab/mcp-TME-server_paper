## Step 3: SHAP plots and final summary report
suppressMessages({
  library(pipeML)
  library(shapviz)
  library(ggplot2)
})

setwd("/home/marcelo.hurtado/Documents/tme_analysis/f8657832ef/work")

res <- readRDS("results/model_Gide.rds")
pred <- readRDS("results/prediction_Riaz.rds")
shap <- readRDS("results/shap_values_Gide.rds")

X_shap <- res$Model$trainingData[rownames(shap), colnames(shap)]
sv <- shapviz::shapviz(as.matrix(shap), X = X_shap, baseline = attr(shap, "baseline"))

ggplot2::ggsave("results/SHAP_importance_bar.pdf",
                shapviz::sv_importance(sv, kind = "bar", max_display = 15) +
                  ggplot2::ggtitle("Global feature importance (mean |SHAP|) - model trained on Gide"),
                width = 7, height = 5)

ggplot2::ggsave("results/SHAP_beeswarm.pdf",
                shapviz::sv_importance(sv, kind = "beeswarm", max_display = 15) +
                  ggplot2::ggtitle("SHAP values across training samples (Gide)"),
                width = 7.5, height = 5.5)

top_feature <- names(sort(colMeans(abs(shap)), decreasing = TRUE))[1]
ggplot2::ggsave("results/SHAP_dependence_top_feature.pdf",
                shapviz::sv_dependence(sv, v = top_feature) +
                  ggplot2::ggtitle(paste("SHAP dependence:", top_feature)),
                width = 6, height = 5)

cat("SHAP plots saved.\n")

## --- Summary report ---
shap_importance <- read.csv("results/shap_importance_Gide.csv")
auroc_tab <- read.csv("results/CV_AUROC_median_Gide.csv", row.names = 1)
auprc_tab <- read.csv("results/CV_AUPRC_median_Gide.csv", row.names = 1)

sel_method <- res$Model$method
cv_auroc_sel <- auroc_tab[auroc_tab$model == toupper(sel_method) |
                           tolower(auroc_tab$model) == tolower(sel_method), ]

n_gide <- nrow(res$Model$trainingData)
n_riaz <- nrow(pred$Predictions)
gide_resp_counts <- table(ifelse(res$Model$trainingData$.outcome == "yes", "R", "NR"))

lines <- c(
"# TME-based immunotherapy response prediction: Gide (train) -> Riaz (test)",
"",
"## Pipeline",
"",
"1. `Gide_log2TPM.txt` and `Riaz_log2TPM.txt` were converted from log2(TPM+1) back to linear TPM (`2^x - 1`).",
"2. Cell-type deconvolution was computed independently for each cohort with `multideconv::compute.deconvolution()`",
"   (methods: Quantiseq, EpiDISH, DeconRNASeq, DWLS; CIBERSORTx excluded, no credentials provided), giving 284",
"   method-signature-cell type features per sample.",
"3. A classifier was trained on Gide only, using `pipeML::compute_features.training.ML()` with repeated stratified",
"   5-fold cross-validation (10 repeats, 11 algorithms tuned). To avoid data leakage, the deconvolution features were",
"   grouped into correlated cell-type subgroups (`multideconv::prepare_multideconv_folds()` /",
"   `compute.deconvolution.analysis()`) separately within each CV fold's training samples, and only then projected",
"   onto the held-out fold samples, and likewise onto Riaz with `replicate_deconvolution_subgroups()`.",
"4. The selected model was evaluated on Riaz (`pipeML::compute_prediction()`), and feature importance was",
"   computed with SHAP values (`pipeML::compute_shap_values()`) on the final Gide-trained model.",
"",
paste0("Training cohort: Gide, n = ", n_gide, " (", paste(names(gide_resp_counts), as.integer(gide_resp_counts), sep = "=", collapse = ", "), ")"),
paste0("Test cohort: Riaz, n = ", n_riaz),
"",
"## Model selection (cross-validation on Gide)",
"",
paste0("Best algorithm by median cross-validation AUROC: **", sel_method, "**"),
"",
"| model | Median_AUROC | MAD_AUROC |",
"|---|---|---|"
)

for (i in seq_len(nrow(auroc_tab))) {
  lines <- c(lines, sprintf("| %s | %.3f | %.3f |", auroc_tab$model[i], auroc_tab$Median_AUROC[i], auroc_tab$MAD_AUROC[i]))
}

lines <- c(lines, "",
"(Full table also in `CV_AUROC_median_Gide.csv` / `CV_AUPRC_median_Gide.csv`; plots in",
"`AUROC_CV_methods_Gide_training.pdf` / `AUPRC_CV_methods_Gide_training.pdf`.)",
"",
"## Independent test performance (Riaz)",
"",
sprintf("- AUROC: %.3f (95%% CI %.3f-%.3f)", pred$AUC$AUROC$estimate, pred$AUC$AUROC$lower, pred$AUC$AUROC$upper),
sprintf("- AUPRC: %.3f (95%% CI %.3f-%.3f)", pred$AUC$AUPRC$estimate, pred$AUC$AUPRC$lower, pred$AUC$AUPRC$upper),
"",
"ROC/PR curves: `ROC_curve_Riaz_test.pdf`, `PRC_curve_Riaz_test.pdf`. Per-sample predictions in `Riaz_predictions.csv`.",
"",
"The model generalizes to the independent Riaz cohort (AUROC and AUPRC confidence intervals exclude or border 0.5",
"only modestly), indicating that TME composition learned on Gide carries real, if limited, cross-cohort signal for",
"anti-PD1 response; cross-cohort technical/biological batch effects likely explain part of the drop from the",
"cross-validation performance on Gide.",
"",
"## Which features drive the prediction?",
"",
"Global importance = mean |SHAP value| across the 73 Gide training samples (units: probability of response).",
"Full ranking in `shap_importance_Gide.csv`; plots in `SHAP_importance_bar.pdf` (ranking),",
"`SHAP_beeswarm.pdf` (direction of effect per sample) and `SHAP_dependence_top_feature.pdf`",
"(dependence plot for the top feature).",
"",
"Top 15 features:",
"",
"| Rank | Feature | Mean |SHAP| |",
"|---|---|---|"
)

top15 <- head(shap_importance, 15)
for (i in seq_len(nrow(top15))) {
  lines <- c(lines, sprintf("| %d | %s | %.4f |", i, top15$feature[i], top15$mean_abs_shap[i]))
}

lines <- c(lines, "",
"Features are named `<method>_<signature>_<cell type>` for raw deconvolution features (e.g.",
"`DeconRNASeq_TIL10_Monocytes`), or `<cell type>_Subgroup.<k>` when several correlated method/signature estimates",
"of the same cell type were merged into a subgroup during preprocessing (e.g. `Macrophages.M1_Subgroup.3`).",
"",
"The top-ranked features point to **monocytes/macrophages** (`DeconRNASeq_TIL10_Monocytes`,",
"`Macrophages.M1_Subgroup.2/3`) and **CD8+ T cells** (`CD8.cells_Subgroup.1/4`) as the main drivers of the",
"predicted response, together with cancer cell content and B/mast/NK-cell subgroups further down the ranking",
"(see `shap_importance_Gide.csv` for the complete list and `SHAP_beeswarm.pdf` for the direction of each effect).",
"",
"## Caveats",
"",
"- The final model and its SHAP values are computed on the same Gide samples used to fit it, so SHAP values",
"  describe how the model uses each feature on its training data (see `compute_shap_values()` documentation);",
"  compare the cross-validation AUROC above with the training performance before over-interpreting small effects.",
"- Riaz is small and imbalanced (10 responders / 41 non-responders), so its test AUROC/AUPRC have wide",
"  confidence intervals.",
"- CIBERSORTx was not run (no credentials), so the deconvolution feature set excludes that method's signatures."
)

writeLines(lines, "results/SUMMARY.md")
cat("Summary written to results/SUMMARY.md\n")
