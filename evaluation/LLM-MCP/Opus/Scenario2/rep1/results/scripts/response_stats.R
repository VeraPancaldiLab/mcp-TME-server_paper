# Wilcoxon rank-sum (R vs NR) on CellTFusion latent factors and cell group scores, with BH-FDR
cd <- read.csv("inputs/Gide_coldata.csv", row.names = 1)
r  <- readRDS("celltfusion/result.rds")
comp <- read.csv("celltfusion/Results/Cell.groups.composition_Gide.csv", check.names = FALSE)
test <- function(M) {
  M <- as.data.frame(M)[rownames(cd), , drop = FALSE]
  y <- cd$Response
  res <- do.call(rbind, lapply(colnames(M), function(f) {
    x <- M[[f]]
    data.frame(feature = f,
               median_R = median(x[y == "R"]), median_NR = median(x[y == "NR"]),
               higher_in = ifelse(median(x[y == "R"]) > median(x[y == "NR"]), "R", "NR"),
               p_value = suppressWarnings(wilcox.test(x[y == "R"], x[y == "NR"])$p.value))
  }))
  res$FDR_BH <- p.adjust(res$p_value, "BH")
  res[order(res$p_value), ]
}
f <- test(r$Latent_spaces$Z)
write.csv(f, "response_association/Latent_factors_vs_Response_stats.csv", row.names = FALSE)
g <- test(r$Cell_groups$Cell_groups)
g$TF_module <- sub("Dendrogram_(.*)_group_.*", "\\1", g$feature)
write.csv(g, "response_association/Cell_groups_vs_Response_stats.csv", row.names = FALSE)
print(f)
cat("\nCell groups tested:", nrow(g), " p<0.05:", sum(g$p_value < 0.05), " FDR<0.05:", sum(g$FDR_BH < 0.05), "\n")
s <- g[g$FDR_BH < 0.05, ]
print(table(s$TF_module, s$higher_in))
print(table(g$TF_module))
print(head(g, 15), row.names = FALSE)
