**1. Input data transformation**
Yes. `Gide_log2TPM.txt` is `log2(TPM+1)`, but RaCInG's `prepare_input_files()` needs linear-scale TPM when fed pre-normalized data. I converted with `TPM = 2^x - 1` and clamped any negative floating-point artifacts to 0, then called the function with `already_normalized = TRUE` (skipping RaCInG's internal `ADImpute::NormalizeTPM()`, which is for raw counts, not already-normalized TPM). Internally the package re-logs this back to `log2(TPM+1)` for the LR-matrix step, so no information was lost.

**2. Methods run / skipped**
Ran: `prepare_input_files()` (Quantiseq deconvolution, curated OmniPath/liana LR prior network from the local cache, NNLS expression profiles, default `fun_LR = min`) → `compute_racing_kernel()` with `communication_type = "D"` (direct communication only) → `computeLRContributions()` + `plotLRContributions()` on the single most common pair.

Skipped:
- Other deconvolution methods (CBSX, EpiDISH, DeconRNASeq, DWLS) — used Quantiseq only, for speed and because CBSX needs credentials I don't have.
- Monte Carlo method (`compute_racing_montecarlo()`) and GSCC — kernel method is deterministic and sufficient for direct communication scores; GSCC (connectivity) wasn't asked for.
- `wilcox_group_test()` / `correlate_features_with_score()` — no comparison group or continuous score was requested.
- LR-activity mode (MOON-based) — used default expression-based LR strength instead, no activity data provided.

**3. Non-default parameters**
- `deconv_method = "Quantiseq"` (default is all 5 methods) — speed/reliability, no CBSX credentials.
- `already_normalized = TRUE` (default FALSE) — required since input is pre-normalized TPM, not raw counts.
- `norm = TRUE` in `compute_racing_kernel()` (default FALSE) — requested so both raw and enrichment kernels were available; only the raw kernel was used in the final summary.
- `expr_threshold = 10` — left at default; not changed.

**4. Problems encountered**
- First run failed: `prepare_input_files()` errored with "Patient names in deconvolution estimates do not match those in the counts matrix." Root cause: `multideconv::compute.deconvolution()` internally sanitizes sample names via R's `make.names()` (e.g. `"10_PD1_PRE"` → `"X10_PD1_PRE"`), but the function then compares against the original, unsanitized `colnames(counts)`. Fix: pre-sanitized `colnames(tpm)` with `make.names(unique = TRUE)` before calling the pipeline, and saved an original↔sanitized ID mapping CSV.
- A stray `Results/` directory (capitalized, distinct from the intended `results/`) appeared containing `Deconvolution_<file_name>.csv` — `multideconv::compute.deconvolution()` writes there unconditionally, ignoring the `output_folder` argument. I moved the real-run file into `results/` and deleted the leftover debug artifact and empty directory (both cleanup steps outside `results/` required separate confirmation due to the destructive-op guard).

**5. Checks performed**
- Confirmed all 73 Gide columns match `colData_all.txt`'s `Cohort == "Gide"` rows (sample ID sanity check) before running.
- Confirmed no duplicate gene symbols in the input matrix.
- Checked the script's log for errors/warnings after both runs; only the expected `already_normalized` warning appeared.
- Verified output dimensions made sense (10 cell types, 55 non-trivial cell-type-pair features, 73 patients).
- Verified the pair-name parser against actual cell-type names (since Quantiseq cell-type names themselves contain underscores, which could break a naive string split) before trusting the sender/receiver extracted for the LR decomposition.
- Visually inspected both output plots to confirm they rendered as intended.

**6. Limits / caveats**
- "Most common pattern" is defined by my own choice (presence in each patient's top-5 raw direct-communication scores, `topK = 5`) — not a built-in RaCInG statistic; a different top-K or a mean/enrichment-based ranking could shift the ordering, especially among the mid-ranked pairs.
- Single-method (Quantiseq) deconvolution only; results may differ with other/combined deconvolution methods, which the package supports but I didn't run for speed.
- Kernel method only — no Monte Carlo uncertainty estimates (no mean/sd across simulated graphs), so there's no measure of per-patient stochastic variability in these scores.
- No clinical grouping (e.g. Response) was incorporated, so this describes the cohort's general communication landscape, not response-associated differences.
- LR decomposition was shown only for the single top pair; other high-ranking pairs weren't broken down into ligand-receptor detail.