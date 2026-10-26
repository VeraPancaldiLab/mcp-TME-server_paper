"""Process metrics of each benchmark run, written as CSV tables for the comparison reports.

Run from the repository root:

    python3 evaluation/Comparison/extract_run_metrics.py

It reads the event log of every run (evaluation/<arm>/<model>/Scenario<n>/rep<k>/log/events.jsonl,
written by evaluation/Benchmark/run_benchmark.py) and writes into evaluation/Comparison/metrics/:

    run_metrics.csv     one row per run: time, cost, tokens, tool calls, errors, questions asked
    messages.csv        every message sent to a run after the prompt (replies, restarts)
    mcp_calls.csv       every MCP tool call: tool, error or not
    outside_calls.csv   tool calls that touched files outside the run's own folder
    package_calls.csv   how each run called the packages: MCP tool calls with their arguments, and calls
                        to the functions of the R packages found in the code the run wrote or ran
"""

import csv
import json
import re
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
EVALUATION = HERE.parent
OUT = HERE / "metrics"

DEBRIEF_START = "The analysis is finished. Do not run anything else."
# files a run may read outside its own folder: the installed R packages and the package sources
ALLOWED_OUTSIDE = ("/R/x86_64-pc-linux-gnu-library/", "/Documents/multideconv", "/Documents/CellTFusion",
                   "/Documents/pipeML", "/Documents/RaCInG_package", "/Documents/Bioinfo-tools",
                   "/anaconda3/", "/.cache/", "/.local/")

# functions exported by the five R packages
PACKAGES = ["multideconv", "CellTFusion", "pipeML", "RaCInG_package", "Bioinfo-tools"]
EXPORTED = {}
for package in PACKAGES:
    namespace = (Path.home() / "Documents" / package / "NAMESPACE").read_text()
    for name in re.findall(r"^export\((.+)\)", namespace, flags=re.M):
        EXPORTED[name.strip('"')] = package
R_CALL = re.compile(r"(?<![\w.])(" + "|".join(re.escape(n) for n in EXPORTED) + r")\(")


def r_calls(code):
    """Calls to package functions in a piece of R code: (function, text of the call)."""
    calls = []
    for match in R_CALL.finditer(code):
        depth, end = 0, match.end() - 1
        for end in range(match.end() - 1, len(code)):  # up to the closing parenthesis
            depth += {"(": 1, ")": -1}.get(code[end], 0)
            if depth == 0:
                break
        calls.append((match.group(1), " ".join(code[match.start():end + 1].split())))
    return calls


