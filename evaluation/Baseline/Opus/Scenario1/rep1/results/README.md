# Gide cohort (n = 73 pre-treatment melanoma, anti-PD1 ± anti-CTLA4) – TME deconvolution with multideconv

Scripts: `../scripts/01_deconvolution.R`, `../scripts/02_tme_analysis.R` (logs: `01_deconvolution.log`, `02_tme_analysis.log`).

## Method
1. `data/Gide_log2TPM.txt` was back-transformed to linear TPM (`2^x - 1`) and passed to
   `multideconv::compute.deconvolution(normalized = FALSE)`. (`normalized = TRUE` would re-run TPM normalisation meant for raw counts.)
   Methods: Quantiseq, DeconRNASeq, EpiDISH, DWLS × 7 bundled signatures (TIL10, LM22, CBSX-Melanoma/HNSCC/Vanderbilt/Zilionis/NSCLC-PBMCs).
   CIBERSORTx was not run because no credentials were provided. This gave 284 features.
2. `compute.deconvolution.analysis(corr = 0.7)` removed low-variance and mostly-zero features and grouped correlated features into cell-type subgroups.
3. **Cell-type consensus score** = mean z-score of all retained features/subgroups for that cell type.
4. **Immune/stromal infiltration** used only the combinations that model non-immune cells, so the fractions are absolute rather than relative to the immune compartment:
   Quantiseq-TIL10 (immune = 1 − uncharacterized) and {DeconRNASeq, EpiDISH, DWLS} × {CBSX-Melanoma, HNSCC, Vanderbilt}
   (immune = sum of immune cells; stromal = CAF + fibroblasts + endothelial + mural + myocytes; tumour = cancer).
   The consensus immune score is the mean z-score across 10 combinations, and the stromal score uses 9. Patients were split into tertiles (Immune-high / intermediate / low).

## Key files
| File | Content |
|---|---|
| `patient_immune_infiltration_ranking.csv` | **Main table**: per-patient immune/stromal scores, mean fractions, rank, tertile group, immune×stroma class, response, therapy, key cell-type z-scores, marker checks |
| `celltype_consensus_scores_zscore.csv` | 38 cell types × 73 samples consensus scores |
| `celltype_consensus_info.csv` | Number of features per cell type and mean pairwise Spearman agreement between them |
| `compartment_fractions_per_method.csv` | Immune/stromal/tumour fractions for every tumour-aware method-signature combination |
| `deconvolution_raw_features.csv` / `.rds` | All 284 raw multideconv features |
| `deconvolution_processed_features.csv`, `deconvolution_subgroups_composition.csv`, `deconvolution_discarded_features.txt` | multideconv post-processing output |
| `Results/` | Files written by multideconv itself |
| `validation_correlations.csv` | Consensus scores compared with PTPRC, cytolytic activity (GZMA/PRF1) and stromal marker genes |
| `association_with_response.csv`, `immune_group_vs_response.csv` | R vs NR Wilcoxon tests (BH-adjusted) and tertile × response Fisher test |
| `figures/` | Heatmaps, ranking barplot, compartment stacked bars, quanTIseq fractions, method concordance, response boxplots |

## Caveats
- The absolute fractions depend on the signature used: tumour fractions look low and stromal fractions look high for melanoma. The patient ranking (z-score consensus) is more reliable than the absolute percentages.
- quanTIseq alone reports 100% immune for 6_PD1_PRE and 36_PD1_PRE, which is implausible. The multi-method consensus reduces the effect of this.
- Biopsy site (e.g. lymph-node metastases) is not in the clinical file. Very high immune / very low tumour samples such as 20_ipiPD1_PRE may be nodal biopsies.
- Immune and stromal scores are anti-correlated (ρ = −0.62), partly because the fractions must sum to 1.
- Many cell-type subsets (e.g. Tregs, M2 macrophages, mast/NK subsets) show low agreement between methods (see `celltype_consensus_info.csv`). Treat them as exploratory. CD8 T cells, macrophages, CAFs and proliferating T cells are the most consistent.
