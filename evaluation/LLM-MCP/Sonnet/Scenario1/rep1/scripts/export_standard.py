import csv
import json
import re

BASE = "/home/marcelo.hurtado/Documents/tme_analysis/59dac6572f"
AGG_CSV = f"{BASE}/mcp-tme-servers/multideconv/runs/sessions/Gide_20261016-203100_64f4c2/Gide/aggregate_cell_groups_20261016-211320_8cb42b/result.csv"
HARM_CSV = f"{BASE}/mcp-tme-servers/multideconv/runs/sessions/Gide_20261016-203100_64f4c2/Gide/analyze_deconvolution_20261016-211331_89b051/result_Deconvolution.matrix.csv"
SCORES_CSV = f"{BASE}/work/results/Gide_immune_stromal_scores.csv"
OUT_DIR = f"{BASE}/work/results/standard"

ORIGINAL_SAMPLES = set()
with open(f"{BASE}/work/data/Gide_log2TPM.txt") as f:
    header = f.readline().rstrip("\n").split("\t")
    ORIGINAL_SAMPLES.update(header[1:])


def to_original_name(rname):
    r = rname.strip('"')
    if r in ORIGINAL_SAMPLES:
        return r
    if r.startswith("X") and r[1:] in ORIGINAL_SAMPLES:
        return r[1:]
    raise ValueError(f"Cannot map row name {r!r} back to an original sample name")


def convert_matrix(in_path, out_path):
    with open(in_path) as f, open(out_path, "w", newline="") as out:
        reader = csv.reader(f)
        header = next(reader)
        header = [h.strip('"') for h in header]
        w = csv.writer(out)
        w.writerow(["patient"] + header[1:])
        for row in reader:
            patient = to_original_name(row[0])
            w.writerow([patient] + row[1:])


convert_matrix(AGG_CSV, f"{OUT_DIR}/deconvolution_raw.csv")
convert_matrix(HARM_CSV, f"{OUT_DIR}/deconvolution_harmonized.csv")

with open(SCORES_CSV) as f, open(f"{OUT_DIR}/immune_score.csv", "w", newline="") as out:
    reader = csv.DictReader(f)
    w = csv.writer(out)
    w.writerow(["patient", "immune_score", "stromal_score"])
    for r in reader:
        patient = to_original_name(r["Sample_id"])
        w.writerow([patient, r["Immune_score"], r["Stromal_score"]])

info = {
    "input_scale": "linear TPM",
    "methods": ["Quantiseq", "Epidish", "DeconRNASeq", "DWLS", "CBSX"],
    "cibersortx": True,
}
with open(f"{OUT_DIR}/info.json", "w") as out:
    json.dump(info, out, indent=2)

print("done")
