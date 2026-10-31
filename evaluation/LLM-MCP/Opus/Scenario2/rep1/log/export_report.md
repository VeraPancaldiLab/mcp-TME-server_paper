I wrote all 11 standard files to `results/standard/`, so none were skipped. Every file was converted from existing outputs, mostly from `celltfusion/result.rds` and `response_association/Latent_factors_vs_Response_stats.csv`. Nothing was recomputed or rerun, and no existing file was changed.

The conversion script is a new file, `results/scripts/export_standard.R`. After writing, I checked that the `patient` column matches the sample names in `data/Gide_log2TPM.txt` exactly. Module and cell-group names also match between each composition file and its score file.

- **factor_scores.csv**: 73 patients × 2 states (Factor1, Factor2), the NMF factor scores that were tested against response.
- **tme_states.csv**: the 2 states with the labels I presented earlier. These labels are my interpretation, not CellTFusion output.
- **response_tests.csv**: Wilcoxon results with BH-adjusted p-values. Factor2 has p = 0.0021 (adjusted 0.0042) and is higher in R. Factor1 has p = 0.19 and is higher in NR.
- **tf_activity.csv**: 73 × 769 TFs.
- **tf_modules.csv**: 769 rows covering 12 modules.
- **tf_module_scores.csv**: 73 × 12 modules.
- **pathway_scores.csv**: 73 × 14 PROGENy pathways.
- **subgroups_composition.csv**: 208 rows, taken from "Deconvolution subgroups composition".
- **cell_groups.csv**: 800 rows covering 154 cell groups. The 32 deconvolution features that were never assigned to a group are not included.
- **cell_group_scores.csv**: 73 × 154 cell groups.
- **info.json**: 2 states, linear TPM input to deconvolution, CIBERSORTx used, Wilcoxon rank-sum test, deconvolution computed inside CellTFusion.

Files written: factor_scores.csv, tme_states.csv, response_tests.csv, tf_activity.csv, tf_modules.csv, tf_module_scores.csv, pathway_scores.csv, subgroups_composition.csv, cell_groups.csv, cell_group_scores.csv, info.json