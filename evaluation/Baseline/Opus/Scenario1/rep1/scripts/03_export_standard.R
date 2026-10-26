# Step 3: copy existing results into a standard format (no recomputation)
proj <- "/home/marcelo.hurtado/Documents/tme_analysis/548819f72e/work"
res  <- file.path(proj, "results")
out  <- file.path(res, "standard"); dir.create(out, showWarnings = FALSE)

input_ids <- strsplit(readLines(file.path(proj, "data/Gide_log2TPM.txt"), n = 1), "\t")[[1]][-1]
id_map <- setNames(input_ids, make.names(input_ids))   # undo multideconv's "X" prefix

to_std <- function(f) {
  x <- read.csv(file.path(res, f), check.names = FALSE, stringsAsFactors = FALSE)
  ids <- x[[1]]; ids <- ifelse(ids %in% input_ids, ids, id_map[ids])
  stopifnot(!anyNA(ids), setequal(ids, input_ids))
  data.frame(patient = ids, x[, -1, drop = FALSE], check.names = FALSE)
}

raw  <- to_std("deconvolution_raw_features.csv")
harm <- to_std("deconvolution_processed_features.csv")
write.csv(raw,  file.path(out, "deconvolution_raw.csv"), row.names = FALSE)
write.csv(harm, file.path(out, "deconvolution_harmonized.csv"), row.names = FALSE)

comp <- read.csv(file.path(res, "deconvolution_subgroups_composition.csv"), stringsAsFactors = FALSE)
stopifnot(all(comp$feature %in% colnames(raw)), all(comp$subgroup %in% colnames(harm)))
write.csv(comp[, c("subgroup", "feature")], file.path(out, "subgroups_composition.csv"), row.names = FALSE)

rk <- read.csv(file.path(res, "patient_immune_infiltration_ranking.csv"), check.names = FALSE, stringsAsFactors = FALSE)
stopifnot(setequal(rk$sample, input_ids))
write.csv(data.frame(patient = rk$sample, immune_score = rk$immune_score, stromal_score = rk$stromal_score),
          file.path(out, "immune_score.csv"), row.names = FALSE)

writeLines('{"input_scale": "linear TPM", "methods": ["Quantiseq", "DeconRNASeq", "Epidish", "DWLS"], "cibersortx": false}',
           file.path(out, "info.json"))
