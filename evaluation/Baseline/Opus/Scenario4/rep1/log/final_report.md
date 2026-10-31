I ran RaCInG on all 73 pre-treatment Gide samples. The main pattern: tumor (non-immune) cells talking to themselves and with monocytes, neutrophils, NK cells and B cells. Most of that pattern comes from how many of each cell type are present. Everything is in `results/`, with a `results/README.md` describing the files.

## How I ran it
- **Input:** I converted the log2(TPM+1) data back to linear TPM, as RaCInG requires.
- **Cell fractions:** I used quanTIseq only. RaCInG's default combines several methods and gives 100+ cell-type features that are hard to interpret; quanTIseq gives 11.
- **Method:** the kernel method, which computes direct communication exactly with no random simulation. Scores are the share of each patient's communication going from a sender to a receiver cell type, weighted by how abundant each is.
- **Ligand–receptor breakdown:** I split every cell-type pair's score into its ligand–receptor pairs. The parts sum back to the totals exactly; the script checks this.

**A problem I had to work around:** with RaCInG's default settings, the tumor/non-immune compartment (about 63% of cells) was silently dropped. A naming mismatch in multideconv, the deconvolution package RaCInG uses, caused this. The immune fractions were then rescaled to fill 100%, which inflated them (e.g. 76% neutrophils in one sample). I computed the fractions myself and passed them in so that compartment is kept (labelled "Cancer/non-immune"). I also had to prefix sample IDs, because names starting with a digit broke sample matching; the outputs use the original IDs.

## Most common interactions (directed, median % of each patient's total)
| # | Interaction | Median % | % of patients where it's in their top 5 |
|---|---|---|---|
| 1 | Cancer → Cancer | 9.1 | 89 |
| 2 | Monocytes → Cancer | 5.5 | 59 |
| 3 | Cancer → Monocytes | 4.7 | 52 |
| 4 | Cancer → Neutrophils | 2.8 | 44 |
| 5 | Monocytes → Monocytes | 2.7 | 47 |
| 6 | Neutrophils → Cancer | 2.7 | 47 |
| 7–9 | NK → Cancer, B → Cancer, Cancer → NK | 1.7–2.4 | — |

- **Each patient's single strongest interaction** is Cancer → Cancer in 53% of patients, Monocytes → Monocytes in 23% and Neutrophils → Neutrophils in 21%.
- **Beyond what abundance predicts:** Cancer → Cancer is 2.2× higher than a baseline where all ligand–receptor pairs are equally strong. Tumor exchanges with neutrophils, monocytes and B cells are 1.3–1.6× higher.
- **Patient groups:** clustering patients splits them into tumor-centred groups dominated by monocytes/NK/B cells, by neutrophils, or by macrophages (M1/M2).
- **T cells and dendritic cells** contribute almost nothing. CD8 T cells and Tregs are under 0.5% each; CD4 helper T cells and dendritic cells have a median abundance of zero.

## Most common ligand–receptor pairs
Communication is spread across about 1,700 pairs, so no single pair accounts for more than about 0.3% of the total. The pairs that most often rank in a patient's top 20 are:
- APP–RPSA, CD99–CD81 and COL3A1–ITGB1 (86–95% of patients), mostly within the tumor/non-immune compartment.
- TYROBP–CD44, APP–TYROBP, APP–CD74, SPP1–CD44, SPP1–ITGB1 and APOE–TYROBP: two-way tumor–myeloid signalling.
- VEGFA–ITGB1, VEGFA–NRP2, and collagen/VCAN/LGALS1 binding the ITGB1 integrin: matrix and blood-vessel signalling.

## Limitations
- **Cell-type rankings mostly follow quanTIseq's abundance estimates.** quanTIseq's "other" fraction mixes tumor cells with stroma, which is why COL3A1 and POSTN show up as "Cancer" ligands.
- **Ligand–receptor pairs assigned to rare immune cells are unreliable.** They depend on estimated cell-type expression profiles, and some are biologically implausible: ANGPTL3 (a liver gene) from B cells, PDGFD and LAMA2 from NK cells. Ligand–receptor results for the tumor, monocyte and neutrophil interactions are more trustworthy.
- **Not done:** I didn't run RaCInG's Monte Carlo simulation, which gives the same direct-communication results with sampling noise. I also didn't compare responders with non-responders, although the patient heatmap is labelled by response and therapy. Either can be added if you want.

Scripts are in `scripts/`; the most useful results are:
- `summary/celltype_pairs_directed_ranking.csv`
- `lr_contributions/lr_pairs_global_ranking.csv`
- `figures/heatmap_directed_communication_median.png`
- `figures/heatmap_patients_top30_interactions.png`