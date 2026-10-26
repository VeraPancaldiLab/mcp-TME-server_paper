# TME-based immunotherapy response prediction (Gide + Riaz)

## Data
- `data/Gide_log2TPM.txt` (73 samples) and `data/Riaz_log2TPM.txt` (51 samples): log2(TPM+1), same 18,979 genes in the same order.
- `data/colData_all.txt` provides each sample's immunotherapy `Response` (R / NR). Pooled cohort: 124 samples, 73 R / 51 NR (46 R / 27 NR in Gide; 10 R / 41 NR in Riaz).
- Expression was converted back to linear TPM (`2^x - 1`) before deconvolution, since cell-type deconvolution must run on linear-scale values, never log-scale.

## Pipeline (multideconv -> pipeML)

1. **Deconvolution** (`mcp__multideconv-server__run_deconvolution`): 5 methods (Quantiseq, EPIC/Epidish, DeconRNASeq, DWLS, CIBERSORTx) across all bundled signatures on the pooled linear-TPM matrix -> 124 samples x 375 method-signature-cell-type columns.
   -> `deconvolution/raw_deconvolution_matrix.csv`

2. **Model training, leakage-free** (`mcp__pipeML-server__train_ml_model`, `fold_construction_fun="prepare_multideconv_folds"`): classification of Response (positive class "R") directly from the **raw** deconvolution matrix. multideconv's cross-method harmonization (correlation >= 0.7, Spearman; drop >=90%-zero or near-constant features) is recomputed from scratch inside every one of the 10-fold x 5-repetition CV folds' training samples only, so the harmonized cell-subgroup features a fold is scored on never saw that fold's held-out samples. This is the primary, most rigorous result.
   -> `model/leakagefree/trained_model_RF.rds`, `AUROC_median_per_algorithm.csv`, `AUPRC_median_per_algorithm.csv`, `*.pdf`
   -> Final full-cohort refit's harmonized features: `deconvolution/harmonized_TME_features_leakagefree_final_refit.csv` (124 samples x 193 TME features)

3. **Feature importance, leakage-free model** (`mcp__pipeML-server__compute_shap_values`): SHAP values of the final RF model on its 124 training samples x 180 retained TME features (after automatic pruning of near-constant/highly-correlated ones).
   -> `shap/leakagefree/SHAP_values_per_sample.csv`, `shap/leakagefree/SHAP_feature_importance.csv`

4. **Naive (secondary) comparison**: TME harmonization run once on the whole cohort (`mcp__multideconv-server__analyze_deconvolution`, controlling for `Cohort` as a batch covariate) before a standard (non-custom-fold) `train_ml_model` run and SHAP. Kept for comparison only -- `model/naive/`, `shap/naive/`, `deconvolution/harmonized_TME_features.csv` (this one did control for cohort batch effects, which the leakage-free fold reconstruction above does not support).

## Model performance (10-fold CV x 5 repetitions)

### Primary (leakage-free, `fold_construction_fun`)
Best model: **Random Forest (RF)**, median AUROC = **0.82** (MAD 0.12), median AUPRC = 0.79.

| model      | Median AUROC | Median AUPRC |
|------------|-------------:|-------------:|
| RF         | 0.821        | 0.790        |
| XGboost    | 0.819        | 0.818        |
| GLMNET     | 0.817        | 0.780        |
| RIDGE      | 0.817        | 0.780        |
| SVM_radial | 0.800        | 0.768        |
| BAG        | 0.789        | 0.775        |
| KNN        | 0.788        | 0.720        |
| LASSO      | 0.786        | 0.742        |
| C50        | 0.779        | 0.756        |
| CART       | 0.667        | 0.622        |
| SVM_linear | 0.600        | 0.579        |

### Secondary (naive, single harmonization pass, batch-corrected for cohort)
Best model: RIDGE, median AUROC = 0.82 (MAD 0.15), median AUPRC = 0.77. Full table: `model/naive/AUROC_median_per_algorithm.csv`.

