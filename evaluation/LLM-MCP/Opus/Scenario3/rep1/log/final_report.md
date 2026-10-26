I built a Random Forest that separates responders from non-responders well in leakage-free cross-validation on Gide, but it only weakly predicts response in Riaz. The CD8 T-cell and monocyte/macrophage features drive the predictions.

**Setup**
- **Input scale:** both files are log2(TPM+1). For deconvolution I converted them to linear TPM (2^x − 1) and rescaled each sample to sum to 1e6. That rescaling was needed because Gide's column sums ranged from 41k to 730k.
- **Deconvolution:** multideconv ran 5 methods (Quantiseq, EpiDISH, DeconRNASeq, DWLS, CIBERSORTx) with its built-in signatures, giving 375 cell-type estimates per sample.
- **Training:** on Gide (73 samples: 46 responders, 27 non-responders). The grouping of agreeing method estimates into cell-type subgroups was redone inside every cross-validation fold, so test samples never influenced their own features. I used 5 folds repeated 10 times and compared 11 algorithms.
- **Test:** Riaz (51 samples: 10 responders, 41 non-responders) was mapped onto the final model's subgroups and then scored.

**Performance**

| | AUROC | AUPRC |
|---|---|---|
| Gide, cross-validation (Random Forest, best of 11) | **0.81** (MAD 0.09) | 0.90 (chance level 0.63) |
| Riaz, external test | **0.61** (95% CI 0.42–0.81) | 0.26 (chance level 0.20) |

The Riaz confidence interval includes 0.5, so I can't claim the model works on an independent cohort. Likely reasons:
- Riaz has only 10 responders.
- Gide includes anti-PD1 plus anti-CTLA4 patients, while Riaz is anti-PD1 only.
- The cohorts were sequenced and processed differently.

The Gide estimate shows the composition signal is real within that cohort; it does not show that it carries over to other cohorts.

**Features driving the prediction** (SHAP values on the final model)
- **Pointing to response:**
  - CD8 T cells, both the CIBERSORTx/TIL10 estimate and the TIL10 subgroup where four methods agree. In Gide responders the median is about 0.03, versus about 0 in non-responders.
  - M1 macrophages: the LM22 subgroup (0.040 vs 0.005) and the TIL10 subgroup.
- **Pointing to non-response:**
  - Monocytes are the single strongest feature (median 0.03 in responders vs 0.13 in non-responders).
  - M2 macrophages (0.18 vs 0.27).
  - Resting mast cells, memory B cells, and the cancer-cell fraction.

Overall, a cytotoxic, M1-polarized immune environment goes with response, and a monocyte/M2-dominated or tumour-dominated one goes with non-response. This fits what is known about checkpoint-inhibitor response in melanoma. SHAP describes how the model uses features on its own training data, so these drivers come from Gide; given the weak Riaz result, I wouldn't assume they generalize.

**Things to know**
- The first deconvolution attempt was killed for lack of memory (15 GB machine). I reran it one cohort at a time with 4 parallel workers instead of 19.
- The deconvolution tool wrote your CIBERSORTx token in plain text into `results/01_deconvolution/{Gide,Riaz}/manifest.json`. I replaced it with `***REDACTED***` there; your `CBSX_credentials` file is unchanged.
- The Riaz deconvolution session couldn't be exported as a log bundle, because the tool requires a standalone harmonization step that this design skips for the test cohort. All its outputs are still in `results/`.

**Saved in `results/`** (`README.md` explains every folder):
- `03_model_training_Gide/`: trained model, per-algorithm cross-validation tables and plots.
- `04_external_test_Riaz/prediction/`: Riaz predictions, metrics, ROC/PRC curves.
- `05_SHAP_feature_importance/`: raw SHAP values.
- `06_feature_drivers_summary/`: ranked features with direction and subgroup members, plus importance and beeswarm plots.
- `07_session_logs/`: reproducibility logs.
- `scripts/summarize_shap.R`: regenerates the feature summary.

To strengthen this, the clearest next step is to pool more cohorts from `colData_all.txt` (Hugo, Liu, MGH, Van Allen) and validate with leave-one-cohort-out. I can set that up if you share their expression files.