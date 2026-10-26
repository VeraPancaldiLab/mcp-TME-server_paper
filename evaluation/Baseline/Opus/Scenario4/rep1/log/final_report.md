I built patient-specific communication networks for all 73 Gide samples with RaCInG and stress-tested them. The headline: which cell types talk to which is very robust, but the specific ligand–receptor (LR) pairs behind each link are not. Everything is in `results/`; start with `results/REPORT.md`.

**Two analysis choices you should know about:**
- **Tumor fraction kept.** The package's default deconvolution step silently drops quanTIseq's "uncharacterized" fraction (about 60% of cells here), leaving an immune-only network. I passed the full composition through `deconv=` and labeled that fraction "Tumor", as the original RaCInG did. In this setup it also contains stromal cells.
- **Two priors.** The package's default way of deciding which cell types can send or receive each ligand/receptor gave implausible assignments (e.g. NK cells "sending" collagen and PDGF ligands; neutrophils "receiving" through CD3D). So I ran everything twice: once with that default, and once with the curated matrices from the original RaCInG paper (bundled as `skcm_example`, rebuilt for Gide with quanTIseq plus EPIC).

**Most common patterns**
- **Dominant communication is centred on the tumour.** Tumor→Tumor carries 13.6% of all communication and is among the 10 strongest links in 95% of patients. Next come tumour exchanges with monocytes and neutrophils (default) or macrophages, fibroblasts (CAF) and endothelium (curated). This mostly reflects abundance: tumour cells are about 63% of the sample.
- **Tumour cells use their LR channels more than expected by chance.** Tumor→Tumor and Tumor→B are enriched in 99–100% of patients under both priors. Communication among immune cells, especially anything involving Tregs, NK cells or CD8 T cells, is consistently below chance.
- **Patients differ along one continuous axis**, from lymphoid-engaged communication (enriched CD8/CD4/Treg/B links) to tumour- or stroma-dominated communication. As an unplanned, uncorrected observation, the lymphoid-engaged end has more responders (Fisher p = 0.011 default, 0.0006 curated).

**How robust the results are**
- **Simulated networks:** the package's simulation (actual random cell graphs) reproduces the exact calculation almost perfectly (correlation above 0.98 for every patient). Graph randomness doesn't affect the results.
- **Input noise and settings:** I ran 167 perturbed runs (noise on cell fractions and expression, 80% subsets of the LR database and of patients, alternative thresholds and scoring, dropping one low-quality sample). Agreement with the original results:

| Result | Agreement (default prior) |
|---|---|
| Ranking of dominant links | 0.99 |
| Ranking of enrichment | 0.96 |
| Patient axis | 0.94 |
| Discrete patient groups (ARI) | 0.47 |

  The curated prior is more stable throughout (0.79 for the groups).
- **Default vs curated prior:** they agree on dominant links (correlation 0.92, 8 of the top 10 shared) and the patient axis (0.71). They agree less on enrichment (0.42–0.63). The patient groupings barely match (ARI 0.23), and the LR pairs attributed to the same link are largely different.

So you can rely on the dominant tumour-centred links, the core enriched channels and the patient axis. Treat the discrete patient subtypes and the LR-level explanations as hypotheses. Tumour↔monocyte/neutrophil and Tumor→CD4 enrichment pass every perturbation test, but they can't be checked against the curated prior, which doesn't include those cell types.

**Issues in RaCInG 0.3.0 itself** (details in section 6 of the report):
- `prepare_input_files()` fails when sample IDs start with a digit (`10_PD1_PRE`), because multideconv renames them. I worked around it with a "Pt" prefix.
- The tumour fraction is dropped by default, as above.
- `.clean_celltype_names()` is never called, so labels keep the `Quantiseq_TIL10_` prefix.
- The `compute_racing_*` wrappers don't pass `already_normalized` through.
- Monte Carlo runs with `ncores > 1` aren't seed-reproducible.

**Data caveats:**
- CCL3/4/5/14/18/23 are missing from the expression file, so links like CCL5–CCR5 can't be assessed.
- Sample `8_PD1_PRE` is low quality. Removing it doesn't change the cohort-level conclusions.

To reproduce, run the scripts in `scripts/` in the order listed in the report.