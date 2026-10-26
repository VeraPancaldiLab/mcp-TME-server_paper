Memory saved. Now let me give the final summary.

## Summary

I ran the full `multideconv` pipeline on the Gide cohort (73 samples filtered from `colData_all.txt`, 18,979 genes). Expression was back-transformed from log2(TPM+1) to linear TPM, then deconvolved with Quantiseq, EpiDISH, DeconRNASeq, and DWLS across all bundled signatures (284 method-signature-celltype features; CIBERSORTx was skipped — no credentials). DWLS had to be run serially after a parallel run silently OOM-crashed on this machine.

**Pipeline steps** (`compute.deconvolution` → `compute.deconvolution.analysis` for robust cell-type subgroups → `aggregate_cell_groups` into Immune/Stromal compartments → `compute.deconvolution.analysis` again on the aggregated matrix):

**Key finding:** responders (R) have significantly higher immune infiltration than non-responders (NR) — Wilcoxon p = 0.0027 — and immune/stromal scores are strongly anti-correlated (immune-hot tumors tend to be stroma-poor, and vice versa), consistent with established melanoma immunotherapy biology.

All results are in `results/`:
- `immune_stromal_scores_per_sample.csv` — per-patient Immune/Stromal composite z-scores, ranked (most → least infiltrated), with Response/Therapy
- `deconvolution_celltype_subgroups.csv` / `deconvolution_immune_stromal.csv` — full reduced deconvolution matrices
- `subgroup_composition_immune_stromal.txt` + `raw_package_output/` — traceability of which method/signature features fed each subgroup
- 4 PDFs: immune-vs-stromal scatter, patients ranked by immune score, immune score by response (boxplot), top-variable cell-type heatmap

The top immune-infiltrated patient is `20_ipiPD1_PRE` (R, CTLA4+PD1); the least infiltrated is `45_ipiPD1_PRE` (R) — full ranking is in the CSV. Intermediate RDS/cache files are kept in `run_tmp/` for reproducibility but aren't part of the deliverables.