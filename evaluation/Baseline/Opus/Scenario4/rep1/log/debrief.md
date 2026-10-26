## 1. Input data transformations

- **log2(TPM+1) back to linear TPM** (`2^x − 1`, negatives set to 0). RaCInG's `prepare_input_files()` expects linear TPM: its 10 TPM expression threshold and its internal `log2(TPM+1)` LR weighting assume it, and quanTIseq/EPIC expect linear TPM.
- **Re-closed each sample to 10^6.** The file is a filtered gene set, so per-sample TPM sums were 0.04–0.73 million instead of 1 million. Without re-closing, the absolute 10 TPM threshold would act very differently across samples. This changes absolute values a lot for some samples (about 24× for `8_PD1_PRE`), so I also ran "no re-closure" as a sensitivity variant.
- **Where the transformed data was used:** deconvolution (quanTIseq, EPIC), NNLS cell-type profiles, L/R thresholds, and LR weights. The LR weights are log2(rescaled TPM + 1), computed inside the package for the default prior and by my code for the curated prior.
- **Sample IDs prefixed with "Pt"** for processing, and stripped again in the outputs.

## 2. Methods run and skipped

**Run:**
- multideconv quanTIseq; EPIC (curated prior only).
- `prepare_input_files()` with a supplied `deconv`.
- `compute_racing_kernel()` / `compute_kernel()` / `compute_kernel_features()`, for D, W, TT and GSCC, both raw and normalized.
- `compute_racing_montecarlo()`: D for both priors; W and TT for the default prior.
- `compute_results_processing()`, `computeLRContributions()`.
- My own analysis code:
  - edge, motif and hub summaries;
  - PCA;
  - resampling consensus clustering (ConsensusClusterPlus is not installed);
  - Wilcoxon marker edges;
  - Fisher test vs response;
  - perturbation framework, patient bootstrap, prior-concordance analysis, synthesis.

**Skipped or not fully used:**
- **Default subgroup path** (`compute.deconvolution.analysis`): bypassed because it drops the tumour fraction.
- **Other deconvolution methods:** only quanTIseq for immune cells (CIBERSORTx needs credentials; others not tried).
- **Sign matrix** (`signed`): not used.
- **Package statistics** (`wilcox_group_test`, `correlate_features_with_score`): not used; I wrote my own tests.
- **Wedge/triangle LR decompositions:** not run.
- **Monte Carlo:**
  - CT and GSCC not simulated.
  - Motifs only for the default prior, raw scale only.
- **GSCC:** kernel features computed but not interpreted.
- **easier:** `compute_LR_pairs` tested on 3 samples, then not used.
- **Riaz dataset:** not used (not requested).
- **Curated-prior perturbations:** fewer variants than for the default prior; no threshold, `fun_LR` or re-closure variants.

## 3. Non-default parameters

**Package parameters:**
- `prepare_input_files`:
  - `already_normalized = TRUE`, because the input is TPM.
  - `deconv` supplied, to keep the full composition including Tumor.
  - `expr_threshold = 10` and `fun_LR = min` are defaults, only set explicitly.
- Kernel:
  - `norm` run both FALSE and TRUE.
  - Directed edges extracted with `bundle = FALSE` and `zero_threshold = 1.01` (so no columns are dropped and all patients share the same edge set).
- Monte Carlo:
  - `remove_direction = FALSE`, `norm = TRUE` for D, `ncores` 8–10.
  - Ngraphs 100 for default D (the default), but **50 for curated D**, and Ncells 5000 / Ndegree 10 / Ngraphs 20 for motifs. I reduced these after the first run took 2.1 h.

**My analysis choices (all chosen by me, not tuned against data):**
- Top-10 cut-off for "dominant".
- "Commonly enriched" means at least 75% of patients with both cell types present, with at least 20 such patients.
- Consensus clustering: 500 × 80% resamples, Ward linkage, k = 2–6, k chosen by lowest PAC with a minimum cluster size of 5.
- Perturbations: noise sd 0.3; 80% subsamples; 20 replicates; thresholds of 5 and 20 TPM; `prod`.
- Robustness tiers: retention ≥ 0.8, bootstrap ≥ 0.9.

