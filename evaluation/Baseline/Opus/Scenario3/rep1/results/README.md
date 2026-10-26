# Immunotherapy response prediction from TME composition (multideconv + pipeML)

Scripts: `../scripts/01_deconvolution.R`, `../scripts/02_ml_model.R` (run from the project root).

## Design
- **Training cohort:** Gide (n = 73 pre-treatment; 46 R / 27 NR; anti-PD1 or ipi+PD1).
- **Independent test cohort:** Riaz (n = 51 pre-treatment; 10 R / 41 NR; anti-PD1). Never used for training or model selection.
- **Positive class:** responder (R).
- **Deconvolution (multideconv):** Quantiseq, EpiDISH, DeconRNASeq and DWLS with all bundled signatures
  (TIL10, LM22, 5 CBSX scRNA-seq signatures), giving 284 features. CIBERSORTx was not run because it needs credentials.
  Input: log2TPM back-transformed to linear TPM and re-scaled to 1e6 per sample on the shared genes (Gide column sums were about 0.5M, Riaz about 0.94M).
- **Feature construction:** `multideconv::prepare_multideconv_folds` was passed to pipeML as the fold construction
  function, so correlated features (Spearman > 0.7) are merged into cell subgroups *inside each CV fold*. This avoids leakage.
  The final Gide model uses 151 features. Riaz was projected onto the Gide subgroups with `replicate_deconvolution_subgroups`.
- **Modelling (pipeML):** 11 algorithms, 5-fold × 10 repeats stratified CV on Gide, model selected by median CV AUROC.
  Interpretation uses SHAP values (`compute_shap_values`) plus univariate Wilcoxon tests in both cohorts.

## Results
| | AUROC | AUPRC |
|---|---|---|
| Gide CV, selected model (Random Forest, mtry = 79) | 0.80 (MAD 0.10) | 0.88 |
| **Riaz independent test** | **0.59 (95% CI 0.40–0.78)** | 0.23 (0.16–0.45); prevalence 0.20 |

The model does **not** transfer convincingly to Riaz: the AUROC CI includes 0.5. The CV estimate is optimistic because it is
the best of 11 models evaluated on 73 samples. All other algorithms also gave Riaz AUROC 0.33–0.65
(`model/Test_performance_all_models_Riaz.csv`; descriptive only, no selection on the test set).
Predicted probabilities in Riaz cluster around 0.5 (median 0.48 NR vs 0.54 R): the response rate (63% vs 20%) and cohort composition differ.

## Features driving the prediction (SHAP, Gide model)
Associated with **response**: CD8 T cells (`CD8.cells_Subgroup.1` = Quantiseq/DWLS/EpiDISH-TIL10 + DeconRNASeq-CBSX;
`CD8.cells_Subgroup.4` = LM22), M1 macrophages (`Macrophages.M1_Subgroup.3`, `_Subgroup.2`), activated CD4 memory T cells and B cells.
Associated with **non-response**: monocytes (DeconRNASeq-TIL10, the top feature), M2 macrophages (LM22),
cancer-cell fraction, resting mast cells and M0 macrophages.

Replication in Riaz: 16 of the 17 features with Gide FDR < 0.05 change in the same direction in Riaz (sign test p = 3e-4,
but the features are correlated, so this is not independent evidence). No single feature reaches FDR < 0.05 in Riaz.
Nominal p < 0.05 in Riaz: cancer fraction, resting mast cells, Monocytes_Subgroup.4 (all higher in NR).
In short, the biology direction (CD8/M1-inflamed vs monocyte/M2/tumor-rich) is consistent across cohorts, but its effect in Riaz is weak.

## Caveats
- Gide sample `8_PD1_PRE` is low quality (4,634 genes with log2TPM > 1 vs a median of about 12,200). It was kept.
- Treatment differs (Gide includes ipi+PD1; Riaz is PD1 only, partly ipi-pretreated). Riaz has only 10 responders, so test metrics have wide CIs.
- SHAP values are computed on the training samples (pipeML default); they describe the model, not causal effects.

## Files
- `deconvolution/` – raw multideconv outputs per cohort (samples × 284 features).
- `model/` – CV performance per algorithm, selected model summary, train/test feature matrices, subgroup composition,
  Riaz predictions and threshold metrics, full pipeML result (`pipeML_training_result.rds`).
- `interpretation/` – SHAP values, `Feature_importance_SHAP.csv` (mean |SHAP|, direction, univariate AUC/p/FDR in both cohorts),
  bar/beeswarm/dependence plots, top-feature boxplots by response.
- `pipeML_plots/` – CV AUROC/AUPRC per algorithm, ROC and PR curves on Riaz.
- `logs/` – run logs and `sessionInfo.txt`.
