## 1. Input data transformation

- **What I did:** the files are log2(TPM+1). I converted them back with `2^x − 1`, set any negative values to 0, and rescaled each sample to sum to 1e6 over the 18,979 shared genes.
- **Where it applied:** only to the deconvolution inputs. I passed `normalized = FALSE` so multideconv would not re-normalize the data as if it were raw counts.
- **Why:** deconvolution methods expect linear-scale expression. The rescaling was needed because the per-sample sums were far from 1e6 and differed between cohorts:
  - Gide: about 41k to 730k
  - Riaz: about 830k to 1.27M
- **What I did not do:** I did not investigate why the sums differ. The rescaling was my own choice.
- **Downstream:** the ML features are the deconvolution outputs, with no further transformation. pipeML's default preprocessing (removing near-constant and highly correlated features) was applied.

## 2. Methods

**Run:**
- multideconv `compute.deconvolution` with Quantiseq, Epidish, DeconRNASeq and DWLS, across the 7 bundled `.txt` signatures:
  - LM22
  - TIL10
  - 5 CBSX scRNA-seq signatures
- pipeML `compute_features.training.ML`, using `prepare_multideconv_folds` to build features per fold. Internally this calls `compute.deconvolution.analysis` and `replicate_deconvolution_subgroups`.
- `replicate_deconvolution_subgroups` to project the Gide-learned subgroups onto Riaz.
- `compute_prediction`, `get_curves` and `compute_shap_values`.
- My own additions: Wilcoxon R-vs-NR tests in each cohort, and a Spearman correlation between each feature and its SHAP values to get a direction.

**Skipped:**
- CIBERSORTx: it needs credentials.
- Single-cell deconvolution and signature creation: no scRNA-seq data was provided.
- `compute.benchmark`: there is no ground truth.
- `aggregate_cell_groups`: it is optional.
- LODO cross-validation: there is only one training cohort.
- Survival modelling: there is no survival data.
- Cross-cohort batch correction, and the `batch` argument (for example, Gide therapy arm): not used.
- The files in the `signatures/MCPcounter/` subfolder: the package does not load them, because it only reads `.txt` files in the top-level folder.

## 3. Non-default parameters

**`compute.deconvolution`:**
- `methods` excluded CBSX, because there were no credentials.
- `normalized = FALSE`, because the input was already TPM.
- `doParallel = TRUE, workers = 3`: 3 workers for memory reasons, after 8 workers ran out of memory.
- `return = FALSE`: I saved the outputs to `results/deconvolution/` myself instead.

**`compute_features.training.ML`:**
- `k_folds = 5` instead of 10: with only 27 non-responders in Gide, 10 folds would leave about 2–3 per test fold.
- `n_rep = 10` instead of 5: for more stable CV estimates.
- `trait.positive = "R"`.
- `fold_construction_fun = prepare_multideconv_folds`: to avoid feature-construction leakage across folds.
- `fold_construction_args_fixed = list(ncores = 3, corr = 0.7)`: `corr` is the default value, and `ncores` was set for memory.
- `return = TRUE`, `file_name = "Gide"`: to save the plots.

**Other calls:** in `compute_prediction`, I set `return = TRUE` to save the plots.

**Not tuned:** the subgrouping thresholds (`corr`, `zero_thr`, `cv_thr`).

## 4. Problems

1. **Out-of-memory kill.** The first deconvolution run was killed during parallel DWLS with 8 workers; about 10 GB of RAM was already in use outside my job. I reduced to 3 workers and reran everything.
2. **Sample-ID mismatch.** The first modelling run failed because multideconv's `data.frame()` call had added an `X` prefix to Gide sample IDs. I mapped them back using `make.names()`; all 73 matched one-to-one.
3. **Garbled names in the per-algorithm check.** The printed row names came out as "2.5%", "2.5%1" and so on, because the AUC values were named vectors. The CSV was unaffected because it is written with `row.names = FALSE`. I added `unname()` to the script *after* the run, so the script on disk differs slightly from the version that produced the outputs.
4. **DeconRNASeq diagnostic.** It printed "number of cell types in the mixtures = 1". I noticed this and did not act on it.
5. **Riaz performance.** Riaz AUROC was 0.59, against 0.80 in CV. I reported this as is and did not tune anything in response. Linear SVM scored 0.33 on Riaz, below chance.
6. **Minor redundancies:**
   - ROC and PR curves were saved twice, as `*_Riaz` and `*_Riaz_test`.
   - The process looked like it was still running after it had finished; it then exited cleanly.

## 5. Checks

**Before deconvolution:**
- Both packages are installed, and I recorded their versions.
- All 73 Gide and 51 Riaz samples are in the clinical table, with no missing responses.
- Gene lists are identical between cohorts, with no NAs and no duplicates.
- The value range (0–14) is consistent with log2(TPM+1).
- I examined the low-library sample `8_PD1_PRE`: 4.6k genes above 1 TPM, and a Spearman correlation of 0.93 with the cohort mean.

**After deconvolution:**
- Both cohorts have identical feature columns and no NAs.
- I spot-checked Quantiseq values.

**Model and outputs:**
- All 151 model features are present in Riaz, with no NAs after projection.
- I inspected the subgroup composition of the top features.
- I looked at the SHAP bar plot.
- The logs contain no errors or warnings.

**Not checked:**
- I did not look at the beeswarm, CV or ROC PDFs.
- I did not compare training performance to CV performance, which the SHAP documentation recommends.
- I did not validate the deconvolution estimates against any reference.

## 6. Limits

**Riaz validation:**
- Riaz has only 10 responders, and the AUROC CI (0.40–0.78) includes chance.
- Prevalence differs a lot between cohorts (63% responders in Gide vs 20% in Riaz), so probability thresholds do not transfer.

**CV estimate:**
- The Gide CV AUROC of 0.80 is optimistic: it was used to select the best of 11 algorithms.

**SHAP interpretation:**
- SHAP describes how a random forest uses its own training data; it does not establish biomarkers.
- The correlated features split importance between them.
- The direction (Spearman between feature and SHAP) is a crude summary.

**Univariate tests:**
- The Wilcoxon p-values are not adjusted for multiple testing.
- "16/20 same direction" only counts signs, and many of the differences are tiny.
- Some top features are not significant even in Gide: NK resting p = 0.46, mast activated p = 0.90.

**Cohort differences:**
- Gide includes ipilimumab + anti-PD1 patients; Riaz is anti-PD1 only.
- Processing and scale differ between cohorts, and I did no harmonization.
- The subgroups were learned on Gide only.
- Response definitions were taken as given from the clinical table.

**Deconvolution:**
- Only 4 methods were used (no CIBERSORTx).
- The 1e6 rescaling over a filtered gene set affects methods that work on an absolute scale.
- The low Gide totals remain unexplained.

**Not checked:**
- I did not check whether any Gide patients appear in both treatment arms, which would leak information across CV folds.