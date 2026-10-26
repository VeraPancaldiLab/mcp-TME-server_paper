**1. Input data**
- `data/Gide_log2TPM.txt` was back-transformed to linear TPM with `2^x − 1` for the deconvolution step (`01_deconvolution.R`). Deconvolution methods assume linear-scale mixtures.
- The `+1` offset was my inference from the file name and value range; I did not confirm it.
- After back-transformation the column sums are about 41k–730k (median about 513k), not 1e6. I did not re-normalize or investigate this; one sample is far lower (about 41k).
- The marker-gene checks (PTPRC, GZMA/PRF1, stromal genes) used the original log2 values.

**2. Methods**
- **Ran:** `compute.deconvolution` with Quantiseq, DeconRNASeq, EpiDISH and DWLS on all 7 bundled signatures (284 features), then `compute.deconvolution.analysis`.
- **My own steps on top of multideconv:** z-score consensus per cell type, compartment sums, an immune/stromal consensus, tertile groups, Wilcoxon and Fisher tests against response, and marker correlations.
- **Skipped CIBERSORTx (CBSX):** it needs credentials, which weren't provided.
- **Skipped single-cell methods** (Autogenes, BayesPrism, Bisque, CPM, MuSiC, SCDC, MOMF) and signature creation: no scRNA-seq reference was available.
- **Not used:** `compute.benchmark` and the pathway/subgroup functions, since they weren't needed for the question.

**3. Non-default parameters**
- **`normalized = FALSE`:** `TRUE` would apply TPM normalization meant for raw counts to data that was already TPM.
- **`return = FALSE` in step 1:** I saved the outputs myself instead.
- **`doParallel`:** first set to `TRUE` with 6 workers, then changed to `FALSE` (see 4).
- **`compute.deconvolution.analysis`:** run with `return = TRUE, file_name = "Gide"` to save its outputs; `corr = 0.7` is the default.
- **`set.seed(123)`** for reproducibility.
- **My own thresholds:** dropping combinations with SD < 0.01 (none were dropped), tertile cut-offs, and median splits for the immune × stroma classes. These are arbitrary choices.

**4. Problems**
- **Out of memory:** the parallel DWLS run was killed after about 1 min. I re-ran serially (about 16 min) and it succeeded.
- **Duplicate row names:** the analysis output keeps whatever sample names it is given, and I had already restored the IDs (multideconv adds an "X" prefix), so remapping a second time produced NAs. I removed the second remapping.
- **`writeLines` type error:** the discarded-feature outputs were not character vectors. I added a converter.
- **Stacked bar plot:** the first version averaged quanTIseq, which has no stromal or tumour categories, with the other combinations, so bars didn't sum consistently. I restricted it to the 9 CBSX combinations.
- **Implausible quanTIseq values:** it reported 100% immune for 6_PD1_PRE and 36_PD1_PRE. I kept these samples, relied on the multi-method consensus, and flagged them.

**5. Checks**
- Confirmed sample IDs match the 73 Gide clinical rows, with no duplicate genes and no NAs.
- Confirmed the Epidish-Melanoma fractions sum to 1 per sample.
- Checked how well the 10 combinations agree on the immune fraction (Spearman 0.32–0.99).
- Compared the immune score with PTPRC (ρ 0.78), cytolytic activity (0.72) and quanTIseq (0.74), and the stromal score with stromal marker genes (0.46).
- Inspected the rendered figures.

**6. Limits**
- **Absolute fractions depend on the signature:** tumour content looks implausibly low and stroma high for melanoma, so the ranking is more reliable than the percentages.
- **Stromal score is weakly validated:** ρ = 0.46 against marker genes.
- **Immune and stromal scores are anti-correlated (−0.62),** partly just because fractions must sum to 1.
- **Many cell subsets agree poorly between methods** (Tregs, M2 macrophages, NK and mast cell subsets, with mean pairwise ρ often < 0.2). Several cell types rest on a single feature.
- **The consensus score is my own construction,** not a multideconv output. It mixes raw features with multideconv subgroups.
- **Biopsy site is unknown:** 20_ipiPD1_PRE could be a lymph-node biopsy.
- **Response associations are exploratory** (unplanned and not validated externally), and samples near the tertile boundaries could change group.
- **The input scaling assumption and the unusual column sums** from point 1 were not resolved.