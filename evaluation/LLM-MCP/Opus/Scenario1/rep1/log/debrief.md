## 1. Input data

- **Transformation:** `data/Gide_log2TPM.txt` held log2(TPM+1) values (range 0–14, non-negative, non-integer). I converted it to linear TPM with 2^x − 1 and clipped negatives to 0. The result is `results/input/Gide_TPM_linear.csv`.
- **Where it was used:**
  - As input to `run_deconvolution` (`normalized=FALSE`), because deconvolution needs linear TPM.
  - For the per-sample TPM totals used in the QC flag.
- **No renormalization:** I did not rescale samples to sum to 1e6. Each sample totals about 0.4–0.7M, presumably because the file holds only about 19k genes.
- **No log-scale step:** nothing in the analysis used the log2 values directly.
- **Sample names:** I removed the "X" prefix that R added to sample names, so they match the clinical table.

## 2. Methods

**Ran:**
- `start_workflow_session`
- `run_deconvolution` with Quantiseq, EpiDISH, DeconRNASeq, DWLS and CBSX, across all bundled signatures
- `aggregate_cell_groups`
- `analyze_deconvolution`
- `export_session_results`
- My own R script, `results/scripts/04_immune_stromal_summary.R`, which computes the consensus scores, classes, Wilcoxon and Fisher tests, and figures

**Skipped:**
- `benchmark_deconvolution`: there are no known cell fractions to compare against.
- `relate_subgroups_to_pathways`: you didn't ask for it, and it needs pathway activity.
- `replicate_subgroups`: you didn't ask for a second cohort. `Riaz_log2TPM.txt` is in `data/` but I didn't use it.
- CellTFusion: infiltration is a composition question.
- BioinfoTools `scores_stat_analysis_categorical`: I did the response and therapy tests in my own R script instead. That was a choice, not a requirement.

## 3. Non-default parameters

**`run_deconvolution`:**
- `normalized=FALSE`, because the input was linear TPM.
- CBSX credentials, read from your file.
- `workers=3`, after the first run used 19 workers and ran out of memory.
- `output_dir` and `file_name`.
- I listed the methods explicitly, but they are the same five as the default.

**`aggregate_cell_groups`:** I defined the groups myself:
- Immune included mast cells and eosinophils.
- Myeloid excluded mast cells and eosinophils.
- Lymphocytes included plasma cells.

**`analyze_deconvolution`:**
- `cells_extra = Immune, Lymphocytes, Stromal`.
- `Myeloid.cells` is already standard multideconv naming, so it was kept anyway.
- I left all other parameters at their defaults. The README says "corr 0.7, Spearman"; I did not check those defaults, so treat that as unverified.

**My own script:**
- Consensus score = mean of each patient's within-cohort percentile across that compartment's features.
- Immune classes are tertiles; the immune × stromal classes use median splits.
- QC flag for samples with a TPM total below 25% of the median.
- The Cancer score uses only `Cancer_Subgroup.2`, the melanoma reference.

All of these are my own choices, not established cutoffs.

## 4. Problems

- **Out-of-memory crash:** the first `run_deconvolution` was killed (exit −9) when DWLS started on 19 workers. The machine had 15 GB RAM with about 5 GB free. I reran with 3 workers, and it completed.
- **Cancer score:** I first used all "Cancer" features. The HNSCC and Vanderbilt tumour profiles estimate almost no tumour cells in melanoma. I restricted the score to the melanoma reference and reran. This changed the result: Cancer vs response went from p = 0.038 (higher in non-responders) to p = 0.60.
- **Stacked composition plot:** the first version mixed compartments from different references, and "Other" took up most of each bar. I redrew it from a single reference: the melanoma scRNAseq signature, median of 4 methods.
- **Low-total sample:** `8_PD1_PRE` totals about 41k TPM, against a median of about 510k. It still has a normal number of detected genes, so I kept it and flagged it.
- **Not investigated:**
  - The R script printed 16 warnings. I only saw the one about ggplot dropping the `shape` aesthetic, which is cosmetic.
  - DeconRNASeq printed "number of cell types in the mixtures = 1" from its internal PCA.
  - One sample has a Quantiseq immune fraction of 1.0, with an uncharacterized fraction of about 0.
- **Expected discards:** total-immune features from immune-only references were dropped for low variance. This is expected, because those references only estimate immune cells, so their immune totals are always close to 1.

## 5. Checks

**Before deconvolution:**
- Value range, no NAs, no negative values, not integers, no duplicate genes.
- Per-sample totals after converting back to linear TPM.
- Number of detected genes in the low-total sample.
- All 73 samples match the clinical table.

**After deconvolution:**
- Which cell types each signature estimates.
- Which features make up each subgroup.
- Spearman agreement among the immune estimates (0.40–0.75) and among the stromal estimates.
- I viewed the stacked composition plot, the scores-by-response plot and the immune vs stromal scatter.
- I did not view the ranked immune plot or the heatmap.

**Credentials:** I searched `results/` for the CIBERSORTx token. It appears in clear text only in `01_deconvolution/manifest.json`. Earlier I said it was "masked" in the session log. I only confirmed that it isn't there in clear text; I didn't check whether it is masked or simply absent.

## 6. Limits

- **No ground truth:** none of the estimates are validated against measured cell fractions.
- **Relative scores:** the scores rank patients within this cohort only and can't be compared with other cohorts.
- **Absolute fractions:** these differ a lot between references (median immune fraction 0.15 to 0.65), so `*_fraction` values are rough.
- **Moderate agreement:** some pairs of immune estimates agree only weakly (ρ ≈ 0.4).
- **Arbitrary cutoffs:** the tertile and median splits are arbitrary.
- **Exploratory tests:** the response tests are exploratory. BH correction was applied within my own set of tests. This is not a predictive model.
- **Outliers:** two non-responders (7_PD1_PRE and 6_PD1_PRE) are among the most infiltrated.
- **Flagged sample:** `8_PD1_PRE` is low-quality and should be interpreted with caution.
- **My earlier description:** my description of immune-high tumours (T cells, NK cells, macrophages) came from looking at the plot, not from a formal test.
- **Credentials:** the token is still in plain text in `01_deconvolution/manifest.json`.