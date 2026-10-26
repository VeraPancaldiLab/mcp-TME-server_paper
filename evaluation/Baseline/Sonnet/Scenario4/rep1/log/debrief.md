**1. Input data transformation**
Yes. The file is log2(TPM+1). I converted it back to linear TPM via `2^x - 1` (clamping tiny negative floating-point artifacts at 0) before calling `prepare_input_files()`, because that function's `already_normalized=TRUE` path (used for cohorts with no raw counts) expects linear-scale TPM — it compares `expr_threshold` against that scale, and skips the internal `ADImpute::NormalizeTPM()` step. No other transform was applied; deconvolution and NNLS expression-profile fitting ran on this linear TPM.

**2. Methods run / skipped**
Ran: `prepare_input_files()` (quanTIseq deconvolution, NNLS expression profiles, OmniPath/LIANA LR prior network), `compute_racing_kernel()` for D/W/TT/GSCC (raw and norm=TRUE), `compute_racing_montecarlo()` twice (independent replicates) for D/W/TT/CT/GSCC.
Skipped: CIBERSORTx, EpiDISH, DeconRNASeq, DWLS deconvolution methods (used quanTIseq only, the package default, since no CIBERSORTx credentials were available and running multiple methods wasn't requested); the `signed`/sign-matrix option (no sign matrix file provided); single-cell-based deconvolution methods (not applicable, bulk RNA-seq only).

**3. Non-default parameters**
- `deconv_method="Quantiseq"` — package default, set explicitly for clarity, not changed.
- `already_normalized=TRUE` — required because input is pre-normalized TPM, not raw counts.
- `communication_type=c("D","W","TT","GSCC")` / `c("D","W","TT","CT","GSCC")` instead of the default `"W"` — requested all motif families instead of just wedges.
- `norm=TRUE` on the kernel call — to get enrichment scores alongside raw scores.
- Monte Carlo `Ncells=2000, Ngraphs=30, Ndegree=15` instead of defaults `Ncells=10000, Ngraphs=100, Ndegree=20` — reduced for tractable runtime across 73 patients x 5 feature types (confirmed ~26 min at this setting with `ncores=10`); `expr_threshold` was left at its default (10 TPM).

**4. Problems encountered**
- `prepare_input_files()` failed with "Patient names in deconvolution estimates do not match those in the counts matrix": `multideconv`'s internal `data.frame()` conversion ran sample names through `make.names()`, prefixing names starting with a digit (e.g. `10_PD1_PRE` → `X10_PD1_PRE`). Fixed by sanitizing sample names with `make.names()` up front and keeping an original↔safe mapping (saved as `Gide_sample_name_map.csv`) to restore real patient IDs afterward.
- `generateInput()` (called internally by `prepare_input_files()`) failed with "file does not exist" because the CSVs it expects to read back require `output_folder` to end in `/` (string-pasted path, not `file.path()`), while the CSVs themselves had already been written correctly. Fixed by passing the output folder with a trailing slash; did not need to redo the (already-written) deconvolution step.
- Monte Carlo runtime was much longer than my single-patient extrapolation suggested (~26 min vs. an estimated ~11 min for the full cohort at 10 cores) — not an error, just an underestimate; I let it run to completion rather than cutting parameters further.

**5. Checks performed**
- Verified the input data's value range (0–14.04) was consistent with log2(TPM+1) before transforming.
- Checked all required R packages (RaCInG, multideconv, ADImpute, OmnipathR, liana, nnls) were installed, and that the OmniPath network was already cached locally (no live network dependency).
- Confirmed sample-name mapping was bijective and order-preserving (`stopifnot(identical(...))` in each script) before relabeling patients.
- Confirmed kernel and Monte Carlo feature column-naming conventions matched exactly (same sender/receiver/triple string format) before comparing them by name.
- Cross-checked kernel vs. Monte Carlo and Monte Carlo run1 vs. run2 via Pearson/Spearman correlation and top-15 overlap, rather than assuming agreement.
- Ran a patient bootstrap to check that top-ranked patterns weren't artifacts of a few patients.

**6. Limits / caveats**
- quanTIseq (TIL10) only resolves 10 immune cell types normalized to sum to 1 among themselves — it does not include tumor/stromal/other non-immune cells, so "abundance" here means *relative immune composition*, not whole-tumor composition; this is why Monocytes/Neutrophils dominate raw scores.
- Only one deconvolution method was used; results (especially absolute abundances and thus raw, abundance-weighted scores) could shift with a different method/signature.
- Monte Carlo was run at reduced `Ncells`/`Ngraphs` relative to the package default for runtime reasons; per-patient triangle estimates in particular carry non-trivial realization-to-realization noise (median CV ~31%) at this setting, even though cohort-level mean rankings were reproducible across two independent runs.
- Pearson correlation between kernel and Monte Carlo triangle scores is low (0.22–0.24) despite high Spearman (0.92–0.93) — the two methods are not on a directly comparable numeric scale for triangles, only in relative ranking.
- No clinical outcome (response/non-response) was incorporated — this was a descriptive, cohort-wide characterization only, not a comparison between treatment arms or outcomes, per the scope of what was asked.
- The ligand-receptor prior network and `expr_threshold=10` TPM cutoff are both method defaults I did not independently validate against this specific dataset.