# Export existing RaCInG results (Gide) to the standard format in standard/.
# Pure format conversion: no recomputation. Run from the results/ directory.
out <- "standard"
dir.create(out, showWarnings = FALSE)

inputs <- readRDS("racing_inputs/result.rds")
kern <- readRDS("racing_kernel/result.rds")
map <- read.csv("sample_id_mapping.csv")
ct <- inputs$celltypes

# Lmatrix/Rmatrix rows are unnamed in result.rds; their order is inputs$celltypes
# (checked against the named copies in racing_inputs/Results/{L,R}matrix_Gide.csv).
long_assign <- function(M, cols, what) {
  stopifnot(nrow(M) == length(ct), ncol(M) == length(cols), all(M %in% c(0, 1)))
  w <- which(M == 1, arr.ind = TRUE)
  d <- data.frame(cell_type = ct[w[, 1]], x = cols[w[, 2]])
  names(d)[2] <- what
  d[order(match(d$cell_type, ct), d[[what]]), ]
}
lig <- long_assign(inputs$Lmatrix, inputs$ligands, "ligand")
rec <- long_assign(inputs$Rmatrix, inputs$receptors, "receptor")
write.csv(lig, file.path(out, "ligands.csv"), row.names = FALSE)
write.csv(rec, file.path(out, "receptors.csv"), row.names = FALSE)

# Kernel features: raw (norm = FALSE) and already undirected (remove_direction = TRUE),
# so only the column names are converted from Dir_<A>_<B> to "<A> - <B>".
feat <- as.matrix(kern$features)
pairs <- expand.grid(i = seq_along(ct), j = seq_along(ct))
key_ab <- paste0("Dir_", ct[pairs$i], "_", ct[pairs$j])
m <- match(colnames(feat), key_ab)
stopifnot(!anyNA(m), !anyDuplicated(m))
new_names <- paste(ct[pairs$i[m]], "-", ct[pairs$j[m]])
# each unordered pair must appear only once
unordered <- paste(pmin(pairs$i[m], pairs$j[m]), pmax(pairs$i[m], pairs$j[m]))
stopifnot(!anyDuplicated(unordered))
patient <- map$original[match(rownames(feat), map$racing_id)]
stopifnot(!anyNA(patient))
di <- data.frame(patient = patient, feat, check.names = FALSE)
colnames(di) <- c("patient", new_names)
write.csv(di, file.path(out, "direct_interactions.csv"), row.names = FALSE)

cat("ligands:", nrow(lig), "rows; receptors:", nrow(rec), "rows; direct_interactions:",
    nrow(di), "x", ncol(di), "\n")
