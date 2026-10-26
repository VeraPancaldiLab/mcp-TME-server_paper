I built the model, but it predicts response well only in the cohort it was trained on. Trained on Gide, it reaches a cross-validated AUROC of 0.80. On Riaz, which it never saw, the AUROC is **0.59 (95% CI 0.40–0.78)**. Because that range includes 0.5, the model does not predict better than chance on new patients.

**How it was built**
- **Cohorts:** Gide (73 patients, 46 responders) was used for training; Riaz (51 patients, 10 responders) was kept aside as an independent test.
- **Cell composition (multideconv):** I estimated cell fractions with Quantiseq, EpiDISH, DeconRNASeq and DWLS against all the bundled reference signatures, giving 284 features. CIBERSORTx was skipped because it needs login credentials.
- **Cell groups:** similar estimates from different methods are merged into cell groups. This was done separately inside each cross-validation fold, so the held-out samples never influenced the features. Riaz was mapped onto the groups learned from Gide.
- **Model (pipeML):** 11 algorithms, 5-fold cross-validation repeated 10 times. Random forest won on AUROC.

**Results**

| | AUROC | AUPRC |
|---|---|---|
| Gide, cross-validation (random forest) | 0.80 | 0.88 |
| **Riaz, independent test** | **0.59 (0.40–0.78)** | 0.23 (Riaz responder rate is 0.20) |

The other ten algorithms also scored between 0.33 and 0.65 on Riaz. The 0.80 is optimistic because it is the best of 11 models on 73 samples. On Riaz the predicted probabilities sit around 0.5 for both groups (median 0.48 for non-responders, 0.54 for responders). The two cohorts differ a lot: responder rate 63% vs 20%, and Gide includes patients on combined ipi + anti-PD1.

**Features driving the prediction** (SHAP values from the random forest model)
- **Higher in responders:** CD8 T cells (two groups, consistent across several methods), M1 macrophages, activated CD4 memory T cells and B cells.
- **Higher in non-responders:** monocytes (the single most important feature), M2 macrophages, the cancer-cell fraction, resting mast cells and M0 macrophages.
- **Replication in Riaz:** 16 of the 17 features that differed significantly in Gide (FDR < 0.05) point the same way in Riaz. These features are correlated, so this is not 16 independent confirmations. None is significant in Riaz after correction. Only cancer fraction, resting mast cells and one monocyte group reach p < 0.05 there, all higher in non-responders.

So the pattern is consistent across cohorts (CD8 T cells and M1 macrophages with response; monocytes, M2 macrophages and tumour content with non-response), but in Riaz its effect is too weak to support individual predictions.

**Things to know**
- To run the methods correctly I converted the log2 values back to linear TPM. I also rescaled each sample to sum to 1e6, because Gide samples summed to about 0.5M against 0.94M for Riaz.
- Gide sample `8_PD1_PRE` looks low quality (4,634 expressed genes against a median of about 12,200). I kept it in.
- Riaz has only 10 responders, which is why its confidence intervals are so wide.
- multideconv added an `X` to Gide sample names that start with a digit. I fixed this in the script and in the saved outputs.
- multideconv and pipeML save their plots to a folder named `Results/`. I renamed it to `results/pipeML_plots/`. Re-running the scripts will create a new `results/Results/` folder.

A natural next step would be to train on Riaz and test on Gide, to see whether the poor transfer depends on which cohort is used for training.

Everything is in `results/`, and `results/README.md` covers the design, results and caveats. The scripts are in `scripts/`; run them from the project root. Main files:
- `results/model/Summary_selected_model.csv`
- `results/interpretation/Feature_importance_SHAP.csv`
- `results/interpretation/SHAP_beeswarm.pdf`
- `results/pipeML_plots/ROC_curve_Riaz_test.pdf`