# Gide cohort – cell-cell communication (RaCInG, kernel method)

Input: `data/Gide_log2TPM.txt` (18,979 genes x 73 pre-treatment samples, log2(TPM+1)).

## Steps
1. `Gide_TPM_linear.csv` – log2(TPM+1) converted back to linear TPM (2^x - 1). RaCInG was run with
   `already_normalized=TRUE`. Sample IDs have an `S` in front because the internal deconvolution
   renamed IDs that start with a digit (`10_PD1_PRE` -> `X10_PD1_PRE`), so they no longer matched the
   expression matrix. `sample_id_mapping.csv` maps them back; all files in `patterns/` and
   `lr_contributions/*/result_original_ids.csv` use the original IDs.
2. `racing_inputs/` – `prepare_racing_inputs`, all defaults: deconvolution with Quantiseq, EpiDISH,
   DeconRNASeq, DWLS and CIBERSORTx, each with all its signatures (raw estimates in
   `Results/Deconvolution_Gide.csv`), then grouping into cell-type subgroups -> 194 cell types,
   661 ligands, 611 receptors, OmniPath ligand-receptor network.
   The first full attempt ran out of memory; the retry (OmniPath network already cached)
   completed, peaking at ~10 GB in use on the machine (`logs/memory_monitor.log`).
3. `racing_kernel/` – `run_racing_kernel`, defaults (raw scores, `norm=FALSE`; directions merged):
   73 patients x 18,767 direct-communication features `Dir_<A>_<B>`.
4. `patterns/` – `scripts/summarize_racing_patterns.R`
   - `celltype_pair_statistics.csv`: per cell-type pair: cohort median/mean score, fraction of
     patients where it is non-zero / in that patient's top 50, median within-patient rank.
   - `lineage_pair_statistics.csv`, `lineage_pair_scores_per_patient.csv`: the same at the level
     of broad cell types (all estimates of one broad cell type pooled, per-patient mean).
   - `lineage_pair_heatmap.pdf`, `top15_lineage_pairs_barplot.pdf`, `top25_celltype_pairs_boxplot.pdf`.
5. `lr_contributions/` – `explain_lr_contributions` for 6 leading cell-type pairs (B<->B, CAF<->B,
   CAF<->CAF, Cancer<->B, Cancer<->Cancer, B<->M1 macrophages), summarised by
   `scripts/summarize_lr_contributions.R`: `*/lr_pair_summary.csv`,
   `top10_lr_pairs_per_edge.csv/.pdf`, `recurrent_lr_pairs_across_edges.csv`,
   `ligand_share_across_edges.csv`.
6. `session_export/` – reproducibility log of every RaCInG tool call.

## Caveat
Raw kernel scores are weighted by cell-type abundance, so the most abundant cell types dominate the
ranking. The three B-cell estimates from the NSCLC-PBMC signature are the most abundant cell types
in this cohort (~5% each). That signature contains only blood cells (no tumor or stromal cells), so
in melanoma tissue those "B cells" probably absorb signal from other cells. The expression profiles
estimated for each cell type are also mixed: e.g. the "B cell" profile expresses myeloid genes
(TYROBP, CD14) and `Cancer_Subgroup.2` expresses T-cell genes (CD3D).
