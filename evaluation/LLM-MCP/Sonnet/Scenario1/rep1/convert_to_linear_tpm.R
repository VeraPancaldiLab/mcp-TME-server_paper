args <- commandArgs(trailingOnly = TRUE)
in_file <- args[1]
out_file <- args[2]

df <- read.delim(in_file, check.names = FALSE, row.names = 1)
df_lin <- 2^df - 1
df_lin[df_lin < 0] <- 0

out <- data.frame(gene = rownames(df_lin), df_lin, check.names = FALSE)
write.csv(out, out_file, quote = FALSE, row.names = FALSE)
