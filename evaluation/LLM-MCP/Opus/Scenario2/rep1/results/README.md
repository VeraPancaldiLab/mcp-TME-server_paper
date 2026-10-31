# Gide cohort — CellTFusion TME states and immunotherapy response

73 pre-treatment melanoma samples (46 R / 27 NR; PD1 n=41, CTLA4+PD1 n=32).

## Inputs (`inputs/`)
- `Gide_TPM_linear.csv` — `data/Gide_log2TPM.txt` back-transformed to linear TPM (2^x - 1); CellTFusion run with `normalized=False` (linear TPM for deconvolution, log2(TPM+1) internally for TF/pathway activity).
- `Gide_coldata.csv` — Gide rows of `data/colData_all.txt`, in expression-column order.

## CellTFusion (`celltfusion/`)
Default settings: deconvolution with Quantiseq, EpiDISH, DeconRNASeq, DWLS, CIBERSORTx; CollecTRI TFs (ulm); WGCNA TF modules; PROGENy; NMF.
- `result.rds` — full result; `result_*.csv` — deconvolution, TF activity, pathway scores, cell niches.
- `Latent_factors_Z.csv` — sample x factor scores (TME states; bootstrap NMF selected rank 2, both factors robust).
- `Cell_group_scores.csv` — sample x cell group scores (154 cell groups from 13 TF modules).
- `Results/` — TF modules (`TFs_modules_Gide.csv`), cell-group composition, niche plots, NMF rank stability, etc.

## Response association (`response_association/`)
Wilcoxon rank-sum, R vs NR; BH-FDR computed by `scripts/response_stats.R`.
- `Latent_factors_vs_Response_stats.csv`, `Cell_groups_vs_Response_stats.csv` — full tables (medians, direction, p, FDR).
- `latent_factors/Results/`, `cell_groups/Results/` — boxplots (cell groups: nominal p < 0.05 only).

## Logs
`session_logs/` — reproducibility logs (every tool call with parameters). The CIBERSORTx token was redacted from `celltfusion/manifest.json`.
