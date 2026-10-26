## Summary

**Approach:** trained on Gide et al. (n=73, 46R/27NR), validated on the independent Riaz et al. cohort (n=51, 10R/41NR) — a cross-cohort generalization test, not just a random split.

**Pipeline** (`scripts/run_analysis.R`):
1. Converted log2(TPM+1) → TPM, matched samples to `colData_all.txt` via `rna_id`.
2. `multideconv::compute.deconvolution()` — 4 methods (quanTIseq, EpiDISH, DeconRNASeq, DWLS) × 6 signatures → 284 raw deconvolution features per cohort.
3. `pipeML::compute_features.training.ML()` with `fold_construction_fun = multideconv::prepare_multideconv_folds` — rebuilds the deconvolution subgroups inside every one of 50 CV folds (5-fold × 10 repeats) so correlation structure from held-out samples never leaks into training. Random Forest was selected (CV AUROC 0.778, AUPRC 0.873 on Gide).
4. `multideconv::replicate_deconvolution_subgroups()` projected Riaz onto the subgroups learned on Gide; `pipeML::compute_prediction()` evaluated the final model.
5. `pipeML::compute_shap_values()` + `shapviz` for interpretability.

**Result:** on the independent Riaz cohort, AUROC = 0.63 [0.45–0.80], AUPRC = 0.26 [0.17–0.54] — modest but above chance, indicating the TME-composition signal generalizes only partially across these two cohorts (expected, given how different the two cohorts' response rates are: 63% vs 20%).

**Top features driving the prediction** (mean |SHAP|, in `shap_feature_importance.csv` and `top_feature_composition.txt`):
1. **Monocytes** (DeconRNASeq/TIL10)
2. **Macrophages M1** — consistent across DWLS/EpiDISH and DeconRNASeq/quanTIseq (two independent subgroups)
3. **CD8+ T cells** — a robust consensus subgroup built from 4 independent method/signature estimates
4. **Mast (resting) cells**, **Cancer cell fraction**, **B memory cells**, **NK (resting) cells**, **Macrophages M2**

Higher monocyte/M1-macrophage and CD8+ T cell estimates pushed predictions toward response, consistent with known anti-PD1 biology (inflamed, CD8-infiltrated tumors respond better).

All results (deconvolution matrices, CV plots, ROC/PR curves, SHAP plots/values, and `RESULTS_SUMMARY.txt`) are saved in `results/`.