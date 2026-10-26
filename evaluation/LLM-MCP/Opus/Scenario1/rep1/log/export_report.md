I wrote all five files to `results/standard/`. They are copies or format conversions of existing results: nothing was recomputed and no existing file was changed. Patient names match the column names of `data/Gide_log2TPM.txt` exactly (I removed the "X" prefix R had added).

- **`deconvolution_raw.csv`** (73 × 462): this is not the deconvolution output alone. I exported the matrix after `aggregate_cell_groups` (`02_aggregated_groups/result.csv`), which is what went into harmonization.
  - It contains all 375 original features from `run_deconvolution`, unchanged, plus the 87 Immune, Lymphocytes, Myeloid.cells and Stromal sums I added before harmonization.
  - I used this version because several subgroups are built from those summed features, and they need to exist in the raw file for the composition table to match. The deconvolution-only matrix is still in `results/01_deconvolution/result.csv`.
- **`deconvolution_harmonized.csv`** (73 × 222): the output of `analyze_deconvolution`.
- **`subgroups_composition.csv`**: 83 subgroups with 262 member rows.
  - No subgroup contains another subgroup.
  - Every subgroup name appears in the harmonized file, and every member feature appears in the raw file.
- **`immune_score.csv`**: the consensus immune and stromal scores I used to rank patients (mean within-cohort percentile; higher means more infiltrated).
- **`info.json`**: input scale was linear TPM; the five methods were Quantiseq, Epidish, DeconRNASeq, DWLS and CBSX; `cibersortx` is true.

Nothing requested was skipped.

Files written: `deconvolution_raw.csv`, `deconvolution_harmonized.csv`, `subgroups_composition.csv`, `immune_score.csv`, `info.json`