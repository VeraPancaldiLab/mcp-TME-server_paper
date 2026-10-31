raw_csv <- "/home/marcelo.hurtado/Documents/tme_analysis/6494fa1e21/work/results/Gide_raw_deconvolution_all_methods.csv"
harm_csv <- "/home/marcelo.hurtado/Documents/tme_analysis/6494fa1e21/work/results/Gide_harmonized_deconvolution_matrix.csv"
ranking_csv <- "/home/marcelo.hurtado/Documents/tme_analysis/6494fa1e21/work/results/Gide_immune_stromal_infiltration_ranking.csv"
analyze_rds <- "/home/marcelo.hurtado/Documents/tme_analysis/6494fa1e21/mcp-tme-servers/multideconv/runs/sessions/Gide_20261027-101149_a86227/Gide/analyze_deconvolution_20261027-104653_83ed71/result.rds"
out_dir <- "/home/marcelo.hurtado/Documents/tme_analysis/6494fa1e21/work/results/standard"

strip_x <- function(x) sub("^X", "", x)

# deconvolution_raw.csv
raw <- read.csv(raw_csv, check.names = FALSE, row.names = 1)
raw_out <- data.frame(patient = strip_x(rownames(raw)), raw, check.names = FALSE)
write.csv(raw_out, file.path(out_dir, "deconvolution_raw.csv"), row.names = FALSE)

# deconvolution_harmonized.csv
harm <- read.csv(harm_csv, check.names = FALSE, row.names = 1)
harm_out <- data.frame(patient = strip_x(rownames(harm)), harm, check.names = FALSE)
write.csv(harm_out, file.path(out_dir, "deconvolution_harmonized.csv"), row.names = FALSE)

# subgroups_composition.csv
res <- readRDS(analyze_rds)
comp <- res[["Deconvolution subgroups composition"]]
rows <- list()
for (cell_type in names(comp)) {
  subgroup_list <- comp[[cell_type]]
  for (subgroup_name in names(subgroup_list)) {
    features <- subgroup_list[[subgroup_name]]
    rows[[length(rows) + 1]] <- data.frame(subgroup = subgroup_name, feature = features, stringsAsFactors = FALSE)
  }
}
comp_out <- do.call(rbind, rows)
write.csv(comp_out, file.path(out_dir, "subgroups_composition.csv"), row.names = FALSE)

# immune_score.csv
ranking <- read.csv(ranking_csv, check.names = FALSE)
score_out <- data.frame(
  patient = ranking$Sample_id,
  immune_score = ranking$Immune_score,
  stromal_score = ranking$Stromal_score
)
write.csv(score_out, file.path(out_dir, "immune_score.csv"), row.names = FALSE)

cat("deconvolution_raw.csv rows:", nrow(raw_out), "cols:", ncol(raw_out), "\n")
cat("deconvolution_harmonized.csv rows:", nrow(harm_out), "cols:", ncol(harm_out), "\n")
cat("subgroups_composition.csv rows:", nrow(comp_out), "unique subgroups:", length(unique(comp_out$subgroup)), "\n")
cat("immune_score.csv rows:", nrow(score_out), "\n")
