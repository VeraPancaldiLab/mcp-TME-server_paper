# TME states in the Gide cohort (CellTFusion)

## Data and preprocessing

- Expression: `data/Gide_log2TPM.txt`, log2(TPM + 1), 18,979 genes x 73 samples.
- Clinical data: `data/colData_all.txt`, filtered to `Cohort == "Gide"` (73 samples, matched 1:1 to the expression columns).
- Back-transformed to linear TPM (`2^x - 1`) and passed to `CellTFusion(..., normalized = FALSE)`, which recomputes log2(TPM + 1) internally for TF/pathway activity and uses linear TPM for deconvolution.
- Deconvolution methods: Quantiseq, Epidish, DeconRNASeq, DWLS (CIBERSORTx skipped, no credentials), run sequentially (`do_parallel = FALSE` — see note below).
- TF activity: CollecTRI regulon, univariate linear model (`ulm`).
- All other `CellTFusion()` parameters left at default (`corr = 0.7`, `corr_mod = 0.9`, `pval = 0.05`, `min_module_size = 5`, seed `123`).

Scripts: `scripts/01_run_celltfusion.R` (full pipeline), `scripts/02_clinical_associations.R` (clinical associations).

Note: this host enforces a 6 GiB memory cgroup; the initial parallel run (8 DWLS workers) was silently OOM-killed. The pipeline was rerun with `do_parallel = FALSE`, which completed within the memory budget (~1.9 GiB peak).

## TME states identified

WTCNA grouped TF activities into 12 co-activity modules, correlated with deconvolution features into 124 cell groups, and NMF on the cell-group scores selected **rank 2** as the largest rank with all factors robust and none redundant (bootstrap NMF, 100 runs/rank, ranks 2-15; both Factor1 and Factor2 have recovery ≥ 0.93 and mean similarity ≥ 0.92 — see `Results/NMF_rank_stability_Gide.pdf`). So the Gide TME is well described by **two latent TME states**:

- **Factor1** — dominated by cell groups linked to the *green* TF module, with top contributing deconvolution features: CD8 T cells, CD4 T cells, macrophages (incl. M1), B cells/plasma cells, myeloid cells (`Results/Cells_niches_Gide.pdf`, factor 1 page). This is an **immune-infiltrated / lymphocyte-myeloid-rich** state.
- **Factor2** — a distinct state (not immune-infiltration-dominated; see `Results/Cells_niches_Gide.pdf`, factor 2 page, and `Results/Cells_niches_heatmap_Gide.pdf` for the full cell-group-by-factor weight matrix).

Full cell-group composition and scores: `Results/Cell.groups.composition_Gide.csv`, `Results/Cell.groups.scores_Gide.csv`. Per-sample factor scores: `Results/LatentFactors_scores_with_clinical_Gide.csv`.

## Association with immunotherapy response

`Response` (R vs NR) was tested against the two latent factors (`scores.stat.analysis()`, Wilcoxon rank-sum and Fisher's exact test on a median split, BH-adjusted):

| Factor | Test | statistic | p-value | p.adj (BH) | significant |
|---|---|---|---|---|---|
| Factor1 | Wilcoxon | W = 348.5 | 0.0018 | 0.0036 | **yes** |
| Factor1 | Fisher | OR = 0.21 | 0.0034 | 0.0067 | **yes** |
| Factor2 | Wilcoxon | W = 756.0 | 0.124 | 0.124 | no |
| Factor2 | Fisher | OR = 2.39 | 0.093 | 0.093 | no |

**Factor1 (the immune-infiltrated state) is significantly higher in responders** (median 0.0145 vs 0.0022 in non-responders, mean 0.018 vs 0.006) and significantly associated with Response by both tests after multiple-testing correction. Factor2 shows no significant association with Response.

Neither factor was associated with `Therapy` (anti-PD1 vs anti-CTLA4+PD1, Wilcoxon, both p.adj > 0.5): `Results/LatentFactors_vs_Therapy_wilcox_stats_Gide.csv`.

As an independent check at the TF-module level (`compute.metadata.association()`, one-way ANOVA across all 12 modules x {Response, Therapy}, BH-adjusted within each trait):

- The **green** TF module (the module underlying Factor1) is also significantly associated with Response (F = 12.85, p.adj = 0.0074), higher in responders (median eigengene 0.49 in R vs -0.97 in NR) — consistent with Factor1.
- The **turquoise** module is significantly associated with Therapy (F = 8.79, p.adj = 0.048), with no counterpart at the factor level.

Full statistics: `Results/LatentFactors_vs_Response_wilcox_stats_Gide.csv`, `Results/LatentFactors_vs_Response_fisher_stats_Gide.csv`, `Results/TFmodules_vs_traits_anova_Gide.csv`. Plots for the significant associations: `Results/Wilcoxon_Response_Factor1.pdf`, `Results/Fisher_Response_Factor1.pdf`, `Results/ANOVA_boxplot_summary_Gide_modules_vs_traits_Response.svg`.

## Conclusion

CellTFusion identifies two robust TME states in the Gide melanoma cohort. One of them, an **immune-infiltrated state (Factor1)** combining T cell, B/plasma cell and myeloid (incl. M1 macrophage) deconvolution features under a shared TF co-activity module (green), is **significantly associated with immunotherapy response**: patients with a higher Factor1 score are more likely to respond. The second state (Factor2) is not associated with response or with therapy type.

## Output files

All outputs are under `results/`:
- `CellTFusion_Gide_full_result.rds` — full R object returned by `CellTFusion()` (deconvolution, TF activity, modules, pathways, cell groups, latent factors, cell niches).
- `Results/` — CSVs and plots saved by the package itself (deconvolution matrices, TF/module matrices, dendrograms, NMF rank-stability and factor-mixture plots, cell-niche trees/heatmap, clinical-association stats and plots).
- `run_log.txt`, `clinical_log.txt` — console logs of the two analysis scripts.
