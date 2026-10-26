All 11 requested files are in `results/standard/`; none had to be skipped. Each was copied from the existing CellTFusion result or the association tables, without recomputing anything or changing existing files. Every patient table has 73 rows in the input data's sample order, with names exactly as in `Gide_log2TPM.txt`.

- **`factor_scores.csv`**: the NMF factor scores (Factor1–Factor4) that I tested against response.
- **`tme_states.csv`**: the 4 states with the labels from my report. These labels are my interpretation of the correlations, not something CellTFusion outputs.
- **`response_tests.csv`**: the main result I presented, a Wilcoxon test of responders vs non-responders across all 73 patients, adjusted across the 4 factors. `higher_in` is R when responders have higher scores. Factor2 and Factor3 are marked R but are not significant (p = 0.52 and 0.76).
- **`tf_activity.csv`**: 769 TFs.
- **`tf_modules.csv`**: 769 rows across the 11 modules.
- **`tf_module_scores.csv`**: one column per module, with names matching `tf_modules.csv`.
- **`pathway_scores.csv`**: the 14 PROGENy pathways.
- **`subgroups_composition.csv`**: 207 rows, taken from "Deconvolution subgroups composition".
- **`cell_groups.csv`**: 706 rows across the 122 cell groups.
- **`cell_group_scores.csv`**: one column per cell group.
- **`info.json`**: 4 states, linear TPM input, CIBERSORTx included, Wilcoxon test, deconvolution computed inside CellTFusion.

Files written: factor_scores.csv, tme_states.csv, response_tests.csv, tf_activity.csv, tf_modules.csv, tf_module_scores.csv, pathway_scores.csv, subgroups_composition.csv, cell_groups.csv, cell_group_scores.csv, info.json