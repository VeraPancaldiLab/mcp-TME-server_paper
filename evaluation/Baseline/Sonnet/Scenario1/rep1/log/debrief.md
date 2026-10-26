**1. Input data transformation**
Yes. `Gide_log2TPM.txt` is log2(TPM+1) (confirmed via ACTB ≈ 11.6 → ~3100 TPM, a plausible housekeeping-gene value). I back-transformed with `TPM = 2^x - 1` before calling `compute.deconvolution()`, since that function expects either raw counts (`normalized=TRUE`, it TPM-normalizes internally) or already-linear-TPM input (`normalized=FALSE`). I used `normalized=FALSE` with the linear TPM matrix. Negative values after back-transform (floating-point noise near zero) were clipped to 0. No transformation was applied downstream (subgroup analysis, aggregation) — those operate on the deconvolution proportions, not expression.

**2. Methods run / skipped**
Ran `compute.deconvolution()` with Quantiseq, EpiDISH, DeconRNASeq, DWLS, across all bundled signatures (`signatures_select=NULL`, 9 signatures). Then `compute.deconvolution.analysis()` (corr=0.7, spearman) to build robust cell-type subgroups, `aggregate_cell_groups()` to sum cell types into Immune/Stromal, then `compute.deconvolution.analysis()` again with `cells_extra=c("Immune","Stromal")`.
Skipped: CIBERSORTx (CBSX) — no credentials, auto-skipped by the package with a warning. MOMF and all single-cell/second-generation methods (Autogenes, BayesPrism, Bisque, CPM, MuSiC, SCDC) — these require an `sc_matrix`/single-cell reference, which wasn't provided or requested.

**3. Non-default parameters**
- `normalized = FALSE` (default is TRUE) — because input was already TPM, not raw counts.
- `doParallel = FALSE` for the final runs (default FALSE already, but I did try `TRUE, workers=6` first — see Problems).
- `methods = c("Quantiseq","Epidish","DeconRNASeq","DWLS")` instead of the function's default set (which includes CBSX) — to skip CBSX cleanly without credential warnings cluttering output.
- `cells_extra = c("Immune","Stromal")` in the second `compute.deconvolution.analysis()` call — required, otherwise the aggregated group columns are discarded (not optional, not a tuning choice).
- All other parameters (`corr=0.7`, `corr_type="spearman"`, `zero_thr`, `cv_thr`, `min_types=2`) were left at defaults.

**4. Problems encountered**
A single `compute.deconvolution()` call with all 4 methods and `doParallel=TRUE, workers=6` crashed silently during the DWLS step: swap filled to 100%, the R process and its 6 workers became zombies, no error was written to the log, and no output/RDS was produced. I diagnosed this as an OOM kill (matches the package's own `CLAUDE.md` RAM caution for this machine, saved to memory as [[feedback_dwls_ram_limit]]). Fix: split the run — fast methods (Quantiseq/EpiDISH/DeconRNASeq) together with `doParallel=FALSE` (finished in <1 min), then DWLS alone, serially (`doParallel=FALSE`), which took ~16 min and stayed stable at ~1 GB RSS. Combined both result matrices with `cbind()` afterward (verified identical row order/names first).
Also noted: output matrix row names get an "X" prefix prepended by R's internal name-sanitization inside the package (sample IDs start with digits). I stripped the leading "X" when matching back to `colData_all.txt` sample IDs.

**5. Checks performed**
- Confirmed 73 Gide samples in `colData_all.txt` matched the 73 columns in `Gide_log2TPM.txt`, same order.
- Confirmed the log2(TPM+1) scale via a housekeeping gene before back-transforming.
- After splitting the deconvolution run, verified `identical(rownames(fast), rownames(dwls))` before `cbind()`.
- Checked that all final Immune_Subgroup.* and Stromal_Subgroup.* features were positively (not negatively) correlated with each other (spearman 0.41–0.74) before averaging their z-scores into one composite score per compartment — this confirms they consistently point the same biological direction ("more immune" / "more stromal"), making the averaging valid.
- Visually inspected all 4 generated plots (scatter, ranked bar chart, boxplot, heatmap) by rendering the PDFs to PNG before reporting completion.

**6. Limits / caveats**
- No single-cell reference was used, so only first-generation (signature-based) methods are represented; second-generation methods were not run.
- CIBERSORTx (CBSX) is entirely absent from the results (no credentials) — this removes one commonly-used method from the consensus, though 4 others and 9 signatures still contributed.
- The Immune/Stromal composite score is an unweighted mean of z-scored subgroup features; it's a relative ranking within this cohort only, not an absolute/calibrated infiltration metric, and isn't comparable across cohorts without re-running with a shared `batch` correction.
- The Response association (p=0.0027) is uncorrected for Therapy (PD1 vs CTLA4+PD1) or multiple testing beyond this single test — treat as a descriptive/exploratory signal, not a validated biomarker result.
- "Timing" in `colData_all.txt` is identical to `Sample_id` for Gide (all "_PRE"), so no pre/post-treatment comparison was possible or attempted here.