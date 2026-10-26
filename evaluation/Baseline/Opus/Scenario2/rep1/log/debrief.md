## 1. Input data

- **Transformation:** I back-transformed log2(TPM+1) to linear TPM with `2^x − 1`, set any negative values to 0, and rescaled each sample to sum to 1e6. I passed the result to `CellTFusion()` with `normalized = FALSE`.
- **Which steps used it:** CellTFusion uses this TPM directly for deconvolution. For TF activity and PROGENy it computes log2(TPM+1) internally, so every step started from my transformed matrix.
- **Why:** the documentation says to pass raw counts or *non-log* TPM, and warns that log values would be logged twice.
- **Why rescale:** the file has only ~19k genes, and per-sample sums ranged from 41k to 730k rather than 1e6. Rescaling was my own choice, not a package requirement, and I did not test how much it changes the results.
- **Assumption:** I assumed the pseudocount was +1 because the minimum value is 0 and 13% of values are 0. I did not confirm this from the data's source.

## 2. Methods

**What I ran:**
- **`CellTFusion()` in one step.** Internally this ran:
  - multideconv deconvolution with Quantiseq, Epidish, DeconRNASeq and DWLS across several signatures, followed by the deconvolution subgroup analysis;
  - TF activity (CollecTRI, ulm);
  - the WGCNA TF network and modules;
  - PROGENy pathway activity;
  - cell group construction;
  - bootstrap NMF latent factors;
  - cell niches.
- **CellTFusion's own association tests:** `compute.metadata.association()` on the TF modules versus Response and Therapy, and `scores.stat.analysis(test = "wilcox")` on the cell groups and on the NMF factors.
- **My own R code:** for every feature, a Wilcoxon test, AUC, a Wilcoxon test within each therapy arm, and a logistic regression adjusted for therapy. I also assigned each patient a dominant state and tested it against response with Fisher tests, and computed Spearman correlations between the factors and the deconvolution, TF and pathway scores.

**What I skipped:**
- **CIBERSORTx:** no credentials.
- **Not run, by choice:** `compute.modules.enrichment` (Reactome), `identify_hub_TFs`, `compute.modules.relationship`, `project_factors`, and GSVA custom gene sets. I judged them unnecessary for the question rather than finding them unusable.
- **ML functions** (`prepare_celltfusion_folds`, `compute.test.set`): not attempted.
- **Survival analysis:** the clinical file has no survival columns.
- **Multi-cohort mode (`batch`):** not used, because this is a single cohort.
- **Riaz data:** not used.

## 3. Non-default parameters

- **`normalized = FALSE`:** required because the input is TPM, not counts.
- **`deconv_methods` without CBSX:** this gives the same outcome as the default, since CBSX is skipped without credentials anyway.
- **`do_parallel = TRUE`, `workers = 4`:** for speed. I kept the worker count low because the machine has 15 GB of RAM.
- **`file_name = "Gide"`:** only affects output file names.
- **Defaults I set explicitly:** `seed = 123` and `TF.collection = "CollecTRI"`.
- **Not tuned:** all module, cell group and NMF parameters stayed at their defaults (`min_module_size`, `corr_mod`, `corr`, `pval`, NMF ranks and thresholds).
- **Downstream tests:**
  - `compute.metadata.association(padj = TRUE, plot_grid = TRUE)`: `plot_grid` is needed because the traits are categorical.
  - `scores.stat.analysis(test = "wilcox", padj = TRUE)`: the default test is Fisher on a median split; I chose Wilcoxon instead.
  - The overall Fisher test on the dominant state used a simulated p-value (B = 1e5).

## 4. Problems

- **Exploration errors:** `ls("package:CellTFusion")` failed because the package was not yet attached; I fixed it with `library()`. A later indexing call failed because I treated a vector as a matrix. Neither affected the results.
- **Inverted odds ratio (my bug):** the state-versus-rest odds ratios were first computed with the table columns in NR/R order, so Factor1 showed OR 0.107. I reordered the columns to R/NR and re-ran; the OR became 9.36. The p-values were unaffected.
- **Hard-coded output folder:** the package always writes to `Results/`. I ran it from inside `results/`, so its outputs are in `results/Results/`. An `omnipathr-log/` folder also ended up in `results/`.
- **Low-depth sample:** `8_PD1_PRE` sums to only 41k TPM over these genes, about 8% of the median sample (I wrote "about 4%" in the summary, which compared it to 1e6). I kept it without a sensitivity analysis.
- **Pipeline messages I did not act on:**
  - DeconRNASeq printed "PCA indicates number of cell types = 1".
  - 37 deconvolution features were discarded for having too many zeros, and one cell type was discarded.
  - 22 of 669 features were not assigned to any cell group.
  - The metadata heatmap was not drawn because there are no numeric traits, which is expected.
- **Warnings check:** I grepped the log for warnings and errors only partway through the run, not after it finished.

## 5. Checks

- **Input format:** value range, per-sample sums and the zero fraction, to work out the transform.
- **Sample matching:** all 73 expression samples are in the clinical data; I checked the Response and Therapy tables.
- **NMF stability:** the rank selection and stability tables (rank 3: all three factors robust, recovery 0.78–0.92).
- **TF modules:** the proportion of variance each module explains.
- **Biological coherence:** each factor's correlations with cell types, pathways and TFs make sense together.
- **Therapy confounding:** therapy-adjusted and within-arm tests.
- **Figures:** I visually inspected two of them (factor boxplots and the characterization heatmap).

**Not checked:**
- the other PDFs;
- agreement between deconvolution methods;
- sensitivity to the rescaling, the seed or parameters;
- whether the internally recomputed log2 TPM matches the original file.

## 6. Limits

- **No validation:** one cohort of 73 patients.
- **Multiple testing:** BH was applied within each feature set only, not across sets or across the different tests. Many tests were run overall.
- **Post-hoc analysis:** the dominant-state Fisher test was my own addition.
- **Therapy imbalance:** responders are enriched in the ipi+PD1 arm (p = 0.09).
- **Factor3 is weaker:**
  - its Wilcoxon q is 0.052, which only passes after therapy adjustment (q = 0.029);
  - its signal is mostly in the ipi+PD1 arm;
  - it relies on the turquoise module, which explains only 9.5% of its TFs' variance;
  - its activated memory CD4 correlation is likely an artifact.
- **Labels are my interpretation:** names like "immune-inflamed", "stromal" and "tumour-intrinsic" come from the correlations; the package did not assign them.
- **Untested choices:** the results depend on the default parameters and my rescaling, and neither was varied. CIBERSORTx features are missing.
- **Response labels:** I used the R/NR labels from the clinical file as given.