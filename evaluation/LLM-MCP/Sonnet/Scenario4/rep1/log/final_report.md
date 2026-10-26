All results are saved under `results/`. Summary:

**Pipeline** (`results/README.md` has full details):
1. Converted `Gide_log2TPM.txt` (log2(TPM+1)) to linear TPM, then ran Quantiseq deconvolution (11 cell types) and fed it into RaCInG's input builder (458 ligands × 431 receptors, OmniPath network).
2. Ran the **kernel method** both as raw magnitude (`racing_kernel_raw/`) and as an abundance-corrected enrichment ratio (`racing_kernel/`).
3. Ran the **Monte Carlo method** (20 simulated graphs/patient) purely to check robustness.
4. Drilled into ligand-receptor pairs for the two strongest direct edges.

**Most common interaction patterns:**
- In raw terms, myeloid cells dominate: Monocyte–Monocyte and Neutrophil–Neutrophil are the strongest direct edges, with Monocyte–NK, B cell–Monocyte, and M2 macrophage–Neutrophil also prominent.
- After correcting for cell-type abundance, CD4 T cell– and neutrophil-centered edges stand out as disproportionately strong (likely genuine targeted signaling, not just an abundance artifact).
- The same handful of cell types (Monocytes, Neutrophils, NK cells, M2 macrophages, CD4 non-regulatory T cells) recur as hubs in wedge/triangle motifs — a consistent "core" communication module across the cohort.
- GSCC ratios are close to 1 for most cell types, meaning most patients' networks are highly interconnected rather than compartmentalized.
- LHB–RAMP2 and EFNA1–EPHA2 are the most prevalent ligand-receptor pairs behind the Monocyte–Monocyte and Neutrophil–Neutrophil edges, respectively.

**Robustness:**
- Monte Carlo simulation noise is low-to-moderate (median CV ≈0.10–0.17 across motif types; triangles are noisiest).
- Kernel vs. Monte Carlo top-15 feature overlap: 13/15 (direct), 9/15 (GSCC), 8/15 (wedge), but only 4/15 (triangles) — direct and global-integration findings are solid, triangle-motif rankings are more sensitive to a few outlier patients.

One implementation note: both `multideconv-server` and `RaCInG-server`'s CSV loaders require true comma-delimited files — I had to re-export the tab-delimited matrix as CSV (with R's X-prefix quirk on sample names fixed) to get past an opaque "Expecting a matrix" error.