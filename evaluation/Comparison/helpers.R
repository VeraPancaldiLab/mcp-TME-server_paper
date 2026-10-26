# Small helpers shared by the ScenarioN_comparison.qmd reports.
# All paths are relative to the repository root.

library(ggplot2)
library(knitr)

options(knitr.kable.NA = "")

runs = c("Groundtruth", "Baseline Opus", "LLM-MCP Opus", "Baseline Sonnet", "LLM-MCP Sonnet")
agent_runs = runs[-1]

# One colour per arm; the ground truth is grey.
arm_colors = c("Baseline" = "#2a78d6", "LLM-MCP" = "#eb6834", "Groundtruth" = "#52514e")
arm_of = function(run) sub(" .*", "", run)

# Colours of the other groups shown in the plots.
response_colors = c("R" = "#1baf7a", "NR" = "#4a3aa7")
subtype_colors = c("IE/F" = "#1baf7a", "D" = "#4a3aa7", "uncharacterized" = "#c3c2b7")

theme_set(theme_minimal() + theme(legend.position = "top"))

# Gide sample names start with a digit, so some runs stored them with an "X" or "S" prefix.
clean_id = function(x) sub("^[XS](?=[0-9])", "", x, perl = TRUE)

# Clinical data of one cohort. Expression column names match rna_id.
load_coldata = function(cohort) {
  coldata = read.table("data/colData_all.txt", header = TRUE, sep = " ", quote = "\"")
  coldata[coldata$Cohort == cohort, c("rna_id", "Response", "Therapy")]
}

# Cell type of a deconvolution feature, named "Method_Signature_CellType" or "CellType_Subgroup.1".
cell_type = function(feature) {
  ifelse(grepl("_Subgroup", feature), sub("_Subgroup.*", "", feature), sub(".*_", "", feature))
}

# Names of the n highest values of a named vector.
top_names = function(x, n) names(sort(x, decreasing = TRUE))[1:n]

# Save the last plot as PDF and PNG in evaluation/Comparison/figures/<name>,
# where name is "<scenario folder>/<figure>", e.g. "Scenario1/response".
save_figure = function(name, width, height) {
  file = paste0("evaluation/Comparison/figures/", name)
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  ggsave(paste0(file, ".pdf"), width = width, height = height)
  ggsave(paste0(file, ".png"), width = width, height = height, dpi = 300)
}

# File with a standard result of one run (written by the run itself in results/standard/),
# e.g. standard_file("Baseline Opus", 1, "immune_score.csv").
standard_file = function(run, scenario, file, repetition = 1) {
  arm_model = strsplit(run, " ")[[1]]
  file.path("evaluation", arm_model[1], arm_model[2], paste0("Scenario", scenario),
            paste0("rep", repetition), "results/standard", file)
}

# A standard table as a numeric matrix with one row per patient.
read_standard = function(run, scenario, file) {
  tab = read.csv(standard_file(run, scenario, file), check.names = FALSE)
  m = as.matrix(tab[, -1, drop = FALSE])
  rownames(m) = clean_id(tab$patient)
  m
}

# R writes some names with a dot where the original has a hyphen (NKX2.1, JAK.STAT, CBSX.HNSCC):
# same style everywhere.
dotted = function(m) {
  colnames(m) = make.names(colnames(m))
  m
}

# Composition of the deconvolution subgroups of a run: one row per member (subgroup, feature).
# A feature left alone is not a subgroup (some runs also listed those).
read_subgroups = function(run, scenario) {
  tab = read.csv(standard_file(run, scenario, "subgroups_composition.csv"))
  tab[tab$subgroup %in% names(which(table(tab$subgroup) > 1)), ]
}

# ---- Scores against the ground truth: reproduced / ground-truth total ----
# What a run does not have is not reproduced, so it lowers the score.

# Same values: identical, or correlation of at least 0.99 across patients
# (CIBERSORTx and DWLS do not return exactly the same numbers in two executions).
same_scores = function(x, y) {
  if (max(abs(x - y)) < 1e-6) return(TRUE)
  correlation = cor(x, y)
  !is.na(correlation) && correlation >= 0.99
}

# Features matched by name: columns of two patients x features matrices.
score_by_name = function(run, gt) {
  shared = intersect(colnames(run), colnames(gt))
  identical_values = vapply(shared, function(f) max(abs(run[, f] - gt[, f])) < 1e-6, logical(1))  # vapply: also when nothing is shared
  reproduced = vapply(shared, function(f) same_scores(run[, f], gt[, f]), logical(1))
  data.frame(GT = ncol(gt), Present = length(shared), Identical = sum(identical_values),
             Reproduced = sum(reproduced), Score = sum(reproduced) / ncol(gt))
}

# Members of each group as one text, e.g. "A + B + C".
members = function(x, group, member) {
  sapply(split(x[[member]], x[[group]]), function(m) paste(sort(unique(m)), collapse = " + "))
}

# Groups matched by composition: a ground-truth group is reproduced when the run has a group
# with exactly the same members, whatever its name. With scores, also whether that group has
# the same scores.
score_by_composition = function(run, gt, group, member, run_scores = NULL, gt_scores = NULL) {
  run_members = members(run, group, member)
  gt_members = members(gt, group, member)
  same_group = names(run_members)[match(gt_members, run_members)]  # run group with the same members, or NA
  found = !is.na(same_group)

  result = data.frame(GT = length(gt_members), Run = length(run_members),
                      Composition_reproduced = sum(found), Composition_score = mean(found))
  if (!is.null(run_scores)) {
    reproduced = sapply(which(found), function(i) same_scores(run_scores[, same_group[i]], gt_scores[, names(gt_members)[i]]))
    result$Scores_reproduced = sum(unlist(reproduced))
    result$Scores_score = sum(unlist(reproduced)) / length(gt_members)
  }
  result
}

# One table with a row per run, from a function that scores one run.
by_run = function(score) {
  tab = data.frame()
  for (r in agent_runs) tab = rbind(tab, cbind(Run = r, score(r)))
  tab
}

# Tables written by extract_run_metrics.py, for one scenario.
metrics_table = function(file, scenario) {
  tab = read.csv(file.path("evaluation/Comparison/metrics", file))
  tab = tab[tab$scenario == scenario, colnames(tab) != "scenario"]
  rownames(tab) = NULL
  tab
}

# Bar plot of the process metrics of one scenario (output of metrics_table).
process_plot = function(metrics) {
  metrics$total_tokens = metrics$total_tokens / 1e6
  shown = c("time_min" = "Time (min)", "cost_usd" = "Cost (USD)", "tool_calls" = "Tool calls",
            "tool_errors" = "Tool errors", "total_tokens" = "Tokens (millions)")

  long = data.frame()
  for (m in names(shown)) {
    long = rbind(long, data.frame(arm = metrics$arm, model = metrics$model, metric = shown[[m]], value = metrics[[m]]))
  }
  long$metric = factor(long$metric, levels = shown)

  ggplot(long, aes(model, value, fill = arm)) +
    geom_col(position = position_dodge(width = 0.8), width = 0.7) +
    geom_text(aes(label = round(value, 1)), position = position_dodge(width = 0.8), vjust = -0.4, size = 3) +
    facet_wrap(~metric, scales = "free_y", nrow = 1) +
    scale_fill_manual(values = arm_colors) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
    labs(x = NULL, y = NULL, fill = NULL)
}
