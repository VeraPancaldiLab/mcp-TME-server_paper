I built the model and ran it end to end: it predicts response well within Gide, but **that performance doesn't hold up on Riaz.**

## Results

| | AUROC | AUPRC |
|---|---|---|
| Gide, cross-validation (random forest, the model pipeML picked) | 0.80 ± 0.10 | – |
| **Riaz, external test** | **0.59 (95% CI 0.40–0.78)** | **0.23 (0.16–0.45)**; chance is 0.20 |

- **Riaz:** responders get slightly higher predicted probabilities than non-responders (median 0.54 vs 0.48). But the confidence interval includes 0.5, so this isn't evidence that the model works on a new cohort.
- **Choice of algorithm:** as a check only, I ran the other 10 trained algorithms on Riaz too. They score between 0.33 and 0.65, so no alternative clearly does better.
- **Likely reasons:**
  - Riaz has only 10 responders out of 51 patients.
  - Gide includes both anti-PD1 and ipilimumab + anti-PD1 patients; Riaz is anti-PD1 only.
  - Deconvolution estimates differ in scale between the two cohorts (e.g. Quantiseq M2 macrophages: 0.018 in Gide vs 0.057 in Riaz).

## Features driving the prediction
These rankings come from SHAP values on the final model. Features named `_Subgroup` are multideconv merges of estimates from several methods/signatures for the same cell type.

| Rank | Feature | Higher value predicts | Same direction in Riaz? |
|---|---|---|---|
| 1 | Monocytes (DeconRNASeq/TIL10) | non-response | yes |
| 2 | CD8 T cells (Quantiseq, DWLS, Epidish/TIL10 + NSCLC) | response | yes |
| 3–4 | M1 macrophages (LM22 and TIL10 subgroups) | response | partly (1 of 2) |
| 5 | CD8 T cells (LM22 subgroup) | response | yes |
| 6 | M2 macrophages (LM22 subgroup) | non-response | no |
| 7 | Cancer cells (Vanderbilt signature) | non-response | yes, significant in Riaz (p=0.04) |

The overall picture is consistent with known biology: CD8 T cells and M1 macrophages go with response, while monocytes, M2 macrophages and tumour cells go with resistance. Most top features differ strongly between responders and non-responders in Gide (p < 0.005). In Riaz, 7 of the top 10 and 16 of the top 20 point the same way, but only two reach significance there.

The SHAP values describe the model fitted on Gide, so treat the ranking as "what the model uses", not as confirmed biomarkers.

## Main choices I made
- **Expression scale:** I converted log2(TPM+1) back to TPM and rescaled each sample to sum to 1e6. Gide's totals were well below 1e6 (as low as about 41k) because the files contain a filtered gene set.
- **Deconvolution:** I ran Quantiseq, Epidish, DeconRNASeq and DWLS with 7 signatures, giving 284 features. CIBERSORTx needs login credentials, so it wasn't run.
- **No Riaz leakage:** the cell subgroups were rebuilt inside each cross-validation fold on Gide only. The final ones were then applied unchanged to Riaz, which played no part in training or picking the model.
- **Cross-validation:** 5 folds × 10 repeats, choosing the model by AUROC, with responders as the positive class.
- **Kept a weaker sample:** Gide sample `8_PD1_PRE` has far fewer detected genes than the others, but its expression profile looks normal, so I left it in.

After the run I made a cosmetic fix to the script so the console printout of the per-algorithm check shows clean row names; the saved CSV is unaffected.

Everything is in `results/`; open `README.md` first. The code is in `scripts/01_deconvolution.R` and `scripts/02_model.R`. Key files:
- `model/test_performance_Riaz.csv`
- `model/feature_importance_SHAP.csv`
- `model/subgroup_composition_Gide.csv`
- `model/SHAP_importance_barplot.pdf`
- `model/SHAP_beeswarm.pdf`
- `Results/` (ROC/PR curves and per-algorithm cross-validation plots written by the packages)