Analysis complete. Summary:

**Pipeline**: Converted `Gide_log2TPM.txt` back to linear TPM, filtered `colData_all.txt` to the 73 Gide samples (46 R / 27 NR, all pre-treatment), then ran CellTFusion's full pipeline (deconvolution with CBSX + Quantiseq/EpiDISH/DeconRNASeq/DWLS → TF activity → WGCNA TF co-activity modules → cell groups → NMF latent factors).

**TME states found**: CellTFusion identified **4 robust recurring TME programs** (NMF latent factors, chosen via bootstrap stability across ranks 2–15).

**Response association**: Of the 4 states, **Factor1** — an immune-enriched program driven by Tregs, B cells, NKT/activated NK cells, M1 macrophages, and CD4 helper T cells — is significantly elevated in responders vs non-responders (Wilcoxon p=2.4e-4, BH-adj p=9.6e-4; t-test p=1.3e-3, BH-adj p=5.1e-3). Factors 2–4 showed no significant association.

All outputs are in `results/`:
- `results/CellTFusion/` — full CellTFusion output (deconvolution, TF activity, pathway activity, cell groups, latent factors, diagnostic PDFs)
- `results/Response_association/` — statistical test outputs and plots
- `results/README.md` — summary of the analysis and findings