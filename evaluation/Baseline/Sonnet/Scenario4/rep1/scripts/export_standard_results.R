#!/usr/bin/env Rscript
# Convert already-produced RaCInG results (results/*.rds, results/*.csv) into
# standard-format CSVs under results/standard/. No new computation.

results_dir  <- "/home/marcelo.hurtado/Documents/tme_analysis/b0f19b8438/work/results"
out_dir      <- file.path(results_dir, "standard")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

input      <- readRDS(file.path(results_dir, "Gide_racing_input.rds"))
kernel_res <- readRDS(file.path(results_dir, "Gide_kernel_result.rds"))
id_map     <- read.csv(file.path(results_dir, "Gide_sample_id_mapping.csv"), stringsAsFactors = FALSE)

celltypes <- input$celltypes

## ---------------------------------------------------------------------------
## ligands.csv : Lmatrix (cell type x ligand) -> long format
## ---------------------------------------------------------------------------
Lmatrix <- input$Lmatrix
if (is.null(rownames(Lmatrix))) rownames(Lmatrix) <- celltypes
lig_idx <- which(Lmatrix == 1, arr.ind = TRUE)
ligands_df <- data.frame(
  cell_type = rownames(Lmatrix)[lig_idx[, "row"]],
  ligand    = colnames(Lmatrix)[lig_idx[, "col"]]
)
ligands_df <- ligands_df[order(ligands_df$cell_type, ligands_df$ligand), ]
write.csv(ligands_df, file.path(out_dir, "ligands.csv"), row.names = FALSE)

## ---------------------------------------------------------------------------
## receptors.csv : Rmatrix (cell type x receptor) -> long format
## ---------------------------------------------------------------------------
Rmatrix <- input$Rmatrix
if (is.null(rownames(Rmatrix))) rownames(Rmatrix) <- celltypes
rec_idx <- which(Rmatrix == 1, arr.ind = TRUE)
receptors_df <- data.frame(
  cell_type = rownames(Rmatrix)[rec_idx[, "row"]],
  receptor  = colnames(Rmatrix)[rec_idx[, "col"]]
)
receptors_df <- receptors_df[order(receptors_df$cell_type, receptors_df$receptor), ]
write.csv(receptors_df, file.path(out_dir, "receptors.csv"), row.names = FALSE)

## ---------------------------------------------------------------------------
## direct_interactions.csv : kernel features (raw, direction already removed)
## columns "Dir_<A>_<B>" -> "<A> - <B>"; rows renamed to original sample IDs
## ---------------------------------------------------------------------------
features <- kernel_res$features

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

new_colnames <- vapply(colnames(features), function(cn) {
  pair <- parse_pair(cn, celltypes)
  paste(pair[1], "-", pair[2])
}, character(1))

direct_df <- as.data.frame(features)
colnames(direct_df) <- new_colnames

patient_ids <- id_map$Sample_id[match(rownames(features), id_map$RaCInG_id)]
if (anyNA(patient_ids)) stop("Could not map all RaCInG patient IDs back to original sample IDs.")

direct_df <- cbind(patient = patient_ids, direct_df)
write.csv(direct_df, file.path(out_dir, "direct_interactions.csv"), row.names = FALSE)

cat("Written:\n")
cat(" -", file.path(out_dir, "ligands.csv"), sprintf("(%d rows)\n", nrow(ligands_df)))
cat(" -", file.path(out_dir, "receptors.csv"), sprintf("(%d rows)\n", nrow(receptors_df)))
cat(" -", file.path(out_dir, "direct_interactions.csv"), sprintf("(%d patients x %d pairs)\n", nrow(direct_df), ncol(direct_df) - 1))
