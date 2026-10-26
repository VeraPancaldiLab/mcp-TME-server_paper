# TME state characterization — Gide cohort (anti-PD1 / anti-PD1+ipilimumab melanoma)

## Input
- Expression: `data/Gide_log2TPM.txt` — log2(TPM+1), 73 samples. Converted back to linear
  TPM (`2^x - 1`) before deconvolution/CellTFusion, since those require linear-scale input
  (see `inputs/Gide_linearTPM.csv`).
- Clinical: `data/colData_all.txt` subset to the 73 Gide samples (`inputs/coldata_gide.csv`),
  matched 1:1 to expression columns by sample ID. `Response` = R (responder) / NR
  (non-responder) to immunotherapy.

## Pipeline
1. `CellTFusion::run_celltfusion` (deconvolution: Quantiseq, EpiDISH, DeconRNASeq, DWLS, CIBERSORTx;
   TF collection CollecTRI; PROGENy pathways) was run on the linear TPM matrix to build:
   - cell-type deconvolution -> harmonized cell subgroups
   - TF activity -> WGCNA TF co-activity modules
   - **cell groups** (138 features): CCA score of each deconvolution subgroup against its
     associated TF module -> "how much of this cell type" x "how active is its regulatory program"
   - **NMF latent factors**: rank selected automatically by bootstrap stability = **4** (all 4
     factors robust, none redundant) -> `CellTFusion/NMF_latent_factors_Z.csv`
   - See `CellTFusion/result_Cells_niches.csv` for which cell groups/features compose each factor.
2. Each of the 138 cell groups and the 4 NMF factors (the TME states) was tested against
   `Response` with a Wilcoxon rank-sum test (`Bioinfo-tools::scores_wilcox_test`) ->
   `response_association/`.

## Main finding
**Factor1**, one of the 4 TME states identified by CellTFusion, is significantly associated
with response to immunotherapy (Wilcoxon p = 2.4e-4, BH-adjusted p = 0.009), and is
**higher in responders** (median 0.0113) than non-responders (median 0).

Factor1 is built from "green"/"greenyellow" TF-module-linked cell groups whose composition
(`CellTFusion/result_Cells_niches.csv`) points to an **immune-active TME**: higher B cells,
CD4/CD8 T cells, NK cells and plasma cells, co-activated with their regulatory TF modules, and
*lower* M1/M2 macrophages and monocytes. This is consistent with the established link between
pre-treatment lymphocyte-rich, less myeloid-dominated tumors and better anti-PD1/anti-CTLA4
response.

Of the 138 individual cell groups, 50 were nominally associated with response (Wilcoxon
p < 0.05) and 34 remained significant after Benjamini-Hochberg correction
(`response_association/Response_association_stats.csv`), almost all driven by the same
green/greenyellow-module lymphocyte-rich cell groups that make up Factor1 — i.e. one coherent
immune-active TME program, not scattered unrelated hits.

The other 3 TME states (Factor2-4) were not significantly associated with response in this
cohort (all p > 0.4).

## Results layout
- `CellTFusion/` — full CellTFusion output: deconvolution, TF activity, pathway activity,
  cell-group scores, NMF latent factors (TME states), cell-niche composition, and all
  diagnostic plots (WGCNA dendrograms, NMF rank stability, cell-niche heatmap).
- `response_association/` — Wilcoxon test results (raw + BH-adjusted p-values) for every cell
  group and every latent factor against `Response`, plus boxplots for each significant feature.
- `inputs/` — the linear-TPM expression matrix and clinical subset actually fed into CellTFusion,
  for reproducibility.
