I ran multideconv on all 73 Gide pre-treatment samples. The most immune-infiltrated patients are 20_ipiPD1, 13_ipiPD1, 7_PD1, 37_ipiPD1, 6_PD1, 45_PD1, 32_ipiPD1 and 53_PD1. Everything is saved in `results/`, with a write-up in `results/README.md`.

**Setup.** I converted the log2TPM values back to TPM and ran four methods (quanTIseq, DeconRNASeq, EpiDISH, DWLS) with the 7 signatures that ship with the package. That gives 284 estimates per sample. multideconv then merged estimates that agree with each other into 158 features covering 38 cell types. CIBERSORTx was skipped because it needs login credentials.

**How I measured infiltration.** I used the share of each sample made up of immune cells, taking the median across the 10 estimates that model the whole tissue. I checked it against plain expression of immune genes, which doesn't depend on deconvolution: it tracks PTPRC (ρ = 0.78), T-cell genes (0.78) and an interferon-gamma signature (0.69).

**Which patients are more infiltrated**

| Group | Patients |
|---|---|
| Inflamed, with strong CD8 T-cell signal | 13_ipiPD1, 53_PD1, 45_PD1, 37_ipiPD1, 32_ipiPD1, 48_PD1 |
| Highly infiltrated but lymph-node-like (B cells and naive CD4 T cells, lymph-node genes) | 20_ipiPD1, 6_PD1 |
| Least infiltrated (immune share below 0.2) | 13_PD1, 5_PD1, 1_ipiPD1, 42_PD1, 45_ipiPD1, 16_PD1 |

20_ipiPD1 has almost no melanoma gene expression, so it is probably a lymph node rather than an inflamed tumor. I've flagged it, along with 6_PD1, 44_PD1, and 8_PD1, which has very low expression content. The full ranking is in `patient_immune_stromal_scores.csv` and `figures/immune_fraction_ranking.pdf`.

**Link to response** (exploratory):
- **By infiltration level:** 83% of the most-infiltrated third responded, against 40% of the least-infiltrated third (Fisher p = 0.007).
- **CD8 T cells:** the strongest single signal, separating responders from non-responders with AUC 0.80 (FDR 7×10⁻⁴).
- **Non-response:** higher mast cell, monocyte and mural-cell scores lean towards non-response, but these are only nominally significant.
- **Robustness:** the results hold when the flagged samples are excluded.

**Decisions that affect the numbers:**
- **Cancer and stromal shares come from the melanoma signature only.** It is the only one with a melanoma tumor reference. The head-and-neck and lung signatures assign almost nothing to tumor in these samples, so I left them out for these two compartments.
- **The stromal share is the weakest result.** The melanoma signature's "CAF" (cancer-associated fibroblast) estimate follows tumor dedifferentiation genes (AXL/WNT5A/NGFR, ρ = 0.67) more than fibroblast genes (ρ = 0.56). Some mesenchymal-like tumor cells are therefore being counted as stroma. For stroma, use the consensus fibroblast score instead (ρ = 0.72 with fibroblast genes). The endothelial estimate does not match endothelial genes.
- **Infiltration ranking uses the immune share, not the composite immune score.** The composite score (also in the tables) mostly reflects which immune cell types are present rather than how many, so it is a weaker measure.
- **One more limitation.** I couldn't adjust for therapy arm or biopsy site; site isn't in the clinical file.

Files are in `results/`:
- `README.md`
- `patient_immune_stromal_scores.csv` (main per-patient table)
- `Results/` (multideconv's own output files)
- `figures/` (8 PDFs)

The two scripts that reproduce everything are in `scripts/`.