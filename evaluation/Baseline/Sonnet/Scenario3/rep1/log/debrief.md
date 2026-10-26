**1. Input data transformation**
Both `Gide_log2TPM.txt` and `Riaz_log2TPM.txt` were log2(TPM+1). I converted them back to linear TPM (`2^x - 1`, clipped at 0) before deconvolution, since `multideconv::compute.deconvolution()` expects linear-scale TPM/counts, not log-transformed values. I then called it with `normalized = FALSE` (meaning "already-normalized/TPM" input — the flag's naming is counterintuitive: `TRUE` means "raw counts, please TPM-normalize internally"). No other transformation was applied — deconvolution subgroup features, SHAP, and model inputs all operate on the (correctly-scaled) deconvolution output, not on raw expression.

**2. Methods run / skipped**
Ran: `compute.deconvolution()` with quanTIseq, EpiDISH, DeconRNASeq, DWLS (×6 signatures) on Gide and Riaz separately; `pipeML::compute_features.training.ML()` with `fold_construction_fun = multideconv::prepare_multideconv_folds` (11 classification algorithms tuned, RF selected); `replicate_deconvolution_subgroups()` to project Riaz onto Gide-learned subgroups; `compute_prediction()`; `compute_shap_values()` + `shapviz`.

Skipped: **CIBERSORTx (CBSX)** — requires credentials I wasn't given, so I excluded it from `methods`. **MOMF** and all second-generation (single-cell-based) deconvolution methods (AutoGeneS, BayesPrism, Bisque, CPM, MuSiC, SCDC) — these require an scRNA-seq reference, which wasn't provided in `data/`. **Batch correction** (`batch=` argument in `compute.deconvolution.analysis`) — not applicable since I deconvolved and trained/tested on separate cohorts rather than a pooled matrix.

**3. Non-default parameters**
- `normalized = FALSE` in `compute.deconvolution()` (default `TRUE`) — required given linear-TPM input, as above.
- `methods = c("Quantiseq","Epidish","DeconRNASeq","DWLS")` instead of default (which includes `CBSX`) — no credentials available.
- `doParallel = TRUE, workers = 4` — default is sequential; parallelized DWLS for speed given 20 cores available (kept conservative given ~4.6GB free RAM observed).
- `n_rep = 10` (vignette-suggested value) instead of the package default of `5` — more repeats for stabler CV estimates given a small training cohort (n=73).
- `k_folds = 5` is actually the pipeML default's companion value used in the tutorial (package default is `10`); I used 5 because with only 27 NR samples in Gide, 10-fold CV would leave very few NR samples per test fold.
- `fold_construction_args_fixed = list(ncores = 4)` — controls the internal parallel pool for `prepare_multideconv_folds`'s 50 folds; kept modest for the same memory-headroom reason.
- Everything else (`corr=0.7`, `zero_thr`, `cv_thr`, `metric="AUROC"`, `seed=123`, `preprocess=TRUE`) was left at package defaults.

**4. Problems encountered**
- **Sample-ID mismatch**: `compute.deconvolution()` calls `data.frame()` internally, which sanitizes column names via R's `make.names()` — Gide's digit-leading sample IDs (e.g. `10_PD1_PRE`) got silently prefixed to `X10_PD1_PRE` in the deconvolution output, while `colData_all.txt`'s `rna_id` stayed unprefixed. I caught this by inspecting a small test run's output rownames before the full run, and fixed it by applying `make.names()` to the clinical-data rownames before matching them to the deconvolution output, with `stopifnot()` checks confirming exact alignment and no `NA` responses afterward.
- **Runtime**: no outright errors, but DWLS deconvolution was the clear bottleneck (~74s for 5 samples × 4 methods in a timed test). I used this to estimate total runtime (~30 min for both cohorts) before committing to the full background run, rather than running blind.
- No other crashes, warnings-as-errors, or silent empty outputs were encountered; the `pca(... more components than matrix columns requested)` warnings from DeconRNASeq's internal PCA step are a routine informational warning from that package for samples with few informative genes, not a pipeline fault.

**5. Checks performed before trusting results**
- Verified `rna_id` in `colData_all.txt` matched expression-matrix column names 1:1 for both cohorts (73/73 Gide, 51/51 Riaz) before running anything.
- Verified no duplicated gene symbols in either expression file.
- Checked the value range of the input matrices (max ~13, consistent with log2(TPM+1), confirming the back-transformation was necessary and correctly scaled).
- Re-confirmed sample alignment after deconvolution via `stopifnot(rownames(traitData) == rownames(deconv))` and `!anyNA(Response)`.
- Inspected the CV leaderboard (`AUROC_median`/`AUPRC_median` across all 11 algorithms) rather than trusting only the top model, to see that RF/XGBoost were close and clearly ahead of weaker learners (sanity check that selection wasn't a fluke of one algorithm).
- Rendered and visually inspected the SHAP bar plot PDF to confirm it was generated correctly, not just that the file existed.
- Looked up the composition of the top SHAP features (`top_feature_composition.txt`) to confirm they correspond to biologically coherent, often multi-method consensus cell-type estimates (e.g. CD8 T cells agreed on by 4 independent method/signature combinations) rather than single noisy features.

**6. Limits / caveats**
- **Test-set performance is modest and imprecise**: AUROC 0.63 [0.45–0.80] on Riaz — the confidence interval crosses 0.5, so I can't claim reliable discrimination on this specific external cohort with n=51.
- **Severe class imbalance in the test cohort** (10 R vs 41 NR) inflates AUPRC interpretation difficulty and widens bootstrap CIs.
- **SHAP values describe the training (Gide) model's internal behavior**, not necessarily what generalizes to Riaz — I flagged in the script's logic (per package docs) that these should be read as "how the model uses features on training data," and the gap between CV AUROC (0.78) and external AUROC (0.63) suggests some overfitting to Gide-specific structure.
- **No CIBERSORTx or single-cell-based (2nd-generation) deconvolution** was included, so the TME feature space is limited to first-generation, signature-based methods only — results could differ with those added.
- **Only two cohorts available**; this is a single train/test split, not a multi-cohort LODO validation, so "generalization" here reflects one specific cohort pair, not a general property of the model.
- I did not attempt any biological-pathway interpretation or literature cross-validation of the top features beyond noting they're directionally consistent with known anti-PD1 immunobiology — this is a plausibility check, not independent confirmation.