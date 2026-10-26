Everything is in place. Here's a summary of what was done and found.

## Pipeline

Used your **RaCInG** R package (found installed at `~/Documents/RaCInG_package`) to reconstruct patient-specific cell-cell communication networks for the 73-sample Gide melanoma cohort:

1. **Preprocessing** — converted log2(TPM+1) → linear TPM, ran `prepare_input_files(already_normalized=TRUE)`: quanTIseq deconvolution (10 immune cell types), NNLS expression profiles, OmniPath/LIANA ligand-receptor prior network.
2. **Kernel method** (deterministic) — Direct, Wedge, Trust/Cycle-triangle, and GSCC features, raw + null-normalized enrichment.
3. **Monte Carlo method** — two independent stochastic replicates (2,000-cell graphs × 30 realizations/patient) for robustness checking.
4. **Pattern ranking + 4 robustness checks** (cross-method, seed-to-seed, within-run noise, patient bootstrap).

I hit and fixed two real snags along the way: sample names starting with digits (e.g. `10_PD1_PRE`) got silently mangled by `multideconv`'s internal `data.frame()` call, and `prepare_input_files()`'s output path needs a trailing slash — both are now handled/documented in `scripts/01_preprocess.R`.

## Most common interaction patterns

The dominant pattern is **myeloid/NK-centered**: Monocytes and Neutrophils (the most abundant resolved immune populations, ~25%/22% by quanTIseq) dominate raw Direct/Wedge/Triangle scores, mostly via self-interactions and cross-talk with NK cells and Macrophages.M2. Separating *abundance* from *specific signaling* (enrichment over a null model) shows Neutrophil-centered communication is the most specifically enriched pattern in the cohort, while the largest raw-score patterns (NK-NK, Macrophages.M2 triangles) are explained by abundance alone, not preferential signaling.

## Robustness

- **Kernel vs. Monte Carlo**: Spearman 0.92–0.99 across all motif types — rankings agree even where raw magnitudes don't scale linearly (triangles).
- **Seed-to-seed**: perfect reproducibility (r=1.00, 100% top-15 overlap) with 30 realizations/patient.
- **Within-run noise**: low for Direct/Wedge (9–15% CV), higher for triangles (31%+).
- **Patient bootstrap** (1,000 resamples): top Direct/Wedge patterns are stable in ≥93–100% of resamples; stability drops further down the ranking.

Full details, tables, and plots are in `results/REPORT.md` and its subfolders (`kernel/`, `montecarlo/`, `robustness/`, `plots/`, `logs/`).