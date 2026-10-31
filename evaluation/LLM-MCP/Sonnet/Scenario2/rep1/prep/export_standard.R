## Reads already-produced CellTFusion/response-test results and re-exports them
## in a standard long/wide CSV format under results/standard/. No new
## computation: every value here already exists in result.rds or the CSVs
## already written to results/.

res <- readRDS("results/CellTFusion/result.rds")
out <- "results/standard"

## factor_scores.csv -- per-patient latent factor (TME state) scores
Z <- as.data.frame(res$Latent_spaces$Z)
Z <- cbind(patient = rownames(Z), Z)
write.csv(Z, file.path(out, "factor_scores.csv"), row.names = FALSE)

## tme_states.csv -- one row per state, with an annotation (only given for
## the state I characterized/presented, Factor1; others left NA since I did
## not produce an annotation for them)
states <- colnames(res$Latent_spaces$Z)
annotation <- setNames(rep(NA_character_, length(states)), states)
annotation["Factor1"] <- "Immune-enriched / lymphocyte-active TME program (driven by Tregs, B cells, NKT/activated NK cells, M1 macrophages, CD4 helper T cells)"
tme_states <- data.frame(state = states, annotation = unname(annotation[states]))
write.csv(tme_states, file.path(out, "tme_states.csv"), row.names = FALSE)

## response_tests.csv -- one row per state, from the Wilcoxon test I presented
## as the main result (TME_factors_vs_Response_stats.csv)
stats <- read.csv("results/Response_association/TME_factors_vs_Response_stats.csv")
higher_in <- ifelse(stats$median_R > stats$median_NR, "R",
              ifelse(stats$median_NR > stats$median_R, "NR", NA))
response_tests <- data.frame(
  state = stats$Factor,
  p_value = stats$p_wilcox,
  adjusted_p_value = stats$p_wilcox_BH,
  higher_in = higher_in
)
write.csv(response_tests, file.path(out, "response_tests.csv"), row.names = FALSE)

## tf_activity.csv -- TF activity matrix, one column per TF
tfs <- res$TFs_matrix
tfs <- cbind(patient = rownames(tfs), tfs)
write.csv(tfs, file.path(out, "tf_activity.csv"), row.names = FALSE)

## tf_modules.csv -- composition of TF modules: one row per TF, module + tf
tf_per_mod <- res$TF_network[["TFs per module"]]
tf_modules <- do.call(rbind, lapply(names(tf_per_mod), function(m) {
  data.frame(module = m, tf = tf_per_mod[[m]])
}))
write.csv(tf_modules, file.path(out, "tf_modules.csv"), row.names = FALSE)

## tf_module_scores.csv -- per-patient score of each TF module
mod_scores <- res$TF_network[["TFs module matrix"]]
mod_scores <- cbind(patient = rownames(mod_scores), mod_scores)
write.csv(mod_scores, file.path(out, "tf_module_scores.csv"), row.names = FALSE)

## pathway_scores.csv -- pathway activity, one column per pathway
paths <- res$Pathways_scores
paths <- cbind(patient = rownames(paths), paths)
write.csv(paths, file.path(out, "pathway_scores.csv"), row.names = FALSE)

## subgroups_composition.csv -- deconvolution subgroup composition: one row
## per member, subgroup + feature (the raw deconvolution feature it merges)
subcomp <- res$Processed_deconvolution[["Deconvolution subgroups composition"]]
rows <- list()
for (celltype in names(subcomp)) {
  for (subgroup in names(subcomp[[celltype]])) {
    feats <- subcomp[[celltype]][[subgroup]]
    rows[[length(rows) + 1]] <- data.frame(subgroup = subgroup, feature = feats)
  }
}
subgroups_composition <- do.call(rbind, rows)
write.csv(subgroups_composition, file.path(out, "subgroups_composition.csv"), row.names = FALSE)

## cell_groups.csv -- composition of cell groups: one row per member
comp <- res$Cell_groups$Composition
cell_groups <- do.call(rbind, lapply(names(comp), function(cg) {
  data.frame(cell_group = cg, feature = comp[[cg]])
}))
write.csv(cell_groups, file.path(out, "cell_groups.csv"), row.names = FALSE)

## cell_group_scores.csv -- per-patient score of each cell group
cg_scores <- res$Cell_groups$Cell_groups
cg_scores <- cbind(patient = rownames(cg_scores), cg_scores)
write.csv(cg_scores, file.path(out, "cell_group_scores.csv"), row.names = FALSE)

## info.json
info <- list(
  n_states = length(states),
  deconvolution_input_scale = "linear TPM",
  cibersortx = TRUE,
  test = "Wilcoxon rank-sum test",
  deconvolution_source = "computed inside CellTFusion"
)
writeLines(jsonlite::toJSON(info, auto_unbox = TRUE, pretty = TRUE), file.path(out, "info.json"))

cat("Done.\n")
