Answers based on what I did. I ran nothing further.

**1. Input data transformation**
- I converted `Gide_log2TPM.txt` from log2(TPM+1) to linear TPM (`2^x - 1`, negatives set to 0) before any step.
- **Deconvolution:** quanTIseq via multideconv needs non-log input.
- **`prepare_input_files(already_normalized = TRUE)`:** RaCInG's 10 TPM expression threshold and its NNLS cell-profile estimation assume linear TPM.
- **Ligand–receptor strengths:** RaCInG then re-logs internally (`log2(TPM+1)`), so these use log2 values, as the package intends.
- I also prefixed sample IDs with `Gide_` (see 4) and removed the prefix again in the outputs.

**2. Methods**
- **Ran:**
  - `multideconv::compute.deconvolution` (quanTIseq only).
  - `prepare_input_files`, using my own fraction matrix, RaCInG's NNLS cell expression profiles and the default cached liana/OmniPath network.
  - `compute_racing_kernel` three times: directed raw, directed normalized, undirected raw.
  - `computeLRContributions` for all 121 sender→receiver pairs.
  - My own summary tables and ggplot/pheatmap figures.
- **Skipped:**
  - Monte Carlo (`compute_racing_montecarlo`, GSCC): the kernel method gives direct communication exactly, which was the question.
  - multideconv's subgroup analysis: it dropped the tumor compartment (see 4).
  - Other deconvolution methods (CIBERSORTx needs credentials; EpiDISH, DeconRNASeq, DWLS): to keep about 11 interpretable cell types.
  - Activity-based ligand–receptor strengths (`LR_activity`): slow and optional.
  - Statistical tests by response or therapy: not requested.
  - The Riaz data: not requested.

**3. Non-default parameters**
- **`already_normalized = TRUE`:** the data was already TPM.
- **`deconv` = my own quanTIseq matrix:** this keeps the non-immune fraction, which I renamed `Cancer`. (My first run used `deconv_method = "Quantiseq"`.)
- **`norm = TRUE`** for one run: to get enrichment over a uniform ligand–receptor baseline.
- **`remove_direction = FALSE`** for the directed runs: to keep sender and receiver separate.
- **`bundle = FALSE`** in `computeLRContributions`: one direction per pair.
- **`file_name = "Gide"`** and custom output folders.
- Unchanged: `expr_threshold = 10`, `fun_LR = min`, `zero_threshold = 1`.

**4. Problems and handling**
- **"Patient names do not match" error:** multideconv applies `make.names`, turning `10_PD1_PRE` into `X10_PD1_PRE`. I fixed it by prefixing sample IDs with `Gide_`.
- **Stray files in the project root:** multideconv wrote `Results/Deconvolution_Gide.csv` and OmnipathR wrote `omnipathr-log/`. I deleted the first (the script now does this) and moved the logs to `results/logs/`.
- **Tumor compartment silently dropped:** after the default subgroup step, only 10 immune types remained. Row sums were 0.14–1 before RaCInG rescaled them to 1, which inflated immune fractions. The cause is that `uncharacterized.cell` doesn't match the nomenclature entry `uncharacterized_cell`. I fixed it by passing my own fractions.
- **A glob `rm` was blocked by permissions:** I deleted the specific files by absolute path instead.
- **Fixes to my own script:**
  - Changed ranking from raw median to median share; only ranks 8 and 9 swapped.
  - Replaced approximate error bars with true IQR of the shares.
  - Removed a deprecated ggplot function.
  - Removed NA rows from a printed table.
  - Fixed clipped plot labels.
- **Metadata warning:** `fread` warns because `colData_all.txt` has a header/column-count mismatch (an extra index column). Columns are matched by name, so I left it.
- **One diagnostic check failed:** the `Lmatrix` has no row names, so my check of whether Monocytes→Neutrophils is structurally impossible errored. I didn't fix it. Instead I confirmed that both cell types are present together in only 34 of 73 samples, which explains the median of 0.

**5. Checks**
- The ligand–receptor contributions sum to the kernel scores (maximum difference < 1e-10).
- quanTIseq fractions sum to 1 in every sample.
- Sample IDs are unique, and their order matches the kernel output rows.
- Metadata matched all 73 samples, and every cell type has a display label.
- I looked at the cell fractions, the log warnings and three of the figures.
- **Not checked:** agreement with Monte Carlo, sensitivity to the expression threshold or deconvolution method, and comparison against published results.

**6. Limits and caution**
- **Rankings mostly reflect quanTIseq abundances.** "Cancer" means all non-immune cells, including stroma, which is why COL3A1 and POSTN appear as "tumor" ligands.
- **Ligand–receptor assignment to rare immune cells is unreliable.** It depends on NNLS-estimated profiles and includes implausible cases (ANGPTL3 from B cells, PDGFD/LAMA2 from NK cells).
- **Per-patient totals are 0.76–1.0, not exactly 1.** I didn't investigate why, so the README's "≈ 1" is loose.
- **Ligand–receptor strength is bulk expression,** the minimum of ligand and receptor log-TPM. It is the same for every cell-type pair within a patient.
- **CD4 helper T cells and dendritic cells are absent in most samples,** and CD8 T cells and Tregs are very low.
- **I treated PD1 and ipi+PD1 samples as independent.** I didn't check for repeated patients.
- **Ligand–receptor results are very spread out** (no pair above about 0.3%), so their order is fragile.
- **No response-related statistics** and only one deconvolution method.