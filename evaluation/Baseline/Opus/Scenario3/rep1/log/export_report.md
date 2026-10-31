All six files were exported to `results/standard/`. Nothing was recomputed and no existing file was changed; I only reformatted saved results with a new script, `scripts/03_export_standard.R`. No item was skipped.

- **`subgroups_composition.csv`**: 147 rows covering the 65 subgroups that are features of the final model. These come from the Gide-only subgrouping saved as the training output; 4 subgroups that pipeML dropped before modelling are not included.
- **`cv_performance.csv`**: 11 algorithms, with the median cross-validation AUROC in Gide.
- **`test_predictions.csv`**: 51 Riaz patients from the main random-forest model. Sample IDs are exactly as in the input file.
- **`feature_importance.csv`**: 151 features, with importance as the mean absolute SHAP value. `cell_type` is not a saved result: I took it from each feature name (the part before `_Subgroup.N`, or the last part of a raw feature name).
- **`shap_values.csv`**: 73 Gide training patients × 151 features. The patient names are the original Gide IDs, without the `X` prefix multideconv added.
- **`info.json`**: random forest (`rf`), trained on Gide and tested on Riaz, features built inside the CV folds, 5 folds × 10 repeats, AUROC, no CIBERSORTx.

Files written: `subgroups_composition.csv`, `cv_performance.csv`, `test_predictions.csv`, `feature_importance.csv`, `shap_values.csv`, `info.json`