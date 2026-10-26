# Immunotherapy response prediction from TME cell composition (multideconv + pipeML)

## Design
- **Training / discovery**: Gide (melanoma, pre-treatment, anti-PD1 ± anti-CTLA4), n = 73 (46 R / 27 NR).
- **External test**: Riaz (melanoma, pre-treatment, anti-PD1), n = 51 (10 R / 41 NR).
- Positive class: responder (`R`).

## Steps
| Folder | What |
|---|---|
| `inputs/` | log2(TPM+1) → linear TPM (2^x − 1, rescaled to 1e6/sample over the 18,979 shared genes); clinical labels. Gide raw deconvolution with original sample IDs restored. |
| `01_deconvolution/{Gide,Riaz}` | multideconv: Quantiseq, EpiDISH, DeconRNASeq, DWLS, CIBERSORTx × bundled signatures → 375 raw features per cohort. |
| `02_harmonized_subgroups_Gide_fulldata` | Descriptive harmonization of the full Gide cohort (195 features). NOT used to train the model. |
| `03_model_training_Gide` | pipeML, `fold_construction_fun = prepare_multideconv_folds` (subgroups re-learned inside each training fold → leakage-free CV), 5-fold × 10 repeats, 11 algorithms, selection by AUROC. `final_model_subgroups.rds` = subgroup structure of the final model. |
| `04_external_test_Riaz` | Riaz projected onto the final model's subgroups (`replicate_subgroups`), then scored (`predict_ml_model`). ROC/PRC plots in `prediction/Results/`. |
| `05_SHAP_feature_importance` | SHAP values of the final model (73 Gide samples × 181 features retained after preprocessing). |
| `06_feature_drivers_summary` | Ranked importance, direction, R-vs-NR medians, subgroup membership, plots. |
| `07_session_logs` | Reproducibility logs (tool calls + parameters). |
| `scripts/summarize_shap.R` | Generates `06_*`. Run: `Rscript results/scripts/summarize_shap.R results`. |

## Results
**Cross-validation on Gide (leakage-free)** — best model: Random Forest (mtry = 92)
- Median AUROC 0.81 (MAD 0.09); median AUPRC 0.90 (prevalence baseline 0.63).
- Runners-up: XGBoost 0.79, bagging 0.78, C5.0 0.77, GLMNET/LASSO 0.75.

**External test on Riaz**
- AUROC 0.61 (95% bootstrap CI 0.42–0.81); AUPRC 0.26 (CI 0.16–0.58; baseline 0.20).
- The CI includes 0.5: transfer to Riaz is weak and not statistically established
  (only 10 responders; different therapy mix — Gide includes anti-PD1 + anti-CTLA4; different library prep / processing).

**Main drivers (SHAP, final model)**
| Rank | Feature | Direction | Median R vs NR (Gide) |
|---|---|---|---|
| 1 | Monocytes (DeconRNASeq/TIL10) | higher → non-response | 0.031 vs 0.127 |
| 2 | M1 macrophages, Subgroup 2 (LM22: CBSX/DWLS/EpiDISH) | higher → response | 0.040 vs 0.005 |
| 3 | CD8 T cells (CIBERSORTx/TIL10) | higher → response | 0.034 vs 0 |
| 4 | M1 macrophages, Subgroup 4 (TIL10: Quantiseq/DeconRNASeq) | higher → response | 0.200 vs 0.148 |
| 5 | CD8 T cells, Subgroup 4 (TIL10 Quantiseq/EpiDISH/DWLS + NSCLC-PBMC) | higher → response | 0.029 vs 0 |
| 6 | Memory B cells, Subgroup 1 (Zilionis) | higher → non-response | 0.018 vs 0.030 |
| 7 | Resting mast cells (LM22) | higher → non-response | 0.079 vs 0.107 |
| 9 | M2 macrophages, Subgroup 2 (LM22) | higher → non-response | 0.177 vs 0.270 |
| 10 | Cancer cells (Vanderbilt) | higher → non-response | 0.052 vs 0.073 |

Per cell type, the summed importance is dominated by monocytes, CD8 T cells and M1 macrophages, followed by M2 macrophages and B-cell subsets.
SHAP explains the final model on its own training data; interpret together with the weak external validation.
