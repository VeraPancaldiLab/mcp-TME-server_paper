# CellTFusion TME states – Gide cohort (anti-PD1 ± anti-CTLA4, pre-treatment melanoma)

73 samples (46 R / 27 NR; 41 PD1, 32 CTLA4+PD1). Scripts: `../scripts/01_run_celltfusion.R`, `../scripts/02_states_and_response.R`.

## Pipeline
- Input `Gide_log2TPM.txt` was back-transformed to TPM (2^x − 1) and run with `CellTFusion(normalized = FALSE)` (the package expects non-log TPM).
- Deconvolution: quanTIseq, EpiDISH, DeconRNASeq, DWLS (CIBERSORTx skipped: no credentials). TF activity: CollecTRI + decoupleR ulm. Pathways: PROGENy.
- 12 TF modules (WGCNA, soft power 9) → 124 cell groups → bootstrap NMF selected **rank 2** (only rank with all factors robust and none redundant; recovery 0.99 / 0.93).

## TME states
| State | Driven by | Correlates with |
|---|---|---|
| **TME_state1 – immune-inflamed** | green module (hubs STAT1, IRF1, NFKB1, RELA, REL, SPI1, RFX5), greenyellow, magenta | CD8 T (ρ=0.82), M1 macrophages (0.70), Tregs, B cells; JAK-STAT (0.82), NFkB (0.80), TNFa (0.75) |
| **TME_state2 – stromal / TGF-β-hypoxic** | yellow (hubs SMAD2/3, TCF21, GATA4), black (CEBPB, TP53), red (ATF3, EGR1, EPAS1), blue | Endothelial, fibroblasts, M2 macrophages, monocytes, mast cells; TGFb (0.58), Hypoxia (0.56) |

## Association with response
- **TME_state1 is higher in responders**: AUC 0.72, Wilcoxon p = 0.0018 (BH 0.0036); OR per SD = 3.08 (95% CI 1.38–6.87, p = 0.006) adjusted for therapy; no therapy interaction (p = 0.28). Same direction in both arms (AUC 0.73 PD1, 0.70 ipi+PD1). Robust to removing low-complexity sample 8_PD1_PRE.
- TME_state2 trends towards non-response (AUC 0.39, p = 0.12) – not significant.
- Dominant state: 28/31 (90%) state1-dominant patients responded vs 18/42 (43%) state2-dominant; Fisher p = 2.6e-5, therapy-stratified exact test p = 9.4e-5.
- Lower levels agree: green TF module (BH p = 0.008), 22/124 cell groups (all green/greenyellow-related, higher in R), PROGENy JAK-STAT/NFkB/TNFa (BH p ≤ 0.007).

Caveats: single cohort, no external validation (e.g. Riaz in `data/` could be projected); the states are unsupervised, but the dominant-state cut is one of several ways to dichotomize them.

## Files
- `CellTFusion_Gide.rds` – full CellTFusion output object; `Gide_coldata.rds` – matched clinical data.
- `Results/` – files written by CellTFusion itself (deconvolution, TF/pathway matrices, TF modules, cell groups, NMF rank stability, niches, Wilcoxon plots of significant features).
- `response_analysis/` – state scores per sample, cell-group weights, characterization correlations, hub TFs, response tests (`Response_*.csv/.txt`) and figures.
