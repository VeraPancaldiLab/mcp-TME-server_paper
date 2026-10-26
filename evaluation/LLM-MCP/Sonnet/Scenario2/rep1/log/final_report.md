## Summary

I ran CellTFusion on the Gide melanoma cohort (73 pre-treatment samples, converted from log2(TPM+1) back to linear TPM) using deconvolution (Quantiseq/EpiDISH/DeconRNASeq/DWLS/CIBERSORTx), TF activity (CollecTRI), and PROGENy pathways, then let it build 138 cell-type×TF-module "cell groups" and summarize them into 4 NMF latent factors — the TME states.

**Key finding:** one of the 4 TME states, **Factor1**, is significantly higher in immunotherapy responders than non-responders (Wilcoxon p = 2.4e-4, BH-adjusted p = 0.009). It reflects an immune-active TME (elevated B cells, CD4/CD8 T cells, NK cells, plasma cells co-activated with their TF modules, with lower M1/M2 macrophage/monocyte content). 34 of the 138 individual cell groups remain significant after multiple-testing correction, nearly all from the same lymphocyte-rich program underlying Factor1 — a coherent signal rather than noise. The other 3 TME states showed no association with response (p > 0.4).

Everything is saved under `results/`:
- `CellTFusion/` — full pipeline output (deconvolution, TF activity, pathways, cell groups, NMF factors, cell niches, diagnostic plots)
- `response_association/` — Wilcoxon results (raw + BH-adjusted p-values) and boxplots for every TME feature vs. Response
- `inputs/` — the linear-TPM matrix and clinical subset actually used
- `README.md` — full write-up of the methodology and findings