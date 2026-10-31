import csv

SRC = "/home/marcelo.hurtado/Documents/tme_analysis/dcede5cb31/work/data/Gide_log2TPM.txt"
OUT_TPM = "/home/marcelo.hurtado/Documents/tme_analysis/dcede5cb31/work/prep/Gide_linTPM.csv"
COLDATA_SRC = "/home/marcelo.hurtado/Documents/tme_analysis/dcede5cb31/work/data/colData_all.txt"
OUT_COLDATA = "/home/marcelo.hurtado/Documents/tme_analysis/dcede5cb31/work/prep/Gide_coldata.csv"

with open(SRC) as f, open(OUT_TPM, "w", newline="") as out:
    reader = csv.reader(f, delimiter="\t")
    writer = csv.writer(out)
    header = next(reader)
    writer.writerow(["gene"] + header[1:])
    for row in reader:
        gene = row[0]
        vals = [2.0 ** float(v) - 1.0 for v in row[1:]]
        writer.writerow([gene] + vals)

with open(COLDATA_SRC) as f:
    reader = csv.reader(f, delimiter=" ")
    rows = list(reader)
header = ["rowname"] + [h.strip('"') for h in rows[0]]
gide = [dict(zip(header, [x.strip('"') for x in r])) for r in rows[1:] if r[-1].strip('"') == "Gide"]

with open(OUT_COLDATA, "w", newline="") as out:
    writer = csv.writer(out)
    writer.writerow(["Sample_id", "Response", "Therapy", "Timing"])
    for r in gide:
        writer.writerow([r["Sample_id"], r["Response"], r["Therapy"], r["Timing"]])

print("Gide samples:", len(gide))
