Full reproducibility log and all intermediate outputs exported too. Here's a summary:

## What was done
1. **Scale conversion**: `Gide_log2TPM.txt` holds log2(TPM+1) values — converted back to linear TPM (deconvolution requires linear scale).
2. **Deconvolution** (`run_deconvolution`, 73 Gide samples): 5 methods (Quantiseq, Epidish, DeconRNASeq, DWLS, CBSX using your credentials) × multiple signatures → 375 raw cell-type features.
3. **Aggregated** every immune cell type into one "Immune" group and every stromal cell type into one "Stromal" group (`aggregate_cell_groups`).
4. **Harmonized** (`analyze_deconvolution`) across methods/signatures into robust, cross-method-agreed subgroups — including the Immune/Stromal composite groups.
5. Computed a per-patient **Immune score** and **Stromal score** (average of the harmonized Immune/Stromal subgroup estimates) and ranked patients.

## Key findings
- **Most immune-infiltrated**: `20_ipiPD1_PRE` (0.92), `6_PD1_PRE` (0.72), `13_ipiPD1_PRE` (0.69), `7_PD1_PRE` (0.67), `53_PD1_PRE` (0.65) — full ranking of all 73 patients in `results/Gide_immune_stromal_scores.csv`.
- **Least immune-infiltrated / most stroma-dominated**: `45_ipiPD1_PRE`, `42_PD1_PRE`, `13_PD1_PRE`, `16_PD1_PRE`.
- Immune and stromal scores are strongly inversely related (as expected — see `Gide_immune_vs_stromal_scatter.png`).
- Cohort-wide composition (`Gide_cell_type_composition_summary.csv`): B cells, Myeloid cells, Macrophages (M1/M2), and Monocytes are the most abundant immune populations; CAF and Fibroblasts dominate the stromal compartment.

## Files in `results/`
- `Gide_immune_stromal_scores.csv` — per-patient Immune/Stromal scores, rank, Response/Therapy
- `Gide_cell_type_composition_summary.csv` — cohort-level breakdown per cell type
- `Gide_immune_infiltration_ranked.png` — patients ranked by immune score (colored by responder/non-responder)
- `Gide_immune_vs_stromal_scatter.png`
- `Gide_deconvolution_raw.csv` / `Gide_deconvolution_harmonized_matrix.csv` — full deconvolution outputs
- `Gide_20261016-203100_64f4c2/` — full multideconv session log/audit trail

One caveat worth noting: this is a modest-sized bulk RNA-seq cohort (73 samples), so these deconvolution-based scores are estimates, not ground truth — I did not have matched FACS/IHC data to benchmark against.