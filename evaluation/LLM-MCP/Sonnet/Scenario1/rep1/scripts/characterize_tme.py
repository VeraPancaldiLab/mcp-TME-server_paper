import csv
import statistics as st

RUN = "/home/marcelo.hurtado/Documents/tme_analysis/59dac6572f/mcp-tme-servers/multideconv/runs/sessions/Gide_20261016-203100_64f4c2/Gide/analyze_deconvolution_20261016-211331_89b051"
HARMONIZED_CSV = f"{RUN}/result_Deconvolution.matrix.csv"
COLDATA_CSV = "/home/marcelo.hurtado/Documents/tme_analysis/59dac6572f/work/work_data/Gide_colData.csv"
OUT_DIR = "/home/marcelo.hurtado/Documents/tme_analysis/59dac6572f/work/results"

CANONICAL_CELL_TYPES = [
    "B.cells", "B.naive.cells", "B.memory.cells",
    "Macrophages.cells", "Macrophages.M0", "Macrophages.M1", "Macrophages.M2",
    "Monocytes", "Neutrophils",
    "NK.cells", "NK.activated", "NK.resting", "NKT.cells",
    "CD4.cells", "CD4.memory.activated", "CD4.memory.resting", "CD4.naive",
    "CD8.cells", "CD4.regulatory", "CD4.non.regulatory",
    "T.cells.helper", "T.cells.gamma.delta", "T.cells.proliferative",
    "Dendritic.cells", "Dendritic.activated.cells", "Dendritic.resting.cells",
    "Dendritic.plasmacytoid.cells", "Eosinophils", "Plasma",
    "Mast.cells", "Mast.activated.cells", "Mast.resting.cells",
    "Myeloid.cells", "Basophils",
    "Endothelial", "Fibroblasts", "CAF", "Pericytes", "Mural.cells", "Myocytes",
    "Cancer", "Epithelial",
]
IMMUNE_TYPES = set(CANONICAL_CELL_TYPES[:33])
STROMAL_TYPES = {"Endothelial", "Fibroblasts", "CAF", "Pericytes", "Mural.cells", "Myocytes"}

with open(HARMONIZED_CSV) as f:
    reader = csv.reader(f)
    header = next(reader)[1:]
    rows = {}
    for line in reader:
        sample = line[0].strip('"').lstrip("X")
        vals = [float(v) for v in line[1:]]
        rows[sample] = vals

samples = list(rows.keys())

def columns_for_type(cell_type):
    cols = []
    for i, c in enumerate(header):
        c = c.strip('"')
        if c == f"{cell_type}" or c.endswith(f"_{cell_type}") or c.startswith(f"{cell_type}_Subgroup"):
            cols.append(i)
    return cols

per_type_summary = []
for ct in CANONICAL_CELL_TYPES:
    cols = columns_for_type(ct)
    if not cols:
        continue
    means = []
    for s in samples:
        vals = [rows[s][i] for i in cols]
        means.append(sum(vals) / len(vals))
    per_type_summary.append((ct, len(cols), st.mean(means), st.median(means), min(means), max(means)))

# Composite Immune/Stromal score uses ONLY the explicit aggregate group columns
# (built via aggregate_cell_groups -> analyze_deconvolution, cells_extra=["Immune","Stromal"]),
# not the individual cell-subtype fractions -- those don't sum to a meaningful "total immune
# fraction" when averaged together.
immune_cols = set()
stromal_cols = set()
for i, c in enumerate(header):
    c = c.strip('"')
    if c == "Quantiseq_TIL10_Immune" or c.startswith("Immune_Subgroup"):
        immune_cols.add(i)
    if c.startswith("Stromal_Subgroup") or c.endswith("_Stromal"):
        stromal_cols.add(i)

immune_cols = sorted(immune_cols)
stromal_cols = sorted(stromal_cols)
print("Immune columns used:", [header[i].strip('\"') for i in immune_cols])
print("Stromal columns used:", [header[i].strip('\"') for i in stromal_cols])

colmeta = {}
with open(COLDATA_CSV) as f:
    reader = csv.DictReader(f)
    for r in reader:
        colmeta[r["Sample_id"]] = r

scores = []
for s in samples:
    imm_vals = [rows[s][i] for i in immune_cols]
    str_vals = [rows[s][i] for i in stromal_cols]
    imm_score = sum(imm_vals) / len(imm_vals)
    str_score = sum(str_vals) / len(str_vals)
    meta = colmeta.get(s, {})
    scores.append({
        "Sample_id": s,
        "Immune_score": imm_score,
        "Stromal_score": str_score,
        "Response": meta.get("Response", ""),
        "Therapy": meta.get("Therapy", ""),
    })

scores.sort(key=lambda r: r["Immune_score"], reverse=True)
for rank, r in enumerate(scores, start=1):
    r["Immune_rank"] = rank

with open(f"{OUT_DIR}/Gide_immune_stromal_scores.csv", "w", newline="") as out:
    w = csv.DictWriter(out, fieldnames=["Sample_id", "Immune_score", "Stromal_score", "Immune_rank", "Response", "Therapy"])
    w.writeheader()
    for r in scores:
        w.writerow(r)

with open(f"{OUT_DIR}/Gide_cell_type_composition_summary.csv", "w", newline="") as out:
    w = csv.writer(out)
    w.writerow(["Cell_type", "Compartment", "N_features", "Mean_fraction", "Median_fraction", "Min_fraction", "Max_fraction"])
    for ct, n, mean_v, med_v, min_v, max_v in per_type_summary:
        compartment = "Immune" if ct in IMMUNE_TYPES else ("Stromal" if ct in STROMAL_TYPES else "Other")
        w.writerow([ct, compartment, n, round(mean_v, 4), round(med_v, 4), round(min_v, 4), round(max_v, 4)])

print("\nTop 10 most immune-infiltrated patients:")
for r in scores[:10]:
    print(f"  {r['Sample_id']:16s} Immune={r['Immune_score']:.3f}  Stromal={r['Stromal_score']:.3f}  Response={r['Response']}")

print("\nBottom 10 least immune-infiltrated patients:")
for r in scores[-10:]:
    print(f"  {r['Sample_id']:16s} Immune={r['Immune_score']:.3f}  Stromal={r['Stromal_score']:.3f}  Response={r['Response']}")
