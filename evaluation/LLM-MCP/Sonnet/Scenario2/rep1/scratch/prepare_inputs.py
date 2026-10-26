import csv

DATA_DIR = "/home/marcelo.hurtado/Documents/tme_analysis/2bf9b0464f/work/data"
OUT_DIR = "/home/marcelo.hurtado/Documents/tme_analysis/2bf9b0464f/work/scratch"

# 1. Convert log2(TPM+1) -> linear TPM
with open(f"{DATA_DIR}/Gide_log2TPM.txt") as fin, open(f"{OUT_DIR}/Gide_linearTPM.csv", "w", newline="") as fout:
    reader = csv.reader(fin, delimiter="\t")
    writer = csv.writer(fout)
    header = next(reader)
    writer.writerow(["gene"] + header[1:])
    for row in reader:
        gene = row[0]
        vals = [str(2 ** float(v) - 1) for v in row[1:]]
        writer.writerow([gene] + vals)

# 2. Subset colData_all.txt to Gide cohort, row names = sample IDs matching expression columns
with open(f"{DATA_DIR}/colData_all.txt") as fin, open(f"{OUT_DIR}/coldata_gide.csv", "w", newline="") as fout:
    reader = csv.reader(fin, delimiter=" ")
    writer = csv.writer(fout)
    header = [h.strip('"') for h in next(reader)]
    writer.writerow(["Sample"] + header)
    for row in reader:
        row = [c.strip('"') for c in row]
        if row[-1] == "Gide":
            writer.writerow([row[1]] + row)

print("done")
