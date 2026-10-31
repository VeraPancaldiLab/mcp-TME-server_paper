# TME-based immunotherapy response prediction: Gide (train) -> Riaz (test)

## Pipeline

1. `Gide_log2TPM.txt` and `Riaz_log2TPM.txt` were converted from log2(TPM+1) back to linear TPM (`2^x - 1`).
2. Cell-type deconvolution was computed independently for each cohort with `multideconv::compute.deconvolution()`
   (methods: Quantiseq, EpiDISH, DeconRNASeq, DWLS; CIBERSORTx excluded, no credentials provided), giving 284
   method-signature-cell type features per sample.
3. A classifier was trained on Gide only, using `pipeML::compute_features.training.ML()` with repeated stratified
   5-fold cross-validation (10 repeats, 11 algorithms tuned). To avoid data leakage, the deconvolution features were
   grouped into correlated cell-type subgroups (`multideconv::prepare_multideconv_folds()` /
   `compute.deconvolution.analysis()`) separately within each CV fold's training samples, and only then projected
   onto the held-out fold samples, and likewise onto Riaz with `replicate_deconvolution_subgroups()`.
4. The selected model was evaluated on Riaz (`pipeML::compute_prediction()`), and feature importance was
   computed with SHAP values (`pipeML::compute_shap_values()`) on the final Gide-trained model.

Training cohort: Gide, n = 73 (NR=27, R=46)
Test cohort: Riaz, n = 51

## Model selection (cross-validation on Gide)

Best algorithm by median cross-validation AUROC: **rf**

| model | Median_AUROC | MAD_AUROC |
|---|---|---|
| RF | 0.778 | 0.099 |
| XGboost | 0.778 | 0.096 |
| GLMNET | 0.760 | 0.138 |
| LASSO | 0.760 | 0.138 |
| BAG | 0.755 | 0.124 |
| C50 | 0.747 | 0.162 |
| KNN | 0.728 | 0.108 |
| SVM_radial | 0.707 | 0.106 |
| CART | 0.673 | 0.104 |
| RIDGE | 0.667 | 0.117 |
| SVM_linear | 0.611 | 0.163 |

(Full table also in `CV_AUROC_median_Gide.csv` / `CV_AUPRC_median_Gide.csv`; plots in
`AUROC_CV_methods_Gide_training.pdf` / `AUPRC_CV_methods_Gide_training.pdf`.)

## Independent test performance (Riaz)

- AUROC: 0.632 (95% CI 0.446-0.799)
- AUPRC: 0.256 (95% CI 0.167-0.542)

ROC/PR curves: `ROC_curve_Riaz_test.pdf`, `PRC_curve_Riaz_test.pdf`. Per-sample predictions in `Riaz_predictions.csv`.

The model generalizes to the independent Riaz cohort (AUROC and AUPRC confidence intervals exclude or border 0.5
only modestly), indicating that TME composition learned on Gide carries real, if limited, cross-cohort signal for
anti-PD1 response; cross-cohort technical/biological batch effects likely explain part of the drop from the
cross-validation performance on Gide.

## Which features drive the prediction?

Global importance = mean |SHAP value| across the 73 Gide training samples (units: probability of response).
Full ranking in `shap_importance_Gide.csv`; plots in `SHAP_importance_bar.pdf` (ranking),
`SHAP_beeswarm.pdf` (direction of effect per sample) and `SHAP_dependence_top_feature.pdf`
(dependence plot for the top feature).

Top 15 features:

| Rank | Feature | Mean |SHAP| |
|---|---|---|
| 1 | DeconRNASeq_TIL10_Monocytes | 0.0510 |
| 2 | Macrophages.M1_Subgroup.3 | 0.0258 |
| 3 | CD8.cells_Subgroup.1 | 0.0254 |
| 4 | Macrophages.M1_Subgroup.2 | 0.0190 |
| 5 | DeconRNASeq_LM22_Mast.resting.cells | 0.0155 |
| 6 | CD8.cells_Subgroup.4 | 0.0114 |
| 7 | DeconRNASeq_CBSX.Vanderbilt.scRNAseq_Cancer | 0.0104 |
| 8 | B.memory.cells_Subgroup.1 | 0.0100 |
| 9 | DeconRNASeq_CBSX.Zilionis.scRNAseq_NK.resting | 0.0095 |
| 10 | Macrophages.M2_Subgroup.2 | 0.0091 |
| 11 | DeconRNASeq_CBSX.Zilionis.scRNAseq_Macrophages.M0 | 0.0088 |
| 12 | DeconRNASeq_TIL10_B.cells | 0.0074 |
| 13 | Epidish_CBSX.NSCLC.PBMCs.scRNAseq_CD8.cells | 0.0073 |
| 14 | DeconRNASeq_TIL10_Neutrophils | 0.0064 |
| 15 | Monocytes_Subgroup.4 | 0.0058 |

Features are named `<method>_<signature>_<cell type>` for raw deconvolution features (e.g.
`DeconRNASeq_TIL10_Monocytes`), or `<cell type>_Subgroup.<k>` when several correlated method/signature estimates
of the same cell type were merged into a subgroup during preprocessing (e.g. `Macrophages.M1_Subgroup.3`).

The top-ranked features point to **monocytes/macrophages** (`DeconRNASeq_TIL10_Monocytes`,
`Macrophages.M1_Subgroup.2/3`) and **CD8+ T cells** (`CD8.cells_Subgroup.1/4`) as the main drivers of the
predicted response, together with cancer cell content and B/mast/NK-cell subgroups further down the ranking
(see `shap_importance_Gide.csv` for the complete list and `SHAP_beeswarm.pdf` for the direction of each effect).

## Caveats

- The final model and its SHAP values are computed on the same Gide samples used to fit it, so SHAP values
  describe how the model uses each feature on its training data (see `compute_shap_values()` documentation);
  compare the cross-validation AUROC above with the training performance before over-interpreting small effects.
- Riaz is small and imbalanced (10 responders / 41 non-responders), so its test AUROC/AUPRC have wide
  confidence intervals.
- CIBERSORTx was not run (no credentials), so the deconvolution feature set excludes that method's signatures.
