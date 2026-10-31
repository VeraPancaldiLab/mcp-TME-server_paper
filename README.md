# mcp-TME-server_paper

Paper and evaluation materials for [mcp-tme-servers](https://github.com/VeraPancaldiLab/mcp-tme-servers), five MCP servers that wrap the R packages multideconv, CellTFusion, pipeML, RaCInG and Bioinfo-tools for tumour microenvironment (TME) analysis of bulk RNA-seq.

## What is evaluated

The benchmark asks whether an LLM agent reproduces what a human analyst gets, with and without the MCP layer. Each run is one **arm** (Baseline or LLM-MCP) × **model** (Claude Opus or Sonnet) × **scenario** × repetition. The two arms get the same prompt, the same data and the same R packages. The only difference is whether the five MCP servers are available. In the Baseline arm the agent writes and runs its own R code.

| Scenario | Prompt (summary) | Package | Criteria compared with the ground truth |
|---|---|---|---|
| 1 | Immune and stromal composition, which patients are more immune infiltrated | multideconv | Methods run, parameters, raw deconvolution features, subgroups (composition and values), patient ranking |
| 2 | TME states and their relation to immunotherapy response | CellTFusion | TF activity scores, TF modules (composition, scores), cell groups (composition, scores), TME states, states associated with response |
| 3 | Predict immunotherapy response and the features driving it (train on Gide, test on Riaz) | multideconv, pipeML | Cross-validation AUROC per algorithm, AUROC on the test cohort, top 10 and 20 predictive features |
| 4 | Cell-cell communication and the most common interaction pairs | RaCInG | Ligand assignments, receptor assignments, direct interactions, most common interactions |

Every score is **reproduced ÷ ground-truth total**, so anything a run lacks lowers its score. Values are the same when they are identical or correlate at 0.9 or more across patients. Groups (subgroups, TF modules, cell groups) are the same when they have exactly the same members, whatever their name.