def read_run(log):
    arm, model, scenario, repetition = log.relative_to(EVALUATION).parts[:4]
    scenario, repetition = scenario[-1], repetition[3:]  # "Scenario4" -> "4", "rep1" -> "1"
    events = [json.loads(line) for line in log.read_text().splitlines()]

    # the debrief questionnaire is not part of the analysis
    debrief = next((i for i, e in enumerate(events) if e.get("type") == "benchmark_message"
                    and e["message"].startswith(DEBRIEF_START)), len(events))
    events = events[:debrief]
    # the launcher sometimes wrote the same stall event twice
    events = [e for i, e in enumerate(events) if i == 0 or e != events[i - 1]]

    messages = [e["message"] for e in events if e.get("type") == "benchmark_message"]
    results = [e for e in events if e.get("type") == "result"]
    answers = [r for r in results if not r.get("is_error")]  # a turn cut by the plan limit ends with an error
    work_folder = next(e["cwd"] for e in events if e.get("type") == "system" and e.get("subtype") == "init")
    run_folder = str(Path(work_folder).parent)
    run_id = Path(run_folder).name
    allowed = ALLOWED_OUTSIDE + (("/Documents/mcp-tme-servers",) if arm == "LLM-MCP" else ())

    tool_names = {}
    tool_calls = mcp_calls = tool_errors = mcp_errors = 0
    mcp_rows, outside_rows, call_rows = [], [], []
    for e in events:
        if e.get("type") not in ("assistant", "user"):
            continue
        for block in e["message"]["content"]:
            if not isinstance(block, dict):
                continue
            if block.get("type") == "tool_use":
                tool_calls += 1
                tool_names[block["id"]] = block["name"]
                is_mcp = block["name"].startswith("mcp__")
                mcp_calls += is_mcp
                if is_mcp:
                    server, tool = block["name"].split("__")[1:3]
                    arguments = {k: "<given>" if any(s in k for s in ("credential", "cbsx", "token", "mail")) else v
                                 for k, v in block["input"].items() if k != "session_id"}
                    call = json.dumps(arguments).replace(run_folder + "/", "")
                    call_rows.append([arm, model, scenario, repetition, server, tool, call])
                code = " ".join(str(block["input"].get(k, "")) for k in ("content", "new_string", "command"))
                for function, call in r_calls(code):
                    if not call.endswith("()"):  # a call without arguments is usually a mention in a text
                        call_rows.append([arm, model, scenario, repetition, EXPORTED[function], function, call])
                text = json.dumps(block["input"])
                outside = [p for p in re.findall(r"(?:/home/[\w.]+|~)/[\w./\-]*", text)
                           if run_id not in p and not any(a in p for a in allowed)]
                if outside:
                    outside_rows.append([arm, model, scenario, repetition, block["name"], "; ".join(sorted(set(outside)))[:300]])
            if block.get("type") == "tool_result":
                name = tool_names.get(block.get("tool_use_id"), "")
                error = bool(block.get("is_error"))
                tool_errors += error
                if name.startswith("mcp__"):
                    mcp_errors += error
                    mcp_rows.append([arm, model, scenario, repetition, name.split("__")[-1], "error" if error else "ok"])

    # time: a turn reports its duration in its result; a turn stopped by the launcher has no result,
    # so its time goes from the first to the last timestamp of its events
    minutes, stamps = 0, []
    for e in events + [{"type": "benchmark_message"}]:
        if e.get("type") == "benchmark_message":  # a new turn starts: close the one before
            if len(stamps) > 1:
                first, last = (datetime.fromisoformat(s.replace("Z", "+00:00")) for s in (stamps[0], stamps[-1]))
                minutes += (last - first).total_seconds() / 60
            stamps = []
        elif e.get("type") == "result":
            minutes += e.get("duration_ms", 0) / 60000
            stamps = []
        elif "timestamp" in e:
            stamps.append(e["timestamp"])

    # each turn ends with a result event that holds the token counts of that turn
    token_kinds = ("input_tokens", "output_tokens", "cache_creation_input_tokens", "cache_read_input_tokens")
    tokens = sum(r.get("usage", {}).get(k) or 0 for r in results for k in token_kinds)
    replies = [m for m in messages[1:] if m != "Continue."]

    row = {
        "arm": arm, "model": model, "scenario": scenario, "repetition": repetition,
        "time_min": round(minutes, 1),
        "cost_usd": round(results[-1].get("total_cost_usd", 0), 2) if results else "",
        "total_tokens": tokens,
        "output_tokens": sum(r.get("usage", {}).get("output_tokens") or 0 for r in results),
        "steps": sum(r.get("num_turns", 0) for r in results),
        "tool_calls": tool_calls, "tool_errors": tool_errors,
        "mcp_calls": mcp_calls, "mcp_errors": mcp_errors,
        "questions_answered": len(replies),
        "asked_cibersortx_credentials": any("CIBERSORTx credentials" in m for m in replies),
        "restarts_after_stall": sum(e.get("type") == "benchmark_stall" for e in events),
        "timeouts": sum(e.get("type") == "benchmark_timeout" for e in events),
        "plan_limit_interruptions": sum(e.get("type") == "benchmark_plan_limit" for e in events),
        "calls_outside_own_folder": len(outside_rows),
        "finished": bool(answers) and answers[-1].get("subtype") == "success",
    }
    message_rows = [[arm, model, scenario, repetition, m] for m in messages[1:]]
    # the same call is often written several times (script edits, re-runs): keep each one once
    call_rows = [list(c) for c in dict.fromkeys(tuple(c) for c in call_rows)]
    return row, message_rows, mcp_rows, outside_rows, call_rows


def write(name, header, rows):
    with (OUT / name).open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(rows)


def main():
    OUT.mkdir(exist_ok=True)
    runs, messages, mcp, outside, calls = [], [], [], [], []
    for log in sorted(EVALUATION.glob("*/*/Scenario*/rep*/log/events.jsonl")):
        row, m, c, o, p = read_run(log)
        runs.append(row)
        messages += m
        mcp += c
        outside += o
        calls += p
    key = ["arm", "model", "scenario", "repetition"]
    write("run_metrics.csv", list(runs[0]), [list(r.values()) for r in runs])
    write("messages.csv", key + ["message"], messages)
    write("mcp_calls.csv", key + ["tool", "status"], mcp)
    write("outside_calls.csv", key + ["tool", "paths"], outside)
    write("package_calls.csv", key + ["package", "name", "call"], calls)
    print("wrote", len(runs), "runs to", OUT)


if __name__ == "__main__":
    main()
