Answers below. Reviewing my work turned up two errors in what I reported, plus one input issue I missed; they are covered under 4 and 6.

**1. Input data**
- **Transformation:** I converted `data/Gide_log2TPM.txt` back to linear TPM (2^x − 1) and set any small negative values to 0. CellTFusion received this file with `normalized=False`.
- **Why:** deconvolution must run on linear TPM, not log values. CellTFusion computes log2(TPM + 1) itself for the TF and pathway steps.
- **No other transformation:** the response tests used CellTFusion's output scores directly.

**2. Methods**
- **Ran:**
  - `run_celltfusion` (deconvolution with Quantiseq, EpiDISH, DeconRNASeq, DWLS and CIBERSORTx; TF activity; WGCNA TF modules; PROGENy pathways; cell groups; NMF with automatic rank selection).
  - `scores_wilcox_test` twice, once on the 2 factors and once on the 154 cell groups.
  - My own R script, `results/scripts/response_stats.R`, for the same Wilcoxon test plus BH-FDR, medians and direction.
  - A quick Spearman correlation between factors and pathways to help interpret them. You didn't ask for this, and I didn't save it.
- **Skipped:**
  - Reusing earlier deconvolution or TF results, because none existed.
  - multideconv, because CellTFusion does its own deconvolution.
  - Adjusting for therapy and validating in the Riaz cohort, because I proposed these but you didn't request them.
  - Testing individual TFs or pathways against response, because that wasn't asked.

**3. Non-default parameters**
- **`run_celltfusion`:**
  - `normalized=False`, because the input was linear TPM.
  - `cbsx_mail` and `cbsx_token`, taken from your credentials file.
  - `file_name`, `output_dir` and `session_id`, which only control naming and locations.
- **`scores_wilcox_test`:**
  - `pval=1` for the factors, so both got plots.
  - `pval=0.05` for the cell groups, to limit the plots to nominal hits.
- I left all analysis settings at their defaults.

**4. Problems**
- **Token leak:** CellTFusion wrote the CIBERSORTx token in plain text into `results/celltfusion/manifest.json`. I removed it there and confirmed with a search that it appears nowhere else in `results/`. The token was also printed in this session's terminal output when I read it from the file.
- **Missing statistics:** the Wilcoxon tool returned no p-values or effect direction, so I recomputed them with my script.
- **Ties warnings:** the Wilcoxon test warned that exact p-values couldn't be computed because of tied values (many factor scores are exactly 0). Approximate p-values were used instead; I accepted this.
- **Unassigned features:** 32 of 832 deconvolution features were not assigned to any cell group. This is reported by the tool, and I left it as is.
- **Error in my summary and README:** I wrote "13 TF modules". The module file lists 12.

**5. Checks**
- **Expression scale:** values run from 0 to 14 with no negatives or missing values, consistent with log2(TPM + 1).
- **Clinical matching:** all 73 samples match the clinical data, and all are pre-treatment.
- **Number of states:** both NMF factors were stable (93% and 100% bootstrap recovery). No higher rank gave stable, distinct factors.
- **Credentials:** I searched `results/` for the token after the run and again after exporting the logs.

**6. Limits**
- **Therapy confounding:** therapy is unevenly split between responders and non-responders, and I did not adjust for it.
- **No validation:** the states were found and tested in the same 73 samples, with no replication cohort.
- **TPM sums (missed earlier):** the back-transformed TPM sums per sample range from about 41,000 to 730,000, not the expected ~1,000,000. This could mean a different pseudocount, a subset of genes, or unusual samples, and I did not investigate it. It may affect the deconvolution estimates.
- **Unverified README claim:** the README says the TF step used "CollecTRI (ulm)". I didn't confirm which scoring statistic CellTFusion used, so treat that as unverified.
- **Interpretation of the factors:** the labels I gave them ("myeloid/stromal", "immune-active") are based on their top cell groups, TF modules and pathway correlations. They are interpretations, not definitions.
- **Cell groups overlap:** the 33 FDR-significant cell groups largely repeat the Factor 2 signal rather than adding independent findings.