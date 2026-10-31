I wrote all 11 files to `results/standard/`; nothing had to be skipped. They were converted from the saved CellTFusion object and the CSVs from the earlier analysis. Nothing was rerun or recomputed, and no existing file was changed. The conversion script is `scripts/03_export_standard.R`.

- **Patient names:** the per-patient tables have 73 rows each. The `patient` column was checked against the input sample names and matches them exactly.
- **What I exported as the main result:**
  - `factor_scores.csv` has the NMF state scores (TME_state1 and TME_state2), not the mixture proportions.
  - `response_tests.csv` uses the Wilcoxon test with BH correction: TME_state1 p = 0.0018 (adjusted 0.0036, higher in R); TME_state2 p = 0.12 (adjusted 0.12, higher in NR). The R/NR direction comes from the saved AUCs.
- **Name formats:** TF names keep CellTFusion's form, which replaces some characters (e.g. `NKX2.5`). Cell-group members are written exactly as CellTFusion gives them, either subgroup names or raw deconvolution feature names. `subgroups_composition.csv` covers all 42 cell types, flattened into one list.
- **`tme_states.csv` annotations:** these are my interpretation from the earlier summary, not an output of the package.
- **TF activity:** these are the raw (unscaled) scores CellTFusion returns for a single cohort.

Files written: factor_scores.csv, tme_states.csv, response_tests.csv, tf_activity.csv, tf_modules.csv, tf_module_scores.csv, pathway_scores.csv, subgroups_composition.csv, cell_groups.csv, cell_group_scores.csv, info.json