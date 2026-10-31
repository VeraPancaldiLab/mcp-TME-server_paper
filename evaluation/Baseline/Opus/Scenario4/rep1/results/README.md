# RaCInG cell-cell communication — Gide cohort (73 pre-treatment melanoma samples)

Scripts: `scripts/01_prepare_input.R`, `scripts/02_racing_kernel_analysis.R` (run from the project root).

## Method
- Input `data/Gide_log2TPM.txt` (log2(TPM+1)) converted back to linear TPM (`2^x - 1`), `already_normalized = TRUE`.
- Cell fractions: quanTIseq (via multideconv). The quanTIseq "other" (non-immune) fraction is kept as
  `Cancer` (= tumor + stroma, ~63% median). It is passed to RaCInG as `deconv` because multideconv's subgroup
  analysis silently drops `uncharacterized.cell` (nomenclature mismatch) and renormalizes immune cells to 100%.
- Ligand-receptor prior: liana curated OmniPath (RaCInG default, cached); expression threshold 10 TPM.
- RaCInG kernel method (direct communication, analytic): directed raw scores, directed normalized
  (enrichment vs. uniform LR baseline), undirected raw. Raw scores = abundance-weighted fraction of
  a patient's communication edges going sender -> receiver (sum ≈ 1 per patient).
- `computeLRContributions()` decomposes each sender->receiver score exactly into ligand-receptor terms.

## Files
- `racing_input/` RaCInG L/R/C/LR matrices, CC table, quanTIseq fractions, input RDS.
- `kernel/` patient x interaction feature matrices (CSV) and full kernel results (RDS).
- `summary/` cohort ranking of directed / undirected cell-type pairs, sender/receiver totals,
  per-patient top 5 interactions, frequency of each patient's #1 interaction.
- `lr_contributions/` global LR-pair ranking, LR pairs per cell-type pair, top LR pairs of the
  top 10 interactions, and the full per-patient decomposition (`.csv.gz`).
- `figures/` heatmaps (median communication, enrichment, patient clustering), box/bar/dot plots.
- `logs/` run logs.

## Caveats
- Cell-type-level results are largely driven by quanTIseq abundances (Cancer/non-immune dominates).
- LR assignments to low-abundance immune types rely on NNLS-estimated cell profiles and contain
  implausible attributions (e.g. ANGPTL3 from B cells, PDGFD/LAMA2 from NK); interpret LR pairs for
  minor cell types with caution. CD4 Tconv and DC are absent in most samples (median fraction 0).
