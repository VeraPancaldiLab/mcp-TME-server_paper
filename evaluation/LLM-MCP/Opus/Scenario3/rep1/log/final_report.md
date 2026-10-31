I trained a model on Gide's cell composition and tested it on Riaz. It did well inside Gide but only weakly on Riaz. Responders vs non-responders: AUROC 0.83 in Gide cross-validation, but 0.64 on Riaz, with a confidence interval that includes chance.

**How it was built**
- **Input scale:** both files were log2(TPM+1), so I converted them to linear TPM (2^x − 1) for deconvolution.
- **Deconvolution:** I ran multideconv separately on each cohort with all default methods, including CIBERSORTx using your credentials. That gives 375 cell-type estimates per sample.
- **Training:** pipeML trained on Gide's 73 samples with 10-fold cross-validation repeated 5 times, using default settings. The step that merges agreeing estimates into cell subgroups was redone inside each training fold, so no test-fold information leaked into the features. Random forest was the best of 11 algorithms. The final model uses 180 features.
- **Testing:** I applied Gide's subgroup definitions to Riaz. All features were present, with no missing values.

**Performance**

| | AUROC | AUPRC |
|---|---|---|
| Gide, cross-validation (median) | 0.83 | 0.91 |
| Riaz, held-out test | **0.64** (95% CI 0.46–0.82) | **0.28** (95% CI 0.17–0.60) |

- Riaz has only 10 responders out of 51 (20%), so 0.28 AUPRC is only modestly above the 0.20 you'd get by chance.
- At the best cutoff the model catches all 10 responders, but only 13 of 41 non-responders are correctly called. Of the patients it predicts as responders, 26% actually are.
- The cohorts differ in ways that likely hurt the transfer:
  - Gide is 63% responders, Riaz 20%.
  - 32 of the 73 Gide patients got anti-PD1 plus anti-CTLA4; Riaz patients got anti-PD1 alone.
  - The TPM scale differs between the two files: once converted back, Gide's samples sum to roughly 130k–660k TPM and Riaz's to about 950k.

**Features driving the prediction** (SHAP values on the Gide model, ranked by average impact)

| Rank | Feature | Higher value means |
|---|---|---|
| 1 | Monocytes (DeconRNASeq, TIL10 signature) | more likely non-responder |
| 2 | M1 macrophages, subgroup 2 (CBSX, DWLS and EpiDISH agreeing on the LM22 signature) | more likely responder |
| 3 | CD8 T cells (CBSX, TIL10 signature) | more likely responder |
| 4 | M1 macrophages, subgroup 4 (Quantiseq and DeconRNASeq, TIL10 signature) | more likely responder |
| 5 | CD8 T cells, subgroup 4 (Quantiseq, EpiDISH, DWLS and DeconRNASeq agreeing) | more likely responder |
| 6–10 | Cancer cells, resting mast cells, memory B cells | more likely non-responder |
| 6–10 | CD8 T cells (LM22 subgroup) | more likely responder |

- The overall pattern: tumours rich in CD8 T cells and M1 macrophages lean towards response. Tumours rich in monocytes, cancer cells and resting mast cells lean towards non-response.
- The top 5 features carry most of the weight, and several methods agree on the CD8 and M1 signals.
- These importances describe how the model uses features on its own training data. Given how weakly it transferred to Riaz, treat them as hypotheses rather than validated biomarkers.

**Credentials in the output folder:** your CIBERSORTx token is stored in plain text in `deconvolution_Gide/manifest.json` and `deconvolution_Riaz/manifest.json`. If you plan to share `results/`, I can remove the token from those two files. I haven't touched them yet.

Everything is in `results/`:
- `inputs/` (TPM matrices and response labels)
- `deconvolution_Gide/`
- `deconvolution_Riaz/`
- `model_training_Gide/` (the trained model plus cross-validation AUROC/AUPRC tables and plots)
- `Riaz_projected_on_Gide_subgroups/`
- `prediction_Riaz/` (predictions, metrics, ROC and precision-recall curves)
- `shap_Gide_model/` (per-sample SHAP values; `SHAP_feature_importance_ranked.csv` has the ranking with direction)
- `session_logs/` (the pipeML call log)

**Citation:** pipeML is Hurtado & Pancaldi (2026), bioRxiv, https://doi.org/10.64898/2026.03.12.711429. Also cite the mcp-tme-servers project (the reference is still a placeholder; check its README) and the random forest method.