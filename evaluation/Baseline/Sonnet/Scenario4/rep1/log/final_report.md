## Summary

I ran RaCInG (R package at `~/Documents/RaCInG_package`) on the Gide cohort (73 melanoma ICB patients, 18,979 genes) via its kernel method, using Quantiseq deconvolution into 10 immune/stromal cell types. Two fixes were needed along the way: converting the `log2(TPM+1)` matrix back to linear TPM, and pre-sanitizing sample names (multideconv silently renames digit-starting IDs internally, which otherwise breaks the pipeline).

**Most common interaction patterns** (defined as: how often a cell-type pair ranks in a patient's top-5 strongest direct-communication scores, across all 73 patients):

| Rank | Pair | % of patients |
|---|---|---|
| 1 | CD4 (non-reg) ↔ Neutrophils | 68.5% |
| 2 | CD4 (non-reg) ↔ Monocytes | 60.3% |
| 3 | Neutrophils ↔ Neutrophils (self) | 60.3% |
| 4 | Monocytes ↔ Neutrophils | 49.3% |
| 5 | CD4 (non-reg) ↔ CD4 (non-reg) (self) | 46.6% |

The top pattern (CD4⁺ T ↔ Neutrophil) is driven mainly by NRG3–ERBB2/ERBB3 and CD44/CSPG4–integrin signaling (see the LR dot plot).

All results — input matrices, kernel scores, the ranked pattern tables/plots, and the LR decomposition — are saved in `results/`. I also saved a few memory notes about the RaCInG package location and the multideconv quirks so future runs on this cohort (or Riaz) won't need to rediscover them.