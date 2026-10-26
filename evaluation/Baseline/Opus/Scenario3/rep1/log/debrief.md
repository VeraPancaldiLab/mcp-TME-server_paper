## 1. Input data transformation
- **Deconvolution only:** I converted log2TPM to linear TPM with 2^x − 1, set any negatives to 0, and rescaled each sample to sum to 1e6. I then called `compute.deconvolution(normalized = FALSE)` so the package would not normalise again.
- **Why:** the deconvolution methods expect linear-scale data. Gide samples summed to about 0.5M and Riaz to about 0.94M, presumably because the gene list was filtered after TPM was computed.
- **Assumption I did not verify:** that the files are log2(TPM + 1).
- **Modelling:** the ML step used the deconvolution outputs (cell fractions and multideconv subgroup medians) as they came, with no extra scaling. pipeML's default preprocessing also removed near-constant features and one of each pair with |r| > 0.9.

## 2. Methods
**Ran:**
- `multideconv::compute.deconvolution` with Quantiseq (TIL10), plus EpiDISH, DeconRNASeq and DWLS on all bundled `.txt` signatures (TIL10, LM22, 5 CBSX scRNA-seq signatures).
- `pipeML::compute_features.training.ML`, with `multideconv::prepare_multideconv_folds` as the fold construction function (this calls `compute.deconvolution.analysis` per fold).
- `replicate_deconvolution_subgroups` to project Riaz onto the Gide subgroups.
- `compute_prediction`, `get_curves` and `compute_shap_values`.
- My own additions: Wilcoxon tests per feature in both cohorts with BH FDR, a binomial sign test, and shapviz plots.

**Skipped:**
- CIBERSORTx: needs credentials I don't have.
- Single-cell-based deconvolution and signature creation: no scRNA-seq data was provided.
- LODO / `batch` options: I trained on one cohort and tested on the other instead of pooling.
- The `compute_features.ML` wrapper: I called the training and prediction steps separately so I could build and save the projected Riaz features myself. The result should be equivalent.
- `aggregate_cell_groups`.
- Reverse direction (train on Riaz, test on Gide): not done.

## 3. Non-default parameters
**`compute.deconvolution`:**
- `methods` set to exclude CBSX (no credentials).
- `normalized = FALSE`, because I supplied my own TPM.
- `doParallel = TRUE, workers = 3`, because of the ~6 GB memory limit.
- `return = FALSE`, so I could save files myself under `results/`.

**`compute_features.training.ML`:**
- `k_folds = 5` (default 10): with 73 samples, 10 folds would leave test folds of about 7 samples with only ~3 non-responders, giving very noisy AUROC per fold.
- `n_rep = 10` (default 5): to offset the extra variance.
- `fold_construction_fun = prepare_multideconv_folds` and `fold_construction_args_fixed = list(ncores = 3)`: to build subgroups inside each fold without leakage, within the memory limit.
- `trait.positive = "R"`: responders as the positive class.
- `file_name` and `return = TRUE`: to save plots.

Everything else was left at defaults: multideconv `corr = 0.7` (Spearman), `seed = 123`, `metric = AUROC`, `preprocess = TRUE`.

## 4. Problems and how I handled them
- **First deconvolution run killed (OOM, exit 137)** when DWLS started 16 workers. I re-ran with 3 workers and it completed.
- **First modelling run stopped on NA labels.** multideconv had renamed Gide samples starting with a digit (`10_PD1_PRE` became `X10_PD1_PRE`).
  - I fixed both saved deconvolution CSVs with a one-off command that checked the names matched `make.names()` of the originals, then restored them.
  - I added the same fix to `01_deconvolution.R`, but **did not re-run that edited script**.
- **Nested subgroup composition list:** I spotted this when checking the output structure before the run, and flattened it in the script.
- **Unequal TPM column sums between cohorts:** handled by rescaling (see question 1).
- **One low-quality Gide sample (`8_PD1_PRE`)** found: noted it and kept it.
- **Poor test performance (AUROC 0.59):** I report it as is, without tuning on the test set.
- **Package output folder `Results/`:** renamed to `pipeML_plots/` for clarity.

## 5. Checks before trusting the results
- **Inputs:** all samples are in `colData_all.txt`; all samples are pre-treatment; gene lists are identical across cohorts; no NAs or duplicate genes.
- **Deconvolution outputs:**
  - Every method–signature combination summed to 1, with no warnings in the log.
  - Both cohorts have the same 284 columns.
  - No NAs.
- **Package behaviour:** I read the package source to confirm that subgroups are rebuilt per fold, how the final model's features are built, and what `Custom_output` contains. The modelling log contained no warnings.
- **Results:**
  - Compared Riaz performance across all 11 algorithms (for description, not selection).
  - Checked univariate associations and direction agreement in both cohorts.
  - Visually inspected the SHAP beeswarm and the ROC curve.

## 6. Limits and cautions
- **Prediction does not transfer to new patients:** the Riaz AUROC 95% CI (0.40–0.78) includes 0.5.
- **The Gide CV AUROC of 0.80 is optimistic:** it is the best of 11 algorithms on 73 samples.
- **Riaz is small:** only 10 responders, so its estimates are very imprecise.
- **The cohorts differ:** treatment (ipi + PD1 in Gide), responder rate (63% vs 20%), and possibly prior ipilimumab in Riaz. This mixes up biology with cohort differences.
- **SHAP values may reflect overfitting:**
  - They are computed on the training samples of a random forest that likely overfits.
  - I did not compare training performance with CV performance, as the pipeML docs advise.
  - They are Monte Carlo estimates.
- **Feature rankings are unstable:** many features are highly correlated and redundant (e.g. several CD8 and macrophage groups), so importance is split across them.
- **The replication evidence is weaker than it looks:**
  - The sign test (16 of 17 features) is not independent evidence, because the features are correlated.
  - Gide univariate p-values come from the training data.
  - No feature is significant in Riaz after FDR correction.
- **Deconvolution estimates were not checked against ground truth.** DeconRNASeq printed a PCA note that the mixtures look like one cell type, so its outputs deserve some caution.
- **Unverified assumptions and choices:**
  - The 2^x − 1 back-transform assumes the files are log2(TPM + 1).
  - Keeping the low-quality sample `8_PD1_PRE` may affect results.
  - The edited `01_deconvolution.R` has not been re-run end to end.