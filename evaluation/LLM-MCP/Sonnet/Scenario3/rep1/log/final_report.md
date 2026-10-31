The analysis is complete. Summary:

**Pipeline:** multideconv (deconvolution + harmonization) → pipeML (leakage-free training with `prepare_multideconv_folds`, prediction, SHAP) on TME cell-composition features, train=Gide (73 samples), test=Riaz (51 samples).

**Model:** XGBoost selected by cross-validated AUROC on Gide (0.833, MAD 0.124). On held-out Riaz: **AUROC = 0.654** (95% CI 0.46–0.85), AUPRC = 0.296.

**Top drivers (SHAP):** Monocyte abundance (strongest single driver, pushes toward non-response) and CD8 T-cell / M1 macrophage / activated dendritic cell / activated CD4 memory T-cell abundance (push toward response) — a classic immune-active-vs-suppressed TME axis.

All intermediate and final outputs (deconvolution matrices, trained model, CV curves, test-set ROC/PRC curves, SHAP values, full feature-importance ranking) are saved under `results/`, with a `SUMMARY.md` describing each step and file. Note Riaz's response rate (10 R/41 NR) differs substantially from Gide's (46 R/27 NR), which likely explains much of the drop from training to test performance.