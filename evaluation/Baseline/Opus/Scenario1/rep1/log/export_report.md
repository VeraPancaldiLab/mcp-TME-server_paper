All five items existed and are now exported to `results/standard/`. Nothing was recomputed and no existing file was changed. The conversion script is `scripts/03_export_standard.R`.

- **`deconvolution_raw.csv`:** copy of `deconvolution_raw_features.csv`, 73 patients × 284 features. multideconv had added an "X" prefix to the sample names (e.g. `X10_PD1_PRE`); I changed them back to the names in the input file.
- **`deconvolution_harmonized.csv`:** copy of `deconvolution_processed_features.csv`, the output of `compute.deconvolution.analysis`. Its sample names already matched the input.
- **`subgroups_composition.csv`:** the `subgroup` and `feature` columns from `deconvolution_subgroups_composition.csv`, 157 rows. No subgroup contains another subgroup. Every subgroup name appears in the harmonized matrix and every feature in the raw matrix.
- **`immune_score.csv`:** `immune_score` and `stromal_score` from `patient_immune_infiltration_ranking.csv`. Rows are in ranking order, from most to least infiltrated.
- **`info.json`:** input scale "linear TPM"; methods Quantiseq, DeconRNASeq, Epidish and DWLS; CIBERSORTx false.

Files written: `deconvolution_raw.csv`, `deconvolution_harmonized.csv`, `subgroups_composition.csv`, `immune_score.csv`, `info.json`