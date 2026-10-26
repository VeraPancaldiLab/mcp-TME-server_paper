All files check out: correct row counts (74/52 = header+samples, 181 = header+180 features, 125 = header+124 patients, 240 = header+239 members), correct `patient` column headers.

No test cohort was held out in this analysis (training/CV used the pooled Gide+Riaz cohort throughout), so **`test_predictions.csv` was not produced and is skipped**.

Files written to `results/standard/`: `deconvolution_raw_Gide.csv`, `deconvolution_raw_Riaz.csv`, `subgroups_composition.csv`, `cv_performance.csv`, `feature_importance.csv`, `shap_values.csv`, `info.json`.