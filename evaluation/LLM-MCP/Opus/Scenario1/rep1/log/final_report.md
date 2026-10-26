## Gide cohort: immune and stromal composition

**The patients with the most immune infiltration are 20_ipiPD1_PRE, 13_ipiPD1_PRE, 7_PD1_PRE, 6_PD1_PRE, 37_ipiPD1_PRE, 45_PD1_PRE, 40_PD1_PRE, 44_PD1_PRE, 48_PD1_PRE and 53_PD1_PRE.** These are the top 10 of 24 patients I classed as immune-high (the top third). The full ranked list is in `results/04_immune_stromal_summary/patient_immune_stromal_scores.csv`.

**How I got there:**
- **Scale:** your file holds log2(TPM+1) values, so I converted them back to linear TPM before deconvolution.
- **Deconvolution:** all 5 methods ran (Quantiseq, EpiDISH, DeconRNASeq, DWLS, CIBERSORTx), giving 29 method–reference combinations. Before merging, I added total Immune, Lymphocyte, Myeloid and Stromal sums for each combination. Merging estimates that agree across methods left 222 cell-type features.
- **Immune score:** I combined 4 independent total-immune estimates by averaging each patient's rank within the cohort. The estimates agree moderately (Spearman 0.40–0.75), and their absolute levels differ between references, which is why I used ranks.
- **Stromal score:** built the same way from fibroblasts/CAFs, endothelial and mural cells.
- **Classes:** patients are split into thirds by immune score. A second classification combines immune and stromal scores, each split at the median.

**Immune and stromal content**

| Immune class | n | Median immune fraction | Responder / non-responder |
|---|---|---|---|
| Immune-high | 24 | 54% | 22 / 2 |
| Immune-intermediate | 23 | 37% | 12 / 11 |
| Immune-low | 26 | 22% | 12 / 14 |

- **Immune and stromal content move in opposite directions** (Spearman ρ = −0.61, p < 1e-8). Immune-high tumours contain CD8 and CD4 T cells, NK cells and macrophages. Immune-low tumours are mostly cancer cells and CAFs.
- **Tumour content:** the melanoma-specific reference puts the median tumour-cell fraction at 59%.
- **Immune-high with low stroma** is the class most enriched for responders: 21 of 24 responded (Fisher p = 0.018 across the four classes).

**Relation to response.** These are exploratory comparisons by Wilcoxon test, with Benjamini–Hochberg (BH) adjusted p-values:
- **CD8 T cells** separate responders from non-responders most clearly (adjusted p = 1e-4).
- **Total immune:** adjusted p = 0.019.
- **Lymphocytes:** adjusted p = 0.034.
- **Stromal, CAF and myeloid** scores are not significantly different.
- **Immune class against response:** Fisher p = 8e-4.
- **Therapy arm:** no compartment differs between PD1 and ipi+PD1 after correction.

**Things to be aware of:**
- **Outliers:** two non-responders, 7_PD1_PRE and 6_PD1_PRE, are among the most infiltrated tumours. A high immune fraction does not always mean an active immune response. Looking at the regulatory state of those cells, for example with CellTFusion, could explain these cases if you want to go further.
- **Low-total sample:** 8_PD1_PRE has a much lower total expression than the other samples. I kept it but flagged it in the score table. It ranks among the least infiltrated.
- **Cancer score:** I based it only on the melanoma reference. The HNSCC and Vanderbilt references model non-melanoma tumour cells and estimate almost none in these samples.
- **Credentials:** your CIBERSORTx token is stored in plain text in `results/01_deconvolution/manifest.json`. It is masked in the exported session log. I can remove it from the manifest if you plan to share the folder.

Everything is in `results/`, with a `README.md` describing each part:
- `input/`
- `01_deconvolution/`
- `02_aggregated_groups/`
- `03_harmonized_subgroups/`
- `04_immune_stromal_summary/` (scores, tests and figures)
- `scripts/`
- `session_export/` (session log)