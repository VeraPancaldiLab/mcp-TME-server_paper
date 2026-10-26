#!/usr/bin/env Rscript
suppressMessages({
  library(ggplot2)
  library(reshape2)
})

work_dir <- "/home/marcelo.hurtado/Documents/tme_analysis/9012cf463c/work"
res_dir <- file.path(work_dir, "results")
dir.create(res_dir, showWarnings = FALSE, recursive = TRUE)

coldata <- readRDS(file.path(work_dir, "run_tmp", "gide_coldata.rds"))
celltypes <- readRDS(file.path(work_dir, "run_tmp", "gide_subgroups_celltypes.rds"))
immstr <- readRDS(file.path(work_dir, "run_tmp", "gide_subgroups_immune_stromal.rds"))

mat_celltypes <- celltypes[["Deconvolution matrix"]]
mat_immstr <- immstr[["Deconvolution matrix"]]

fix_names <- function(x) sub("^X", "", x)
rownames(mat_celltypes) <- fix_names(rownames(mat_celltypes))
rownames(mat_immstr) <- fix_names(rownames(mat_immstr))

stopifnot(all(coldata$Sample_id %in% rownames(mat_immstr)))
mat_celltypes <- mat_celltypes[coldata$Sample_id, ]
mat_immstr <- mat_immstr[coldata$Sample_id, ]

# ---- Composite Immune / Stromal scores (mean of z-scored subgroup-level features) ----
imm_cols <- grep("Immune", colnames(mat_immstr), value = TRUE)
str_cols <- grep("Stromal", colnames(mat_immstr), value = TRUE)

zscore <- function(x) (x - mean(x, na.rm = TRUE)) / sd(x, na.rm = TRUE)

immune_z <- apply(mat_immstr[, imm_cols, drop = FALSE], 2, zscore)
stromal_z <- apply(mat_immstr[, str_cols, drop = FALSE], 2, zscore)

immune_score <- rowMeans(immune_z)
stromal_score <- rowMeans(stromal_z)

summary_df <- data.frame(
  Sample_id = coldata$Sample_id,
  Patient = coldata$Timing,
  Response = coldata$Response,
  Therapy = coldata$Therapy,
  Immune_score = immune_score,
  Stromal_score = stromal_score,
  Immune_minus_Stromal = immune_score - stromal_score
)
summary_df <- summary_df[order(-summary_df$Immune_score), ]
summary_df$Immune_rank <- seq_len(nrow(summary_df))

write.csv(summary_df, file.path(res_dir, "immune_stromal_scores_per_sample.csv"), row.names = FALSE)

# full reduced cell-type matrix + immune/stromal scores, with clinical annotation
full_annotated <- cbind(
  coldata[match(rownames(mat_celltypes), coldata$Sample_id),
          c("Sample_id", "Timing", "Response", "Therapy")],
  mat_celltypes
)
write.csv(full_annotated, file.path(res_dir, "deconvolution_celltype_subgroups.csv"), row.names = FALSE)

full_immstr_annotated <- cbind(
  coldata[match(rownames(mat_immstr), coldata$Sample_id),
          c("Sample_id", "Timing", "Response", "Therapy")],
  mat_immstr
)
write.csv(full_immstr_annotated, file.path(res_dir, "deconvolution_immune_stromal.csv"), row.names = FALSE)

# subgroup composition (which method-signature features were merged) for traceability
sink(file.path(res_dir, "subgroup_composition_immune_stromal.txt"))
cat("=== Immune subgroup composition ===\n")
print(immstr[["Deconvolution subgroups composition"]]$Immune)
cat("\n=== Stromal subgroup composition ===\n")
print(immstr[["Deconvolution subgroups composition"]]$Stromal)
sink()

cat("Saved per-sample scores and matrices to results/\n")

# ---- Plot 1: Immune vs Stromal score scatter, colored by Response ----
p1 <- ggplot(summary_df, aes(x = Stromal_score, y = Immune_score, color = Response)) +
  geom_point(size = 2.5, alpha = 0.85) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey60") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey60") +
  scale_color_manual(values = c("R" = "#1b9e77", "NR" = "#d95f02")) +
  theme_minimal(base_size = 13) +
  labs(title = "Gide cohort: immune vs stromal infiltration",
       x = "Stromal score (z-score)", y = "Immune score (z-score)")
