## Summary

I ran RaCInG's kernel method on the Gide cohort (73 samples). Two data issues had to be fixed before it would run:
- The file is log2(TPM+1), not linear TPM — converted back via `2^x - 1`.
- Sample names starting with digits (e.g. `10_PD1_PRE`) get silently mangled by R's `make.names` inside the deconvolution step, causing a patient-mismatch error — fixed by prefixing all sample IDs with `Pt_`.

Deconvolution used the full default method set (Quantiseq, EpiDISH, DeconRNASeq, DWLS, CIBERSORTx) with your provided CBSX credentials, yielding 192 harmonized cell-type nodes → 18,390 directed cell-type-pair communication features from the kernel.

**Most common interaction patterns** (aggregated to 38 recognizable cell types; ranked by strength among the 377/741 cell-type pairs with detectable communication in *all* 73 patients):

| Rank | Cell-type pair | Mean score |
|---|---|---|
| 1 | B cells ↔ B cells | 0.0404 |
| 2 | B cells ↔ Monocytes | 0.0287 |
| 3 | B cells ↔ Macrophages M1 | 0.0261 |
| 4 | B cells ↔ CAFs | 0.0253 |
| 5 | B cells ↔ Macrophages M2 | 0.0252 |
| 6 | B cells ↔ CD4 T cells | 0.0179 |
| 7 | B cells ↔ NK cells | 0.0160 |
| 8 | B cells ↔ CD8 T cells | 0.0137 |
| 9 | Monocytes ↔ Monocytes | 0.0130 |
| 10 | B cells ↔ Cancer cells | 0.0128 |

B cells are the most consistently and strongly interacting hub in this cohort, both with themselves and across nearly every other major compartment (myeloid, stromal/CAF, lymphoid, tumor). Myeloid-myeloid and myeloid-CAF crosstalk (monocyte/macrophage ↔ CAF/monocyte/macrophage) forms the next-strongest recurring theme.

**Saved in `results/`:**
- `Gide_CCC_broad_celltype_pairs_summary.csv` — prevalence + mean strength per cell-type pair (the table above, full list)
- `Gide_CCC_broad_celltype_pairs_per_patient.csv` — per-patient values for each pair
- `RaCInG_outputs/` — the underlying RaCInG outputs: direct communication features (fine-grained, 18,390 cols), cell-type abundance (Cmatrix), ligand/receptor-by-celltype matrices (Lmatrix/Rmatrix), and the raw deconvolution matrix

Full intermediate run directories (incl. the large raw cell-cell table and `result.rds` files) remain in the RaCInG session at `.../racing/runs/sessions/Gide_20261030-045357_0ac7a2/`, in case you want to chain further analysis (e.g. `explain_lr_contributions` to see which ligand-receptor pairs drive the B-cell interactions).