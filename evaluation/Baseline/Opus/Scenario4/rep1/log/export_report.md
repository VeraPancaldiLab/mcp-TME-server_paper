I exported the main result (the default-prior run in `results/01_inputs/` and `results/02_kernel/`) to `results/standard/`, converting existing files only. All five requested items were produced, so nothing was skipped. The curated-prior variant was not exported.

- **`composition.csv`**: the normalized cell-type matrix RaCInG used, 73 patients × 11 cell types (B, CD4, CD8, DC, M1, M2, Monocyte, Neutrophil, NK, Treg, Tumor). I removed the "Pt" prefix I had added during processing, so patient names match the input file.
- **`ligands.csv`** (1,971 rows) and **`receptors.csv`** (2,078 rows): one row per cell type–gene assignment. RaCInG's file reading had turned hyphens into dots in 19 ligand names (e.g. `HLA.A`). I restored the hyphenated symbol only where the dotted name isn't a gene in the expression file but the hyphenated one is. No receptor names needed this.
- **`direct_interactions.csv`**: copied from the raw, undirected direct features RaCInG returned (`features_D_raw.csv`), not rebuilt from directed edges. All 66 unordered pairs are present, with columns renamed to `A - B`.
- **`info.json`**: deconvolution by quanTIseq, no CIBERSORTx, computed by me before RaCInG, input scale linear TPM.

Files written: `composition.csv`, `ligands.csv`, `receptors.csv`, `direct_interactions.csv`, `info.json`