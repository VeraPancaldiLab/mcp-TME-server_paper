#!/usr/bin/env Rscript
## Converts already-produced CellTFusion results (results/, results/Results/)
## into a standard, patient-row CSV format in results/standard/.
## No analysis is rerun: every value here already exists in those files.

work_dir <- "/home/marcelo.hurtado/Documents/tme_analysis/2cbab8b568/work"
setwd(work_dir)
res_dir <- file.path(work_dir, "results")
pkg_dir <- file.path(res_dir, "Results")
out_dir <- file.path(res_dir, "standard")
dir.create(out_dir, showWarnings = FALSE)

## ---- Map make.names()-converted sample names back to the original ones ----
orig_names <- colnames(read.table(file.path(work_dir, "data/Gide_log2TPM.txt"),
                                   header = TRUE, sep = "\t", nrows = 1, check.names = FALSE))
name_map <- setNames(orig_names, make.names(orig_names))
restore_patients <- function(df) {
  df <- data.frame(patient = name_map[rownames(df)], df, row.names = NULL, check.names = FALSE)
  df
}
read_matrix_csv <- function(path) read.csv(path, row.names = 1, check.names = FALSE)

## ---- factor_scores.csv : latent factor (TME state) scores per patient ----
Z <- read_matrix_csv(file.path(res_dir, "TME_states_latent_factor_scores.csv"))
write.csv(restore_patients(Z), file.path(out_dir, "factor_scores.csv"), row.names = FALSE)

## ---- tme_states.csv : one row per TME state, with its cell-niche annotation ----
summary_tbl <- read.csv(file.path(res_dir, "TME_states_vs_Response_summary.csv"))
tme_states <- data.frame(state = summary_tbl$factor, annotation = summary_tbl$top_cell_groups)
tme_states <- tme_states[order(tme_states$state), ]
write.csv(tme_states, file.path(out_dir, "tme_states.csv"), row.names = FALSE)

## ---- response_tests.csv : one row per TME state, test result + direction ----
stats_tbl <- read.csv(file.path(res_dir, "LatentFactors_vs_Response_stats.csv"))
coldata_all <- read.table(file.path(work_dir, "data/colData_all.txt"), header = TRUE, sep = " ",
                           stringsAsFactors = FALSE)
coldata <- coldata_all[coldata_all$Cohort == "Gide", ]
rownames(coldata) <- make.names(coldata$Sample_id)
coldata <- coldata[rownames(Z), ]
higher_in <- sapply(colnames(Z), function(f) {
  m <- tapply(Z[[f]], coldata$Response, median)
  names(which.max(m))
})
response_tests <- data.frame(
  state = stats_tbl$feature,
  p_value = stats_tbl$p_value,
  adjusted_p_value = stats_tbl$p_adjusted,
  higher_in = higher_in[stats_tbl$feature]
)
response_tests <- response_tests[order(response_tests$state), ]
write.csv(response_tests, file.path(out_dir, "response_tests.csv"), row.names = FALSE)

## ---- tf_activity.csv ----
tfs <- read_matrix_csv(file.path(pkg_dir, "TF_matrix_Gide.csv"))
write.csv(restore_patients(tfs), file.path(out_dir, "tf_activity.csv"), row.names = FALSE)

## ---- tf_modules.csv : one row per TF, with its module ----
tf_mod <- read.csv(file.path(pkg_dir, "TFs_modules_Gide.csv"), check.names = FALSE)
colnames(tf_mod) <- c("module", "Composition")
tf_modules <- do.call(rbind, lapply(seq_len(nrow(tf_mod)), function(i) {
  data.frame(module = tf_mod$module[i],
             tf = trimws(strsplit(tf_mod$Composition[i], ",")[[1]]))
}))
write.csv(tf_modules, file.path(out_dir, "tf_modules.csv"), row.names = FALSE)

## ---- tf_module_scores.csv ----
tf_mod_scores <- read_matrix_csv(file.path(pkg_dir, "TF_module_matrix_Gide.csv"))
write.csv(restore_patients(tf_mod_scores), file.path(out_dir, "tf_module_scores.csv"), row.names = FALSE)

## ---- pathway_scores.csv (PROGENy; no custom gene_sets/GSVA were used) ----
paths <- read_matrix_csv(file.path(pkg_dir, "Pathway_matrix_PROGENy_Gide.csv"))
write.csv(restore_patients(paths), file.path(out_dir, "pathway_scores.csv"), row.names = FALSE)

## ---- subgroups_composition.csv : one row per member (subgroup, feature) ----
subg <- read.csv(file.path(pkg_dir, "Cell_subgroups_Gide.csv"), check.names = FALSE)
colnames(subg) <- c("subgroup", "Members")
subgroups_composition <- do.call(rbind, lapply(seq_len(nrow(subg)), function(i) {
  data.frame(subgroup = subg$subgroup[i],
             feature = trimws(strsplit(subg$Members[i], "\n")[[1]]))
}))
write.csv(subgroups_composition, file.path(out_dir, "subgroups_composition.csv"), row.names = FALSE)

## ---- cell_groups.csv : one row per member (cell_group, feature) ----
cg <- read.csv(file.path(pkg_dir, "Cell.groups.composition_Gide.csv"), check.names = FALSE)
colnames(cg) <- c("cell_group", "Members")
cell_groups <- do.call(rbind, lapply(seq_len(nrow(cg)), function(i) {
  data.frame(cell_group = cg$cell_group[i],
             feature = trimws(strsplit(cg$Members[i], "\n")[[1]]))
}))
write.csv(cell_groups, file.path(out_dir, "cell_groups.csv"), row.names = FALSE)

## ---- cell_group_scores.csv ----
cg_scores <- read_matrix_csv(file.path(pkg_dir, "Cell.groups.scores_Gide.csv"))
write.csv(restore_patients(cg_scores), file.path(out_dir, "cell_group_scores.csv"), row.names = FALSE)

## ---- info.json ----
info <- list(
  n_states = ncol(Z),
  deconvolution_input_scale = "linear TPM",
  cibersortx = FALSE,
  test = "wilcox",
  deconvolution_source = "computed inside CellTFusion"
)
writeLines(jsonlite::toJSON(info, auto_unbox = TRUE, pretty = TRUE), file.path(out_dir, "info.json"))

cat("Done. Files written to", out_dir, "\n")
print(list.files(out_dir))
