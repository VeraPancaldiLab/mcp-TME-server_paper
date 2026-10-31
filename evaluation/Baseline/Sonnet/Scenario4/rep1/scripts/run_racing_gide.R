#!/usr/bin/env Rscript
# Infer cell-cell communication networks for the Gide melanoma ICB cohort with RaCInG
# and summarize the most common interaction patterns across patients.

suppressMessages(library(RaCInG))

data_dir    <- "/home/marcelo.hurtado/Documents/tme_analysis/b0f19b8438/work/data"
results_dir <- "/home/marcelo.hurtado/Documents/tme_analysis/b0f19b8438/work/results"
dir.create(results_dir, showWarnings = FALSE, recursive = TRUE)

set.seed(1)

## ---------------------------------------------------------------------------
## 1. Load expression matrix (genes x samples) and undo log2(TPM + 1)
## ---------------------------------------------------------------------------
log2tpm <- as.matrix(read.table(
  file.path(data_dir, "Gide_log2TPM.txt"),
  header = TRUE, row.names = 1, sep = "\t", check.names = FALSE
))
tpm <- 2^log2tpm - 1
tpm[tpm < 0] <- 0

## multideconv::compute.deconvolution() internally sanitizes sample names
## with R's data.frame rules (e.g. "10_PD1_PRE" -> "X10_PD1_PRE"); sanitize
## up front so colnames(tpm) match the deconvolution output exactly.
original_names <- colnames(tpm)
colnames(tpm) <- make.names(original_names, unique = TRUE)
write.csv(
  data.frame(Sample_id = original_names, RaCInG_id = colnames(tpm)),
  file.path(results_dir, "Gide_sample_id_mapping.csv"), row.names = FALSE
)

cat(sprintf("Gide cohort: %d genes x %d samples\n", nrow(tpm), ncol(tpm)))

## ---------------------------------------------------------------------------
## 2. Build RaCInG input matrices (deconvolution, LR prior network, LR matrix)
## ---------------------------------------------------------------------------
input <- prepare_input_files(
  counts          = tpm,
  output_folder   = results_dir,
  file_name       = "Gide",
  deconv_method   = "Quantiseq",
  already_normalized = TRUE,
  expr_threshold  = 10
)
saveRDS(input, file.path(results_dir, "Gide_racing_input.rds"))
cat("Cell types:", paste(input$celltypes, collapse = ", "), "\n")

## ---------------------------------------------------------------------------
## 3. Kernel method: direct cell-cell communication per patient
## ---------------------------------------------------------------------------
kernel_res <- compute_racing_kernel(
  input_data         = input,
  communication_type = "D",
  norm               = TRUE,
  remove_direction   = TRUE
)
saveRDS(kernel_res, file.path(results_dir, "Gide_kernel_result.rds"))

features <- kernel_res$features
write.csv(features, file.path(results_dir, "Gide_interaction_features_raw.csv"))

cat(sprintf("Interaction features: %d patients x %d cell-type pairs\n", nrow(features), ncol(features)))

## ---------------------------------------------------------------------------
## 4. Most common interaction patterns across the cohort
##    "Common" = how often a cell-type pair is among each patient's
##    strongest communication routes (top-K raw direct-communication scores).
## ---------------------------------------------------------------------------
topK <- 5
top_pairs_per_patient <- apply(features, 1, function(row) {
  names(sort(row, decreasing = TRUE))[seq_len(min(topK, length(row)))]
})

pair_counts <- table(unlist(as.list(as.data.frame(top_pairs_per_patient, stringsAsFactors = FALSE))))
pair_counts <- sort(pair_counts, decreasing = TRUE)

n_patients <- nrow(features)
common_patterns <- data.frame(
  Pair               = names(pair_counts),
  N_Patients_Top5    = as.integer(pair_counts),
  Pct_Patients_Top5  = round(100 * as.integer(pair_counts) / n_patients, 1),
  Mean_Raw_Score     = sapply(names(pair_counts), function(p) mean(features[, p])),
  Median_Raw_Score   = sapply(names(pair_counts), function(p) median(features[, p])),
  row.names = NULL
)
write.csv(common_patterns, file.path(results_dir, "Gide_most_common_interaction_patterns.csv"), row.names = FALSE)

cat("\nTop 10 most common cell-cell interaction patterns (by presence in each patient's top-5):\n")
print(head(common_patterns, 10))

## Secondary ranking: mean raw communication strength across the whole cohort
mean_ranked <- data.frame(
  Pair           = colnames(features),
  Mean_Raw_Score = colMeans(features),
  row.names = NULL
)
mean_ranked <- mean_ranked[order(-mean_ranked$Mean_Raw_Score), ]
write.csv(mean_ranked, file.path(results_dir, "Gide_interactions_ranked_by_mean_strength.csv"), row.names = FALSE)

## ---------------------------------------------------------------------------
## 5. Plot: frequency of the top common interaction patterns
## ---------------------------------------------------------------------------
top_n_plot <- min(15, nrow(common_patterns))
plot_df <- common_patterns[seq_len(top_n_plot), ]
plot_df$Pair <- factor(plot_df$Pair, levels = rev(plot_df$Pair))

png(file.path(results_dir, "Gide_most_common_interaction_patterns.png"), width = 1400, height = 900, res = 150)
par(mar = c(5, 14, 4, 2))
barplot(
  plot_df$Pct_Patients_Top5, names.arg = plot_df$Pair, horiz = TRUE, las = 1,
  col = "steelblue", xlab = "% of patients with this pair in their top-5 communication routes",
  main = sprintf("Most common cell-cell interaction patterns (Gide cohort, n = %d)", n_patients)
)
dev.off()

## ---------------------------------------------------------------------------
## 6. Ligand-receptor decomposition of the single most common pattern
## ---------------------------------------------------------------------------
## Cell-type names can themselves contain "_", so split "Dir_<A>_<B>" by
## matching known celltypes rather than naively splitting on "_".
parse_pair <- function(pair_name, celltypes) {
  body <- sub("^Dir_", "", pair_name)
  for (ct in celltypes) {
    if (startsWith(body, paste0(ct, "_"))) {
      other <- substring(body, nchar(ct) + 2)
      if (other %in% celltypes) return(c(ct, other))
    }
  }
  stop("Could not parse cell types from pair name: ", pair_name)
}

top_pair <- as.character(common_patterns$Pair[1])
pair_celltypes <- parse_pair(top_pair, input$celltypes)
sender   <- pair_celltypes[1]
receiver <- pair_celltypes[2]

lr_contrib <- computeLRContributions(
  Lmatrix = input$Lmatrix, Rmatrix = input$Rmatrix,
  Cmatrix = input$Cmatrix, LRmatrix = input$LRmatrix,
  celltypes = input$celltypes, sender = sender, receiver = receiver,
  patient_names = rownames(features)
)
write.csv(lr_contrib, file.path(results_dir, sprintf("Gide_LR_contributions_%s.csv", top_pair)), row.names = FALSE)

lr_plot <- plotLRContributions(lr_contrib, top_n = 10)
ggplot2::ggsave(file.path(results_dir, sprintf("Gide_LR_contributions_%s.png", top_pair)), lr_plot, width = 9, height = 6, dpi = 150)

cat(sprintf("\nMost common interaction pattern overall: %s (%s)\n", top_pair, pair_celltypes))
cat("Top ligand-receptor pairs driving it:\n")
print(head(lr_contrib, 10))

cat("\nDone. All results saved under:", results_dir, "\n")
