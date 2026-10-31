I wrote all five standard files to `results/standard/`. They are copies of existing results only: nothing was recomputed and no existing file was changed.

- **Patient names:** the `patient` column uses the sample names exactly as in `Gide_log2TPM.txt`. I removed the `X` prefix R had added and kept the original column order.
- **`deconvolution_raw.csv`:** the full `run_deconvolution` output, 73 patients × 375 features.
- **`deconvolution_harmonized.csv`:** the harmonized matrix from `analyze_deconvolution`, 73 × 194 features.
- **`subgroups_composition.csv`:** 69 subgroups listed as 208 subgroup–feature rows. No subgroup contains another subgroup. Every subgroup name appears in the harmonized file and every feature appears in the raw file.
- **`immune_score.csv`:** `immune_score` is the score I used for the ranking (mean of per-combination z-scores of total immune fraction). `stromal_score` is the matching stromal score.
- **`info.json`:** input scale "linear TPM", the five methods that ran (Quantiseq, Epidish, DeconRNASeq, DWLS, CBSX), and `cibersortx: true`.

Nothing requested was skipped.

Files written: deconvolution_raw.csv, deconvolution_harmonized.csv, subgroups_composition.csv, immune_score.csv, info.json