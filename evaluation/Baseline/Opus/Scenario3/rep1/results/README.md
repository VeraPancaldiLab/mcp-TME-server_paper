# TME-based immunotherapy response prediction: train on Gide, test on Riaz

Scripts: `../scripts/01_deconvolution.R` and `../scripts/02_model.R`, both run from this directory.
Logs: `01_deconvolution.log` and `02_model.log`.

## Pipeline
1. **Deconvolution (multideconv 0.2.0)**: log2(TPM+1) was converted back to TPM and each sample rescaled
   to 1e6 over the 18,979 shared genes. Quantiseq, Epidish, DeconRNASeq and DWLS were run with the
   LM22, TIL10 and 5 CBSX scRNA-seq signatures. CIBERSORTx was not run because it needs credentials.
   This gives 284 features per sample. Each cohort was deconvolved separately.
2. **Training (pipeML 0.0.1)**: Gide, n=73 (46 R / 27 NR; PD1 and ipi+PD1). The positive class is R.
   5-fold × 10-repeat CV, tuned and selected by AUROC, across 11 algorithms.
   `prepare_multideconv_folds` rebuilds the multideconv cell subgroups (correlated method/signature
   estimates merged, Spearman r ≥ 0.7) on the training part of each fold only.
3. **Test**: The subgroups learned on all Gide samples were projected onto Riaz
   (`replicate_deconvolution_subgroups`), and the final model was applied to Riaz, n=51 (10 R / 41 NR, PD1).
   Riaz was not used for any training or model choice.
4. **Explanation**: SHAP values of the final model on the Gide training samples (`compute_shap_values`).

## Key results
| | AUROC | AUPRC |
|---|---|---|
| Gide CV (RF, median ± MAD) | 0.80 ± 0.10 | see `model/cv_AUPRC_Gide.csv` |
| **Riaz external test** | **0.59 (95% CI 0.40–0.78)** | **0.23 (0.16–0.45)**; chance = 0.20 |

On Riaz the model ranks responders a little above non-responders. The CI includes 0.5, so this is
**not significant evidence of transfer**. The other 10 algorithms give Riaz AUROCs of 0.33–0.65
(`model/sensitivity_all_models_Riaz_AUROC.csv`; this is a sensitivity check only, not used for selection).

## Files
- `deconvolution/`: raw deconvolution matrices per cohort.
- `model/pipeML_training_Gide.rds`: full pipeML output, including all models.
- `model/cv_AUROC_Gide.csv`, `model/cv_AUPRC_Gide.csv`: CV performance per algorithm.
- `model/subgroup_composition_Gide.csv`: which method/signature estimates make up each `*_Subgroup.N` feature.
- `model/features_Riaz.csv`: Riaz features in the Gide feature space.
- `model/test_performance_Riaz.csv`, `test_predictions_Riaz.csv`, `test_threshold_metrics_Riaz.csv`.
- `model/feature_importance_SHAP.csv`: mean |SHAP|, direction, and univariate R-vs-NR Wilcoxon tests in Gide and Riaz.
- `model/SHAP_importance_barplot.pdf`, `model/SHAP_beeswarm.pdf`.
- `Results/`: plots written by the packages (CV AUROC/AUPRC per algorithm, ROC/PR curves on Riaz).

## Notes
- Gide sample `8_PD1_PRE` has low library complexity (4.6k genes > 1 TPM vs a ~12k median). Its profile
  still correlates normally with the cohort (Spearman 0.93), so it was kept.
- multideconv adds an `X` prefix to sample IDs that start with a digit (Gide). `02_model.R` maps them
  back to the original IDs.
