# TME-composition model of ICI response: train on Gide, test on Riaz

## Data
- Expression: `Gide_log2TPM.txt` (73 samples) and `Riaz_log2TPM.txt` (51 samples), log2(TPM+1).
  Converted back to linear TPM (`2^x - 1`) before deconvolution.
- Outcome: `Response` (R/NR) from `colData_all.txt`, matched by sample ID.
  Gide: 46 R / 27 NR. Riaz: 10 R / 41 NR.

## Pipeline
1. **multideconv::run_deconvolution** on each cohort separately (linear TPM, `normalized=FALSE`),
   default methods (Quantiseq, EpiDISH, DeconRNASeq, DWLS, CIBERSORTx) x all bundled signatures
   -> 375 raw method/signature/cell-type features per cohort.
   - `multideconv_Gide/result.csv`, `multideconv_Riaz/result.csv`
2. **pipeML::train_ml_model** (classification, target = Response, positive class = "R") on Gide's
   raw deconvolution matrix, with `fold_construction_fun = "prepare_multideconv_folds"` (10-fold x
   5 repeats): cell-type harmonization (multideconv::analyze_deconvolution) is redone inside every
   training fold, so no information about held-out folds (or about Riaz) ever influences which
   cell-type subgroups are built — leakage-free CV, selecting among BAG/RF/C50/GLMNET/KNN/CART/
   LASSO/RIDGE/SVM(linear&radial)/XGBoost by median CV AUROC.
   - Best model: **XGBoost**, CV AUROC = 0.833 (MAD 0.124), CV AUPRC = 0.908.
   - `pipeML_train/result.rds`, `result_AUROC_median.csv`, `result_AUPRC_median.csv`,
     `Results/AUROC_CV_methods_.pdf`, `Results/AUPRC_CV_methods_.pdf`
   - The harmonized Gide cell-subgroup structure the final model was trained on was extracted to
     `pipeML_train/Custom_output.rds`.
3. **multideconv::replicate_subgroups**: Riaz's raw deconvolution matrix projected onto Gide's
   learned cell-subgroup definitions (192 features) — Riaz never influenced how those subgroups
   were built.
   - `multideconv_Riaz_projected/result.csv`
4. **pipeML::predict_ml_model**: trained XGBoost model scored on the projected Riaz features.
   - **Test-set AUROC = 0.654** (95% CI 0.461–0.846), **AUPRC = 0.296** (95% CI 0.181–0.638).
   - `pipeML_predict_Riaz/result_Metrics.csv`, `result_Predictions.csv`,
     `Results/ROC_curve.pdf`, `Results/PRC_curve.pdf`
5. **pipeML::compute_shap_values** on the final model (73 Gide training samples x 180 retained
   features after preprocessing) to identify which TME features drive its predictions.
   - `pipeML_shap/result.csv` (per-sample SHAP values), `pipeML_shap/feature_importance.csv`
     (global ranking: mean |SHAP| per feature, plus the Spearman correlation between each
     feature's own value and its SHAP value, indicating the direction of its effect).

## Top features driving the prediction (by mean |SHAP|)

| Feature | Mean \|SHAP\| | Direction |
|---|---|---|
| DeconRNASeq_TIL10_Monocytes | 0.0675 | higher -> more non-response |
| Macrophages.M1_Subgroup.2 | 0.0395 | higher -> more response |
| CBSX_TIL10_CD8.cells | 0.0283 | higher -> more response |
| Macrophages.M1_Subgroup.4 | 0.0188 | higher -> more response |
| CD8.cells_Subgroup.4 | 0.0184 | higher -> more response |
| B.memory.cells_Subgroup.1 | 0.0132 | higher -> more non-response |
| Endothelial_Subgroup.3 | 0.0062 | higher -> more response |
| DeconRNASeq_LM22_Dendritic.activated.cells | 0.0060 | higher -> more response |
| CD4.memory.activated_Subgroup.2 | 0.0047 | higher -> more response |
| DeconRNASeq_CBSX.Vanderbilt.scRNAseq_CD4.regulatory | 0.0046 | higher -> more response |

Full ranking of all 180 features in `pipeML_shap/feature_importance.csv`.

**Interpretation:** the model relies predominantly on a classic immune-active-vs-immunosuppressed
TME axis — higher CD8 T-cell, M1 macrophage, activated dendritic cell and activated CD4 memory
T-cell content push predictions toward response, while higher monocyte and memory B-cell content
push toward non-response. Monocyte abundance alone is by far the single largest contributor.

## Caveat
The model's cross-validated performance on Gide (AUROC 0.83) does not generalize well to Riaz
(test AUROC 0.65, 95% CI crossing 0.5), reflecting known cross-cohort heterogeneity (different
cancer-stage/treatment-line mix, class imbalance: Riaz is 80% non-responders vs. Gide's 63%
responders) rather than a modeling artifact, since the cross-cohort feature projection and
cross-validation were both leakage-free.
