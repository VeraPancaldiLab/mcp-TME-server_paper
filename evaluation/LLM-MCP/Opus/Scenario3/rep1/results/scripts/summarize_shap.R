# Summarize test-set performance and SHAP feature drivers of the Gide-trained TME model.
suppressMessages(library(ggplot2))
args <- commandArgs(trailingOnly = TRUE)
res <- if (length(args)) args[1] else "results"
out <- file.path(res, "06_feature_drivers_summary")
dir.create(out, showWarnings = FALSE, recursive = TRUE)

# --- External test performance (Riaz)
pred <- readRDS(file.path(res, "04_external_test_Riaz/prediction/result.rds"))
auc <- pred$AUC
capture.output(str(auc), file = file.path(out, "Riaz_test_AUC.txt"))
print(auc)

# Riaz predictions also stratified by observed response
cl <- read.csv(file.path(res, "inputs/Riaz_clinical.csv"), stringsAsFactors = FALSE)
p <- pred$Predictions
p$sample <- rownames(p); p$Response <- cl$Response[match(p$sample, cl$sample)]
write.csv(p, file.path(out, "Riaz_predictions_with_response.csv"), row.names = FALSE)
print(wilcox.test(yes ~ Response, data = p))

# --- SHAP global importance and direction
shap <- read.csv(file.path(res, "05_SHAP_feature_importance/result.csv"), row.names = 1, check.names = FALSE)
model <- readRDS(file.path(res, "03_model_training_Gide/result.rds"))
X <- model$Model$trainingData
X <- X[, colnames(shap), drop = FALSE]
y <- model$Model$trainingData$.outcome

imp <- data.frame(
  feature = colnames(shap),
  mean_abs_SHAP = colMeans(abs(shap)),
  # Direction: Spearman correlation between a feature's value and its SHAP value
  # (> 0: higher abundance pushes the prediction toward response)
  direction_rho = sapply(colnames(shap), function(f) suppressWarnings(cor(X[[f]], shap[[f]], method = "spearman"))),
  median_in_R = sapply(colnames(shap), function(f) median(X[[f]][y == "yes"])),
  median_in_NR = sapply(colnames(shap), function(f) median(X[[f]][y == "no"])),
  wilcox_p_R_vs_NR = sapply(colnames(shap), function(f) suppressWarnings(wilcox.test(X[[f]] ~ y)$p.value))
)
imp$effect <- ifelse(imp$direction_rho > 0, "higher -> Response", "higher -> Non-response")
imp$cell_type <- sub("_Subgroup\\..*$", "", sub("^[^_]+_[^_]+_", "", imp$feature))
imp <- imp[order(-imp$mean_abs_SHAP), ]
imp$rank <- seq_len(nrow(imp))

# Subgroup composition: which method/signature features each subgroup merges
comp <- model$Custom_output[["Deconvolution subgroups composition"]]
members <- unlist(unname(lapply(comp, function(ct) {
  if (is.null(ct) || !length(ct)) return(NULL)
  sapply(ct, function(m) paste(m, collapse = "; "))
})))
imp$subgroup_members <- ifelse(imp$feature %in% names(members), members[imp$feature], "")
write.csv(imp, file.path(out, "SHAP_feature_importance_ranked.csv"), row.names = FALSE)

# Aggregate importance per cell type
ct <- aggregate(mean_abs_SHAP ~ cell_type, imp, sum)
ct <- ct[order(-ct$mean_abs_SHAP), ]
write.csv(ct, file.path(out, "SHAP_importance_per_cell_type.csv"), row.names = FALSE)

print(head(imp[, c("rank", "feature", "mean_abs_SHAP", "direction_rho", "effect", "wilcox_p_R_vs_NR")], 25), row.names = FALSE)
print(head(ct, 15), row.names = FALSE)

# --- Plots
top <- head(imp, 20)
top$feature <- factor(top$feature, levels = rev(top$feature))
g1 <- ggplot(top, aes(mean_abs_SHAP, feature, fill = effect)) + geom_col() +
  scale_fill_manual(values = c("higher -> Response" = "#2b8cbe", "higher -> Non-response" = "#e34a33")) +
  labs(x = "mean |SHAP| (probability of response)", y = NULL, fill = NULL,
       title = "Top 20 TME features driving response prediction (RF, Gide)") +
  theme_bw() + theme(legend.position = "bottom")
ggsave(file.path(out, "SHAP_top20_importance.pdf"), g1, width = 9, height = 7)

long <- do.call(rbind, lapply(as.character(top$feature), function(f)
  data.frame(feature = f, shap = shap[[f]], value = rank(X[[f]]) / nrow(X))))
long$feature <- factor(long$feature, levels = levels(top$feature))
g2 <- ggplot(long, aes(shap, feature, colour = value)) +
  geom_vline(xintercept = 0, colour = "grey60") +
  geom_jitter(height = 0.2, size = 1.4) +
  scale_colour_gradient(low = "#3182bd", high = "#de2d26", name = "Feature value\n(rank, low->high)") +
  labs(x = "SHAP value (impact on P(response))", y = NULL, title = "SHAP beeswarm, top 20 features") +
  theme_bw()
ggsave(file.path(out, "SHAP_top20_beeswarm.pdf"), g2, width = 10, height = 7)

ctp <- head(ct, 15); ctp$cell_type <- factor(ctp$cell_type, levels = rev(ctp$cell_type))
g3 <- ggplot(ctp, aes(mean_abs_SHAP, cell_type)) + geom_col(fill = "grey40") +
  labs(x = "summed mean |SHAP| over the cell type's features", y = NULL, title = "Importance per cell type") + theme_bw()
ggsave(file.path(out, "SHAP_importance_per_cell_type.pdf"), g3, width = 8, height = 6)
