# Export existing CellTFusion results to a standard format in results/standard/.
# No method is rerun: everything is read from results/CellTFusion_Gide.rds and the saved CSVs.
# Usage (from the project root): Rscript scripts/03_export_standard.R

suppressPackageStartupMessages(library(jsonlite))

out <- "results/standard"
dir.create(out, showWarnings = FALSE, recursive = TRUE)
res <- readRDS("results/CellTFusion_Gide.rds")
inp <- colnames(read.delim("data/Gide_log2TPM.txt", nrows = 1, check.names = FALSE))[-1]

per_patient <- function(m, file) {
  m <- as.data.frame(m, check.names = FALSE)
  stopifnot(identical(rownames(m), inp))
  write.csv(data.frame(patient = rownames(m), m, check.names = FALSE),
            file.path(out, file), row.names = FALSE)
}
long_list <- function(l, cols, file) {
  d <- data.frame(rep(names(l), lengths(l)), unlist(l, use.names = FALSE))
  colnames(d) <- cols
  write.csv(d, file.path(out, file), row.names = FALSE)
}

# TME states: NMF factor scores (Z) tested against response, as saved by 02_states_and_response.R
st <- read.csv("results/response_analysis/TME_state_scores_per_sample.csv", check.names = FALSE)
rownames(st) <- st$sample
per_patient(st[, c("TME_state1", "TME_state2")], "factor_scores.csv")

write.csv(data.frame(
  state = c("TME_state1", "TME_state2"),
  annotation = c("immune-inflamed (STAT1/IRF1/NF-kB TF module; CD8/CD4 T, B/plasma, M1 macrophages; JAK-STAT/NFkB/TNFa)",
                 "stromal / TGF-beta-hypoxic (SMAD2/3, CEBPB, EPAS1 TF modules; endothelial, fibroblasts, M2 macrophages, monocytes, mast cells; TGFb/Hypoxia)")),
  file.path(out, "tme_states.csv"), row.names = FALSE)

# Main response test: Wilcoxon rank-sum (BH across states); direction from the saved AUC (P(R > NR))
w <- read.csv("results/response_analysis/Response_wilcox_TME_states.csv")
mods <- read.csv("results/response_analysis/Response_TME_states_logistic_models.csv")
mods <- mods[mods$set == "all_samples", ]
w$higher_in <- ifelse(mods$AUC[match(w$feature, mods$state)] > 0.5, "R", "NR")
write.csv(data.frame(state = w$feature, p_value = w$p_value, adjusted_p_value = w$p_adjusted,
                     higher_in = w$higher_in),
          file.path(out, "response_tests.csv"), row.names = FALSE)

# TF activity, TF modules and their scores, pathways
per_patient(res$TFs_matrix, "tf_activity.csv")
long_list(res$TF_network[["TFs per module"]], c("module", "tf"), "tf_modules.csv")
per_patient(res$TF_network[["TFs module matrix"]], "tf_module_scores.csv")
per_patient(res$Pathways_scores, "pathway_scores.csv")

# Deconvolution subgroups (flattened over cell types) and cell groups
sub <- unlist(unname(res$Processed_deconvolution[["Deconvolution subgroups composition"]]),
              recursive = FALSE)
long_list(sub, c("subgroup", "feature"), "subgroups_composition.csv")
long_list(res$Cell_groups$Composition, c("cell_group", "feature"), "cell_groups.csv")
per_patient(res$Cell_groups$Cell_groups, "cell_group_scores.csv")

write_json(list(n_states = ncol(res$Latent_spaces$Z),
                deconvolution_input_scale = "linear TPM",
                cibersortx = FALSE,
                test = "Wilcoxon rank-sum test (BH-adjusted across states)",
                deconvolution_source = "computed inside CellTFusion"),
           file.path(out, "info.json"), auto_unbox = TRUE, pretty = TRUE)
cat("Written:", paste(list.files(out), collapse = ", "), "\n")
