CellTFusion found two TME states in the Gide cohort, and one of them is clearly linked to response. Factor 2, an immune-active, interferon-driven state, is higher in responders (Wilcoxon p = 0.002, FDR = 0.004). Factor 1, a myeloid/stromal state, does not differ between responders and non-responders (p = 0.19).

**How the run went**
- CellTFusion ran on all 73 samples with the default settings, including all five deconvolution methods (CIBERSORTx used your credentials).
- It received linear TPM, converted back from your log2 values. TF and pathway activity were computed on log2(TPM + 1).
- It produced 13 co-active TF modules and 154 cell groups (sets of cell types tied to a TF module).
- The automatic step that chooses how many TME states to keep (NMF with bootstrap) picked 2. Both are stable (93% and 100% recovery). No higher number gave states that were both stable and distinct.

**The two TME states**

| | Factor 1: myeloid / stromal | Factor 2: immune-active / interferon |
|---|---|---|
| Main TF modules | black (CEBPA/B, HIF1A, NR3C1, TP53), yellow, magenta, blue | green (STAT1/2/4, IRF1/7/8/9, TBX21, EOMES, CIITA, RUNX3, NFKB, FOXP3, PRDM1) and greenyellow (ETS1, STAT6, FLI1) |
| Main cell types | Monocytes, mast cells, plasma cells, endothelial cells, resting dendritic cells, cancer cells | CD8 and CD4 T cells, B cells, regulatory T cells, M1 macrophages, myeloid cells |
| Pathway activity (Spearman ρ) | Hypoxia 0.56, TGFβ 0.54 | JAK-STAT 0.82, NFκB 0.80, TNFα 0.75 |
| Responders vs non-responders | p = 0.19, not different | Higher in responders, p = 0.002 (FDR 0.004) |

The pathway correlations were a quick check to help interpret the states; I didn't save them as an output.

**Individual cell groups**
- 54 of the 154 cell groups differ at nominal p < 0.05, and 33 pass FDR < 0.05.
- All 33 are higher in responders. They come mostly from the green (17) and greenyellow (7) modules, plus purple (AP-1/STAT3, 5), black (2) and magenta (2).
- These groups overlap heavily, so they largely repeat the Factor 2 signal rather than adding independent findings.

**Limitations**
- **Therapy confounding:** therapy is unevenly split between responders and non-responders, and I did not adjust for it. Part of the Factor 2 link could come from therapy.
- **Not validated:** the states were found and tested in the same 73 samples, so this is a finding from this cohort only.
- **Credentials:** CellTFusion wrote your CIBERSORTx token in plain text into `results/celltfusion/manifest.json`. I removed it there and checked that it appears nowhere else in `results/`.

If you'd like, I can next re-test Factor 2 within each therapy arm, or check it in the Riaz cohort in `data/` using the same cell groups.

Everything is in `results/`; `README.md` describes each part. The files to open first are:
- `celltfusion/Latent_factors_Z.csv`
- `celltfusion/result_Cells_niches.csv`
- `celltfusion/Results/Cells_niches_heatmap_Gide.pdf`
- `response_association/Latent_factors_vs_Response_stats.csv`
- `response_association/Cell_groups_vs_Response_stats.csv`