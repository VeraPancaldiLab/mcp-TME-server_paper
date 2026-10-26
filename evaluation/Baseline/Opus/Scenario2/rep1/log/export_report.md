All 11 standard files are in `results/standard/`, and I produced every item you listed, so none were skipped. They come from the saved pipeline object and the existing statistics table, reshaped by a new script, `scripts/04_export_standard.R`. Nothing was recomputed, no method was rerun, and no existing file was changed.

- **Sample names:** the `patient` column matches the input exactly. The script checks this against the input file's column names.
- **Main result:** `factor_scores.csv` holds the three NMF factor scores that I tested against response.
- **Response tests:** `response_tests.csv` has the two-sided Wilcoxon p-values and BH-adjusted p-values (q) presented earlier. They are identical to CellTFusion's own Wilcoxon output.
- **`higher_in`:** this column comes from the existing AUC values (R if AUC > 0.5). Factor2's AUC is 0.499, so its label of NR means essentially no difference (p = 0.995).
- **TME state annotations:** these are my interpretive labels from the README, not labels assigned by CellTFusion.
- **Module scores:** the column names already match the module names in `tf_modules.csv` (e.g. `black`).
- **Cell groups:** members are the deconvolution features and subgroups exactly as CellTFusion names them.
- **`info.json`:** linear TPM input to deconvolution, no CIBERSORTx, deconvolution computed inside CellTFusion, 3 states.

Files written: factor_scores.csv, tme_states.csv, response_tests.csv, tf_activity.csv, tf_modules.csv, tf_module_scores.csv, pathway_scores.csv, subgroups_composition.csv, cell_groups.csv, cell_group_scores.csv, info.json