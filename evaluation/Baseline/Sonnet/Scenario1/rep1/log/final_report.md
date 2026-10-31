The analysis is complete. Here's a summary:

## What was done

Using `multideconv` on the 73 Gide melanoma ICB samples (log2TPM reversed to linear TPM):
- Ran 4 first-generation deconvolution methods (Quantiseq, EpiDISH, DeconRNASeq, DWLS) across all bundled signatures (TIL10, LM22, 5× CBSX scRNA-seq references) — CBSX itself was skipped (no CIBERSORTx credentials/Docker) and MOMF was skipped (no scRNA-seq reference available)
- `compute.deconvolution.analysis()` collapsed the ~250 raw method-signature-celltype features into correlation-based subgroups per cell type (Spearman ≥ 0.7)
- Classified each of the 39 recovered cell types as **Immune** (31 types: T/B/NK/myeloid lineages) or **Stromal** (6 types: Fibroblasts, CAF, Endothelial, Pericytes, Mural, Myocytes), with Cancer/Epithelial kept as "Other"
- Built a composite **Immune Score** and **Stromal Score** per patient (two-level z-scoring: subgroups → cell type → category average, so no single cell type or method dominates)

## Key results (`results/`)
- `Immune_Stromal_scores_Gide.csv` — full ranked table, most → least immune-infiltrated. Top: `20_ipiPD1_PRE`, `27_PD1_PRE`, `6_PD1_PRE`; bottom: `17_ipiPD1_PRE`, `23_PD1_PRE`, `45_ipiPD1_PRE`
- `Immune_score_ranking_Gide.png/pdf` — all 73 patients ranked, colored by response
- `Heatmap_celltypes_Gide.png/pdf` — full cell-type composition heatmap
- `Immune_vs_Stromal_scatter_Gide.png/pdf` and `Immune_Stromal_by_Response_Gide.png/pdf` — composition vs. ICB response (R/NR)
- `Deconvolution_Gide.csv`, `Deconvolution_after_subgrouping_Gide.csv`, `Cell_subgroups_Gide.csv`, `Feature_cell_type_annotation_Gide.csv` — full intermediate deconvolution outputs
- `analysis_log_Gide.txt` — run parameters for reproducibility

Note: immune/stromal scores did not differ significantly by response in this cohort (Wilcoxon p = 0.38 immune, p = 0.08 stromal) — a trend toward lower stromal content in responders, but not significant at this sample size.

Two bugs in the wrapper script were caught and fixed along the way (sample-ID mangling from `data.frame()`'s `check.names`, and ungrouped features keeping raw column names) — both documented in a memory note for future runs.