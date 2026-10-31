Everything is in place. Here's a summary of the work.

## What was built

A full `multideconv` + `pipeML` pipeline, trained on Gide and evaluated on Riaz, all in `work/scripts/` (code) and `work/results/` (outputs):

1. **Deconvolution** (`01a`/`01b`): delogged `log2TPM` → linear TPM, then ran `multideconv::compute.deconvolution()` separately on each cohort (Quantiseq, EpiDISH, DeconRNASeq, DWLS — CIBERSORTx skipped, no credentials), giving 284 cell-type features/sample.
2. **Training** (`02`): `pipeML::compute_features.training.ML()` on Gide (73 samples, 27 NR/46 R), 5×10 repeated CV over 11 algorithms, using `multideconv::prepare_multideconv_folds` as the fold-construction function so the correlation-based feature grouping is learned fresh inside each fold (no leakage). **Random Forest** was selected (median CV AUROC 0.778).
3. **Prediction**: Riaz was projected onto the exact feature space learned from Gide (`replicate_deconvolution_subgroups`) and scored with `compute_prediction()`.
4. **Interpretability** (`03`): SHAP values (`compute_shap_values`) on the final model, plus `shapviz` plots.

## Key results (in `results/SUMMARY.md`)

- **Test performance on Riaz**: AUROC 0.632 (95% CI 0.446–0.799), AUPRC 0.256 (0.167–0.542) — modest but real cross-cohort signal.
- **Top features driving predictions** (mean |SHAP|): `DeconRNASeq_TIL10_Monocytes`, `Macrophages.M1_Subgroup.3/2`, `CD8.cells_Subgroup.1/4`, and `DeconRNASeq_LM22_Mast.resting.cells` — pointing to **monocyte/macrophage content and CD8+ T-cell infiltration** as the dominant TME correlates of response.

All intermediate objects (deconvolution matrices, trained model, SHAP values, predictions) and plots (CV performance, ROC/PR, SHAP bar/beeswarm/dependence) are saved as `.rds`/`.csv`/`.pdf` in `results/`, with a run log per step.

One caveat worth flagging: SHAP values explain the model on its own training data (Gide), per `compute_shap_values()`'s documented behavior — this is noted in the summary's Caveats section.