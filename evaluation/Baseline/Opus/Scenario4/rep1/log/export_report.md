The three files from the previous step are still in `results/standard/` with the same row and column counts, so I didn't write anything new. No requested item was skipped.

- **`ligands.csv`** (1,578 rows: `cell_type`, `ligand`): one row per cell type–ligand assignment in the prepared-input `Lmatrix`.
- **`receptors.csv`** (1,620 rows: `cell_type`, `receptor`): the same conversion of the `Rmatrix`.
- **`direct_interactions.csv`** (73 patients × 66 unordered pairs, plus the `patient` column):
  - These are the existing raw, undirected kernel features, exactly as RaCInG returned them with the direction removed.
  - Columns are named `A - B` using the cell-type names in `ligands.csv`, and patient names match the input data exactly.
  - When I made it, I checked that each value equals A→B + B→A from the directed features, so "A - A" is twice A→A.

Files written: `results/standard/ligands.csv`, `results/standard/receptors.csv`, `results/standard/direct_interactions.csv`