**1. Input data transformation**
Yes. `Gide_log2TPM.txt` is log2(TPM+1). I reversed it to linear TPM via `2^x - 1` (floored at 0) before deconvolution, because `multideconv`'s methods expect raw counts or linear TPM, not log-transformed values. This was done once, upstream of all deconvolution methods.

**2. Methods run / skipped**
Ran `compute.deconvolution()` with methods `Quantiseq`, `Epidish`, `DeconRNASeq`, `DWLS`, across all bundled signatures (TIL10, LM22, 5× CBSX scRNA-seq refs), then `compute.deconvolution.analysis()` for correlation-based subgrouping.
Skipped: `CBSX` (needs CIBERSORTx credentials + Docker, neither available), `MOMF` and all second-generation methods (`Autogenes`, `BayesPrism`, `Bisque`, `CPM`, `MuSic`, `SCDC`) — these require a single-cell reference matrix, which was not provided or requested.

**3. Non-default parameters**
- `normalized = FALSE` (default `TRUE`) — because the input was already TPM-normalized (after my log-reversal), not raw counts.
- `doParallel = TRUE`, `workers = 4` (default `FALSE`/`NULL`) — to speed up DWLS, chosen conservatively given the machine's limited free RAM rather than using all cores.
- `corr = 0.7`, `corr_type = "spearman"` in `compute.deconvolution.analysis()` — these are actually the function defaults, not changed.
- `zero_thr`, `cv_thr`, `batch` left at defaults.

**4. Problems encountered and handling**
- First run: `compute.deconvolution()` internally builds a `data.frame()` with `check.names = TRUE` on the TPM matrix, which prepended `"X"` to all sample IDs (they start with digits, e.g. `10_PD1_PRE` → `X10_PD1_PRE`). This broke the later merge with clinical data (produced an empty/near-empty scores table, which only surfaced downstream as a Wilcoxon-test error). Fixed by rebuilding a name map (`make.names(colnames(tpm))` → original) and restoring original sample IDs on `deconv` right after the call.
- Second run: my cell-type-extraction regex assumed all output columns followed `<CellType>_Subgroup.<i>`, but ungrouped (singleton) features keep their raw `method_signature_celltype` name instead. This misclassified many columns as "Unassigned" cell types. Fixed by adding a second parsing branch: strip the `_Subgroup.N` suffix when present, otherwise take the last `_`-delimited token as the cell type.
- Minor: `pheatmap` errored because an annotation factor level ("Unassigned") had no matching color; fixed by adding a fallback color and also classifying `uncharacterized_cell` under "Other".
- Each fix required a full rerun of the pipeline (~8–9 min each), since no intermediate objects were cached outside the package's own per-method cache (which is deleted on success).

**5. Checks performed before trusting results**
- Verified all 73 Gide sample IDs in the expression matrix exactly matched `Sample_id` in the clinical table (no missing/extra samples) and no duplicate gene symbols in the expression file.
- Confirmed required R packages/optional dependencies (`DeconRNASeq`, `DWLS`, `immunedeconv`, `EpiDISH`, `ADImpute`, `omnideconv`) were installed before running.
- After the fixes, re-checked that `Immune_Stromal_scores_Gide.csv` had 73 non-empty rows with sensible value ranges, and visually inspected the heatmap and boxplot outputs to confirm category annotations and color legends rendered correctly (no "Unassigned" cells left dangling in categories, Response/Therapy annotations aligned).
- Monitored memory/CPU during the DWLS parallel step (RAM dropped to ~250MB free with some swap use but did not OOM or crash).

**6. Limits / caveats**
- Immune/Stromal/Other scores are a composite z-score heuristic I defined (two-level averaging: subgroup → cell type → category), not a built-in `multideconv` function — it's a reasonable but not uniquely-validated way to combine heterogeneous proportion scales across methods.
- CIBERSORTx and all single-cell-based (second-generation) methods were entirely excluded, so the cell-type estimates rest only on first-generation, signature-based methods.
- The log2→TPM reversal assumes the data was generated as `log2(TPM+1)`; I did not have independent confirmation of this from the data source, only a plausibility check (TPM=0 cases land exactly at log2 value 0 under this assumption, which matched the observed column of zeros).
- Immune/Stromal score differences by response (R vs NR) were not statistically significant (Wilcoxon p = 0.38 and 0.08) — likely underpowered at n=73 with imbalanced groups (46 R / 27 NR); this should be read as descriptive, not a validated biomarker association.
- "Epithelial" and "Cancer" were placed in an "Other" bucket excluded from both Immune and Stromal scores; depending on the biological question, one or both could reasonably be folded into "Stromal"/parenchymal framing instead.