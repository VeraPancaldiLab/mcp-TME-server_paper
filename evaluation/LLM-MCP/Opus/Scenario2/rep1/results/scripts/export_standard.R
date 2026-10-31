# Convert existing CellTFusion / response-test outputs to a standard format (no recomputation)
r  <- readRDS("celltfusion/result.rds")
cd <- read.csv("inputs/Gide_coldata.csv", row.names = 1)
out <- "standard"
wpat <- function(M, f) {
  M <- as.data.frame(M)
  write.csv(data.frame(patient = rownames(M), M, check.names = FALSE), file.path(out, f), row.names = FALSE)
}
long <- function(lst, a, b) {
  d <- do.call(rbind, lapply(names(lst), function(n) data.frame(x = n, y = lst[[n]])))
  names(d) <- c(a, b); d
}
wpat(r$Latent_spaces$Z, "factor_scores.csv")
write.csv(data.frame(state = c("Factor1", "Factor2"),
  annotation = c("Myeloid/stromal state (monocytes, mast, plasma, endothelial, resting DC, cancer cells; black/yellow/magenta/blue TF modules)",
                 "Immune-active/interferon state (CD8, CD4, B cells, Tregs, M1/myeloid; green (STAT/IRF/TBX21/EOMES) and greenyellow TF modules)")),
  file.path(out, "tme_states.csv"), row.names = FALSE)
t <- read.csv("response_association/Latent_factors_vs_Response_stats.csv")
write.csv(data.frame(state = t$feature, p_value = t$p_value, adjusted_p_value = t$FDR_BH, higher_in = t$higher_in),
  file.path(out, "response_tests.csv"), row.names = FALSE)
wpat(r$TFs_matrix, "tf_activity.csv")
write.csv(long(r$TF_network[["TFs per module"]], "module", "tf"), file.path(out, "tf_modules.csv"), row.names = FALSE)
wpat(r$TF_network[["TFs module matrix"]], "tf_module_scores.csv")
wpat(r$Pathways_scores, "pathway_scores.csv")
sc <- unlist(unname(r$Processed_deconvolution[["Deconvolution subgroups composition"]]), recursive = FALSE)
write.csv(long(sc, "subgroup", "feature"), file.path(out, "subgroups_composition.csv"), row.names = FALSE)
write.csv(long(r$Cell_groups$Composition, "cell_group", "feature"), file.path(out, "cell_groups.csv"), row.names = FALSE)
wpat(r$Cell_groups$Cell_groups, "cell_group_scores.csv")
writeLines(jsonlite::toJSON(list(n_states = 2L, deconvolution_input_scale = "linear TPM", cibersortx = TRUE,
  test = "Wilcoxon rank-sum test (R vs NR), BH-adjusted", deconvolution_source = "computed inside CellTFusion"),
  auto_unbox = TRUE, pretty = TRUE), file.path(out, "info.json"))
# sanity checks
for (f in list.files(out, "csv$")) { d <- read.csv(file.path(out, f), check.names = FALSE); cat(f, dim(d), names(d)[1:2], "\n") }
cat("patients match input:", setequal(read.csv(file.path(out, "factor_scores.csv"))$patient,
  colnames(read.delim("../data/Gide_log2TPM.txt", check.names = FALSE, nrows = 1))[-1]), "\n")
m <- read.csv(file.path(out, "tf_modules.csv")); cat("modules in scores:", all(unique(m$module) %in% names(read.csv(file.path(out, "tf_module_scores.csv")))), "\n")
cg <- read.csv(file.path(out, "cell_groups.csv")); cat("cell groups in scores:", all(unique(cg$cell_group) %in% names(read.csv(file.path(out, "cell_group_scores.csv"), check.names = FALSE))), "\n")