ggsave(file.path(res_dir, "immune_vs_stromal_scatter.pdf"), p1, width = 7, height = 5.5)

# ---- Plot 2: Patients ranked by immune score ----
summary_df$Sample_id <- factor(summary_df$Sample_id, levels = summary_df$Sample_id[order(summary_df$Immune_score)])
p2 <- ggplot(summary_df, aes(x = Sample_id, y = Immune_score, fill = Response)) +
  geom_col() +
  coord_flip() +
  scale_fill_manual(values = c("R" = "#1b9e77", "NR" = "#d95f02")) +
  theme_minimal(base_size = 8) +
  theme(axis.text.y = element_text(size = 5)) +
  labs(title = "Patients ranked by immune infiltration score",
       x = NULL, y = "Immune score (z-score)")
ggsave(file.path(res_dir, "patients_ranked_by_immune_score.pdf"), p2, width = 7, height = 12)

# ---- Plot 3: Immune score by Response (boxplot) ----
p3 <- ggplot(summary_df, aes(x = Response, y = Immune_score, fill = Response)) +
  geom_boxplot(outlier.shape = NA, alpha = 0.6) +
  geom_jitter(width = 0.15, size = 1.8) +
  scale_fill_manual(values = c("R" = "#1b9e77", "NR" = "#d95f02")) +
  theme_minimal(base_size = 13) +
  labs(title = "Immune infiltration by response to therapy", x = NULL, y = "Immune score (z-score)")
wt <- wilcox.test(Immune_score ~ Response, data = summary_df)
p3 <- p3 + labs(subtitle = paste0("Wilcoxon p = ", signif(wt$p.value, 3)))
ggsave(file.path(res_dir, "immune_score_by_response.pdf"), p3, width = 5, height = 5.5)

# ---- Plot 4: Heatmap of detailed cell-type subgroup composition (top variable features) ----
vars <- apply(mat_celltypes, 2, var, na.rm = TRUE)
top_feats <- names(sort(vars, decreasing = TRUE))[1:min(40, length(vars))]
heat_mat <- scale(mat_celltypes[, top_feats])
heat_mat <- heat_mat[order(summary_df$Immune_score[match(rownames(heat_mat), summary_df$Sample_id)]), ]
heat_df <- melt(heat_mat, varnames = c("Sample", "Feature"))
heat_df$Sample <- factor(heat_df$Sample, levels = rownames(heat_mat))

p4 <- ggplot(heat_df, aes(x = Feature, y = Sample, fill = value)) +
  geom_tile() +
  scale_fill_gradientn(colors = c("#2166ac", "white", "#b2182b"), limits = c(-3, 3), oob = scales::squish) +
  theme_minimal(base_size = 7) +
  theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5, size = 6),
        axis.text.y = element_text(size = 4)) +
  labs(title = "Top variable cell-type subgroups across Gide samples\n(rows ordered by immune score)",
       x = NULL, y = NULL, fill = "z-score")
ggsave(file.path(res_dir, "celltype_subgroup_heatmap.pdf"), p4, width = 11, height = 10)

cat("Saved plots to results/\n")

# ---- Summary stats printed to console/log ----
cat("\n=== Top 10 most immune-infiltrated samples ===\n")
print(head(summary_df[, c("Sample_id", "Response", "Therapy", "Immune_score", "Stromal_score")], 10))
cat("\n=== Bottom 10 least immune-infiltrated samples ===\n")
print(tail(summary_df[, c("Sample_id", "Response", "Therapy", "Immune_score", "Stromal_score")], 10))
cat("\nWilcoxon test Immune_score ~ Response: p =", signif(wt$p.value, 3), "\n")
cat("Mean immune score R:", mean(summary_df$Immune_score[summary_df$Response == "R"]),
    " NR:", mean(summary_df$Immune_score[summary_df$Response == "NR"]), "\n")
