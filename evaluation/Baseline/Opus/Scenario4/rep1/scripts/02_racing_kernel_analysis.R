# RaCInG kernel analysis of the Gide cohort: direct cell-cell communication,
# cohort-level ranking of cell-type pairs and of the ligand-receptor pairs behind them.
suppressPackageStartupMessages({
  library(RaCInG)
  library(data.table)
  library(ggplot2)
  library(pheatmap)
})

out_dir <- "results"
k_dir   <- file.path(out_dir, "kernel")
s_dir   <- file.path(out_dir, "summary")
lr_dir  <- file.path(out_dir, "lr_contributions")
f_dir   <- file.path(out_dir, "figures")
for (d in c(k_dir, s_dir, lr_dir, f_dir)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

inp <- readRDS(file.path(out_dir, "racing_input", "Gide_racing_input.rds"))
# restore the original sample IDs (prefixed in 01_prepare_input.R)
rownames(inp$Cmatrix) <- sub("^Gide_", "", rownames(inp$Cmatrix))
patients  <- rownames(inp$Cmatrix)
celltypes <- inp$celltypes

pretty_ct <- c(B.cells = "B", Cancer = "Cancer/non-immune", CD4.non.regulatory = "CD4 Tconv",
               CD4.regulatory = "Treg", CD8.cells = "CD8 T", Dendritic.cells = "DC",
               Macrophages.M1 = "Mac M1", Macrophages.M2 = "Mac M2", Monocytes = "Monocytes",
               Neutrophils = "Neutrophils", NK.cells = "NK")
stopifnot(all(celltypes %in% names(pretty_ct)))

meta <- fread("data/colData_all.txt")[Cohort == "Gide"]
meta <- meta[match(patients, rna_id), .(Patient = rna_id, Response, Therapy)]
stopifnot(!anyNA(meta$Patient))

# ---- 1. Kernel: direct communication ---------------------------------------
run_kernel <- function(norm, remove_direction) {
  suppressWarnings(compute_racing_kernel(input_data = inp, norm = norm,
                                         remove_direction = remove_direction))
}
dir_raw  <- run_kernel(norm = FALSE, remove_direction = FALSE)  # sender -> receiver
dir_norm <- run_kernel(norm = TRUE,  remove_direction = FALSE)  # enrichment vs uniform LR baseline
und_raw  <- run_kernel(norm = FALSE, remove_direction = TRUE)   # both directions merged
stopifnot(identical(rownames(dir_raw$features), patients))

write.csv(dir_raw$features,  file.path(k_dir, "direct_communication_directed_raw.csv"))
write.csv(dir_norm$features, file.path(k_dir, "direct_communication_directed_normalized.csv"))
write.csv(und_raw$features,  file.path(k_dir, "direct_communication_undirected_raw.csv"))
saveRDS(list(directed_raw = dir_raw, directed_norm = dir_norm, undirected_raw = und_raw),
        file.path(k_dir, "racing_kernel_results.rds"))

# ---- 2. Cohort-level ranking of cell-type pairs ----------------------------
# feature name -> (sender, receiver); cell-type names contain no "_"
pair_index <- CJ(Sender = celltypes, Receiver = celltypes, sorted = FALSE)
pair_index[, Feature := paste0("Dir_", Sender, "_", Receiver)]

summarise_features <- function(feat, top_k = 5) {
  feat <- as.matrix(feat)
  share <- feat / rowSums(feat)  # fraction of each patient's total direct communication
  rk <- t(apply(-share, 1, rank, ties.method = "min"))
  data.table(
    Feature            = colnames(feat),
    Mean               = colMeans(feat),
    Median             = apply(feat, 2, median),
    Q1                 = apply(feat, 2, quantile, 0.25),
    Q3                 = apply(feat, 2, quantile, 0.75),
    MedianPctOfTotal   = 100 * apply(share, 2, median),
    Q1PctOfTotal       = 100 * apply(share, 2, quantile, 0.25),
    Q3PctOfTotal       = 100 * apply(share, 2, quantile, 0.75),
    PctPatientsDetected = 100 * colMeans(feat > 0),
    PctPatientsAbove1pct = 100 * colMeans(share >= 0.01),
    MedianRankInPatient = apply(rk, 2, median),
    PctPatientsTop5    = 100 * colMeans(rk <= top_k)
  )
}

dir_sum <- summarise_features(dir_raw$features)
dir_sum <- merge(pair_index, dir_sum, by = "Feature")
norm_med <- apply(as.matrix(dir_norm$features), 2, median)
dir_sum[, MedianEnrichment := norm_med[Feature]]
dir_sum[, Interaction := paste0(pretty_ct[Sender], " -> ", pretty_ct[Receiver])]
setorder(dir_sum, -MedianPctOfTotal)
dir_sum[, CohortRank := .I]
setcolorder(dir_sum, c("CohortRank", "Interaction", "Sender", "Receiver", "Feature"))
fwrite(dir_sum, file.path(s_dir, "celltype_pairs_directed_ranking.csv"))

und_sum <- summarise_features(und_raw$features)
und_pairs <- pair_index[Feature %in% und_sum$Feature]
und_sum <- merge(und_pairs, und_sum, by = "Feature")
und_sum[, Interaction := paste0(pretty_ct[Sender], " <-> ", pretty_ct[Receiver])]
setorder(und_sum, -MedianPctOfTotal)
und_sum[, CohortRank := .I]
setcolorder(und_sum, c("CohortRank", "Interaction", "Sender", "Receiver", "Feature"))
fwrite(und_sum, file.path(s_dir, "celltype_pairs_undirected_ranking.csv"))

# per-sender / per-receiver totals (outgoing and incoming communication)
role <- rbind(
  dir_sum[, .(Role = "Sender (outgoing)", MedianOfSum = NA_real_), by = .(CellType = Sender)],
  dir_sum[, .(Role = "Receiver (incoming)", MedianOfSum = NA_real_), by = .(CellType = Receiver)]
)
feat_mat <- as.matrix(dir_raw$features)
for (i in seq_len(nrow(role))) {
  cols <- if (role$Role[i] == "Sender (outgoing)") dir_sum[Sender == role$CellType[i], Feature]
          else dir_sum[Receiver == role$CellType[i], Feature]
  role$MedianOfSum[i] <- median(rowSums(feat_mat[, cols, drop = FALSE]))
}
role[, CellTypeLabel := pretty_ct[CellType]]
role[, MedianAbundance := apply(inp$Cmatrix, 2, median)[CellType]]
fwrite(role[order(Role, -MedianOfSum)], file.path(s_dir, "celltype_sender_receiver_totals.csv"))

# per-patient top interactions
pt_top <- rbindlist(lapply(patients, function(p) {
  v <- feat_mat[p, ]; o <- order(-v)[1:5]
  data.table(Patient = p, Rank = 1:5, Feature = names(v)[o], Score = v[o],
             PctOfTotal = 100 * v[o] / sum(v))
}))
pt_top <- merge(pt_top, dir_sum[, .(Feature, Interaction)], by = "Feature")
pt_top <- merge(pt_top, meta, by = "Patient")
setorder(pt_top, Patient, Rank)
fwrite(pt_top[, .(Patient, Response, Therapy, Rank, Interaction, Score, PctOfTotal)],
       file.path(s_dir, "per_patient_top5_interactions.csv"))
top1 <- pt_top[Rank == 1, .N, by = Interaction][order(-N)]
top1[, PctPatients := 100 * N / length(patients)]
fwrite(top1, file.path(s_dir, "most_frequent_top1_interaction.csv"))

# ---- 3. Ligand-receptor pairs behind each cell-type pair --------------------
lr_all <- rbindlist(lapply(seq_len(nrow(pair_index)), function(i) {
  x <- computeLRContributions(inp$Lmatrix, inp$Rmatrix, inp$Cmatrix, inp$LRmatrix,
                              celltypes, sender = pair_index$Sender[i],
                              receiver = pair_index$Receiver[i], bundle = FALSE,
                              patient_names = patients)
  if (is.null(x)) return(NULL)
  as.data.table(x)[, .(Patient, Sender, Receiver, Ligand, Receptor, Contribution, PctOfTotal)]
}))
# sanity check: contributions add up to the kernel score of each cell-type pair
chk <- lr_all[, .(S = sum(Contribution)), by = .(Patient, Sender, Receiver)]
chk[, K := feat_mat[cbind(Patient, paste0("Dir_", Sender, "_", Receiver))]]
stopifnot(max(abs(chk$S - chk$K)) < 1e-10)
fwrite(lr_all, file.path(lr_dir, "lr_contributions_all_pairs_all_patients.csv.gz"))

n_pt <- length(patients)
lr_all[, LR := paste0(Ligand, "-", Receptor)]

# (a) LR pairs ranked within each sender->receiver pair (missing = 0 contribution)
lr_by_pair <- lr_all[, .(MeanContribution = sum(Contribution) / n_pt,
                         MeanPctOfPair = sum(PctOfTotal) / n_pt,
                         PctPatientsPresent = 100 * .N / n_pt),
                     by = .(Sender, Receiver, Ligand, Receptor, LR)]
lr_by_pair[, Interaction := paste0(pretty_ct[Sender], " -> ", pretty_ct[Receiver])]
setorder(lr_by_pair, Sender, Receiver, -MeanContribution)
lr_by_pair[, RankInPair := seq_len(.N), by = .(Sender, Receiver)]
fwrite(lr_by_pair, file.path(lr_dir, "lr_pairs_per_celltype_pair.csv"))

top_pairs <- dir_sum[1:10, .(Sender, Receiver, CohortRank)]
lr_top_pairs <- merge(lr_by_pair[RankInPair <= 10], top_pairs, by = c("Sender", "Receiver"))
setorder(lr_top_pairs, CohortRank, RankInPair)
fwrite(lr_top_pairs, file.path(lr_dir, "top10_LR_pairs_for_top10_celltype_pairs.csv"))

# (b) LR pairs ranked over all communication (summed over cell-type pairs)
pt_total <- rowSums(feat_mat)
lr_pt <- lr_all[, .(Contribution = sum(Contribution)), by = .(Patient, Ligand, Receptor, LR)]
lr_pt[, PctOfPatientTotal := 100 * Contribution / pt_total[Patient]]
lr_pt[, RankInPatient := frank(-Contribution, ties.method = "min"), by = Patient]
lr_global <- lr_pt[, .(MeanPctOfTotal = sum(PctOfPatientTotal) / n_pt,
                       MedianPctOfTotal = median(c(PctOfPatientTotal, rep(0, n_pt - .N))),
                       PctPatientsTop20 = 100 * sum(RankInPatient <= 20) / n_pt,
                       PctPatientsPresent = 100 * .N / n_pt),
                   by = .(Ligand, Receptor, LR)]
main_pair <- lr_all[, .(C = sum(Contribution)), by = .(LR, Sender, Receiver)][
  order(-C), .(MainCellPair = paste0(pretty_ct[Sender[1]], " -> ", pretty_ct[Receiver[1]]),
               MainCellPairPct = 100 * C[1] / sum(C)), by = LR]
lr_global <- merge(lr_global, main_pair, by = "LR")
setorder(lr_global, -MeanPctOfTotal)
lr_global[, CohortRank := .I]
setcolorder(lr_global, "CohortRank")
fwrite(lr_global, file.path(lr_dir, "lr_pairs_global_ranking.csv"))

# ---- 4. Figures -------------------------------------------------------------
save_plot <- function(p, name, w, h) {
  ggsave(file.path(f_dir, paste0(name, ".pdf")), p, width = w, height = h)
  ggsave(file.path(f_dir, paste0(name, ".png")), p, width = w, height = h, dpi = 200)
}
ct_order <- names(pretty_ct)[names(pretty_ct) %in% celltypes]
hm <- copy(dir_sum)[, `:=`(SenderL = factor(pretty_ct[Sender], pretty_ct[ct_order]),
                           ReceiverL = factor(pretty_ct[Receiver], pretty_ct[ct_order]))]

p1 <- ggplot(hm, aes(ReceiverL, SenderL, fill = MedianPctOfTotal)) +
  geom_tile(colour = "white") +
  geom_text(aes(label = sprintf("%.1f", MedianPctOfTotal)), size = 2.8) +
  scale_fill_gradient(low = "white", high = "firebrick", name = "% of total\n(median)") +
  labs(x = "Receiver", y = "Sender",
       title = "RaCInG direct communication - Gide cohort (n = 73)",
       subtitle = "Median % of each patient's total direct communication") +
  theme_minimal(base_size = 10) + theme(axis.text.x = element_text(angle = 45, hjust = 1))
save_plot(p1, "heatmap_directed_communication_median", 7.5, 6)

p2 <- ggplot(hm, aes(ReceiverL, SenderL, fill = log2(MedianEnrichment))) +
  geom_tile(colour = "white") +
  geom_text(aes(label = sprintf("%.2f", MedianEnrichment)), size = 2.6) +
  scale_fill_gradient2(low = "steelblue", mid = "white", high = "firebrick",
                       name = "log2 median\nenrichment") +
  labs(x = "Receiver", y = "Sender",
       title = "Communication enrichment vs. uniform ligand-receptor baseline",
       subtitle = "Median ratio across patients (1 = expected from abundance/topology)") +
  theme_minimal(base_size = 10) + theme(axis.text.x = element_text(angle = 45, hjust = 1))
save_plot(p2, "heatmap_directed_enrichment_median", 7.5, 6)

top20 <- dir_sum[1:20]
long20 <- melt(as.data.table(feat_mat[, top20$Feature] / rowSums(feat_mat), keep.rownames = "Patient"),
               id.vars = "Patient", variable.name = "Feature", value.name = "Score")
long20 <- merge(long20, top20[, .(Feature, Interaction)], by = "Feature")
long20[, Interaction := factor(Interaction, rev(top20$Interaction))]
p3 <- ggplot(long20, aes(Score * 100, Interaction)) +
  geom_boxplot(outlier.size = 0.6, fill = "grey90") +
  labs(x = "% of total direct communication", y = NULL,
       title = "Top 20 directed cell-cell interactions (ranked by cohort median)") +
  theme_bw(base_size = 10)
save_plot(p3, "boxplot_top20_directed_interactions", 7.5, 6)

und20 <- und_sum[1:20]
p3b <- ggplot(und20, aes(MedianPctOfTotal, factor(Interaction, rev(Interaction)))) +
  geom_col(fill = "grey40") +
  geom_errorbar(aes(xmin = Q1PctOfTotal, xmax = Q3PctOfTotal), width = 0.3, orientation = "y") +
  labs(x = "% of total direct communication (median and IQR across patients)", y = NULL,
       title = "Top 20 cell-type pairs, both directions merged") + theme_bw(base_size = 10)
save_plot(p3b, "barplot_top20_undirected_interactions", 7.5, 6)

# patient x interaction heatmap (top 30 directed interactions, z-scored)
top30 <- dir_sum[1:30]
mat <- t(feat_mat[, top30$Feature])
rownames(mat) <- top30$Interaction
ann <- data.frame(Response = meta$Response, Therapy = meta$Therapy, row.names = meta$Patient)
pheatmap(mat, scale = "row", annotation_col = ann, show_colnames = FALSE,
         clustering_method = "ward.D2", fontsize_row = 8,
         color = colorRampPalette(c("steelblue", "white", "firebrick"))(100),
         breaks = seq(-3, 3, length.out = 101),
         main = "Top 30 directed interactions across patients (row z-score)",
         filename = file.path(f_dir, "heatmap_patients_top30_interactions.pdf"), width = 11, height = 7)
pheatmap(mat, scale = "row", annotation_col = ann, show_colnames = FALSE,
         clustering_method = "ward.D2", fontsize_row = 8,
         color = colorRampPalette(c("steelblue", "white", "firebrick"))(100),
         breaks = seq(-3, 3, length.out = 101),
         main = "Top 30 directed interactions across patients (row z-score)",
         filename = file.path(f_dir, "heatmap_patients_top30_interactions.png"), width = 11, height = 7)

g25 <- lr_global[1:25]
p4 <- ggplot(g25, aes(MeanPctOfTotal, factor(LR, rev(LR)), fill = PctPatientsTop20)) +
  geom_col() +
  scale_fill_gradient(low = "grey80", high = "darkgreen", name = "% patients\nwith LR in\ntheir top 20") +
  labs(x = "Mean % of total direct communication", y = NULL,
       title = "Top 25 ligand-receptor pairs (all cell-type pairs combined)") +
  theme_bw(base_size = 10)
save_plot(p4, "barplot_top25_LR_pairs_global", 7.5, 6.5)

dp <- lr_top_pairs[RankInPair <= 5]
dp[, Interaction := factor(Interaction, unique(Interaction[order(CohortRank)]))]
p5 <- ggplot(dp, aes(Interaction, factor(LR, rev(unique(LR[order(CohortRank, RankInPair)]))))) +
  geom_point(aes(size = MeanPctOfPair, colour = PctPatientsPresent)) +
  scale_colour_gradient(low = "orange", high = "darkred", name = "% patients\nwith pair") +
  scale_size_continuous(name = "Mean % of\ncell-pair\ncommunication") +
  labs(x = NULL, y = NULL,
       title = "Top 5 ligand-receptor pairs of the 10 most common cell-cell interactions") +
  theme_bw(base_size = 9) + theme(axis.text.x = element_text(angle = 45, hjust = 1),
                                 plot.margin = margin(5.5, 5.5, 5.5, 60))
save_plot(p5, "dotplot_top_LR_per_top10_celltype_pairs", 9, 9)

# ---- 5. Console summary -----------------------------------------------------
cat("\nTop 15 directed interactions:\n")
print(dir_sum[1:15, .(CohortRank, Interaction, MedianPctOfTotal = round(MedianPctOfTotal, 2),
                      PctPatientsTop5 = round(PctPatientsTop5), MedianEnrichment = round(MedianEnrichment, 2))])
cat("\nTop 10 undirected interactions:\n")
print(und_sum[1:10, .(CohortRank, Interaction, MedianPctOfTotal = round(MedianPctOfTotal, 2),
                      PctPatientsTop5 = round(PctPatientsTop5))])
cat("\nMost frequent #1 interaction per patient:\n"); print(head(top1, 8))
cat("\nSender/receiver totals:\n"); print(role[order(Role, -MedianOfSum)])
cat("\nTop 20 LR pairs overall:\n")
print(lr_global[1:20, .(CohortRank, LR, MeanPctOfTotal = round(MeanPctOfTotal, 2),
                        PctPatientsTop20 = round(PctPatientsTop20), MainCellPair,
                        MainCellPairPct = round(MainCellPairPct))])
cat("\nTop 5 LR pairs of the top 10 directed interactions:\n")
print(lr_top_pairs[RankInPair <= 5, .(CohortRank, Interaction, LR,
                                      MeanPctOfPair = round(MeanPctOfPair, 2),
                                      PctPatientsPresent = round(PctPatientsPresent))])
cat("\nTop 10 directed interactions by enrichment (pairs with median share >= 0.5%):\n")
print(dir_sum[MedianPctOfTotal >= 0.5][order(-MedianEnrichment)][1:10,
      .(Interaction, MedianEnrichment = round(MedianEnrichment, 2), MedianPctOfTotal = round(MedianPctOfTotal, 2))])
