CellTFusion found three TME states in the Gide cohort, and two of them are linked to immunotherapy response: an immune-inflamed state goes with response, and a tumour-intrinsic, immune-low state goes with non-response. The pipeline and all downstream scripts ran without errors, and everything is saved in `results/`.

**Setup.** Your file is log2(TPM+1), but CellTFusion needs raw counts or un-logged TPM. I back-transformed it, rescaled each sample to sum to 1e6 over its ~19k genes, and ran with `normalized = FALSE`. Deconvolution used Quantiseq, Epidish, DeconRNASeq and DWLS; CIBERSORTx was skipped because there were no credentials. Everything else was left at CellTFusion defaults (CollecTRI, PROGENy, seed 123).

**What the pipeline built:** 11 TF modules, 121 cell groups, and 3 NMF factors (the TME states). Bootstrap selected rank 3 as the largest rank where all factors are stable.

| State | Biology | Response (27 NR vs 46 R) |
|---|---|---|
| **Factor1**: immune-inflamed | Immune TF module (IRF1/4, STAT4, TBX21, CIITA, BATF); CD8/CD4 T cells, B/plasma cells, macrophages; JAK-STAT, NFkB, TNFa | **Higher in responders**: AUC 0.72, FDR q = 0.004. Still holds after adjusting for therapy (OR 2.9 per SD, q = 0.017). 20 of 22 patients dominated by this state responded |
| **Factor2**: stromal / TGFb | CAFs, fibroblasts, endothelium, M2 macrophages; TGFb, hypoxia, PI3K (SMAD/TWIST1 TFs) | No association (AUC 0.50) |
| **Factor3**: tumour-intrinsic, immune-low | Cancer-cell signal, MITF-containing module; NFkB, TNFa and JAK-STAT all low | **Higher in non-responders**: AUC 0.35, q = 0.052; therapy-adjusted q = 0.029. 11 of 25 patients dominated by this state responded |

The same pattern shows at the finer levels:
- **TF modules:** the immune module (black, q = 0.004) and the red module (q = 0.03) are higher in responders.
- **Cell groups:** 23 of 121 pass FDR. Of these, 21 are higher in responders (from the immune and red modules, plus two blue) and 2 are higher in non-responders (from the turquoise module).
- **Patient-level states:** assigning each patient their dominant state is also associated with response (Fisher p = 0.002).

**Caveats:**
- **No validation yet.** This is a single cohort of 73 patients. `data/Riaz_log2TPM.txt` is available for an independent check if you want one.
- **Therapy imbalance.** Responders are enriched in the ipi+PD1 arm (24/32 vs 22/41; p = 0.09). That's why every test also has a therapy-adjusted logistic model and a test within each therapy arm. Factor1 stays significant either way; Factor3's signal comes mostly from the ipi+PD1 arm.
- **Dominant-state Fisher test was my own addition.** It is a post-hoc grouping of the NMF mixtures, not a built-in CellTFusion output. The per-factor tests are the primary result.
- **Factor3 is the least clean state.** It leans on the turquoise module, which explains only 9.5% of its TFs' variance. One of its top correlates (activated memory CD4 from LM22/DeconRNASeq) looks like a tumour-cell artifact.
- **One low-quality sample.** `8_PD1_PRE` had very low protein-coding TPM (about 4% of a typical sample before rescaling). I kept it; it is a non-responder assigned to Factor3.

**Where things are** (all in `results/`):
- `README.md` summarises the analysis.
- `CellTFusion_Gide.rds` is the full pipeline output.
- `Results/` holds CellTFusion's own output files, which it always writes to that folder name.
- `response_association/` has the statistics tables and plots.
- `tme_states_characterization/` describes what each state is made of.
- The three scripts are in `scripts/`, and each step's log is in `results/`.