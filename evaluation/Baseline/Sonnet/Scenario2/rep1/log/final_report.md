Analysis complete. Summary:

Using CellTFusion on the Gide melanoma cohort (73 samples), I identified **2 robust TME states** (NMF latent factors, both recovery ≥0.93):

- **Factor1**: an immune-infiltrated state (CD8/CD4 T cells, B/plasma cells, macrophages/myeloid cells under a shared "green" TF co-activity module)
- **Factor2**: a distinct, non-immune-infiltration state

**Factor1 is significantly associated with immunotherapy response** (Wilcoxon p.adj=0.0036, Fisher p.adj=0.0067), higher in responders than non-responders. The underlying green TF module confirms this independently (ANOVA p.adj=0.0074). Factor2 showed no association with response. Neither factor was associated with therapy type (anti-PD1 vs combo).

All results (CSVs, plots, the full R object, and a written `ANALYSIS_SUMMARY.md`) are saved under `results/`. One operational note: this host caps memory at 6 GiB (not the 15 GiB `free -h` shows), which silently killed the first parallel run — I reran sequentially and saved that as a memory for future sessions here.