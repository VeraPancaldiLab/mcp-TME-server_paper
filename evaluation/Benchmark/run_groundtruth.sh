#!/bin/bash
# Ground truth of the four scenarios, one after the other, with the frozen packages of the benchmark.
# Usage (from the repository root): bash evaluation/Benchmark/run_groundtruth.sh <folder for the HTML reports> [scripts]
# e.g. ... run_groundtruth.sh <folder> Scenario4/RaCInG   (default: the four scenarios)
export R_LIBS="$HOME/Documents/tme_benchmark_packages/library"
QUARTO=/usr/lib/rstudio/resources/app/bin/quarto/bin/quarto
scripts="${@:2}"
for script in ${scripts:-Scenario1/Deconvolution Scenario2/CellTFusion Scenario3/ML_analysis Scenario4/RaCInG}; do
  echo "=== GT $script started $(date '+%m-%d %H:%M')"
  (cd evaluation/Groundtruth/$(dirname $script) && $QUARTO render $(basename $script).qmd --output-dir "$1") || { echo "=== GT $script FAILED"; exit 1; }
  echo "=== GT $script finished $(date '+%m-%d %H:%M')"
done
