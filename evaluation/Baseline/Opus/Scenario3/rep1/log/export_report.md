All eight requested files are in `results/standard/`, copied from existing outputs; nothing was recomputed and no existing file was changed. No item had to be skipped. The script checked that patient names in every patient table match the input data exactly.

Some things to know when comparing:
- **Raw deconvolution:** these are the matrices from `compute.deconvolution` (284 features, all four methods and signatures). They are "raw" in the sense that no subgrouping or filtering has been applied. They are still the package's returned output: it standardises cell-type column names internally, and its inputs were my rescaled linear TPM. The Gide sample names were restored from multideconv's `X` prefix to the original names.
- **Subgroup composition:** limited to subgroups that are features of the final model, taken from the subgrouping done on all Gide samples. That is 65 subgroups and 147 member rows. Every subgroup feature of the model has its members listed.
- **CV performance:** `cv_auroc` is pipeML's median AUROC over the 50 resamples (5 folds × 10 repeats).
- **Test predictions:** the random forest's probability of response for the 51 Riaz patients.
- **Feature importance:** `importance` is the mean absolute SHAP value. `cell_type` is taken from the feature name: for subgroups, the part before `_Subgroup.N`; for single features, the part after method_signature.
- **SHAP values:** for the 73 Gide training patients only, because SHAP was not computed for Riaz.
- **info.json:** the selected algorithm is caret's `rf`, which pipeML labels `RF`.

Files written: `deconvolution_raw_Gide.csv`, `deconvolution_raw_Riaz.csv`, `subgroups_composition.csv`, `cv_performance.csv`, `test_predictions.csv`, `feature_importance.csv`, `shap_values.csv`, `info.json`.