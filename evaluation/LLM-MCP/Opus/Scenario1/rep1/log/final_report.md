The multideconv deconvolution of all 73 Gide samples is done. 24 patients come out as highly immune infiltrated, 24 as intermediate and 25 as low. Everything is saved in `results/`.

**What went into it**
- Your file holds log2(TPM+1), so I converted it back to linear TPM (2^x − 1) for deconvolution.
- I ran 5 methods (Quantiseq, EpiDISH, DeconRNASeq, DWLS and CIBERSORTx) with 7 signatures, giving 375 raw estimates.
- multideconv reduced these to 194 consensus features. It dropped 41 that were zero in more than 90% of samples, mostly some NK, CD8, Treg and neutrophil estimates.

**How I defined "immune infiltrated"**
- Only 13 of the method×signature combinations also estimate tumor or stromal cells, so only they can say how much of a sample is immune. The rest only estimate immune cells, so they can't.
- For each patient I took the total immune fraction from each of those 13 combinations and averaged the standardized values into one immune score.
- I then split patients into thirds: High, Intermediate and Low.
- The methods agree well on who ranks high or low (median Spearman correlation 0.65).
- They disagree on absolute levels: the cohort-median immune fraction ranges from 11% to 71% depending on the combination. So rely on the ranking, not any single percentage.

**Composition** (melanoma-specific signature, the most realistic absolute numbers; cohort median)

| Cell type | Median fraction |
|---|---|
| Tumor cells | ~51% |
| Fibroblasts (CAF) | ~19% |
| Macrophages | ~10% |
| CD4 T cells | ~3% |
| Endothelial cells | ~2% |
| NK cells | <1% |
| B cells | <1% |
| CD8 T cells | ~0% (Q3 ~1%) |

- **Macrophages are the largest immune population.** All lymphocyte types together are much smaller.
- **More immune means less stroma.** The immune and stromal scores are negatively correlated (Spearman −0.65). Low-infiltrated tumors have about twice the fibroblast fraction of high ones (median 38% vs 16%).
- **Fibroblasts are probably overestimated in the all-signature consensus.** Its median stromal fraction is ~43%, because the non-melanoma signatures have no melanoma tumor reference and count melanoma cells as fibroblasts.

**Most immune-infiltrated patients** (high third, ordered by score):
20_ipiPD1, 13_ipiPD1, 37_ipiPD1, 7_PD1, 45_PD1, 6_PD1, 53_PD1, 32_ipiPD1, 40_PD1, 44_PD1, 21_ipiPD1, 38_PD1, 48_PD1, 47_PD1, 27_ipiPD1, 54_PD1, 26_ipiPD1, 36_PD1, 46_ipiPD1, 47_ipiPD1, 34_PD1, 24_ipiPD1, 21_PD1, 36_ipiPD1 (all `_PRE`).
- The top three stand out, with a median of 74–90% immune content across combinations.
- The least infiltrated include 42_PD1, 45_ipiPD1, 16_PD1, 3_PD1, 25_ipiPD1 and 13_PD1, each around 9–17% immune.
- High-infiltrated tumors have more macrophages (15% vs 7%), CD4 T cells (5% vs 2%) and CD8 T cells than low ones.

**Things to be aware of**
- **Sample `8_PD1_PRE`** has an unusually low total TPM in your input file. Its expression profile still matches the cohort, so I kept it. It ranks Low (57th of 73), and it is flagged in the ranking table.
- **Your CIBERSORTx token is stored in plain text** in `results/01_deconvolution/manifest.json`. The exported session log masks it. Remove or redact that file before sharing `results/`.
- I added each patient's therapy and response as reference columns in the ranking table, but I did not test any link between infiltration and response.

**Files in `results/`**
- `input/`: the linear TPM matrix and the Gide clinical subset.
- `01_deconvolution/`: raw multideconv output (375 features).
- `02_harmonized_subgroups/`: consensus cell subgroups and lists of discarded features.
- `03_immune_infiltration/`:
  - `immune_infiltration_ranking.csv`: the main table, with score, rank, group, immune fraction (median and IQR) and stromal score per patient.
  - Composition tables and stacked bar charts.
  - Per-method immune and stromal fractions, plus a heatmap of how well the methods agree.
  - A heatmap of the 194 consensus features with patients ordered by immune score.
- `scripts/immune_infiltration.R`: the code that builds the score, tables and plots.
- `session_export/`: the reproducibility log.

If useful, I could next test whether the infiltration groups or individual cell types differ between responders and non-responders.