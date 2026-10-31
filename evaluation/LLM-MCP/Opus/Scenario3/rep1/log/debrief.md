**1. Input data transformation**
- Both files were log2(TPM+1), with values from 0 to about 14–17 and no negatives or NAs.
- For deconvolution, the only expression-based step, I converted them back to linear TPM (2^x − 1) and set any negatives to 0 as a safeguard. Deconvolution should run on linear TPM.
- These went to `run_deconvolution` with `normalized=False`.
- No other step used expression directly. pipeML only received deconvolution features.

**2. Methods run and skipped**
- **Run:**
  - multideconv `run_deconvolution` on each cohort.
  - pipeML `train_ml_model` on Gide, with per-fold subgroup harmonization via `prepare_multideconv_folds`.
  - multideconv `replicate_subgroups` to project Riaz onto Gide's subgroups.
  - pipeML `predict_ml_model` on Riaz and `compute_shap_values`.
  - Small R scripts of my own: the TPM conversion, target tables, the SHAP ranking with a direction column, and a lookup of subgroup composition.
- **Skipped:**
  - Standalone `analyze_deconvolution`: harmonization happened inside the CV folds, and the final subgroup definitions came from the model's `Custom_output`.
  - `aggregate_cell_groups`: optional and not requested.
  - `benchmark_deconvolution`: no known cell fractions to compare against.
  - SHAP on the Riaz test set.
  - CellTFusion and RaCInG: not asked for.
  - Exporting the multideconv sessions: they weren't export-ready because no standalone harmonization stage was recorded. Only the pipeML session was exported.

**3. Non-default parameters**
- **Required by the data or the task (not choices):**
  - `normalized=False` (input was TPM, not counts).
  - CBSX credentials.
  - File paths, output dirs and file names.
  - `target_column="Response"`.
- **Choices I made, both stated in my plan before running:**
  - `trait_positive="R"`, so responders are the positive class.
  - `fold_construction_fun="prepare_multideconv_folds"`, so subgroup harmonization is recomputed within each fold and can't leak.
- Everything else was default: methods, signatures, CV scheme and algorithms.

**4. Problems encountered**
- **Gide sample names gained an "X" prefix** in the deconvolution output, because R adds one to names starting with a digit. I wrote `Gide_target_matched.csv` with the same renamed IDs and checked that every sample matched. Riaz names were unaffected.
- **`replicate_subgroups` needed an RDS file.** I extracted the model's `Custom_output` to `custom_output_deconv_res.rds`.
- **Gide TPM sums are uneven** after back-transformation: about 130k–660k per sample, versus about 950k for Riaz. I noted this and proceeded without renormalizing.
- **The CIBERSORTx token is in plain text** in two `manifest.json` files. I reported this but didn't edit the files.
- No tool returned an error.

**5. Checks before trusting results**
- **Inputs:** expression scale, NAs and negatives; that every expression sample was in the clinical table; the responder/non-responder counts per cohort; and that all samples were pre-treatment.
- **Deconvolution:** CBSX actually produced output (91 columns), and each method's proportions summed to 1.
- **Labels:** Gide and Riaz sample IDs matched their target tables.
- **Projected Riaz features:** no NAs. I didn't explicitly compare them against the model's 180 feature names. I inferred full coverage from the lack of NAs and the prediction running cleanly.
- **Model:** reviewed the CV results per algorithm and the selected model's tuning parameters.

**6. Limits and cautions**
- **The test set is small**, with 10 responders. Both confidence intervals are wide, and the AUROC interval includes 0.5.
- **The sensitivity and specificity I reported are optimistic.** The cutoff was the one with the best MCC, chosen on Riaz itself.
- **The CV estimate is somewhat optimistic.** RF was picked as the best of 11 algorithms on that same CV. Its mean CV AUROC (0.79) is also lower than the median I quoted (0.83).
- **SHAP describes the training data only.** The values come from one RF model on Gide.
- **Many of the 180 features are correlated** across methods and signatures, so importance is spread among them.
- **The "direction" column is my own heuristic** (Spearman correlation between feature value and SHAP value), not a pipeML output.
- **The cohorts differ** in responder rate (63% vs 20%), therapy (anti-PD1 plus anti-CTLA4 vs anti-PD1 alone) and TPM scaling. The scaling difference may affect some deconvolution methods.
- **Patient overlap in Gide is unverified.** I didn't check whether the `PD1` and `ipiPD1` samples sharing a number are the same patient. If they are, the CV folds could leak.