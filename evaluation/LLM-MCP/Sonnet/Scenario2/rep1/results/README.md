# TME state analysis — Gide cohort (immunotherapy)

## Input
- Expression: `data/Gide_log2TPM.txt` (log2(TPM+1), 73 pre-treatment samples), converted back
  to linear TPM (`prep/Gide_linTPM.csv`) for CellTFusion's internal deconvolution step.
- Clinical: `data/colData_all.txt` filtered to Cohort == "Gide" (`prep/Gide_coldata.csv`):
  73 samples, all Timing = "Pre", Response = 46 R / 27 NR, Therapy = PD1 or CTLA4+PD1.

## Pipeline: CellTFusion (`results/CellTFusion/`)
`run_celltfusion` on linear TPM (deconv_methods: Quantiseq, EpiDISH, DeconRNASeq, DWLS, CBSX;
tf_collection: CollecTRI; method: ulm/consensus defaults). Produced:
- `result_Deconvolution.csv` — 73 x 375 raw cell-type proportions (multiple methods/signatures)
- `result_TFs_matrix.csv` — 73 x 769 TF activity scores
- `result_Pathways_scores.csv` — 73 x 14 PROGENy pathway activity
- `Results/TF_module_matrix_Gide.csv` — WGCNA TF co-activity modules
- `Results/Cell.groups.scores_Gide.csv` — cell-type x TF-module "cell group" scores
- `result_Cells_niches.csv` — composition of each NMF latent factor (top cell groups/features)
- `TME_latent_factors_Gide.csv` — **the 4 TME states**: per-sample NMF latent factor scores
  (Factor1–Factor4), extracted from `result.rds$Latent_spaces$Z`. NMF rank (4) was chosen
  automatically via bootstrap stability (100 runs/rank, ranks 2–15): largest rank with all
  factors robust and none redundant.
- `Results/*.pdf` — QC/diagnostic plots (WGCNA dendrograms, soft-threshold, NMF rank stability,
  NMF patient mixture, cell niches heatmap).

## TME states identified
4 recurring TME programs (latent factors), each a combination of cell-type abundance and
co-regulated TF activity (see `result_Cells_niches.csv` for full composition):
- **Factor1**: driven by Tregs, B cells, NKT cells, activated NK cells, M1 macrophages, CD4
  helper T cells — an immune-enriched/lymphocyte-active TME program.
- Factor2, Factor3, Factor4: other recurring cell-group combinations (see
  `result_Cells_niches.csv` / `Results/Cells_niches_Gide.pdf`).

## Association with immunotherapy response (`results/Response_association/`)
Tested each TME latent factor against Response (R vs NR) with Wilcoxon rank-sum (primary,
scores are non-negative/zero-inflated) and Welch's t-test (confirmatory); see
`TME_factors_vs_Response_stats.csv`.

| Factor  | median R | median NR | Wilcoxon p | BH-adj p | t-test p | BH-adj p |
|---------|----------|-----------|------------|----------|----------|----------|
| Factor1 | 0.0113   | 0.000     | 2.4e-04    | 9.6e-04  | 1.3e-03  | 5.1e-03  |
| Factor2 | 0.0063   | 0.0017    | 0.45       | 0.89     | 0.75     | 0.75     |
| Factor3 | 0.0124   | 0.0108    | 0.81       | 0.98     | 0.65     | 0.75     |
| Factor4 | 0.0012   | 0.000     | 0.98       | 0.98     | 0.38     | 0.75     |

**Conclusion**: Factor1 — the immune-enriched TME program (Tregs, B cells, NKT/activated NK
cells, M1 macrophages, CD4 helper cells) — is significantly higher in responders (R) than
non-responders (NR), surviving multiple-testing correction (BH-adjusted p < 0.01 by both tests).
Factors 2–4 show no significant association with response.
