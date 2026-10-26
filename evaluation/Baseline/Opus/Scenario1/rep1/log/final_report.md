I ran multideconv on all 73 Gide pre-treatment samples and ranked the patients by immune infiltration. About a third of the cohort is clearly immune-infiltrated, and that group is mostly made up of responders. Everything is in `results/`, with a `README.md` that explains each file.

## How it was run
- **Input:** I converted the log2 TPM values back to linear TPM and ran `compute.deconvolution(normalized = FALSE)`. Despite its name, `normalized = TRUE` would re-normalise the data as if it were raw counts.
- **Methods:** quanTIseq, DeconRNASeq, EpiDISH and DWLS, each with all 7 signatures bundled with the package, giving 284 features. CIBERSORTx was skipped because it needs login credentials you hadn't provided.
- **Post-processing:** `compute.deconvolution.analysis(corr = 0.7)` filtered the features and grouped correlated ones. I averaged them into a consensus score for each of 38 cell types.
- **Infiltration ranking:** I only used the 10 method/signature combinations that also estimate tumour and stromal cells, because they give absolute immune fractions. Signatures like LM22 only describe proportions within the immune cells, so they can't say how infiltrated a sample is. The consensus immune score is the average across those 10. Patients were split into thirds: Immune-high, intermediate and low.

## Checks on the consensus score
- The methods mostly agree with each other (Spearman ρ 0.4–0.99).
- The immune score tracks marker genes measured directly from the expression data: the pan-immune marker PTPRC (ρ = 0.78) and cytolytic activity from GZMA and PRF1 (ρ = 0.72).
- quanTIseq on its own calls 6_PD1_PRE and 36_PD1_PRE 100% immune, which is implausible. This is the main reason I used a consensus rather than any single method.

## Which patients are more infiltrated
| Group | Median immune fraction | Median stromal fraction | R / NR |
|---|---|---|---|
| **Immune-high (24)** | 0.54 | 0.31 | **21 / 3** |
| Immune-intermediate (25) | 0.38 | 0.37 | 15 / 10 |
| Immune-low (24) | 0.27 | 0.49 | 10 / 14 |

- **Immune-high:** 20_ipiPD1, 13_ipiPD1, 37_ipiPD1, 7_PD1, 45_PD1, 6_PD1, 53_PD1, 32_ipiPD1, 40_PD1, 44_PD1, 38_PD1, 21_ipiPD1, 48_PD1, 47_PD1, 27_ipiPD1, 54_PD1, 36_PD1, 26_ipiPD1, 46_ipiPD1, 47_ipiPD1, 34_PD1, 21_PD1, 24_ipiPD1, 36_ipiPD1 (all `_PRE`).
- **Least infiltrated:** 42_PD1, 45_ipiPD1, 3_PD1, 13_PD1, 16_PD1, 17_ipiPD1 and 25_ipiPD1. These have higher stromal (CAF/endothelial) content.
- Infiltration is not tied to treatment arm: each third has a similar mix of PD1 and ipi+PD1 patients.
- **Link with response:** the thirds differ in response rate (Fisher p = 0.003). Responders have more CD8 T cells (FDR = 0.004), M1 macrophages (FDR = 0.016) and a higher overall immune score (FDR = 0.04). Non-responders have relatively more mast cells and monocytes.

## Caveats
- **Absolute fractions:** these depend on the signature. Tumour content looks low and stroma high for melanoma, so trust the patient ranking more than the exact percentages.
- **Biopsy site:** this isn't in the clinical file. The most infiltrated sample, 20_ipiPD1_PRE (about 2% tumour), may be a lymph-node biopsy rather than truly "hot".
- **Fine subsets:** Tregs, M2 macrophages and the NK and mast cell subtypes agree poorly between methods, so treat them as exploratory. Agreement is best for CD8 T cells, macrophages and CAFs.

## Where to look in `results/`
- **Main table:** `patient_immune_infiltration_ranking.csv`
- **Per cell type:** `celltype_consensus_scores_zscore.csv`
- **Figures:** `figures/`, including the heatmap, ranking barplot, compartment bars and response boxplots
- **Scripts:** `scripts/01_deconvolution.R` and `scripts/02_tme_analysis.R`