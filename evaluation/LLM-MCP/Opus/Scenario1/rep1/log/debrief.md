**1. Input data**
- `Gide_log2TPM.txt` held log2(TPM+1): values 0–14, no negatives, no NAs.
- For deconvolution I converted it to linear TPM (2^x − 1, negatives clipped to 0) and passed it with `normalized=False`, because deconvolution needs linear TPM.
- I did not rescale columns to 1e6. The linear sums were about 41k–730k (median ~513k), probably because the file has only 18,979 genes. I treated it as TPM anyway.
- Nothing else used expression directly. All later steps used deconvolution output.

**2. Methods**
- **Ran:**
  - `start_workflow_session`
  - `run_deconvolution` with the default methods (Quantiseq, EpiDISH, DeconRNASeq, DWLS, CIBERSORTx) and all 7 bundled signatures
  - `analyze_deconvolution`
  - `export_session_results`
  - My own R script (`results/scripts/immune_infiltration.R`) for immune/stromal fractions, the consensus score, tertiles, tables and plots
- **Skipped:**
  - `aggregate_cell_groups`: not needed; I built lineage groupings in my script instead.
  - `benchmark_deconvolution`: no ground-truth fractions exist.
  - `relate_subgroups_to_pathways` and `replicate_subgroups`: not requested.
  - CellTFusion: answers a regulatory-state question, not infiltration.
  - Response association tests: not requested.
  - `Riaz_log2TPM.txt`: not part of the request.

**3. Non-default parameters**
- `run_deconvolution`:
  - `normalized=False`: the input was TPM, not counts.
  - CBSX email and token: taken from your file.
  - `file_name` and `output_dir`: to save inside `results/`.
- `analyze_deconvolution`: `verbose=true`, plus `file_name` and `output_dir`.
- All filtering and grouping thresholds were left at defaults (90% zero threshold, default correlation and CV thresholds).
- In my script, these were analysis choices rather than tool parameters:
  - z-score averaging across combinations
  - tertile cut-offs
  - which cell types count as stromal or tumor

**4. Problems**
- **Sample `8_PD1_PRE` had a very low total TPM** (~41k). Its Spearman correlation with the cohort mean was 0.93, so I kept it and flagged it.
- **R added an "X" prefix to sample IDs.** I stripped it and checked that the IDs match the clinical data.
- **My script first failed** with a `matrix()` length mismatch in the lineage step. I fixed the function and re-ran it.
- **Absolute immune fractions disagreed widely** across combinations (median 11%–71%). I relied on the rank-based consensus score and reported medians with IQR.
- **Non-melanoma signatures seemed to inflate fibroblasts**, likely by misassigning melanoma cells. I added a separate melanoma-signature view.
- **CD8 and NK estimates were near zero**, and multideconv discarded several of them for having too many zeros. I reported this as a finding without correcting it.
- **Your CIBERSORTx token is stored in plain text** in `results/01_deconvolution/manifest.json`. I reported this and did not edit the file. I also read the full token into this conversation when I opened the credentials file.

**5. Checks**
- **Input:** expression scale, dimensions, NAs, duplicate genes, and that all 73 samples match the Gide rows of the clinical file.
- **Deconvolution:** the log shows each method×signature combination summing to 1.
- **Agreement:** Spearman correlation of the immune fraction across the 13 combinations (median 0.65).
- **Plots:** I visually checked only two of them (melanoma-signature composition and immune fraction per patient). I did not open the heatmaps, the lineage stacked plot or the immune vs stromal plot.
- **Token:** I grepped `results/` for where the token was written.

**6. Limits**
- **No validation against true cell fractions.** Absolute proportions depend heavily on the method and signature. Only the ranking is reasonably robust.
- **Which data feeds the score.** The immune score uses only the 13 raw combinations that also estimate non-immune cells, not multideconv's 194 harmonized features. The harmonized output appears only in the heatmap.
- **Most signatures are not melanoma-specific**, which biases the stromal and tumor fractions.
- **Arbitrary choices:** the tertile cut-offs and my compartment and lineage assignments. For example, the "myeloid" group catches all remaining immune types, and Quantiseq's "uncharacterized" cells count as tumor/other.
- **Patients near the tertile borders** could change group with small changes in method.
- **CD8, NK and Treg estimates are unreliable** in this cohort.
- **`8_PD1_PRE` is a possible quality outlier.**
- **No statistical testing** was done, including no test against response.