## 4. Problems and how I handled them

1. **Sample IDs with a leading digit:** multideconv renamed them (X-prefix), which caused a patient-name mismatch error. Fixed with the "Pt" prefix.
2. **Tumor fraction dropped:** the default deconvolution path discarded the uncharacterized fraction (about 60% of cells), leaving an immune-only network. I passed the full quanTIseq composition instead.
3. **Cell-type labels kept the `Quantiseq_TIL10_` prefix.** I mapped them to short names.
4. **Implausible NNLS L/R assignments,** and poor agreement with the curated matrices (κ −0.06 to 0.48). I added the curated-prior pipeline as a second analysis.
5. **Missing genes:** CCL3/4/5/14/18/23 are absent from the file. Documented only.
6. **Low-quality sample `8_PD1_PRE`:** kept, and tested by removal.
7. **Enrichment for absent cell types:** it stays defined when a cell type has zero abundance, which inflated prevalence. I made prevalence presence-aware.
8. **Out-of-memory failures:** 6 parallel perturbation workers died. I reduced to 2 cores and added handling for dead workers.
9. **`EPIC()` failed in forked workers.** Attached `library(EPIC)` and reran.
10. **Unseeded consensus clustering inside perturbations.** Seeded it and reran both perturbation sets.
11. **Monte Carlo much slower than expected.** I stopped the job chain and reran the remaining runs with fewer graphs. My "wait for PID" loop hung on a zombie process, so I launched those runs directly.
12. **Minor code issues:** a stray code fragment in `04c` (fixed before it ran), a deprecated ggplot geom, and wrong facet ordering in a figure. All fixed.

## 5. Checks before trusting results

- The installed package's `compute_kernel` matches the local source (I compared only that function).
- Expression scale and per-sample TPM sums.
- NNLS marker genes in the cell-type profiles. This is how I found the contamination: melanoma genes such as PMEL/MLANA appear in immune profiles.
- Directed edge probabilities sum to 1 per patient. Their bundled sums were close to, but not exactly, the package's own direct features (max difference 0.0017); I did not investigate the difference further.
- The refactored curated-input builder reproduces the earlier inputs exactly.
- Monte Carlo vs kernel: edges agree with r ≥ 0.98 per patient; wedges and triangles with r ≥ 0.998.
- PC1 sign, by inspecting loadings and correlations with cell fractions.
- Figures rendered and inspected visually.

## 6. Limits and cautions

- **Bug in the LR-driver output:** the column `frac_patients_present` is a copy of `frac_top5`. The colour legend in `03_patterns/figures/e_lr_drivers.pdf` ("fraction of patients") actually shows the fraction of patients in which that pair is in the edge's top 5.
- **Report section 6.6 is unverified:** the claim that the kernel GSCC (`lab = 1`) is "sub-critical / not comparable" to Monte Carlo was not tested.
- **The curated prior is an approximation:**
  - LR pairs = the union of nonzero pairs across the 10 bundled example patients.
  - Its composition mixes quanTIseq and EPIC; Tumor = "other" minus CAF and Endo, floored at 0.
- **The default prior has known weaknesses:** "Tumor" includes stroma, and monocyte/neutrophil estimates are less reliable. Those cell types can't be checked against the curated prior.
- **Patient clusters are weak** (PAC 0.59 for the default prior) and unstable. The perturbation ARI used a fixed k and only 100 resamples, against a baseline built with 500.
- **LR-level drivers depend on the prior** and should be treated as hypotheses.
- **Response associations were not requested:** they are exploratory, uncorrected, and not adjusted for therapy.
- **Tier thresholds and set definitions are my own choices.** Single-setting perturbations had n = 1 run each.
- **Monte Carlo with ncores > 1 is not seed-reproducible,** and the two priors used different numbers of graphs.