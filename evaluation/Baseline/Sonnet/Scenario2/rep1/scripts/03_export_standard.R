#!/usr/bin/env Rscript
# Convert already-produced CellTFusion results (results/CellTFusion_Gide_full_result.rds,
# results/clinical_log.txt outputs) into a standard, comparable format under results/standard/.
# No new computation: only reformatting of existing objects.

res <- readRDS("/home/marcelo.hurtado/Documents/tme_analysis/10d0ef4104/work/results/CellTFusion_Gide_full_result.rds")

out_dir <- "/home/marcelo.hurtado/Documents/tme_analysis/10d0ef4104/work/results/standard"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

write_patient_csv <- function(mat, path) {
  df <- data.frame(patient = rownames(mat), as.data.frame(mat), check.names = FALSE)
  write.csv(df, path, row.names = FALSE)
}

## 1. factor_scores.csv -------------------------------------------------
write_patient_csv(res$Latent_spaces$Z, file.path(out_dir, "factor_scores.csv"))

## 2. tme_states.csv -----------------------------------------------------
tme_states <- data.frame(
  state = c("Factor1", "Factor2"),
  annotation = c(
    "Immune-infiltrated state (T cells, B/plasma cells, macrophages/myeloid cells; driven by the green TF module)",
    "Not immune-infiltration dominated (no further subtype annotation produced)"
  )
)
write.csv(tme_states, file.path(out_dir, "tme_states.csv"), row.names = FALSE)

## 3. response_tests.csv (main test presented: Wilcoxon rank-sum) --------
response_tests <- data.frame(
  state = c("Factor1", "Factor2"),
  p_value = c(0.001814791, 0.124267841),
  adjusted_p_value = c(0.003629582, 0.124267841),
  higher_in = c("R", "NR")
)
write.csv(response_tests, file.path(out_dir, "response_tests.csv"), row.names = FALSE)

## 4. tf_activity.csv ------------------------------------------------------
write_patient_csv(res$TFs_matrix, file.path(out_dir, "tf_activity.csv"))

## 5. tf_modules.csv (module, tf) -------------------------------------------
tfs_per_module <- res$TF_network[["TFs per module"]]
tf_modules <- do.call(rbind, lapply(names(tfs_per_module), function(mod) {
  data.frame(module = mod, tf = tfs_per_module[[mod]])
}))
write.csv(tf_modules, file.path(out_dir, "tf_modules.csv"), row.names = FALSE)

## 6. tf_module_scores.csv --------------------------------------------------
write_patient_csv(res$TF_network[["TFs module matrix"]], file.path(out_dir, "tf_module_scores.csv"))

## 7. pathway_scores.csv -----------------------------------------------------
write_patient_csv(res$Pathways_scores, file.path(out_dir, "pathway_scores.csv"))

## 8. subgroups_composition.csv (subgroup, feature) --------------------------
subgroup_comp <- res$Processed_deconvolution[["Deconvolution subgroups composition"]]
rows <- list()
for (celltype in names(subgroup_comp)) {
  subgroups <- subgroup_comp[[celltype]]
  for (sg_name in names(subgroups)) {
    rows[[length(rows) + 1]] <- data.frame(subgroup = sg_name, feature = subgroups[[sg_name]])
  }
}
subgroups_composition <- do.call(rbind, rows)
write.csv(subgroups_composition, file.path(out_dir, "subgroups_composition.csv"), row.names = FALSE)

## 9. cell_groups.csv (cell_group, feature) -----------------------------------
cg_composition <- res$Cell_groups$Composition
cell_groups <- do.call(rbind, lapply(names(cg_composition), function(cg) {
  data.frame(cell_group = cg, feature = cg_composition[[cg]])
}))
write.csv(cell_groups, file.path(out_dir, "cell_groups.csv"), row.names = FALSE)

## 10. cell_group_scores.csv --------------------------------------------------
write_patient_csv(res$Cell_groups$Cell_groups, file.path(out_dir, "cell_group_scores.csv"))

## 11. info.json ---------------------------------------------------------
info <- list(
  n_states = ncol(res$Latent_spaces$Z),
  deconvolution_input_scale = "linear TPM",
  cibersortx = FALSE,
  test = "wilcox",
  deconvolution_source = "computed inside CellTFusion"
)
jsonlite_available <- requireNamespace("jsonlite", quietly = TRUE)
if (jsonlite_available) {
  jsonlite::write_json(info, file.path(out_dir, "info.json"), auto_unbox = TRUE, pretty = TRUE)
} else {
  json_txt <- sprintf(
    '{\n  "n_states": %d,\n  "deconvolution_input_scale": "%s",\n  "cibersortx": %s,\n  "test": "%s",\n  "deconvolution_source": "%s"\n}\n',
    info$n_states, info$deconvolution_input_scale, tolower(as.character(info$cibersortx)), info$test, info$deconvolution_source
  )
  writeLines(json_txt, file.path(out_dir, "info.json"))
}

cat("Standard export done. Files in", out_dir, ":\n")
print(list.files(out_dir))
