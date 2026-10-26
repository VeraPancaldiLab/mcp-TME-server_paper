#!/bin/bash
# After a run has finished its analysis: debrief, standard export, then copy into evaluation/.
# Usage (from the repository root): bash evaluation/Benchmark/finish_run.sh <run> [<run> ...]
for run in "$@"; do
  python3 -u evaluation/Benchmark/run_benchmark.py debrief $run
  python3 -u evaluation/Benchmark/run_benchmark.py export $run
  python3 -u evaluation/Benchmark/run_benchmark.py collect $run
done
