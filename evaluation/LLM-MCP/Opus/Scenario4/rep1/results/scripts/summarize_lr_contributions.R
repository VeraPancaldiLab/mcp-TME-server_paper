# Summarize ligand-receptor contributions (explain_lr_contributions) of the leading Gide
# cell-type pairs: per edge, which LR pairs carry most of the score and how consistently
# across patients. Run from the results/ directory.
suppressPackageStartupMessages(library(ggplot2))

map <- read.csv("sample_id_mapping.csv")
edges <- list.dirs("lr_contributions", recursive = FALSE)
all_top <- list()
for (d in edges) {
  x <- read.csv(file.path(d, "result.csv"))
  x$Patient <- map$original[match(x$Patient, map$racing_id)]
  write.csv(x, file.path(d, "result_original_ids.csv"), row.names = FALSE)
  x$LR <- paste(x$Ligand, "->", x$Receptor)
  # bundled edges hold both directions: keep the direction (sender -> receiver) in the key
  x$key <- paste(x$Sender, x$Receiver, x$LR, sep = "|")
  n_pat <- length(unique(x$Patient))
  # within each patient, rank LR pairs by contribution
  x <- x[order(x$Patient, -x$Contribution), ]
  x$rank <- ave(x$Contribution, x$Patient, FUN = function(v) seq_along(v))
  s <- do.call(rbind, lapply(split(x, x$key), function(g) data.frame(
    LR = g$LR[1], Ligand = g$Ligand[1], Receptor = g$Receptor[1],
    Sender = g$Sender[1], Receiver = g$Receiver[1],
    direction = if (g$Sender[1] == g$Receiver[1]) "autocrine" else paste(g$Sender[1], "->", g$Receiver[1]),
    median_pct_of_edge = median(c(g$PctOfTotal, rep(0, n_pat - nrow(g)))),
    mean_pct_of_edge = sum(g$PctOfTotal) / n_pat,
    frac_patients_top10 = sum(g$rank <= 10) / n_pat,
    frac_patients_present = nrow(g) / n_pat)))
  s <- s[order(-s$mean_pct_of_edge), ]
  s$edge <- basename(d)
  write.csv(s, file.path(d, "lr_pair_summary.csv"), row.names = FALSE)
  all_top[[basename(d)]] <- head(s, 10)
  cat("\n==", basename(d), "(", s$Sender[1], "<->", s$Receiver[1], ")  LR pairs:", nrow(s), "\n")
  cat("   top-10 LR pairs cover", round(sum(head(s$mean_pct_of_edge, 10)), 1), "% of the edge on average\n")
  print(head(s[, c("direction", "LR", "mean_pct_of_edge", "frac_patients_top10", "frac_patients_present")], 10),
        row.names = FALSE, digits = 3)
}
top <- do.call(rbind, all_top)
write.csv(top, "lr_contributions/top10_lr_pairs_per_edge.csv", row.names = FALSE)

# LR pairs recurring among the top 10 of several edges
rec <- aggregate(edge ~ LR, top, function(e) paste(sort(unique(e)), collapse = ";"))
rec$n_edges <- lengths(strsplit(rec$edge, ";"))
rec <- rec[order(-rec$n_edges), ]
write.csv(rec, "lr_contributions/recurrent_lr_pairs_across_edges.csv", row.names = FALSE)
cat("\nLR pairs in the top 10 of >= 3 edges:\n"); print(rec[rec$n_edges >= 3, ], row.names = FALSE)

# Ligand / receptor family view across all six edges (mean % of edge)
allsum <- do.call(rbind, lapply(edges, function(d) read.csv(file.path(d, "lr_pair_summary.csv"))))
lig <- aggregate(mean_pct_of_edge ~ Ligand, allsum, sum); lig$mean_pct_of_edge <- lig$mean_pct_of_edge / length(edges)
lig <- lig[order(-lig$mean_pct_of_edge), ]
write.csv(lig, "lr_contributions/ligand_share_across_edges.csv", row.names = FALSE)
cat("\nTop ligands (mean % share across the 6 edges):\n"); print(head(lig, 15), row.names = FALSE, digits = 3)

g <- ggplot(top, aes(reorder(LR, mean_pct_of_edge), mean_pct_of_edge)) + geom_col(fill = "seagreen") +
  coord_flip() + facet_wrap(~edge, scales = "free_y", ncol = 2) + theme_bw(base_size = 8) +
  labs(x = NULL, y = "Mean % of edge score across patients", title = "Gide: top 10 LR pairs per leading cell-type pair")
ggsave("lr_contributions/top10_lr_pairs_per_edge.pdf", g, width = 12, height = 12)
