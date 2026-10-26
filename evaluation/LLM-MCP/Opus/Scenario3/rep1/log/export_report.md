I wrote all 7 requested files to `results/standard/` by converting existing outputs only. Nothing was recomputed and no existing file was changed. A check confirmed that every `patient` column matches the sample names in the input expression files.

Where each file comes from:
- **`deconvolution_raw_Gide.csv`** (73 × 375 features): `results/inputs/Gide_deconvolution_raw.csv`. This is the deconvolution step's output with the original sample IDs restored (the step had added an "X" prefix).
- **`deconvolution_raw_Riaz.csv`** (51 × 375): `01_deconvolution/Riaz/result.csv`.
- **`subgroups_composition.csv`** (207 member rows): the final model's subgroup definitions, learned on all Gide training samples. These are not from the descriptive full-data harmonization run.
- **`cv_performance.csv`** (11 algorithms): the median cross-validation AUROC of each algorithm.
- **`test_predictions.csv`** (51 Riaz patients): the predicted probability of response.
- **`feature_importance.csv`** (181 features): mean absolute SHAP value per feature. The `cell_type` column comes from my summary script, which parsed it out of the feature names.
- **`shap_values.csv`**: SHAP values for the 73 Gide training patients (the final model was explained on its training data) × 181 features.
- **`info.json`**: Random Forest, trained on Gide, tested on Riaz, features built inside the CV folds, 5 folds × 10 repeats, AUROC, CIBERSORTx used.

I also added one new file, `results/scripts/export_standard.R`, which does this conversion.

Files written: deconvolution_raw_Gide.csv, deconvolution_raw_Riaz.csv, subgroups_composition.csv, cv_performance.csv, test_predictions.csv, feature_importance.csv, shap_values.csv, info.json