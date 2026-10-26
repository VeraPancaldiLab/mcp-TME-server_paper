The names match exactly. The earlier failure came from how my quick check read the header, not from the export.

I exported the main analysis: quanTIseq composition including the tumor fraction, with the 0.001 abundance floor, `fun_LR=min`, threshold 10 TPM, and the raw kernel. Patient names are the original IDs, without the `Gide_` prefix I added for RaCInG. Nothing was recomputed. The export script is `results/scripts/04_export_standard.R`.

- **`composition.csv`:** the Cmatrix as RaCInG used it, 73 patients × 11 cell types.
- **`ligands.csv` / `receptors.csv`:** every cell-type/gene pair with a nonzero entry in the Lmatrix or Rmatrix (1,577 and 1,621 rows).
- **`direct_interactions.csv`:** RaCInG's own direction-removed D features from the raw kernel, renamed to `A - B`. RaCInG dropped no pairs, so all 66 unordered pairs are present.
- **`info.json`, "deconvolution_source":** I chose "computed by me before RaCInG", but the history is mixed. quanTIseq first ran inside my first `prepare_racing_inputs` call. I then took that output, relabelled its "uncharacterized" fraction as `Cancer`, applied the floor, and passed it to the main run through `deconv_csv`.

Nothing was skipped; all five requested items existed.

Files written to `results/standard/`: composition.csv, ligands.csv, receptors.csv, direct_interactions.csv, info.json