I exported all five items to `results/standard/` by converting files that already existed; nothing was recomputed or rerun, and no existing file was changed. Patients are in the same order as the input data, with the original sample names (the multideconv `X` prefix is removed). The script checked that every subgroup name exists in the harmonized matrix and every member feature exists in the raw matrix.

- **`deconvolution_raw.csv`** (73 × 284 features): copy of `results/deconvolution_all_methods_signatures.csv`, the multideconv output before subgrouping.
- **`deconvolution_harmonized.csv`** (73 × 158 features): the "Deconvolution matrix" saved in `deconvolution_subgroups.rds`. Merged features are named like `CD8.cells_Subgroup.1`; features that matched nothing at the 0.7 correlation cutoff keep their raw names.
- **`subgroups_composition.csv`**: 157 rows covering 69 subgroups, with columns `subgroup` and `feature`. There are no nested subgroups, so every member is a raw feature.
- **`immune_score.csv`** has two columns:
  - `immune_score` is the consensus immune fraction I used for the ranking: the median of the 10 whole-tissue estimates.
  - `stromal_score` is the melanoma-signature stromal fraction from the main table. It partly reflects dedifferentiated tumor cells, so treat it with caution. The fibroblast score I called the better stromal readout was not exported here; it is in `cell_type_consensus_scores_z.csv`.
- **`info.json`**: input scale `"linear TPM"`, methods Quantiseq, DeconRNASeq, Epidish and DWLS, and `cibersortx: false`.

Files written: `deconvolution_raw.csv`, `deconvolution_harmonized.csv`, `subgroups_composition.csv`, `immune_score.csv`, `info.json`