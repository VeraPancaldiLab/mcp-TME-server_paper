# Gide cohort – immune & stromal composition (multideconv)

73 pre-treatment melanoma samples (anti-PD1 n=44, ipi+PD1 n=29; R=46, NR=27).

## Input handling
- `data/Gide_log2TPM.txt` holds log2(TPM+1) (range 0–14, non-negative, non-integer). Deconvolution needs linear TPM,
  so it was back-transformed (2^x − 1) → `input/Gide_TPM_linear.csv`, passed to `run_deconvolution(normalized=FALSE)`.
- Clinical annotation (Gide rows of `colData_all.txt`) → `input/Gide_coldata.csv`.
- QC: `8_PD1_PRE` has a much lower TPM total (~41k vs ~510k median) – kept, flagged in the score table.

## Steps
| Folder | Tool | What |
|---|---|---|
| `01_deconvolution/` | multideconv `run_deconvolution` | Quantiseq, EpiDISH, DeconRNASeq, DWLS, CIBERSORTx × all bundled signatures → 29 method-signature combinations, 375 features |
| `02_aggregated_groups/` | `aggregate_cell_groups` | added Immune, Lymphocytes, Myeloid.cells, Stromal sums per combination |
| `03_harmonized_subgroups/` | `analyze_deconvolution` (corr 0.7, Spearman) | cross-method consensus subgroups → 222 features (`result_Deconvolution.matrix.csv`) |
| `04_immune_stromal_summary/` | `scripts/04_immune_stromal_summary.R` | compartment scores, patient classes, clinical association, figures |

## Scores (04_immune_stromal_summary)
- **Consensus score** per compartment = mean within-cohort percentile across the harmonized features of that compartment
  (definitions in `compartment_feature_definitions.txt`). Total-immune and stromal scores only use references that also model
  non-immune cells (quanTIseq, CBSX HNSCC / Melanoma / Vanderbilt scRNAseq signatures). `*_fraction` = median absolute estimate.
- Cancer score uses only the melanoma scRNAseq reference (HNSCC/Vanderbilt tumour profiles are non-melanocytic, ~0 here).
- **Immune_class**: tertiles of the immune score. **TME_class**: median splits of immune × stromal score.

## Key files
- `patient_immune_stromal_scores.csv` – per-patient scores, rank, classes, QC flag (sorted most → least infiltrated)
- `compartment_scores_vs_clinical_wilcoxon.csv`, `immune_class_vs_response.txt`, `all_harmonized_features_vs_response_wilcoxon.csv`
- Figures: `immune_score_ranked.pdf`, `compartment_composition_stacked.pdf`, `immune_vs_stromal_scatter.pdf`,
  `compartment_scores_by_response.pdf`, `harmonized_features_heatmap.pdf`
- `session_export/` – multideconv session reproducibility log
