**1. Input transformation**
Yes. The input file is log2(TPM+1). `CellTFusion(normalized = FALSE)` expects linear, non-log-transformed TPM (it computes log2(TPM+1) internally for TF/pathway steps, and uses linear values as-is for deconvolution). I back-transformed with `TPM = 2^x - 1` (clipping tiny negative floating-point artifacts to 0) before passing the matrix in. This was done once, for the whole input matrix, before any pipeline step.

**2. Methods run / skipped**
Ran the full `CellTFusion()` wrapper: deconvolution (Quantiseq, Epidish, DeconRNASeq, DWLS), TF activity (CollecTRI, `ulm`), WTCNA TF modules, PROGENy pathway activity, cell-group construction, NMF latent factors, cell niches. Then `scores.stat.analysis()` (latent factors vs Response, vs Therapy; Wilcoxon and Fisher) and `compute.metadata.association()` (TF modules vs Response/Therapy, ANOVA).
Skipped: CIBERSORTx (no credentials provided — it's skipped automatically by the package with a message, not something I disabled); survival analysis (no time/event columns in `colData_all.txt` for Gide); `cancer_type`/ARACNE TF collection (not applicable, used default CollecTRI); the pkgdown-documented `compute_factor_gsea()`/`map_factors_to_metaprograms()`/`map_factors_to_TME()` (not present in the installed/source package version, 0.0.1 — documentation ahead of code, not something I could run).

**3. Non-default parameters**
`normalized = FALSE` (data already TPM, not raw counts), `deconv_methods` restricted to the four non-CIBERSORTx methods (no credentials available), `do_parallel = FALSE` (forced after the OOM — see below), `file_name = "Gide"`. Everything else (`corr=0.7`, `corr_mod=0.9`, `pval=0.05`, `min_module_size=5`, `seed=123`, rank selection `NULL`/auto) was left at default.

**4. Problems encountered**
- First run used `do_parallel = TRUE, workers = 8`. It stalled mid-DWLS and the process became a defunct zombie with no error printed. I checked `/sys/fs/cgroup/memory.max` (6 GiB, not the 15 GiB `free -h` reports) and `memory.events` (`oom_kill` incremented) — confirmed an OOM kill. Fixed by rerunning with `do_parallel = FALSE`; it completed using ~1.9 GiB peak. I saved this as a project memory since it's a non-obvious host constraint likely to recur.
- No other errors; the rest of the pipeline ran without warnings I had to handle (e.g., no warning was raised about the value range of `raw_counts`, meaning the TPM back-transform looked valid to the package's own sanity check).

**5. Checks before trusting results**
- Sample identity and order: confirmed `colnames(expr)` and `coldata$rna_id` for `Cohort == "Gide"` were an exact set match (73/73) and reordered coldata to match the expression matrix exactly before every statistical test, with `stopifnot(identical(...))` guards in the scripts.
- Rank selection: checked `rank_selection` and `stability` tables — rank 2 was chosen as the largest rank with all factors robust (recovery ≥0.93, mean similarity ≥0.92) and none redundant, not just the default/lowest rank.
- Cross-checked the latent-factor result (Factor1 vs Response) against an independent, module-level test (`compute.metadata.association` on TF modules): the "green" module behind Factor1 was independently significant for Response in the same direction, which corroborates rather than just repeats the factor-level test.
- Checked direction of effect (medians/means of Factor1 by Response group), not just p-values, before describing it as "higher in responders."

**6. Limits / caution**
- Single cohort (Gide, n=73, melanoma), no external validation set projected onto these factors — findings are internal to this cohort, not independently validated here.
- Rank-selection stability at neighboring ranks (3+) was poor (low recovery/redundant factors), so I'm reporting the stable rank-2 solution; a richer decomposition may exist but isn't statistically supported by this data/bootstrap procedure.
- Deconvolution ran without CIBERSORTx (no credentials), so the cell-group composition is based on four methods only, not the full default five.
- p-values for Response/Therapy associations are BH-adjusted within each test/trait separately, not across the combined set of all tests performed (latent factors × 2 traits × 2 tests, plus modules × 2 traits) — treat the combination of significant results as suggestive of a real immune-infiltration/response link, not as a single globally corrected result.
- Sample size per subgroup is modest (NR=27, R=46 pooling both therapies), limiting power especially for the Therapy-stratified comparisons, which were negative — a true but small effect of therapy on these factors can't be ruled out.