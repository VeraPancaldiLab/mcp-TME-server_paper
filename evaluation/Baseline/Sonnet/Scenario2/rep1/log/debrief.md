**1. Input data transformation**
Yes. `Gide_log2TPM.txt` contains log2(TPM+1) values (range 0–14.04). `CellTFusion()` with `normalized = FALSE` requires un-logged TPM, so I converted with `tpm = 2^x - 1` (clipping any negative rounding artifacts to 0) before passing it in. No other transformation was applied — deconvolution, TF-activity, and pathway steps compute their own internal normalizations.

**2. Methods run / skipped**
Ran the full `CellTFusion()` wrapper: deconvolution (`multideconv::compute.deconvolution()` with Quantiseq, Epidish, DeconRNASeq), TF activity (`compute.TFs.activity()`, CollecTRI), TF co-activity modules (`compute.WTCNA()`), pathway activity (PROGENy), cell-group construction (`construct_cell_groups()`), NMF latent factors (`compute.latent_factors()`), cell niches (`compute_cells_niches()`), and clinical association (`scores.stat.analysis()` for latent factors vs. Response, `compute.metadata.association()` for TF modules vs. Response/Therapy).

Skipped:
- **CBSX (CIBERSORTx)** — needs user credentials, none provided; auto-skipped by the package.
- **DWLS** — attempted with `do_parallel = TRUE`, but it OOM-crashed the main R process twice (workers ~1GB each, machine has 15GB RAM/2GB swap, already near capacity). Dropped it entirely rather than risk a third crash.
- **MOMF** — not in `CellTFusion()`'s own default `deconv_methods` list, so never attempted.
- **`cancer_type` / meta-program / TME-subtype mapping** — the installed package version (0.0.1) doesn't export `compute_factor_gsea()`/`map_factors_to_metaprograms()`/`map_factors_to_TME()` despite the GitHub vignette describing them; confirmed via `getNamespaceExports()`. So I didn't get a subtype label (e.g. "IE"/"F") — I annotated factors manually from `Cells_niches` composition instead.
- **Survival analysis (`compute.survival.analysis()`)** — skipped, no survival/time-to-event columns exist in `colData_all.txt` (only `Response`, `Therapy`, `Timing`).

**3. Non-default parameters**
- `normalized = FALSE` (data was already TPM after my conversion, not raw counts).
- `deconv_methods = c("Quantiseq","Epidish","DeconRNASeq")` instead of the function default (which also includes CBSX, DWLS).
- `do_parallel = FALSE` (default) after the parallel DWLS crash — not actually a deviation since DWLS was removed, but I explicitly disabled parallelism.
- `seed = 123` — left at default, not changed.
- `padj = TRUE` in `scores.stat.analysis()` (default `FALSE`) — chose BH correction since 4 factors were tested against Response, to control multiple-testing inflation.
- Everything else (NMF rank search 2:15, `corr_mod = 0.9`, `min_module_size = 5`, `pval = 0.05`, `top_n = 5`, etc.) was left at package defaults.

**4. Problems encountered**
- Two full pipeline crashes during the DWLS-parallel deconvolution step: the main R process died (became a zombie/disappeared) while orphaned worker processes lingered, consuming memory until killed. `free -h` showed swap fully exhausted at the time. No `dmesg`/OOM log access to confirm the exact kill mechanism, but memory pressure during 8-way parallel DWLS is the clear proximate cause. Handled by removing DWLS and parallelism rather than retrying with fewer workers, to avoid a third failed run.
- Separately, the first two background-launch attempts (`nohup ... &`) were killed as soon as the Bash tool call returned, before DWLS was even reached. Handled by relaunching with `setsid nohup ... < /dev/null & disown` to fully detach the process into its own session.
- `scores.stat.analysis()` in the installed version has no `file_name` argument (unlike the vignette example) — caught before running by checking `args()`/help on the installed function, and removed that argument from my call.

**5. Checks performed before trusting results**
- Verified log2TPM value range (0–14.04, no negatives) matched the log2(TPM+1) assumption before converting.
- Verified all 73 Gide `Sample_id`s matched the expression matrix's column names exactly (`setdiff` empty) and that row/column ordering was aligned before passing data to `CellTFusion()`.
- Checked installed package version and exported function list (`packageVersion`, `getNamespaceExports`) against the newer GitHub docs before relying on vignette-described behavior, since they diverged.
- Confirmed the pipeline log showed "Everything done!" with no trailing errors, and that expected output files (TF matrix, cell groups, NMF stability plot, niche composition) were all written.
- Cross-checked the Factor1–Response association at a second, independent level (TF module ANOVA on "green"/"greenyellow" modules) rather than relying on the latent-factor test alone.
- Confirmed the direction of the effect (median Factor1 score 0 in NR vs. 0.0064 in R), not just the p-value, before describing it as "higher in responders."

**6. Limits / caveats**
- Only 3 of the 5 commonly-used first-generation deconvolution methods were used (no CBSX, no DWLS); results could shift somewhat with a fuller deconvolution ensemble.
- "Immune-enriched" is my descriptive label from inspecting Factor1's cell-niche composition, not a package-assigned, validated TME-subtype annotation (that functionality isn't available in the installed version) — treat it as an interpretation, not a formal classification.
- n=73 with 27 NR / 46 R is a modest sample size for a single factor's Wilcoxon test; the finding is statistically significant after BH correction but not independently validated on a held-out cohort (e.g. Riaz) in this run.
- NMF rank selection (4) and WTCNA module detection used default thresholds (`corr_mod = 0.9`, bootstrap `n_boot = 100`, etc.) — not tuned or sensitivity-tested for this specific dataset.
- No survival/PFS data was available, so I cannot say whether this TME state also relates to longer-term outcome, only to the binary R/NR label as recorded in `colData_all.txt`.