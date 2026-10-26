Both sessions completed successfully and are export-ready. Here's a summary of what was done:

**Pipeline**: pooled Gide (73 samples) + Riaz (51 samples) ICB cohorts → converted log2(TPM+1) back to linear TPM → `multideconv` deconvolution (5 methods incl. CIBERSORTx) → `pipeML` classification of Response (R vs NR), using `fold_construction_fun="prepare_multideconv_folds"` so the harmonization of cell-type estimates into robust subgroups is recomputed fresh inside every CV fold (no leakage) → SHAP for feature importance.

**Performance**: best model (Random Forest) reaches median AUROC ≈ 0.82 / AUPRC ≈ 0.79 under leakage-free 10-fold×5-repeat CV — consistent with a secondary, simpler run.

**Top drivers of response** (SHAP): higher CD8+ T-cell, M1 macrophage, B-cell and naive/activated CD4 T-cell infiltration push toward predicted **response**; higher monocyte, M2 macrophage, endothelial, and activated mast-cell content push toward **non-response** — the classic "hot/CD8-inflamed" vs. "immunosuppressive/M2-stromal" TME dichotomy.

All results (deconvolution matrices, trained models, performance tables/plots, SHAP tables, and a `README.md` write-up) are saved under `results/` (deconvolution/, model/{leakagefree,naive}/, shap/{leakagefree,naive}/).