# CellTFusion – Gide cohort (73 pre-treatment melanoma, anti-PD1 ± anti-CTLA4)

Scripts: `../scripts/01_run_celltfusion.R`, `02_response_association.R`, `03_characterize_tme_states.R` (run from the project root).

## Input handling
- `Gide_log2TPM.txt` is log2(TPM+1) on ~19k genes. It was back-transformed (2^x − 1), re-closed to 1e6 per sample, and passed with `normalized = FALSE`.
- Deconvolution: Quantiseq, Epidish, DeconRNASeq, DWLS. CIBERSORTx was skipped because there were no credentials.
- Everything else uses CellTFusion defaults (CollecTRI/ulm, PROGENy, seed 123).

## Contents
- `CellTFusion_Gide.rds`: the full `CellTFusion()` output object.
- `Results/`: native CellTFusion outputs:
  - deconvolution, TF activity, TF modules, PROGENy, cell groups, NMF, niches
  - Wilcoxon plots for the cell groups that were significant
- `response_association/`: R vs NR tests of TF modules, cell groups, NMF factors, PROGENy and the dominant TME state per patient.
  - Tests used: Wilcoxon + AUC, therapy-stratified Wilcoxon, and logistic regression adjusted for therapy. BH is applied within each feature set.
- `tme_states_characterization/`: correlation of each factor with deconvolution features, TFs and PROGENy, plus each TF module's share of the NMF weights.
- `*.log`: console output of each step.

## TME states (bootstrap NMF, selected rank 3, all factors robust)
| State | Main TF modules | Biology | Response |
|---|---|---|---|
| Factor1 | black (IRF/STAT4/TBX21/CIITA/BATF), red | Immune-inflamed: CD8/CD4 T, B/plasma, macrophages; JAK-STAT, NFkB, TNFa | Higher in R: AUC 0.72, q = 0.004; therapy-adjusted OR/SD 2.9, q = 0.017. 20/22 patients dominated by this state responded |
| Factor2 | blue, green, brown, purple | Stromal/TGFb: CAFs, fibroblasts, endothelium, M2 macrophages; TGFb, hypoxia, PI3K | No association (AUC 0.50) |
| Factor3 | turquoise, pink, greenyellow, yellow | Tumour-intrinsic / immune-low: cancer-cell signal; NFkB, TNFa and JAK-STAT all low | Higher in NR: AUC 0.35, Wilcoxon q = 0.052; therapy-adjusted q = 0.029. 11/25 patients responded |
