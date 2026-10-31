1. **Input transformation:** Yes. Both `Gide_log2TPM.txt` and `Riaz_log2TPM.txt` were log2(TPM+1). I converted them back to linear TPM (`2^x - 1`) before deconvolution only, because cell-type deconvolution requires linear TPM, never log-transformed input. No other transformation was applied (no additional normalization, no batch correction between Gide and Riaz).

2. **Methods run:** `multideconv::run_deconvolution` (on Gide and Riaz separately, default methods: Quantiseq, EpiDISH, DeconRNASeq, DWLS, CIBERSORTx, all bundled signatures) → `pipeML::train_ml_model` (classification, `fold_construction_fun="prepare_multideconv_folds"`, default algorithm panel) → `multideconv::replicate_subgroups` (project Riaz onto Gide's learned subgroups) → `pipeML::predict_ml_model` → `pipeML::compute_shap_values`.
Skipped: `aggregate_cell_groups` and `benchmark_deconvolution`/`relate_subgroups_to_pathways` (not requested, not needed for the prediction task); CellTFusion and RaCInG servers (user asked specifically for cell composition via pipeML + multideconv, not TF/regulatory state or cell-cell networks).

3. **Non-default parameters:** `normalized=FALSE` in `run_deconvolution` (required — input was already TPM-scale, not raw counts); `fold_construction_fun="prepare_multideconv_folds"` in `train_ml_model` (required for leakage-free harmonization since multideconv subgroups must not be built on data that includes test folds); `trait_positive="R"` (required — defines which class is "positive" for AUROC/AUPRC/SHAP direction; not a free choice). All other parameters (fold count/repeats, algorithm list, SHAP settings) were left at defaults.

4. **Problems encountered:**
   - Gide sample IDs starting with digits (e.g. `10_PD1_PRE`) were auto-prefixed with "X" by R (`make.names`) inside the deconvolution output. I detected this by inspecting the result CSV row names and fixed it by renaming the matching entries in my `Gide_target.csv` to match (`X10_PD1_PRE`), otherwise the labels would have silently failed to join.
   - `train_ml_model`'s `Custom_output` (needed to project Riaz) is nested inside `result.rds`, not saved separately by the tool. I wrote a small R script to extract and save it as its own `.rds` file, as the tool documentation specified was required for `replicate_subgroups`.
   - No tool errors, crashes, or failed calls occurred during the run.

5. **Checks performed before trusting results:**
   - Confirmed `rna_id` in `colData_all.txt` matched expression-matrix column names exactly for both cohorts.
   - Confirmed no duplicate gene symbols in either expression file.
   - Confirmed the expression scale (max ~12.9, consistent with log2(TPM+1)) before converting.
   - Confirmed Response labels present for all samples in both cohorts (no missing/NA), and checked class balance per cohort.
   - Verified the deconvolution ran on the same default method/signature set for both cohorts (so Riaz's raw features before projection were a superset consistent with Gide's — Riaz was then correctly projected onto Gide's exact training subgroup space before prediction).
   - Checked the model's CV AUROC/AUPRC ranking table to confirm which algorithm was actually selected (XGBoost) rather than assuming.

6. **Limits / caution:**
   - Test AUROC (0.654, 95% CI 0.46–0.85) crosses 0.5, so generalization from Gide to Riaz is weak/uncertain by this metric, even though internal CV on Gide looked strong (0.833).
   - Riaz's class balance (10 R/41 NR) is very different from Gide's (46 R/27 NR), which likely limits how comparable the two cohorts' "response" signal is and contributes to the CI width.
   - SHAP values and direction-of-effect were computed on the 73 Gide training samples only, i.e. they describe what drove the model's fit on the training cohort, not an independent validation of feature importance on Riaz.
   - No hyperparameter tuning, feature selection, or batch correction between cohorts was done beyond pipeML/multideconv defaults — a stronger cross-cohort harmonization approach might change results.
   - I did not run CIBERSORTx-method benchmarking or validate deconvolution proportions against any ground truth; deconvolution accuracy itself is assumed, not verified.