Both approaches converge on ~0.80-0.82 median AUROC, which is a reasonably strong, consistent signal given only 124 samples pooled across two different ICB cohorts/studies.

## Which TME features drive the prediction (SHAP, primary leakage-free RF model)

Mean |SHAP| ranks each feature's average contribution to the model's predicted response probability. Direction tendency is the Pearson correlation between each feature's raw abundance and its SHAP value across samples (RF is non-linear, so this is a tendency, not an exact linear coefficient). Full ranked list: `shap/leakagefree/SHAP_feature_importance.csv`.

| Rank | Feature | Mean \|SHAP\| | Tendency |
|---|---|---|---|
| 1 | DeconRNASeq_TIL10_Monocytes | 0.0306 | higher -> **NR** |
| 2 | DeconRNASeq_TIL10_Macrophages.M1 | 0.0235 | higher -> **R** |
| 3 | Endothelial_Subgroup.1 | 0.0195 | higher -> **NR** |
| 4 | DeconRNASeq_CBSX.HNSCC.scRNAseq_CD8.cells | 0.0189 | higher -> **R** |
| 5 | DeconRNASeq_TIL10_B.cells | 0.0158 | higher -> **R** |
| 6 | DeconRNASeq_TIL10_Macrophages.M2 | 0.0146 | higher -> **NR** |
| 7 | CD4.memory.activated_Subgroup.2 | 0.0129 | higher -> **R** |
| 8 | Macrophages.M2_Subgroup.2 | 0.0129 | higher -> **NR** |
| 9 | CD4.naive_Subgroup.1 | 0.0127 | higher -> **R** |
| 10 | DeconRNASeq_CBSX.HNSCC.scRNAseq_Endothelial | 0.0101 | higher -> **NR** |
| 11 | DeconRNASeq_LM22_CD4.naive | 0.0089 | higher -> **R** |
| 12 | CBSX_TIL10_CD8.cells | 0.0087 | higher -> **R** |
| 13 | CD4.cells_Subgroup.3 | 0.0086 | higher -> **R** |
| 14 | DeconRNASeq_CBSX.Zilionis.scRNAseq_NK.resting | 0.0084 | higher -> **R** |
| 15 | Quantiseq_TIL10_B.cells | 0.0082 | higher -> **R** |
| 16 | DeconRNASeq_TIL10_CD8.cells | 0.0079 | higher -> **R** |
| 17 | Macrophages.M1_Subgroup.2 | 0.0077 | higher -> **R** |
| 18 | DeconRNASeq_CBSX.Vanderbilt.scRNAseq_CD4.regulatory | 0.0072 | higher -> **R** |
| 19 | B.cells_Subgroup.1 | 0.0072 | higher -> **R** |
| 20 | Mast.activated.cells_Subgroup.1 | 0.0070 | higher -> **NR** |

**Biological summary**: the same pattern emerges in both the leakage-free and the naive model. CD8+ T-cell infiltration, M1-polarized (pro-inflammatory) macrophages, B cells, naive/activated CD4 T cells, and resting NK cells all push the model toward predicting **response**. Monocyte abundance, M2-polarized (immunosuppressive) macrophages, endothelial content, and activated mast cells push toward **non-response**. This matches the established "hot," CD8-infiltrated/M1-skewed vs. immunosuppressive/M2-skewed/stromal-rich TME dichotomy reported for checkpoint-blockade response.

## Reproducibility notes
- `deconvolution/merged_linear_TPM_input.csv`: pooled linear-TPM matrix (Gide + Riaz) fed to deconvolution.
- `model/sample_metadata.csv`: per-sample Response/Cohort/Therapy/Timing labels used for training (sample IDs made R-safe with a leading "X" where they started with a digit, to match multideconv's/R's row names).
- CIBERSORTx was run with user-supplied credentials (not stored in this results folder).
- The leakage-free `fold_construction_fun="prepare_multideconv_folds"` path does not support passing a batch covariate, so cohort-of-origin was not explicitly controlled for inside each fold's harmonization there; the secondary/naive run shows results are very similar with or without that batch correction.
