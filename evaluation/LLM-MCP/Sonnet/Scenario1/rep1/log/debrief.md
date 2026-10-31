**1. Input data transformation**
Yes. `Gide_log2TPM.txt` held log2(TPM+1) values (confirmed by range: min 0, max ~14). Deconvolution requires linear-scale expression, so I converted with `2^x - 1` (clamping negatives to 0) before `run_deconvolution`. No transformation was applied for other steps since only deconvolution was run.

**2. Methods run / skipped**
Ran: `run_deconvolution` (Quantiseq, EpiDISH, DeconRNASeq, DWLS, CIBERSORTx — all default methods and all their bundled signatures) → `analyze_deconvolution` (harmonization into cell subgroups) → `export_session_results`.
Skipped: `aggregate_cell_groups` (I built Immune/Stromal/Tumor composites myself post-hoc in R instead of through this tool — see Limits), `benchmark_deconvolution`, `relate_subgroups_to_pathways`, `replicate_subgroups` (none requested), and CellTFusion-server/RaCInG-server (out of scope — you asked for composition/infiltration, which is multideconv's domain, not TME regulatory state or cell-cell communication).

**3. Non-default parameters**
`normalized=False` in `run_deconvolution` (default is `True`/raw counts) — set because the input, after conversion, was linear TPM, not raw counts. CIBERSORTx credentials (`credentials_mail`, `credentials_token`) were supplied from `CBSX_credentials`, since CBSX otherwise can't run. All other parameters (e.g. `analyze_deconvolution`'s correlation/zero/variance thresholds) were left at default.

**4. Problems encountered**
- First `run_deconvolution` call failed ("Expecting a matrix/an object with numeric values") because I passed a tab-delimited file where the tool expected true comma-separated CSV. Fixed by rewriting the conversion script to output with `write.csv`.
- `colData_all.txt` failed to parse with `read.delim` (`$ operator is invalid for atomic vectors`) because the file is space-delimited with quoted fields, not tab-delimited. Fixed by switching to `read.table(..., sep=" ")`.
- R's `make.names` prepended "X" to sample columns starting with digits (e.g. `X10_PD1_PRE`); handled by stripping the "X" prefix before matching back to `colData`.

**5. Checks performed before trusting results**
- Verified expression scale numerically (min/max) before deciding on the log→linear conversion rather than assuming from the filename.
- Confirmed `colData_all.txt` rows for `Cohort == "Gide"` matched the Gide expression matrix's sample columns (spot-checked several IDs).
- Checked per-sample linear-TPM column sums (~460k–530k) were in the right order of magnitude for TPM (not exactly 1e6 since this is a filtered ~19k-gene panel, not the full transcriptome).
- Inspected `analyze_deconvolution`'s discard lists (41 zero-heavy features, 1 non-standard cell type, 0 low-variance) to confirm nothing substantial was silently dropped.
- Confirmed final composition table covered all 73 Gide samples and a biologically sensible set of 37 immune/stromal/tumor cell types.

**6. Limits / caveats**
- The Immune/Stromal/Tumor compartment scores are a **post-hoc summary I constructed** (averaging harmonized subgroups per canonical cell type, then summing within compartment) — not an official multideconv function/output, so the categorization of cell types into "immune" vs "stromal" vs "tumor" reflects my own biological judgment, not a validated or built-in score.
- These summed scores are a relative ranking tool, not calibrated absolute fractions — the underlying method/signature estimates don't all share the same scale, so cross-cohort or absolute-fraction comparisons should not be made from them.
- Some cell types are represented by harmonized multi-method subgroups (more robust), others by only one or two individual method/signature features (e.g., several NK/CD8 features were dropped entirely for high zero-rate) — confidence is uneven across cell types.
- No statistical test was run linking infiltration to Response/Therapy; the color-coding in the scatter plot is descriptive only, not a significance claim.
- Results reflect pre-treatment ("PRE") Gide samples only, as that's what's in the file — no post-treatment or on-treatment timepoints were in this cohort subset.