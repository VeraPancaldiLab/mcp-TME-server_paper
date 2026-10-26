**1. Input data transformation**

- `data/Gide_log2TPM.txt` held values from 0 to 14.0 and was non-integer and non-negative, which fits log2(TPM+1). I converted it to linear TPM (2^x − 1) for all RaCInG steps, because both the internal deconvolution and the `expr_threshold` comparison expect linear TPM.
- The back-transformed per-sample totals were about 41k–730k, not 1e6. I assumed this was because only about 19k genes are present, and I did **not** renormalize to 1e6.
- I prefixed sample IDs with `Gide_` because names starting with a digit broke the name matching (see 4).
- No log-scale steps were run, so the log2 values were never used directly.

**2. Methods run and skipped**

- **Run:**
  - `prepare_racing_inputs`: its internal quanTIseq run, then supplied compositions afterwards.
  - `run_racing_kernel`, both raw (`norm=FALSE`) and normalized (`norm=TRUE`), for D, W, TT and GSCC.
  - `run_racing_montecarlo`: a single-patient pilot through the MCP tool. The full 73-patient run used RaCInG's `compute_racing_montecarlo` directly in a background Rscript, because the MCP call blocks and would take hours.
  - `explain_lr_contributions` for Cancer–Cancer, Cancer–Mono and Cancer–Neutro.
  - My own R scripts: cohort summaries, wedge recomputation, Ward clustering with silhouette and bootstrap, PCA axis, sensitivity, bootstrap and outlier analyses.
- **Skipped or incomplete:**
  - Other deconvolution methods: I used only quanTIseq, RaCInG's default, and did no robustness check across deconvolution methods.
  - Signed networks: kept the default `signed=FALSE`.
  - `explain_lr_contributions` for Cancer–CD8 and for the Cancer–Mono–Cancer wedge: these were OOM-killed and never rerun.
  - `03_robustness_montecarlo.R`: written but **never executed**.
  - I did not use the Riaz file, and did no survival or ML analysis.

**3. Non-default parameters**

- **Main run:**
  - `already_normalized=TRUE`, since the input was linear TPM.
  - `deconv_csv`: a custom quanTIseq composition with the "uncharacterized" fraction renamed `Cancer`, so tumor cells are part of the network.
  - That composition had fractions below 0.001 set to 0 and was renormalized. This was my preprocessing choice to stop raw W/TT values from exploding; it is not a RaCInG parameter.
- **Sensitivity runs:**
  - `fun_lr=prod` (default `min`).
  - `expr_threshold=5` and `expr_threshold=20` (default 10).
  - An immune-only composition.
- **Monte Carlo:**
  - `Ngraphs=20` (default 100), for compute time.
  - `ncores=6` (default 1); 12 workers ran out of memory.
  - Pilots used 20 and 5 graphs.
- `norm` was set both ways, to get raw magnitude and enrichment.

**4. Problems and how I handled them**

- **Sample-name mismatch error:** RaCInG added an "X" to names starting with digits. I renamed samples with a `Gide_` prefix and saved an ID map.
- **Tumor cells missing:** the internal quanTIseq run dropped the tumor/other fraction, so the network was immune-only. I supplied my own composition that includes it.
- **Exploding raw values:** raw TT values reached about 1e11, caused by abundances near zero (for example 1e-16) in the denominator. I applied the 0.001 floor; some remaining TT outliers come from rare cell types, so I summarize with medians and ranks.
- **Suspected RaCInG wedge bug:** the kernel's wedge enumeration gives uneven numbers of features per hub cell type, with 220 of 726 wedges missing and some duplicated. I found this by reading the code. I recomputed wedges from the kernel arrays using the same formula.
- **Monte Carlo crashes from memory:**
  - 12 workers crashed. I relaunched with 6 workers.
  - I stopped the second run deliberately after finding the tiny-abundance problem, and relaunched it on the floored inputs.
  - Orphaned workers were killed by PID; `pkill` also killed my own shell twice (exit 144).
- **Lost connection on the threshold-5 input run (S2):** the output files existed, and I validated `result.rds` before using it.
- **OOM-killed LR explanations** while Monte Carlo was running: two were not retried, as noted in 2.
- **My final wait command was killed (exit 137).** I never confirmed whether the Monte Carlo run finished.

**5. Checks before trusting results**

- Checked the expression scale.
- Confirmed composition rows sum to 1.
- Reproduced RaCInG's D values from the kernel by hand.
- My wedges match RaCInG's to within 1e-14 on the 506 wedges both enumerations share.
- Determined the Monte Carlo wedge hub position by matching the pilot to the kernel (Spearman 0.999).
- Ran 4 sensitivity scenarios: cohort rankings had Spearman 0.91–0.998, and the top feature was unchanged in every scenario.
- Bootstrapped patients 1000 times to test top-10 stability.
- Excluded 3 outlier samples: ranking Spearman stayed at or above 0.98.
- Checked the patient axis (PC1) across scenarios and 500 bootstraps: Spearman at or above 0.996.

**6. Limits and cautions**

- **Monte Carlo robustness is not done:** the run's completion is unknown and its analysis was never run, so robustness to random network realizations is unassessed.
- **The "Cancer" node is not purely tumor:** it is quanTIseq's uncharacterized fraction, which includes stroma and other unmodeled cells.
- **CD4 and DC sit at a median abundance of 0**, so they are effectively absent; that is a deconvolution limitation.
- **Patient clusters are weak:**
  - The k=2 silhouette is 0.30.
  - Cluster assignment collapsed under `fun_LR=prod` (ARI 0.10).
  - Use the continuous neutrophil-to-monocyte axis instead of the clusters.
- **Normalized and immune-only features are less stable**, with a patient-level ρ as low as 0.65–0.71 in the immune-only scenario.
- **The 0.001 abundance floor and the wedge fix are my own choices,** not RaCInG defaults.
- **Response associations were not significant** (p=0.13 and 0.30) and are exploratory only.
- **No final report or README was written.** `results/` still holds superseded or temporary runs that are not part of the final results: `01_racing_inputs`, `02_racing_inputs_with_tumor`, `03_kernel`, `04_kernel_raw` and the `tmp_mc_pilot*` folders.