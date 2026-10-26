## Pure format-conversion script: reads only files already present under results/,
## reshapes them into the requested standard layout, writes to results/standard/.
## No new computation (no stats, no model refit) is performed here.

RES <- "/home/marcelo.hurtado/Documents/tme_analysis/2bf9b0464f/work/results"
OUT <- file.path(RES, "standard")
CT  <- file.path(RES, "CellTFusion")

with_patient <- function(df) {
  out <- data.frame(patient = rownames(df), df, check.names = FALSE)
  rownames(out) <- NULL
  out
}

## 1. factor_scores.csv -- NMF latent factor (TME state) scores per patient
z <- read.csv(file.path(CT, "NMF_latent_factors_Z.csv"), row.names = 1, check.names = FALSE)
write.csv(with_patient(z), file.path(OUT, "factor_scores.csv"), row.names = FALSE)

## 2. tme_states.csv -- one row per TME state with an annotation
## Only Factor1 was characterized in the presented analysis (immune-active program,
## significantly higher in responders); Factor2-4 were not individually annotated.
tme_states <- data.frame(
  state = colnames(z),
  annotation = c(
    "immune-active TME program: elevated B cells, CD4/CD8 T cells, NK cells and plasma cells co-activated with their TF modules (green/greenyellow); lower M1/M2 macrophages and monocytes; significantly higher in immunotherapy responders",
    "", "", ""
  )
)
write.csv(tme_states, file.path(OUT, "tme_states.csv"), row.names = FALSE)

## 3. response_tests.csv -- one row per TME state: p-value, BH-adjusted p-value, direction
stats <- read.csv(file.path(RES, "response_association", "Response_association_stats.csv"))
factor_stats <- stats[stats$type == "NMF_latent_factor", ]
response_tests <- data.frame(
  state = factor_stats$feature,
  p_value = factor_stats$p_value,
  adjusted_p_value = factor_stats$padj_BH,
  higher_in = ifelse(factor_stats$median_R > factor_stats$median_NR, "R", "NR")
)
response_tests <- response_tests[match(colnames(z), response_tests$state), ]
write.csv(response_tests, file.path(OUT, "response_tests.csv"), row.names = FALSE)

## 4. tf_activity.csv -- TF activity matrix, one column per TF
tfs <- read.csv(file.path(CT, "result_TFs_matrix.csv"), row.names = 1, check.names = FALSE)
write.csv(with_patient(tfs), file.path(OUT, "tf_activity.csv"), row.names = FALSE)

## 5. tf_modules.csv -- TF module composition, one row per TF (module, tf)
tf_mod_raw <- read.csv(file.path(CT, "Results", "TFs_modules_Gide_CellTFusion.csv"),
                        check.names = FALSE, stringsAsFactors = FALSE)
colnames(tf_mod_raw) <- c("module", "composition")
tf_modules <- do.call(rbind, lapply(seq_len(nrow(tf_mod_raw)), function(i) {
  tfs_i <- strsplit(tf_mod_raw$composition[i], ",")[[1]]
  data.frame(module = tf_mod_raw$module[i], tf = tfs_i, stringsAsFactors = FALSE)
}))
write.csv(tf_modules, file.path(OUT, "tf_modules.csv"), row.names = FALSE)

## 6. tf_module_scores.csv -- TF module score per patient, one column per module
tf_mod_scores <- read.csv(file.path(CT, "Results", "TF_module_matrix_Gide_CellTFusion.csv"),
                           row.names = 1, check.names = FALSE)
write.csv(with_patient(tf_mod_scores), file.path(OUT, "tf_module_scores.csv"), row.names = FALSE)

## 7. pathway_scores.csv -- pathway activity, one column per pathway
paths <- read.csv(file.path(CT, "result_Pathways_scores.csv"), row.names = 1, check.names = FALSE)
write.csv(with_patient(paths), file.path(OUT, "pathway_scores.csv"), row.names = FALSE)

## 8. subgroups_composition.csv -- deconvolution subgroup composition (subgroup, feature)
subgr_raw <- read.csv(file.path(CT, "Results", "Cell_subgroups_Gide_CellTFusion.csv"),
                       check.names = FALSE, stringsAsFactors = FALSE)
colnames(subgr_raw) <- c("subgroup", "composition")
subgroups_composition <- do.call(rbind, lapply(seq_len(nrow(subgr_raw)), function(i) {
  feats <- strsplit(subgr_raw$composition[i], "\n")[[1]]
  feats <- trimws(feats)
  feats <- feats[feats != ""]
  data.frame(subgroup = subgr_raw$subgroup[i], feature = feats, stringsAsFactors = FALSE)
}))
write.csv(subgroups_composition, file.path(OUT, "subgroups_composition.csv"), row.names = FALSE)

## 9. cell_groups.csv -- cell group composition (cell_group, feature)
cg_raw <- read.csv(file.path(CT, "Results", "Cell.groups.composition_Gide_CellTFusion.csv"),
                    check.names = FALSE, stringsAsFactors = FALSE)
colnames(cg_raw) <- c("cell_group", "composition")
cell_groups <- do.call(rbind, lapply(seq_len(nrow(cg_raw)), function(i) {
  feats <- strsplit(cg_raw$composition[i], "\n")[[1]]
  feats <- trimws(feats)
  feats <- feats[feats != ""]
  data.frame(cell_group = cg_raw$cell_group[i], feature = feats, stringsAsFactors = FALSE)
}))
write.csv(cell_groups, file.path(OUT, "cell_groups.csv"), row.names = FALSE)

## 10. cell_group_scores.csv -- cell group score per patient, one column per cell group
cg_scores <- read.csv(file.path(CT, "Results", "Cell.groups.scores_Gide_CellTFusion.csv"),
                       row.names = 1, check.names = FALSE)
write.csv(with_patient(cg_scores), file.path(OUT, "cell_group_scores.csv"), row.names = FALSE)

## 11. info.json
info <- list(
  n_states = ncol(z),
  deconvolution_input_scale = "linear TPM",
  cibersortx = TRUE,
  test = "Wilcoxon rank-sum test",
  deconvolution_source = "computed inside CellTFusion"
)
writeLines(jsonlite::toJSON(info, auto_unbox = TRUE, pretty = TRUE), file.path(OUT, "info.json"))

cat("Done.\n")
