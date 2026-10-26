# CellTFusion TME states vs immunotherapy response — Gide cohort

73 pre-treatment melanoma samples (46 R / 27 NR; PD1 alone 22 R / 19 NR; ipilimumab + PD1 24 R / 8 NR).

## Input preparation (`inputs/`)
- `data/Gide_log2TPM.txt` is log2(TPM + 1). It was converted back to linear TPM (2^x − 1). Each sample was then rescaled to sum to 1e6, because the per-sample totals over these 18,979 genes ranged from 41k to 730k.
- CellTFusion was run with `normalized=False`. Deconvolution used linear TPM; TF and pathway activity used log2(TPM + 1), computed internally.
- All 73 samples were kept. 8_PD1_PRE has a very low TPM total and is flagged; the conclusions don't change when it is removed.

## CellTFusion (`celltfusion/`)
- Settings: defaults, plus CIBERSORTx. Deconvolution methods: quanTIseq, EpiDISH, DeconRNASeq, DWLS and CIBERSORTx. TF network: CollecTRI with ulm.
- Output: 769 TFs scored, 11 WGCNA TF modules, 122 cell groups, and an NMF rank of 4 chosen by bootstrap. All 4 factors are robust (recovery 0.70–0.89).
- The CIBERSORTx token was masked in `celltfusion/manifest.json`.

## The 4 TME states (`association/Factor_characterization_*`)
Spearman correlations with TF modules, PROGENy pathways, quanTIseq fractions and key TFs; Benjamini–Hochberg (BH) adjusted p < 0.05.

| State | Main features | Interpretation |
|---|---|---|
| Factor1 | black TF module (ρ 0.95): IRF1, STAT1, TBX21, NFKB1, EOMES, FOXP3; quanTIseq CD8 (0.89); JAK-STAT, TNFa, NFkB | **Immune-inflamed / IFN-γ–cytotoxic** |
| Factor2 | purple/brown/green modules; SMAD3, TWIST1, HIF1A, AP-1; TGFb, PI3K, Hypoxia | **Mesenchymal / TGF-β–hypoxic stroma** |
| Factor3 | yellow + greenyellow modules; SOX10, MITF, MYC, E2F1; anti-TGFb | **Melanocytic / proliferative tumor** |
| Factor4 | turquoise + magenta modules; CTNNB1, p53 pathway; low CD8, EOMES, TBX21, JAK-STAT | **Immune-cold / β-catenin–associated** |

## Association with response (`association/`)
- **LatentFactors_vs_Response.csv** gives, for each factor: Wilcoxon tests overall and within each arm, AUC (values above 0.5 mean higher in responders), a logistic regression adjusted for therapy, and BH-adjusted p-values.

| State | AUC (all) | p | FDR | PD1 AUC (p) | ipi+PD1 AUC (p) | OR per SD, therapy-adjusted (p) |
|---|---|---|---|---|---|---|
| Factor1 inflamed | 0.72 | 0.0013 | 0.005 | 0.70 (0.027) | 0.77 (0.021) | 2.27 (0.014) |
| Factor4 cold | 0.30 | 0.0032 | 0.006 | 0.27 (0.012) | 0.35 (0.21) | 0.52 (0.027) |
| Factor2 TGF-β | 0.54 | 0.52 | 0.70 | — | — | n.s. |
| Factor3 melanocytic | 0.52 | 0.76 | 0.76 | — | — | n.s. |

- **DominantState_vs_Response.csv**: response rate by each patient's dominant state is 81% for Factor1 (17/21), 56% for Factor2, 65% for Factor3 and 36% for Factor4 (4/11). The global Fisher test gives p = 0.085.
- **CellGroups_vs_Response.csv**: 31 of the 122 cell groups pass FDR < 0.05. All the ones higher in responders come from the immune black/red modules (mostly Factor1). The ones higher in non-responders come from the turquoise/magenta modules (Factor4).
- Plots: boxplots, response-rate bars, cell-group volcano plot, characterization heatmap.

## Caveats
- These results come from a single cohort with no validation. The states were learned without using response, so the test itself is not circular. Even so, they should be replicated, for example in Riaz (`data/Riaz_log2TPM.txt`) using `score_celltfusion_test_set` and then `project_celltfusion_factors`.
- The ipilimumab + PD1 arm has only 8 non-responders, so the within-arm tests there have little power.

## Reproduce
`Rscript results/scripts/associate_tme_states_response.R results`. The CellTFusion call log is in `session_export/`.
