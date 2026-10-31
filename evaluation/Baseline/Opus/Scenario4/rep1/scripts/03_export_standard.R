# Export existing RaCInG results to a standard format (conversion only, nothing recomputed)
suppressPackageStartupMessages(library(data.table))

std_dir <- "results/standard"
dir.create(std_dir, recursive = TRUE, showWarnings = FALSE)

to_long <- function(path, value_name) {
  m <- as.matrix(read.csv(path, row.names = 1, check.names = FALSE))
  idx <- which(m > 0, arr.ind = TRUE)
  out <- data.table(cell_type = rownames(m)[idx[, "row"]], x = colnames(m)[idx[, "col"]])
  setnames(out, "x", value_name)
  setorderv(out, c("cell_type", value_name))
  list(table = out, celltypes = rownames(m))
}

lig <- to_long("results/racing_input/Lmatrix_Gide.csv", "ligand")
rec <- to_long("results/racing_input/Rmatrix_Gide.csv", "receptor")
stopifnot(setequal(lig$celltypes, rec$celltypes))
fwrite(lig$table, file.path(std_dir, "ligands.csv"))
fwrite(rec$table, file.path(std_dir, "receptors.csv"))

# Undirected raw kernel features, as returned by compute_racing_kernel(remove_direction = TRUE)
und <- read.csv("results/kernel/direct_communication_undirected_raw.csv",
                row.names = 1, check.names = FALSE)
celltypes <- lig$celltypes
stopifnot(!any(grepl("_", celltypes)))  # so "Dir_A_B" splits unambiguously
parts <- strsplit(sub("^Dir_", "", colnames(und)), "_", fixed = TRUE)
stopifnot(all(lengths(parts) == 2), all(unlist(parts) %in% celltypes))
new_names <- vapply(parts, function(p) paste(p[1], "-", p[2]), character(1))
stopifnot(!anyDuplicated(new_names))

# read-only consistency check against the directed raw features (A-B = A->B + B->A, A-A = 2 * A->A)
dir <- read.csv("results/kernel/direct_communication_directed_raw.csv",
                row.names = 1, check.names = FALSE)
stopifnot(identical(rownames(dir), rownames(und)))
for (j in seq_along(parts)) {
  a <- parts[[j]][1]; b <- parts[[j]][2]
  expected <- dir[[paste0("Dir_", a, "_", b)]] + dir[[paste0("Dir_", b, "_", a)]]
  stopifnot(max(abs(und[[j]] - expected)) < 1e-12)
}

# patient names exactly as in the input data
input_samples <- colnames(fread("data/Gide_log2TPM.txt", nrows = 0))[-1]
stopifnot(setequal(rownames(und), input_samples), !anyDuplicated(rownames(und)))

out <- data.table(patient = rownames(und), und, check.names = FALSE)
setnames(out, c("patient", new_names))
fwrite(out, file.path(std_dir, "direct_interactions.csv"))

cat("ligands.csv:", nrow(lig$table), "rows;", "receptors.csv:", nrow(rec$table), "rows;",
    "direct_interactions.csv:", nrow(out), "patients x", ncol(out) - 1, "pairs\n")
