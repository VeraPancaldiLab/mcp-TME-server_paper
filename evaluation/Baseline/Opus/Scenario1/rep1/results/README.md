# Gide cohort – immune and stromal TME characterisation (multideconv)

73 pre-treatment melanoma biopsies (anti-PD1 n = 40, anti-PD1 + anti-CTLA4 n = 33; R = 46, NR = 27).
Scripts: `scripts/01_deconvolution.R`, `scripts/02_tme_analysis.R` (logs: `01_deconvolution.log`, `02_tme_analysis.log`).

## Methods
1. **Input**: log2(TPM+1) back-transformed to TPM, passed to `compute.deconvolution(normalized = FALSE)`.
2. **Deconvolution** (multideconv 0.2.0): quanTIseq + DeconRNASeq, EpiDISH and DWLS × the 7 packaged signatures
   (LM22, TIL10, CBSX-Melanoma, CBSX-HNSCC, CBSX-Vanderbilt, CBSX-NSCLC-PBMCs, CBSX-Zilionis) → 284 features.
   CIBERSORTx was skipped because no credentials were available.
   DWLS ran sequentially because parallel DWLS ran out of memory.
3. **Subgrouping**: `compute.deconvolution.analysis(corr = 0.7, spearman)`. Features of the same cell type that all
   correlate ≥ 0.7 are merged (median) → 158 features covering 38 cell types; 37 features were dropped for >90 % zeros.
4. **Consensus cell type scores**: features are z-scored, then averaged per cell type, weighting each by the number of method–signature estimates behind it.
5. **Compartment fractions** (absolute, 0–1):
   - *Immune fraction* = median over the 10 whole-tissue estimates (3 methods × CBSX-Melanoma/HNSCC/Vanderbilt + quanTIseq).
     This is the **primary infiltration metric**. It matches immune marker expression best (PTPRC ρ = 0.78, CD3 ρ = 0.78, IFNG signature ρ = 0.69).
   - *Cancer* / *stromal fraction* = median over CBSX-Melanoma × 3 methods only. This is the only signature with a melanoma
     malignant reference: its malignant fraction correlates with MLANA/PMEL/TYR/MITF at ρ ≈ 0.75, compared with ≈ 0 for HNSCC and Vanderbilt
     (`signature_validation_vs_markers.csv`).
6. **Stratification**: tertiles of the immune fraction (Immune-high / intermediate / low). Unsupervised TME clusters come from
   Ward clustering of the cell type scores (k = 3).
7. **Response**: Wilcoxon test with BH FDR across all cell types and summary scores; sensitivity analysis excluding QC-flagged samples.

## Key results
- **Most immune-infiltrated patients** (immune fraction ≥ 0.6): 20_ipiPD1, 13_ipiPD1, 7_PD1, 37_ipiPD1, 6_PD1, 45_PD1,
  32_ipiPD1, 53_PD1. Full ranking: `patient_immune_stromal_scores.csv` and `figures/immune_fraction_ranking.pdf`.
  - 13_ipiPD1, 53_PD1, 45_PD1, 37_ipiPD1 and 32_ipiPD1 combine a high immune fraction with a strong CD8 T-cell signal ("hot").
  - 20_ipiPD1 and 6_PD1 are infiltrated mainly by B cells and naive/resting CD4 T cells, with a lymph-node gene program
    (CCR7, SELL, CR2, LTB). 20_ipiPD1 has almost no melanoma marker expression, so it is probably a lymph node
    biopsy rather than an inflamed tumour. These two samples form TME cluster C3.
- **Least infiltrated** (immune fraction < 0.2): 13_PD1, 5_PD1, 1_ipiPD1, 42_PD1, 45_ipiPD1, 16_PD1.
- **Response**:
  - Immune-high patients responded in 20/24 cases (83 %), compared with 16/24 (67 %) for intermediate and 10/25 (40 %) for low (Fisher p = 0.007).
  - The CD8 T-cell consensus score is the strongest single predictor (AUC 0.80, FDR = 7e-4). The immune fraction follows (AUC 0.71, FDR = 0.04).
  - Higher mast cell, monocyte and mural-cell scores are associated with non-response, though only nominally significant.
  - Results are unchanged after excluding flagged samples.
- **TME clusters**: C2 (immune/CD8/myeloid-rich) has 31 R and 8 NR. C1 (immune-poor, mast/mural/NK-activated relatively higher) has 14 R and 18 NR.

## Caveats
- The stromal/CAF fraction from CBSX-Melanoma follows the melanoma **dedifferentiation** program (AXL/WNT5A/NGFR/TGFBI, ρ = 0.67) more than
  fibroblast markers (ρ = 0.56). Mesenchymal-like tumour cells are partly called "CAF", so cancer fractions are underestimated
  in MITF-low tumours. The consensus `Fibroblasts` score is the better stromal readout (ρ = 0.72 with COL1A1/COL3A1/DCN/FAP).
  The endothelial estimate does not track endothelial markers.
- Cell type scores from immune-only signatures (LM22, TIL10, …) describe immune *composition*. The composite `Immune_score`
  is therefore a secondary, relative index; use `Immune_fraction` to rank infiltration.
- QC flags (`QC_flag` column): lymph-node-like = 20_ipiPD1, 6_PD1, 44_PD1. Very low TPM content within the provided gene set = 8_PD1.
- Associations are exploratory: pre-treatment only, a single cohort, and no adjustment for therapy arm or biopsy site.

## Files
| File | Content |
|---|---|
| `patient_immune_stromal_scores.csv` | **Main table**: per-patient fractions, scores, class, cluster, response, QC flag (sorted by immune fraction) |
| `deconvolution_all_methods_signatures.csv` | Raw multideconv output (73 × 284) |
| `Results/` | Native multideconv outputs (`Deconvolution_Gide.csv`, `Deconvolution_after_subgrouping_Gide.csv`, `Cell_subgroups_Gide.csv`) |
| `subgrouped_feature_annotation.csv` | Each subgrouped feature with its cell type, compartment and member method–signatures |
| `cell_type_consensus_scores_z.csv` | Consensus z-scores per cell type (38) |
| `immune/stromal/cancer_fraction_per_method_signature.csv` | Compartment fractions per method–signature |
| `signature_validation_vs_markers.csv`, `score_vs_marker_genes_spearman.csv`, `marker_gene_scores_log2TPM.csv` | Validation against marker genes |
| `association_with_response_wilcoxon*.csv`, `immune_class_vs_response*.csv`, `tme_cluster_vs_response.csv` | Response associations |
| `figures/` | Heatmaps, compartment barplots, quanTIseq composition, ranking, validation, response boxplots |
