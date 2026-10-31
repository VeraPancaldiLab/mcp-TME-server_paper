All three files from my previous export are still in `results/standard/` and match the requested format, so I didn't write them again.

- **`ligands.csv`**: 24,697 rows with columns `cell_type` and `ligand`, taken from RaCInG's prepared ligand matrix (194 cell types).
- **`receptors.csv`**: 27,507 rows with columns `cell_type` and `receptor`, taken from the prepared receptor matrix.
- **`direct_interactions.csv`**: 73 patients × 18,767 cell-type pairs, plus the `patient` column.
  - This is the main kernel result, not normalised, and RaCInG had already removed the direction, so nothing was summed. I only renamed the columns from `Dir_<A>_<B>` to `<A> - <B>`.
  - The patient names and their order match `data/Gide_log2TPM.txt` exactly, and every cell-type name in the columns appears in `ligands.csv`.

**Missing from `direct_interactions.csv`:** 148 of the 18,915 possible cell-type pairs, because RaCInG's output doesn't contain them. They are probably pairs that were zero in every patient and dropped by RaCInG's default filter, but I didn't verify that. I didn't add them.

The conversion script is `results/scripts/export_standard.R`.

Files written: `results/standard/ligands.csv`, `results/standard/receptors.csv`, `results/standard/direct_interactions.csv`