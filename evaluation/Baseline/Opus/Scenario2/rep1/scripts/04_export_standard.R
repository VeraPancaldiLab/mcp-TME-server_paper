# Export existing CellTFusion results (Gide) to a standard format in results/standard/.
# Only reshapes outputs already produced by scripts 01-03; nothing is recomputed.
# Usage: Rscript scripts/04_export_standard.R   (from the project root)

suppressPackageStartupMessages(library(jsonlite))

root <- normalizePath(".")
out_dir <- file.path(root, "results")
std_dir <- file.path(out_dir, "standard")
dir.create(std_dir, showWarnings = FALSE)

res <- readRDS(file.path(out_dir, "CellTFusion_Gide.rds"))
stats <- read.csv(file.path(out_dir, "response_association/Response_association_all_features.csv"))

input_samples <- colnames(read.delim(file.path(root, "data/Gide_log2TPM.txt"), row.names = 1,
                                     check.names = FALSE, nrows = 1))

per_patient <- function(mat, file) {
  mat <- as.data.frame(mat, check.names = FALSE)
  stopifnot(setequal(rownames(mat), input_samples))
  mat <- mat[input_samples, , drop = FALSE]
  write.csv(data.frame(patient = input_samples, mat, check.names = FALSE),
            file.path(std_dir, file), row.names = FALSE)
}
long_list <- function(lst, col1, col2, file) {
  df <- data.frame(rep(names(lst), lengths(lst)), unlist(lst, use.names = FALSE))
  colnames(df) <- c(col1, col2)
  write.csv(df, file.path(std_dir, file), row.names = FALSE)
}

# TME states = NMF latent factors (Z), the scores tested against response
Z <- res$Latent_spaces$Z
per_patient(Z, "factor_scores.csv")

# Annotations as presented in results/README.md
write.csv(data.frame(
  state = c("Factor1", "Factor2", "Factor3"),
  annotation = c("Immune-inflamed (T/B/plasma cells, macrophages; JAK-STAT, NFkB, TNFa)",
                 "Stromal/TGFb (CAFs, fibroblasts, endothelium, M2 macrophages; TGFb, hypoxia, PI3K)",
                 "Tumour-intrinsic, immune-low (cancer-cell signal; low inflammatory pathways)")),
  file.path(std_dir, "tme_states.csv"), row.names = FALSE)

# Main test: two-sided Wilcoxon R vs NR, BH across the 3 factors; direction from the AUC (> 0.5: higher in R)
lf <- stats[stats$set == "Latent_factors", ]
lf <- lf[match(colnames(Z), lf$feature), ]
write.csv(data.frame(state = lf$feature, p_value = lf$wilcox_p, adjusted_p_value = lf$wilcox_padj,
                     higher_in = ifelse(lf$AUC > 0.5, "R", "NR")),
          file.path(std_dir, "response_tests.csv"), row.names = FALSE)

per_patient(res$TFs_matrix, "tf_activity.csv")
long_list(res$TF_network[["TFs per module"]], "module", "tf", "tf_modules.csv")
stopifnot(setequal(colnames(res$TF_network[[1]]), names(res$TF_network[["TFs per module"]])))
per_patient(res$TF_network[[1]], "tf_module_scores.csv")
per_patient(res$Pathways_scores, "pathway_scores.csv")

subgroups <- unlist(unname(res$Processed_deconvolution[["Deconvolution subgroups composition"]]),
                    recursive = FALSE)
long_list(subgroups, "subgroup", "feature", "subgroups_composition.csv")

long_list(res$Cell_groups$Composition, "cell_group", "feature", "cell_groups.csv")
stopifnot(setequal(colnames(res$Cell_groups$Cell_groups), names(res$Cell_groups$Composition)))
per_patient(res$Cell_groups$Cell_groups, "cell_group_scores.csv")

write_json(list(n_states = ncol(Z),
                deconvolution_input_scale = "linear TPM",
                cibersortx = FALSE,
                test = "Two-sided Wilcoxon rank-sum test (R vs NR), Benjamini-Hochberg across the 3 latent factors",
                deconvolution_source = "computed inside CellTFusion"),
           file.path(std_dir, "info.json"), auto_unbox = TRUE, pretty = TRUE)
