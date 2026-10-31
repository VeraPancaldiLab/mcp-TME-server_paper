CellTFusion found two TME states in the Gide data, and one of them is clearly linked to response to immunotherapy. Patients high in the immune-inflamed state responded much more often, in both treatment arms.

**Pipeline:** your file is log2(TPM+1), but CellTFusion expects unlogged TPM, so I converted it back to TPM before running it. Cell-type deconvolution used quanTIseq, EpiDISH, DeconRNASeq and DWLS. CIBERSORTx was skipped because it needs login credentials. The pipeline built 12 groups of co-active transcription factors (TF modules) and 124 cell groups. It then tested 2 to 15 states, and 2 was the only number where every state was both stable and distinct (they were recovered in 99% and 93% of resampling runs).

**The two TME states**

| State | Driven by | Correlates with |
|---|---|---|
| **State 1 – immune-inflamed** | STAT1, IRF1, NF-κB, SPI1, RFX5 module | CD8 T cells (ρ = 0.82), M1 macrophages (0.70), B cells, Tregs; JAK-STAT, NF-κB and TNFα pathways (ρ ≈ 0.75–0.82) |
| **State 2 – stromal / TGF-β / hypoxic** | SMAD2/3, TCF21, CEBPB, EPAS1, ATF3 modules | Endothelial cells, fibroblasts, M2 macrophages, monocytes, mast cells; TGF-β and hypoxia pathways (ρ ≈ 0.56–0.58) |

**Link to response** (46 responders, 27 non-responders)
- **State 1 is higher in responders:** AUC 0.72, Wilcoxon p = 0.0018. The two treatment arms have different response rates (54% on anti-PD1 alone vs 75% with ipilimumab added), so I adjusted for therapy: odds ratio 3.1 per standard deviation (95% CI 1.4–6.9, p = 0.006). The effect doesn't differ by arm (AUC 0.73 for anti-PD1, 0.70 with ipilimumab).
- **Patients grouped by their main state:** 90% (28/31) of patients mostly in State 1 responded, against 43% (18/42) of those mostly in State 2 (Fisher p = 2.6e-5; still p = 9.4e-5 within therapy arms).
- **State 2** leans towards non-response, but not significantly (AUC 0.39, p = 0.12).
- **Finer levels agree:** the STAT1/IRF1 TF module, 22 of the 124 cell groups (all higher in responders) and the JAK-STAT, NF-κB and TNFα pathways are all significant after multiple-testing correction.
- **Low-quality sample:** sample `8_PD1_PRE` has only ~4.6k expressed genes, against a median of ~12k. Removing it doesn't change the results.

**Caveats:** this is one cohort with no outside validation. The "main state" grouping is just one way of splitting the continuous scores. `data/Riaz_log2TPM.txt` is already in your folder, so the next step would be to check whether these states predict response there too. I can set that up if you want.

Everything is in `results/`:
- **`results/README.md`:** a summary of the above.
- **`results/response_analysis/`:** my tables and figures (per-sample state scores, response tests, boxplots, state mixture plot, heatmap).
- **`results/Results/`:** the files CellTFusion writes itself.
- **`results/CellTFusion_Gide.rds`:** the full CellTFusion output.

The scripts that reproduce it are in `scripts/` and the logs in `logs/`.