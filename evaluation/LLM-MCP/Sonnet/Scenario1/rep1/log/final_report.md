All results are saved. Here's a summary of what was done and found:

**Pipeline (multideconv):**
1. Confirmed `Gide_log2TPM.txt` holds log2(TPM+1) values (range 0–14) → converted back to linear TPM (`2^x - 1`), since deconvolution requires linear-scale expression.
2. `run_deconvolution` on the 73 Gide samples using Quantiseq, EpiDISH, DeconRNASeq, DWLS, and CIBERSORTx (with your provided credentials) across all bundled signatures → 375 method/signature/cell-type columns.
3. `analyze_deconvolution` harmonized agreeing method/signature estimates into robust subgroups (194 features retained; one near-constant/all-discarded uncharacterized feature removed).
4. Averaged each canonical cell type's harmonized subgroup(s) into one representative value per patient, then summed into **Immune**, **Stromal**, and **Tumor** compartment scores.

**Results in `results/`:**
- `Gide_cell_type_composition.csv` — per-patient abundance for 37 canonical immune/stromal/tumor cell types (B, CD4/CD8 subsets, NK, macrophage polarization, DCs, granulocytes, fibroblasts/CAFs, endothelial, pericytes, cancer cells, etc.)
- `Gide_immune_stromal_infiltration_ranking.csv` — patients ranked by immune infiltration score, with stromal/tumor scores and clinical annotation (Response, Therapy) attached
- `Gide_immune_infiltration_barplot.pdf` — all 73 samples ranked by immune score
- `Gide_immune_vs_stromal_scatter.pdf` — immune vs. stromal infiltration, colored by response
- `Gide_harmonized_deconvolution_matrix.csv`, `Gide_raw_deconvolution_all_methods.csv` — full intermediate matrices
- `Gide_20261027-101149_a86227/` — full reproducibility log/audit trail from the multideconv session

**Most immune-infiltrated samples:** 13_ipiPD1_PRE, 7_PD1_PRE, 6_PD1_PRE, 45_PD1_PRE, 20_ipiPD1_PRE (top 5).
**Least immune-infiltrated:** 45_ipiPD1_PRE, 42_PD1_PRE, 38_ipiPD1_PRE, 17_ipiPD1_PRE, 16_PD1_PRE (bottom 5), which tend to show higher stromal scores instead — consistent with an immune-excluded/stromal-dominant phenotype in these tumors.