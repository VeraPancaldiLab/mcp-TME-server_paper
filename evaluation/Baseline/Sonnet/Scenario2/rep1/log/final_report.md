## Summary

I ran `CellTFusion` on the Gide melanoma cohort (73 pre-treatment samples from `data/Gide_log2TPM.txt`, matched to `Response`/`Therapy` in `data/colData_all.txt`). All outputs are in `results/` (pipeline object `CellTFusion_Gide_result.rds`, CSVs, and the package's own plots/tables nested under `results/Results/`).

**TME states found:** NMF identified 4 robust latent factors (TME states) from the cell-group scores (deconvolution × TF-module structure).

**Relation to immunotherapy response:** Testing each factor against `Response` (Wilcoxon, BH-adjusted):
- **Factor1 is significantly associated with response** (p = 0.0021, adj. p = 0.0082), with higher scores in responders than non-responders.
- Factor1's defining cell niches are an **immune-enriched signature** — B cells, memory B/plasma cells, CD4/CD8 T cells, NK cells, monocytes, M1 macrophages, activated dendritic cells.
- This is corroborated at the TF-module level: the same underlying modules ("green", "greenyellow") are independently associated with response (ANOVA p = 0.0006 and 0.026).
- Factors 2–4 showed no significant association with response.

Key result files: `results/TME_states_vs_Response_summary.csv` (factor stats + top cell groups), `results/TME_states_cell_niches_composition.csv` (full niche composition), `results/Results/Wilcoxon_Response_Factor1.pdf` (boxplot).

Two implementation notes worth flagging: the installed `CellTFusion` R package (v0.0.1) is older than its GitHub docs and lacks the meta-program/TME-subtype auto-annotation functions, so "TME states" here are the NMF factors annotated by their top cell-niche composition rather than named subtypes (e.g. "immune-enriched" is my interpretation of the composition, not a package-assigned label). Also, parallel DWLS deconvolution repeatedly OOM-crashed the run, so I used Quantiseq/Epidish/DeconRNASeq only.