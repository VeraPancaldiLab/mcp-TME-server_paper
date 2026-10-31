All six files are in `results/standard/`, each converted from outputs that already existed. Nothing was computed or rerun, and no existing file was changed; no item had to be skipped.

- **`subgroups_composition.csv`**: one row per subgroup member, taken from the final model's saved deconvolution analysis on the Gide training samples. It covers only the subgroups the model uses as features, and all 64 are included.
- **`cv_performance.csv`**: one row for each of the 11 algorithms compared, with its median cross-validation AUROC on Gide.
- **`test_predictions.csv`**: the predicted probability of response for each of the 51 Riaz patients. The names are exactly as in the input; I checked them against the header of `Riaz_log2TPM.txt`.
- **`feature_importance.csv`**: one row for each of the 180 features, with importance as the mean absolute SHAP value. For `cell_type`, I used the part of a subgroup name before `_Subgroup`; for a raw feature, I used the last part of its name after the final underscore.
- **`shap_values.csv`**: one row for each of the 73 Gide patients and one column per feature. The tools had added an "X" to the start of the Gide names, so I mapped them back to the original names from the header of `Gide_log2TPM.txt`; each one matched exactly one original name.
- **`info.json`**:
  - The cross-validation was 10 folds repeated 5 times, and the cell subgroups were built inside each training fold.
  - The metric is "AUROC". That is pipeML's default for choosing the algorithm, since I didn't set one.
  - `cibersortx` is true because CIBERSORTx was one of the deconvolution methods.

Files written: subgroups_composition.csv, cv_performance.csv, test_predictions.csv, feature_importance.csv, shap_values.csv, info.json