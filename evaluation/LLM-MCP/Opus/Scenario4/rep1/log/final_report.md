RaCInG has finished on the Gide cohort. The most common pattern is signaling among a handful of very abundant cell types, centred on fibroblasts/CAFs and B cells, with myeloid cells, macrophages and tumor cells next. The B-cell signal looks like an artefact, so treat that part with care. Everything is saved in `results/`, and `results/README.md` explains each folder.

**How I ran it**
- **Input:** the expression file is log2(TPM+1), so I converted it back to linear TPM for RaCInG (`results/Gide_TPM_linear.csv`).
- **Sample IDs:** RaCInG's deconvolution renames IDs that start with a digit (`10_PD1_PRE` becomes `X10_PD1_PRE`), which broke the matching. I put an `S` in front of each ID for the run. The results use your original IDs, and `results/sample_id_mapping.csv` maps between them.
- **Input step** (`results/racing_inputs/`): all default settings, including CIBERSORTx with your credentials. This gave 194 cell types, 661 ligands, 611 receptors and 73 patients. The first full attempt ran out of memory; a plain retry succeeded.
- **Kernel step** (`results/racing_kernel/`): default settings, giving 73 patients × 18,767 cell-type-pair scores.
- **Ligand–receptor breakdown** (`results/lr_contributions/`): I split six of the strongest cell-type pairs into the ligand–receptor pairs behind them.

**Most common cell-type pairs** (`results/patterns/`)

| Broad cell-type pair | Patients where it ranks in their top 10 |
|---|---|
| Fibroblasts/CAF ↔ Fibroblasts/CAF | 92% |
| Fibroblasts/CAF ↔ Myeloid cells | 81% |
| Myeloid cells ↔ Myeloid cells | 70% |
| B cells ↔ Fibroblasts/CAF | 66% |
| Fibroblasts/CAF ↔ Macrophages | 62% |
| B cells ↔ Myeloid cells, Macrophages ↔ Myeloid cells | 58% |
| Fibroblasts/CAF ↔ Monocytes | 49% |

- Tumor cells come next, mainly paired with CAFs and myeloid cells.
- For individual cell types, B cells ↔ B cells, CAF ↔ B cells and CAF ↔ CAF are each in the top 50 for 70–97% of patients.
- Of the 100 strongest individual pairs, B cells ↔ macrophages account for 22, B cells ↔ CAF for 12 and B cells ↔ monocytes for 9.
- The pattern is very consistent: these pairs are non-zero in every patient (97% for the tumor-cell pairs).

**Ligand–receptor pairs behind them**
- **Shared across edges:** APOE→TYROBP and TYROBP→CD44 are in the top 10 of four of the six pairs I broke down. APP→CD74, APP→TYROBP and CLU→TYROBP are in three.
- **CAF ↔ CAF:** CNTN1→NOTCH1, CNTN1→NRCAM, NID1→PTPRF, SLIT2→GPC1, and collagen/SPP1→ITGB1.
- **B cells ↔ M1 macrophages:** CCL2→CCR1 (top 10 in 80% of patients), HLA-A/B/C→LILRA1, IL10→IL10RA and VEGFC→LYVE1.
- **Tumor cells ↔ B cells:** SELPLG→SELL (top 10 in 90% of patients) and HLA-A/B/C/B2M→CD3D.
- **Most-used ligands overall:** APP, COL4A1/COL4A2, SPP1, APOE, VEGFA, LAMA2, THBS1, MDK, TGFB1 and CXCL12. This points to a microenvironment shaped by extracellular matrix, myeloid cells and immune suppression.
- **No single pair dominates:** each edge is spread over 200–770 ligand–receptor pairs, and the top 10 together carry only 2.5–9% of an edge's score.

**Limits on interpretation**
1. **The scores follow cell abundance.** RaCInG's default scores are weighted by how much of each cell type a patient has, so common cell types rank highest.
2. **The "B cells" are probably not real B cells.** The three most abundant cell types (about 5% each) are B-cell estimates from a signature built from lung-cancer patients' blood (NSCLC-PBMC). That signature has no tumor or stromal cells, so in melanoma tissue those "B cells" are likely absorbing signal from other cells.
3. **The estimated expression profiles are mixed.** For example, the "B cell" profile expresses myeloid genes (TYROBP, CD14), and a tumor-cell subgroup expresses a T-cell gene (CD3D). Read ligand–receptor pairs tied to a specific cell type with that in mind.

RaCInG can also score each pair against a baseline that removes the effect of abundance (`norm=True`), which would show which pairs communicate more than their abundance alone predicts. Should I run that version as well?

Everything is in `results/`; open these first:
- `patterns/lineage_pair_statistics.csv`
- `patterns/celltype_pair_statistics.csv`
- `patterns/lineage_pair_heatmap.pdf`
- `lr_contributions/top10_lr_pairs_per_edge.pdf`
- `README.md`