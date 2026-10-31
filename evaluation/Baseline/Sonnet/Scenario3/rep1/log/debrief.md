**1. Input data transformation**
Yes. Both `Gide_log2TPM.txt` and `Riaz_log2TPM.txt` are log2(TPM+1)-scaled. I delogged them to linear TPM (`TPM = 2^x - 1`, clipped at 0) before deconvolution, because `multideconv::compute.deconvolution()` expects linear-scale counts/TPM, not log-transformed values — deconvolution methods (quanTIseq, DWLS, etc.) assume additive/linear mixing of cell-type signatures, which log-transformed values violate.

**2. Methods run / skipped**
- Deconvolution: `multideconv::compute.deconvolution()` with methods Quantiseq, EpiDISH, DeconRNASeq, DWLS, run separately on Gide and Riaz (`normalized = FALSE` since input was already TPM, not raw counts).
- Skipped **CIBERSORTx**: requires user credentials (mail/token) that weren't provided.
- Skipped single-cell-based second-generation deconvolution (Autogenes, BayesPrism, Bisque, CPM, MuSiC, SCDC) and signature creation (MOMF, BSeq-sc): no scRNA-seq reference data was given, and the task only called for bulk TME composition.
- Training: `pipeML::compute_features.training.ML()` (classification, 11 algorithms tuned) with `fold_construction_fun = multideconv::prepare_multideconv_folds` so the correlation-based feature grouping (`compute.deconvolution.analysis`) is learned separately per CV fold, not leaked.
- Test-set projection: `multideconv::replicate_deconvolution_subgroups()` to map Riaz onto Gide's learned feature space.
- Evaluation: `pipeML::compute_prediction()`, `get_curves()`.
- Interpretability: `pipeML::compute_shap_values()`, plotted with `shapviz`.
- Skipped LODO (Leave-One-Dataset-Out) cross-validation: not requested, and the task specified a fixed train(Gide)/test(Riaz) split rather than a multi-cohort LODO scheme.

**3. Non-default parameters**
- `normalized = FALSE` in `compute.deconvolution()` (input already TPM, not raw counts — default is `TRUE`).
- `doParallel = TRUE, workers = 2` for DWLS (default `doParallel = FALSE`) — needed for runtime, but capped at 2 workers after an OOM kill at `workers = 6`.
- `methods = c("Quantiseq","Epidish","DeconRNASeq","DWLS")` instead of the function's default set (which includes CBSX) — CBSX excluded for lack of credentials.
- `k_folds = 5, n_rep = 10` in `compute_features.training.ML()` (defaults are `k_folds=10, n_rep=5`) — followed the `multideconv` vignette's own example settings for this workflow, appropriate given Gide's modest sample size (73).
- `fold_construction_fun = prepare_multideconv_folds` with `fold_construction_args_fixed = list(ncores = 6)` — this is the documented leakage-prevention mechanism for this exact use case (feature grouping must not see held-out samples), not a default behavior of `compute_features.training.ML()` (default is no custom fold function).

**4. Problems encountered**
- **Sample ID mangling**: Gide sample IDs start with digits (e.g. `10_PD1_PRE`); internally the package converts them via `data.frame()`, which R turns into `X10_PD1_PRE` (`make.names()`). I detected this by inspecting the deconvolution matrix's row names, and matched clinical metadata to it using `make.names(rna_id)` instead of raw `rna_id`.
- **Background process killed between tool calls**: an initial attempt to run the full deconvolution in the background (`nohup ... &`) resulted in the process silently becoming a zombie with no output — the sandboxed shell does not keep backgrounded jobs alive across tool invocations. I switched to running each step synchronously in the foreground with a long timeout.
- **Out-of-memory kill (exit code 137)**: the first synchronous run of Gide deconvolution with `workers = 6` for DWLS was OOM-killed (only ~4–6 GB free on a 15 GB machine). I killed the orphaned leftover worker processes to free memory, then reran with `workers = 2`, which completed successfully (~5–6 min per cohort).
- **`Results/` symlink replaced by a real directory mid-run**: I had symlinked `Results -> results` so the packages' hardcoded `Results/` output path would land in the requested `results/`. At some point during the run, something in the package's internal cleanup (likely an `unlink`/`dir.create` on old plot files) replaced the symlink with a fresh real `Results/` directory, so 4 PDFs and 2 deconvolution CSVs ended up there instead of `results/`. I caught this by listing files afterward, moved those files into `results/`, deleted a resulting self-referential broken symlink (`Results/results -> results`), and removed the now-empty stray directory. No data was lost — all files saved via explicit `results/...` paths in my own scripts were unaffected.
- **Minor reporting bug**: my own summary-generation code referenced a non-existent `target` column in caret's training data (it's actually named `.outcome`), producing an empty responder/non-responder count string in the summary. Fixed by using `.outcome` and regenerating `SUMMARY.md`.

**5. Checks performed before trusting results**
- Verified log2TPM value range (min 0, many exact zeros) to confirm the log2(TPM+1) assumption before delogging.
- Verified `rna_id` entries (after `make.names()` for Gide) exactly matched the deconvolution matrices' row names for both cohorts (`setdiff` checks returned empty), and no duplicate IDs.
- Checked for `NA`s in both deconvolution matrices (none) and in the Riaz-projected feature matrix after `replicate_deconvolution_subgroups()` (none — all training-derived subgroups had at least one matching member in Riaz).
- Ran a reduced-scale smoke test (`n_rep = 1`) of the full train→project→predict→SHAP pipeline before committing to the expensive full run (`n_rep = 10`), to catch logic errors cheaply.
- Inspected the per-algorithm CV AUROC/AUPRC table to confirm the selected model (RF) was in fact top-ranked, not an arbitrary pick.
- Confirmed sample counts and class balance per cohort (Gide 27 NR/46 R; Riaz 41 NR/10 R) against `colData_all.txt` directly.

**6. Limitations / caveats**
- SHAP values are computed on the same Gide samples used to train the final model, so they describe how the model uses features on training data, not guaranteed-generalizing effects; this is flagged explicitly in `results/SUMMARY.md`, and I noted that training-vs-CV performance should be compared before over-interpreting small SHAP effects.
- Riaz is small and imbalanced (10 responders / 41 non-responders), so its test AUROC/AUPRC confidence intervals are wide (AUROC 0.45–0.80).
- CIBERSORTx-based features are entirely absent, since no credentials were supplied — the feature space is narrower than the package's full default.
- Cross-cohort generalization (AUROC 0.63) is modest; part of the gap from cross-validation performance on Gide (0.78) is expected from unmodeled batch/technical differences between cohorts, but this wasn't formally decomposed (e.g. no explicit batch-correction step was applied between Gide and Riaz beyond the per-fold/per-cohort feature-subgroup projection).
- I did not run LODO validation across all six available cohorts (Hugo, Liu, MGH, Van_allen, in addition to Gide/Riaz) — only the Gide→Riaz split requested, so robustness across other cohorts is unverified.