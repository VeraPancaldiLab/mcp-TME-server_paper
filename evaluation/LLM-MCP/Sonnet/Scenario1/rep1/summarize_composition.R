args <- commandArgs(trailingOnly = TRUE)
deconv_file <- args[1]
coldata_file <- args[2]
out_dir <- args[3]

deconv <- read.csv(deconv_file, check.names = FALSE, row.names = 1)
rownames(deconv) <- sub("^X", "", rownames(deconv))

coldata <- read.table(coldata_file, check.names = FALSE, header = TRUE, sep = " ")
coldata <- coldata[coldata$Cohort == "Gide", ]
rownames(coldata) <- coldata$Sample_id

immune_types <- c(
  "B.cells", "B.naive.cells", "B.memory.cells", "Plasma",
  "CD4.cells", "CD4.memory.activated", "CD4.memory.resting", "CD4.naive",
  "CD4.regulatory", "CD4.non.regulatory", "CD8.cells",
  "T.cells.helper", "T.cells.gamma.delta", "T.cells.proliferative",
  "NK.cells", "NK.activated", "NK.resting", "NKT.cells",
  "Macrophages.cells", "Macrophages.M0", "Macrophages.M1", "Macrophages.M2",
  "Monocytes", "Myeloid.cells",
  "Dendritic.cells", "Dendritic.activated.cells", "Dendritic.resting.cells", "Dendritic.plasmacytoid.cells",
  "Neutrophils", "Eosinophils", "Basophils",
  "Mast.cells", "Mast.activated.cells", "Mast.resting.cells"
)
stromal_types <- c("Endothelial", "Fibroblasts", "CAF", "Pericytes", "Mural.cells", "Myocytes")
tumor_types <- c("Cancer", "Epithelial")

all_types <- c(immune_types, stromal_types, tumor_types)

get_type <- function(colname) {
  for (t in all_types[order(-nchar(all_types))]) {
    pattern <- paste0("_", t, "(_Subgroup\\.[0-9]+)?$")
    if (grepl(pattern, colname)) return(t)
  }
  if (grepl("^[A-Za-z0-9.]+_Subgroup\\.[0-9]+$", colname)) {
    return(sub("_Subgroup\\.[0-9]+$", "", colname))
  }
  NA
}

cols <- colnames(deconv)
cell_type_map <- sapply(cols, get_type)

composite <- sapply(all_types, function(t) {
  matched <- cols[cell_type_map == t & !is.na(cell_type_map)]
  if (length(matched) == 0) return(rep(NA_real_, nrow(deconv)))
  if (length(matched) == 1) return(deconv[[matched]])
  rowMeans(deconv[, matched, drop = FALSE], na.rm = TRUE)
})
rownames(composite) <- rownames(deconv)
composite <- as.data.frame(composite)
composite <- composite[, colSums(!is.na(composite)) > 0]

immune_cols <- intersect(immune_types, colnames(composite))
stromal_cols <- intersect(stromal_types, colnames(composite))
tumor_cols <- intersect(tumor_types, colnames(composite))

immune_score <- rowSums(composite[, immune_cols, drop = FALSE], na.rm = TRUE)
stromal_score <- rowSums(composite[, stromal_cols, drop = FALSE], na.rm = TRUE)
tumor_score <- rowSums(composite[, tumor_cols, drop = FALSE], na.rm = TRUE)

patient_meta <- coldata[rownames(composite), c("Sample_id", "Timing", "Response", "Therapy")]

scores <- data.frame(
  Sample_id = rownames(composite),
  patient_meta[, c("Response", "Therapy")],
  Immune_score = immune_score,
  Stromal_score = stromal_score,
  Tumor_score = tumor_score
)
scores <- scores[order(-scores$Immune_score), ]
scores$Immune_rank <- seq_len(nrow(scores))

composition_out <- cbind(Sample_id = rownames(composite), composite)

write.csv(composition_out, file.path(out_dir, "Gide_cell_type_composition.csv"), row.names = FALSE)
write.csv(scores, file.path(out_dir, "Gide_immune_stromal_infiltration_ranking.csv"), row.names = FALSE)

pdf(file.path(out_dir, "Gide_immune_infiltration_barplot.pdf"), width = 14, height = 6)
ord <- order(-scores$Immune_score)
barplot(scores$Immune_score[ord], names.arg = scores$Sample_id[ord], las = 2, cex.names = 0.5,
        col = "firebrick", main = "Immune infiltration score per sample (Gide cohort)",
        ylab = "Summed immune cell-type abundance")
dev.off()

pdf(file.path(out_dir, "Gide_immune_vs_stromal_scatter.pdf"), width = 7, height = 7)
plot(scores$Stromal_score, scores$Immune_score, pch = 19,
     col = ifelse(scores$Response == "R", "forestgreen", "steelblue"),
     xlab = "Stromal score", ylab = "Immune score",
     main = "Immune vs stromal infiltration (Gide cohort)")
legend("topright", legend = c("Responder", "Non-responder"), col = c("forestgreen", "steelblue"), pch = 19)
dev.off()

cat("n_samples:", nrow(scores), "\n")
cat("Top 10 most immune infiltrated:\n")
print(head(scores[, c("Sample_id", "Response", "Immune_score", "Stromal_score")], 10))
cat("\nBottom 10 least immune infiltrated:\n")
print(tail(scores[, c("Sample_id", "Response", "Immune_score", "Stromal_score")], 10))
