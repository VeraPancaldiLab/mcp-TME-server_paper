**1. Input data transformation**
- `Gide_log2TPM.txt` was converted back to linear TPM (`2^x − 1`, negatives set to 0) and passed to `CellTFusion(normalized = FALSE)`.
- **Why:** the help page says that with `normalized = FALSE` the input must be TPM that is not log-transformed. CellTFusion uses the TPM values directly for deconvolution and computes log2(TPM+1) itself for TF and pathway activity. Passing the log values would have log-transformed them twice.
- I assumed the file is log2(TPM+1), based on its name and its value range (max 14). The back-transformed columns sum to 41k–730k rather than 1e6, and I did not renormalize them.
- For the logistic models, I standardized each state score so odds ratios are per standard deviation.

**2. Methods**
- **Run:** `CellTFusion()` as a single call, which covers:
  - deconvolution with quanTIseq, EpiDISH, DeconRNASeq and DWLS, then the deconvolution subgrouping step
  - TF activity (CollecTRI network, ulm method) and PROGENy pathway activity
  - TF modules (`compute.WTCNA`) and cell groups
  - bootstrap NMF to define the states, and cell niches
- **Run afterwards:**
  - `identify_hub_TFs`
  - `compute.modules.relationship`: states against PROGENy, quanTIseq and TF modules; modules against PROGENy
  - `scores.stat.analysis` (Wilcoxon) on states, cell groups, modules and pathways
  - `compute.metadata.association` (ANOVA on Response and Therapy)
- **Base-R tests I added myself:** AUC; logistic regression with and without therapy adjustment, plus a therapy interaction test; Wilcoxon within each therapy arm; Fisher's exact test and a therapy-stratified exact test on the dominant state; a sensitivity analysis without sample `8_PD1_PRE`.
- **Skipped:**
  - CIBERSORTx: no credentials.
  - GSVA gene sets: none provided.
  - `compute.modules.enrichment` (Reactome): not run.
  - Survival analysis: there is no survival data in the clinical file.
  - Multi-cohort/batch mode, cross-validation and projection functions: single cohort.
  - The Riaz data: not used, so there is no external validation.

**3. Non-default parameters**
- **`normalized = FALSE`:** the input is TPM, not raw counts.
- **`deconv_methods` without "CBSX":** CIBERSORTx would have been skipped anyway without credentials.
- **`do_parallel = TRUE`, `workers = 3`:** for speed. I first used 6 workers, which ran out of memory (see 4).
- **`file_name = "Gide"`:** to name the output files.
- **Downstream:**
  - `padj = TRUE` (Benjamini-Hochberg) in the correlation, Wilcoxon and ANOVA calls, to correct for multiple testing.
  - `test = "wilcox"` instead of the default Fisher test, because response is binary and the scores are continuous.
  - `plot_grid = TRUE`, so categorical traits are tested.
  - `vertical = TRUE`, for plot layout only.
- **Left at defaults and not tuned:** all biological thresholds (`corr`, `pval`, `min_module_size`, `corr_mod`, `top_n`, NMF ranks 2–15, hub TF thresholds).

**4. Problems**
- **Out of memory:** the first run was killed during DWLS with 6 workers. The container has a 6 GB memory cap. I killed a leftover worker process and reran with 3 workers, which peaked at about 4.4 GB and finished.
- **No vignette installed:** I read the package help pages instead.
- **Package messages I accepted without acting on them:**
  - quanTIseq found 129/138 of its signature genes.
  - DeconRNASeq printed that its PCA suggests 1 cell type in the mixtures.
  - 30 of 750 deconvolution features were not assigned to any cell group.
  - The metadata function drew no correlation heatmap because there are no numeric traits.
- **Low-quality sample:** `8_PD1_PRE` has only ~4.6k expressed genes (median ~12k) and a low TPM total. I kept it and ran a sensitivity analysis without it.
- **Number of states:** the NMF selected 2 states, the lowest candidate, because it was the only number where all states were both stable and distinct.

**5. Checks**
- **Data:** dimensions, no missing values, plausible log range, no duplicate genes, all 73 samples matched to clinical rows in the same order (enforced with `stopifnot`), all samples pre-treatment, and the response by therapy table.
- **Log:** no TPM-scale warning and no errors.
- **NMF:** I inspected the rank selection and stability tables.
- **Biological consistency:** State 1 tracks CD8 T cells, JAK-STAT and STAT1/IRF1 hub TFs.
- **Confounding:** therapy adjustment, analysis within each arm, and the interaction test. The sensitivity analysis without the outlier gave the same result.
- **Figures:** I opened 2 of them to confirm they render. I did not open the other PDFs, including the by-therapy boxplot, where I removed a plot layer in code.

**6. Limits**
- **Validation:** one cohort with no external validation (Riaz was not used). Within the CTLA4+PD1 arm alone, the State 1 effect is not significant (p = 0.097; 8 non-responders).
- **Number of states:** rank 2 sits at the lower bound of the range tested, so the states are coarse.
- **Novelty:** State 1 largely captures a known inflamed/CD8/IFN signature. I did not compare it with established response signatures.
- **State labels:** "immune-inflamed" and "stromal/TGF-β/hypoxic" are my interpretation. They rest on hub TF names, PROGENy correlations and niche features, since Reactome enrichment was not run. State 2 correlates only weakly with quanTIseq cell fractions.
- **Dominant-state test:** the dominant-state split is one of several possible ways to dichotomize continuous scores.
- **Multiple testing:** BH correction was applied within each family of tests, not across all of them.
- **Deconvolution:** CIBERSORTx is missing, and the TPM totals are not 1e6.
- **Sample independence:** I assumed each sample is a different patient. I did not check whether `N_PD1` and `N_ipiPD1` samples with the same number come from the same person.